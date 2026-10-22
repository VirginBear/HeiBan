import AppKit
import WebKit

/// Offline instructions in a separate window, with no example boards added to the library.
final class HeiBanUserGuide: NSObject, NSWindowDelegate {
    static let shared = HeiBanUserGuide()
    private var window: NSWindow?
    private var currentLanguage: String?

    func show() {
        guard let url = Bundle.module.url(forResource:L10n.shared.code,withExtension:"html",subdirectory:"Guides")
            ?? Bundle.module.url(forResource:"HeiBanUserGuide",withExtension:"html") else { return }
        if let window {
            if currentLanguage != L10n.shared.code,let web=window.contentView as? WKWebView {
                web.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent());currentLanguage=L10n.shared.code
            }
            NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil);return
        }
        currentLanguage=L10n.shared.code
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 740),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        panel.title = L10n.t("黑板 · 使用手冊")
        panel.minSize = NSSize(width: 680, height: 480)
        panel.contentView = webView
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { window = nil }
}
