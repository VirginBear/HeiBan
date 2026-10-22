import Foundation

/// 原稿開啟／另存及各種匯出入口；完整可編輯內容依 HeiBanDocumentCodec，不以圖片替代原稿。
extension BoardEngine {
    // MARK: - 可編輯原稿（.heiban 與舊 JSON）
    public func exportToJsonData() throws -> Data {
        cancelEraserSwipe()
        return try HeiBanDocumentCodec.encode(document, prettyPrinted: true)
    }

    public func loadFromJsonData(_ data: Data) throws {
        let doc = try HeiBanDocumentCodec.decode(from: data)
        guard saveBeforeLeaving() else { return }
        activate(doc)
        scheduleAutosave()
        showTemporaryStatus("成功載入黑板檔案：\(doc.board.title)")
    }

    /// Conversion owns a complete value snapshot. Save the old owner asynchronously once,
    /// then recheck identity/cancellation before installing; never replace the active work from a late callback.
    @MainActor
    public func importPreparedDocument(_ incoming: HeiBanDocument, expectedBoardID: String) async throws {
        guard board.id == expectedBoardID else { throw CancellationError() }
        let saved = await withCheckedContinuation { continuation in
            saveBeforeLeaving { continuation.resume(returning: $0) }
        }
        try Task.checkCancellation()
        guard saved, board.id == expectedBoardID else {
            throw NSError(
                domain: "HeiBanImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "原作品未保存或已切換，匯入已停止"])
        }
        // PDF restoration is an import, not permission to overwrite a library work with a matching embedded ID.
        var imported=incoming
        imported.board.id=UUID().uuidString
        imported.board.revision=1
        imported.board.thumbnail=nil
        for index in imported.objects.indices { imported.objects[index].boardId=imported.board.id }
        activate(imported)
        let importedSaved = await withCheckedContinuation { continuation in
            saveBeforeLeaving { continuation.resume(returning: $0) }
        }
        if !importedSaved {
            // The completed import remains in the editor for retry/export; never discard it after a disk error.
            throw NSError(
                domain: "HeiBanImport", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "匯入已保留在畫布，但儲存失敗，請另存或重試"])
        }
    }

    public func loadShowcaseBoard() {
        guard saveBeforeLeaving() else { return }
        if let doc = FeatureShowcaseDocument.makeDocument() {
            activate(doc)
            scheduleAutosave()
            showTemporaryStatus("已載入功能示範黑板")
        } else {
            showTemporaryStatus("載入示範黑板失敗")
        }
    }

    public func save(to url: URL) throws {
        let data = try exportToJsonData()
        try data.write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws {
        if ["pdf", "ppt", "pptx", "key"].contains(url.pathExtension.lowercased()),
            let handler = documentImportHandler
        {
            handler(url)
            return
        }
        let data = try Data(contentsOf: url)
        try loadFromJsonData(data)
    }

    public func saveToFilePrompt() {
        let cleanTitle = board.title.replacingOccurrences(of: "/", with: "_")
        let defaultName = "\(cleanTitle).heiban"

        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        dialogService.runSavePanel(defaultName: defaultName, allowedExtensions: ["heiban", "json"]) {
            [weak self] url in
            guard let self = self, let url = url else { return }
            do {
                try self.save(to: url)
                self.showTemporaryStatus("已儲存黑板至檔案")
            } catch {
                self.showTemporaryStatus("儲存失敗: \(error.localizedDescription)")
            }
        }
    }

    public func openFromFilePrompt() {
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        dialogService.runOpenPanel(
            allowedExtensions: ["blackboard.json", "json", "heiban", "pdf", "ppt", "pptx", "key"],
            allowsMultiple: false
        ) { [weak self] urls in
            guard let self = self, let url = urls?.first else { return }
            do {
                try self.load(from: url)
            } catch {
                self.showTemporaryStatus("載入失敗: \(error.localizedDescription)")
            }
        }
    }

    public func exportHTMLPrompt() {
        presentExport(format: "HTML", fileExtension: "html", success: "已匯出 HTML 離線網頁檔") { exporter in
            Data(try exporter.exportHTML(scope: .allObjects, selectedIds: selectedIds).utf8)
        }
    }

    public func exportSVGPrompt() {
        presentExport(format: "SVG", fileExtension: "svg", success: "已匯出 SVG 向量圖") { exporter in
            Data(try exporter.exportSVG(scope: .allObjects, selectedIds: selectedIds).utf8)
        }
    }

    public func exportPDFPrompt() {
        if let handler = pdfExportHandler {
            handler()
            return
        }
        presentExport(format: "PDF", fileExtension: "pdf", success: "已匯出 PDF 文件") { exporter in
            try exporter.exportPDF(scope: .allObjects, selectedIds: selectedIds)
        }
    }

    public func exportPNGPrompt() {
        presentExport(format: "PNG", fileExtension: "png", success: "已匯出 PNG 高清圖") { exporter in
            try exporter.exportPNG(scope: .allObjects, selectedIds: selectedIds, scale: 2.0)
        }
    }

    /// 先擷取文件與生成輸出，再呈現存檔面板；所有格式共用取消、錯誤與原子寫入規則。
    private func presentExport(
        format: String,
        fileExtension: String,
        success: String,
        generate: (BoardExporter) throws -> Data
    ) {
        guard let dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }
        let data: Data
        do { data = try generate(BoardExporter(document: document)) } catch {
            showTemporaryStatus("匯出 \(format) 失敗：\(error.localizedDescription)")
            return
        }
        let title = (board.title.isEmpty ? "黑板" : board.title).replacingOccurrences(of: "/", with: "_")
        dialogService.runSavePanel(
            defaultName: "\(title).\(fileExtension)", allowedExtensions: [fileExtension]
        ) { [weak self] url in
            guard let self, let url else { return }
            do {
                try data.write(to: url, options: .atomic)
                self.showTemporaryStatus(success)
            } catch { self.showTemporaryStatus("儲存 \(format) 失敗：\(error.localizedDescription)") }
        }
    }
}
