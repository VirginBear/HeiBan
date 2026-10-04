import SwiftUI
import AppKit
import UniformTypeIdentifiers
import HeiBanCore

public struct CanvasView: View {
    @ObservedObject var engine: BoardEngine
    @AppStorage("HeiBan.rulerLabelColor") private var rulerLabelColor = "#FFFFFF"

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Board Background & Grid
                CanvasBackgroundView(
                    theme: engine.board.boardTheme,
                    gridStyle: engine.board.gridStyle,
                    viewport: engine.viewport,
                    canvasMode: engine.board.canvasMode,
                    canvasWidth: engine.board.canvasWidth,
                    canvasHeight: engine.board.canvasHeight
                )

                // 2. Render Board Objects
                CanvasObjectsLayer(engine: engine)

                // 3. Render In-flight Stroke & GoodNotes Snapped Preview
                InFlightStrokeView(engine: engine, preview: engine.strokePreview)

                // 3.5 Selection Bounding Box & Transform Handles Overlay
                SelectionOverlayView(engine: engine)

                // 4. Gesture surface sits behind the ruler so ruler handles can receive drags.
                NativePointerSurface(engine: engine)

                if engine.currentTool == .eraser, engine.eraserMode == .pixel,
                   let point = engine.eraserCursorPoint {
                    EraserCursorOverlayView(engine: engine, point: point)
                        .allowsHitTesting(false)
                        .zIndex(12)
                }

                LineEndpointHandlesView(engine: engine, preview: engine.strokePreview)
                PolygonVertexHandlesView(engine: engine)

                // 5. Virtual Screen Ruler Overlay
                if engine.ruler.enabled {
                    RulerOverlayView(engine: engine, labelColor: rulerLabelColor)
                }

                PinMarkerOverlayView(engine: engine)

                // Wheel zoom is anchored to the pointer, like CAD editors.
                ScrollWheelMonitor { point, deltaX, deltaY, shift in
                    engine.handleScrollWheel(at: point, deltaX: deltaX, deltaY: deltaY, shift: shift)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if engine.showInlineTextEditor {
                    InlineTextEditorOverlay(engine: engine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(20)
                }
            }
            .coordinateSpace(name: "canvas")
            .onDrop(of: [UTType.fileURL, UTType.image], delegate: CanvasImageDropDelegate(engine: engine))
            .onAppear {
                engine.canvasSize = geo.size
                engine.repositionRulerIfNeeded(windowSize: geo.size)
            }
            .onChange(of: geo.size) { _, size in
                engine.canvasSize = size
                engine.repositionRulerIfNeeded(windowSize: size)
            }
            .clipped()
            .focusable()
            .onKeyPress(.space) {
                engine.isHoldingSpace = true
                return .handled
            }
            .onKeyPress(.escape) {
                engine.cancelTransientInteraction()
                return .handled
            }
        }
    }
}

private struct CanvasImageDropDelegate: DropDelegate {
    let engine: BoardEngine

    func performDrop(info: DropInfo) -> Bool {
        let screenPoint = Point(info.location)
        let providers = info.itemProviders(for: [.fileURL, .image])
        guard !providers.isEmpty else { return false }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let urlValue = item as? URL { url = urlValue }
                    else if let urlValue = item as? NSURL { url = urlValue as URL }
                    else { url = nil }
                    guard let url, let data = try? Data(contentsOf: url) else { return }
                    DispatchQueue.main.async {
                        engine.insertDroppedImage(data, filename: url.lastPathComponent, at: screenPoint)
                    }
                }
                return true
            }

            if let imageType = provider.registeredTypeIdentifiers.first(where: {
                guard let type = UTType($0) else { return false }
                return type.conforms(to: .image) && type != .image
            }) {
                provider.loadDataRepresentation(forTypeIdentifier: imageType) { data, _ in
                    guard let data else { return }
                    let filename = "截圖.\(UTType(imageType)?.preferredFilenameExtension ?? "png")"
                    DispatchQueue.main.async {
                        engine.insertDroppedImage(data, filename: filename, at: screenPoint)
                    }
                }
                return true
            }
        }
        return false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }
}

private struct PinMarkerOverlayView: View {
    @ObservedObject var engine: BoardEngine

