import Foundation

public struct SyncMutation: Codable, Equatable, Identifiable {
    public var id: String
    public var boardId: String
    public var baseRevision: Int
    public var timestamp: String
    public var insertedObjects: [BoardObject]
    public var deletedObjectIds: [String]
    public var updatedMetadata: BoardMetadata?

    public init(
        id: String = UUID().uuidString,
        boardId: String,
        baseRevision: Int,
        timestamp: String = ISO8601DateFormatter().string(from: Date()),
        insertedObjects: [BoardObject] = [],
        deletedObjectIds: [String] = [],
        updatedMetadata: BoardMetadata? = nil
    ) {
        self.id = id
        self.boardId = boardId
        self.baseRevision = baseRevision
        self.timestamp = timestamp
        self.insertedObjects = insertedObjects
        self.deletedObjectIds = deletedObjectIds
        self.updatedMetadata = updatedMetadata
    }
}

public protocol CloudSyncTransport: AnyObject {
    func pushMutation(_ mutation: SyncMutation) throws -> Int
    func pullLatestDocument(boardId: String) throws -> HeiBanDocument?
    var isOnline: Bool { get set }
}

public enum SyncCoordinatorStatus: Equatable {
    case idle
    case syncing(pendingCount: Int)
    case synced(lastSyncTime: Date)
    case offline(pendingCount: Int)
    case conflictResolved(copyTitle: String)
    case failed(error: String)
}

public final class CloudSyncCoordinator {
    public let transport: CloudSyncTransport
    public let queueDirectory: URL
    private let queueFileURL: URL
    private let library: LocalBoardLibrary

    public private(set) var queue: [SyncMutation] = []
    public private(set) var status: SyncCoordinatorStatus = .idle

    public init(
        // 明確注入實際／檢查 transport；正式核心不能默默選用記憶體假雲端。
        transport: CloudSyncTransport,
        queueDirectory: URL? = nil,
        library: LocalBoardLibrary = LocalBoardLibrary()
    ) {
        self.transport = transport
        self.library = library
        let dir =
            queueDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HeiBan/SyncQueue", isDirectory: true)
        self.queueDirectory = dir
        self.queueFileURL = dir.appendingPathComponent("queue.json")

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        loadQueueFromDisk()
    }

    private func loadQueueFromDisk() {
        if let data = try? Data(contentsOf: queueFileURL),
            let loaded = try? JSONDecoder().decode([SyncMutation].self, from: data)
        {
            self.queue = loaded
        } else {
            self.queue = []
        }
        updateStatus()
    }

    private func saveQueueToDisk() {
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: queueFileURL, options: .atomic)
        }
        updateStatus()
    }

    public func enqueue(mutation: SyncMutation) {
        queue.append(mutation)
        saveQueueToDisk()
        if transport.isOnline {
            _ = drainQueue()
        }
    }

    @discardableResult
    public func drainQueue() -> Bool {
        guard transport.isOnline else {
            updateStatus()
            return false
        }

        guard !queue.isEmpty else {
            status = .synced(lastSyncTime: Date())
            return true
        }

        status = .syncing(pendingCount: queue.count)
        var uncommitted: [SyncMutation] = []

        for mutation in queue {
            do {
                _ = try transport.pushMutation(mutation)
            } catch {
                uncommitted.append(mutation)
            }
        }

        queue = uncommitted
        saveQueueToDisk()

        if queue.isEmpty {
            status = .synced(lastSyncTime: Date())
            return true
        } else {
            status = .offline(pendingCount: queue.count)
            return false
        }
    }

    public func syncDocument(localDocument: inout HeiBanDocument) throws -> HeiBanDocument {
        guard transport.isOnline else {
            updateStatus()
            return localDocument
        }

        // 1. Drain pending queue first
        drainQueue()

        // 2. Pull remote latest
        guard let remoteDoc = try transport.pullLatestDocument(boardId: localDocument.board.id) else {
            // 雲端尚無此文件，以本機文件推播為初版
            let initialMutation = SyncMutation(
                boardId: localDocument.board.id,
                baseRevision: localDocument.board.revision ?? 1,
                insertedObjects: localDocument.objects,
                updatedMetadata: localDocument.board
            )
            enqueue(mutation: initialMutation)
            return localDocument
        }

        let localRev = localDocument.board.revision ?? 1
        let remoteRev = remoteDoc.board.revision ?? 1

        if remoteRev > localRev {
            // 衝突判定：若本機有尚未同步之變更且雲端版本不同，建立衝突副本保護資料 (A29 規範)
            if !queue.isEmpty || localDocument.objects != remoteDoc.objects {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd-HHmmss"
                let dateStr = formatter.string(from: Date())
                let copyTitle = "\(localDocument.board.title) (衝突副本 - \(dateStr))"

                var conflictCopy = localDocument
                conflictCopy.board.id = UUID().uuidString
                conflictCopy.board.title = copyTitle
                conflictCopy.board.revision = 1
                try? library.save(conflictCopy)

                status = .conflictResolved(copyTitle: copyTitle)
            }

            // 本地套用雲端最新資料
            localDocument = remoteDoc
        }

        return localDocument
    }

    private func updateStatus() {
        if !transport.isOnline {
            status = .offline(pendingCount: queue.count)
        } else if queue.isEmpty {
            if case .synced = status {} else { status = .idle }
        } else {
            status = .syncing(pendingCount: queue.count)
        }
    }
}
