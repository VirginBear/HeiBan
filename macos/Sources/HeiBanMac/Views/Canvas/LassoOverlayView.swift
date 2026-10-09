import SwiftUI
import HeiBanCore

struct LassoOverlayView: View {
    @ObservedObject var engine: BoardEngine

    var body: some View {
        Canvas { context, size in
            guard engine.inFlightLassoPoints.count >= 2 else { return }
            let screenPoints = engine.inFlightLassoPoints.map {
                VectorMath.worldToScreen($0, viewport: engine.viewport)
            }

            var path = Path()
            path.move(to: CGPoint(x: screenPoints[0].x, y: screenPoints[0].y))
            for pt in screenPoints.dropFirst() {
                path.addLine(to: CGPoint(x: pt.x, y: pt.y))
            }

            // Soft tinted fill
            context.fill(path, with: .color(Color.accentColor.opacity(0.08)))

            // Dashed outline
            let strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [6, 4])
            context.stroke(path, with: .color(Color.accentColor.opacity(0.85)), style: strokeStyle)
        }
        .allowsHitTesting(false)
    }
}
