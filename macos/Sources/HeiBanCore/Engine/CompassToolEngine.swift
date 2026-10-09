import Foundation
import CoreGraphics
import SwiftUI

public final class CompassToolEngine: ObservableObject {
    @Published public var isEnabled: Bool = false
    @Published public var center: Point = Point(x: 400.0, y: 300.0)
    @Published public var radius: Double = 120.0
    @Published public var startAngle: Double = 0.0 // degrees
    @Published public var sweepAngle: Double = 360.0 // degrees
    @Published public var isDrawingArc: Bool = false
    @Published public private(set) var isArmed = false
    @Published public var currentPencilAngle: Double = 0.0

    @Published public var strokeColor: String = "#86efac"
    @Published public var strokeWidth: Double = 3.5
    @Published public var lineStyle: String = "solid"

    public init() {}

    // MARK: - Safe Transformations & Clamping

    public func moveCenter(to newCenter: Point) {
        guard !isArmed else { return }
        guard !newCenter.x.isNaN, !newCenter.x.isInfinite,
              !newCenter.y.isNaN, !newCenter.y.isInfinite else { return }
        center = newCenter
    }

    public func adjustRadius(to newRadius: Double) {
        guard !isArmed else { return }
        guard !newRadius.isNaN, !newRadius.isInfinite else { return }
        // Clamp to positive reasonable range (min 5.0, max 20,000)
        radius = max(5.0, min(20000.0, newRadius))
    }

    public func setStartAngle(_ degrees: Double) {
        guard !degrees.isNaN, !degrees.isInfinite else { return }
        var norm = degrees.truncatingRemainder(dividingBy: 360.0)
        if norm < 0 { norm += 360.0 }
        startAngle = norm
        currentPencilAngle = norm
    }

    public func prepare() {
        isArmed = false
        isDrawingArc = false
        sweepAngle = 0
        currentPencilAngle = startAngle
    }

    public func toggleArmed() {
        guard !isDrawingArc else { return }
        isArmed.toggle()
        sweepAngle = 0
    }

    public func positionPencil(atAngle angle: Double) {
        guard !isArmed else { return }
        setStartAngle(angle)
    }

    public func setSweepAngle(_ degrees: Double) {
        guard !degrees.isNaN, !degrees.isInfinite else { return }
        sweepAngle = max(-360.0, min(360.0, degrees))
    }

    // MARK: - Interactive Arc Drawing

    public func startArc(atAngle: Double) {
        guard isArmed, !atAngle.isNaN, !atAngle.isInfinite else { return }
        var norm = atAngle.truncatingRemainder(dividingBy: 360.0)
        if norm < 0 { norm += 360.0 }
        // Begin exactly at the prepared tip, not the first moved mouse sample.
        sweepAngle = 0.0
        currentPencilAngle = startAngle
        isDrawingArc = true
        updateSweep(toAngle: norm)
    }

    public func updateSweep(toAngle: Double) {
        guard isDrawingArc, !toAngle.isNaN, !toAngle.isInfinite else { return }
        var delta = toAngle - currentPencilAngle
        // Cross-zero continuous sweep calculation
        while delta > 180.0 { delta -= 360.0 }
        while delta < -180.0 { delta += 360.0 }

        sweepAngle = max(-360, min(360, sweepAngle + delta))
        currentPencilAngle = toAngle
    }

    public func finishArcDrawing() {
        isDrawingArc = false
    }

    // MARK: - Committing to BoardEngine

    @discardableResult
    public func drawFullCircle(engine: BoardEngine, returnToSelect: Bool = true) -> BoardObject {
        let circleObj = BoardObject(
            type: "arc",
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2.0,
            height: radius * 2.0,
            strokeColor: strokeColor,
            fillColor: "none",
            strokeWidth: strokeWidth,
            lineStyle: lineStyle,
            pageId: engine.activePageId,
            arcRadius: radius,
            arcStartAngle: 0.0,
            arcSweepAngle: 360.0
        )

        engine.addObject(circleObj)
        engine.selectedIds = [circleObj.id]
        engine.showTemporaryStatus("已由圓規繪製整圓")

        if returnToSelect {
            engine.selectTool(.select)
            isEnabled = false
        }

        return circleObj
    }

    @discardableResult
    public func commitArc(engine: BoardEngine, returnToSelect: Bool = true) -> BoardObject {
        let effectiveSweep = sweepAngle

        let arcObj = BoardObject(
            type: "arc",
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2.0,
            height: radius * 2.0,
            strokeColor: strokeColor,
            fillColor: "none",
            strokeWidth: strokeWidth,
            lineStyle: lineStyle,
            pageId: engine.activePageId,
            arcRadius: radius,
            arcStartAngle: startAngle,
            arcSweepAngle: effectiveSweep
        )

        engine.addObject(arcObj)
        engine.selectedIds = [arcObj.id]
        engine.showTemporaryStatus("已由圓規建立可編輯圓弧")

        isDrawingArc = false

        if returnToSelect {
            engine.selectTool(.select)
            isEnabled = false
        }

        return arcObj
    }

    // MARK: - Handle Projections

    public func screenCenter(viewport: ViewportTransform) -> Point {
        VectorMath.worldToScreen(center, viewport: viewport)
    }

    public func screenRadius(viewport: ViewportTransform) -> Double {
        radius * viewport.zoom
    }

    public func screenRadiusEndpoint(angleDeg: Double, viewport: ViewportTransform) -> Point {
        let rad = angleDeg * Double.pi / 180.0
        let worldPt = Point(
            x: center.x + radius * cos(rad),
            y: center.y + radius * sin(rad)
        )
        return VectorMath.worldToScreen(worldPt, viewport: viewport)
    }
}
