import Darwin
import Foundation
import HeiBanCore

/// 供應範本與使用者練習是兩個擁有者：範本只能建立新作品，不能覆蓋既有作品。
struct QuickStartGuideStore {
    static let defaultID = "heiban-macos-quickstart-v3"
    let library: LocalBoardLibrary
    private var settingsDirectory: URL {
        library.directory.deletingLastPathComponent().appendingPathComponent("Settings", isDirectory: true)
    }
    private var markerURL: URL { settingsDirectory.appendingPathComponent("quickstart-macos-v3.json") }
    private struct Marker: Codable {
        let schema: Int
        let boardID: String
    }

    func installOnFirstLaunch(template: () throws -> HeiBanDocument) throws {
        // 舊Mac v2已建立或已刪除的練習不自動重生；使用者可手動建立新的Mac指南。
        guard !FileManager.default.fileExists(atPath: markerURL.path),
            !FileManager.default.fileExists(
                atPath: settingsDirectory.appendingPathComponent("quickstart-v2.json").path)
        else { return }
        let exists =
            FileManager.default.fileExists(atPath: library.fileURL(id: Self.defaultID).path)
            || FileManager.default.fileExists(atPath: library.trashFileURL(id: Self.defaultID).path)
        if exists {
            try writeMarker(id: Self.defaultID)
            return
        }
        _ = try create(template: template, id: Self.defaultID)
    }

    func openOrCreate(template: () throws -> HeiBanDocument) throws -> String {
        var candidates: [String] = []
        if let data = try? Data(contentsOf: markerURL),
            let marker = try? JSONDecoder().decode(Marker.self, from: data),
            marker.boardID.hasPrefix(Self.defaultID)
        {
            candidates.append(marker.boardID)
        }
        candidates.append(Self.defaultID)
        for id in candidates where FileManager.default.fileExists(atPath: library.fileURL(id: id).path) {
            // 即使文件損壞也不以範本覆蓋；交由正常載入的錯誤／備份流程處理。
            return id
        }
        let id =
            FileManager.default.fileExists(atPath: markerURL.path)
                || FileManager.default.fileExists(atPath: library.trashFileURL(id: Self.defaultID).path)
            ? Self.defaultID + "-" + UUID().uuidString : Self.defaultID
        return try create(template: template, id: id)
    }

    func createFresh(template: () throws -> HeiBanDocument) throws -> String {
        try create(template: template, id: Self.defaultID + "-" + UUID().uuidString)
    }

    private func create(template: () throws -> HeiBanDocument, id: String) throws -> String {
        var doc = try template()
        let now = ISO8601DateFormatter().string(from: Date())
        doc.board.id = id
        doc.board.createdAt = now
        doc.board.updatedAt = now
        doc.board.revision = 1
        for i in doc.objects.indices { doc.objects[i].boardId = id }
        if var pins = doc.board.pins {
            for i in pins.indices { pins[i].boardId = id }
            doc.board.pins = pins
        }
        // advisory lock的生命週期跟隨process/fd，崩潰不會留下永久鎖目錄。
        // 既有LocalBoardLibrary的expectedRevision尚未執行CAS，不能依賴該參數防覆寫。
        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        let lockURL = settingsDirectory.appendingPathComponent("quickstart-macos-v3.lock")
        let fd = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { Darwin.close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw CocoaError(.fileLocking) }
        defer { flock(fd, LOCK_UN) }
        guard !FileManager.default.fileExists(atPath: library.fileURL(id: id).path),
            !FileManager.default.fileExists(atPath: library.trashFileURL(id: id).path)
        else { throw CocoaError(.fileWriteFileExists) }
        try library.save(doc)
        try writeMarker(id: id)
        return id
    }

    private func writeMarker(id: String) throws {
        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(Marker(schema: 3, boardID: id)).write(to: markerURL, options: .atomic)
    }
}