    var body: some View {
        ForEach(engine.board.pins ?? []) { pin in
            let pinWorld = pin.resolveWorldPosition(canvasSize: engine.canvasSize)
            let point = VectorMath.worldToScreen(pinWorld, viewport: engine.viewport)
            VStack(spacing: 2) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Color.accentColor, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                Text(pin.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
            }
            .contentShape(Rectangle())
            .onTapGesture { engine.jumpToPin(pin) }
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named("canvas"))
                    .onChanged { engine.updatePinDrag(id: pin.id, at: Point($0.location)) }
                    .onEnded { _ in engine.endPinDrag(id: pin.id) }
            )
            .position(x: point.x, y: point.y)
            .zIndex(15)
            .help("圖釘：\(pin.name)；點擊返回此視角")
        }
    }
}

private struct PolygonVertexHandlesView: View {
    @ObservedObject var engine: BoardEngine

    var body: some View {
        ForEach(engine.selectedObjects.filter { ["triangle", "quadrilateral", "curve"].contains($0.type) }) { object in
            ForEach(Array(object.parsedPoints.enumerated()), id: \.offset) { index, point in
                PolygonVertexHandleView(
                    engine: engine,
                    objectID: object.id,
                    index: index,
                    point: VectorMath.worldToScreen(point, viewport: engine.viewport)
                )
            }
        }
    }
}

private struct EraserCursorOverlayView: View {
    @ObservedObject var engine: BoardEngine
    let point: Point

    var body: some View {
        let diameter = engine.eraserSize * engine.viewport.zoom
        Circle()
            .fill(Color.accentColor.opacity(0.16))
            .overlay(Circle().stroke(Color.accentColor.opacity(0.82), lineWidth: 1.5))
            .overlay(Circle().fill(Color.white.opacity(0.7)).frame(width: 3, height: 3))
            .frame(width: diameter, height: diameter)
            .position(x: point.x, y: point.y)
    }
}

private struct PolygonVertexHandleView: View {
    @ObservedObject var engine: BoardEngine
    let objectID: String
    let index: Int
    let point: Point

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 2)
            .position(x: point.x, y: point.y)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                    .onChanged { engine.updatePolygonVertex(objectID: objectID, index: index, at: Point($0.location)) }
                    .onEnded { _ in engine.endPolygonVertexDrag(objectID: objectID) }
            )
            .help("拖曳調整多邊形頂點")
    }
}

// MARK: - Canvas Background & Grid
struct CanvasBackgroundView: View {
    let theme: BoardTheme
    let gridStyle: GridStyle
    let viewport: ViewportTransform
    var canvasMode: CanvasMode? = .infinite
    var canvasWidth: Double? = nil
    var canvasHeight: Double? = nil

