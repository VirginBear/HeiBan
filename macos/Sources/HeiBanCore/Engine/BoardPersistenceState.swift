import Foundation

/// 非 UI 的保存生命週期；跨檔延伸方法共用，但不暴露給 HeiBanMac。
/// 所有實例共用串行 queue，避免離開作品時被較舊的背景快照覆寫。
final class BoardPersistenceState {
    struct DocumentHeader {
        let schemaVersion: String
        let version: String
        let extraFields: [String: AnyCodableValue]?

        init(_ document: HeiBanDocument) {
            schemaVersion = document.schemaVersion
            version = document.version
            extraFields = document.extraFields
        }
    }

    static let queue = DispatchQueue(label: "com.bear.HeiBan.autosave", qos: .utility)
    let enabled: Bool
    var header: DocumentHeader?
    var workItem: DispatchWorkItem?
    var generation = 0

    init(enabled: Bool) { self.enabled = enabled }

    deinit { workItem?.cancel() }
}

public enum BoardSaveFeedbackState: Equatable, Sendable {
    case saved(detail: String)
    case saving
    case unsaved
    case failed(detail: String)

    public static func resolve(status: String) -> BoardSaveFeedbackState {
        if status.contains("失敗") || status.contains("無法") {
            return .failed(detail: status)
        }
        if status == "儲存中…" || status == "儲存中" {
            return .saving
        }
        if status.contains("本機已儲存") || status.contains("已還原上次工作") {
            return .saved(detail: status)
        }
        return .unsaved
    }
}

