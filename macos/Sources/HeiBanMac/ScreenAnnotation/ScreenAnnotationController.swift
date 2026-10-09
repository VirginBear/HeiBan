import AppKit
import Combine
import HeiBanCore
import SwiftUI
import UniformTypeIdentifiers

/// 螢幕畫布的生命週期入口：待命 → 作畫／穿透操作 → 截圖 → 恢復 → 保存結束。
/// Carbon／AppKit 回呼在主執行緒管理視窗；指標取樣仍由各顯示器自己的引擎處理。
final class ScreenAnnotationController: ObservableObject {
    static let shared = ScreenAnnotationController()
    @Published private(set) var isActive = false
    @Published private(set) var isDrawing = false
    @Published private(set) var isCapturing = false
    @Published var message = "⌘⌥⇧D 作畫／操作 · ⌘⌥⇧X 結束"
    @Published private(set) var activeEngine = BoardEngine(restoreSession: false, persistenceEnabled: false)
    private var sessions: [ScreenAnnotationSession] = []
    private var controls: NSPanel?
    private let hotKeys = ScreenAnnotationHotKeys()
    private let capture = MacScreenCaptureService()
    private var displayObserver: NSObjectProtocol?
    private var localKeys: Any?
    private var activationObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var isPresentingDialog = false
    private var lastExternalApp: NSRunningApplication?
    private var registered = false
    private var shortcutsAvailable = false
    private var selectedDisplayID: UInt32?
    private var pendingStop = false
    private var lastShortcutAt: TimeInterval = 0

    private var recoveryDirectory: URL {
        BoardEngine.library.directory.deletingLastPathComponent().appendingPathComponent(
            "ScreenAnnotations", isDirectory: true)
    }

