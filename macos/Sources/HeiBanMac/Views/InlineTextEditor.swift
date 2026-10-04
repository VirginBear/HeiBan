import AppKit
import SwiftUI
import HeiBanCore

private enum InlineTextFormat: Equatable {
    case bold, italic, underline, strikethrough, highlight, color(String)
}

/// A native NSTextView keeps macOS input-method composition (including CJK IMEs)
/// inside the canvas while retaining a real UTF-16 selection for rich formatting.
private struct InlineTextEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var spans: [TextSpan]
    let fontFamily: String
    let fontSize: Double
    let textColor: String
    let opacity: Double
    let alignment: String
    let formatAction: String?
    let formatRevision: Int
    let onCommit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder

        let textView = InlineNSTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 120))
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 3, height: 5)
        textView.drawsBackground = false
        textView.onCommit = onCommit
        textView.onCancel = onCancel
        textView.font = makeFont(family: fontFamily, size: fontSize, bold: false, italic: false)
        textView.textColor = NSColor(heibanHex: textColor)
        textView.alphaValue = opacity
        textView.alignment = paragraphAlignment(alignment)
        textView.textStorage?.setAttributedString(makeAttributedString(text, spans: spans, family: fontFamily, size: fontSize, color: textColor))
        context.coordinator.textView = textView
        scroll.documentView = textView
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        textView.onCommit = onCommit
        textView.onCancel = onCancel
        textView.alphaValue = opacity
        textView.alignment = paragraphAlignment(alignment)
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
        let fontKey = "\(fontFamily)|\(fontSize)"
        if context.coordinator.lastFontKey != fontKey {
            context.coordinator.lastFontKey = fontKey
            let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            var fontUpdates: [(NSRange, NSFont)] = []
            textView.textStorage?.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                let oldFont = value as? NSFont ?? NSFont.systemFont(ofSize: CGFloat(fontSize))
                let traits = oldFont.fontDescriptor.symbolicTraits
                let newFont = makeFont(family: fontFamily, size: fontSize, bold: traits.contains(.bold), italic: traits.contains(.italic))
                fontUpdates.append((range, newFont))
            }
            for (range, font) in fontUpdates {
                textView.textStorage?.addAttribute(.font, value: font, range: range)
            }
            textView.font = makeFont(family: fontFamily, size: fontSize, bold: false, italic: false)
        }
        if context.coordinator.lastAlignment != alignment {
            context.coordinator.lastAlignment = alignment
            let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            if range.length > 0 {
                textView.textStorage?.addAttribute(.paragraphStyle, value: makeParagraphStyle(alignment), range: range)
            }
            textView.alignment = paragraphAlignment(alignment)
        }
        if let action = formatAction, context.coordinator.lastFormatRevision != formatRevision {
            context.coordinator.lastFormatRevision = formatRevision
            context.coordinator.apply(action)
        }
    }

    private func makeAttributedString(_ string: String, spans: [TextSpan], family: String, size: Double, color: String) -> NSAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: makeFont(family: family, size: size, bold: false, italic: false),
            .foregroundColor: NSColor(heibanHex: color),
            .paragraphStyle: makeParagraphStyle(alignment)
        ]
        let result = NSMutableAttributedString(string: string, attributes: baseAttributes)
        var cursor = 0
        for span in spans {
            let length = (span.text as NSString).length
            guard length > 0, cursor + length <= result.length else { break }
            let range = NSRange(location: cursor, length: length)
            var attributes: [NSAttributedString.Key: Any] = [:]
            let bold = span.isBold ?? false
            let italic = span.isItalic ?? false
            attributes[.font] = makeFont(family: family, size: size, bold: bold, italic: italic)
            if let color = span.color { attributes[.foregroundColor] = NSColor(heibanHex: color) }
            if let color = span.highlightColor { attributes[.backgroundColor] = NSColor(heibanHex: color) }
            if span.isUnderline == true { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if span.isStrikethrough == true { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            result.addAttributes(attributes, range: range)
            cursor += length
        }
        return result
    }

    private func makeFont(family: String, size: Double, bold: Bool, italic: Bool) -> NSFont {
        let base = NSFont(name: family, size: CGFloat(size)) ?? NSFont.systemFont(ofSize: CGFloat(size))
        var font = base
        if bold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        if italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        return font
    }

    private func paragraphAlignment(_ value: String) -> NSTextAlignment {
        switch value {
        case "center": .center
        case "right": .right
        default: .left
        }
    }

    private func makeParagraphStyle(_ alignment: String) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = paragraphAlignment(alignment)
        return style
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineTextEditorRepresentable
        weak var textView: InlineNSTextView?
        var lastFormatRevision = -1
        var lastFontKey: String?
        var lastAlignment: String?

        init(_ parent: InlineTextEditorRepresentable) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            parent.spans = extractSpans(from: textView.attributedString())
        }

        func apply(_ rawAction: String) {
            guard let textView else { return }
            let format: InlineTextFormat
            switch rawAction {
            case "bold": format = .bold
            case "italic": format = .italic
            case "underline": format = .underline
            case "strikethrough": format = .strikethrough
            case "highlight": format = .highlight
            case let value where value.hasPrefix("color:#"): format = .color(String(value.dropFirst(6)))
            default: return
            }
            let range = textView.selectedRange()
            let length = (textView.string as NSString).length
            let safeRange = NSRange(location: min(range.location, length), length: min(range.length, max(0, length - range.location)))
            let storage = textView.textStorage
            let currentFont = (textView.typingAttributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: CGFloat(parent.fontSize))
            let selectedFont = safeRange.length > 0 ? storage?.attribute(.font, at: safeRange.location, effectiveRange: nil) as? NSFont : nil
            let font = selectedFont ?? currentFont
            let shouldRemove = isApplied(format, range: safeRange, textView: textView, fallbackFont: font)

            let applyToTypingAttributes: (inout [NSAttributedString.Key: Any]) -> Void = { attributes in
                Self.update(attributes: &attributes, format: format, remove: shouldRemove, font: font)
            }
            if safeRange.length == 0 {
                var attributes = textView.typingAttributes
                applyToTypingAttributes(&attributes)
                textView.typingAttributes = attributes
            } else {
                var edits: [(NSRange, [NSAttributedString.Key: Any])] = []
                storage?.enumerateAttributes(in: safeRange) { attributes, range, _ in
                    let runFont = attributes[.font] as? NSFont ?? font
                    var changes: [NSAttributedString.Key: Any] = [:]
                    Self.update(attributes: &changes, format: format, remove: shouldRemove, font: runFont)
                    edits.append((range, changes))
                }
                storage?.beginEditing()
                for (range, changes) in edits {
                    for (key, value) in changes {
                        storage?.addAttribute(key, value: value, range: range)
                    }
                    if shouldRemove {
                        let key: NSAttributedString.Key
                        switch format {
                        case .underline: key = .underlineStyle
                        case .strikethrough: key = .strikethroughStyle
                        case .highlight: key = .backgroundColor
                        case .bold, .italic, .color: continue
                        }
                        storage?.removeAttribute(key, range: range)
                    }
                }
                storage?.endEditing()
            }
            parent.spans = extractSpans(from: textView.attributedString())
        }

        private func isApplied(_ format: InlineTextFormat, range: NSRange, textView: InlineNSTextView, fallbackFont: NSFont) -> Bool {
            if range.length == 0 {
                let attributes = textView.typingAttributes
                return Self.isApplied(format, attributes: attributes, fallbackFont: fallbackFont)
            }
            var allApplied = true
            textView.textStorage?.enumerateAttributes(in: range) { attributes, _, stop in
                if !Self.isApplied(format, attributes: attributes, fallbackFont: fallbackFont) {
                    allApplied = false
                    stop.pointee = true
                }
            }
            return allApplied
        }

        private static func isApplied(_ format: InlineTextFormat, attributes: [NSAttributedString.Key: Any], fallbackFont: NSFont) -> Bool {
            switch format {
            case .bold: return (attributes[.font] as? NSFont ?? fallbackFont).fontDescriptor.symbolicTraits.contains(.bold)
            case .italic: return (attributes[.font] as? NSFont ?? fallbackFont).fontDescriptor.symbolicTraits.contains(.italic)
            case .underline: return (attributes[.underlineStyle] as? Int ?? 0) != 0
            case .strikethrough: return (attributes[.strikethroughStyle] as? Int ?? 0) != 0
            case .highlight: return attributes[.backgroundColor] != nil
            case .color(let hex): return Self.hex(attributes[.foregroundColor] as? NSColor ?? .clear).caseInsensitiveCompare(hex) == .orderedSame
            }
        }

        private static func update(attributes: inout [NSAttributedString.Key: Any], format: InlineTextFormat, remove: Bool, font: NSFont) {
            switch format {
            case .bold, .italic:
                var traits = font.fontDescriptor.symbolicTraits
                let trait: NSFontDescriptor.SymbolicTraits = format == .bold ? .bold : .italic
                if remove { traits.remove(trait) } else { traits.insert(trait) }
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                attributes[.font] = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
            case .underline:
                attributes[.underlineStyle] = remove ? nil : NSUnderlineStyle.single.rawValue
            case .strikethrough:
                attributes[.strikethroughStyle] = remove ? nil : NSUnderlineStyle.single.rawValue
            case .highlight:
                attributes[.backgroundColor] = remove ? nil : NSColor.systemYellow.withAlphaComponent(0.45)
            case .color(let hex):
                attributes[.foregroundColor] = NSColor(heibanHex: hex)
            }
        }

        private func extractSpans(from attributed: NSAttributedString) -> [TextSpan] {
            guard attributed.length > 0 else { return [] }
            var result: [TextSpan] = []
            attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
                let value = (attributed.string as NSString).substring(with: range)
                let font = attrs[.font] as? NSFont
                let color = attrs[.foregroundColor] as? NSColor
                let background = attrs[.backgroundColor] as? NSColor
                let underline = attrs[.underlineStyle] as? Int
                let strike = attrs[.strikethroughStyle] as? Int
                let traits = font?.fontDescriptor.symbolicTraits ?? []
                result.append(TextSpan(
                    text: value,
                    isBold: traits.contains(.bold),
                    isItalic: traits.contains(.italic),
                    isUnderline: underline != nil && underline != 0,
                    isStrikethrough: strike != nil && strike != 0,
                    color: color.map(Self.hex),
                    highlightColor: background.map(Self.hex)
                ))
            }
            return result
        }

        private static func hex(_ color: NSColor) -> String {
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            return String(format: "#%02x%02x%02x", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
        }
    }
}

