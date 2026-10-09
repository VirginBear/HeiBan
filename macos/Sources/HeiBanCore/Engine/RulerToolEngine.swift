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
    /// Both typed angles and pointer rotation use 0.1° increments.
    public static func quantizedAngle(_ degrees: Double) -> Double? {
        guard degrees.isFinite else { return nil }
        var result = (degrees.truncatingRemainder(dividingBy: 360) * 10).rounded() / 10
        if result > 180 { result -= 360 }
        if result < -180 { result += 360 }
        return result == 0 ? 0 : result
    }

    /// Rotate around the chosen pivot, including when the angle is entered with the keyboard.
    @discardableResult
    public static func setAngle(_ degrees: Double, ruler: inout RulerState) -> Bool {
        guard let angle = quantizedAngle(degrees) else { return false }
        if ruler.angle == angle { return true }
        let oldAngle = ruler.angle * .pi / 180
        let newAngle = angle * .pi / 180
        let x = (ruler.pivotRatio - 0.5) * ruler.width
        let y = ruler.pivotEdge == "top" ? -ruler.height / 2 : (ruler.pivotEdge == "bottom" ? ruler.height / 2 : 0)
        let pivotX = ruler.screenCenterX + x * cos(oldAngle) - y * sin(oldAngle)
        let pivotY = ruler.screenCenterY + x * sin(oldAngle) + y * cos(oldAngle)
        ruler.angle = angle
        ruler.screenCenterX = pivotX - x * cos(newAngle) + y * sin(newAngle)
        ruler.screenCenterY = pivotY - x * sin(newAngle) - y * cos(newAngle)
        return true
    }

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
