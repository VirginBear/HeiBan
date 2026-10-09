import Foundation

public enum EraserToolEngine {
    /// Slices a vector stroke/curve object around an eraser center and radius.
    /// Returns the array of new segmented BoardObjects (with >= 2 points each), or [object] if not hit.
    public static func sliceStroke(
        object: BoardObject,
        eraserCenter: Point,
        eraserRadius: Double
    ) -> [BoardObject] {
        let controlPoints = object.parsedPoints
        let pts: [Point]
        if object.type == "curve", controlPoints.count >= 3 {
            pts = (0...48).map { step in
                let t = Double(step) / 48
                let u = 1 - t
                return Point(
                    x: u * u * controlPoints[0].x + 2 * u * t * controlPoints[1].x + t * t
                        * controlPoints[2].x,
                    y: u * u * controlPoints[0].y + 2 * u * t * controlPoints[1].y + t * t
                        * controlPoints[2].y
                )
            }
        } else {
            pts = controlPoints
        }

        guard !pts.isEmpty else { return [object] }

        let strokeHalfW = object.strokeWidth / 2.0
        let effectiveRadius = eraserRadius + strokeHalfW

        var hasHit = false
        var runs: [[Point]] = []
        var currentRun: [Point] = []

        for pt in pts {
            let dist = hypot(pt.x - eraserCenter.x, pt.y - eraserCenter.y)
            if dist <= effectiveRadius {
                hasHit = true
                if !currentRun.isEmpty {
                    runs.append(currentRun)
                    currentRun = []
                }
            } else {
                currentRun.append(pt)
            }
        }
        if !currentRun.isEmpty {
            runs.append(currentRun)
        }

        guard hasHit else { return [object] }

        var segments: [BoardObject] = []
        for run in runs where run.count >= 2 {
            let xs = run.map(\.x)
            let ys = run.map(\.y)
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 0
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 0
            let w = max(1.0, maxX - minX)
            let h = max(1.0, maxY - minY)
            let pointsJSON = String(data: (try? JSONEncoder().encode(run)) ?? Data(), encoding: .utf8)

            let segment = BoardObject(
                id: UUID().uuidString,
                boardId: object.boardId,
                type: object.type == "curve" ? "stroke" : object.type,
                x: minX,
                y: minY,
                width: w,
                height: h,
                points: pointsJSON,
                strokeColor: object.strokeColor,
                fillColor: object.fillColor,
                strokeWidth: object.strokeWidth,
                lineStyle: object.lineStyle,
                opacity: object.opacity,
                rotation: object.rotation,
                zIndex: object.zIndex,
                groupId: object.groupId,
                createdBy: object.createdBy,
                creatorName: object.creatorName,
                pageId: object.pageId
            )
            segments.append(segment)
        }

        return segments
    }
}
