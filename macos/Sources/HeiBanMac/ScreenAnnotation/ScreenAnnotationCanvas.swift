import HeiBanCore
import SwiftUI

/// 只渲染註記；AppKit 父視圖接收輸入。省略 CanvasBackground，保留實際桌面。
struct ScreenAnnotationCanvas: View {
    @ObservedObject var engine: BoardEngine
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasObjectsLayer(engine: engine)
                InFlightStrokeView(engine: engine, preview: engine.strokePreview)
                SelectionOverlayView(engine: engine)
                LaserOverlayView(laser: engine.laserEngine, viewport: engine.viewport)
                if engine.currentTool == .eraser,
                   let point = engine.eraserCursorPoint ?? engine.hoverCursorPoint {
                    EraserCursorOverlayView(engine: engine, point: point)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.coordinateSpace(name: "canvas").allowsHitTesting(false)
    }
}
