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
    @Published private(set) var controlsDock = AnnotationToolbarDock(
        rawValue: UserDefaults.standard.string(forKey: "HeiBan.screenToolbar.dock") ?? "top") ?? .top
    @Published private(set) var controlsCollapsed = UserDefaults.standard.bool(forKey: "HeiBan.screenToolbar.collapsed")
    @Published private(set) var controlsSize = NSSize(width: 820, height: 60)
    private var controlsPosition: Double = {
        let value = UserDefaults.standard.object(forKey: "HeiBan.screenToolbar.position") as? Double ?? 0.5
        return value.isFinite ? min(1, max(0, value)) : 0.5
    }()
    private var controlsDisplayID = (UserDefaults.standard.object(forKey: "HeiBan.screenToolbar.display") as? NSNumber)?.uint32Value
    private var controlsDrag: (mouse: NSPoint, frame: NSRect)?
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
            // 文字編輯器先處理 Esc／中文組字；不能被全域暫停作畫攔走。
            if self.sessions.contains(where: { $0.panel == event.window && $0.engine.inlineTextEditing }) {
                return event
            }
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
            session.onRecoveryFailure = { [weak self] detail in
                self?.message = "註記暫存失敗：\(detail)"
            }
            session.subscription = session.engine.$objects.dropFirst().sink { [weak session] _ in
                guard let session else { return }
                session.scheduleRecovery()
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
        session.engine.toolbarPreferences = activeEngine.toolbarPreferences
        session.engine.activeBrushKind = activeEngine.activeBrushKind
        session.engine.activeLineStyle = activeEngine.activeLineStyle
        session.engine.activeHighlighterOpacity = activeEngine.activeHighlighterOpacity
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
        if !drawing {
            commitTextDrafts()
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
        commitTextDrafts()
        do { for session in sessions { try session.saveRecovery() } } catch {
            message = "註記未能保存，保留畫布：\(error.localizedDescription)"
            return
        }
        finishStopAfterRecoverySaved()
    }

    /// App 正常退出時先提交每個顯示器的草稿，背景寫恢復檔；全部成功後才關閉疊層。
    func prepareForTermination(completion: @escaping (Bool) -> Void) {
        guard isActive else { completion(true); return }
        guard !isCapturing else {
            message = "截圖尚未完成；請稍後再結束黑板"
            completion(false)
            return
        }

        commitTextDrafts()
        if isDrawing {
            isDrawing = false
            for session in sessions { session.setDrawing(false) }
        }

        let snapshots = sessions.compactMap { session -> (URL, HeiBanDocument)? in
            if session.recoveryIssue == "無法保留原註記暫存；本次停用自動暫存" { return nil }
            return (session.recoveryURL, session.recoveryDocument())
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try ScreenAnnotationSession.persistRecoverySnapshots(snapshots)
                DispatchQueue.main.async {
                    guard let self else { completion(false); return }
                    self.finishStopAfterRecoverySaved()
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.message = "螢幕註記未能保存，保留畫布：\(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }

    private func finishStopAfterRecoverySaved() {
        for session in sessions {
            session.recoveryWorkItem?.cancel()
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
        controlsDrag = nil
        isActive = false
        isDrawing = false
        lastExternalApp?.activate(options: [])
    }

    func selectTool(_ tool: ToolType) {
        if !isDrawing { setDrawing(true) }
        commitTextDrafts()
        for session in sessions where session.engine.currentTool != tool {
            session.engine.selectTool(tool)
        }
    }

    /// 暫停、換工具、保存及截圖共同收束文字草稿，先結束原生組字。
    /// 不把未提交文字只留在 editor；停止後仍沿用既有 .heiban 恢復檔。
    private func commitTextDrafts() {
        for session in sessions where session.engine.showInlineTextEditor {
            (session.panel.firstResponder as? NSTextView)?.unmarkText()
            session.engine.commitInlineTextEntry()
        }
    }
    func showUserGuide() {
        // 手冊是普通原生視窗；先穿透，避免透明輸入層截走手冊的點擊。
        setDrawing(false)
        HeiBanUserGuide.shared.show()
    }

    func clearAnnotations() {
        guard isActive, !isCapturing, !isPresentingDialog else { return }
        // 清空是可復原的編輯命令，不走 modal／orderOut／stop，避免露出黑板首頁。
        // 取消未完成筆畫後恢復原工具／樣式與穿透模式；雷射尾跡也要一併消失。
        for session in sessions {
            session.setDrawing(isDrawing)
            session.engine.laserEngine.clear()
            session.engine.clearAll()
        }
        message = "已清空所有螢幕註記 · 可在各螢幕復原"
        do {
            // 空白狀態立即落盤，避免清空後立刻停止／重開又恢復舊註記。
            for session in sessions { try session.saveRecovery() }
        } catch {
            message = "已清空；註記暫存失敗：\(error.localizedDescription)"
        }
        if isDrawing { focusDrawingCanvas() }
    }

    var focusedEngine: BoardEngine? {
        guard isActive, let keyWindow = NSApp.keyWindow,
            keyWindow == controls || sessions.contains(where: { $0.panel == keyWindow })
        else { return nil }
        return activeEngine
    }

    func saveEditable() {
        commitTextDrafts()
        guard isActive else { return }
        let panel = NSSavePanel()
        panel.title = L10n.t("儲存可編輯螢幕註記")
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
        commitTextDrafts()
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
                panel.title = L10n.t("儲存螢幕與註記截圖")
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

    private func controlsFrame(dock:AnnotationToolbarDock,on screen:NSScreen) -> NSRect {
        guard !controlsCollapsed,activeEngine.toolbarPreferences.displayMode=="labels" else {
            return AnnotationToolbarLayout.frame(for:dock,position:controlsPosition,collapsed:controlsCollapsed,on:screen,itemCount:ToolbarContentPolicy.screenItemCount(activeEngine.toolbarPreferences))
        }
        let area=AnnotationToolbarLayout.availableFrame(on:screen)
        let size=dock.isVertical ? NSSize(width:min(160,area.width),height:min(660,area.height)) : NSSize(width:min(1100,area.width),height:min(136,area.height))
        let fraction=max(0,min(1,controlsPosition))
        var origin=area.origin
        if dock.isVertical { origin.y += (area.height-size.height)*fraction;if dock == .right { origin.x=area.maxX-size.width } }
        else { origin.x += (area.width-size.width)*fraction;if dock == .top { origin.y=area.maxY-size.height } }
        return NSRect(origin:origin,size:size)
    }

    private func showControls() {
        guard let screen = NSScreen.screens.first(where: { displayID(for: $0) == controlsDisplayID })
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        else { return }
        let frame = controlsFrame(dock:controlsDock,on:screen)
        controlsSize = frame.size
        for session in sessions { session.engine.toolbarDock = controlsDock.rawValue }
        let panel = AnnotationControlsPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = L10n.t("螢幕畫布控制列")
        panel.level = AnnotationWindowPolicy.controlsLevel
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = AnnotationWindowPolicy.collectionBehavior
        let host = NSHostingView(rootView: ScreenAnnotationControls(controller: self))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        controls = panel
        if let id = displayID(for: screen) { selectDisplay(id) }
        panel.orderFrontRegardless()
    }

    private func displayID(for screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// 工具偏好共用，但視窗尺寸屬於螢幕模式；只在低頻清單變更時重排。
    func toolbarPreferencesChanged() {
        for session in sessions where session.engine !== activeEngine {
            if session.engine.toolbarPreferences != activeEngine.toolbarPreferences {
                session.engine.toolbarPreferences = activeEngine.toolbarPreferences
            }
        }
        guard controlsDrag == nil, let screen = controls?.screen else { return }
        placeControls(dock: controlsDock, on: screen)
    }

    func importImage() {
        setDrawing(true)
        commitTextDrafts()
        withHiddenOverlays { activeEngine.importImageFromFilePrompt() }
    }

    func setControlsDock(_ dock: AnnotationToolbarDock) {
        guard let screen = controls?.screen ?? NSScreen.main else { return }
        controlsDrag = nil
        placeControls(dock: dock, on: screen)
    }

    func setControlsCollapsed(_ collapsed: Bool) {
        guard controlsCollapsed != collapsed, let screen = controls?.screen ?? NSScreen.main else { return }
        controlsCollapsed = collapsed
        UserDefaults.standard.set(collapsed, forKey: "HeiBan.screenToolbar.collapsed")
        placeControls(dock: controlsDock, on: screen)
    }

    func beginControlsDrag(at point: NSPoint) {
        guard !isCapturing, let panel = controls else { return }
        controlsDrag = (point, panel.frame)
    }

    func moveControlsDrag(to point: NSPoint) {
        guard let drag = controlsDrag, let panel = controls,
            let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? panel.screen else { return }
        let available = AnnotationToolbarLayout.availableFrame(on: screen)
        var origin = NSPoint(x: drag.frame.minX + point.x - drag.mouse.x, y: drag.frame.minY + point.y - drag.mouse.y)
        origin.x = min(max(available.minX, origin.x), max(available.minX, available.maxX - drag.frame.width))
        origin.y = min(max(available.minY, origin.y), max(available.minY, available.maxY - drag.frame.height))
        // 拖動過程不發布 SwiftUI 方向／尺寸，不會因握把換位置而反覆跳動。
        panel.setFrameOrigin(origin)
    }

    func endControlsDrag(at point: NSPoint) {
        guard let drag = controlsDrag else { return }
        controlsDrag = nil
        guard hypot(point.x - drag.mouse.x, point.y - drag.mouse.y) > 3,
            let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? controls?.screen else { return }
        let dock = AnnotationToolbarLayout.nearestDock(to: point, on: screen, current: controlsDock)
        let available = AnnotationToolbarLayout.availableFrame(on: screen)
        let size = controlsFrame(dock:dock,on:screen).size
        controlsPosition = AnnotationToolbarLayout.position(forDrop: point, dock: dock, availableFrame: available, size: size)
        placeControls(dock: dock, on: screen)
        if let id = displayID(for: screen) { selectDisplay(id) }
    }

    private func placeControls(dock: AnnotationToolbarDock, on screen: NSScreen) {
        guard let panel = controls else { return }
        controlsDock = dock
        // 僅更新螢幕 engine 的排版資料，不能呼叫會改一般畫布偏好的 setToolbarDock。
        for session in sessions { session.engine.toolbarDock = dock.rawValue }
        let frame = controlsFrame(dock:dock,on:screen)
        controlsSize = frame.size
        panel.setFrame(frame, display: true, animate: false)
        controlsDisplayID = displayID(for: screen)
        let defaults = UserDefaults.standard
        defaults.set(dock.rawValue, forKey: "HeiBan.screenToolbar.dock")
        defaults.set(controlsPosition, forKey: "HeiBan.screenToolbar.position")
        if let id = controlsDisplayID { defaults.set(NSNumber(value: id), forKey: "HeiBan.screenToolbar.display") }
    }

    private func focusDrawingCanvas() {
        guard let panel = sessions.first(where: { $0.displayID == selectedDisplayID })?.panel else { return }
        // 作畫開始後 Esc／繪圖快捷鍵屬於畫布；非啟動 panel 不把背後程式切回首頁。
        panel.makeKey()
        panel.makeFirstResponder((panel.contentView as? AnnotationInputView)?.pointerReceiver ?? panel.contentView)
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
