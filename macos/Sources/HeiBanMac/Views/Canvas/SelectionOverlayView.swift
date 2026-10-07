import SwiftUI
import HeiBanCore

struct SelectionOverlayView: View {
    @ObservedObject var engine: BoardEngine

    var body: some View {
        Canvas { context, _ in
            let zoom = engine.viewport.zoom

            // 1. Draw Marquee Box
            if let marquee = engine.marqueeRect, marquee.width > 0 || marquee.height > 0 {
                let screenOrigin = VectorMath.worldToScreen(Point(x: marquee.minX, y: marquee.minY), viewport: engine.viewport)
                let screenRect = CGRect(
                    x: screenOrigin.x,
                    y: screenOrigin.y,
                    width: marquee.width * zoom,
                    height: marquee.height * zoom
                )
                // Fill translucent accent color
                context.fill(Path(screenRect), with: .color(Color.accentColor.opacity(0.12)))
                // Stroke dashed border
                let strokeStyle = StrokeStyle(lineWidth: 1.0, dash: [4, 4])
                context.stroke(Path(screenRect), with: .color(Color.accentColor), style: strokeStyle)
            }

            // 2. Draw Selection Bounding Box & 8 Handles & Rotation Handle
            if !engine.selectedIds.isEmpty, let bounds = engine.selectionBoundingBox {
                let screenOrigin = VectorMath.worldToScreen(Point(x: bounds.minX, y: bounds.minY), viewport: engine.viewport)
                let screenW = bounds.width * zoom
                let screenH = bounds.height * zoom
                let screenRect = CGRect(x: screenOrigin.x, y: screenOrigin.y, width: screenW, height: screenH)

                // Selection Box border
                let borderStroke = StrokeStyle(lineWidth: 1.5)
                context.stroke(Path(screenRect), with: .color(Color.accentColor.opacity(0.85)), style: borderStroke)

                // Handles in screen space
                let handlePoints: [(TransformHandle, CGPoint)] = [
                    (.topLeft, CGPoint(x: screenRect.minX, y: screenRect.minY)),
                    (.topCenter, CGPoint(x: screenRect.midX, y: screenRect.minY)),
                    (.topRight, CGPoint(x: screenRect.maxX, y: screenRect.minY)),
                    (.middleRight, CGPoint(x: screenRect.maxX, y: screenRect.midY)),
                    (.bottomRight, CGPoint(x: screenRect.maxX, y: screenRect.maxY)),
                    (.bottomCenter, CGPoint(x: screenRect.midX, y: screenRect.maxY)),
                    (.bottomLeft, CGPoint(x: screenRect.minX, y: screenRect.maxY)),
                    (.middleLeft, CGPoint(x: screenRect.minX, y: screenRect.midY))
                ]

                // Line connecting top-center to rotation handle
                let rotHandleScreen = CGPoint(x: screenRect.midX, y: screenRect.minY - 24)
                var stemPath = Path()
                stemPath.move(to: CGPoint(x: screenRect.midX, y: screenRect.minY))
                stemPath.addLine(to: rotHandleScreen)
                context.stroke(stemPath, with: .color(Color.accentColor.opacity(0.8)), style: StrokeStyle(lineWidth: 1.0))

                // Rotation handle circle
                let rotRadius: CGFloat = 5.0
                let rotRect = CGRect(x: rotHandleScreen.x - rotRadius, y: rotHandleScreen.y - rotRadius, width: rotRadius * 2, height: rotRadius * 2)
                context.fill(Path(ellipseIn: rotRect), with: .color(.white))
                context.stroke(Path(ellipseIn: rotRect), with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 1.5))

                // 8 Resize Handles (squares)
                let handleSize: CGFloat = 8.0
                let halfH = handleSize / 2.0
                for (_, pos) in handlePoints {
                    let hRect = CGRect(x: pos.x - halfH, y: pos.y - halfH, width: handleSize, height: handleSize)
                    context.fill(Path(roundedRect: hRect, cornerRadius: 1.5), with: .color(.white))
                    context.stroke(Path(roundedRect: hRect, cornerRadius: 1.5), with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 1.5))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
