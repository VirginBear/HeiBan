import SwiftUI
import HeiBanCore

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
        Color(hex: bgHex)
            .overlay(
                GridPatternView(gridStyle: gridStyle, viewport: viewport, backgroundColor: bgHex, gridColor: gridColor)
            )
            .overlay(
                FixedCanvasFrameView(viewport: viewport, canvasMode: canvasMode, width: canvasWidth, height: canvasHeight)
            )
            .ignoresSafeArea()
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
                let shadowRect = rect.offsetBy(dx: 4 * zoom, dy: 6 * zoom)
                context.fill(Path(roundedRect: shadowRect, cornerRadius: 4), with: .color(Color.black.opacity(0.35)))
                context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color.white.opacity(0.45)), lineWidth: 1.5)
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
        guard let bg = backgroundColor, bg.hasPrefix("#"), bg.count >= 7 else { return false }
        let hex = bg.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF)
        let g = Double((int >> 8) & 0xFF)
        let b = Double(int & 0xFF)
        return (r * 0.299 + g * 0.587 + b * 0.114) > 130
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
