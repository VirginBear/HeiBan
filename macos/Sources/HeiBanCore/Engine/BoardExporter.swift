import Foundation
import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif

public struct PaperPresets {
    public static let a4 = CGSize(width: 595.28, height: 841.89) // 210 x 297 mm
    public static let a3 = CGSize(width: 841.89, height: 1190.55) // 297 x 420 mm
    public static let widescreen = CGSize(width: 1920.0, height: 1080.0)
    public static let standard43 = CGSize(width: 1440.0, height: 1080.0)
}

public enum ExportScope: Equatable {
    case selection
    case allObjects
    case fixedCanvas
    case customRegion(CGRect)
}

public struct PDFImportResult {
    public let canRestoreOriginalObjects: Bool
    public let isExternalPDF: Bool
    public let document: HeiBanDocument?
    public let importedBackgroundObject: BoardObject?

    public init(canRestoreOriginalObjects: Bool, isExternalPDF: Bool, document: HeiBanDocument?, importedBackgroundObject: BoardObject?) {
        self.canRestoreOriginalObjects = canRestoreOriginalObjects
        self.isExternalPDF = isExternalPDF
        self.document = document
        self.importedBackgroundObject = importedBackgroundObject
    }
}

public final class BoardExporter {
    public let document: HeiBanDocument

    public init(document: HeiBanDocument) {
        self.document = document
    }

    public func computeScopeBounds(scope: ExportScope, selectedIds: Set<String>) -> CGRect {
        switch scope {
        case .selection:
            let selected = document.objects.filter { selectedIds.contains($0.id) && $0.isVisible != false }
            return VectorMath.selectionBounds(for: selected) ?? CGRect(x: 0, y: 0, width: 800, height: 600)

        case .allObjects:
            let visible = document.objects.filter { $0.isVisible != false }
            return VectorMath.selectionBounds(for: visible) ?? CGRect(x: 0, y: 0, width: 800, height: 600)

        case .fixedCanvas:
            let w = document.board.canvasWidth ?? 1920.0
            let h = document.board.canvasHeight ?? 1080.0
            return CGRect(x: 0, y: 0, width: w, height: h)

        case .customRegion(let rect):
            return rect
        }
    }

