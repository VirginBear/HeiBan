import Foundation

public enum CollaboratorRole: String, Codable, CaseIterable {
    case owner = "owner"
    case editor = "editor"
    case viewer = "viewer"

    public var canEdit: Bool {
        self == .owner || self == .editor
    }
}

public struct CollaboratorInfo: Codable, Equatable, Identifiable {
    public var id: String { userId }
    public var userId: String
    public var name: String
    public var role: CollaboratorRole
    public var colorHex: String
    public var joinedAt: String

    public init(userId: String, name: String, role: CollaboratorRole, colorHex: String, joinedAt: String = ISO8601DateFormatter().string(from: Date())) {
        self.userId = userId
        self.name = name
        self.role = role
        self.colorHex = colorHex
        self.joinedAt = joinedAt
    }
}

public struct UserPresence: Codable, Equatable, Identifiable {
    public var id: String { userId }
    public var userId: String
    public var userName: String
    public var colorHex: String
    public var cursorPosition: Point
    public var isDrawing: Bool
    public var activeTool: String?
    public var activeStrokePoints: [Point]?
    public var lastSeen: Date

    public init(
        userId: String,
        userName: String,
        colorHex: String,
        cursorPosition: Point = Point(x: 0, y: 0),
        isDrawing: Bool = false,
        activeTool: String? = nil,
        activeStrokePoints: [Point]? = nil,
        lastSeen: Date = Date()
    ) {
        self.userId = userId
        self.userName = userName
        self.colorHex = colorHex
        self.cursorPosition = cursorPosition
        self.isDrawing = isDrawing
        self.activeTool = activeTool
        self.activeStrokePoints = activeStrokePoints
        self.lastSeen = lastSeen
    }

    public var isExpired: Bool {
        Date().timeIntervalSince(lastSeen) > 10.0 // 10 秒心跳超時
    }
}

public enum RoomJoinResult: Equatable {
    case success(role: CollaboratorRole)
    case capacityExceeded(maxAllowed: Int)
    case accessDenied(reason: String)
}

public final class CollaborationRoom {
    public let boardId: String
    public let maxParticipants: Int = 10
    public var presencesTTL: TimeInterval = 10.0

    public private(set) var ownerId: String
    public private(set) var collaborators: [String: CollaboratorInfo] = [:]
    public private(set) var activePresences: [String: UserPresence] = [:]
    public private(set) var shareLinks: [String: CollaboratorRole] = [:]

    // 顯示開關 (A30 規範：可關閉呈現且不影響他人編輯)
    public var showCollaboratorCursors: Bool = true
    public var showCollaboratorTrajectories: Bool = true

    public init(boardId: String, ownerId: String, ownerName: String = "擁有人") {
        self.boardId = boardId
        self.ownerId = ownerId
        self.collaborators[ownerId] = CollaboratorInfo(
            userId: ownerId,
            name: ownerName,
            role: .owner,
            colorHex: "#22c55e"
        )
    }

    public func createShareLink(role: CollaboratorRole = .editor) -> String {
        let token = "share_" + UUID().uuidString.prefix(12)
        shareLinks[token] = role
        return "https://heiban.app/join/\(boardId)?token=\(token)"
    }

    public func revokeShareLink(token: String) {
        shareLinks.removeValue(forKey: token)
    }

    public func revokeCollaborator(userId: String) -> Bool {
        guard userId != ownerId else { return false }
        collaborators.removeValue(forKey: userId)
        activePresences.removeValue(forKey: userId)
        return true
    }

    public func joinRoom(userId: String, userName: String, shareToken: String? = nil) -> RoomJoinResult {
        // 1. 若已經是授權成員
        if let existing = collaborators[userId] {
            return .success(role: existing.role)
        }

        // 2. 檢查人數上限 (至多十人服務端嚴格限制，A30 規範)
        let activeEditorCount = collaborators.values.filter { $0.role.canEdit }.count
        if activeEditorCount >= maxParticipants {
            return .capacityExceeded(maxAllowed: maxParticipants)
        }

        // 3. 透過 Share Token 加入
        var assignedRole: CollaboratorRole = .viewer
        if let token = shareToken, let role = shareLinks[token] {
            assignedRole = role
        } else if shareToken == nil {
            assignedRole = .editor
        } else {
            return .accessDenied(reason: "無效或已撤銷的邀請連結")
        }

        let palette = ["#3b82f6", "#ec4899", "#8b5cf6", "#f59e0b", "#10b981", "#06b6d4", "#f97316", "#e11d48", "#14b8a6", "#6366f1"]
        let color = palette[collaborators.count % palette.count]

        let info = CollaboratorInfo(userId: userId, name: userName, role: assignedRole, colorHex: color)
        collaborators[userId] = info
        return .success(role: assignedRole)
    }

    public func updatePresence(
        userId: String,
        cursorPosition: Point,
        isDrawing: Bool = false,
        activeTool: String? = nil,
        activeStrokePoints: [Point]? = nil
    ) {
        guard let collab = collaborators[userId] else { return }

        let presence = UserPresence(
            userId: userId,
            userName: collab.name,
            colorHex: collab.colorHex,
            cursorPosition: cursorPosition,
            isDrawing: isDrawing,
            activeTool: activeTool,
            activeStrokePoints: activeStrokePoints,
            lastSeen: Date()
        )
        activePresences[userId] = presence
    }

    public func leaveRoom(userId: String) {
        activePresences.removeValue(forKey: userId)
    }

    public func pruneExpiredPresences(referenceDate: Date = Date()) {
        let expired = activePresences.filter { referenceDate.timeIntervalSince($0.value.lastSeen) > presencesTTL }.map(\.key)
        for uid in expired {
            activePresences.removeValue(forKey: uid)
        }
    }
}

public final class ConvergenceEngine {
    /// 依據最後寫入者獲勝 (LWW) 與時間戳記收斂多端並發操作，保證 10 個客戶端收斂到 100% 相同的文件
    public static func convergeDocument(
        baseDocument: HeiBanDocument,
        incomingMutations: [SyncMutation]
    ) -> HeiBanDocument {
        var doc = baseDocument
        var objMap: [String: BoardObject] = [:]
        for obj in doc.objects {
            objMap[obj.id] = obj
        }

        // 依據時間戳與 mutation ID 排序，保證各客戶端套用順序確定性一致
        let sortedMutations = incomingMutations.sorted {
            if $0.timestamp == $1.timestamp {
                return $0.id < $1.id
            }
            return $0.timestamp < $1.timestamp
        }

        var deletedIds: Set<String> = []

        for mut in sortedMutations {
            for delId in mut.deletedObjectIds {
                deletedIds.insert(delId)
                objMap.removeValue(forKey: delId)
            }

            for inserted in mut.insertedObjects {
                // 若物件先前已被刪除，且插入時間早於或等於刪除時間，則不復原
                if deletedIds.contains(inserted.id) {
                    continue
                }
                objMap[inserted.id] = inserted
            }

            if let meta = mut.updatedMetadata {
                doc.board.title = meta.title
                doc.board.boardTheme = meta.boardTheme
                doc.board.backgroundColor = meta.backgroundColor
            }
        }

        doc.objects = Array(objMap.values).sorted(by: {
            if $0.zIndex == $1.zIndex {
                return $0.id < $1.id
            }
            return $0.zIndex < $1.zIndex
        })
        let maxRev = incomingMutations.map(\.baseRevision).max() ?? (doc.board.revision ?? 1)
        doc.board.revision = maxRev + 1
        return doc
    }
}
