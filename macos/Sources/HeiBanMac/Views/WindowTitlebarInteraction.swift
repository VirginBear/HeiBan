import AppKit
import SwiftUI

/// hiddenTitleBar 的空白區在不同 macOS 版本不一定執行原生雙擊動作。
/// 只補普通作品視窗的標題列事件，不覆蓋 SwiftUI 的 window delegate。
struct WindowTitlebarInteraction: NSViewRepresentable {
    func makeNSView(context: Context) -> TitlebarObserverView { TitlebarObserverView() }
    func updateNSView(_ nsView: TitlebarObserverView, context: Context) {}

    static func dismantleNSView(_ nsView: TitlebarObserverView, coordinator: ()) {
        nsView.stopObserving()
    }

    final class TitlebarObserverView: NSView {
        private var eventMonitor: Any?

        // 觀察視窗附著／離開，不接管內容命中；文字框、畫布及控制項照原路徑處理。
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard window != nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
                [weak self] event in
                guard let window = self?.window, event.window === window,
                      event.clickCount == 2, !(window is NSPanel),
                      window.styleMask.contains(.titled), window.styleMask.contains(.resizable),
                      !window.styleMask.contains(.fullScreen), window.attachedSheet == nil,
                      Self.isTitlebarPoint(event.locationInWindow, in: window) else { return event }
                window.performZoom(nil)
                // 不再把同一個雙擊交給 AppKit，以免系統也縮放而立刻還原。
                return nil
            }
        }

        private static func isTitlebarPoint(_ point: NSPoint, in window: NSWindow) -> Bool {
            let height = window.frame.height
            // fullSizeContentView 有時回報 layout rect 延伸到頂端；至少保留原生
            // traffic lights 的 28 pt 標題列。上緣 3 pt 留給系統調整視窗尺寸。
            let bottom = min(window.contentLayoutRect.maxY, height - 28)
            guard point.y >= bottom, point.y < height - 3 else { return false }
            let controlsRight = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
                .compactMap { window.standardWindowButton($0) }
                .map { $0.convert($0.bounds, to: nil).maxX }
                .max() ?? 76
            return point.x > controlsRight + 8 && point.x < window.frame.width - 3
        }

        func stopObserving() {
            if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
            eventMonitor = nil
        }

        deinit { if let eventMonitor { NSEvent.removeMonitor(eventMonitor) } }
    }
}