    public func exportSVG(scope: ExportScope, selectedIds: Set<String>) throws -> String {
        let bounds = computeScopeBounds(scope: scope, selectedIds: selectedIds)
        let filteredObjects: [BoardObject]
        switch scope {
        case .selection:
            filteredObjects = document.objects.filter { selectedIds.contains($0.id) && $0.isVisible != false }
        default:
            filteredObjects = document.objects.filter { $0.isVisible != false }
        }

        var svg = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        svg += "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(bounds.minX) \(bounds.minY) \(bounds.width) \(bounds.height)\" width=\"\(bounds.width)\" height=\"\(bounds.height)\">\n"
        svg += "  <rect x=\"\(bounds.minX)\" y=\"\(bounds.minY)\" width=\"\(bounds.width)\" height=\"\(bounds.height)\" fill=\"\(document.board.backgroundColor)\" />\n"

        for obj in filteredObjects.sorted(by: { $0.zIndex < $1.zIndex }) {
            let stroke = obj.strokeColor
            let strokeW = obj.strokeWidth
            let fill = obj.fillColor == "none" ? "none" : obj.fillColor
            let opacity = obj.opacity
            let dashAttr = obj.lineStyle == "dashed" ? " stroke-dasharray=\"8,8\"" : ""

            switch obj.type {
            case "rect":
                svg += "  <rect x=\"\(obj.x)\" y=\"\(obj.y)\" width=\"\(obj.width)\" height=\"\(obj.height)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\" fill=\"\(fill)\" opacity=\"\(opacity)\"\(dashAttr) />\n"

            case "circle":
                let rx = obj.width / 2.0
                let ry = obj.height / 2.0
                let cx = obj.x + rx
                let cy = obj.y + ry
                svg += "  <ellipse cx=\"\(cx)\" cy=\"\(cy)\" rx=\"\(rx)\" ry=\"\(ry)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\" fill=\"\(fill)\" opacity=\"\(opacity)\"\(dashAttr) />\n"

            case "stroke":
                if let ptsJSON = obj.points, let ptsData = ptsJSON.data(using: .utf8),
                   let pts = try? JSONDecoder().decode([Point].self, from: ptsData), !pts.isEmpty {
                    var d = "M \(pts[0].x) \(pts[0].y)"
                    for p in pts.dropFirst() {
                        d += " L \(p.x) \(p.y)"
                    }
                    svg += "  <path d=\"\(d)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\" fill=\"none\" opacity=\"\(opacity)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"\(dashAttr) />\n"
                }

            case "text":
                svg += "  <text x=\"\(obj.x)\" y=\"\(obj.y + 24)\" fill=\"\(stroke)\" opacity=\"\(opacity)\" font-family=\"\(obj.fontFamily ?? "PingFang TC")\" font-size=\"\(obj.fontSize ?? 24)\">\n"
                if let spans = obj.richTextSpans, !spans.isEmpty {
                    for span in spans {
                        var style = ""
                        if span.isBold == true { style += " font-weight=\"bold\"" }
                        if span.isItalic == true { style += " font-style=\"italic\"" }
                        if span.isUnderline == true { style += " text-decoration=\"underline\"" }
                        let spanColor = span.color ?? stroke
                        svg += "    <tspan fill=\"\(spanColor)\"\(style)>\(escapeXML(span.text))</tspan>\n"
                    }
                } else if let txt = obj.text {
                    svg += "    \(escapeXML(txt))\n"
                }
                svg += "  </text>\n"

            case "sticky":
                svg += "  <g opacity=\"\(opacity)\">\n"
                svg += "    <rect x=\"\(obj.x)\" y=\"\(obj.y)\" width=\"\(obj.width)\" height=\"\(obj.height)\" rx=\"8\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\" fill=\"\(fill)\" />\n"
                if let txt = obj.text {
                    svg += "    <text x=\"\(obj.x + 12)\" y=\"\(obj.y + 28)\" fill=\"\(stroke)\" font-size=\"14\">\(escapeXML(txt))</text>\n"
                }
                svg += "  </g>\n"

            default:
                break
            }
        }

        svg += "</svg>\n"
        return svg
    }

    public func exportPDF(scope: ExportScope, selectedIds: Set<String>, paperSize: CGSize = PaperPresets.a4, embedEditableData: Bool = true) throws -> Data {
        let bounds = computeScopeBounds(scope: scope, selectedIds: selectedIds)
        let filteredObjects: [BoardObject]
        switch scope {
        case .selection:
            filteredObjects = document.objects.filter { selectedIds.contains($0.id) && $0.isVisible != false }
        default:
            filteredObjects = document.objects.filter { $0.isVisible != false }
        }

        let pdfData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: paperSize)

