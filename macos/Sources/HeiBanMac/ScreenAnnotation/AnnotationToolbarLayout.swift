import AppKit

/// 螢幕工具列只保存停靠邊與可移動軸的位置，不把螢幕絕對座標寫進作品。
/// 原生桌面座標的 y 向上；負座標顯示器也使用相同算法。
enum AnnotationToolbarDock: String, CaseIterable {
    case top, bottom, left, right

    var isVertical: Bool { self == .left || self == .right }
    var title: String {
        switch self {
        case .top: return "上方"
        case .bottom: return "下方"
        case .left: return "左側"
        case .right: return "右側"
        }
    }
}

struct AnnotationToolbarLayout {
    static let inset: CGFloat = 12

    static func availableFrame(on screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        return NSRect(x: frame.minX + inset, y: frame.minY + inset,
                      width: max(1, frame.width - 2 * inset), height: max(1, frame.height - 2 * inset))
    }

    static func size(for dock: AnnotationToolbarDock, on screen: NSScreen) -> NSSize {
        let available = availableFrame(on: screen)
        // 側邊只有一欄圖示；屬性在彈出面板中調整，不為滑桿保留整條寬度。
        let preferred = dock.isVertical ? NSSize(width: 64, height: 688) : NSSize(width: 820, height: 60)
        return NSSize(width: min(preferred.width, available.width), height: min(preferred.height, available.height))
    }

    static func frame(for dock: AnnotationToolbarDock, position: Double, on screen: NSScreen) -> NSRect {
        let available = availableFrame(on: screen)
        let size = size(for: dock, on: screen)
        let fraction = CGFloat(position.isFinite ? min(1, max(0, position)) : 0.5)
        var origin = available.origin
        if dock.isVertical {
            origin.y += fraction * max(0, available.height - size.height)
            if dock == .right { origin.x = available.maxX - size.width }
        } else {
            origin.x += fraction * max(0, available.width - size.width)
            if dock == .top { origin.y = available.maxY - size.height }
        }
        return NSRect(origin: origin, size: size)
    }

    static func nearestDock(to point: NSPoint, on screen: NSScreen, current: AnnotationToolbarDock) -> AnnotationToolbarDock {
        let frame = screen.visibleFrame
        let distances: [AnnotationToolbarDock: CGFloat] = [
            .top: abs(frame.maxY - point.y), .bottom: abs(point.y - frame.minY),
            .left: abs(point.x - frame.minX), .right: abs(frame.maxX - point.x),
        ]
        let closest = distances.values.min() ?? 0
        // 角落距離接近時保留原邊；判斷只在 mouseUp 執行，不在拖曳中反覆改方向。
        if let distance = distances[current], distance <= closest + 12 { return current }
        return AnnotationToolbarDock.allCases.min { distances[$0, default: 0] < distances[$1, default: 0] } ?? current
    }

    static func position(forDrop point: NSPoint, dock: AnnotationToolbarDock, on screen: NSScreen) -> Double {
        let available = availableFrame(on: screen)
        let size = size(for: dock, on: screen)
        // 握把在左上內距約 24 pt；轉向後仍盡量讓握把留在放開的位置。
        let span = dock.isVertical ? available.height - size.height : available.width - size.width
        guard span > 0 else { return 0.5 }
        let offset = dock.isVertical ? point.y + 24 - size.height - available.minY : point.x - 24 - available.minX
        return Double(min(1, max(0, offset / span)))
    }
}
