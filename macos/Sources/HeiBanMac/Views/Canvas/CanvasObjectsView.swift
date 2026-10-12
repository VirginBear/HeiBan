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
                // 線段／箭頭只有AB控制；不能在另一個渲染層再畫回矩形外框。
                if isSelected && !["line", "arrow"].contains(obj.type) {
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

        case "arc":
            let radius = (obj.arcRadius ?? (obj.width / 2.0)) * zoom
            let center = CGPoint(x: screenX + screenW / 2.0, y: screenY + screenH / 2.0)
            let startDeg = obj.arcStartAngle ?? 0.0
            let sweepDeg = obj.arcSweepAngle ?? 360.0
            let endDeg = startDeg + sweepDeg

            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(degrees: startDeg),
                endAngle: Angle(degrees: endDeg),
                clockwise: sweepDeg < 0
            )

            let strokeStyle = StrokeStyle(
                lineWidth: strokeW,
                lineCap: .round,
                dash: dashPattern(for: obj.lineStyle, zoom: zoom)
            )
            context.stroke(path, with: .color(strokeColor), style: strokeStyle)

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

        case "tape":
            let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
            let isRevealed = obj.isRevealed ?? false
            let tapeColor = Color(hex: obj.strokeColor.isEmpty || obj.strokeColor == "#86efac" ? "#f59e0b" : obj.strokeColor)

            if isRevealed {
                // Ghost/revealed state: transparent dashed outline with soft tinted background, revealing underlying content
                context.fill(Path(roundedRect: rect, cornerRadius: 4 * zoom), with: .color(tapeColor.opacity(0.12)))
                let dashStyle = StrokeStyle(lineWidth: 1.5 * zoom, dash: [5 * zoom, 3 * zoom])
                context.stroke(Path(roundedRect: rect, cornerRadius: 4 * zoom), with: .color(tapeColor.opacity(0.6)), style: dashStyle)
            } else {
                // Obscured state: pleasant washi tape look with diagonal stripes
                context.fill(Path(roundedRect: rect, cornerRadius: 4 * zoom), with: .color(tapeColor.opacity(0.96 * obj.opacity)))
                let clipPath = Path(roundedRect: rect, cornerRadius: 4 * zoom)
                var patternPath = Path()
                let step: CGFloat = 16.0 * CGFloat(zoom)
                for x in stride(from: -rect.height, to: rect.width + rect.height, by: step) {
                    patternPath.move(to: CGPoint(x: rect.minX + x, y: rect.minY))
                    patternPath.addLine(to: CGPoint(x: rect.minX + x + rect.height, y: rect.maxY))
                }
                var subContext = context
                subContext.clip(to: clipPath)
                subContext.stroke(patternPath, with: .color(Color.white.opacity(0.25)), lineWidth: 3.0 * zoom)
                context.stroke(Path(roundedRect: rect, cornerRadius: 4 * zoom), with: .color(tapeColor.opacity(0.85)), lineWidth: 1.2 * zoom)
            }

        case "rounded_rect":
            let cornerR = (obj.cornerRadius ?? 16.0) * zoom
            let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
            if obj.fillColor != "none" {
                fillShape(Path(roundedRect: rect, cornerRadius: cornerR), bounds: rect, object: obj, context: &context)
            }
            let strokeStyle = StrokeStyle(
                lineWidth: strokeW,
                dash: dashPattern(for: obj.lineStyle, zoom: zoom)
            )
            context.stroke(Path(roundedRect: rect, cornerRadius: cornerR), with: .color(strokeColor), style: strokeStyle)

        case "polygon":
            let sides = obj.polygonSides ?? 5
            let centerWorld = Point(x: obj.x + obj.width / 2.0, y: obj.y + obj.height / 2.0)
            let radiusWorld = min(obj.width, obj.height) / 2.0
            let vertices = VectorMath.computePolygonVertices(center: centerWorld, radius: radiusWorld, sides: sides, rotation: obj.rotation)
            var polyPath = Path()
            for (idx, v) in vertices.enumerated() {
                let sPt = CGPoint(x: v.x * zoom + vx, y: v.y * zoom + vy)
                if idx == 0 { polyPath.move(to: sPt) } else { polyPath.addLine(to: sPt) }
            }
            polyPath.closeSubpath()
            let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
            if obj.fillColor != "none" {
                fillShape(polyPath, bounds: rect, object: obj, context: &context)
            }
            let strokeStyle = StrokeStyle(lineWidth: strokeW, dash: dashPattern(for: obj.lineStyle, zoom: zoom))
            context.stroke(polyPath, with: .color(strokeColor), style: strokeStyle)

        case "connector":
            let (start, end) = lineEndpoints(for: obj, canvasSize: canvasSize)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let strokeStyle = StrokeStyle(lineWidth: strokeW, lineCap: .round, dash: dashPattern(for: obj.lineStyle, zoom: zoom))
            context.stroke(path, with: .color(strokeColor), style: strokeStyle)
            let dotRadius: CGFloat = max(3.5 * CGFloat(zoom), strokeW * 0.9)
            context.fill(Path(ellipseIn: CGRect(x: start.x - dotRadius, y: start.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(strokeColor))
            context.fill(Path(ellipseIn: CGRect(x: end.x - dotRadius, y: end.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(strokeColor))

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

        case "frame":
            renderFrame(obj: obj, screenX: screenX, screenY: screenY, screenW: screenW, screenH: screenH, zoom: zoom, strokeColor: strokeColor, context: &context)

        case "mindmap":
            renderMindMap(obj: obj, screenX: screenX, screenY: screenY, zoom: zoom, strokeColor: strokeColor, context: &context)

        case "table":
            renderTable(obj: obj, screenX: screenX, screenY: screenY, zoom: zoom, strokeColor: strokeColor, context: &context)

        case "formula":
            renderFormula(obj: obj, screenX: screenX, screenY: screenY, zoom: zoom, strokeColor: strokeColor, context: &context)

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

    private func renderFrame(
        obj: BoardObject,
        screenX: Double,
        screenY: Double,
        screenW: Double,
        screenH: Double,
        zoom: Double,
        strokeColor: Color,
        context: inout GraphicsContext
    ) {
        let rect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
        let cornerR = 8.0 * zoom
        let path = Path(roundedRect: rect, cornerRadius: cornerR)

        if obj.fillColor != "none" {
            context.fill(path, with: .color(Color(hex: obj.fillColor).opacity(obj.opacity * obj.fillOpacity)))
        }

        let borderStyle = StrokeStyle(
            lineWidth: max(1.5, obj.strokeWidth * zoom),
            dash: [6.0 * zoom, 4.0 * zoom]
        )
        context.stroke(path, with: .color(strokeColor.opacity(0.85)), style: borderStyle)

        let titleText = obj.frameTitle ?? "畫框"
        let tabHeight = 24.0 * zoom
        let tabWidth = min(screenW, max(80.0 * zoom, Double(titleText.count * 14) * zoom + 20.0 * zoom))
        let tabRect = CGRect(x: screenX, y: screenY - tabHeight, width: tabWidth, height: tabHeight)
        let tabPath = Path(roundedRect: tabRect, cornerRadius: 4.0 * zoom)
        context.fill(tabPath, with: .color(Color(hex: "#1e293b").opacity(0.9)))
        context.stroke(tabPath, with: .color(strokeColor.opacity(0.85)), lineWidth: 1.0 * zoom)

        let font = Font.system(size: 11.0 * zoom, weight: .bold)
        let resolved = context.resolve(Text(titleText).font(font).foregroundColor(.white))
        context.draw(resolved, in: tabRect)
    }

    private func renderMindMap(
        obj: BoardObject,
        screenX: Double,
        screenY: Double,
        zoom: Double,
        strokeColor: Color,
        context: inout GraphicsContext
    ) {
        guard let data = obj.mindMapData else { return }
        let nodeDict = data.nodes
        let nodeW = 120.0 * zoom
        let nodeH = 34.0 * zoom

        for node in data.nodes.values {
            guard node.isCollapsed != true else { continue }
            let pX = screenX + (node.relativeX ?? 0.0) * zoom
            let pY = screenY + (node.relativeY ?? 0.0) * zoom
            let pOut = CGPoint(x: pX + nodeW, y: pY + nodeH / 2.0)

            for childId in node.childrenIds {
                guard let child = nodeDict[childId] else { continue }
                let cX = screenX + (child.relativeX ?? 0.0) * zoom
                let cY = screenY + (child.relativeY ?? 0.0) * zoom
                let cIn = CGPoint(x: cX, y: cY + nodeH / 2.0)

                var curve = Path()
                curve.move(to: pOut)
                let midX = (pOut.x + cIn.x) / 2.0
                curve.addCurve(to: cIn, control1: CGPoint(x: midX, y: pOut.y), control2: CGPoint(x: midX, y: cIn.y))

                let lineColor = child.color.map { Color(hex: $0) } ?? strokeColor
                context.stroke(curve, with: .color(lineColor.opacity(0.7)), lineWidth: 2.0 * zoom)
            }
        }

        for node in data.nodes.values {
            let nX = screenX + (node.relativeX ?? 0.0) * zoom
            let nY = screenY + (node.relativeY ?? 0.0) * zoom
            let nRect = CGRect(x: nX, y: nY, width: nodeW, height: nodeH)
            let nPath = Path(roundedRect: nRect, cornerRadius: 8.0 * zoom)

            let nodeColor = node.color.map { Color(hex: $0) } ?? Color(hex: "#6366f1")
            context.fill(nPath, with: .color(nodeColor.opacity(0.22)))
            context.stroke(nPath, with: .color(nodeColor), lineWidth: 1.5 * zoom)

            let font = Font.system(size: 13.0 * zoom, weight: .medium)
            let resolved = context.resolve(Text(node.text).font(font).foregroundColor(.white))
            context.draw(resolved, in: nRect)

            if node.isCollapsed == true && !node.childrenIds.isEmpty {
                let badgeR = 7.0 * zoom
                let badgeCenter = CGPoint(x: nRect.maxX, y: nRect.midY)
                let badgeRect = CGRect(x: badgeCenter.x - badgeR, y: badgeCenter.y - badgeR, width: badgeR * 2, height: badgeR * 2)
                context.fill(Path(ellipseIn: badgeRect), with: .color(nodeColor))
                let badgeTxt = context.resolve(Text("+").font(Font.system(size: 9.0 * zoom, weight: .bold)).foregroundColor(.white))
                context.draw(badgeTxt, in: badgeRect)
            }
        }
    }

    private func renderTable(
        obj: BoardObject,
        screenX: Double,
        screenY: Double,
        zoom: Double,
        strokeColor: Color,
        context: inout GraphicsContext
    ) {
        guard let data = obj.tableData else { return }

        var curY = screenY
        for r in 0..<data.rowCount {
            let rowH = (r < data.rowHeights.count ? data.rowHeights[r] : 36.0) * zoom
            var curX = screenX
            for c in 0..<data.colCount {
                let colW = (c < data.colWidths.count ? data.colWidths[c] : 120.0) * zoom
                let cell = data.cells.first(where: { $0.row == r && $0.col == c })

                let rowSpan = max(1, cell?.rowSpan ?? 1)
                let colSpan = max(1, cell?.colSpan ?? 1)

                var spanW = colW
                if colSpan > 1 {
                    spanW = (c..<(c + colSpan)).map { ($0 < data.colWidths.count ? data.colWidths[$0] : 120.0) * zoom }.reduce(0, +)
                }
                var spanH = rowH
                if rowSpan > 1 {
                    spanH = (r..<(r + rowSpan)).map { ($0 < data.rowHeights.count ? data.rowHeights[$0] : 36.0) * zoom }.reduce(0, +)
                }

                let cellRect = CGRect(x: curX, y: curY, width: spanW, height: spanH)

                if let cell = cell {
                    let bgHex = cell.bgColor ?? (cell.isHeader == true ? "#334155" : (r % 2 == 1 ? "#1e293b" : "#0f172a"))
                    context.fill(Path(cellRect), with: .color(Color(hex: bgHex).opacity(0.85 * obj.opacity)))
                    context.stroke(Path(cellRect), with: .color(strokeColor.opacity(0.3)), lineWidth: 1.0 * zoom)

                    if !cell.text.isEmpty {
                        let txtColor = cell.textColor.map { Color(hex: $0) } ?? Color.white
                        let isHeader = cell.isHeader == true
                        let font = Font.system(size: (isHeader ? 13.0 : 12.0) * zoom, weight: isHeader ? .bold : .regular)
                        let resolved = context.resolve(Text(cell.text).font(font).foregroundColor(txtColor))
                        context.draw(resolved, in: cellRect.insetBy(dx: 6.0 * zoom, dy: 4.0 * zoom))
                    }
                }
                curX += colW
            }
            curY += rowH
        }
    }

    private func renderFormula(
        obj: BoardObject,
        screenX: Double,
        screenY: Double,
        zoom: Double,
        strokeColor: Color,
        context: inout GraphicsContext
    ) {
        let latex = obj.latex ?? ""
        let baseSize = (obj.formulaFontSize ?? 24.0) * zoom
        let layoutResult = LaTeXParserEngine.layout(latex: latex, baseFontSize: baseSize)

        for line in layoutResult.lines {
            let lRect = CGRect(
                x: screenX + line.x,
                y: screenY + line.y,
                width: line.width,
                height: max(1.0, line.height)
            )
            context.fill(Path(lRect), with: .color(strokeColor))
        }

        for glyph in layoutResult.glyphs {
            let font = Font.system(size: glyph.fontSize, weight: glyph.isItalic ? .regular : .medium, design: glyph.isItalic ? .serif : .default)
            let resolved = context.resolve(Text(glyph.text).font(font).foregroundColor(strokeColor))
            context.draw(resolved, at: CGPoint(x: screenX + glyph.x, y: screenY + glyph.y), anchor: .topLeading)
        }
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
