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
        // 新工作使舊工作的 UI 回報失效；寫入本身由串行 queue 保證順序。
        persistence.generation += 1
        let generation = persistence.generation
        let work = DispatchWorkItem { [weak self] in self?.writeAutosaveSnapshot(generation: generation) }
        persistence.workItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
        autosaveStatus = "儲存中…"
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
}