    var body: some View {
        Color(hex: theme.defaultBackgroundColor)
            .overlay(
                GridPatternView(gridStyle: gridStyle, viewport: viewport)
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
        if canvasMode == .fixed, let w = width, let h = height, w > 0, h > 0 {
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

    var body: some View {
        Canvas { context, size in
            let step = 32.0 * viewport.zoom
            guard step > 8 else { return }

            let offsetX = viewport.x.truncatingRemainder(dividingBy: step)
            let offsetY = viewport.y.truncatingRemainder(dividingBy: step)
            let dotColor = Color.white.opacity(0.12)
            let lineColor = Color.white.opacity(0.08)

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
            case .blank:
                break
            }
        }
    }
}

// MARK: - Canvas Objects Rendering
private struct CanvasObjectsLayer: View {
    @ObservedObject var engine: BoardEngine
    @ViewState<CGSize> private var offset = CGSize.zero
    @ViewState<LineEndpointPreview?> private var endpoint: LineEndpointPreview?
    @ViewState<BoardObject?> private var shape: BoardObject?
    var body: some View {
        CanvasObjectsView(engine: engine, selectionOffset: offset, lineEndpoint: endpoint, shapeObject: shape)
            .onReceive(engine.strokePreview.$selectionOffset.removeDuplicates()) { offset = $0 }
            .onReceive(engine.strokePreview.$lineEndpoint.removeDuplicates()) { endpoint = $0 }
            .onReceive(engine.strokePreview.$shapeObject.removeDuplicates()) { shape = $0 }
    }
}

private func dashPattern(for style: String?, zoom: Double) -> [CGFloat] {
    let unit = CGFloat(zoom)
    switch style ?? "solid" {
    case "dashed": return [8 * unit, 6 * unit]
    case "dotted": return [1.5 * unit, 5 * unit]
    case "dashDot": return [8 * unit, 4 * unit, 1.5 * unit, 4 * unit]
    default: return []
    }
}

struct CanvasObjectsView: View {
    @ObservedObject var engine: BoardEngine
    let selectionOffset: CGSize
    let lineEndpoint: LineEndpointPreview?
    let shapeObject: BoardObject?

    var body: some View {
        Canvas { context, size in
            let visibleRect = VectorMath.visibleWorldRect(canvasSize: size, viewport: engine.viewport)

            for obj in engine.objects {
                guard obj.isVisible != false else { continue }
                let isSelected = engine.selectedIds.contains(obj.id)

                // Spatial AABB culling: Skip off-screen objects unless actively selected
                if !isSelected && !VectorMath.intersects(object: obj, worldVisibleRect: visibleRect) {
                    continue
                }

                var renderable = obj
                if let endpoint = lineEndpoint, endpoint.objectID == obj.id {
                    if endpoint.endpoint == .start {
                        renderable.x1 = endpoint.point.x
                        renderable.y1 = endpoint.point.y
                    } else {
                        renderable.x2 = endpoint.point.x
                        renderable.y2 = endpoint.point.y
                    }
                }
                var objectContext = context
                if isSelected {
                    objectContext.translateBy(x: selectionOffset.width, y: selectionOffset.height)
                }
                renderObject(renderable, in: &objectContext, canvasSize: size)
                if isSelected {
                    drawSelectionOutline(for: renderable, in: &context, offset: selectionOffset)
                }
            }
            if let shape = shapeObject {
                renderObject(shape, in: &context, canvasSize: size)
            }
        }
    }

    private func drawSelectionOutline(for object: BoardObject, in context: inout GraphicsContext, offset: CGSize) {
        let zoom = engine.viewport.zoom
        let x = object.x * zoom + engine.viewport.x + offset.width
        let y = object.y * zoom + engine.viewport.y + offset.height
        let rect = CGRect(x: x - 4, y: y - 4, width: max(8, object.width * zoom + 8), height: max(8, object.height * zoom + 8))
        context.stroke(Path(rect), with: .color(.cyan.opacity(0.9)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }

    private func renderObject(_ obj: BoardObject, in context: inout GraphicsContext, canvasSize: CGSize) {
        let zoom = engine.viewport.zoom
        let vx = engine.viewport.x
        let vy = engine.viewport.y

        // Transform object world coordinates to screen
        let screenX = obj.x * zoom + vx
        let screenY = obj.y * zoom + vy
        let screenW = obj.width * zoom
        let screenH = obj.height * zoom

        let strokeColor = Color(hex: obj.strokeColor).opacity(obj.opacity)
        let strokeW = obj.strokeWidth * zoom

        let polygonHasWorldPoints = (obj.type == "triangle" || obj.type == "quadrilateral") && obj.points != nil
        if obj.rotation != 0,
           !["stroke", "highlighter", "paint", "curve", "line", "arrow"].contains(obj.type),
           !polygonHasWorldPoints {
            context.translateBy(x: screenX + screenW / 2, y: screenY + screenH / 2)
            context.rotate(by: .degrees(obj.rotation))
            context.translateBy(x: -(screenX + screenW / 2), y: -(screenY + screenH / 2))
        }

        switch obj.type {
        case "stroke", "highlighter", "paint", "curve":
            let worldPath = BoardPathCache.worldPath(for: obj)
            guard !worldPath.isEmpty else { return }
            let transform = CGAffineTransform(scaleX: zoom, y: zoom)
                .concatenating(CGAffineTransform(translationX: vx, y: vy))
            let screenPath = worldPath.applying(transform)
            let strokeStyle = StrokeStyle(
                lineWidth: strokeW,
                lineCap: .round,
                lineJoin: .round,
                dash: dashPattern(for: obj.lineStyle, zoom: zoom)
            )
            context.stroke(screenPath, with: .color(strokeColor), style: strokeStyle)

        case "rect":
            let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
            if obj.fillColor != "none" {
                fillShape(Path(roundedRect: rect, cornerRadius: 8 * zoom), bounds: rect, object: obj, context: &context)
            }
            let strokeStyle = StrokeStyle(
                lineWidth: strokeW,
                dash: dashPattern(for: obj.lineStyle, zoom: zoom)
            )
            context.stroke(Path(roundedRect: rect, cornerRadius: 8 * zoom), with: .color(strokeColor), style: strokeStyle)

        case "circle", "ellipse":
            let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
            if obj.fillColor != "none" {
                fillShape(Path(ellipseIn: rect), bounds: rect, object: obj, context: &context)
            }
            let strokeStyle = StrokeStyle(
                lineWidth: strokeW,
                dash: dashPattern(for: obj.lineStyle, zoom: zoom)
            )
            context.stroke(Path(ellipseIn: rect), with: .color(strokeColor), style: strokeStyle)

        case "triangle", "quadrilateral", "diamond", "star":
            var path = Path()
            let polygonPoints = obj.parsedPoints
            if (obj.type == "triangle" || obj.type == "quadrilateral"), polygonPoints.count >= 3 {
                for (index, point) in polygonPoints.enumerated() {
                    let screenPoint = CGPoint(x: point.x * zoom + vx, y: point.y * zoom + vy)
                    if index == 0 { path.move(to: screenPoint) } else { path.addLine(to: screenPoint) }
                }
                path.closeSubpath()
            } else if obj.type == "triangle" {
                path.move(to: CGPoint(x: screenX + screenW / 2, y: screenY))
                path.addLine(to: CGPoint(x: screenX, y: screenY + screenH))
                path.addLine(to: CGPoint(x: screenX + screenW, y: screenY + screenH))
                path.closeSubpath()
            } else if obj.type == "diamond" {
                path.move(to: CGPoint(x: screenX + screenW / 2, y: screenY))
                path.addLine(to: CGPoint(x: screenX + screenW, y: screenY + screenH / 2))
                path.addLine(to: CGPoint(x: screenX + screenW / 2, y: screenY + screenH))
                path.addLine(to: CGPoint(x: screenX, y: screenY + screenH / 2))
                path.closeSubpath()
            } else {
                for index in 0..<10 {
                    let angle = Double(index) * .pi / 5 - .pi / 2
                    let radius = index.isMultiple(of: 2) ? 0.5 : 0.22
                    let point = CGPoint(
                        x: screenX + screenW / 2 + screenW * radius * cos(angle),
                        y: screenY + screenH / 2 + screenH * radius * sin(angle)
                    )
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
            }
            if obj.fillColor != "none" {
                fillShape(path, bounds: CGRect(x: screenX, y: screenY, width: screenW, height: screenH), object: obj, context: &context)
            }
            context.stroke(path, with: .color(strokeColor), lineWidth: strokeW)

        case "line":
            let (start, end) = lineEndpoints(for: obj, canvasSize: canvasSize)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let strokeStyle = StrokeStyle(
                lineWidth: strokeW,
                lineCap: .round,
                dash: dashPattern(for: obj.lineStyle, zoom: zoom)
            )
            context.stroke(path, with: .color(strokeColor), style: strokeStyle)

        case "arrow":
            let (start, end) = lineEndpoints(for: obj, canvasSize: canvasSize)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let lineStyle = StrokeStyle(lineWidth: strokeW, lineCap: .round, dash: dashPattern(for: obj.lineStyle, zoom: zoom))
            context.stroke(path, with: .color(strokeColor), style: lineStyle)

            // Arrow head
            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLen = (obj.arrowHeadLength ?? 16.0) * zoom
            let headHalfWidth = (obj.arrowHeadWidth ?? 10.0) * zoom / 2
            let baseX = end.x - headLen * cos(angle)
            let baseY = end.y - headLen * sin(angle)
            var head = Path()
            head.move(to: end)
            head.addLine(to: CGPoint(x: baseX - headHalfWidth * sin(angle), y: baseY + headHalfWidth * cos(angle)))
            head.addLine(to: CGPoint(x: baseX + headHalfWidth * sin(angle), y: baseY - headHalfWidth * cos(angle)))
            head.closeSubpath()
            context.fill(head, with: .color(strokeColor))

        case "sticky":
            let style = obj.stickyStyle ?? .classic
            let cornerRadius: CGFloat = (style == .soft ? 18 : (style == .notebook ? 10 : 8)) * CGFloat(zoom)
            let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)

            // Paper drop shadow
            let shadowOffset: CGFloat = (style == .soft ? 6 : 4) * CGFloat(zoom)
            let shadowRect = rect.offsetBy(dx: shadowOffset, dy: shadowOffset)
            context.fill(Path(roundedRect: shadowRect, cornerRadius: cornerRadius), with: .color(Color.black.opacity(0.18 * obj.opacity)))

            // Paper body
            context.fill(Path(roundedRect: rect, cornerRadius: cornerRadius), with: .color(Color(hex: obj.fillColor).opacity(obj.opacity * obj.fillOpacity)))
            context.stroke(Path(roundedRect: rect, cornerRadius: cornerRadius), with: .color(Color.black.opacity(0.12 * obj.opacity)), lineWidth: 1)

            // Style-specific decorations (A16)
            switch style {
            case .classic:
                let foldSize: CGFloat = 16 * CGFloat(zoom)
                var fold = Path()
                fold.move(to: CGPoint(x: rect.maxX - foldSize, y: rect.maxY))
                fold.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - foldSize))
                fold.addLine(to: CGPoint(x: rect.maxX - foldSize, y: rect.maxY - foldSize))
                fold.closeSubpath()
                context.fill(fold, with: .color(Color.black.opacity(0.12 * obj.opacity)))
            case .washi:
                let tapeW: CGFloat = min(72 * CGFloat(zoom), rect.width * 0.45)
                let tapeH: CGFloat = 12 * CGFloat(zoom)
                let tapeRect = CGRect(x: rect.midX - tapeW / 2, y: rect.minY - tapeH / 3, width: tapeW, height: tapeH)
                context.fill(Path(roundedRect: tapeRect, cornerRadius: 2), with: .color(Color(hex: "#f472b6").opacity(0.85 * obj.opacity)))
            case .cat:
                let pawFont = Font.system(size: 14 * CGFloat(zoom))
                let pawText = context.resolve(Text("🐾").font(pawFont))
                context.draw(pawText, in: CGRect(x: rect.maxX - 24 * CGFloat(zoom), y: rect.minY + 6 * CGFloat(zoom), width: 18 * CGFloat(zoom), height: 18 * CGFloat(zoom)))
            case .notebook:
                let holeRadius: CGFloat = 2.5 * CGFloat(zoom)
                let holeCount = 5
                let step = rect.width / CGFloat(holeCount + 1)
                for i in 1...holeCount {
                    let cx = rect.minX + step * CGFloat(i)
                    let cy = rect.minY + 8 * CGFloat(zoom)
                    let holeRect = CGRect(x: cx - holeRadius, y: cy - holeRadius, width: holeRadius * 2, height: holeRadius * 2)
                    context.fill(Path(ellipseIn: holeRect), with: .color(Color.black.opacity(0.35 * obj.opacity)))
                }
            case .grid:
                let gridSpacing: CGFloat = 14 * CGFloat(zoom)
                var gridPath = Path()
                var gx = rect.minX + gridSpacing
                while gx < rect.maxX {
                    gridPath.move(to: CGPoint(x: gx, y: rect.minY + 4))
                    gridPath.addLine(to: CGPoint(x: gx, y: rect.maxY - 4))
                    gx += gridSpacing
                }
                var gy = rect.minY + gridSpacing
                while gy < rect.maxY {
                    gridPath.move(to: CGPoint(x: rect.minX + 4, y: gy))
                    gridPath.addLine(to: CGPoint(x: rect.maxX - 4, y: gy))
                    gy += gridSpacing
                }
                context.stroke(gridPath, with: .color(Color.black.opacity(0.06 * obj.opacity)), lineWidth: 0.5)
            case .soft:
                let innerRect = rect.insetBy(dx: 3 * CGFloat(zoom), dy: 3 * CGFloat(zoom))
                context.stroke(Path(roundedRect: innerRect, cornerRadius: cornerRadius - 2), with: .color(Color.white.opacity(0.4 * obj.opacity)), lineWidth: 1)
            }

            // Sticky text
            if let text = obj.text, !text.isEmpty {
                let textFont = Font.custom(obj.fontFamily ?? "PingFang TC", size: (obj.fontSize ?? 14) * zoom)
                let resolved = context.resolve(renderText(obj, fallback: text, font: textFont, color: Color(hex: obj.strokeColor.isEmpty ? "#1f2937" : obj.strokeColor), weight: .medium))
                let contentRect = rect.insetBy(dx: 14 * zoom, dy: (style == .notebook || style == .washi ? 18 : 14) * zoom)
                context.draw(resolved, in: contentRect)
            }

            // Overflow indicator badge if text exceeds boundary (A16)
            if engine.isStickyTextOverflowing(object: obj) {
                let badgeSize: CGFloat = 18 * CGFloat(zoom)
                let badgeRect = CGRect(x: rect.maxX - badgeSize - 4 * CGFloat(zoom), y: rect.maxY - badgeSize - 4 * CGFloat(zoom), width: badgeSize, height: badgeSize)
                context.fill(Path(ellipseIn: badgeRect), with: .color(Color(hex: "#ef4444").opacity(0.9 * obj.opacity)))
                let badgeText = context.resolve(Text("⋯").font(Font.system(size: 11 * CGFloat(zoom), weight: .bold)).foregroundColor(.white))
                context.draw(badgeText, in: badgeRect)
            }

        case "text":
            if let text = obj.text {
                let rect = CGRect(x: screenX, y: screenY, width: max(screenW, 300 * zoom), height: max(screenH, 50 * zoom))
                let textFont = Font.custom(obj.fontFamily ?? "PingFang TC", size: (obj.fontSize ?? 22) * zoom)
                let resolved = context.resolve(renderText(obj, fallback: text, font: textFont, color: strokeColor, weight: .semibold))
                context.draw(resolved, in: rect)
            }

        case "image":
            if let base64 = obj.imageUrl,
               let nsImg = CanvasImageCache.image(for: base64) {
                let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
                context.opacity = obj.opacity
                context.draw(Image(nsImage: nsImg), in: rect)
            }

        default:
            break
        }
    }

    private func fillShape(_ path: Path, bounds: CGRect, object: BoardObject, context: inout GraphicsContext) {
        if let start = object.fillGradientStart, let end = object.fillGradientEnd {
            let gradient = Gradient(colors: [Color(hex: start).opacity(object.opacity * object.fillOpacity), Color(hex: end).opacity(object.opacity * object.fillOpacity)])
            context.fill(path, with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: bounds.minX, y: bounds.midY),
                endPoint: CGPoint(x: bounds.maxX, y: bounds.midY)
            ))
        } else {
            context.fill(path, with: .color(Color(hex: object.fillColor).opacity(object.opacity * object.fillOpacity)))
        }
    }

