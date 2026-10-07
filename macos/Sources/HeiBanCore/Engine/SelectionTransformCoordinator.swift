import Foundation
import CoreGraphics

public struct Rect: Equatable, Codable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(_ cgRect: CGRect) {
        self.minX = cgRect.minX
        self.minY = cgRect.minY
        self.maxX = cgRect.maxX
        self.maxY = cgRect.maxY
    }

    public var cgRect: CGRect {
        CGRect(x: minX, y: minY, width: width, height: height)
    }
}

public struct TransformHandlePositions: Equatable {
    public var topLeft: Point
    public var topCenter: Point
    public var topRight: Point
    public var middleLeft: Point
    public var middleRight: Point
    public var bottomLeft: Point
    public var bottomCenter: Point
    public var bottomRight: Point
    public var rotationHandle: Point

    public init(
        topLeft: Point,
        topCenter: Point,
        topRight: Point,
        middleLeft: Point,
        middleRight: Point,
        bottomLeft: Point,
        bottomCenter: Point,
        bottomRight: Point,
        rotationHandle: Point
    ) {
        self.topLeft = topLeft
        self.topCenter = topCenter
        self.topRight = topRight
        self.middleLeft = middleLeft
        self.middleRight = middleRight
        self.bottomLeft = bottomLeft
        self.bottomCenter = bottomCenter
        self.bottomRight = bottomRight
        self.rotationHandle = rotationHandle
    }
}

public enum SelectionTransformCoordinator {
    public static func calculateHandlePositions(for bounds: Rect, rotation: Double = 0, zoom: Double = 1.0) -> TransformHandlePositions {
        let minX = bounds.minX
        let maxX = bounds.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY
        let midX = (minX + maxX) / 2.0
        let midY = (minY + maxY) / 2.0
        let rotationOffset = 25.0 / max(0.1, zoom)

        let rawTopLeft = Point(x: minX, y: minY)
        let rawTopCenter = Point(x: midX, y: minY)
        let rawTopRight = Point(x: maxX, y: minY)
        let rawMiddleLeft = Point(x: minX, y: midY)
        let rawMiddleRight = Point(x: maxX, y: midY)
        let rawBottomLeft = Point(x: minX, y: maxY)
        let rawBottomCenter = Point(x: midX, y: maxY)
        let rawBottomRight = Point(x: maxX, y: maxY)
        let rawRotation = Point(x: midX, y: minY - rotationOffset)

        if abs(rotation) < 1e-6 {
            return TransformHandlePositions(
                topLeft: rawTopLeft,
                topCenter: rawTopCenter,
                topRight: rawTopRight,
                middleLeft: rawMiddleLeft,
                middleRight: rawMiddleRight,
                bottomLeft: rawBottomLeft,
                bottomCenter: rawBottomCenter,
                bottomRight: rawBottomRight,
                rotationHandle: rawRotation
            )
        }

        let center = Point(x: midX, y: midY)
        return TransformHandlePositions(
            topLeft: rotatePoint(rawTopLeft, around: center, angle: rotation),
            topCenter: rotatePoint(rawTopCenter, around: center, angle: rotation),
            topRight: rotatePoint(rawTopRight, around: center, angle: rotation),
            middleLeft: rotatePoint(rawMiddleLeft, around: center, angle: rotation),
            middleRight: rotatePoint(rawMiddleRight, around: center, angle: rotation),
            bottomLeft: rotatePoint(rawBottomLeft, around: center, angle: rotation),
            bottomCenter: rotatePoint(rawBottomCenter, around: center, angle: rotation),
            bottomRight: rotatePoint(rawBottomRight, around: center, angle: rotation),
            rotationHandle: rotatePoint(rawRotation, around: center, angle: rotation)
        )
    }

    public static func hitTestHandle(
        point: Point,
        bounds: Rect,
        rotation: Double = 0,
        zoom: Double = 1.0,
        handleRadius: Double = 8.0
    ) -> TransformHandle? {
        let handles = calculateHandlePositions(for: bounds, rotation: rotation, zoom: zoom)
        let effectiveRadius = handleRadius / max(0.1, zoom)

        if distance(point, handles.rotationHandle) <= effectiveRadius {
            return .rotate
        }
        if distance(point, handles.topLeft) <= effectiveRadius {
            return .topLeft
        }
        if distance(point, handles.topRight) <= effectiveRadius {
            return .topRight
        }
        if distance(point, handles.bottomLeft) <= effectiveRadius {
            return .bottomLeft
        }
        if distance(point, handles.bottomRight) <= effectiveRadius {
            return .bottomRight
        }
        if distance(point, handles.topCenter) <= effectiveRadius {
            return .topCenter
        }
        if distance(point, handles.bottomCenter) <= effectiveRadius {
            return .bottomCenter
        }
        if distance(point, handles.middleLeft) <= effectiveRadius {
            return .middleLeft
        }
        if distance(point, handles.middleRight) <= effectiveRadius {
            return .middleRight
        }

        return nil
    }

    public static func applyResize(
        handle: TransformHandle,
        initialBounds: Rect,
        delta: CGPoint,
        maintainAspectRatio: Bool = false
    ) -> Rect {
        var minX = initialBounds.minX
        var maxX = initialBounds.maxX
        var minY = initialBounds.minY
        var maxY = initialBounds.maxY

        let dx = delta.x
        let dy = delta.y

        switch handle {
        case .topLeft:
            minX += dx
            minY += dy
        case .topCenter:
            minY += dy
        case .topRight:
            maxX += dx
            minY += dy
        case .middleLeft:
            minX += dx
        case .middleRight:
            maxX += dx
        case .bottomLeft:
            minX += dx
            maxY += dy
        case .bottomCenter:
            maxY += dy
        case .bottomRight:
            maxX += dx
            maxY += dy
        case .rotate:
            break
        }

        if maxX < minX {
            swap(&minX, &maxX)
        }
        if maxY < minY {
            swap(&minY, &maxY)
        }

        let width = max(10.0, maxX - minX)
        let height = max(10.0, maxY - minY)

        return Rect(minX: minX, minY: minY, maxX: minX + width, maxY: minY + height)
    }

    public static func calculateRotationAngle(currentPoint: Point, center: Point) -> Double {
        let dx = currentPoint.x - center.x
        let dy = currentPoint.y - center.y
        return atan2(dy, dx)
    }

    private static func rotatePoint(_ pt: Point, around center: Point, angle: Double) -> Point {
        let cosA = cos(angle)
        let sinA = sin(angle)
        let dx = pt.x - center.x
        let dy = pt.y - center.y
        return Point(
            x: center.x + dx * cosA - dy * sinA,
            y: center.y + dx * sinA + dy * cosA
        )
    }

    private static func distance(_ a: Point, _ b: Point) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
