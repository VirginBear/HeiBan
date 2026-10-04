import Foundation

public enum ExternalConflictState: Equatable {
    case none
    case conflict
    case fileDeletedExternally
}

public final class DocumentCoordinator {
    public let documentURL: URL
    public private(set) var lastSelfSaveData: Data?
    public private(set) var lastSelfSaveDate: Date?

    public init(documentURL: URL) {
        self.documentURL = documentURL
    }

    public func recordSelfSave(contentData: Data) {
        self.lastSelfSaveData = contentData
        self.lastSelfSaveDate = Date()
    }

    public func checkExternalChange(currentInMemoryData: Data) -> ExternalConflictState {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return .fileDeletedExternally
        }

        guard let onDiskData = try? Data(contentsOf: documentURL) else {
            return .none
        }

        // 1. If disk data equals our recorded self-save data, it's a deduplicated self-save event
        if let lastSave = lastSelfSaveData, onDiskData == lastSave {
            return .none
        }

        // 2. If disk data equals current in-memory data, no divergence
        if onDiskData == currentInMemoryData {
            return .none
        }

        // 3. Disk data diverged from last saved data while memory also diverged or has uncommitted work
        if let lastSave = lastSelfSaveData {
            if onDiskData != lastSave && currentInMemoryData != lastSave {
                return .conflict
            }
        } else {
            // First time tracking, but contents diverge
            return .conflict
        }

        return .none
    }
}

public struct WorkspaceFileInfo: Identifiable, Equatable {
    public var id: String { url.path }
    public var name: String
    public var url: URL
    public var updatedAt: Date

    public init(name: String, url: URL, updatedAt: Date) {
        self.name = name
        self.url = url
        self.updatedAt = updatedAt
    }
}

public final class WorkspaceRepository {
    public let folderURL: URL

    public init(folderURL: URL) {
        self.folderURL = folderURL
    }

    public func listBlackboardFiles() throws -> [WorkspaceFileInfo] {
        guard FileManager.default.fileExists(atPath: folderURL.path) else { return [] }
        let resolvedFolder = folderURL.resolvingSymlinksInPath()
        let urls = try FileManager.default.contentsOfDirectory(at: resolvedFolder, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.lastPathComponent.hasSuffix(".blackboard.json") || $0.lastPathComponent.hasSuffix(".heiban") }

        var results: [WorkspaceFileInfo] = []
        for u in urls {
            let resourceValues = try? u.resourceValues(forKeys: [.contentModificationDateKey])
            let mtime = resourceValues?.contentModificationDate ?? Date()
            let name = u.deletingPathExtension().lastPathComponent
            results.append(WorkspaceFileInfo(name: name, url: u.resolvingSymlinksInPath(), updatedAt: mtime))
        }
        return results.sorted { $0.updatedAt > $1.updatedAt }
    }
}

public final class DocumentSession: Identifiable {
    public let id: String
    public var fileURL: URL
    public let engine: BoardEngine
    public let coordinator: DocumentCoordinator

    public init(id: String = UUID().uuidString, fileURL: URL, engine: BoardEngine) {
        self.id = id
        self.fileURL = fileURL
        self.engine = engine
        self.coordinator = DocumentCoordinator(documentURL: fileURL)
    }

    public func save() throws {
        let data = try HeiBanDocumentCodec.encode(engine.document, prettyPrinted: true)
        try data.write(to: fileURL, options: .atomic)
        coordinator.recordSelfSave(contentData: data)
    }

    public func saveAs(to newURL: URL, repointSession: Bool = false) throws {
        let data = try HeiBanDocumentCodec.encode(engine.document, prettyPrinted: true)
        try data.write(to: newURL, options: .atomic)
        if repointSession {
            self.fileURL = newURL
        }
    }

    public func resolveConflictWithReload() throws {
        let data = try Data(contentsOf: fileURL)
        let loaded = try HeiBanDocumentCodec.decode(from: data)
        engine.board = loaded.board
        engine.objects = loaded.objects.sorted { $0.zIndex < $1.zIndex }
        coordinator.recordSelfSave(contentData: data)
    }
}

public final class DocumentSessionManager {
    public private(set) var activeSessions: [DocumentSession] = []

    public init() {}

    public func openDocument(at url: URL) throws -> DocumentSession {
        if let existing = activeSessions.first(where: { $0.fileURL.standardizedFileURL == url.standardizedFileURL }) {
            return existing
        }

        let data = try Data(contentsOf: url)
        let doc = try HeiBanDocumentCodec.decode(from: data)
        let engine = BoardEngine(restoreSession: false)
        engine.board = doc.board
        engine.objects = doc.objects.sorted { $0.zIndex < $1.zIndex }

        let session = DocumentSession(fileURL: url, engine: engine)
        session.coordinator.recordSelfSave(contentData: data)
        activeSessions.append(session)
        return session
    }

    public func closeSession(id: String) {
        activeSessions.removeAll { $0.id == id }
    }
}
