import SwiftUI
import HeiBanCore

struct AlignmentGuidesOverlayView: View {
    @ObservedObject var engine: BoardEngine

    var body: some View {
        Canvas { context, size in
            guard !engine.activeAlignmentGuides.isEmpty else { return }

            let guideColor = Color(hex: "#06b6d4") // Cyan guide lines
            let strokeStyle = StrokeStyle(lineWidth: 1.0, dash: [4, 4])

            for guide in engine.activeAlignmentGuides {
                var path = Path()
                if guide.isVertical {
                    let screenX = guide.position * engine.viewport.zoom + engine.viewport.x
                    let screenStartY = guide.start * engine.viewport.zoom + engine.viewport.y - 40
                    let screenEndY = guide.end * engine.viewport.zoom + engine.viewport.y + 40
                    path.move(to: CGPoint(x: screenX, y: max(0, screenStartY)))
                    path.addLine(to: CGPoint(x: screenX, y: min(size.height, screenEndY)))
                } else {
                    let screenY = guide.position * engine.viewport.zoom + engine.viewport.y
                    let screenStartX = guide.start * engine.viewport.zoom + engine.viewport.x - 40
                    let screenEndX = guide.end * engine.viewport.zoom + engine.viewport.x + 40
                    path.move(to: CGPoint(x: max(0, screenStartX), y: screenY))
                    path.addLine(to: CGPoint(x: min(size.width, screenEndX), y: screenY))
                }
                context.stroke(path, with: .color(guideColor.opacity(0.85)), style: strokeStyle)
            }
        }
        .allowsHitTesting(false)
    }
}
