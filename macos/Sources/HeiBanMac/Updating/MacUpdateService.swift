import AppKit
import HeiBanCore

/// 讀取官方已發布的 Mac 發行資料；檢查失敗或本地版較新時不降版。
/// 安裝仍由使用者在官方發行頁選擇，避免未公證開發版在背景替換執行中的 App。
@MainActor
final class MacUpdateService: ObservableObject {
    static let shared = MacUpdateService()
    @Published private(set) var busy = false
    @Published private(set) var status = "尚未檢查更新"
    @Published private(set) var latest: MacGitHubRelease?
    @Published private(set) var lastChecked: Date?
    @Published var automaticallyCheck: Bool {
        didSet { UserDefaults.standard.set(automaticallyCheck, forKey: "HeiBan.updates.checkAutomatically") }
    }
    @Published var includePreview: Bool {
        didSet { UserDefaults.standard.set(includePreview, forKey: "HeiBan.updates.includePreview"); latest = nil; status = "尚未檢查更新" }
    }
    private var generation = 0

    init() {
        let defaults = UserDefaults.standard
        automaticallyCheck = defaults.object(forKey: "HeiBan.updates.checkAutomatically") as? Bool ?? true
        includePreview = defaults.object(forKey: "HeiBan.updates.includePreview") as? Bool ?? true
    }
    var updateAvailable: Bool {
        guard let latest, let remote = MacReleaseVersion(latest.tag_name), let local = MacReleaseVersion(AboutInfo.appVersion) else { return false }
        return local < remote
    }
    func checkOnLaunch() async { if automaticallyCheck { await check() } }
    func check() async {
        guard !busy else { return }
        busy = true
        generation += 1
        let token = generation
        let previews = includePreview
        status = "正在檢查 GitHub 更新…"
        defer { busy = false }
        do {
            var releases: [MacGitHubRelease] = []
            for page in 1...10 {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/VirginBear/HeiBan/releases?per_page=100&page=\(page)")!)
                request.setValue("HeiBan-macOS/\(AboutInfo.appVersion)", forHTTPHeaderField: "User-Agent")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= 4 * 1024 * 1024 else {
                    throw URLError(.badServerResponse)
                }
                let batch = try JSONDecoder().decode([MacGitHubRelease].self, from: data)
                releases += batch
                if batch.count < 100 { break }
            }
            guard token == generation, previews == includePreview else { return }
            #if arch(arm64)
            let architecture = "arm64"
            #else
            let architecture = "x64"
            #endif
            latest = MacGitHubRelease.select(releases, includePreview: previews, architecture: architecture)
            lastChecked = Date()
            guard let latest else { status = "所選管道尚無相容的 Mac 發行版"; return }
            let local = MacReleaseVersion(AboutInfo.appVersion)
            let remote = MacReleaseVersion(latest.tag_name)
            status = updateAvailable ? "有新的 Mac 版本可下載" : local != nil && remote != nil && remote! < local!
                ? "本機開發版較新，保留目前版本" : "目前已是所選更新管道的最新版本。"
        } catch {
            latest = nil
            status = "目前無法連線到 GitHub，下次再試；可繼續使用目前版本。"
        }
    }
    func openRelease() {
        guard let latest else { return }
        NSWorkspace.shared.open(latest.html_url)
    }
}