    private func renderText(_ object: BoardObject, fallback: String, font: Font, color: Color, weight: Font.Weight) -> Text {
        let savedSpans = object.richTextSpans ?? []
        let spans = savedSpans.isEmpty ? [
            TextSpan(text: fallback, isBold: object.isBold, isItalic: object.isItalic,
                     isUnderline: object.isUnderline, isStrikethrough: object.isStrikethrough,
                     color: object.strokeColor, highlightColor: object.highlightColor)
        ] : savedSpans
        var attributed = AttributedString()
        for span in spans {
            let runColor = span.color.map { Color(hex: $0) } ?? color
            var run = AttributedString(span.text)
            run.font = canvasNSFont(object: object, bold: span.isBold == true, italic: span.isItalic == true, fallback: font, weight: weight)
            run.foregroundColor = runColor.opacity(object.opacity)
            run.backgroundColor = span.highlightColor.map { Color(hex: $0).opacity(0.35 * object.opacity) }
            run.underlineStyle = span.isUnderline == true ? .single : nil
            run.strikethroughStyle = span.isStrikethrough == true ? .single : nil
            let paragraph = NSMutableParagraphStyle()
            switch object.align {
            case "center": paragraph.alignment = .center
            case "right": paragraph.alignment = .right
            default: paragraph.alignment = .left
            }
            run.paragraphStyle = paragraph
            attributed.append(run)
        }
        return Text(attributed)
    }

