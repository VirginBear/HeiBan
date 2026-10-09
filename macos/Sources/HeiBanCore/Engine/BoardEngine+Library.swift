import CoreGraphics
import Foundation

/// 作品庫的開啟、建立、命名、備份恢復與垃圾桶。activate 統一重設互動、歷史與文件版本封套。
extension BoardEngine {
    public func refreshLibrary() {
        do {
            let result = try Self.library.inspectLibrary()
            libraryBoards = result.validBoards
            damagedBoards = result.damagedFiles
            trashedLibraryBoards = try Self.library.trashBoards()
        } catch {
            showTemporaryStatus("無法讀取黑板資料庫：\(error.localizedDescription)")
        }
    }

    public func recoverDamagedBoard(id: String) {
        do {
            let restored = try Self.library.restoreFromBackup(id: id)
            refreshLibrary()
            showTemporaryStatus("已從備份成功恢復黑板：\(restored.board.title)")
        } catch {
            showTemporaryStatus("恢復失敗：\(error.localizedDescription)")
        }
    }

    public func returnHome() {
        guard saveBeforeLeaving() else { return }
        cancelTransientInteraction()
        showingHome = true
    }

    public func openLibraryBoard(_ id: String) {
        guard saveBeforeLeaving() else { return }
        do { activate(try Self.library.load(id: id)) } catch {
            showTemporaryStatus("開啟失敗：\(error.localizedDescription)")
        }
    }

    public func createBoard(
        title: String,
        theme: BoardTheme = .dark,
        mode: CanvasMode = .infinite,
        preset: CanvasPreset? = nil,
        width: Double? = nil,
        height: Double? = nil,
        orientation: String? = nil,
        coverStyle: String? = nil,
        gridStyle: GridStyle = .dots,
        backgroundColor: String? = nil,
        gridColor: String? = nil
    ) {
        guard saveBeforeLeaving() else { return }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? "未命名黑板" : title

        var meta = BoardMetadata(
            id: UUID().uuidString,
            title: finalTitle,
            backgroundColor: backgroundColor ?? theme.defaultBackgroundColor,
            gridStyle: gridStyle,
            boardTheme: theme,
            coverStyle: coverStyle,
            orientation: orientation,
            gridColor: gridColor
        )
        meta.canvasMode = mode

        switch mode {
        case .infinite:
            meta.canvasPreset = .infinite
            meta.canvasWidth = nil
            meta.canvasHeight = nil
            meta.pages = nil
            meta.activePageId = nil
        case .fixed:
            let resolvedPreset = preset ?? .sixteen_nine
            meta.canvasPreset = resolvedPreset
            var w = width ?? resolvedPreset.dimensions.width
            var h = height ?? resolvedPreset.dimensions.height
            if orientation == "landscape" || orientation == "橫向" {
                if w < h { swap(&w, &h) }
            } else if orientation == "portrait" || orientation == "直向" {
                if w > h { swap(&w, &h) }
            }
            meta.canvasWidth = w
            meta.canvasHeight = h
            meta.pages = nil
            meta.activePageId = nil
        case .notebook:
            let resolvedPreset = preset ?? .notebook
            meta.canvasPreset = resolvedPreset
            var w = width ?? resolvedPreset.dimensions.width
            var h = height ?? resolvedPreset.dimensions.height
            if orientation == "landscape" || orientation == "橫向" {
                if w < h { swap(&w, &h) }
            } else if orientation == "portrait" || orientation == "直向" {
                if w > h { swap(&w, &h) }
            }
            meta.canvasWidth = w
            meta.canvasHeight = h
            let firstPage = BoardPage(id: UUID().uuidString, title: "第 1 頁", index: 0)
            meta.pages = [firstPage]
            meta.activePageId = firstPage.id
        }

        activate(HeiBanDocument(board: meta, objects: []))
        scheduleAutosave()
    }

    public func duplicateLibraryBoard(_ id: String) {
        guard saveBeforeLeaving() else { return }
        do {
            var document = try Self.library.load(id: id)
            document.board.id = UUID().uuidString
            document.board.title += " 副本"
            for index in document.objects.indices { document.objects[index].boardId = document.board.id }
            try BoardPersistenceState.queue.sync { try Self.library.save(document) }
            refreshLibrary()
        } catch { showTemporaryStatus("複製失敗：\(error.localizedDescription)") }
    }

    public func renameLibraryBoard(_ id: String, title: String) {
        guard saveBeforeLeaving() else { return }
        do {
            var document = try Self.library.load(id: id)
            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            document.board.title = cleaned
            try BoardPersistenceState.queue.sync { try Self.library.save(document) }
            if board.id == id { board.title = cleaned }
            refreshLibrary()
        } catch { showTemporaryStatus("重新命名失敗：\(error.localizedDescription)") }
    }

    public func deleteLibraryBoards(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        do {
            for id in ids { try Self.library.delete(id: id) }
            if ids.contains(board.id) && !showingHome {
                cancelTransientInteraction()
                showingHome = true
            }
            refreshLibrary()
            showTemporaryStatus("已刪除 \(ids.count) 張黑板")
        } catch {
            showTemporaryStatus("刪除黑板失敗：\(error.localizedDescription)")
        }
    }

    /// 所有文件切換共用此入口，避免只換 board／objects 而遺失版本封套。
    /// internal 是核心 session 的整合邊界；UI 應使用開啟／載入命令。
    func activate(_ document: HeiBanDocument) {
        cancelTransientInteraction()
        readingMode = false
        viewportLocked = false
        transactionManager.clear()
        persistence.header = BoardPersistenceState.DocumentHeader(document)
        board = document.board
        objects = document.objects.sorted { $0.zIndex < $1.zIndex }
        selectedIds.removeAll()
        viewport = ViewportTransform(x: 200, y: 150, zoom: 1)
        showingHome = false
    }

    public func trashLibraryBoards(_ ids: Set<String>) {
        do {
            for id in ids { try Self.library.moveToTrash(id: id) }
            refreshLibrary()
            showTemporaryStatus("已移到垃圾桶，可隨時還原")
        } catch {
            refreshLibrary()
            showTemporaryStatus("移到垃圾桶失敗：\(error.localizedDescription)")
        }
    }
    public func restoreLibraryBoard(_ id: String) {
        do {
            _ = try Self.library.restoreFromTrash(id: id)
            refreshLibrary()
        } catch { showTemporaryStatus("還原失敗：\(error.localizedDescription)") }
    }
}
