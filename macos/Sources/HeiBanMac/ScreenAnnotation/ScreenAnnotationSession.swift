import AppKit
import Combine
import HeiBanCore

/// 一個顯示器的一份透明文件、原生視窗與恢復檔；不回寫普通作品庫。
final class ScreenAnnotationSession {
    let displayID: UInt32
    let engine: BoardEngine
    let panel: NSPanel
    let recoveryURL: URL
    var subscription: AnyCancellable?
    private(set) var recoveryIssue: String?

    init(screen: NSScreen, recoveryDirectory: URL, onActivate: @escaping (UInt32) -> Void) {
        displayID =
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            ?? 0
        recoveryURL = recoveryDirectory.appendingPathComponent("display-\(displayID).heiban")
        engine = BoardEngine(restoreSession: false, persistenceEnabled: false)
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
        if !drawing { engine.laserEngine.cleanupOnDeactivate() }
        panel.ignoresMouseEvents = !drawing
    }

    func saveRecovery() throws {
        guard recoveryIssue != "無法保留原註記暫存；本次停用自動暫存" else { return }
        try FileManager.default.createDirectory(
            at: recoveryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var document = engine.document
        document.extraFields = (document.extraFields ?? [:]).merging(["purpose": .string("screenAnnotation")])
        { _, value in value }
        let data = try HeiBanDocumentCodec.encode(document)
        try data.write(to: recoveryURL, options: .atomic)
    }
}

private final class AnnotationCanvasPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