    private func canvasNSFont(object: BoardObject, bold: Bool, italic: Bool, fallback: Font, weight: Font.Weight) -> Font {
        let size = CGFloat((object.fontSize ?? 22) * engine.viewport.zoom)
        guard let base = NSFont(name: object.fontFamily ?? "PingFang TC", size: size) else {
            return fallback.weight(bold ? .bold : weight)
        }
        var styled = base
        if bold { styled = NSFontManager.shared.convert(styled, toHaveTrait: .boldFontMask) }
        if italic { styled = NSFontManager.shared.convert(styled, toHaveTrait: .italicFontMask) }
        return Font(styled)
    }

    private func lineEndpoints(for object: BoardObject, canvasSize: CGSize) -> (CGPoint, CGPoint) {
        let zoom = engine.viewport.zoom
        let start = CGPoint(x: (object.x1 ?? object.x) * zoom + engine.viewport.x, y: (object.y1 ?? object.y) * zoom + engine.viewport.y)
        let end = CGPoint(x: (object.x2 ?? (object.x + object.width)) * zoom + engine.viewport.x, y: (object.y2 ?? (object.y + object.height)) * zoom + engine.viewport.y)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return (start, end) }
        let ux = dx / length
        let uy = dy / length
        let extensionLength = hypot(canvasSize.width, canvasSize.height) * 2

