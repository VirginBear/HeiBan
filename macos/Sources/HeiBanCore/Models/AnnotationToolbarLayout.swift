import AppKit

/// 螢幕工具列只保存停靠邊與可移動軸的位置，不把螢幕絕對座標寫進作品。
/// 原生桌面座標的 y 向上；負座標顯示器也使用相同算法。
public enum AnnotationToolbarDock: String, CaseIterable, Codable {
    case top, bottom, left, right

    public var isVertical: Bool { self == .left || self == .right }
    public var title: String {
        switch self {
        case .top: return "上方"
        case .bottom: return "下方"
        case .left: return "左側"
        case .right: return "右側"
        }
    }
}

/// 舊佈局呼叫者的預設格數；正式工具內容只由 ToolbarPreferences / ToolbarContentPolicy 定義。
/// 正式展開控制列走 ToolbarContentPolicy；這裡保留收合尺寸及舊呼叫者相容幾何。
public enum AnnotationToolbarCatalog {
    public static let horizontalItemCount = 17
    public static let verticalItemCount = 16
}

public struct AnnotationToolbarLayout {
    public static let inset: CGFloat = 12

    public static func availableFrame(for visibleFrame: NSRect) -> NSRect {
        NSRect(
            x: visibleFrame.minX + inset,
            y: visibleFrame.minY + inset,
            width: max(1, visibleFrame.width - 2 * inset),
            height: max(1, visibleFrame.height - 2 * inset)
        )
    }

    public static func availableFrame(on screen: NSScreen) -> NSRect {
        availableFrame(for: screen.visibleFrame)
    }

    public static func size(for dock: AnnotationToolbarDock, collapsed: Bool = false, availableSize: NSSize, itemCount: Int? = nil) -> NSSize {
        let verticalCount = max(1, itemCount ?? AnnotationToolbarCatalog.verticalItemCount)
        let horizontalCount = max(1, itemCount ?? AnnotationToolbarCatalog.horizontalItemCount)
        let preferred: NSSize
        if collapsed {
            preferred = dock.isVertical
                ? NSSize(width: 64, height: 252)
                : NSSize(width: min(284, availableSize.width), height: 60)
        } else if dock.isVertical {
            // 「更多」已併入共用網格；尾端只留下清空／退出，不累積舊工具列空白。
            let fixedHeight: CGFloat = itemCount == nil ? 212 : 176
            let rowsAvailable = max(1, Int((availableSize.height - fixedHeight + 4) / 36))
            let columns = min(verticalCount, max(1, Int(ceil(Double(verticalCount) / Double(rowsAvailable)))))
            let rows = Int(ceil(Double(verticalCount) / Double(columns)))
            preferred = NSSize(width: max(64, CGFloat(columns) * 36 + 12),
                               height: fixedHeight + CGFloat(rows) * 36 - 4)
        } else {
            let width = min(itemCount == nil ? 820 : max(284, horizontalFixedWidth + CGFloat(horizontalCount) * 36 - 4), availableSize.width, 820)
            let columns = horizontalColumns(width: width, itemCount: horizontalCount)
            let rows = Int(ceil(Double(horizontalCount) / Double(columns)))
            preferred = NSSize(width: width, height: 60 + CGFloat(rows - 1) * 36)
        }
        return NSSize(width: min(preferred.width, availableSize.width), height: min(preferred.height, availableSize.height))
    }

    /// 握把＋模式 92，清空＋退出 70，分隔線 2，組間距 24，外內距 24。
    /// 中段依共用偏好計算數量，每格 32 pt／4 pt 間距；退出固定在中段之外。
    public static let horizontalFixedWidth: CGFloat = 174
    public static func horizontalColumns(width: CGFloat, itemCount: Int = AnnotationToolbarCatalog.horizontalItemCount) -> Int {
        max(1, min(max(1, itemCount), Int((max(32, width - horizontalFixedWidth) + 4) / 36)))
    }

    public static func size(for dock: AnnotationToolbarDock, collapsed: Bool = false, on screen: NSScreen, itemCount: Int? = nil) -> NSSize {
        size(for: dock, collapsed: collapsed, availableSize: availableFrame(on: screen).size, itemCount: itemCount)
    }

    public static func frame(for dock: AnnotationToolbarDock, position: Double, collapsed: Bool = false, availableFrame: NSRect, itemCount: Int? = nil) -> NSRect {
        let size = size(for: dock, collapsed: collapsed, availableSize: availableFrame.size, itemCount: itemCount)
        let fraction = CGFloat(position.isFinite ? min(1, max(0, position)) : 0.5)
        var origin = availableFrame.origin
        if dock.isVertical {
            origin.y += fraction * max(0, availableFrame.height - size.height)
            if dock == .right { origin.x = availableFrame.maxX - size.width }
        } else {
            origin.x += fraction * max(0, availableFrame.width - size.width)
            if dock == .top { origin.y = availableFrame.maxY - size.height }
        }
        return NSRect(origin: origin, size: size)
    }

    public static func frame(for dock: AnnotationToolbarDock, position: Double, collapsed: Bool = false, on screen: NSScreen, itemCount: Int? = nil) -> NSRect {
        frame(for: dock, position: position, collapsed: collapsed, availableFrame: availableFrame(on: screen), itemCount: itemCount)
    }

    public static func nearestDock(to point: NSPoint, visibleFrame: NSRect, current: AnnotationToolbarDock) -> AnnotationToolbarDock {
        let distances: [AnnotationToolbarDock: CGFloat] = [
            .top: abs(visibleFrame.maxY - point.y),
            .bottom: abs(point.y - visibleFrame.minY),
            .left: abs(point.x - visibleFrame.minX),
            .right: abs(visibleFrame.maxX - point.x),
        ]
        let closest = distances.values.min() ?? 0
        if let distance = distances[current], distance <= closest + 12 { return current }
        return AnnotationToolbarDock.allCases.min { distances[$0, default: 0] < distances[$1, default: 0] } ?? current
    }

    public static func nearestDock(to point: NSPoint, on screen: NSScreen, current: AnnotationToolbarDock) -> AnnotationToolbarDock {
        nearestDock(to: point, visibleFrame: screen.visibleFrame, current: current)
    }

    public static func position(forDrop point: NSPoint, dock: AnnotationToolbarDock, availableFrame: NSRect, size: NSSize) -> Double {
        let span = dock.isVertical ? availableFrame.height - size.height : availableFrame.width - size.width
        guard span > 0 else { return 0.5 }
        let offset = dock.isVertical ? point.y + 24 - size.height - availableFrame.minY : point.x - 24 - availableFrame.minX
        return Double(min(1, max(0, offset / span)))
    }

    public static func position(forDrop point: NSPoint, dock: AnnotationToolbarDock, on screen: NSScreen) -> Double {
        let available = availableFrame(on: screen)
        let size = size(for: dock, on: screen)
        return position(forDrop: point, dock: dock, availableFrame: available, size: size)
    }
}
