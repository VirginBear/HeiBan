import CoreGraphics
import Foundation

/// 文字編輯是一筆交易：草稿與原物件分離，提交才更新文件；中文組字由原生文字區處理。
extension BoardEngine {
    public func commitTextEntry() {
        let content = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            showTextEditor = false
            textDraft = ""
            currentTool = .select
        }
        guard !content.isEmpty else { return }

        let isSticky = textEntryKind == .sticky
        let object = BoardObject(
            boardId: board.id,
            type: isSticky ? "sticky" : "text",
            x: textEntryPoint.x,
            y: textEntryPoint.y,
            width: isSticky ? 260 : 320,
            height: isSticky ? 200 : 80,
            strokeColor: isSticky ? "#1f2937" : activeColor,
            fillColor: isSticky ? "#fef08a" : "none",
            strokeWidth: 1,
            opacity: activeOpacity,
            zIndex: objects.count + 1,
            text: content,
            fontSize: isSticky ? 16 : 24
        )
        addObject(object)
        selectedIds = [object.id]
    }

    public func cancelTextEntry() {
        showTextEditor = false
        textDraft = ""
        currentTool = .select
    }

    // MARK: - Native inline text editing (A15)
    public func beginInlineTextEntry(at point: Point, kind: ToolType) {
        guard kind == .text || kind == .sticky else { return }
        if kind == .sticky {
            let sticky = BoardObject(
                boardId: board.id,
                type: "sticky",
                x: point.x,
                y: point.y,
                width: 260,
                height: 210,
                strokeColor: "#1f2937",
                fillColor: StickyPalette.yellow,
                strokeWidth: 1,
                zIndex: (objects.map(\.zIndex).max() ?? 0) + 1,
                text: "",
                fontSize: 16,
                fontFamily: "PingFang TC",
                stickyStyle: .classic
            )
            addObject(sticky)
            selectedIds = [sticky.id]
            beginEditingText(object: sticky)
            return
        }
        showTextEditor = false
        showInlineTextEditor = true
        editingTextObjectId = nil
        originalTextObject = nil
        textEntryKind = kind
        textEntryPoint = point
        inlineTextPoint = point
        textDraft = ""
        editingRichTextSpans = []
        editingFontFamily = "PingFang TC"
        editingFontSize = kind == .sticky ? 16 : 24
        editingTextAlign = "left"
        editingTextColor = kind == .sticky ? "#1f2937" : activeColor
        editingTextOpacity = activeOpacity
        currentTool = .select
    }

    public func beginEditingText(object: BoardObject) {
        guard object.type == "text" || object.type == "sticky" else { return }
        showTextEditor = false
        showInlineTextEditor = true
        editingTextObjectId = object.id
        originalTextObject = object
        textEntryKind = object.type
        textEntryPoint = Point(x: object.x, y: object.y)
        inlineTextPoint = textEntryPoint
        textDraft = object.text ?? ""
        editingRichTextSpans = object.richTextSpans ?? []
        editingFontFamily = object.fontFamily ?? "PingFang TC"
        editingFontSize = object.fontSize ?? (object.type == "sticky" ? 16 : 24)
        editingTextAlign = object.align ?? "left"
        editingTextColor = object.strokeColor
        editingTextOpacity = object.opacity
        selectedIds = [object.id]
    }

    public func commitInlineTextEntry() {
        let content = textDraft
        defer {
            showInlineTextEditor = false
            textDraft = ""
            editingTextObjectId = nil
            originalTextObject = nil
            editingRichTextSpans = []
            currentTool = .select
        }

        if let original = originalTextObject, let index = objects.firstIndex(where: { $0.id == original.id })
        {
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if original.type == "sticky" {
                    var updated = original
                    updated.text = ""
                    if let index = objects.firstIndex(where: { $0.id == original.id }) {
                        objects[index] = updated
                    }
                    transactionManager.push(.modifyObjects(before: [original], after: [updated]))
                    scheduleAutosave()
                    return
                }
                // Emptying an existing text item follows the same undoable delete semantics as other edits.
                objects.remove(at: index)
                selectedIds.remove(original.id)
                transactionManager.push(.removeObjects([original]))
                scheduleAutosave()
                return
            }
            var updated = original
            updated.text = content
            updated.richTextSpans = normalizedRichTextSpans(editingRichTextSpans, plainText: content)
            updated.fontFamily = editingFontFamily
            updated.fontSize = editingFontSize
            updated.align = editingTextAlign
            updated.strokeColor = editingTextColor
            updated.opacity = editingTextOpacity
            updated.updatedAt = ISO8601DateFormatter().string(from: Date())
            guard updated != original else { return }
            objects[index] = updated
            transactionManager.push(.modifyObjects(before: [original], after: [updated]))
            scheduleAutosave()
            return
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let isSticky = textEntryKind == .sticky
        let object = BoardObject(
            boardId: board.id,
            type: isSticky ? "sticky" : "text",
            x: textEntryPoint.x,
            y: textEntryPoint.y,
            width: isSticky ? 260 : 320,
            height: isSticky ? 200 : 100,
            strokeColor: editingTextColor,
            fillColor: isSticky ? "#fef08a" : "none",
            strokeWidth: 1,
            opacity: editingTextOpacity,
            zIndex: objects.count + 1,
            text: content,
            fontSize: editingFontSize,
            fontFamily: editingFontFamily,
            align: editingTextAlign,
            richTextSpans: normalizedRichTextSpans(editingRichTextSpans, plainText: content)
        )
        addObject(object)
        selectedIds = [object.id]
    }

    public func cancelInlineTextEntry() {
        showInlineTextEditor = false
        textDraft = ""
        editingTextObjectId = nil
        originalTextObject = nil
        editingRichTextSpans = []
        currentTool = .select
    }

    public func requestInlineTextFormat(_ action: String) {
        guard
            ["bold", "italic", "underline", "strikethrough", "highlight"].contains(action)
                || action.hasPrefix("color:#")
        else { return }
        inlineTextFormatAction = action
        inlineTextFormatRevision &+= 1
    }

    public func updateObjectRichText(id: String, spans: [TextSpan]) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
            objects[index].type == "text" || objects[index].type == "sticky"
        else { return }
        let before = objects[index]
        var updated = before
        let filtered = spans.filter { !$0.text.isEmpty }
        updated.richTextSpans = filtered.isEmpty ? nil : filtered
        if !filtered.isEmpty {
            updated.text = filtered.map(\.text).joined()
        }
        guard updated != before else { return }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [before], after: [updated]))
        scheduleAutosave()
    }

    public func updateObjectTypography(id: String, fontFamily: String?, fontSize: Double?, align: String?) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
            objects[index].type == "text" || objects[index].type == "sticky"
        else { return }
        let before = objects[index]
        var updated = before
        if let fontFamily { updated.fontFamily = fontFamily }
        if let fontSize { updated.fontSize = max(8, min(144, fontSize)) }
        if let align, ["left", "center", "right"].contains(align) { updated.align = align }
        guard updated != before else { return }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [before], after: [updated]))
        scheduleAutosave()
    }

    private func normalizedRichTextSpans(_ spans: [TextSpan], plainText: String) -> [TextSpan]? {
        guard !spans.isEmpty else { return nil }
        let filtered = spans.filter { !$0.text.isEmpty }
        guard !filtered.isEmpty else { return nil }
        let joined = filtered.map(\.text).joined()
        return joined == plainText ? filtered : [TextSpan(text: plainText)]
    }
}
