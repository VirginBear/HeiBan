import Foundation

// MARK: - 跨平台架構決策 (Architecture Decision Records, ADR, W29, A31)

public enum PlatformTarget: String, Codable, CaseIterable {
    case macOS = "macOS"
    case web = "Web"
    case windows = "Windows"
}

public struct PlatformArchitectureDecision: Codable, Equatable {
    public let platform: PlatformTarget
    public let renderingStack: String
    public let inputDispatcher: String
    public let persistenceBackend: String
    public let textEngine: String
    public let maxFontMetricTolerancePt: Double
    public let schemaContractVersion: String
    public let sharedFixturesSupported: [String]

    public init(
        platform: PlatformTarget,
        renderingStack: String,
        inputDispatcher: String,
        persistenceBackend: String,
        textEngine: String,
        maxFontMetricTolerancePt: Double = 2.0,
        schemaContractVersion: String = "1.0.0",
        sharedFixturesSupported: [String] = ["F01", "F02", "F03", "F04", "F05"]
    ) {
        self.platform = platform
        self.renderingStack = renderingStack
        self.inputDispatcher = inputDispatcher
        self.persistenceBackend = persistenceBackend
        self.textEngine = textEngine
        self.maxFontMetricTolerancePt = maxFontMetricTolerancePt
        self.schemaContractVersion = schemaContractVersion
        self.sharedFixturesSupported = sharedFixturesSupported
    }
}

// MARK: - 平台互通性矩陣與驗證器 (Platform Interoperability Validator, W29, A23, A31)

public struct PlatformInteroperabilityMatrix {
    public static let standardDecisions: [PlatformTarget: PlatformArchitectureDecision] = [
        .macOS: PlatformArchitectureDecision(
            platform: .macOS,
            renderingStack: "SwiftUI + AppKit + Metal (原生 120Hz/60Hz 低延遲筆跡)",
            inputDispatcher: "NSEvent + 高精度觸控板手勢 + Wacom/繪圖板壓感 (0.0~1.0)",
            persistenceBackend: "Atomic File Swap + ~/Library/Application Support/com.bear.HeiBan",
            textEngine: "CoreText / NSTextView (原生 IME 候選字隔離)",
            maxFontMetricTolerancePt: 2.0,
            schemaContractVersion: "1.0.0"
        ),
        .web: PlatformArchitectureDecision(
            platform: .web,
            renderingStack: "React 19 + HTML5 Canvas 2D / OffscreenCanvas + Tailwind CSS v4",
            inputDispatcher: "W3C PointerEvents (Coalesced Events) + Touch / Mouse Events",
            persistenceBackend: "IndexedDB + File System Access API (showSaveFilePicker)",
            textEngine: "HTML5 Canvas measureText + DOM ContentEditable Overlay",
            maxFontMetricTolerancePt: 2.0,
            schemaContractVersion: "1.0.0"
        ),
        .windows: PlatformArchitectureDecision(
            platform: .windows,
            renderingStack: "WinUI 3 + Direct2D / Windows App SDK (原生高效能手寫渲染)",
            inputDispatcher: "PointerPoint + Windows Ink API + 高精度壓感",
            persistenceBackend: "Windows.Storage.ApplicationData.Current.LocalFolder + 原子寫入",
            textEngine: "DirectWrite + XAML RichEditBox",
            maxFontMetricTolerancePt: 2.0,
            schemaContractVersion: "1.0.0"
        )
    ]

    /// 檢驗跨平台文件契約版本一致性 (A23, A31)
    public static func verifyContractParity() -> Bool {
        let versions = standardDecisions.values.map(\.schemaContractVersion)
        guard let first = versions.first else { return false }
        return versions.allSatisfy { $0 == first && $0 == "1.0.0" }
    }

    /// 檢驗所有平台對全套標準 Fixture (F01–F05) 的支援完整度
    public static func verifyFixtureCoverage() -> Bool {
        let required = Set(["F01", "F02", "F03", "F04", "F05"])
        return standardDecisions.values.allSatisfy { decision in
            Set(decision.sharedFixturesSupported).isSuperset(of: required)
        }
    }

    /// 檢驗跨平台字型度量與排版容差極限 (≤ 2.0 pt)
    public static func verifyFontMetricTolerance() -> Bool {
        return standardDecisions.values.allSatisfy { $0.maxFontMetricTolerancePt <= 2.0 }
    }
}
