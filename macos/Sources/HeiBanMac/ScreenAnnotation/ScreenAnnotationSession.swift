import AppKit
import Combine
import HeiBanCore

/// 一個顯示器的一份透明文件、原生視窗與恢復檔；不回寫普通作品庫。
final class ScreenAnnotationSession {
    private static let recoveryQueue = DispatchQueue(label: "com.bear.HeiBan.screen-recovery", qos: .utility)
    private let dialogService = MacPlatformDialogService()
    let displayID: UInt32
    let engine: BoardEngine
    let panel: NSPanel
    let recoveryURL: URL
    var subscription: AnyCancellable?
    var recoveryWorkItem: DispatchWorkItem?
    var onRecoveryFailure: ((String) -> Void)?
    private(set) var recoveryIssue: String?

    init(screen: NSScreen, recoveryDirectory: URL, onActivate: @escaping (UInt32) -> Void) {
        displayID =
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            ?? 0
        recoveryURL = recoveryDirectory.appendingPathComponent("display-\(displayID).heiban")
        engine = BoardEngine(restoreSession: false, persistenceEnabled: false)
        engine.dialogService = dialogService
        engine.pasteboardService = MacPlatformPasteboardService()
        engine.imageDecoderService = MacPlatformImageDecoderService()
        engine.board.title = "螢幕註記 · \(screen.localizedName)"
        engine.board.backgroundColor = "#ffffff"
        if FileManager.default.fileExists(atPath: recoveryURL.path) {
            do {
                try engine.loadFromJsonData(Data(contentsOf: recoveryURL))
            } catch {
                // Never overwrite a damaged or newer recovery file with an empty session.
                let preserved = recoveryURL.deletingPathExtension().appendingPathExtension(
                    "preserved-\(Int(Date().timeIntervalSince1970)).heiban")
                do { try FileManager.default.moveItem(at: recoveryURL, to: preserved) } catch {
                    recoveryIssue = "無法保留原註記暫存；本次停用自動暫存"
                }
                if recoveryIssue == nil { recoveryIssue = "原註記無法讀取，已保留原檔；請查閱使用手冊" }
            }
        }
        // 文件啟用會清理工具／viewport。恢復完成後才設定螢幕作畫的初始狀態。
        engine.board.canvasMode = .infinite
        engine.viewport = ViewportTransform()
        engine.viewportLocked = true
        engine.canvasSize = screen.frame.size
        engine.showingHome = false
        engine.selectTool(.pen)
        engine.updateCurrentToolStyle(color: "#ef4444", strokeWidth: 4, opacity: 1)
        panel = AnnotationCanvasPanel(
            contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: false)
        panel.setFrame(screen.frame, display: false)
        panel.title = "螢幕畫布 · \(screen.localizedName)"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = AnnotationWindowPolicy.canvasLevel
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = AnnotationWindowPolicy.collectionBehavior
        panel.contentView = AnnotationInputView(
            engine: engine, size: screen.frame.size,
            onInteraction: { [displayID] in onActivate(displayID) })
    }

    /// 清掉未完成手勢，再恢復工具與樣式；作畫／操作切換不是工具選取命令。
    func setDrawing(_ drawing: Bool) {
        let tool = engine.currentTool
        let color = engine.activeColor
        let width = engine.activeStrokeWidth
        let opacity = engine.activeOpacity
        engine.cancelTransientInteraction()
        if tool != .select { engine.selectTool(tool) }
        engine.updateCurrentToolStyle(color: color, strokeWidth: width, opacity: opacity)
        if !drawing {
            engine.laserEngine.cleanupOnDeactivate()
            engine.cane.clear()
            engine.caneStopSoundHandler?()
            engine.caneRenderTick &+= 1
        }
        panel.ignoresMouseEvents = !drawing
        if !drawing {
            panel.makeFirstResponder(nil)
            if panel.isKeyWindow { panel.resignKey() }
        }
    }

    func saveRecovery() throws {
        guard recoveryIssue != "無法保留原註記暫存；本次停用自動暫存" else { return }
        try Self.persistRecoverySnapshots([(recoveryURL, recoveryDocument())])
    }

    static func persistRecoverySnapshots(_ snapshots: [(URL, HeiBanDocument)]) throws {
        try recoveryQueue.sync {
            try writeRecoverySnapshots(snapshots)
        }
    }

    private static func writeRecoverySnapshots(_ snapshots: [(URL, HeiBanDocument)]) throws {
        for (url, document) in snapshots {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try HeiBanDocumentCodec.encode(document)
            try data.write(to: url, options: .atomic)
        }
    }

    func recoveryDocument() -> HeiBanDocument {
        var document = engine.document
        document.extraFields = (document.extraFields ?? [:]).merging(["purpose": .string("screenAnnotation")])
        { _, value in value }
        return document
    }

    func scheduleRecovery() {
        recoveryWorkItem?.cancel()
        let settings = AppSettingsManager.shared.current
        guard settings.autoSaveEnabled, settings.autoSaveFrequency != .manual else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let latest = AppSettingsManager.shared.current
            guard latest.autoSaveEnabled, latest.autoSaveFrequency != .manual else { return }
            guard self.recoveryIssue != "無法保留原註記暫存；本次停用自動暫存" else { return }
            let document = self.recoveryDocument()
            let url = self.recoveryURL
            Self.recoveryQueue.async { [weak self] in
                do {
                    try Self.writeRecoverySnapshots([(url, document)])
                } catch {
                    let message = error.localizedDescription
                    DispatchQueue.main.async {
                        self?.onRecoveryFailure?(message)
                    }
                }
            }
        }
        recoveryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.autoSaveFrequency.rawValue, execute: work)
    }
}

private final class AnnotationCanvasPanel: NSPanel {
    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }
}
