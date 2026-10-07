import SwiftUI
import AppKit
import HeiBanCore

struct CanvasObjectsView: View {
    @ObservedObject var engine: BoardEngine
    let selectionOffset: CGSize
    let lineEndpoint: LineEndpointPreview?
    let shapeObject: BoardObject?

    var body: some View {
        Canvas { context, size in
            let visibleRect = VectorMath.visibleWorldRect(canvasSize: size, viewport: engine.viewport)

            for obj in engine.currentPageObjects {
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

struct LineEndpointHandlesView: View {
    @ObservedObject var engine: BoardEngine
    @ObservedObject var preview: StrokePreviewStore

    private var selectedLine: BoardObject? {
        engine.currentPageObjects.reversed().first {
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

enum CanvasImageCache {
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
