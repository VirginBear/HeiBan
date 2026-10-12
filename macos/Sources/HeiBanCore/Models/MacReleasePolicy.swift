import Foundation

/// GitHub 同一個 repository 有不同平台的 releases；只接受 macos-v 標籤與 Mac 套件。
/// 比較發行版本，不把 commit 數／build 日期當成可下載的新版本。
public struct MacReleaseVersion: Comparable, Equatable {
    public let numbers: [Int]
    public let preview: [String]?
    public init?(_ raw: String) {
        let value = raw.hasPrefix("macos-v") ? String(raw.dropFirst(7)) : raw
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = parts.first, !core.isEmpty else { return nil }
        let components = core.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3, components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts.count == 1 || !parts[1].isEmpty else { return nil }
        let numbers = components.compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        self.numbers = numbers
        preview = parts.count == 2 ? parts[1].split(separator: ".").map(String.init) : nil
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.numbers != rhs.numbers { return lhs.numbers.lexicographicallyPrecedes(rhs.numbers) }
        guard let left = lhs.preview else { return false }
        guard let right = rhs.preview else { return true }
        for (a, b) in zip(left, right) where a != b {
            if let an = Int(a), let bn = Int(b) { return an < bn }
            if Int(a) != nil { return true }
            if Int(b) != nil { return false }
            return a < b
        }
        return left.count < right.count
    }
}

public struct MacGitHubRelease: Decodable {
    public struct Asset: Decodable {
        public let name: String
        public let browser_download_url: URL
    }
    public let tag_name: String
    public let html_url: URL
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]

    public var version: String { String(tag_name.dropFirst(7)) }
    public static func select(_ releases: [Self], includePreview: Bool, architecture: String) -> Self? {
        releases.filter { release in
            !release.draft && (includePreview || !release.prerelease)
                && release.tag_name.hasPrefix("macos-v")
                && MacReleaseVersion(release.tag_name) != nil
                && release.html_url.scheme == "https" && release.html_url.host == "github.com"
                && release.html_url.path.hasPrefix("/VirginBear/HeiBan/releases/tag/macos-v")
                && release.assets.contains { asset in
                    asset.name.hasPrefix("HeiBan-macOS-")
                        && (asset.name.contains("-\(architecture).") || asset.name.contains("-universal."))
                        && ["zip", "dmg"].contains(asset.browser_download_url.pathExtension.lowercased())
                        && asset.browser_download_url.scheme == "https" && asset.browser_download_url.host == "github.com"
                        && asset.browser_download_url.path.hasPrefix("/VirginBear/HeiBan/releases/download/")
                }
        }.max { MacReleaseVersion($0.tag_name)! < MacReleaseVersion($1.tag_name)! }
    }
}
