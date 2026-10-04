import Foundation
import CoreGraphics
import SwiftUI

public struct BoundingBox: Equatable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double
    public var width: Double
    public var height: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
        self.width = width
        self.height = height
    }

    public var cgRect: CGRect {
        CGRect(x: minX, y: minY, width: width, height: height)
    }
}

public enum VectorMath {
    /// Screen to World (Canvas) coordinate transformation
    public static func screenToWorld(_ screenPt: Point, viewport: ViewportTransform) -> Point {
        let worldX = (screenPt.x - viewport.x) / viewport.zoom
        let worldY = (screenPt.y - viewport.y) / viewport.zoom
        return Point(x: worldX, y: worldY, pressure: screenPt.pressure)
    }

    /// World to Screen coordinate transformation
    public static func worldToScreen(_ worldPt: Point, viewport: ViewportTransform) -> Point {
        let screenX = worldPt.x * viewport.zoom + viewport.x
        let screenY = worldPt.y * viewport.zoom + viewport.y
        return Point(x: screenX, y: screenY, pressure: worldPt.pressure)
    }

    /// Compute tight bounding box of a list of points
    public static func computeBoundingBox(points: [Point], strokeWidth: Double = 2.0) -> BoundingBox {
        guard !points.isEmpty else {
            return BoundingBox(minX: 0, minY: 0, maxX: 0, maxY: 0, width: 0, height: 0)
        }

        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        for p in points {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }

        let pad = strokeWidth / 2.0
        let bMinX = minX - pad
        let bMinY = minY - pad
        let bMaxX = maxX + pad
        let bMaxY = maxY + pad

        return BoundingBox(
            minX: bMinX,
            minY: bMinY,
            maxX: bMaxX,
            maxY: bMaxY,
            width: max(1.0, bMaxX - bMinX),
            height: max(1.0, bMaxY - bMinY)
        )
    }

    /// Snap point to ruler straight edge WITH strict length limiter (A13)
    public static func snapToRulerEdge(
        screenPt: Point,
        ruler: RulerState,
        snapTolerance: Double = 28.0,
        stopSnappingBeyondEnds: Bool = false
    ) -> (snapped: Bool, screenPt: Point) {
        guard ruler.enabled else { return (false, screenPt) }

        let rad = ruler.angle * Double.pi / 180.0
        let cosA = cos(-rad)
        let sinA = sin(-rad)

        // Transform point relative to ruler center
        let dx = screenPt.x - ruler.screenCenterX
        let dy = screenPt.y - ruler.screenCenterY
        let localX = dx * cosA - dy * sinA
        let localY = dx * sinA + dy * cosA

        let halfW = ruler.width / 2.0
        let halfH = ruler.height / 2.0

        if stopSnappingBeyondEnds && (localX < -halfW || localX > halfW) {
            return (false, screenPt)
        }

        // Distance to top edge (localY = -halfH) and bottom edge (localY = halfH)
        let distTop = abs(localY - (-halfH))
        let distBottom = abs(localY - halfH)

        let rCos = cos(rad)
        let rSin = sin(rad)
        let clampedLocalX = max(-halfW, min(halfW, localX))

        if distTop < snapTolerance {
            let snappedLocalY = -halfH
            return (
                true,
                Point(
                    x: ruler.screenCenterX + clampedLocalX * rCos - snappedLocalY * rSin,
                    y: ruler.screenCenterY + clampedLocalX * rSin + snappedLocalY * rCos,
                    pressure: screenPt.pressure
                )
            )
        } else if distBottom < snapTolerance {
            let snappedLocalY = halfH
            return (
                true,
                Point(
                    x: ruler.screenCenterX + clampedLocalX * rCos - snappedLocalY * rSin,
                    y: ruler.screenCenterY + clampedLocalX * rSin + snappedLocalY * rCos,
                    pressure: screenPt.pressure
                )
            )
        }

        return (false, screenPt)
    }

