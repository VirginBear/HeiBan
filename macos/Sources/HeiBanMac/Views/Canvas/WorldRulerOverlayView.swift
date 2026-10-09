import SwiftUI
import HeiBanCore

struct WorldRulerOverlayView: View {
    @ObservedObject var engine: BoardEngine

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let rulerThickness: CGFloat = 20.0

            ZStack(alignment: .topLeading) {
                // Top horizontal ruler
                Canvas { context, size in
                    drawHorizontalRuler(context: context, width: size.width, height: size.height)
                }
                .frame(width: w, height: rulerThickness)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.gray.opacity(0.3)), alignment: .bottom)

                // Left vertical ruler
                Canvas { context, size in
                    drawVerticalRuler(context: context, width: size.width, height: size.height)
                }
                .frame(width: rulerThickness, height: h)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(width: 1).foregroundStyle(Color.gray.opacity(0.3)), alignment: .trailing)

                // Top-left intersection corner
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: rulerThickness, height: rulerThickness)
                    .overlay(
                        Text("px")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.secondary)
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func stepForZoom(_ zoom: Double) -> (major: Double, minor: Double) {
        if zoom >= 2.0 {
            return (50.0, 10.0)
        } else if zoom >= 0.75 {
            return (100.0, 20.0)
        } else if zoom >= 0.3 {
            return (200.0, 50.0)
        } else {
            return (500.0, 100.0)
        }
    }

    private func drawHorizontalRuler(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        let zoom = engine.viewport.zoom
        let vx = engine.viewport.x
        let (majorStep, minorStep) = stepForZoom(zoom)

        let startWorld = (-vx) / zoom
        let endWorld = (Double(width) - vx) / zoom

        let firstMajor = floor(startWorld / majorStep) * majorStep
        var worldX = firstMajor
        while worldX <= endWorld {
            let screenX = CGFloat(worldX * zoom + vx)
            if screenX >= 20 && screenX <= width {
                var tick = Path()
                tick.move(to: CGPoint(x: screenX, y: height - 8))
                tick.addLine(to: CGPoint(x: screenX, y: height))
                context.stroke(tick, with: .color(Color.primary.opacity(0.6)), lineWidth: 1)

                let label = Text("\(Int(worldX))")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.75))
                context.draw(label, at: CGPoint(x: screenX + 12, y: height / 2 - 2))
            }
            worldX += majorStep
        }

        // Minor ticks
        var minorX = floor(startWorld / minorStep) * minorStep
        while minorX <= endWorld {
            let screenX = CGFloat(minorX * zoom + vx)
            if screenX >= 20 && screenX <= width {
                var tick = Path()
                tick.move(to: CGPoint(x: screenX, y: height - 4))
                tick.addLine(to: CGPoint(x: screenX, y: height))
                context.stroke(tick, with: .color(Color.primary.opacity(0.3)), lineWidth: 0.8)
            }
            minorX += minorStep
        }
    }

    private func drawVerticalRuler(context: GraphicsContext, width: CGFloat, height: CGFloat) {
        let zoom = engine.viewport.zoom
        let vy = engine.viewport.y
        let (majorStep, minorStep) = stepForZoom(zoom)

        let startWorld = (-vy) / zoom
        let endWorld = (Double(height) - vy) / zoom

        let firstMajor = floor(startWorld / majorStep) * majorStep
        var worldY = firstMajor
        while worldY <= endWorld {
            let screenY = CGFloat(worldY * zoom + vy)
            if screenY >= 20 && screenY <= height {
                var tick = Path()
                tick.move(to: CGPoint(x: width - 8, y: screenY))
                tick.addLine(to: CGPoint(x: width, y: screenY))
                context.stroke(tick, with: .color(Color.primary.opacity(0.6)), lineWidth: 1)

                let label = Text("\(Int(worldY))")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.75))
                context.draw(label, at: CGPoint(x: width / 2 - 2, y: screenY + 8))
            }
            worldY += majorStep
        }

        // Minor ticks
        var minorY = floor(startWorld / minorStep) * minorStep
        while minorY <= endWorld {
            let screenY = CGFloat(minorY * zoom + vy)
            if screenY >= 20 && screenY <= height {
                var tick = Path()
                tick.move(to: CGPoint(x: width - 4, y: screenY))
                tick.addLine(to: CGPoint(x: width, y: screenY))
                context.stroke(tick, with: .color(Color.primary.opacity(0.3)), lineWidth: 0.8)
            }
            minorY += minorStep
        }
    }
}
