import SwiftUI
import AppKit
import HeiBanCore

@main
struct HeiBanApp: App {
    @StateObject private var engine: BoardEngine = {
        let eng = BoardEngine()
        eng.dialogService = MacPlatformDialogService()
        eng.pasteboardService = MacPlatformPasteboardService()
        eng.imageDecoderService = MacPlatformImageDecoderService()
        return eng
    }()

    var body: some Scene {
        WindowGroup {
            MainWindowView(engine: engine)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("開啟黑板專案檔 (.blackboard.json)...") {
                    engine.openFromFilePrompt()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("儲存黑板專案檔 (.blackboard.json)...") {
                    engine.saveToFilePrompt()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("復原") { engine.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!engine.canUndo)
                Button("重做") { engine.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!engine.canRedo)
            }
        }
    }
}
