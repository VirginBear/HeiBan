import Foundation
import HeiBanCore

/// 既有檢查使用的記憶體替身，不能作為正式登入／雲端實作。
public final class MockCloudSyncTransport: CloudSyncTransport {
    public var isOnline: Bool = true
    public var remoteRevisions: [String: Int] = [:]
    public var remoteDocuments: [String: HeiBanDocument] = [:]
    public var receivedMutationIds: Set<String> = []
    public var onMutationPushed: ((SyncMutation) -> Void)?

    public init() {}

    public func pushMutation(_ mutation: SyncMutation) throws -> Int {
        guard isOnline else {
            throw NSError(domain: "HeiBanSync", code: 503, userInfo: [NSLocalizedDescriptionKey: "網路離線中"])
        }

        // 冪等性去重保證：重複的 mutationId 不會引發二次寫入
        if receivedMutationIds.contains(mutation.id) {
            return remoteRevisions[mutation.boardId] ?? mutation.baseRevision
        }

        receivedMutationIds.insert(mutation.id)
        let currentRev = remoteRevisions[mutation.boardId] ?? mutation.baseRevision
        let newRev = currentRev + 1
        remoteRevisions[mutation.boardId] = newRev

        var doc =
            remoteDocuments[mutation.boardId]
            ?? HeiBanDocument(
                board: mutation.updatedMetadata
                    ?? BoardMetadata(id: mutation.boardId, title: "雲端黑板", revision: newRev),
                objects: []
            )
        doc.board.revision = newRev
        if let meta = mutation.updatedMetadata {
            doc.board = meta
            doc.board.revision = newRev
        }

        let delSet = Set(mutation.deletedObjectIds)
        doc.objects.removeAll(where: { delSet.contains($0.id) })

        for obj in mutation.insertedObjects {
            if let idx = doc.objects.firstIndex(where: { $0.id == obj.id }) {
                doc.objects[idx] = obj
            } else {
                doc.objects.append(obj)
            }
        }

        remoteDocuments[mutation.boardId] = doc
        onMutationPushed?(mutation)
        return newRev
    }

    public func pullLatestDocument(boardId: String) throws -> HeiBanDocument? {
        guard isOnline else {
            throw NSError(domain: "HeiBanSync", code: 503, userInfo: [NSLocalizedDescriptionKey: "網路離線中"])
        }
        return remoteDocuments[boardId]
    }
}