        var auxInfo: [CFString: Any] = [
            kCGPDFContextCreator: "HeiBan Blackboard Vector Engine",
            kCGPDFContextAuthor: "HeiBan",
            kCGPDFContextSubject: "HeiBan Document"
        ]

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, auxInfo as CFDictionary) else {
            throw NSError(domain: "HeiBanPDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "無法建立 PDF Context"])
        }

        context.beginPage(mediaBox: &mediaBox)

        let margin: Double = 24.0
        let targetW = max(10.0, Double(paperSize.width) - margin * 2)
        let targetH = max(10.0, Double(paperSize.height) - margin * 2)
        let scale = min(targetW / max(1.0, Double(bounds.width)), targetH / max(1.0, Double(bounds.height)))

        context.saveGState()
        context.translateBy(x: margin, y: Double(paperSize.height) - margin)
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)

        if let bgColor = parseColor(document.board.backgroundColor) {
            context.setFillColor(bgColor)
            context.fill(bounds)
        }

        for obj in filteredObjects.sorted(by: { $0.zIndex < $1.zIndex }) {
            context.saveGState()
            context.setAlpha(obj.opacity)

            if let strokeColor = parseColor(obj.strokeColor) {
                context.setStrokeColor(strokeColor)
            }
            context.setLineWidth(obj.strokeWidth)
            if obj.lineStyle == "dashed" {
                context.setLineDash(phase: 0, lengths: [8, 8])
            }

            switch obj.type {
            case "rect":
                let r = CGRect(x: obj.x, y: obj.y, width: obj.width, height: obj.height)
                if obj.fillColor != "none", let fillColor = parseColor(obj.fillColor) {
                    context.setFillColor(fillColor)
                    context.fill(r)
                }
                context.stroke(r)

            case "circle":
                let r = CGRect(x: obj.x, y: obj.y, width: obj.width, height: obj.height)
                if obj.fillColor != "none", let fillColor = parseColor(obj.fillColor) {
                    context.setFillColor(fillColor)
                    context.fillEllipse(in: r)
                }
                context.strokeEllipse(in: r)

            case "stroke":
                if let ptsJSON = obj.points, let ptsData = ptsJSON.data(using: .utf8),
                   let pts = try? JSONDecoder().decode([Point].self, from: ptsData), pts.count >= 2 {
                    context.beginPath()
                    context.move(to: CGPoint(x: pts[0].x, y: pts[0].y))
                    for p in pts.dropFirst() {
                        context.addLine(to: CGPoint(x: p.x, y: p.y))
                    }
                    context.strokePath()
                }

            case "text", "sticky":
                let r = CGRect(x: obj.x, y: obj.y, width: obj.width, height: obj.height)
                if obj.type == "sticky" {
                    if obj.fillColor != "none", let fillColor = parseColor(obj.fillColor) {
                        context.setFillColor(fillColor)
                        context.fill(r)
                    }
                    context.stroke(r)
                }
                let textToDraw = obj.text ?? ""
                if !textToDraw.isEmpty {
                    context.saveGState()
                    context.translateBy(x: obj.x, y: obj.y + (obj.type == "sticky" ? 28 : 24))
                    context.scaleBy(x: 1.0, y: -1.0)
                    #if canImport(AppKit)
                    let font = NSFont.systemFont(ofSize: obj.fontSize ?? 16)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: NSColor(cgColor: parseColor(obj.strokeColor)!) ?? .white
                    ]
                    let str = NSAttributedString(string: textToDraw, attributes: attrs)
                    let line = CTLineCreateWithAttributedString(str)
                    CTLineDraw(line, context)
                    #endif
                    context.restoreGState()
                }

            default:
                break
            }
            context.restoreGState()
        }

        context.restoreGState()
        context.endPage()
        context.closePDF()

        if embedEditableData {
            let docJSONData = try HeiBanDocumentCodec.encode(document)
            let base64Doc = docJSONData.base64EncodedString()
            let markerStart = "\n%HeiBanDocumentJSON-START%\n"
            let markerEnd = "\n%HeiBanDocumentJSON-END%\n"
            if let startData = markerStart.data(using: .utf8),
               let bodyData = base64Doc.data(using: .utf8),
               let endData = markerEnd.data(using: .utf8) {
                pdfData.append(startData)
                pdfData.append(bodyData)
                pdfData.append(endData)
            }
        }

        return pdfData as Data
    }

    public func exportPNG(scope: ExportScope, selectedIds: Set<String>, scale: Double = 2.0, transparentBackground: Bool = false) throws -> Data {
        let bounds = computeScopeBounds(scope: scope, selectedIds: selectedIds)
        let pixelW = Int(max(10.0, bounds.width * scale))
        let pixelH = Int(max(10.0, bounds.height * scale))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: pixelW,
            height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "HeiBanPNG", code: 2, userInfo: [NSLocalizedDescriptionKey: "無法建立 Bitmap Context"])
        }

        if !transparentBackground {
            if let bgColor = parseColor(document.board.backgroundColor) {
                context.setFillColor(bgColor)
                context.fill(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
            }
        }

        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)

        let filteredObjects: [BoardObject]
        switch scope {
        case .selection:
            filteredObjects = document.objects.filter { selectedIds.contains($0.id) && $0.isVisible != false }
        default:
            filteredObjects = document.objects.filter { $0.isVisible != false }
        }

        for obj in filteredObjects.sorted(by: { $0.zIndex < $1.zIndex }) {
            context.saveGState()
            context.setAlpha(obj.opacity)
            if let strokeColor = parseColor(obj.strokeColor) {
                context.setStrokeColor(strokeColor)
            }
            context.setLineWidth(obj.strokeWidth)

            switch obj.type {
            case "rect":
                let r = CGRect(x: obj.x, y: obj.y, width: obj.width, height: obj.height)
                if obj.fillColor != "none", let fillColor = parseColor(obj.fillColor) {
                    context.setFillColor(fillColor)
                    context.fill(r)
                }
                context.stroke(r)

            case "circle":
                let r = CGRect(x: obj.x, y: obj.y, width: obj.width, height: obj.height)
                if obj.fillColor != "none", let fillColor = parseColor(obj.fillColor) {
                    context.setFillColor(fillColor)
                    context.fillEllipse(in: r)
                }
                context.strokeEllipse(in: r)

            case "stroke":
                if let ptsJSON = obj.points, let ptsData = ptsJSON.data(using: .utf8),
                   let pts = try? JSONDecoder().decode([Point].self, from: ptsData), pts.count >= 2 {
                    context.beginPath()
                    context.move(to: CGPoint(x: pts[0].x, y: pts[0].y))
                    for p in pts.dropFirst() {
                        context.addLine(to: CGPoint(x: p.x, y: p.y))
                    }
                    context.strokePath()
                }

            default:
                break
            }
            context.restoreGState()
        }

        guard let cgImg = context.makeImage() else {
            throw NSError(domain: "HeiBanPNG", code: 3, userInfo: [NSLocalizedDescriptionKey: "無法產生 CGImage"])
        }

        #if canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: cgImg)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "HeiBanPNG", code: 4, userInfo: [NSLocalizedDescriptionKey: "PNG 編碼失敗"])
        }
        return pngData
        #else
        return Data()
        #endif
    }

    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func parseColor(_ hex: String) -> CGColor? {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6, let rgb = UInt64(clean, radix: 16) else {
            return CGColor(gray: 1.0, alpha: 1.0)
        }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        return CGColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}

