import CoreGraphics
import Foundation
import SwiftUI

private final class CachedPathWrapper: NSObject {
    let path: Path
    init(_ path: Path) {
        self.path = path
    }
}

/// 使用實際幾何資料作 key，不能只看 points 字數或秒級 updatedAt。
/// 相同字數的新控制點、快速重畫、undo 都可能保持舊時間戳／尺寸。
private final class PathCacheKey: NSObject {
    private struct Geometry: Hashable {
        let id: String
        let type: String
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let points: String?
    }

    private let geometry: Geometry
    init(_ object: BoardObject) {
        geometry = Geometry(
            id: object.id, type: object.type, x: object.x, y: object.y,
            width: object.width, height: object.height, points: object.points)
    }
    override var hash: Int { geometry.hashValue }
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PathCacheKey else { return false }
        return geometry == other.geometry
    }
}

public enum BoardPathCache {
    private static let storage: NSCache<PathCacheKey, CachedPathWrapper> = {
        let cache = NSCache<PathCacheKey, CachedPathWrapper>()
        cache.countLimit = 8192
        cache.totalCostLimit = 128 * 1024 * 1024  // 128 MB
        return cache
    }()

    /// 取得筆跡或向量物件的世界座標路徑（含快取）
    public static func worldPath(for object: BoardObject) -> Path {
        let key = PathCacheKey(object)
        if let cached = storage.object(forKey: key) {
            return cached.path
        }

        let path: Path
        switch object.type {
        case "stroke", "highlighter", "paint":
            let points = object.parsedPoints
            guard !points.isEmpty else {
                path = Path()
                break
            }
            path = VectorMath.pointsToPath(points: points)

        case "curve":
            let points = object.parsedPoints
            guard points.count >= 3 else {
                path = VectorMath.pointsToPath(points: points)
                break
            }
            var curve = Path()
            curve.move(to: points[0].cgPoint)
            curve.addQuadCurve(to: points[2].cgPoint, control: points[1].cgPoint)
            path = curve

        case "rect":
            let rect = CGRect(x: object.x, y: object.y, width: object.width, height: object.height)
            path = Path(roundedRect: rect, cornerRadius: 8)

        case "circle", "ellipse":
            let rect = CGRect(x: object.x, y: object.y, width: object.width, height: object.height)
            path = Path(ellipseIn: rect)

        case "triangle":
            var p = Path()
            p.move(to: CGPoint(x: object.x + object.width / 2, y: object.y))
            p.addLine(to: CGPoint(x: object.x, y: object.y + object.height))
            p.addLine(to: CGPoint(x: object.x + object.width, y: object.y + object.height))
            p.closeSubpath()
            path = p

        case "diamond":
            var p = Path()
            p.move(to: CGPoint(x: object.x + object.width / 2, y: object.y))
            p.addLine(to: CGPoint(x: object.x + object.width, y: object.y + object.height / 2))
            p.addLine(to: CGPoint(x: object.x + object.width / 2, y: object.y + object.height))
            p.addLine(to: CGPoint(x: object.x, y: object.y + object.height / 2))
            p.closeSubpath()
            path = p

        default:
            path = Path()
        }

        // NSCache 的 totalCostLimit 只有傳入 cost 才有意義；此為估算，非精確記憶體量測。
        let estimatedCost = max(256, (object.points?.utf8.count ?? 0) * 4)
        storage.setObject(CachedPathWrapper(path), forKey: key, cost: estimatedCost)
        return path
    }

    /// 清理快取
    public static func clear() {
        storage.removeAllObjects()
    }
}
