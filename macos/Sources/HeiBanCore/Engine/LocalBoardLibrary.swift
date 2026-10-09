import Foundation

public enum PersistenceError: Error, LocalizedError, Equatable {
    case revisionConflict(current: Int, incoming: Int)
    case documentNotFound(id: String)
    case backupNotFound(id: String)
    case fileDamaged(url: URL, reason: String)

    public var errorDescription: String? {
        switch self {
        case .revisionConflict(let current, let incoming):
            return "修訂衝突：磁碟上修訂版號 (\(current)) 新於嘗試寫入之版號 (\(incoming))，終止覆蓋以防資料遺失"
        case .documentNotFound(let id):
            return "找不到黑板檔案：\(id)"
        case .backupNotFound(let id):
            return "找不到備份快照：\(id)"
        case .fileDamaged(let url, let reason):
            return "黑板檔案損壞 (\(url.lastPathComponent))：\(reason)"
        }
    }
}

public struct DamagedBoardFileInfo: Identifiable, Equatable {
    public var id: String { url.path }
    public var url: URL
    public var errorDescription: String
    public var hasBackup: Bool

    public init(url: URL, errorDescription: String, hasBackup: Bool) {
        self.url = url
        self.errorDescription = errorDescription
        self.hasBackup = hasBackup
    }
}

public struct LibraryInspectionResult: Equatable {
    public var validBoards: [BoardMetadata]
    public var damagedFiles: [DamagedBoardFileInfo]

    public init(validBoards: [BoardMetadata], damagedFiles: [DamagedBoardFileInfo]) {
        self.validBoards = validBoards
        self.damagedFiles = damagedFiles
    }
}

/// One atomic document per board with revisions, backup snapshots, and corruption detection.
public struct LocalBoardLibrary {
    public let directory: URL
    public let backupsDirectory: URL
    public let tempDirectory: URL
    public let thumbnailsDirectory: URL
    public let trashDirectory: URL
    public let indexFileURL: URL

    public init(directory: URL? = nil) {
        let sandbox = ProcessInfo.processInfo.environment["HEIBAN_DATA_DIRECTORY"]
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        let base = directory ?? sandbox ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HeiBan", isDirectory: true)

        self.directory = base.appendingPathComponent("Boards", isDirectory: true)
        self.backupsDirectory = base.appendingPathComponent("Backups", isDirectory: true)
        self.tempDirectory = base.appendingPathComponent("Temp", isDirectory: true)
        self.thumbnailsDirectory = base.appendingPathComponent("Thumbnails", isDirectory: true)
        self.trashDirectory = base.appendingPathComponent("Trash", isDirectory: true)
        self.indexFileURL = base.appendingPathComponent("library_index.json")
    }

    public func fileURL(id: String) -> URL {
        let filename = Data(id.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(filename + ".blackboard.json")
    }

    public func backupURL(id: String) -> URL {
        let filename = Data(id.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return backupsDirectory.appendingPathComponent(filename + ".backup.json")
    }

    public func thumbnailURL(id: String) -> URL {
        let filename = Data(id.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return thumbnailsDirectory.appendingPathComponent(filename + ".thumb.json")
    }

    public func thumbnailData(id: String) -> Data? {
        let url = thumbnailURL(id: id)
        return try? Data(contentsOf: url)
    }

    public func trashFileURL(id: String) -> URL {
        let filename = Data(id.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return trashDirectory.appendingPathComponent(filename + ".blackboard.json")
    }

    /// 原子寫入黑板文件至任意目標路徑，含修訂版號保護、快照備份、真實縮圖與索引更新
    public func saveToFile(
        _ document: HeiBanDocument,
        at targetURL: URL,
        expectedRevision: Int? = nil,
        createBackup: Bool = true,
        generateThumbnail: Bool = true
    ) throws {
        let parentDir = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)

        // 1. 修訂衝突防護：若磁碟上已存在較新修訂版號，禁止覆蓋
        let incomingRev = document.board.revision ?? 1
        if FileManager.default.fileExists(atPath: targetURL.path),
           let onDiskData = try? Data(contentsOf: targetURL),
           let onDiskDoc = try? HeiBanDocumentCodec.decode(from: onDiskData) {
            let onDiskRev = onDiskDoc.board.revision ?? 1
            if onDiskRev > incomingRev {
                throw PersistenceError.revisionConflict(current: onDiskRev, incoming: incomingRev)
            }
        }

        var snapshot = document
        snapshot.board.itemCount = snapshot.objects.count
        snapshot.board.updatedAt = ISO8601DateFormatter().string(from: Date())
        if snapshot.board.revision == nil {
            snapshot.board.revision = incomingRev
        }

        let encodedData = try HeiBanDocumentCodec.encode(snapshot, prettyPrinted: true)

        // 2. 先寫入隔離臨時檔案，再原子替換目標路徑
        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString).tmp")
        try encodedData.write(to: tempURL)

        if FileManager.default.fileExists(atPath: targetURL.path) {
            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: targetURL)
        }

        // 3. 建立備份快照
        if createBackup {
            let bURL = backupURL(id: snapshot.board.id)
            try? encodedData.write(to: bURL, options: .atomic)
        }

        // 4. 產生實體縮圖檔案 (A21)
        if generateThumbnail {
            let thumbObjects = Array(snapshot.objects.prefix(50))
            let thumbDoc = HeiBanDocument(board: snapshot.board, objects: thumbObjects)
            if let thumbData = try? JSONEncoder().encode(thumbDoc) {
                try? thumbData.write(to: thumbnailURL(id: snapshot.board.id), options: .atomic)
            }
        }

        // 5. 若目標路徑位於 library 專屬 Boards 目錄下，更新 metadata 索引檔
        if targetURL.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path) {
            updateIndex(with: snapshot.board)
        }
    }

