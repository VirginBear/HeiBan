import SwiftUI
import HeiBanCore

struct SelectionOverlayView: View {
    @ObservedObject var engine: BoardEngine
    @ObservedObject private var preview: StrokePreviewStore

    init(engine: BoardEngine) { self.engine = engine; self.preview = engine.strokePreview }

    var body: some View {
        ZStack {
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

                if let line = engine.selectedEndpointLine {
                    for endpoint in [LineEndpoint.start, .end] {
                        let active = preview.lineEndpoint.flatMap { $0.objectID == line.id && $0.endpoint == endpoint ? $0.point : nil }
                        let world = active ?? Point(x: endpoint == .start ? line.x1 ?? line.x : line.x2 ?? line.x + line.width,
                                                    y: endpoint == .start ? line.y1 ?? line.y : line.y2 ?? line.y + line.height)
                        let projected = VectorMath.worldToScreen(world, viewport: engine.viewport)
                        // 整段平移也走獨立預覽，端點須跟著圖面移動而不逐樣本寫文件。
                        let point = Point(x: projected.x + preview.selectionOffset.width, y: projected.y + preview.selectionOffset.height)
                        let circle = Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
                        context.fill(circle, with: .color(.white))
                        context.stroke(circle, with: .color(line.isLocked == true ? .gray : .accentColor), lineWidth: 2)
                        context.draw(Text(endpoint == .start ? "A" : "B").font(.system(size: 12, weight: .bold)).foregroundColor(line.isLocked == true ? .gray : .accentColor),
                                     at: CGPoint(x: point.x, y: point.y + 19))
                    }
                }

                // 2. Draw Selection Bounding Box & 8 Handles & Rotation Handle
                if !engine.selectionUsesEndpoints, !engine.selectedIds.isEmpty, let bounds = engine.selectionBoundingBox {
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

            // 3. Transformation HUD Pills (Dimensions & Rotation)
            if let handle = engine.activeTransformHandle, let bounds = engine.selectionBoundingBox {
                let zoom = engine.viewport.zoom
                let screenOrigin = VectorMath.worldToScreen(Point(x: bounds.minX, y: bounds.minY), viewport: engine.viewport)
                let screenW = bounds.width * zoom
                let screenH = bounds.height * zoom
                let screenRect = CGRect(x: screenOrigin.x, y: screenOrigin.y, width: screenW, height: screenH)

                if handle == .rotate {
                    let degrees = engine.activeTransformDegrees ?? (engine.selectedObjects.first?.rotation ?? 0.0)
                    HUDBadgeView(text: CanvasHUDFormatter.formatRotation(degrees: degrees))
                        .position(x: screenRect.midX, y: max(20, screenRect.minY - 48))
                } else {
                    let hudText: String = {
                        if engine.selectedObjects.count == 1,
                           let single = engine.selectedObjects.first,
                           single.type == "line" || single.type == "arrow" {
                            return CanvasHUDFormatter.formatLength(length: hypot(bounds.width, bounds.height))
                        }
                        return CanvasHUDFormatter.formatDimensions(width: bounds.width, height: bounds.height)
                    }()
                    let hudY = screenRect.maxY + 24 <= engine.canvasSize.height - 20
                        ? screenRect.maxY + 24
                        : max(20, screenRect.minY - 24)
                    HUDBadgeView(text: hudText)
                        .position(x: screenRect.midX, y: hudY)
                }
            } else if let shape = engine.strokePreview.shapeObject, max(shape.width, shape.height) >= 5 {
                let zoom = engine.viewport.zoom
                let screenOrigin = VectorMath.worldToScreen(Point(x: shape.x, y: shape.y), viewport: engine.viewport)
                let screenW = shape.width * zoom
                let screenH = shape.height * zoom
                let screenRect = CGRect(x: screenOrigin.x, y: screenOrigin.y, width: screenW, height: screenH)
                let hudText = (shape.type == "line" || shape.type == "arrow")
                    ? CanvasHUDFormatter.formatLength(length: hypot(shape.width, shape.height))
                    : CanvasHUDFormatter.formatDimensions(width: shape.width, height: shape.height)
                HUDBadgeView(text: hudText)
                    .position(x: screenRect.midX, y: screenRect.maxY + 20)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct HUDBadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.78), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }
}