    /// Convert array of Points into a smooth SwiftUI Path using quadratic splines
    public static func pointsToPath(points: [Point]) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        if points.count == 1 {
            path.move(to: points[0].cgPoint)
            path.addLine(to: CGPoint(x: points[0].x + 0.1, y: points[0].y + 0.1))
            return path
        }

        if points.count == 2 {
            path.move(to: points[0].cgPoint)
            path.addLine(to: points[1].cgPoint)
            return path
        }

        path.move(to: points[0].cgPoint)
        for i in 0..<(points.count - 1) {
            appendSmoothSegment(to: &path, points: points, index: i)
        }

        return path
    }

    /// Each cubic segment becomes stable once its next neighboring sample arrives.
    public static func appendSmoothSegment(to path: inout Path, points: [Point], index i: Int) {
        guard i >= 0, i + 1 < points.count else { return }
        let p0 = points[max(0, i - 1)]
        let p1 = points[i]
        let p2 = points[i + 1]
        let p3 = points[min(points.count - 1, i + 2)]
        path.addCurve(to: p2.cgPoint,
            control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
            control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
    }

    /// Check if point is inside or near an object (for selection & eraser)
    public static func isPointNearObject(point: Point, object: BoardObject, threshold: Double = 15.0) -> Bool {
        if object.type == "stroke" || object.type == "highlighter" || object.type == "paint" || object.type == "curve" {
            let points = object.parsedPoints
            let hitRadius = max(threshold, object.strokeWidth / 2.0)
            if object.type == "curve", points.count >= 3 {
                var previous = points[0].cgPoint
                for step in 1...32 {
                    let t = Double(step) / 32
                    let u = 1 - t
                    let next = CGPoint(
                        x: u * u * points[0].x + 2 * u * t * points[1].x + t * t * points[2].x,
                        y: u * u * points[0].y + 2 * u * t * points[1].y + t * t * points[2].y
                    )
                    if distance(from: point.cgPoint, toSegmentFrom: previous, to: next) <= hitRadius { return true }
                    previous = next
                }
                return false
            }
            if points.count == 1 {
                return hypot(points[0].x - point.x, points[0].y - point.y) <= hitRadius
            }
            for index in 0..<(max(0, points.count - 1)) {
                if distance(from: point.cgPoint, toSegmentFrom: points[index].cgPoint, to: points[index + 1].cgPoint) <= hitRadius {
                    return true
                }
            }
            return false
        } else if object.type == "line" || object.type == "arrow" {
            let start = CGPoint(x: object.x1 ?? object.x, y: object.y1 ?? object.y)
            let end = CGPoint(x: object.x2 ?? (object.x + object.width), y: object.y2 ?? (object.y + object.height))
            let maxDist = max(threshold, object.strokeWidth / 2)
            switch object.extensionMode ?? .none {
            case .none:
                return distance(from: point.cgPoint, toSegmentFrom: start, to: end) <= maxDist
            case .start:
                let rayDir = CGPoint(x: start.x - end.x, y: start.y - end.y)
                return distanceToRay(from: point.cgPoint, rayOrigin: end, rayDirection: rayDir) <= maxDist
            case .end:
                let rayDir = CGPoint(x: end.x - start.x, y: end.y - start.y)
                return distanceToRay(from: point.cgPoint, rayOrigin: start, rayDirection: rayDir) <= maxDist
            case .both:
                return distanceToInfiniteLine(from: point.cgPoint, p1: start, p2: end) <= maxDist
            }
        } else {
            // Box hit test
            let minX = min(object.x, object.x + object.width) - threshold
            let maxX = max(object.x, object.x + object.width) + threshold
            let minY = min(object.y, object.y + object.height) - threshold
            let maxY = max(object.y, object.y + object.height) + threshold
            return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
        }
    }

    public static func distanceToRay(from point: CGPoint, rayOrigin: CGPoint, rayDirection: CGPoint) -> Double {
        let dx = rayDirection.x
        let dy = rayDirection.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return hypot(point.x - rayOrigin.x, point.y - rayOrigin.y) }
        let projection = max(0, ((point.x - rayOrigin.x) * dx + (point.y - rayOrigin.y) * dy) / lenSq)
        let closest = CGPoint(x: rayOrigin.x + projection * dx, y: rayOrigin.y + projection * dy)
        return hypot(point.x - closest.x, point.y - closest.y)
    }

    public static func distanceToInfiniteLine(from point: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return hypot(point.x - p1.x, point.y - p1.y) }
        let projection = ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / lenSq
        let closest = CGPoint(x: p1.x + projection * dx, y: p1.y + projection * dy)
        return hypot(point.x - closest.x, point.y - closest.y)
    }

    private static func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let projection = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let closest = CGPoint(x: start.x + projection * dx, y: start.y + projection * dy)
        return hypot(point.x - closest.x, point.y - closest.y)
    }

    /// Calculate visible rectangle in world coordinates
    public static func visibleWorldRect(canvasSize: CGSize, viewport: ViewportTransform, padding: Double = 50.0) -> CGRect {
        let minX = (-viewport.x) / viewport.zoom - padding
        let minY = (-viewport.y) / viewport.zoom - padding
        let maxX = (Double(canvasSize.width) - viewport.x) / viewport.zoom + padding
        let maxY = (Double(canvasSize.height) - viewport.y) / viewport.zoom + padding
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    /// Check if object bounds intersect with visible world rectangle (AABB culling)
    public static func intersects(object: BoardObject, worldVisibleRect: CGRect) -> Bool {
        let objMinX = min(object.x, object.x + object.width) - (object.strokeWidth / 2.0)
        let objMaxX = max(object.x, object.x + object.width) + (object.strokeWidth / 2.0)
        let objMinY = min(object.y, object.y + object.height) - (object.strokeWidth / 2.0)
        let objMaxY = max(object.y, object.y + object.height) + (object.strokeWidth / 2.0)

        return !(objMaxX < worldVisibleRect.minX ||
                 objMinX > worldVisibleRect.maxX ||
                 objMaxY < worldVisibleRect.minY ||
                 objMinY > worldVisibleRect.maxY)
    }

    /// Compute combined bounding box for an array of BoardObjects
    public static func selectionBounds(for objects: [BoardObject]) -> CGRect? {
        guard !objects.isEmpty else { return nil }

        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        for object in objects {
            if object.type == "stroke" || object.type == "highlighter" || object.type == "paint" || object.type == "curve" {
                let pts = object.parsedPoints
                if !pts.isEmpty {
                    for p in pts {
                        if p.x < minX { minX = p.x }
                        if p.x > maxX { maxX = p.x }
                        if p.y < minY { minY = p.y }
                        if p.y > maxY { maxY = p.y }
                    }
                } else {
                    let oMinX = min(object.x, object.x + object.width)
                    let oMaxX = max(object.x, object.x + object.width)
                    let oMinY = min(object.y, object.y + object.height)
                    let oMaxY = max(object.y, object.y + object.height)
                    if oMinX < minX { minX = oMinX }
                    if oMaxX > maxX { maxX = oMaxX }
                    if oMinY < minY { minY = oMinY }
                    if oMaxY > maxY { maxY = oMaxY }
                }
            } else if object.type == "line" || object.type == "arrow" {
                let x1 = object.x1 ?? object.x
                let y1 = object.y1 ?? object.y
                let x2 = object.x2 ?? (object.x + object.width)
                let y2 = object.y2 ?? (object.y + object.height)
                let lMinX = min(x1, x2)
                let lMaxX = max(x1, x2)
                let lMinY = min(y1, y2)
                let lMaxY = max(y1, y2)
                if lMinX < minX { minX = lMinX }
                if lMaxX > maxX { maxX = lMaxX }
                if lMinY < minY { minY = lMinY }
                if lMaxY > maxY { maxY = lMaxY }
            } else {
                let oMinX = min(object.x, object.x + object.width)
                let oMaxX = max(object.x, object.x + object.width)
                let oMinY = min(object.y, object.y + object.height)
                let oMaxY = max(object.y, object.y + object.height)
                if oMinX < minX { minX = oMinX }
                if oMaxX > maxX { maxX = oMaxX }
                if oMinY < minY { minY = oMinY }
                if oMaxY > maxY { maxY = oMaxY }
            }
        }

        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else { return nil }
        return CGRect(x: minX, y: minY, width: max(1.0, maxX - minX), height: max(1.0, maxY - minY))
    }

    /// Returns handle positions in world coordinates
    public static func handlePositions(for bounds: CGRect, zoom: Double = 1.0) -> [TransformHandle: CGPoint] {
        let rotOffset = 24.0 / max(0.01, zoom)
        return [
            .topLeft: CGPoint(x: bounds.minX, y: bounds.minY),
            .topCenter: CGPoint(x: bounds.midX, y: bounds.minY),
            .topRight: CGPoint(x: bounds.maxX, y: bounds.minY),
            .middleRight: CGPoint(x: bounds.maxX, y: bounds.midY),
            .bottomRight: CGPoint(x: bounds.maxX, y: bounds.maxY),
            .bottomCenter: CGPoint(x: bounds.midX, y: bounds.maxY),
            .bottomLeft: CGPoint(x: bounds.minX, y: bounds.maxY),
            .middleLeft: CGPoint(x: bounds.minX, y: bounds.midY),
            .rotate: CGPoint(x: bounds.midX, y: bounds.minY - rotOffset)
        ]
    }

    /// Hit test handles for selection bounding box
    public static func hitTestHandle(point: Point, bounds: CGRect, zoom: Double, hitRadius: Double = 12.0) -> TransformHandle? {
        let handles = handlePositions(for: bounds, zoom: zoom)
        let effectiveRadius = hitRadius / max(0.01, zoom)
        for (handle, pos) in handles {
            let dist = hypot(point.x - Double(pos.x), point.y - Double(pos.y))
            if dist <= effectiveRadius {
                return handle
            }
        }
        return nil
    }

    /// Check if object intersects or is enclosed by a marquee selection box
    public static func objectIntersectsRect(object: BoardObject, rect: CGRect) -> Bool {
        let objMinX = min(object.x, object.x + object.width)
        let objMaxX = max(object.x, object.x + object.width)
        let objMinY = min(object.y, object.y + object.height)
        let objMaxY = max(object.y, object.y + object.height)
        let objRect = CGRect(x: objMinX, y: objMinY, width: max(1.0, objMaxX - objMinX), height: max(1.0, objMaxY - objMinY))

        guard rect.intersects(objRect) else { return false }

        if object.type == "stroke" || object.type == "highlighter" || object.type == "paint" || object.type == "curve" {
            let pts = object.parsedPoints
            if pts.isEmpty { return true }
            for p in pts {
                if rect.contains(CGPoint(x: p.x, y: p.y)) { return true }
            }
            return false
        } else if object.type == "line" || object.type == "arrow" {
            let p1 = CGPoint(x: object.x1 ?? object.x, y: object.y1 ?? object.y)
            let p2 = CGPoint(x: object.x2 ?? (object.x + object.width), y: object.y2 ?? (object.y + object.height))
            if rect.contains(p1) || rect.contains(p2) { return true }
            return rect.intersects(objRect)
        } else {
            return true
        }
    }

    /// Scale/transform object from old bounds to new bounds, handling negative flips
    public static func transformObject(
        object: BoardObject,
        from oldBounds: CGRect,
        to newBounds: CGRect,
        preserveAspectRatio: Bool = false
    ) -> BoardObject {
        guard oldBounds.width > 0, oldBounds.height > 0 else { return object }
        var sx = newBounds.width / oldBounds.width
        var sy = newBounds.height / oldBounds.height

        if preserveAspectRatio {
            let s = max(abs(sx), abs(sy))
            sx = (sx < 0 ? -s : s)
            sy = (sy < 0 ? -s : s)
        }

        var updated = object

        let originX = Double(newBounds.origin.x)
        let originY = Double(newBounds.origin.y)
        let oldOriginX = Double(oldBounds.origin.x)
        let oldOriginY = Double(oldBounds.origin.y)

        if object.type == "stroke" || object.type == "highlighter" || object.type == "paint" || object.type == "curve" {
            let pts = object.parsedPoints
            let transformedPts = pts.map { p -> Point in
                let nx = originX + (p.x - oldOriginX) * sx
                let ny = originY + (p.y - oldOriginY) * sy
                return Point(x: nx, y: ny, pressure: p.pressure)
            }
            if let data = try? JSONEncoder().encode(transformedPts),
               let str = String(data: data, encoding: .utf8) {
                updated.points = str
            }
            let bb = computeBoundingBox(points: transformedPts, strokeWidth: object.strokeWidth)
            updated.x = bb.minX
            updated.y = bb.minY
            updated.width = bb.width
            updated.height = bb.height
        } else if object.type == "line" || object.type == "arrow" {
            let x1 = object.x1 ?? object.x
            let y1 = object.y1 ?? object.y
            let x2 = object.x2 ?? (object.x + object.width)
            let y2 = object.y2 ?? (object.y + object.height)

            let nx1 = originX + (x1 - oldOriginX) * sx
            let ny1 = originY + (y1 - oldOriginY) * sy
            let nx2 = originX + (x2 - oldOriginX) * sx
            let ny2 = originY + (y2 - oldOriginY) * sy

            updated.x1 = nx1
            updated.y1 = ny1
            updated.x2 = nx2
            updated.y2 = ny2
            updated.x = min(nx1, nx2)
            updated.y = min(ny1, ny2)
            updated.width = abs(nx2 - nx1)
            updated.height = abs(ny2 - ny1)
        } else if (object.type == "triangle" || object.type == "quadrilateral") && object.points != nil {
            let transformedPoints = object.parsedPoints.map { point in
                Point(x: originX + (point.x - oldOriginX) * sx, y: originY + (point.y - oldOriginY) * sy, pressure: point.pressure)
            }
            if let data = try? JSONEncoder().encode(transformedPoints), let json = String(data: data, encoding: .utf8) {
                updated.points = json
            }
            updated.x = transformedPoints.map(\.x).min() ?? originX
            updated.y = transformedPoints.map(\.y).min() ?? originY
            updated.width = max(1, (transformedPoints.map(\.x).max() ?? originX + 1) - updated.x)
            updated.height = max(1, (transformedPoints.map(\.y).max() ?? originY + 1) - updated.y)
        } else {
            var nx = originX + (object.x - oldOriginX) * sx
            var ny = originY + (object.y - oldOriginY) * sy
            let nw = object.width * abs(sx)
            let nh = object.height * abs(sy)
            if sx < 0 { nx -= nw }
            if sy < 0 { ny -= nh }

            updated.x = nx
            updated.y = ny
            updated.width = nw
            updated.height = nh

            if let fs = object.fontSize {
                let scaleFactor = (abs(sx) + abs(sy)) / 2.0
                updated.fontSize = max(8.0, fs * scaleFactor)
            }
        }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        return updated
    }

    /// Rotate object around pivot center
    public static func rotateObject(
        object: BoardObject,
        around center: CGPoint,
        deltaDegrees: Double
    ) -> BoardObject {
        var updated = object
        let rad = deltaDegrees * Double.pi / 180.0
        let cosA = cos(rad)
        let sinA = sin(rad)

        if object.type == "stroke" || object.type == "highlighter" || object.type == "paint" || object.type == "curve" {
            let pts = object.parsedPoints
            let rotatedPts = pts.map { p -> Point in
                let dx = p.x - Double(center.x)
                let dy = p.y - Double(center.y)
                let rx = Double(center.x) + dx * cosA - dy * sinA
                let ry = Double(center.y) + dx * sinA + dy * cosA
                return Point(x: rx, y: ry, pressure: p.pressure)
            }
            if let data = try? JSONEncoder().encode(rotatedPts),
               let str = String(data: data, encoding: .utf8) {
                updated.points = str
            }
            let bb = computeBoundingBox(points: rotatedPts, strokeWidth: object.strokeWidth)
            updated.x = bb.minX
            updated.y = bb.minY
            updated.width = bb.width
            updated.height = bb.height
            updated.rotation = (object.rotation + deltaDegrees).truncatingRemainder(dividingBy: 360.0)
        } else if object.type == "line" || object.type == "arrow" {
            let x1 = object.x1 ?? object.x
            let y1 = object.y1 ?? object.y
            let x2 = object.x2 ?? (object.x + object.width)
            let y2 = object.y2 ?? (object.y + object.height)

            let dx1 = x1 - Double(center.x)
            let dy1 = y1 - Double(center.y)
            let nx1 = Double(center.x) + dx1 * cosA - dy1 * sinA
            let ny1 = Double(center.y) + dx1 * sinA + dy1 * cosA

            let dx2 = x2 - Double(center.x)
            let dy2 = y2 - Double(center.y)
            let nx2 = Double(center.x) + dx2 * cosA - dy2 * sinA
            let ny2 = Double(center.y) + dx2 * sinA + dy2 * cosA

            updated.x1 = nx1
            updated.y1 = ny1
            updated.x2 = nx2
            updated.y2 = ny2
            updated.x = min(nx1, nx2)
            updated.y = min(ny1, ny2)
            updated.width = abs(nx2 - nx1)
            updated.height = abs(ny2 - ny1)
            updated.rotation = (object.rotation + deltaDegrees).truncatingRemainder(dividingBy: 360.0)
        } else if (object.type == "triangle" || object.type == "quadrilateral") && object.points != nil {
            let points = object.parsedPoints.map { point -> Point in
                let dx = point.x - Double(center.x)
                let dy = point.y - Double(center.y)
                return Point(x: Double(center.x) + dx * cosA - dy * sinA,
                             y: Double(center.y) + dx * sinA + dy * cosA,
                             pressure: point.pressure)
            }
            if let data = try? JSONEncoder().encode(points), let json = String(data: data, encoding: .utf8) { updated.points = json }
            updated.x = points.map(\.x).min() ?? object.x
            updated.y = points.map(\.y).min() ?? object.y
            updated.width = max(1, (points.map(\.x).max() ?? object.x + 1) - updated.x)
            updated.height = max(1, (points.map(\.y).max() ?? object.y + 1) - updated.y)
            updated.rotation = (object.rotation + deltaDegrees).truncatingRemainder(dividingBy: 360.0)
        } else {
            let objCenterX = object.x + object.width / 2.0
            let objCenterY = object.y + object.height / 2.0
            let dx = objCenterX - Double(center.x)
            let dy = objCenterY - Double(center.y)
            let newCenterX = Double(center.x) + dx * cosA - dy * sinA
            let newCenterY = Double(center.y) + dx * sinA + dy * cosA

            updated.x = newCenterX - object.width / 2.0
            updated.y = newCenterY - object.height / 2.0
            updated.rotation = (object.rotation + deltaDegrees).truncatingRemainder(dividingBy: 360.0)
        }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        return updated
    }
}

public enum TransformHandle: String, CaseIterable, Equatable {
    case topLeft
    case topCenter
    case topRight
    case middleRight
    case bottomRight
    case bottomCenter
    case bottomLeft
    case middleLeft
    case rotate

    public var cursorType: TransformCursorType {
        switch self {
        case .middleLeft, .middleRight:
            return .resizeHorizontal
        case .topCenter, .bottomCenter:
            return .resizeVertical
        case .topLeft, .bottomRight:
            return .resizeDiagonalNWSE
        case .topRight, .bottomLeft:
            return .resizeDiagonalNESW
        case .rotate:
            return .rotate
        }
    }
}

public enum TransformCursorType: String, CaseIterable, Equatable {
    case resizeHorizontal     // 左右雙向拉伸
    case resizeVertical       // 上下雙向拉伸
    case resizeDiagonalNWSE   // 左上-右下對角拉伸
    case resizeDiagonalNESW   // 右上-左下對角拉伸
    case rotate               // 旋轉
}

