import SwiftUI
import HeiBanCore

struct InFlightStrokeView: View {
    @ObservedObject var engine: BoardEngine
    @ObservedObject var preview: StrokePreviewStore

    var body: some View {
        Canvas { context, size in
            let zoom = engine.viewport.zoom
            let vx = engine.viewport.x
            let vy = engine.viewport.y

            if !engine.polygonDraftPoints.isEmpty {
                let anchors = engine.polygonDraftPoints.map { CGPoint(x: $0.x * zoom + vx, y: $0.y * zoom + vy) }
                var draft = Path()
                if let first = anchors.first {
                    draft.move(to: first)
                    for anchor in anchors.dropFirst() { draft.addLine(to: anchor) }
                    if let cursor = engine.polygonDraftCursorPoint {
                        let cursorScreen = CGPoint(x: cursor.x * zoom + vx, y: cursor.y * zoom + vy)
                        draft.addLine(to: cursorScreen)
                        context.stroke(draft, with: .color(Color(hex: engine.activeColor)), style: StrokeStyle(lineWidth: max(2, engine.activeStrokeWidth * zoom), lineCap: .round, lineJoin: .round))
                        if anchors.count > 1 {
                            var closingEdge = Path()
                            closingEdge.move(to: cursorScreen)
                            closingEdge.addLine(to: first)
                            context.stroke(closingEdge, with: .color(Color(hex: engine.activeColor).opacity(0.62)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        }
                        let cursorMarker = CGRect(x: cursorScreen.x - 4, y: cursorScreen.y - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: cursorMarker), with: .color(Color(hex: engine.activeColor).opacity(0.45)))
                    } else {
                        context.stroke(draft, with: .color(Color(hex: engine.activeColor)), style: StrokeStyle(lineWidth: max(2, engine.activeStrokeWidth * zoom), lineCap: .round, lineJoin: .round))
                    }
                }
                for screen in anchors {
                    let marker = CGRect(x: screen.x - 4, y: screen.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: marker), with: .color(Color(hex: engine.activeColor)))
                }
                return
            }

            // If shape recognized during hold
            if let shape = preview.snappedShape {
                let sx = shape.x * zoom + vx
                let sy = shape.y * zoom + vy
                let sw = shape.width * zoom
                let sh = shape.height * zoom
                let color = Color(hex: engine.activeColor)

                switch shape.type {
                case "line":
                    var path = Path()
                    let x1 = (shape.x1 ?? shape.x) * zoom + vx
                    let y1 = (shape.y1 ?? shape.y) * zoom + vy
                    let x2 = (shape.x2 ?? (shape.x + shape.width)) * zoom + vx
                    let y2 = (shape.y2 ?? (shape.y + shape.height)) * zoom + vy
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                    let strokeStyle = StrokeStyle(
                        lineWidth: engine.activeStrokeWidth * zoom,
                        lineCap: .round,
                        dash: dashPattern(for: engine.activeLineStyle, zoom: zoom)
                    )
                    context.opacity = engine.activeOpacity
                    context.stroke(path, with: .color(color), style: strokeStyle)
                case "circle", "ellipse":
                    let rect = CGRect(x: sx, y: sy, width: sw, height: sh)
                    let strokeStyle = StrokeStyle(
                        lineWidth: engine.activeStrokeWidth * zoom,
                        dash: dashPattern(for: engine.activeLineStyle, zoom: zoom)
                    )
                    context.opacity = engine.activeOpacity
                    context.stroke(Path(ellipseIn: rect), with: .color(color), style: strokeStyle)
                default: // rect
                    let rect = CGRect(x: sx, y: sy, width: sw, height: sh)
                    let strokeStyle = StrokeStyle(
                        lineWidth: engine.activeStrokeWidth * zoom,
                        dash: dashPattern(for: engine.activeLineStyle, zoom: zoom)
                    )
                    context.opacity = engine.activeOpacity
                    context.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(color), style: strokeStyle)
                }
                return
            }

            // Otherwise draw active points
            guard !preview.points.isEmpty else { return }
            let opacity = engine.currentTool == .highlighter ? engine.activeHighlighterOpacity : engine.activeOpacity
            let multiplier = engine.currentTool == .highlighter ? 3.5 : (engine.currentTool == .paint ? 8.0 : 1.0)
            let minimumWidth = engine.currentTool == .highlighter ? 12.0 : (engine.currentTool == .paint ? 24.0 : 0.0)
            let color = Color(hex: engine.activeColor)
            let width = max(minimumWidth, engine.activeStrokeWidth * multiplier)
            context.opacity = opacity
            // Composite translucent ink once, preventing darker seams between cached chunks.
            context.drawLayer { layer in
                layer.translateBy(x: vx, y: vy)
                layer.scaleBy(x: zoom, y: zoom)
                let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                layer.stroke(preview.stablePath, with: .color(color), style: style)
                layer.stroke(preview.activePath, with: .color(color), style: style)
                layer.stroke(preview.tailPath, with: .color(color), style: style)
            }
        }
    }
}
