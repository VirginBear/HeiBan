import AppKit
import HeiBanCore
import SwiftUI

/// 隱藏只影響導覽列命中，不重建子視圖／改變畫布大小；popover 可繼續持有錨點。
struct WorkspaceHeaderView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    var onVisibilityChanged: (Bool) -> Void = { _ in }
    @AppStorage("HeiBan.workspaceHeaderPinned") private var pinned = false
    @ViewState private var revealed = false
    @ViewState private var hovered = false
    @ViewState private var panelOpen = false
    @ViewState private var trackingMenus = 0
    @ViewState private var hideTask: Task<Void, Never>?

    private var visible: Bool { pinned || revealed || panelOpen || engine.showPinManager || trackingMenus > 0 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if engine.readingMode {
                    ReadingNavigationView(engine: engine, headerPinned: $pinned) { panelOpen = $0 }
                } else {
                    TopNavView(engine: engine, headerPinned: $pinned) { panelOpen = $0 }
                }
            }
                .opacity(visible ? 1 : 0)
                .allowsHitTesting(visible)
                .accessibilityHidden(!visible)
            if !visible {
                // 可點擊箭頭只佔右上 320×16 pt，其餘靠近區由穿透 tracking area 處理。
                Button(action: reveal) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .frame(width: 320, height: 16, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.t("顯示導覽列；也可將滑鼠移到右上角"))
                .accessibilityLabel(L10n.t("顯示導覽列"))
                .onHover { if $0 { reveal() } }
            }
        }
        .background(HeaderHoverSensor { inside in
            hovered = inside
            if inside { reveal() } else { scheduleHide() }
        })
        .animation(.easeOut(duration: 0.16), value: visible)
        .onChange(of: panelOpen) { _, open in if open { reveal() } else { scheduleHide() } }
        .onChange(of: engine.showPinManager) { _, open in if open { reveal() } else { scheduleHide() } }
        .onChange(of: pinned) { _, value in if value { reveal() } else { scheduleHide() } }
        .onChange(of: engine.readingMode) { _, _ in panelOpen = false; reveal() }
        // SwiftUI Menu 在 AppKit 視窗中追蹤，游標離開膠囊不能關掉選單錨點。
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
            guard visible else { return }
            trackingMenus += 1
            hideTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
            trackingMenus = max(0, trackingMenus - 1)
            scheduleHide()
        }
        .onAppear { onVisibilityChanged(visible) }
        .onChange(of: visible) { _, value in onVisibilityChanged(value) }
        .onDisappear { hideTask?.cancel(); onVisibilityChanged(false) }
    }

    private func reveal() {
        hideTask?.cancel()
        revealed = true
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard !pinned, !hovered, !panelOpen, !engine.showPinManager, trackingMenus == 0 else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            revealed = false
        }
    }
}

/// TrackingArea 在隱藏的膠囊範圍仍接近即顯示；hitTest 回 nil 讓落筆穿透到畫布。
private struct HeaderHoverSensor: NSViewRepresentable {
    var onHover: (Bool) -> Void
    func makeNSView(context: Context) -> HeaderTrackingView { HeaderTrackingView() }
    func updateNSView(_ view: HeaderTrackingView, context: Context) { view.onHover = onHover }
}

private final class HeaderTrackingView: NSView {
    var onHover: (Bool) -> Void = { _ in }
    private var area: NSTrackingArea?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let updated = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(updated)
        area = updated
    }
    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }
}
