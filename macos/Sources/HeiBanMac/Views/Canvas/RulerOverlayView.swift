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
                context.stroke(tick, with: .color(Color(hex: labelColor).opacity(major ? 0.95 : 0.62)), lineWidth: major ? 1.5 : 1)
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

private struct RulerBodyView: View, Equatable {
    let width: Double
    let height: Double
    let opacity: Double
    let appearance: RulerAppearance

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(hex: appearance.body).opacity(opacity))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: appearance.ink).opacity(0.4), lineWidth: 1))
            .overlay(StaticRulerTicksView(width: width, height: height, labelColor: appearance.ink).equatable())
            .frame(width: width, height: height)
    }
}

// MARK: - Virtual Ruler Overlay
struct RulerOverlayView: View {
    let engine: BoardEngine
    let appearance: RulerAppearance
    @ObservedObject private var rulerStore: RulerStateStore
    @ViewState private var showSettings = false

    init(engine: BoardEngine, appearance: RulerAppearance) {
        self.engine = engine
        self.appearance = appearance
        _rulerStore = ObservedObject(wrappedValue: engine.rulerStore)
    }

    private var ruler: RulerState { rulerStore.state }

    var body: some View {
        ZStack {
            // Ruler Body
            RulerBodyView(width: ruler.width, height: ruler.height, opacity: ruler.opacity, appearance: appearance)
                .equatable()
                .rotationEffect(.degrees(ruler.angle))
                .position(x: ruler.screenCenterX, y: ruler.screenCenterY)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            engine.updateRulerDrag(start: Point(value.startLocation), current: Point(value.location))
                        }
                        .onEnded { _ in engine.endRulerDrag() }
                )

            rotationHandle(fromLeft: true)
            rotationHandle(fromLeft: false)
            pivotHandle
            moveHandle
            angleButton
        }
        .coordinateSpace(name: "rulerOverlay")
        .allowsHitTesting(true)
        .transaction { $0.animation = nil }
    }

    private var angleButton: some View {
        let angle = ruler.angle * .pi / 180
        let localX = ruler.width / 2 - 90
        let localY = -ruler.height / 2 + 16
        return Button { showSettings = true } label: {
            Text(String(format: "%.1f°", ruler.angle))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: appearance.ink))
                .frame(width: 86, height: 26)
                .background(Color(hex: appearance.badge).opacity(0.95), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: appearance.ink).opacity(0.25)))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showSettings) { RulerSettingsView(engine: engine) }
        .position(x: ruler.screenCenterX + localX * cos(angle) - localY * sin(angle),
                  y: ruler.screenCenterY + localX * sin(angle) + localY * cos(angle))
        .accessibilityLabel("尺規角度 \(String(format: "%.1f", ruler.angle)) 度，點擊輸入角度")
        .help("點擊輸入角度與設定尺規配色（精度 0.1°）")
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
