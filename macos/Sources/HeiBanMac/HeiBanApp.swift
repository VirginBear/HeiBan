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

    @ObservedObject private var screenCanvas = ScreenAnnotationController.shared

    private var commandEngine: BoardEngine { screenCanvas.focusedEngine ?? engine }

    var body: some Scene {
        WindowGroup {
            MainWindowView(engine: engine)
                .preferredColorScheme(.light)
                .onAppear {
                    NSApplication.shared.applicationIconImage = HeiBanBrand.appIcon
                    screenCanvas.registerShortcuts()
                    appDelegate.persistBeforeQuit = {
                        screenCanvas.stop()
                        guard !screenCanvas.isActive else { return false }
                        return engine.saveBeforeLeaving()
                    }
                }
                .onOpenURL { url in
                    guard url.isFileURL, ["heiban", "json"].contains(url.pathExtension.lowercased()) else { return }
                    do { try engine.load(from: url) }
                    catch { engine.showTemporaryStatus("開啟失敗：\(error.localizedDescription)") }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("開啟黑板專案檔 (.heiban)...") {
                    engine.openFromFilePrompt()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("儲存黑板專案檔 (.heiban)...") {
                    if screenCanvas.focusedEngine != nil { screenCanvas.saveEditable() }
                    else { engine.saveToFilePrompt() }
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandMenu("螢幕畫布") {
                Button(screenCanvas.isActive ? "切換作畫／操作　⌘⌥⇧D" : "我的螢幕就是我的畫布　⌘⌥⇧D") { screenCanvas.toggleDrawing() }
                Button("截圖並儲存　⌘⌥⇧S") { screenCanvas.captureScreen() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
                Button("儲存可編輯註記…") { screenCanvas.saveEditable() }.disabled(!screenCanvas.isActive)
                Button("一鍵清空螢幕畫布（可復原）") { screenCanvas.clearAnnotations() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
                Button("結束螢幕畫布　⌘⌥⇧X") { screenCanvas.stop() }.disabled(!screenCanvas.isActive)
            }
            CommandGroup(replacing: .help) { Button("黑板使用手冊") { HeiBanUserGuide.shared.show() } }
            CommandGroup(replacing: .undoRedo) {
                Button("復原") { commandEngine.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!commandEngine.canUndo || commandEngine.readingMode)
                Button("重做") { commandEngine.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!commandEngine.canRedo || commandEngine.readingMode)
            }
        }
        MenuBarExtra("黑板螢幕畫布", systemImage: "pencil.tip.crop.circle") {
            Button(screenCanvas.isActive ? "切換作畫／操作　⌘⌥⇧D" : "開啟螢幕畫布　⌘⌥⇧D") { screenCanvas.toggleDrawing() }
            Button("截圖並儲存　⌘⌥⇧S") { screenCanvas.captureScreen() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
            Button("一鍵清空螢幕畫布（可復原）") { screenCanvas.clearAnnotations() }.disabled(!screenCanvas.isActive || screenCanvas.isCapturing)
            Button("結束螢幕畫布　⌘⌥⇧X") { screenCanvas.stop() }.disabled(!screenCanvas.isActive)
            Divider()
            Button("使用手冊") { HeiBanUserGuide.shared.show() }
        }
    }
}

private final class HeiBanAppDelegate: NSObject, NSApplicationDelegate {
    var persistBeforeQuit: (() -> Bool)?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        (persistBeforeQuit?() ?? true) ? .terminateNow : .terminateCancel
    }
}
