import SwiftUI
import HeiBanCore

struct StaticRulerTicksView: View, Equatable {
    let width: CGFloat
    let height: CGFloat
    let labelColor: String

    static func == (lhs: StaticRulerTicksView, rhs: StaticRulerTicksView) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height && lhs.labelColor == rhs.labelColor
    }

    var body: some View {
        Canvas { context, size in
            for mark in stride(from: 0, through: Int(size.width), by: 10) {
                let major = mark % 50 == 0
                let medium = mark % 20 == 0
                let length: CGFloat = major ? 23 : (medium ? 15 : 8)
                var tick = Path()
                tick.move(to: CGPoint(x: CGFloat(mark), y: 0))
                tick.addLine(to: CGPoint(x: CGFloat(mark), y: length))
                context.stroke(tick, with: .color(.white.opacity(major ? 0.95 : 0.62)), lineWidth: major ? 1.5 : 1)
                if major {
                    let label = Text("\(mark)").font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundColor(Color(hex: labelColor).opacity(0.95))
                    context.draw(label, at: CGPoint(x: CGFloat(mark + 10), y: size.height - 8))
                }
            }
        }
        .frame(width: width, height: height)
        .drawingGroup()
    }
}

// MARK: - Virtual Ruler Overlay
struct RulerOverlayView: View {
    @ObservedObject var engine: BoardEngine
    let labelColor: String

    private var ruler: RulerState { engine.ruler }

    var body: some View {
        ZStack {
            // Ruler Body
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    StaticRulerTicksView(width: ruler.width, height: ruler.height, labelColor: labelColor)
                        .equatable()
                )
                .overlay(alignment: .topTrailing) {
                    Text("\(Int(ruler.angle))°")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: labelColor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.4), in: Capsule())
                        .padding(.top, 3)
                        .padding(.trailing, 40)
                }
                .frame(width: ruler.width, height: ruler.height)
                .rotationEffect(.degrees(ruler.angle))
                .position(x: ruler.screenCenterX, y: ruler.screenCenterY)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            engine.updateRulerDrag(start: Point(value.startLocation), current: Point(value.location))
                        }
                        .onEnded { _ in engine.endRulerDrag() }
                )
                .opacity(ruler.opacity)

            rotationHandle(fromLeft: true)
            rotationHandle(fromLeft: false)
            pivotHandle
            moveHandle
        }
        .coordinateSpace(name: "rulerOverlay")
        .allowsHitTesting(true)
    }

    private func rotationHandle(fromLeft: Bool) -> some View {
        let direction = fromLeft ? -1.0 : 1.0
        let angle = ruler.angle * .pi / 180
        let offset = direction * (ruler.width / 2 - 14)
        return Circle()
            .fill(Color.accentColor)
            .frame(width: 26, height: 26)
            .overlay(Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11)).foregroundColor(.white))
            .position(
                x: ruler.screenCenterX + offset * cos(angle),
                y: ruler.screenCenterY + offset * sin(angle)
            )
            .gesture(
                DragGesture(coordinateSpace: .named("rulerOverlay"))
                    .onChanged { value in
                        engine.rotateRuler(toward: Point(value.location), fromLeftEnd: fromLeft)
                    }
            )
            .help(fromLeft ? "拖曳左端旋轉尺" : "拖曳右端旋轉尺")
    }

    private var moveHandle: some View {
        let angle = ruler.angle * .pi / 180
        let localX = -ruler.width * 0.28
        let localY: Double = 0
        let pointX = ruler.screenCenterX + localX * cos(angle) - localY * sin(angle)
        let pointY = ruler.screenCenterY + localX * sin(angle) + localY * cos(angle)
        return Capsule()
            .fill(Color.accentColor)
            .frame(width: 38, height: 28)
            .overlay(Image(systemName: "move.3d").font(.system(size: 12, weight: .semibold)).foregroundColor(.white))
            .position(x: pointX, y: pointY)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                    .onChanged { value in
                        engine.updateRulerDrag(start: Point(value.startLocation), current: Point(value.location))
                    }
                    .onEnded { _ in engine.endRulerDrag() }
            )
            .zIndex(10)
            .help("拖曳此把手移動尺")
    }

    private var pivotHandle: some View {
        let angle = ruler.angle * .pi / 180
        let localX = (ruler.pivotRatio - 0.5) * ruler.width
        let localY: Double = ruler.pivotEdge == "top" ? -ruler.height / 2 : (ruler.pivotEdge == "bottom" ? ruler.height / 2 : 0)
        return Circle()
            .fill(Color.orange.opacity(0.48))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1))
            .position(
                x: ruler.screenCenterX + localX * cos(angle) - localY * sin(angle),
                y: ruler.screenCenterY + localX * sin(angle) + localY * cos(angle)
            )
            .gesture(
                DragGesture(coordinateSpace: .named("rulerOverlay"))
                    .onChanged { value in engine.updateRulerPivot(at: Point(value.location)) }
            )
            .help("沿尺拖曳設定旋轉固定點與尺緣")
    }
}
