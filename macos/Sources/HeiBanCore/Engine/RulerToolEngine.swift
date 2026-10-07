import Foundation

public struct RulerSnapResult: Equatable {
    public var snapped: Bool
    public var snappedPoint: Point

    public init(snapped: Bool, snappedPoint: Point) {
        self.snapped = snapped
        self.snappedPoint = snappedPoint
    }
}

public enum RulerToolEngine {
    public static func snapPointToRuler(
        point: Point,
        ruler: RulerState,
        snapTolerance: Double = 28.0,
        stopSnappingBeyondEnds: Bool = true
    ) -> RulerSnapResult {
        let result = VectorMath.snapToRulerEdge(
            screenPt: point,
            ruler: ruler,
            snapTolerance: snapTolerance,
            stopSnappingBeyondEnds: stopSnappingBeyondEnds
        )
        return RulerSnapResult(snapped: result.snapped, snappedPoint: result.screenPt)
    }

    public static func updatePivot(
        at screenPt: Point,
        ruler: inout RulerState
    ) {
        let angle = ruler.angle * .pi / 180
        let dx = screenPt.x - ruler.screenCenterX
        let dy = screenPt.y - ruler.screenCenterY
        let localX = dx * cos(angle) + dy * sin(angle)
        let localY = -dx * sin(angle) + dy * cos(angle)
        ruler.pivotRatio = max(0, min(1, localX / max(1, ruler.width) + 0.5))
        if localY < -ruler.height * 0.22 {
            ruler.pivotEdge = "top"
        } else if localY > ruler.height * 0.22 {
            ruler.pivotEdge = "bottom"
        } else {
            ruler.pivotEdge = "center"
        }
    }
}
