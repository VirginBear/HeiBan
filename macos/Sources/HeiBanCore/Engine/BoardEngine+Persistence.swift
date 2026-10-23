import CoreGraphics
import Foundation

/// 自動保存與最近工作快照。主執行緒先擷取不可變文件，再交給單一寫入佇列；退出等待已排程寫入。
extension BoardEngine {
    public var document: HeiBanDocument {
        var snapshot = HeiBanDocument(board: board, objects: objects)
        if let envelope = persistence.header {
            snapshot.schemaVersion = envelope.schemaVersion
            snapshot.version = envelope.version
            snapshot.extraFields = envelope.extraFields
        }
        return snapshot
    }

    static var autosaveURL: URL? {
        Self.library.directory.deletingLastPathComponent()
            .appendingPathComponent("current.blackboard.json")
    }

    func restoreAutosave() {
        guard let url = Self.autosaveURL,
            let data = try? Data(contentsOf: url),
            let document = try? HeiBanDocumentCodec.decode(from: data)
        else { return }
        persistence.header = BoardPersistenceState.DocumentHeader(document)
        board = document.board
        objects = document.objects.sorted { $0.zIndex < $1.zIndex }
        autosaveStatus = "已還原上次工作"
    }

    public func scheduleAutosave() {
        guard persistence.enabled else { return }
        persistence.workItem?.cancel()
        persistence.workItem = nil
        // 每次提交都使舊快照回報失效，與是否啟用自動保存無關。
        // 否則關閉自動保存後的新編輯會被上一個背景寫入誤報為「已儲存」。
        persistence.generation += 1
        autosaveStatus = "尚未儲存"
        let settings = AppSettingsManager.shared.current
        guard settings.autoSaveEnabled, settings.autoSaveFrequency != .manual else { return }
        let generation = persistence.generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.persistence.generation == generation else { return }
            let latest = AppSettingsManager.shared.current
            guard latest.autoSaveEnabled, latest.autoSaveFrequency != .manual else {
                self.autosaveStatus = "尚未儲存"
                return
            }
            self.autosaveStatus = "儲存中…"
            self.writeAutosaveSnapshot(generation: generation)
        }
        persistence.workItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.autoSaveFrequency.rawValue, execute: work)
        autosaveStatus = "尚未儲存"
    }

    private func writeAutosaveSnapshot(generation: Int) {
        guard let url = Self.autosaveURL else {
            autosaveStatus = "無法取得自動儲存位置"
            return
        }
        var document = self.document
        let nextRev = (board.revision ?? 0) + 1
        document.board.revision = nextRev

        BoardPersistenceState.queue.async { [weak self] in
            do {
                let data = try HeiBanDocumentCodec.encode(document)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                try Self.library.save(document)
                DispatchQueue.main.async {
                    guard self?.persistence.generation == generation else { return }
                    self?.board.revision = nextRev
                    self?.refreshLibrary()
                    self?.autosaveStatus = "本機已儲存 \(Date.now.formatted(date: .omitted, time: .shortened))"
                }
            } catch {
                DispatchQueue.main.async {
                    guard self?.persistence.generation == generation else { return }
                    self?.autosaveStatus = "自動儲存失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    @discardableResult
    public func saveBeforeLeaving() -> Bool {
        cancelEraserSwipe()
        finishBoardEraser()
        if inlineTextEditing { commitInlineTextEntry() }
        guard persistence.enabled else { return true }
        if showingHome && objects.isEmpty && !libraryBoards.contains(where: { $0.id == board.id }) {
            return true
        }
        persistence.workItem?.cancel()
        persistence.generation += 1
        var document = self.document
        let nextRev = (board.revision ?? 0) + 1
        document.board.revision = nextRev

        do {
            // Serialize with pending background saves so an older snapshot cannot overwrite this one.
            try BoardPersistenceState.queue.sync {
                try Self.library.save(document)
                if let url = Self.autosaveURL {
                    try FileManager.default.createDirectory(
                        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let data = try HeiBanDocumentCodec.encode(document)
                    try data.write(to: url, options: .atomic)
                }
            }
            // 只有寫入成功才前進修訂號，失敗時保留可重試的原狀態。
            board.revision = nextRev
            refreshLibrary()
            autosaveStatus = "本機已儲存 \(Date.now.formatted(date: .omitted, time: .shortened))"
            return true
        } catch {
            autosaveStatus = "儲存失敗：\(error.localizedDescription)"
            showTemporaryStatus("儲存失敗，保留目前黑板：\(error.localizedDescription)")
            return false
        }
    }

    public func flushAutosave() { _ = saveBeforeLeaving() }

    /// 正常結束應用程式時使用非同步保存，避免大作品的編碼／磁碟寫入凍結主執行緒。
    public func saveBeforeLeaving(completion: @escaping (Bool) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        cancelEraserSwipe()
        finishBoardEraser()
        if inlineTextEditing { commitInlineTextEntry() }
        guard persistence.enabled else {
            completion(true)
            return
        }
        if showingHome && objects.isEmpty && !libraryBoards.contains(where: { $0.id == board.id }) {
            completion(true)
            return
        }

        persistence.workItem?.cancel()
        persistence.generation += 1
        let generation = persistence.generation
        var snapshot = document
        let nextRev = (snapshot.board.revision ?? 0) + 1
        snapshot.board.revision = nextRev
        autosaveStatus = "儲存中…"

        BoardPersistenceState.queue.async { [weak self] in
            do {
                try Self.library.save(snapshot)
                if let url = Self.autosaveURL {
                    try FileManager.default.createDirectory(
                        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let data = try HeiBanDocumentCodec.encode(snapshot)
                    try data.write(to: url, options: .atomic)
                }
                DispatchQueue.main.async {
                    guard let self else {
                        completion(false)
                        return
                    }
                    guard self.persistence.generation == generation else {
                        completion(false)
                        return
                    }
                    self.board.revision = nextRev
                    self.refreshLibrary()
                    self.autosaveStatus = "本機已儲存 \(Date.now.formatted(date: .omitted, time: .shortened))"
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else {
                        completion(false)
                        return
                    }
                    guard self.persistence.generation == generation else {
                        completion(false)
                        return
                    }
                    self.autosaveStatus = "儲存失敗：\(error.localizedDescription)"
                    self.showTemporaryStatus("儲存失敗，保留目前黑板：\(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
}