        switch object.extensionMode ?? .none {
        case .none: return (start, end)
        case .start: return (CGPoint(x: start.x - ux * extensionLength, y: start.y - uy * extensionLength), end)
        case .end: return (start, CGPoint(x: end.x + ux * extensionLength, y: end.y + uy * extensionLength))
        case .both:
            return (
                CGPoint(x: start.x - ux * extensionLength, y: start.y - uy * extensionLength),
                CGPoint(x: end.x + ux * extensionLength, y: end.y + uy * extensionLength)
            )
        }
    }
}

private struct LineEndpointHandlesView: View {
    @ObservedObject var engine: BoardEngine
    @ObservedObject var preview: StrokePreviewStore

    private var selectedLine: BoardObject? {
        engine.objects.reversed().first {
            engine.selectedIds.contains($0.id) && ($0.type == "line" || $0.type == "arrow")
        }
    }

    var body: some View {
        if let line = selectedLine {
            let start = endpointPosition(for: line, endpoint: .start)
            let end = endpointPosition(for: line, endpoint: .end)
            endpointHandle(at: start, objectID: line.id, endpoint: .start)
            endpointHandle(at: end, objectID: line.id, endpoint: .end)
        }
    }

    private func endpointPosition(for line: BoardObject, endpoint: LineEndpoint) -> CGPoint {
        let previewPoint = preview.lineEndpoint.flatMap {
            $0.objectID == line.id && $0.endpoint == endpoint ? $0.point : nil
        }
        let x = previewPoint?.x ?? (endpoint == .start ? (line.x1 ?? line.x) : (line.x2 ?? line.x + line.width))
        let y = previewPoint?.y ?? (endpoint == .start ? (line.y1 ?? line.y) : (line.y2 ?? line.y + line.height))
        return CGPoint(x: x * engine.viewport.zoom + engine.viewport.x, y: y * engine.viewport.zoom + engine.viewport.y)
    }