private final class InlineNSTextView: NSTextView {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && !hasMarkedText() {
            onCancel?()
            return
        }
        if event.keyCode == 36 && event.modifierFlags.contains(.command) && !hasMarkedText() {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }
}

struct InlineTextEditorOverlay: View {
    @ObservedObject var engine: BoardEngine

    private var isSticky: Bool { engine.textEntryKind == .sticky }
    private var editorWidth: CGFloat { max(300, CGFloat(isSticky ? 260 : 320) * CGFloat(engine.viewport.zoom)) }
    private var panelWidth: CGFloat { min(max(520, editorWidth), max(320, engine.canvasSize.width - 16)) }
    private var editorHeight: CGFloat { isSticky ? 260 : 210 }
    private var screenOrigin: CGPoint {
        let x = engine.inlineTextPoint.x * engine.viewport.zoom + engine.viewport.x
        let y = engine.inlineTextPoint.y * engine.viewport.zoom + engine.viewport.y
        return CGPoint(x: min(max(8, x), max(8, engine.canvasSize.width - panelWidth - 8)),
                       y: min(max(8, y), max(8, engine.canvasSize.height - editorHeight - 8)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                formatButton("B", help: "粗體", format: .bold).fontWeight(.bold)
                formatButton("I", help: "斜體", format: .italic).italic()
                formatButton("U", help: "底線", format: .underline).underline()
                formatButton("S", help: "刪除線", format: .strikethrough).strikethrough()
                formatButton("▧", help: "螢光標記", format: .highlight)
                formatButton("A", help: "將所選文字設為目前文字色", format: .color(engine.editingTextColor))
                ColorPicker("文字色彩", selection: Binding(
                    get: { Color(hex: engine.editingTextColor) },
                    set: { engine.editingTextColor = Self.hex(from: $0); engine.requestInlineTextFormat("color:\(engine.editingTextColor)") }
                ))
                .labelsHidden()
                .frame(width: 26)
                Spacer(minLength: 8)
                Button("取消") { engine.cancelInlineTextEntry() }
                    .keyboardShortcut(.cancelAction)
                Button("完成") { engine.commitInlineTextEntry() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#4f8c70"))
            }
            .controlSize(.small)

            HStack(spacing: 8) {
                TextField("字體", text: $engine.editingFontFamily)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 112)
                Stepper(value: $engine.editingFontSize, in: 8...144, step: 1) {
                    Text("\(Int(engine.editingFontSize)) pt").monospacedDigit()
                }
                .frame(width: 108)
                Text("不透明度")
                Slider(value: $engine.editingTextOpacity, in: 0.05...1)
                    .frame(width: 92)
                Picker("對齊", selection: $engine.editingTextAlign) {
                    Text("靠左").tag("left")
                    Text("置中").tag("center")
                    Text("靠右").tag("right")
                }
                .labelsHidden()
                .frame(width: 84)
            }
            .controlSize(.small)

            InlineTextEditorRepresentable(
                text: $engine.textDraft,
                spans: $engine.editingRichTextSpans,
                fontFamily: engine.editingFontFamily,
                fontSize: engine.editingFontSize,
                textColor: engine.editingTextColor,
                opacity: engine.editingTextOpacity,
                alignment: engine.editingTextAlign,
                formatAction: engine.inlineTextFormatAction,
                formatRevision: engine.inlineTextFormatRevision,
                onCommit: engine.commitInlineTextEntry,
                onCancel: engine.cancelInlineTextEntry
            )
            .frame(width: min(max(280, editorWidth - 16), panelWidth - 16), height: max(80, editorHeight - 110))
        }
        .padding(8)
        .background(isSticky ? Color(hex: "#fef08a") : Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSticky ? Color(hex: "#d4a72c") : Color.accentColor.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        .frame(width: panelWidth, height: editorHeight, alignment: .topLeading)
        .position(x: screenOrigin.x + panelWidth / 2, y: screenOrigin.y + editorHeight / 2)
    }

    private func formatButton(_ title: String, help: String, format: InlineTextFormat) -> some View {
        Button {
            engine.requestInlineTextFormat(actionName(for: format))
        } label: {
            Text(title).frame(width: 25, height: 24)
        }
        .buttonStyle(.bordered)
        .help(help)
    }

    private func actionName(for format: InlineTextFormat) -> String {
        switch format {
        case .bold: "bold"
        case .italic: "italic"
        case .underline: "underline"
        case .strikethrough: "strikethrough"
        case .highlight: "highlight"
        case .color(let hex): "color:\(hex)"
        }
    }

    private static func hex(from color: Color) -> String {
        let rgb = (NSColor(color).usingColorSpace(.deviceRGB) ?? .white)
        return String(format: "#%02x%02x%02x", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}

private extension NSColor {
    convenience init(heibanHex: String) {
        let hex = heibanHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let red, green, blue: UInt64
        if hex.count >= 6 {
            red = (value >> 16) & 0xff
            green = (value >> 8) & 0xff
            blue = value & 0xff
        } else {
            red = 134; green = 239; blue = 172
        }
        self.init(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
}
