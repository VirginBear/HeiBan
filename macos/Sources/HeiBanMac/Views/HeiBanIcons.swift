import HeiBanCore
import SwiftUI

/// Original HeiBan artwork, drawn in a 32-point grid and shared by every pin entry point.
/// The supplied image is a direction reference only; no pixels or paths were copied.
struct HeiBanPinIcon: View {
    var color: String = "#39B9DC"
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 32
            ZStack {
                PinSilhouette().fill(
                    LinearGradient(
                        colors: [Color(hex: color).opacity(0.8), Color(hex: color)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Path { path in
                    path.move(to: CGPoint(x: 15, y: 23))
                    path.addLine(to: CGPoint(x: 17, y: 23))
                    path.addLine(to: CGPoint(x: 16, y: 30))
                    path.closeSubpath()
                }.fill(Color(hex: "#DDE8E4"))
                PinSilhouette().stroke(
                    Color(hex: "#234B43"), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                Path { path in
                    path.move(to: CGPoint(x: 13, y: 7))
                    path.addLine(to: CGPoint(x: 18, y: 7))
                }
                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            .frame(width: 32, height: 32)
            .rotationEffect(.degrees(35))
            .scaleEffect(scale)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct PinSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // A gently tapered cap, short body and flared base distinguish our pushpin.
        path.move(to: CGPoint(x: 11, y: 4))
        path.addQuadCurve(to: CGPoint(x: 21, y: 4), control: CGPoint(x: 16, y: 2))
        path.addQuadCurve(to: CGPoint(x: 23, y: 8), control: CGPoint(x: 24, y: 4))
        path.addLine(to: CGPoint(x: 20, y: 10))
        path.addLine(to: CGPoint(x: 20, y: 17))
        path.addQuadCurve(to: CGPoint(x: 25, y: 21), control: CGPoint(x: 25, y: 18))
        path.addQuadCurve(to: CGPoint(x: 17, y: 23), control: CGPoint(x: 25, y: 23))
        path.addLine(to: CGPoint(x: 16, y: 30))
        path.addLine(to: CGPoint(x: 15, y: 23))
        path.addQuadCurve(to: CGPoint(x: 7, y: 21), control: CGPoint(x: 7, y: 23))
        path.addQuadCurve(to: CGPoint(x: 12, y: 17), control: CGPoint(x: 7, y: 18))
        path.addLine(to: CGPoint(x: 12, y: 10))
        path.addLine(to: CGPoint(x: 9, y: 8))
        path.addQuadCurve(to: CGPoint(x: 11, y: 4), control: CGPoint(x: 8, y: 4))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 32, y: rect.height / 32))
    }
}

/// One coherent outline system: binding, open edges and closed edges.
struct BoardFormatIcon: View {
    let mode: CanvasMode

    var body: some View {
        BoardFormatOutline(mode: mode)
            .stroke(.foreground, style: StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

private struct BoardFormatOutline: Shape {
    let mode: CanvasMode

    func path(in rect: CGRect) -> Path {
        var p = Path()
        func line(_ a: CGPoint, _ b: CGPoint) {
            p.move(to: a)
            p.addLine(to: b)
        }
        switch mode {
        case .notebook:
            p.addRoundedRect(
                in: CGRect(x: 5, y: 3, width: 16, height: 18), cornerSize: CGSize(width: 2, height: 2))
            line(CGPoint(x: 9, y: 3), CGPoint(x: 9, y: 21))
            for y in [7, 12, 17] { line(CGPoint(x: 3, y: y), CGPoint(x: 6, y: y)) }
            line(CGPoint(x: 12, y: 9), CGPoint(x: 17, y: 9))
            line(CGPoint(x: 12, y: 13), CGPoint(x: 17, y: 13))
        case .infinite:
            for (x, y, dx, dy) in [(3.0, 7.0, 4.0, -4.0), (21, 7, -4, -4), (3, 17, 4, 4), (21, 17, -4, 4)] {
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x, y: y + dy))
                p.addLine(to: CGPoint(x: x + dx, y: y + dy))
            }
            p.move(to: CGPoint(x: 12, y: 12))
            p.addCurve(to: CGPoint(x: 4, y: 12), control1: CGPoint(x: 7, y: 5), control2: CGPoint(x: 4, y: 8))
            p.addCurve(
                to: CGPoint(x: 12, y: 12), control1: CGPoint(x: 4, y: 16), control2: CGPoint(x: 7, y: 19))
            p.addCurve(
                to: CGPoint(x: 20, y: 12), control1: CGPoint(x: 17, y: 5), control2: CGPoint(x: 20, y: 8))
            p.addCurve(
                to: CGPoint(x: 12, y: 12), control1: CGPoint(x: 20, y: 16), control2: CGPoint(x: 17, y: 19))
        case .fixed:
            p.addRoundedRect(
                in: CGRect(x: 3, y: 4, width: 18, height: 13), cornerSize: CGSize(width: 2, height: 2))
            line(CGPoint(x: 12, y: 17), CGPoint(x: 12, y: 21))
            line(CGPoint(x: 8, y: 21), CGPoint(x: 16, y: 21))
        }
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

extension BoardMetadata {
    var iconCanvasMode: CanvasMode {
        if let mode = canvasMode { return mode }
        if canvasPreset == .notebook { return .notebook }
        if let preset = canvasPreset, preset != .infinite { return .fixed }
        if (canvasWidth ?? 0) > 0 && (canvasHeight ?? 0) > 0 { return .fixed }
        return .infinite
    }
    var canvasFormatLabel: String {
        switch iconCanvasMode {
        case .notebook: return "筆記本"
        case .infinite: return "無邊界筆記"
        case .fixed: return "有邊界黑板"
        }
    }

}

struct BoardFormatBadge: View {
    let board: BoardMetadata

    var body: some View {
        HStack(spacing: 5) {
            BoardFormatIcon(mode: board.iconCanvasMode).frame(width: 16, height: 16)
            Text(board.canvasFormatLabel).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.25))
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.97), in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("畫布類型：\(board.canvasFormatLabel)")
        .allowsHitTesting(false)
    }
}

/// Original drafting compass: two legs, crossbar and a joint, readable at toolbar scale.
struct HeiBanCompassIcon: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 24
            var path = Path()
            path.move(to: CGPoint(x: 12 * s, y: 5 * s))
            path.addLine(to: CGPoint(x: 4 * s, y: 22 * s))
            path.move(to: CGPoint(x: 12 * s, y: 5 * s))
            path.addLine(to: CGPoint(x: 20 * s, y: 22 * s))
            path.move(to: CGPoint(x: 7 * s, y: 15 * s))
            path.addLine(to: CGPoint(x: 17 * s, y: 15 * s))
            path.move(to: CGPoint(x: 12 * s, y: 0))
            path.addLine(to: CGPoint(x: 12 * s, y: 3 * s))
            context.stroke(
                path, with: .foreground,
                style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round, lineJoin: .round))
            context.stroke(
                Path(ellipseIn: CGRect(x: 9 * s, y: 3 * s, width: 6 * s, height: 6 * s)), with: .foreground,
                lineWidth: 1.6 * s)
        }.frame(width: 19, height: 19).accessibilityHidden(true)
    }
}

struct HeiBanMagnetIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            var path = Path()
            path.move(to: CGPoint(x: 5 * scale, y: 4 * scale))
            path.addLine(to: CGPoint(x: 5 * scale, y: 13 * scale))
            path.addCurve(
                to: CGPoint(x: 12 * scale, y: 20 * scale), control1: CGPoint(x: 5 * scale, y: 17 * scale),
                control2: CGPoint(x: 8 * scale, y: 20 * scale))
            path.addCurve(
                to: CGPoint(x: 19 * scale, y: 13 * scale), control1: CGPoint(x: 16 * scale, y: 20 * scale),
                control2: CGPoint(x: 19 * scale, y: 17 * scale))
            path.addLine(to: CGPoint(x: 19 * scale, y: 4 * scale))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
            for x in [3.0, 17.0] {
                context.fill(
                    Path(CGRect(x: x * scale, y: 4 * scale, width: 4 * scale, height: 3 * scale)),
                    with: .color(.white))
            }
        }.frame(width: 19, height: 19).accessibilityHidden(true)
    }
}
