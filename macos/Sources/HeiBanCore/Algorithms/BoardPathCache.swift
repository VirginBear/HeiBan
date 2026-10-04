import Foundation
import CoreGraphics
import SwiftUI

private final class CachedPathWrapper: NSObject {
    let path: Path
    init(_ path: Path) {
        self.path = path
    }
}

public enum BoardPathCache {
    private static let storage: NSCache<NSString, CachedPathWrapper> = {
        let cache = NSCache<NSString, CachedPathWrapper>()
        cache.countLimit = 8192
        cache.totalCostLimit = 128 * 1024 * 1024 // 128 MB
        return cache
    }()

    /// 取得筆跡或向量物件的世界座標路徑（含快取）
    public static func worldPath(for object: BoardObject) -> Path {
        let key = "\(object.id):\(object.updatedAt):\(object.points?.count ?? 0):\(object.width):\(object.height)" as NSString
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

        storage.setObject(CachedPathWrapper(path), forKey: key)
        return path
    }

    /// 清理快取
    public static func clear() {
        storage.removeAllObjects()
    }
}