    /// 原子寫入黑板文件，含修訂版號保護、快照備份、真實縮圖與索引更新
    public func save(_ document: HeiBanDocument, expectedRevision: Int? = nil, createBackup: Bool = true, generateThumbnail: Bool = true) throws {
        try saveToFile(
            document,
            at: fileURL(id: document.board.id),
            expectedRevision: expectedRevision,
            createBackup: createBackup,
            generateThumbnail: generateThumbnail
        )
    }

    /// 批次寫入並建立 500 張黑板 metadata 索引 (效能壓力測試專用)
    public func batchIndexBoards(_ docs: [HeiBanDocument]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

        var metas: [BoardMetadata] = []
        for doc in docs {
            let targetURL = fileURL(id: doc.board.id)
            let encodedData = try HeiBanDocumentCodec.encode(doc, prettyPrinted: false)
            try encodedData.write(to: targetURL)
            metas.append(doc.board)
        }
        let indexData = try JSONEncoder().encode(metas)
        try indexData.write(to: indexFileURL, options: .atomic)
    }

    private func updateIndex(with board: BoardMetadata) {
        var current = (try? readIndex()) ?? []
        if let idx = current.firstIndex(where: { $0.id == board.id }) {
            current[idx] = board
        } else {
            current.append(board)
        }
        current.sort { $0.updatedAt > $1.updatedAt }
        if let data = try? JSONEncoder().encode(current) {
            try? data.write(to: indexFileURL, options: .atomic)
        }
    }

    private func removeFromIndex(id: String) {
        var current = (try? readIndex()) ?? []
        current.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(current) {
            try? data.write(to: indexFileURL, options: .atomic)
        }
    }

    private func readIndex() throws -> [BoardMetadata] {
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else {
            throw PersistenceError.documentNotFound(id: "index")
        }
        let data = try Data(contentsOf: indexFileURL)
        return try JSONDecoder().decode([BoardMetadata].self, from: data)
    }

    /// 讀取黑板文件
    public func load(id: String) throws -> HeiBanDocument {
        let url = fileURL(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PersistenceError.documentNotFound(id: id)
        }
        do {
            let data = try Data(contentsOf: url)
            return try HeiBanDocumentCodec.decode(from: data)
        } catch {
            throw PersistenceError.fileDamaged(url: url, reason: error.localizedDescription)
        }
    }

    /// 從備份快照還原損壞文件
    public func restoreFromBackup(id: String) throws -> HeiBanDocument {
        let bURL = backupURL(id: id)
        guard FileManager.default.fileExists(atPath: bURL.path) else {
            throw PersistenceError.backupNotFound(id: id)
        }
        let data = try Data(contentsOf: bURL)
        let doc = try HeiBanDocumentCodec.decode(from: data)
        try save(doc, createBackup: false)
        return doc
    }

