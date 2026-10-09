import Foundation
import CoreGraphics

public enum LassoMode: String, Codable, CaseIterable, Sendable {
    case freeform = "freeform"     // 自由手繪套索
    case rectangle = "rectangle"   // 矩形套索
}

public enum LassoFilter: String, Codable, CaseIterable, Sendable {
    case all = "all"                     // 全部物件
    case strokesOnly = "strokesOnly"     // 僅筆跡/繪圖
    case shapesOnly = "shapesOnly"       // 僅幾何形狀
    case textOnly = "textOnly"           // 僅文字與便簽
    case imagesOnly = "imagesOnly"       // 僅圖片
}

public enum LassoSelectionCoordinator {
    /// Tests which candidate objects should be selected given the lasso loop points and filter.
    public static func selectObjects(
        in points: [Point],
        objects: [BoardObject],
        mode: LassoMode = .freeform,
        filter: LassoFilter = .all
    ) -> Set<String> {
        guard !points.isEmpty, !objects.isEmpty else { return [] }

        var selected = Set<String>()

        switch mode {
        case .freeform:
            guard points.count >= 3 else { return [] }
            for obj in objects {
                if obj.isLocked == true || obj.isVisible == false { continue }
                guard matchesFilter(obj: obj, filter: filter) else { continue }

                // Test representative points: center and corners
                let cx = obj.x + obj.width / 2.0
                let cy = obj.y + obj.height / 2.0
                let centerPt = Point(x: cx, y: cy)

                if VectorMath.isPointInPolygon(point: centerPt, polygon: points) {
                    selected.insert(obj.id)
                    continue
                }

                // If object is a stroke/curve, check if any of its parsed points fall inside
                if ["stroke", "pen", "highlighter", "paint", "curve"].contains(obj.type) {
                    if obj.parsedPoints.contains(where: { VectorMath.isPointInPolygon(point: $0, polygon: points) }) {
                        selected.insert(obj.id)
                    }
                }
            }

        case .rectangle:
            let minX = points.map(\.x).min() ?? 0
            let maxX = points.map(\.x).max() ?? 0
            let minY = points.map(\.y).min() ?? 0
            let maxY = points.map(\.y).max() ?? 0
            let lassoRect = CGRect(x: minX, y: minY, width: max(1.0, maxX - minX), height: max(1.0, maxY - minY))

            for obj in objects {
                if obj.isLocked == true || obj.isVisible == false { continue }
                guard matchesFilter(obj: obj, filter: filter) else { continue }

                let objRect = CGRect(
                    x: min(obj.x, obj.x + obj.width),
                    y: min(obj.y, obj.y + obj.height),
                    width: max(1.0, abs(obj.width)),
                    height: max(1.0, abs(obj.height))
                )

                if lassoRect.intersects(objRect) {
                    selected.insert(obj.id)
                }
            }
        }

        return selected
    }

    public static func matchesFilter(obj: BoardObject, filter: LassoFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .strokesOnly:
            return ["stroke", "pen", "highlighter", "paint", "curve"].contains(obj.type)
        case .shapesOnly:
            return ["rect", "circle", "ellipse", "triangle", "quadrilateral", "diamond", "star", "line", "arrow", "arc", "rounded_rect", "polygon", "connector"].contains(obj.type)
        case .textOnly:
            return ["text", "sticky"].contains(obj.type)
        case .imagesOnly:
            return obj.type == "image"
        }
    }
}
