import SwiftUI
import HeiBanCore

/// Keep stored content intact when changing formats, while drawing only on the paper.
struct CanvasContentBounds: Shape {
    private let pageRect: CGRect?

    init(board: BoardMetadata, viewport: ViewportTransform) {
        if (board.canvasMode == .fixed || board.canvasMode == .notebook),
           let width = board.canvasWidth, let height = board.canvasHeight {
            pageRect = CGRect(x: viewport.x, y: viewport.y, width: width * viewport.zoom, height: height * viewport.zoom)
        } else {
            pageRect = nil
        }
    }

    func path(in rect: CGRect) -> Path {
        Path(pageRect ?? rect)
    }
}

struct CanvasBackgroundView: View {
    let theme: BoardTheme
    let gridStyle: GridStyle
    let viewport: ViewportTransform
    var canvasMode: CanvasMode? = .infinite
    var canvasWidth: Double? = nil
    var canvasHeight: Double? = nil
    var backgroundColor: String? = nil
    var gridColor: String? = nil

    var body: some View {
        let bgHex = backgroundColor ?? theme.defaultBackgroundColor
        let bounded = canvasMode == .fixed || canvasMode == .notebook
        GeometryReader { geo in
            ZStack {
                if bounded, let w = canvasWidth, let h = canvasHeight {
                    Color(red: 0.82, green: 0.84, blue: 0.85)
                    Rectangle()
                        .fill(Color(hex: bgHex))
                        .frame(width: w * viewport.zoom, height: h * viewport.zoom)
                        .shadow(color: .black.opacity(0.24), radius: 8, x: 0, y: 4)
                        .position(x: viewport.x + w * viewport.zoom / 2, y: viewport.y + h * viewport.zoom / 2)
                    GridPatternView(gridStyle: gridStyle, viewport: viewport, backgroundColor: bgHex, gridColor: gridColor)
                        .mask {
                            Rectangle()
                                .frame(width: w * viewport.zoom, height: h * viewport.zoom)
                                .position(x: viewport.x + w * viewport.zoom / 2, y: viewport.y + h * viewport.zoom / 2)
                        }
                } else {
                    Color(hex: bgHex)
                    GridPatternView(gridStyle: gridStyle, viewport: viewport, backgroundColor: bgHex, gridColor: gridColor)
                }
                FixedCanvasFrameView(viewport: viewport, canvasMode: canvasMode, width: canvasWidth, height: canvasHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

struct FixedCanvasFrameView: View {
    let viewport: ViewportTransform
    let canvasMode: CanvasMode?
    let width: Double?
    let height: Double?

    var body: some View {
        if (canvasMode == .fixed || canvasMode == .notebook), let w = width, let h = height, w > 0, h > 0 {
            let zoom = viewport.zoom
            let pageX = viewport.x
            let pageY = viewport.y
            let pageW = w * zoom
            let pageH = h * zoom
            let rect = CGRect(x: pageX, y: pageY, width: pageW, height: pageH)

            Canvas { context, _ in
                context.stroke(Path(rect), with: .color(Color.black.opacity(0.22)), lineWidth: 1)
            }
            .allowsHitTesting(false)
        }
    }
}

struct GridPatternView: View {
    let gridStyle: GridStyle
    let viewport: ViewportTransform
    var backgroundColor: String? = nil
    var gridColor: String? = nil

    private var isLightBackground: Bool {
        guard let bg = backgroundColor, let components = HexColorComponents(hex: bg) else { return false }
        return (components.red * 0.299 + components.green * 0.587 + components.blue * 0.114) > 130.0 / 255
    }

    var body: some View {
        Canvas { context, size in
            let step = 32.0 * viewport.zoom
            guard step > 8 else { return }

            let offsetX = viewport.x.truncatingRemainder(dividingBy: step)
            let offsetY = viewport.y.truncatingRemainder(dividingBy: step)

            let dotColor: Color
            let lineColor: Color
            if let custom = gridColor {
                dotColor = Color(hex: custom)
                lineColor = Color(hex: custom)
            } else if isLightBackground {
                dotColor = Color.black.opacity(0.22)
                lineColor = Color.black.opacity(0.16)
            } else {
                dotColor = Color.white.opacity(0.12)
                lineColor = Color.white.opacity(0.08)
            }

            switch gridStyle {
            case .dots:
                var x = offsetX
                while x < size.width {
                    var y = offsetY
                    while y < size.height {
                        let dotRect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                        context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                        y += step
                    }
                    x += step
                }
            case .grid:
                var path = Path()
                var x = offsetX
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y = offsetY
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            case .lines:
                var path = Path()
                var y = offsetY
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            case .staff:
                let lineGap = 8.0 * viewport.zoom
                let staveGap = 40.0 * viewport.zoom
                let staveHeight = lineGap * 4.0 + staveGap
                let staveOffsetY = viewport.y.truncatingRemainder(dividingBy: staveHeight)
                var path = Path()
                var currentTop = staveOffsetY - staveHeight
                while currentTop < size.height + staveHeight {
                    for i in 0..<5 {
                        let lineY = currentTop + Double(i) * lineGap
                        if lineY >= 0 && lineY <= size.height {
                            path.move(to: CGPoint(x: 0, y: lineY))
                            path.addLine(to: CGPoint(x: size.width, y: lineY))
                        }
                    }
                    currentTop += staveHeight
                }
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            case .blank:
                break
            }
        }
    }
}
