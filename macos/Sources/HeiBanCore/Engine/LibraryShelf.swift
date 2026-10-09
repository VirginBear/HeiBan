import Foundation
import SwiftUI

/// Local library organization is separate from editable board content and revisions.
public final class LibraryShelf: ObservableObject {
    @Published public private(set) var favorites: Set<String> = []
    @Published public private(set) var errorMessage: String?
    private let url: URL
    private struct Record: Codable { var version = 1; var favorites: Set<String> }

    public init(library: LocalBoardLibrary) {
        url = library.directory.deletingLastPathComponent().appendingPathComponent("Settings/library_shelf.json")
        reload()
    }
    public func reload() {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
                guard record.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                favorites = record.favorites
            } else { favorites = [] }
            errorMessage = nil
        } catch { errorMessage = "無法讀取收藏設定：\(error.localizedDescription)" }
    }
    public func toggleFavorite(_ id: String) {
        reload()
        guard errorMessage == nil else { return }
        var next = favorites
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Record(favorites: next)).write(to: url, options: .atomic)
            favorites = next
        } catch { errorMessage = "收藏未儲存：\(error.localizedDescription)" }
    }
}
