import Foundation
import CryptoKit

// MARK: - 簽章與公證狀態契約 (A31)

public enum SigningStatus: String, Codable, Equatable {
    case developerID = "developer_id"
    case development = "development"
    case adHoc = "ad_hoc"
    case unsigned = "unsigned"
}

public enum NotarizationStatus: String, Codable, Equatable {
    case notarizedAndStapled = "notarized_and_stapled"
    case notarized = "notarized"
    case unnotarized = "unnotarized"
}

public enum ArchitectureTarget: String, Codable, Equatable {
    case arm64 = "arm64"
    case x86_64 = "x86_64"
    case universal2 = "universal2"
}

// MARK: - 發行產物資訊 (Release Artifact Info, A31)

public struct ReleaseArtifactInfo: Codable, Equatable {
    public let appName: String
    public let bundleIdentifier: String
    public let version: String
    public let buildNumber: String
    public let minimumOSVersion: String
    public let currentOSVersion: String
    public let targetArchitecture: ArchitectureTarget
    public let sha256Checksum: String
    public let signingStatus: SigningStatus
    public let notarizationStatus: NotarizationStatus
    public let releaseDate: String

    public init(
        appName: String = "HeiBan 黑板",
        bundleIdentifier: String = "com.bear.HeiBan",
        version: String = "1.0.0",
        buildNumber: String = "1",
        minimumOSVersion: String = "14.0",
        targetArchitecture: ArchitectureTarget = .arm64,
        sha256Checksum: String,
        signingStatus: SigningStatus = .developerID,
        notarizationStatus: NotarizationStatus = .notarizedAndStapled,
        releaseDate: String = "2026-10-02"
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.buildNumber = buildNumber
        self.minimumOSVersion = minimumOSVersion
        let os = ProcessInfo.processInfo.operatingSystemVersion
        self.currentOSVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        self.targetArchitecture = targetArchitecture
        self.sha256Checksum = sha256Checksum
        self.signingStatus = signingStatus
        self.notarizationStatus = notarizationStatus
        self.releaseDate = releaseDate
    }

    /// 驗證當前執行之作業系統是否符合最低系統版本需求 (macOS 14.0, A31)
    public func isSystemCompatible() -> Bool {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let minParts = minimumOSVersion.split(separator: ".").compactMap { Int($0) }
        guard let minMajor = minParts.first else { return true }
        if os.majorVersion > minMajor { return true }
        if os.majorVersion < minMajor { return false }
        if minParts.count > 1 {
            let minMinor = minParts[1]
            return os.minorVersion >= minMinor
        }
        return true
    }
}

// MARK: - 遠端版本發布資訊 (App Release Info)

public struct AppReleaseInfo: Codable, Equatable {
    public let version: String
    public let buildNumber: String
    public let releaseDate: String
    public let changelog: [String]
    public let downloadURL: String
    public let sha256: String
    public let isCritical: Bool

    public init(
        version: String,
        buildNumber: String,
        releaseDate: String,
        changelog: [String],
        downloadURL: String,
        sha256: String,
        isCritical: Bool = false
    ) {
        self.version = version
        self.buildNumber = buildNumber
        self.releaseDate = releaseDate
        self.changelog = changelog
        self.downloadURL = downloadURL
        self.sha256 = sha256
        self.isCritical = isCritical
    }
}

// MARK: - 更新狀態機 (Update Lifecycle State Machine, W28, A31)

public enum UpdateLifecycleStatus: Equatable {
    case idle
    case checking
    case updateAvailable(AppReleaseInfo)
    case upToDate
    case downloading(progress: Double)
    case readyToInstall(mountPath: String)
    case failed(String)
}

public class AppUpdateManager {
    public let currentVersion: String
    public private(set) var skippedVersions: Set<String> = []
    public private(set) var lastCheckDate: Date?
    public private(set) var status: UpdateLifecycleStatus = .idle