    private func endpointHandle(at point: CGPoint, objectID: String, endpoint: LineEndpoint) -> some View {
        Circle()
            .fill(endpoint == .start ? Color.blue : Color.cyan)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 3)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                    .onChanged { value in
                        engine.updateLineEndpointDrag(objectID: objectID, endpoint: endpoint, at: Point(value.location))
                    }
                    .onEnded { _ in engine.endLineEndpointDrag() }
            )
            .help(endpoint == .start ? "拖曳 A 點調整直線起點" : "拖曳 B 點調整直線終點")
    }
}

private enum CanvasImageCache {
    private static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        cache.totalCostLimit = 256 * 1024 * 1024
        return cache
    }()

    static func image(for dataURL: String) -> NSImage? {
        let key = "\(dataURL.count):\(dataURL.hashValue)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let raw = dataURL.components(separatedBy: ",").last,
              let data = Data(base64Encoded: raw),
              let image = NSImage(data: data) else { return nil }
        images.setObject(image, forKey: key, cost: data.count)
        return image
    }
}

// MARK: - In-flight Stroke & Shape Recognition Preview
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

// MARK: - Gesture Surface View
// MARK: - Color Hex Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 134, 239, 172)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Selection & Transform Handles Overlay (A06)
struct SelectionOverlayView: View {
    @ObservedObject var engine: BoardEngine

    var body: some View {
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

            // 2. Draw Selection Bounding Box & 8 Handles & Rotation Handle
            if !engine.selectedIds.isEmpty, let bounds = engine.selectionBoundingBox {
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
        .allowsHitTesting(false)
    }
}