    func registerShortcuts() {
        guard !registered else { return }
        registered = true
        hotKeys.perform = { [weak self] id in
            DispatchQueue.main.async { self?.performShortcut(id) }
        }
        shortcutsAvailable = hotKeys.register()
        if !shortcutsAvailable { message = "快捷鍵無法登錄；請使用控制列或選單切換" }
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.stop()
            self.message = "顯示器配置已變更，註記已保存；請重新開啟螢幕畫布"
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier != Bundle.main.bundleIdentifier
            {
                self?.lastExternalApp = app
                self?.raiseOverlayWindows()
            }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.raiseOverlayWindows() }
        localKeys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Also handle AppKit-delivered shortcuts, including remote desktop / accessibility input.
            if event.modifierFlags.contains([.command, .option, .shift]),
                let key = event.charactersIgnoringModifiers?.lowercased(),
                let index = ["d", "s", "x"].firstIndex(of: key)
            {
                self.performShortcut(UInt32(index + 1))
                return nil
            }
            guard self.isActive, self.sessions.contains(where: { $0.panel == event.window }),
                event.keyCode == 53
            else { return event }
            self.setDrawing(false)
            return nil
        }
    }

    private func performShortcut(_ id: UInt32) {
        guard !isPresentingDialog else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastShortcutAt > 0.12 else { return }
        lastShortcutAt = now
        switch id {
        case 1: toggleDrawing()
        case 2: captureScreen()
        case 3: stop()
        default: break
        }
    }

    func start() {
        guard !isActive else {
            setDrawing(true)
            return
        }
        registerShortcuts()
        if let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            lastExternalApp = app
        }
        sessions = NSScreen.screens.map {
            ScreenAnnotationSession(screen: $0, recoveryDirectory: recoveryDirectory) { [weak self] id in
                self?.selectDisplay(id)
            }
        }
        guard !sessions.isEmpty else {
            message = "找不到顯示器"
            return
        }
        for session in sessions {
            session.subscription = session.engine.$objects.dropFirst().debounce(
                for: .seconds(0.8), scheduler: DispatchQueue.main
            ).sink { [weak self, weak session] _ in
                guard let session else { return }
                do { try session.saveRecovery() } catch {
                    self?.message = "註記暫存失敗：\(error.localizedDescription)"
                }
            }
            session.panel.orderFrontRegardless()
        }
        selectScreenUnderMouse()
        isActive = true
        isDrawing = true
        message = sessions.compactMap(\.recoveryIssue).first ?? drawingMessage
        showControls()
        focusDrawingCanvas()
    }

    func toggleDrawing() {
        guard !isCapturing else { return }
        if !isActive { start() } else { setDrawing(!isDrawing) }
    }

    private func selectDisplay(_ id: UInt32) {
        guard isActive, selectedDisplayID != id, let session = sessions.first(where: { $0.displayID == id })
        else { return }
        // selectTool 是 UI toggle；同步到另一個顯示器時相同工具不得反而取消。
        if session.engine.currentTool != activeEngine.currentTool {
            session.engine.selectTool(activeEngine.currentTool)
        }
        session.engine.activeColor = activeEngine.activeColor
        session.engine.activeStrokeWidth = activeEngine.activeStrokeWidth
        session.engine.activeOpacity = activeEngine.activeOpacity
        session.engine.eraserMode = activeEngine.eraserMode
        session.engine.eraserSize = activeEngine.eraserSize
        session.engine.laserEngine.mode = activeEngine.laserEngine.mode
        session.engine.laserEngine.color = activeEngine.laserEngine.color
        session.engine.laserEngine.width = activeEngine.laserEngine.width
        session.engine.laserEngine.pointDiameter = activeEngine.laserEngine.pointDiameter
        session.engine.laserEngine.fadeDuration = activeEngine.laserEngine.fadeDuration
        session.engine.laserEngine.hasWhiteCore = activeEngine.laserEngine.hasWhiteCore
        activeEngine = session.engine
        selectedDisplayID = id
    }

    private func selectScreenUnderMouse() {
        let session = sessions.first { $0.panel.frame.contains(NSEvent.mouseLocation) } ?? sessions[0]
        if isActive {
            selectDisplay(session.displayID)
        } else {
            activeEngine = session.engine
            selectedDisplayID = session.displayID
        }
    }

    private var drawingMessage: String {
        shortcutsAvailable ? "作畫中 · Esc 暫停，或 ⌘⌥⇧D 切換" : "作畫中 · 快捷鍵無法登錄，請使用控制列切換"
    }

    func setDrawing(_ drawing: Bool) {
        guard isActive, !isCapturing else { return }
        guard isDrawing != drawing else {
            raiseOverlayWindows()
            return
        }
        isDrawing = drawing
        for session in sessions {
            session.setDrawing(drawing)
        }
        message =
            drawing
            ? drawingMessage : (shortcutsAvailable ? "操作中 · 滑鼠可穿透；⌘⌥⇧D 繼續作畫" : "操作中 · 滑鼠可穿透；請用控制列繼續作畫")
        if drawing {
            selectScreenUnderMouse()
            raiseOverlayWindows()
            focusDrawingCanvas()
        } else { lastExternalApp?.activate(options: []) }
    }

    func stop() {
        guard isActive else { return }
        if isCapturing {
            pendingStop = true
            capture.cancel()
            return
        }
        do { for session in sessions { try session.saveRecovery() } } catch {
            message = "註記未能保存，保留畫布：\(error.localizedDescription)"
            return
        }
        for session in sessions {
            session.engine.cancelTransientInteraction()
            session.engine.laserEngine.cleanupOnDeactivate()
            session.subscription?.cancel()
            session.panel.orderOut(nil)
            session.panel.close()
        }
        sessions.removeAll()
        controls?.orderOut(nil)
        controls?.close()
        controls = nil
        isActive = false
        isDrawing = false
        lastExternalApp?.activate(options: [])
    }

    func selectTool(_ tool: ToolType) {
        if !isDrawing { setDrawing(true) }
        for session in sessions where session.engine.currentTool != tool {
            session.engine.selectTool(tool)
        }
    }
    func setColor(_ color: String) {
        for session in sessions {
            session.engine.activeColor = color
            session.engine.laserEngine.color = color
        }
    }
    func setWidth(_ width: Double) {
        for session in sessions { session.engine.activeStrokeWidth = width }
    }
    func setOpacity(_ opacity: Double) {
        for session in sessions { session.engine.activeOpacity = opacity }
    }

    func showUserGuide() {
        // 手冊是普通原生視窗；先穿透，避免透明輸入層截走手冊的點擊。
        setDrawing(false)
        HeiBanUserGuide.shared.show()
    }

    func clearAnnotations() {
        let alert = NSAlert()
        alert.messageText = "清除所有螢幕的註記？"
        alert.informativeText = "只清除透明畫布上的物件，不影響背後的程式。可在本次工作階段復原。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "清除")
        if withHiddenOverlays({ alert.runModal() }) == .alertSecondButtonReturn {
            sessions.forEach { $0.engine.clearAll() }
        }
    }

    var focusedEngine: BoardEngine? {
        guard isActive, let keyWindow = NSApp.keyWindow,
            keyWindow == controls || sessions.contains(where: { $0.panel == keyWindow })
        else { return nil }
        return activeEngine
    }

    func saveEditable() {
        guard isActive else { return }
        let panel = NSSavePanel()
        panel.title = "儲存可編輯螢幕註記"
        panel.nameFieldStringValue = "螢幕註記.heiban"
        panel.allowedContentTypes = [HeiBanFileType.document]
        if withHiddenOverlays({ panel.runModal() }) == .OK, let url = panel.url {
            do {
                var document = activeEngine.document
                document.extraFields = (document.extraFields ?? [:]).merging([
                    "purpose": .string("screenAnnotation")
                ]) { _, value in value }
                try HeiBanDocumentCodec.encode(document).write(to: url, options: .atomic)
                message = "已儲存可編輯註記；背後螢幕不包含在此檔案"
            } catch { message = "儲存失敗：\(error.localizedDescription)" }
        }
        lastExternalApp?.activate(options: [])
    }

    func captureScreen() {
        guard isActive, !isCapturing else { return }
        let wasDrawing = isDrawing
        let mouseSession = sessions.first { $0.panel.frame.contains(NSEvent.mouseLocation) }
        let id = mouseSession?.displayID ?? selectedDisplayID
        let index =
            (NSScreen.screens.firstIndex {
                (($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value)
                    == id
            } ?? 0) + 1
        setDrawing(false)
        isCapturing = true
        controls?.orderOut(nil)
        capture.capture(mode: .display(index: index)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .image(let data):
                let panel = NSSavePanel()
                panel.title = "儲存螢幕與註記截圖"
                panel.nameFieldStringValue = "黑板螢幕截圖.png"
                panel.allowedContentTypes = [.png]
                if self.withHiddenOverlays({ panel.runModal() }) == .OK, let url = panel.url {
                    do {
                        try data.write(to: url, options: .atomic)
                        self.message = "已儲存螢幕與註記截圖"
                    } catch { self.message = "截圖儲存失敗：\(error.localizedDescription)" }
                }
            case .cancelled: self.message = "已取消截圖"
            case .failed(let detail): self.message = "截圖失敗：\(detail)"
            }
            self.isCapturing = false
            if self.pendingStop {
                self.pendingStop = false
                self.stop()
                return
            }
            let captureMessage = self.message
            self.setDrawing(wasDrawing)
            self.message = captureMessage
            self.controls?.orderFrontRegardless()
            self.lastExternalApp?.activate(options: [])
        }
    }

    private func showControls() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let panel = AnnotationControlsPanel(
            contentRect: NSRect(
                x: screen.visibleFrame.midX - 370, y: screen.visibleFrame.maxY - 118, width: 740, height: 102),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "螢幕畫布控制列"
        panel.level = AnnotationWindowPolicy.controlsLevel
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = AnnotationWindowPolicy.collectionBehavior
        panel.contentView = NSHostingView(rootView: ScreenAnnotationControls(controller: self))
        controls = panel
        panel.orderFrontRegardless()
    }

    private func focusDrawingCanvas() {
        guard let panel = sessions.first(where: { $0.displayID == selectedDisplayID })?.panel else { return }
        // 作畫開始後 Esc／繪圖快捷鍵屬於畫布；非啟動 panel 不把背後程式切回首頁。
        panel.makeKey()
        panel.makeFirstResponder(panel.contentView)
    }

    /// 切換前景程式／Space 後只重排疊層；不搶主程式焦點、不取消筆畫。
    private func raiseOverlayWindows() {
        guard isActive, !isPresentingDialog else { return }
        sessions.forEach { $0.panel.orderFrontRegardless() }
        if !isCapturing { controls?.orderFrontRegardless() }
    }

    /// 高位階畫布不能蓋住本程式自己的原生保存／確認對話框。
    /// 截圖保存時仍保持隱藏，等截圖生命週期統一恢復，不在 defer 提早顯示。
    private func withHiddenOverlays<T>(_ action: () -> T) -> T {
        isPresentingDialog = true
        sessions.forEach { $0.panel.orderOut(nil) }
        controls?.orderOut(nil)
        defer {
            isPresentingDialog = false
            if !isCapturing { raiseOverlayWindows() }
        }
        return action()
    }
}

private final class AnnotationControlsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
