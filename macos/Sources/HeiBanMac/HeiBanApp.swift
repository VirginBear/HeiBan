import SwiftUI
import AppKit
import HeiBanCore

@main
struct HeiBanApp: App {
    @NSApplicationDelegateAdaptor(HeiBanAppDelegate.self) private var appDelegate
    private static let platformDialogService = MacPlatformDialogService()
    @StateObject private var engine: BoardEngine = {
        let eng = BoardEngine()
        eng.dialogService = HeiBanApp.platformDialogService
        eng.pasteboardService = MacPlatformPasteboardService()
        eng.imageDecoderService = MacPlatformImageDecoderService()
        eng.screenCaptureService = MacScreenCaptureService()
        return eng
    }()

    @ObservedObject private var language = L10n.shared
    @ObservedObject private var screenCanvas = ScreenAnnotationController.shared

    private var commandEngine: BoardEngine { screenCanvas.focusedEngine ?? engine }

    // NSTextView 包含原生文字框／輸入法 field editor；文字貼上保留 AppKit 行為。
    private func performClipboardAction(_ selector: String, canvasAction: () -> Void) {
        if NSApplication.shared.keyWindow?.firstResponder is NSTextView {
            NSApplication.shared.sendAction(Selector(selector), to: nil, from: nil)
        } else if !commandEngine.showingHome && !commandEngine.readingMode { canvasAction() }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(engine: engine)
                .preferredColorScheme(.light)
                .tint(Color(hex:"#39735a"))
                .task { await MacUpdateService.shared.checkOnLaunch() }
                .onAppear {
                    NSApplication.shared.applicationIconImage = HeiBanBrand.appIcon
                    screenCanvas.registerShortcuts()
                    MacDocumentExchange.shared.attach(to:engine)
                    appDelegate.persistBeforeQuit = { completion in
                        screenCanvas.prepareForTermination { screensSaved in
                            guard screensSaved else { completion(false); return }
                            engine.saveBeforeLeaving(completion: completion)
                        }
                    }
                }
                .onOpenURL { url in
                    guard url.isFileURL, ["heiban", "json", "pdf", "ppt", "pptx", "key"].contains(url.pathExtension.lowercased()) else { return }
                    MacDocumentExchange.shared.attach(to:engine)
                    do { try engine.load(from: url) }
                    catch { engine.showTemporaryStatus("開啟失敗：\(error.localizedDescription)") }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .windowSize) {
                Button(L10n.t("放大／還原視窗")) {
                    // AppKit zoom 會保留還原尺寸及目前螢幕的工作區，不進入另一個 Space。
                    // 透明螢幕畫布的 NSPanel 不能套用普通視窗縮放。
                    guard let window = NSApplication.shared.keyWindow,
                          !(window is NSPanel), window.styleMask.contains(.resizable),
                          !window.styleMask.contains(.fullScreen) else { return }
                    window.performZoom(nil)
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(screenCanvas.isActive)
            }
            CommandGroup(replacing: .newItem) {
                Button(L10n.t("開啟黑板專案檔 (.heiban)...")) {
                    engine.openFromFilePrompt()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(L10n.t("儲存黑板專案檔 (.heiban)...")) {
                    if screenCanvas.focusedEngine != nil { screenCanvas.saveEditable() }
                    else { engine.saveToFilePrompt() }
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandGroup(replacing: .pasteboard) {
                Button(L10n.t("剪下")) { performClipboardAction("cut:") { commandEngine.cutSelected() } }
                    .keyboardShortcut("x", modifiers: .command)
                Button(L10n.t("拷貝")) { performClipboardAction("copy:") { commandEngine.copySelected() } }
                    .keyboardShortcut("c", modifiers: .command)
                Button(L10n.t("貼上")) { performClipboardAction("paste:") { commandEngine.pasteClipboard() } }
                    .keyboardShortcut("v", modifiers: .command)
            }
            CommandMenu(L10n.t("螢幕畫布")) {
                Button(screenCanvas.isActive ? "切換作畫／操作　⌘⌥⇧D" : "我的螢幕就是我的畫布　⌘⌥⇧D") { screenCanvas.toggleDrawing() }
                Button(L10n.t("操作螢幕")) { screenCanvas.setDrawing(false) }
                    .disabled(!screenCanvas.isActive || !screenCanvas.isDrawing || screenCanvas.isCapturing)
                Button(L10n.t("繼續作畫")) { screenCanvas.setDrawing(true) }
                    .disabled(!screenCanvas.isActive || screenCanvas.isDrawing || screenCanvas.isCapturing)
                Button(L10n.t("顯示螢幕畫布工具列")) { screenCanvas.showControlsForInteraction() }
                    .disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
                Button(L10n.t("截圖並儲存　⌘⌥⇧S")) { screenCanvas.captureScreen() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
                Button(L10n.t("儲存可編輯註記…")) { screenCanvas.saveEditable() }.disabled(!screenCanvas.isActive)
                Button(L10n.t("一鍵清空螢幕畫布（可復原）")) { screenCanvas.clearAnnotations() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
                Button(L10n.t("結束螢幕畫布　⌘⌥⇧X")) { screenCanvas.stop() }.disabled(!screenCanvas.isActive)
            }
            CommandGroup(replacing: .help) { Button(L10n.t("黑板使用手冊")) { HeiBanUserGuide.shared.show() } }
            CommandGroup(replacing: .undoRedo) {
                Button(L10n.t("復原")) { commandEngine.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!commandEngine.canUndo || commandEngine.readingMode)
                Button(L10n.t("重做")) { commandEngine.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!commandEngine.canRedo || commandEngine.readingMode)
            }
        }
        MenuBarExtra("黑板螢幕畫布", systemImage: "pencil.tip.crop.circle") {
            Button(screenCanvas.isActive ? "切換作畫／操作　⌘⌥⇧D" : "開啟螢幕畫布　⌘⌥⇧D") { screenCanvas.toggleDrawing() }
            Button(L10n.t("操作螢幕")) { screenCanvas.setDrawing(false) }
                .disabled(!screenCanvas.isActive || !screenCanvas.isDrawing || screenCanvas.isCapturing)
            Button(L10n.t("繼續作畫")) { screenCanvas.setDrawing(true) }
                .disabled(!screenCanvas.isActive || screenCanvas.isDrawing || screenCanvas.isCapturing)
            Button(L10n.t("顯示螢幕畫布工具列")) { screenCanvas.showControlsForInteraction() }
                .disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
            Button(L10n.t("截圖並儲存　⌘⌥⇧S")) { screenCanvas.captureScreen() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
            Button(L10n.t("一鍵清空螢幕畫布（可復原）")) { screenCanvas.clearAnnotations() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
            Button(L10n.t("結束螢幕畫布　⌘⌥⇧X")) { screenCanvas.stop() }.disabled(!screenCanvas.isActive)
            Divider()
            Button(L10n.t("使用手冊")) { HeiBanUserGuide.shared.show() }
        }
    }
}

private final class HeiBanAppDelegate: NSObject, NSApplicationDelegate {
    var persistBeforeQuit: ((@escaping (Bool) -> Void) -> Void)?
    private var terminationInProgress = false
    private var terminationEventMonitor: Any?
    private var terminationPanel: NSPanel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let persistBeforeQuit else { return .terminateNow }
        guard !terminationInProgress else { return .terminateCancel }
        terminationInProgress = true
        let panel=NSPanel(contentRect:NSRect(x:0,y:0,width:300,height:100),styleMask:[.titled,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title=L10n.t("儲存中…");panel.isReleasedWhenClosed=false
        let spinner=NSProgressIndicator(frame:NSRect(x:24,y:38,width:24,height:24));spinner.style = .spinning;spinner.startAnimation(nil)
        let label=NSTextField(labelWithString:L10n.t("正在保存作品，完成後離開…"));label.frame=NSRect(x:62,y:36,width:220,height:28)
        panel.contentView?.addSubview(spinner);panel.contentView?.addSubview(label);panel.center();panel.orderFrontRegardless();terminationPanel=panel
        terminationEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
                       .rightMouseDown, .rightMouseUp, .rightMouseDragged,
                       .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel]
        ) { [weak self] event in
            self?.terminationInProgress == true ? nil : event
        }
        persistBeforeQuit { [weak self] saved in
            DispatchQueue.main.async {
                guard let self else { return }
                self.terminationInProgress = false
                self.terminationPanel?.close();self.terminationPanel=nil
                if let monitor = self.terminationEventMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.terminationEventMonitor = nil
                }
                sender.reply(toApplicationShouldTerminate: saved)
            }
        }
        return .terminateLater
    }
}
