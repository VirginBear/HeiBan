import HeiBanCore
import SwiftUI
import UniformTypeIdentifiers

/// 螢幕與一般畫布共用物件、指標與工具疊層；只省略背景及視角導航。
/// 互動元件在 NativePointerSurface 上方，空白區仍由原生 PointerView 直接取樣。
struct ScreenAnnotationCanvas: View {
    @ObservedObject var engine: BoardEngine
    var onInteraction: () -> Void
    @AppStorage("HeiBan.rulerColorMode") private var rulerColorMode = "adaptive"
    @AppStorage("HeiBan.rulerLabelColor") private var rulerLabelColor = "#0f172a"
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasObjectsLayer(engine: engine)
                InFlightStrokeView(engine: engine, preview: engine.strokePreview)
                SelectionOverlayView(engine: engine)
                NativePointerSurface(engine: engine, onInteraction: onInteraction, screenAnnotation: true)
                PolygonVertexHandlesView(engine: engine)
                if engine.ruler.enabled {
                    RulerOverlayView(engine: engine, appearance: RulerAppearance(
                        backgroundColor: "#ffffff", customInk: rulerColorMode == "custom" ? rulerLabelColor : nil))
                }
                SelectionQuickActionBar(engine: engine)
                AlignmentGuidesOverlayView(engine: engine)
                if engine.currentTool == .lasso { LassoOverlayView(engine: engine) }
                CompassOverlayView(compass: engine.compassEngine, engine: engine)
                LaserOverlayView(laser: engine.laserEngine, viewport: engine.viewport)
                if engine.currentTool == .eraser,
                   let point = engine.eraserCursorPoint ?? engine.hoverCursorPoint {
                    EraserCursorOverlayView(engine: engine, point: point).allowsHitTesting(false)
                }
                InspectorDockView(engine: engine, windowSize: geometry.size)
                CalculatorPanelView(model: engine.calculator, engine: engine, workspaceSize: geometry.size)
                TimerPanelView(coordinator: engine.timerCoordinator, engine: engine, workspaceSize: geometry.size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .coordinateSpace(name: "HeiBan.workspace")
            .onDrop(of: [UTType.fileURL, UTType.image], delegate: CanvasImageDropDelegate(engine: engine))
            .onAppear { engine.repositionRulerIfNeeded(windowSize: geometry.size) }
        }.coordinateSpace(name: "canvas")
    }
}
