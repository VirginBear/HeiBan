import Foundation

public struct RecognizedShape: Equatable {
    public var type: String // "line" | "circle" | "ellipse" | "rect"
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var x1: Double?
    public var y1: Double?
    public var x2: Double?
    public var y2: Double?

    public init(
        type: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        x1: Double? = nil,
        y1: Double? = nil,
        x2: Double? = nil,
        y2: Double? = nil
    ) {
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

public enum ShapeRecognizer {
    /// Recognizes whether a stroke represents a geometric line, circle, ellipse, or rectangle.
    /// Returns nil if the stroke is normal handwriting, an open wave/scribble, or doesn't match.
    public static func recognize(points: [Point]) -> RecognizedShape? {
        guard points.count >= 5 else { return nil }

        let start = points[0]
        let end = points[points.count - 1]

        // 1. Calculate path length and straight line distance
        var totalPathLength = 0.0
        for i in 0..<(points.count - 1) {
            totalPathLength += hypot(points[i + 1].x - points[i].x, points[i + 1].y - points[i].y)
        }

        let straightDist = hypot(end.x - start.x, end.y - start.y)

        // Line Recognition: If straight distance is at least 84% of total traveled path
        if straightDist > 20 && totalPathLength > 0 && (straightDist / totalPathLength) >= 0.84 {
            let minX = min(start.x, end.x)
            let minY = min(start.y, end.y)
            let w = abs(end.x - start.x)
            let h = abs(end.y - start.y)
            return RecognizedShape(
                type: "line",
                x: round(minX),
                y: round(minY),
                width: round(w),
                height: round(h),
                x1: round(start.x),
                y1: round(start.y),
                x2: round(end.x),
                y2: round(end.y)
            )
        }

        // Calculate bounding box and centroid
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        var sumX = 0.0
        var sumY = 0.0

        for p in points {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
            sumX += p.x
            sumY += p.y
        }

        let width = max(20.0, maxX - minX)
        let height = max(20.0, maxY - minY)
        let count = Double(points.count)
        let cx = sumX / count
        let cy = sumY / count

        let startEndGap = hypot(end.x - start.x, end.y - start.y)
        let maxDim = max(width, height)

        // Closed loops (circle, ellipse, rect) require start and end to be relatively close
        if (startEndGap < maxDim * 0.45 || startEndGap < 40.0) && width >= 20 && height >= 20 {
            let aspect = min(width, height) / max(width, height)
            let minDim = min(width, height)

            // 1. Circle check (aspect ratio close to 1:1, strictly low radial variance)
            // A square has radial variance ≈ 0.18, while a circle is < 0.10.
            if aspect >= 0.75 {
                var radialVariance = 0.0
                let avgR = (width + height) / 4.0
                for p in points {
                    let dist = hypot(p.x - cx, p.y - cy)
                    radialVariance += abs(dist - avgR)
                }
                let avgVariance = radialVariance / count
                if (avgVariance / avgR) < 0.12 {
                    return RecognizedShape(
                        type: "circle",
                        x: round(minX),
                        y: round(minY),
                        width: round(width),
                        height: round(height)
                    )
                }
            }

            // 2. Ellipse check (aspect ratio elongated, strictly low ellipse equation variance)
            // An elongated rectangle has ellipse variance ≈ 0.22, while an ellipse is < 0.10.
            if aspect < 0.75 {
                let a = width / 2.0
                let b = height / 2.0
                if a > 0 && b > 0 {
                    var ellipseVariance = 0.0
                    for p in points {
                        let termX = (p.x - cx) / a
                        let termY = (p.y - cy) / b
                        let normDist = sqrt(termX * termX + termY * termY)
                        ellipseVariance += abs(normDist - 1.0)
                    }
                    let avgEllipseVariance = ellipseVariance / count
                    if avgEllipseVariance < 0.12 {
                        return RecognizedShape(
                            type: "ellipse",
                            x: round(minX),
                            y: round(minY),
                            width: round(width),
                            height: round(height)
                        )
                    }
                }
            }

            // 3. Rectangle check: points hug the 4 bounding box edges closely
            var edgeDistSum = 0.0
            for p in points {
                let distToLeft = abs(p.x - minX)
                let distToRight = abs(p.x - maxX)
                let distToTop = abs(p.y - minY)
                let distToBottom = abs(p.y - maxY)
                edgeDistSum += min(distToLeft, distToRight, distToTop, distToBottom)
            }
            let avgEdgeDist = edgeDistSum / count
            if (avgEdgeDist / minDim) < 0.20 {
                return RecognizedShape(
                    type: "rect",
                    x: round(minX),
                    y: round(minY),
                    width: round(width),
                    height: round(height)
                )
            }
        }

        // Ordinary handwriting, open curves, or non-matching shapes -> return nil
        return nil
    }
}
