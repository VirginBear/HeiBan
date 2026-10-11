import Foundation

public enum AppTheme: String, Codable, CaseIterable {
    case system = "system"
    case blackboard = "blackboard"
    case whiteboard = "whiteboard"

    public var displayName: String {
        switch self {
        case .system: return "跟隨系統"
        case .blackboard: return "經典黑板 (深色)"
        case .whiteboard: return "清晰白板 (淺色)"
        }
    }
}

public enum AutoSaveFrequency: Double, Codable, CaseIterable {
    case fast = 5.0
    case standard = 15.0
    case relaxed = 30.0
    case slow = 60.0
    case manual = 0.0

    public var displayName: String {
        switch self {
        case .fast: return "即時 (5 秒)"
        case .standard: return "標準 (15 秒)"
        case .relaxed: return "緩和 (30 秒)"
        case .slow: return "節能 (60 秒)"
        case .manual: return "僅手動存檔"
        }
    }
}

public enum CloudSyncState: Equatable {
    case localOnly(reason: String)
    case unauthenticated(message: String)
    case authenticating
    case synced(lastSyncTime: Date)
    case syncing(progress: Double)
    case syncFailed(error: String, retryCount: Int)
    case offline(pendingCount: Int)

    public var displayName: String {
        switch self {
        case .localOnly: return "本機安全儲存"
        case .unauthenticated: return "未登入帳號"
        case .authenticating: return "帳號驗證中..."
        case .synced: return "已完成同步"
        case .syncing: return "雲端同步中..."
        case .syncFailed: return "同步失敗"
        case .offline: return "離線模式"
        }
    }

    public var statusDescription: String {
        switch self {
        case .localOnly(let reason): return reason
        case .unauthenticated(let msg): return msg
        case .authenticating: return "正在與 Google 服務建立安全連線..."
        case .synced(let time):
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return "上次同步：\(f.string(from: time))"
        case .syncing(let progress): return "正在傳輸變更：\(Int(progress * 100))%"
        case .syncFailed(let err, let count): return "錯誤：\(err)（已重試 \(count) 次）"
        case .offline(let count): return "網路離線，累積 \(count) 筆未同步修訂"
        }
    }
}

public struct ChangelogEntry: Codable, Equatable, Identifiable {
    public var id: String { version }
    public var version: String
    public var releaseDate: String
    public var highlights: [String]

    public init(version: String, releaseDate: String, highlights: [String]) {
        self.version = version
        self.releaseDate = releaseDate
        self.highlights = highlights
    }
}

public struct AboutInfo: Equatable {
    public static let appName = "HeiBan 黑板"
    public static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.12"
    }
    public static var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "20261010.4"
    }
    public static let engineVersion = "HeiBan Blackboard Vector Engine 1.0"
    public static let copyright = "© 2026 HeiBan Team. All rights reserved."
    public static let feedbackUrl = "https://github.com/VirginBear/HeiBan/issues"
    public static let supportEmail = "support@heiban.app"

    public static let changelog: [ChangelogEntry] = [
        ChangelogEntry(version: "1.0.12", releaseDate: "2026-10-10", highlights: [
            "「我的螢幕就是我的畫布」新增原生文字框 (T) 輸入、換行與 ⌘Enter 提交",
            "文字框原地右鍵支援快捷文字大小、自訂顏色與「更多文字設定」面板",
            "支援 Shift/框選多個文字框批次調整格式，混合欄位獨立套用且單次 Undo 復原"
        ]),
        ChangelogEntry(version: "1.0.5", releaseDate: "2026-10-09", highlights: [
            "截圖改用原生 ScreenCaptureKit，支援系統選取授權與區域框選",
            "截圖失敗顯示原因，取消不再誤貼剪貼簿，封裝時簽署完整 App"
        ]),
        ChangelogEntry(version: "1.0.4", releaseDate: "2026-10-09", highlights: [
            "屬性標籤與標題可拖曳到四邊停靠，記住位置",
            "畫布與作品庫的選單箭頭改用一致間距",
            "滑鼠滾輪以游標位置為中心縮放；觸控板保持雙指平移與捏合縮放"
        ]),
        ChangelogEntry(version: "1.0.1", releaseDate: "2026-10-08", highlights: [
            "採用繁體手寫「黑板」Logo，首頁、關於及 App 圖示統一",
            "首頁改為作品優先；新增畫布設定集中在新增視窗",
            "原創斜向圖釘統一外觀；首頁標示三種畫布格式"
        ]),
        ChangelogEntry(
            version: "1.0.0",
            releaseDate: "2026-10-03",
            highlights: [
                "原生 macOS 黑板與白板雙主題，符合 WCAG 2.1 AA 高對比度標準",
                "無限畫布與固定紙張畫布（A4 / A3 / 16:9 / 4:3）自由切換",
                "GoodNotes 級 Hold-to-Shape 智慧轉形與平滑 Catmull-Rom 筆跡",
                "向量橡皮擦（全物件與向量筆劃分割，絕非點陣遮罩）",
                "富文本原地編輯器（粗體/斜體/底線/刪除線/高亮/色彩）與多輸入法 IME 相容",
                "6 款手繪便簽（經典/和紙/貓咪/活頁/方格/柔和卡片）與自動約束",
                "畫布實體圖釘與左上快速導航（20% 舒適書寫視野錨定）",
                "純向量 SVG / PDF / PNG 多格式與選取範圍輸出，自產 PDF 內嵌 100% 往返可編輯資料",
                "非破壞性 8 向圖片裁切與多螢幕截圖安全防誤貼機制",
                "本機 500+ 作品毫秒級快速搜尋與縮圖快取索引"
            ]
        ),
        ChangelogEntry(
            version: "0.9.0",
            releaseDate: "2026-09-15",
            highlights: [
                "首版 macOS 原生架構與 Swift Package Manager 整合",
                "多文件獨立 Session 與磁碟外部衝突監聽器",
                "五邊停靠面板與工具參數獨立記憶"
            ]
        )
    ]
}