    /// 檢查資料庫狀態，分離正常檔案與損壞檔案（避免開檔失敗丟失原件）
    public func inspectLibrary() throws -> LibraryInspectionResult {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return LibraryInspectionResult(validBoards: [], damagedFiles: [])
        }

        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".blackboard.json") }

        var validBoards: [BoardMetadata] = []
        var damagedFiles: [DamagedBoardFileInfo] = []

        for file in files {
            do {
                let data = try Data(contentsOf: file)
                let doc = try HeiBanDocumentCodec.decode(from: data)
                validBoards.append(doc.board)
            } catch {
                let baseName = file.deletingPathExtension().deletingPathExtension().lastPathComponent
                let expectedBackup = backupsDirectory.appendingPathComponent(baseName + ".backup.json")
                let hasBackup = FileManager.default.fileExists(atPath: expectedBackup.path)
                damagedFiles.append(DamagedBoardFileInfo(
                    url: file,
                    errorDescription: error.localizedDescription,
                    hasBackup: hasBackup
                ))
            }
        }

        validBoards.sort { $0.updatedAt > $1.updatedAt }
        // Synchronize index
        if let data = try? JSONEncoder().encode(validBoards) {
            try? data.write(to: indexFileURL, options: .atomic)
        }
        return LibraryInspectionResult(validBoards: validBoards, damagedFiles: damagedFiles)
    }

    /// 列出所有有效黑板 (優先讀取 metadata index 避免解碼大檔案物件，A21 規範)
    public func list() throws -> [BoardMetadata] {
        if let indexed = try? readIndex() {
            return indexed
        }
        return try inspectLibrary().validBoards
    }

    /// 搜尋黑板
    public func search(query: String) -> [BoardMetadata] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return (try? list()) ?? [] }
        return (try? list())?.filter { $0.title.localizedCaseInsensitiveContains(cleaned) } ?? []
    }

    /// 取得最近作品
    public func recent(limit: Int = 10) -> [BoardMetadata] {
        let all = (try? list()) ?? []
        return Array(all.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
    }

    /// 製作副本 (具備全新獨立 UUID，A21 規範)
    public func duplicate(id: String, newTitle: String? = nil) throws -> BoardMetadata {
        let original = try load(id: id)
        let newId = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        var newBoard = original.board
        newBoard.id = newId
        newBoard.title = newTitle ?? "\(original.board.title) (副本)"
        newBoard.createdAt = now
        newBoard.updatedAt = now
        newBoard.revision = 1

        let newObjects = original.objects.map { obj -> BoardObject in
            var copy = obj
            copy.id = UUID().uuidString
            copy.boardId = newId
            return copy
        }
        let newDoc = HeiBanDocument(board: newBoard, objects: newObjects)
        try save(newDoc)
        return newBoard
    }

    /// 重新命名黑板
    public func rename(id: String, newTitle: String) throws {
        var doc = try load(id: id)
        doc.board.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        try save(doc)
    }

    /// 移至垃圾桶 (可恢復刪除，A21 規範)
    public func moveToTrash(id: String) throws {
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        let sourceURL = fileURL(id: id)
        let targetURL = trashFileURL(id: id)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw PersistenceError.documentNotFound(id: id)
        }
        if FileManager.default.fileExists(atPath: targetURL.path) {
            throw CocoaError(.fileWriteFileExists)
        }
        try FileManager.default.moveItem(at: sourceURL, to: targetURL)
        removeFromIndex(id: id)
    }

    /// 列出垃圾桶中的黑板
    public func listTrash() throws -> [String] {
        guard FileManager.default.fileExists(atPath: trashDirectory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: trashDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".blackboard.json") }
        var ids: [String] = []
        for file in files {
            if let data = try? Data(contentsOf: file),
               let doc = try? HeiBanDocumentCodec.decode(from: data) {
                ids.append(doc.board.id)
            }
        }
        return ids
    }

    /// 從垃圾桶還原黑板
    public func restoreFromTrash(id: String) throws -> HeiBanDocument {
        let trashURL = trashFileURL(id: id)
        let targetURL = fileURL(id: id)
        guard FileManager.default.fileExists(atPath: trashURL.path) else {
            throw PersistenceError.documentNotFound(id: id)
        }
        if FileManager.default.fileExists(atPath: targetURL.path) {
            throw PersistenceError.revisionConflict(current: (try? load(id: id).board.revision) ?? 1, incoming: 0)
        }
        _ = try HeiBanDocumentCodec.decode(from: Data(contentsOf: trashURL))
        try FileManager.default.moveItem(at: trashURL, to: targetURL)
        let doc = try load(id: id)
        updateIndex(with: doc.board)
        return doc
    }

    /// 讀取可還原的作品中繼資料。
    public func trashBoards() throws -> [BoardMetadata] {
        guard FileManager.default.fileExists(atPath: trashDirectory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: trashDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".blackboard.json") }
            .compactMap { url in (try? HeiBanDocumentCodec.decode(from: Data(contentsOf: url)))?.board }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 清空垃圾桶。
    public func emptyTrash() throws {
        guard FileManager.default.fileExists(atPath: trashDirectory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: trashDirectory, includingPropertiesForKeys: nil)
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    public func delete(id: String) throws {
        let documentURL = fileURL(id: id)
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            throw PersistenceError.documentNotFound(id: id)
        }
        try FileManager.default.removeItem(at: documentURL)
        try? FileManager.default.removeItem(at: backupURL(id: id))
        try? FileManager.default.removeItem(at: thumbnailURL(id: id))
        removeFromIndex(id: id)
    }
}