public final class BoardImporter {
    public static func importPDF(data: Data) throws -> PDFImportResult {
        let startMarker = "%HeiBanDocumentJSON-START%\n".data(using: .utf8)!
        let endMarker = "\n%HeiBanDocumentJSON-END%".data(using: .utf8)!

        if let startRange = data.range(of: startMarker),
           let endRange = data.range(of: endMarker, in: startRange.upperBound..<data.count) {
            let base64Data = data.subdata(in: startRange.upperBound..<endRange.lowerBound)
            if let base64Str = String(data: base64Data, encoding: .utf8),
               let docData = Data(base64Encoded: base64Str.trimmingCharacters(in: .whitespacesAndNewlines)),
               let doc = try? HeiBanDocumentCodec.decode(from: docData) {
                return PDFImportResult(
                    canRestoreOriginalObjects: true,
                    isExternalPDF: false,
                    document: doc,
                    importedBackgroundObject: nil
                )
            }
        }

        let bgObject = BoardObject(
            boardId: "external_pdf",
            type: "pdf_page",
            x: 0,
            y: 0,
            width: PaperPresets.a4.width,
            height: PaperPresets.a4.height,
            strokeColor: "#000000",
            fillColor: "#ffffff",
            name: "外部 PDF 頁面"
        )

        return PDFImportResult(
            canRestoreOriginalObjects: false,
            isExternalPDF: true,
            document: nil,
            importedBackgroundObject: bgObject
        )
    }
}
