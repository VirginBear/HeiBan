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

    public static func size(for dock: AnnotationToolbarDock, collapsed: Bool = false, availableSize: NSSize) -> NSSize {
        let preferred: NSSize
        if collapsed {
            preferred = dock.isVertical
                ? NSSize(width: 64, height: min(252, availableSize.height))
                : NSSize(width: min(272, availableSize.width), height: 60)
        } else {
            if dock.isVertical {
                let fixedSectionHeight: CGFloat = 204
                let toolAreaHeight = availableSize.height - fixedSectionHeight
                // 16 個按鈕（11 個繪圖工具 + 5 個操作按鈕），每個 36 pt 高
                if toolAreaHeight >= 16 * 36 - 4 {
                    // 單欄 64 pt
                    preferred = NSSize(width: 64, height: min(688, availableSize.height))
                } else {
                    // 空間不足單欄排完：自動切換為雙欄 96 pt，杜絕滾動遮擋！
                    preferred = NSSize(width: 96, height: min(492, availableSize.height))
                }
            } else {
                let width = min(820, availableSize.width)
                let toolArea = max(32, width - 310)
                let toolCount = 11
                let columns = max(1, min(toolCount, Int((toolArea + 4) / 36)))
                let rows = (toolCount + columns - 1) / columns
                preferred = NSSize(width: width, height: 60 + CGFloat(rows - 1) * 36)
            }
        }
        return NSSize(width: min(preferred.width, availableSize.width), height: min(preferred.height, availableSize.height))
    }

    public static func size(for dock: AnnotationToolbarDock, collapsed: Bool = false, on screen: NSScreen) -> NSSize {
        size(for: dock, collapsed: collapsed, availableSize: availableFrame(on: screen).size)
    }

    public static func frame(for dock: AnnotationToolbarDock, position: Double, collapsed: Bool = false, availableFrame: NSRect) -> NSRect {
        let size = size(for: dock, collapsed: collapsed, availableSize: availableFrame.size)
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

    public static func frame(for dock: AnnotationToolbarDock, position: Double, collapsed: Bool = false, on screen: NSScreen) -> NSRect {
        frame(for: dock, position: position, collapsed: collapsed, availableFrame: availableFrame(on: screen))
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