    public init(currentVersion: String = "1.0.0") {
        self.currentVersion = currentVersion
    }

    // MARK: - 語意化版本比對 (SemVer Comparison)

    public static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(parts1.count, parts2.count)

        for i in 0..<maxCount {
            let val1 = i < parts1.count ? parts1[i] : 0
            let val2 = i < parts2.count ? parts2[i] : 0
            if val1 < val2 {
                return .orderedAscending
            } else if val1 > val2 {
                return .orderedDescending
            }
        }
        return .orderedSame
    }

    public static func isNewer(remoteVersion: String, currentVersion: String) -> Bool {
        return compareVersions(currentVersion, remoteVersion) == .orderedAscending
    }

    // MARK: - 檢查更新生命週期 (含提醒去重與離線容錯)

    public func checkForUpdates(remoteRelease: AppReleaseInfo?, isOffline: Bool = false) -> UpdateLifecycleStatus {
        status = .checking
        lastCheckDate = Date()

        if isOffline {
            // 離線狀態：平順提示離線模式，絕不崩潰或中斷使用者編輯 (W28, A31)
            status = .failed("網路離線，無法檢查更新。本機可正常繼續使用。")
            return status
        }

        guard let remote = remoteRelease else {
            status = .upToDate
            return status
        }

        if Self.isNewer(remoteVersion: remote.version, currentVersion: currentVersion) {
            // 檢查是否被使用者主動跳過
            if skippedVersions.contains(remote.version) && !remote.isCritical {
                status = .upToDate // 提醒去重：已跳過該版本且非重大安全更新
                return status
            }
            status = .updateAvailable(remote)
            return status
        } else {
            status = .upToDate
            return status
        }
    }

    public func skipVersion(_ version: String) {
        skippedVersions.insert(version)
    }

    public func resetSkippedVersions() {
        skippedVersions.removeAll()
    }

    // MARK: - 產物雜湊計算與校驗 (SHA-256 Verification, A31)

    public static func computeSHA256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func verifyChecksum(data: Data, expectedSha256: String) -> Bool {
        let actual = computeSHA256(data: data)
        return actual.caseInsensitiveCompare(expectedSha256) == .orderedSame
    }

    // MARK: - 模擬下載與安裝流程

    public func simulateDownload(packageData: Data, releaseInfo: AppReleaseInfo) -> Bool {
        status = .downloading(progress: 0.5)
        status = .downloading(progress: 1.0)

        // 驗證下載封包的 SHA-256 雜湊
        if Self.verifyChecksum(data: packageData, expectedSha256: releaseInfo.sha256) {
            status = .readyToInstall(mountPath: "/tmp/HeiBan-\(releaseInfo.version).dmg")
            return true
        } else {
            status = .failed("更新套件 SHA-256 校驗失敗，檔案可能已損毀，已中止安裝。")
            return false
        }
    }
}

// MARK: - 冷安裝與使用者資料保全 (Cold Install & Data Preservation, A31)

public struct ColdInstallStorageCoordinator {
    /// 使用者黑板資料持久化目錄 (標準 macOS Application Support)
    public static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("com.bear.HeiBan", isDirectory: true)
    }

    public static func boardsDirectory() -> URL {
        return applicationSupportDirectory().appendingPathComponent("boards", isDirectory: true)
    }

    /// 檢驗 App Bundle 與資料目錄是否物理隔離 (符合 macOS Sandbox 與 App 卸載資料保留規範)
    public static func isIsolated(appBundleURL: URL, userDataURL: URL) -> Bool {
        let bundlePath = appBundleURL.standardizedFileURL.path
        let dataPath = userDataURL.standardizedFileURL.path
        // 資料目錄絕不可位於 App Bundle 內部，以確保冷安裝替換 App 或拖進垃圾桶時使用者黑板 100% 保全
        return !dataPath.hasPrefix(bundlePath)
    }
}