public struct AppSettings: Codable, Equatable {
    public var appTheme: AppTheme
    public var defaultCanvasMode: CanvasMode
    public var defaultPaperPreset: String
    public var defaultFontFamily: String
    public var defaultFontSize: Double
    public var autoSaveFrequency: AutoSaveFrequency
    public var defaultToolbarDock: String // "left", "right", "top", "bottom", "floating"
    public var showCanvasGrid: Bool
    public var isHapticFeedbackEnabled: Bool
    public var loggedInUserEmail: String?

    public init(
        appTheme: AppTheme = .blackboard,
        defaultCanvasMode: CanvasMode = .infinite,
        defaultPaperPreset: String = "A4",
        defaultFontFamily: String = "PingFang TC",
        defaultFontSize: Double = 24.0,
        autoSaveFrequency: AutoSaveFrequency = .standard,
        defaultToolbarDock: String = "left",
        showCanvasGrid: Bool = true,
        isHapticFeedbackEnabled: Bool = true,
        loggedInUserEmail: String? = nil
    ) {
        self.appTheme = appTheme
        self.defaultCanvasMode = defaultCanvasMode
        self.defaultPaperPreset = defaultPaperPreset
        self.defaultFontFamily = defaultFontFamily
        self.defaultFontSize = defaultFontSize
        self.autoSaveFrequency = autoSaveFrequency
        self.defaultToolbarDock = defaultToolbarDock
        self.showCanvasGrid = showCanvasGrid
        self.isHapticFeedbackEnabled = isHapticFeedbackEnabled
        self.loggedInUserEmail = loggedInUserEmail
    }
}

public final class AppSettingsManager {
    public static let shared = AppSettingsManager()

    public private(set) var current: AppSettings
    public private(set) var syncState: CloudSyncState = .localOnly(reason: "本機單機模式：所有黑板保存在此 Mac，離線安全")

    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(userDefaults: UserDefaults = .standard, storageKey: String = "HeiBan_AppSettings") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let data = userDefaults.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.current = loaded
        } else {
            self.current = AppSettings()
        }

        updateSyncStateFromSettings()
    }

    public func update(_ block: (inout AppSettings) -> Void) {
        block(&current)
        save()
        updateSyncStateFromSettings()
    }

    public func resetToDefaults() {
        current = AppSettings()
        save()
        updateSyncStateFromSettings()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(current) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    public func setSyncState(_ state: CloudSyncState) {
        self.syncState = state
    }

    public func loginUser(email: String) {
        update { $0.loggedInUserEmail = email }
        self.syncState = .synced(lastSyncTime: Date())
    }

    public func logoutUser() {
        update { $0.loggedInUserEmail = nil }
        self.syncState = .localOnly(reason: "本機單機模式：所有黑板保存在此 Mac，離線安全")
    }

    private func updateSyncStateFromSettings() {
        if let email = current.loggedInUserEmail, !email.isEmpty {
            self.syncState = .synced(lastSyncTime: Date())
        } else {
            self.syncState = .localOnly(reason: "本機單機模式：所有黑板保存在此 Mac，離線安全")
        }
    }
}
