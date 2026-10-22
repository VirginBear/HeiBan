import AppKit
import HeiBanCore
import PDFKit
import SwiftUI

/// Native document exchange. Rendering stays outside Core and never automates the user's open slides.
@MainActor
final class MacDocumentExchange {
    static let shared = MacDocumentExchange()
    private var importTask: Task<Void, Never>?
    private var progressWindow: NSPanel?

    func attach(to engine: BoardEngine) {
        engine.documentImportHandler = { [weak engine] url in
            guard let engine else { return }
            self.open(url, in: engine)
        }
        engine.pdfExportHandler = { [weak engine] in
            guard let engine else { return }
            self.exportPDF(engine)
        }
    }
    private func error(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.t("文件處理失敗")
        alert.informativeText = message
        alert.runModal()
    }
    func open(_ url: URL, in engine: BoardEngine) {
        guard importTask == nil else {
            error(L10n.t("請先完成或取消目前匯入"))
            return
        }
        let ext = url.pathExtension.lowercased()
        guard ["pdf", "ppt", "pptx", "key"].contains(ext) else { return }
        let expectedBoard = engine.board.id
        let notice = NSAlert()
        notice.messageText = L10n.t("匯入文件")
        notice.informativeText = L10n.t(
            "外部PDF與簡報會轉成鎖定圖片頁，可加註但不能編輯原文字或投影片元素。動畫、影片與互動不保留。簡報需安裝Keynote並允許自動化；也可先自行轉成PDF。")
        notice.addButton(withTitle: L10n.t("繼續"))
        notice.addButton(withTitle: L10n.t("取消"))
        guard notice.runModal() == .alertFirstButtonReturn else { return }
        showProgress()
        importTask = Task { [weak engine] in
            defer {
                progressWindow?.close()
                progressWindow = nil
                importTask = nil
            }
            do {
                let prepared = try await Task.detached(priority: .userInitiated) {
                    if ext == "pdf" {
                        let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard bytes <= 250_000_000 else { throw ExchangeError("來源PDF超過250MB，請先拆分文件") }
                        return try Data(contentsOf: url)
                    }
                    return try Self.convertPresentation(url)
                }.value
                try Task.checkCancellation()
                guard let engine else { return }
                // Our own PDF can restore the complete native document, including unknown fields.
                if let restored = try BoardImporter.importPDF(data: prepared).document {
                    let choice = NSAlert()
                    choice.messageText = L10n.t("PDF內含可編輯黑板原稿")
                    choice.informativeText = L10n.t("恢復會載入完整原稿，可能包含其他頁面與隱藏物件。")
                    choice.addButton(withTitle: L10n.t("恢復原稿"))
                    choice.addButton(withTitle: L10n.t("匯入圖片頁"))
                    choice.addButton(withTitle: L10n.t("取消"))
                    let response = choice.runModal()
                    if response == .alertFirstButtonReturn {
                        try Task.checkCancellation()
                        try await install(restored, in: engine, expectedBoard: expectedBoard)
                        return
                    }
                    if response != .alertSecondButtonReturn { return }
                }
                guard let pdf = PDFDocument(data: prepared) else { throw ExchangeError("無法讀取PDF") }
                if pdf.isLocked {
                    let password = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
                    let prompt = NSAlert()
                    prompt.messageText = L10n.t("PDF密碼")
                    prompt.accessoryView = password
                    prompt.addButton(withTitle: L10n.t("繼續"))
                    prompt.addButton(withTitle: L10n.t("取消"))
                    guard prompt.runModal() == .alertFirstButtonReturn else { return }
                    guard pdf.unlock(withPassword: password.stringValue) else {
                        throw ExchangeError("密碼錯誤或PDF無法解鎖")
                    }
                }
                guard pdf.pageCount > 0 else { throw ExchangeError("PDF沒有頁面") }
                let start = NSTextField(string: "1")
                let end = NSTextField(string: String(min(pdf.pageCount, 200)))
                let row = NSStackView(views: [
                    NSTextField(labelWithString: L10n.t("起始頁")), start,
                    NSTextField(labelWithString: L10n.t("結束頁")), end,
                ])
                row.orientation = .horizontal
                row.spacing = 8
                row.frame = NSRect(x: 0, y: 0, width: 340, height: 28)
                let range = NSAlert()
                range.messageText = L10n.t("選擇匯入頁面")
                range.informativeText = "\(pdf.pageCount) · " + L10n.t("一次最多200頁，圖片合計最多100MB；可分範圍匯入。")
                range.accessoryView = row
                range.addButton(withTitle: L10n.t("匯入"))
                range.addButton(withTitle: L10n.t("取消"))
                guard range.runModal() == .alertFirstButtonReturn else { return }
                guard let first = Int(start.stringValue), let last = Int(end.stringValue), first >= 1,
                    last >= first, last <= pdf.pageCount, last - first < 200
                else { throw ExchangeError("頁碼範圍無效") }
                // PDFKit stays on this actor; per-page yields let cancellation and progress repaint.
                var pages: [BoardPage] = []
                var objects: [BoardObject] = []
                var totalBytes = 0
                var maxWidth = 1.0
                var maxHeight = 1.0
                let id = UUID().uuidString
                for index in (first - 1)..<last {
                    try Task.checkCancellation()
                    guard let page = pdf.page(at: index) else { throw ExchangeError("無法讀取PDF頁面") }
                    let bounds = page.bounds(for: .cropBox)
                    let rotation = abs(page.rotation) % 180 == 90
                    let width = rotation ? bounds.height : bounds.width
                    let height = rotation ? bounds.width : bounds.height
                    guard width.isFinite, height.isFinite, width > 0, height > 0, width <= 20000,
                        height <= 20000
                    else { throw ExchangeError("PDF頁面尺寸無效或過大") }
                    let scale = min(2, 3072 / max(width, height))
                    let image = page.thumbnail(
                        of: NSSize(width: ceil(width * scale), height: ceil(height * scale)), for: .cropBox)
                    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                        let png = bitmap.representation(using: .png, properties: [:])
                    else { throw ExchangeError("PDF頁面轉圖失敗") }
                    totalBytes += png.count
                    guard totalBytes <= 100_000_000 else { throw ExchangeError("圖片總量超過100MB，請縮小頁碼範圍") }
                    let metadata = BoardPage(title: "\(index+1)", index: pages.count)
                    pages.append(metadata)
                    objects.append(
                        BoardObject(
                            boardId: id, type: "image", x: 0, y: 0, width: width, height: height,
                            imageUrl: "data:image/png;base64," + png.base64EncodedString(), isLocked: true,
                            pageId: metadata.id))
                    maxWidth = max(maxWidth, width)
                    maxHeight = max(maxHeight, height)
                    engine.showTemporaryStatus(L10n.t("匯入文件") + " \(index-first+2)/\(last-first+1)")
                    await Task.yield()
                }
                for i in objects.indices {
                    objects[i].x = (maxWidth - objects[i].width) / 2
                    objects[i].y = (maxHeight - objects[i].height) / 2
                }
                let board = BoardMetadata(
                    id: id, title: url.deletingPathExtension().lastPathComponent, backgroundColor: "#ffffff",
                    gridStyle: .blank, boardTheme: .whiteboard, canvasMode: .notebook, canvasPreset: .custom,
                    canvasWidth: maxWidth, canvasHeight: maxHeight, pages: pages,
                    activePageId: pages.first?.id)
                try Task.checkCancellation()
                try await install(
                    HeiBanDocument(board: board, objects: objects), in: engine, expectedBoard: expectedBoard)
            } catch is CancellationError { engine?.showTemporaryStatus(L10n.t("已取消匯入")) } catch {
                self.error(error.localizedDescription)
            }
        }
    }
    private func install(_ document: HeiBanDocument, in engine: BoardEngine, expectedBoard: String)
        async throws
    {
        guard engine.board.id == expectedBoard else { throw ExchangeError("目前作品已切換，請重新匯入") }
        try await engine.importPreparedDocument(document, expectedBoardID: expectedBoard)
        engine.fitNavigationView()
    }
    private func showProgress() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 110), styleMask: [.titled],
            backing: .buffered, defer: false)
        panel.title = L10n.t("匯入文件")
        panel.isReleasedWhenClosed = false
        let label = NSTextField(labelWithString: L10n.t("正在處理，可取消；完成前不會寫入作品。"))
        let button = NSButton(title: L10n.t("取消"), target: self, action: #selector(cancelImport))
        let stack = NSStackView(views: [label, button])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.frame = NSRect(x: 15, y: 15, width: 310, height: 80)
        panel.contentView?.addSubview(stack)
        panel.center()
        panel.orderFront(nil)
        progressWindow = panel
    }
    @objc private func cancelImport() { importTask?.cancel() }
    nonisolated private static func convertPresentation(_ url: URL) throws -> Data {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iWork.Keynote") != nil
        else { throw ExchangeError("請安裝Keynote，或先用PowerPoint／Keynote匯出PDF後再匯入") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HeiBan-presentation-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("Source." + url.pathExtension)
        let output = directory.appendingPathComponent("Pages.pdf")
        try FileManager.default.copyItem(at: url, to: input)
        func literal(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                + "\""
        }
        // Keynote imports slides without executing VBA. Only this unique temporary document is closed.
        let source = """
            with timeout of 120 seconds
                tell application id "com.apple.iWork.Keynote"
                    set deck to open POSIX file \(literal(input.path))
                    try
                        export deck to POSIX file \(literal(output.path)) as PDF
                        close deck saving no
                    on error messageText number errorNumber
                        try
                            close deck saving no
                        end try
                        error messageText number errorNumber
                    end try
                end tell
            end timeout
            """
        var info: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw ExchangeError("無法建立Keynote轉換指令") }
        _ = script.executeAndReturnError(&info)
        if let info {
            throw ExchangeError("Keynote轉換未完成：\(info[NSAppleScript.errorMessage] ?? "請檢查自動化授權或先匯出PDF")")
        }
        return try Data(contentsOf: output)
    }

    func exportPDF(_ engine: BoardEngine) {
        engine.commitInlineTextEntry()
        engine.finishBoardEraser()
        let source = engine.document
        var allPages = engine.isNotebook
        if engine.isNotebook {
            let range = NSAlert()
            range.messageText = L10n.t("PDF匯出範圍")
            range.informativeText = L10n.t("PDF會附完整可編輯原稿，包含其他頁面與隱藏物件；只分享可見內容請使用PNG。")
            range.addButton(withTitle: L10n.t("全部頁面"))
            range.addButton(withTitle: L10n.t("目前頁面"))
            range.addButton(withTitle: L10n.t("取消"))
            let answer = range.runModal()
            guard answer != .alertThirdButtonReturn else { return }
            allPages = answer == .alertFirstButtonReturn
        } else {
            let notice = NSAlert()
            notice.messageText = L10n.t("PDF包含可編輯原稿")
            notice.informativeText = L10n.t("PDF會附完整可編輯原稿，包含其他頁面與隱藏物件；只分享可見內容請使用PNG。")
            notice.addButton(withTitle: L10n.t("繼續"))
            notice.addButton(withTitle: L10n.t("取消"))
            guard notice.runModal() == .alertFirstButtonReturn else { return }
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = source.board.title.replacingOccurrences(of: "/", with: "_") + ".pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self.renderPDF(source, allPages: allPages).write(to: url, options: .atomic)
                engine.showTemporaryStatus(L10n.t("已匯出 PDF 文件"))
            } catch { self.error(error.localizedDescription) }
        }
    }
    private func renderPDF(_ source: HeiBanDocument, allPages: Bool) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { throw ExchangeError("無法建立PDF") }
        let preview = BoardEngine(restoreSession: false, persistenceEnabled: false)
        preview.board = source.board
        preview.objects = source.objects
        preview.selectedIds = []
        var pageIds: [String?] =
            allPages && source.board.canvasMode == .notebook
            ? (source.board.pages ?? []).sorted { $0.index < $1.index }.map { Optional($0.id) }
            : [source.board.activePageId ?? source.board.pages?.first?.id]
        if pageIds.isEmpty { pageIds = [nil] }
        for id in pageIds {
            preview.board.activePageId = id
            let bounds: CGRect
            if let w = source.board.canvasWidth, let h = source.board.canvasHeight,
                source.board.canvasMode != .infinite
            {
                bounds = CGRect(x: 0, y: 0, width: w, height: h)
            } else {
                bounds =
                    VectorMath.selectionBounds(
                        for: preview.currentPageObjects.filter { $0.isVisible != false })
                    ?? CGRect(x: 0, y: 0, width: 800, height: 600)
            }
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
                throw ExchangeError("匯出尺寸無效")
            }
            let scale = min(1, 14400 / max(bounds.width, bounds.height))
            let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
            preview.viewport = ViewportTransform(
                x: -bounds.minX * scale, y: -bounds.minY * scale, zoom: scale)
            let renderer = ImageRenderer(
                content: ZStack {
                    Color(hex: source.board.backgroundColor)
                    CanvasObjectsView(
                        engine: preview, selectionOffset: .zero, lineEndpoint: nil, shapeObject: nil)
                }.frame(width: size.width, height: size.height))
            renderer.proposedSize = ProposedViewSize(size)
            renderer.scale = 2
            var box = CGRect(origin: .zero, size: size)
            context.beginPage(mediaBox: &box)
            renderer.render { _, render in render(context) }
            context.endPage()
        }
        context.closePDF()
        return try PDFEditableAttachment.append(to: data as Data, document: source)
    }
}

private struct ExchangeError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { L10n.t(message) }
}
