import AppKit
import HeiBanCore
import SwiftUI

struct MagnetTargetOverlay: View {
    @ObservedObject var state: DrawingAssistState
    let viewport: ViewportTransform
    var body: some View {
        if let p = state.target {
            Circle().stroke(Color(hex: "#39735a"), lineWidth: 2).background(
                Circle().fill(.white.opacity(0.8))
            )
            .frame(width: 12, height: 12).position(
                x: p.x * viewport.zoom + viewport.x, y: p.y * viewport.zoom + viewport.y
            )
            .allowsHitTesting(false)
        }
    }
}

/// copy 資源以 URL 明確載入，不依賴 SwiftUI 對裸 PNG 名稱的資產目錄查找。
/// 原圖無法讀取時仍提供板擦輪廓，避免只剩看不見的 hit target。
struct BoardEraserArtwork: View {
    private static let image: NSImage? = Bundle.module.url(forResource: "BoardEraser", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
    var body: some View {
        if let image = Self.image {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#d6dfd0"))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#39735a"), lineWidth: 3))
        }
    }
}

struct BoardEraserOverlay: View {
    @ObservedObject var engine: BoardEngine
    @ObservedObject var state: BoardEraserState
    let size: CGSize
    let onInteraction: () -> Void
    init(engine: BoardEngine, size: CGSize, onInteraction: @escaping () -> Void = {}) {
        self.engine = engine
        self.state = engine.boardEraser
        self.size = size
        self.onInteraction = onInteraction
    }
    private var origin: CGPoint {
        if let p = state.pointer { return CGPoint(x: p.x - state.grip.x, y: p.y - state.grip.y) }
        return CGPoint(
            x: max(0, size.width - BoardEraserGeometry.width - 20),
            y: max(0, size.height - BoardEraserGeometry.height - 40))
    }
    private var spriteTransform: CGAffineTransform {
        let t = BoardEraserGeometry.imageTransform
        let cx = BoardEraserGeometry.width / 2
        let cy = BoardEraserGeometry.height / 2
        let m = CGAffineTransform(a: t.m11, b: t.m12, c: t.m21, d: t.m22, tx: 0, ty: 0)
        return CGAffineTransform(translationX: -cx, y: -cy)
            .concatenating(m)
            .concatenating(CGAffineTransform(translationX: cx, y: cy))
    }
    var body: some View {
        if engine.toolbarPreferences.boardEraserVisible && !engine.readingMode {
            ZStack {
                BoardEraserArtwork()
                    .transformEffect(spriteTransform)
                    .opacity(state.pointer == nil ? 1 : 0.78).allowsHitTesting(false)
                BoardEraserPointer(engine: engine, origin: origin, onInteraction: onInteraction)
            }
            .frame(width: BoardEraserGeometry.width, height: BoardEraserGeometry.height)
            .position(
                x: origin.x + BoardEraserGeometry.width / 2, y: origin.y + BoardEraserGeometry.height / 2
            )
            .help(L10n.t("拖曳板擦清除筆畫與圖形；右鍵切換擦除模式或隱藏"))
        }
    }
}

private struct BoardEraserPointer: NSViewRepresentable {
    let engine: BoardEngine
    let origin: CGPoint
    let onInteraction: () -> Void
    func makeNSView(context: Context) -> Surface { Surface(engine: engine, origin: origin, onInteraction: onInteraction) }
    func updateNSView(_ view: Surface, context: Context) {
        view.origin = origin
        view.onInteraction = onInteraction
    }
    static func dismantleNSView(_ view: Surface, coordinator: ()) { view.engine.cancelBoardEraser() }
    final class Surface: NSView {
        let engine: BoardEngine
        var origin: CGPoint
        var onInteraction: () -> Void
        var startWindow: CGPoint?, startCanvas: Point?
        private var resignObserver: NSObjectProtocol?
        deinit {
            if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        }
        private func cancelDrag() {
            engine.cancelBoardEraser()
            startWindow = nil
            startCanvas = nil
        }
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        init(engine: BoardEngine, origin: CGPoint, onInteraction: @escaping () -> Void) {
            self.engine = engine
            self.origin = origin
            self.onInteraction = onInteraction
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let hit = super.hitTest(point),
                BoardEraserGeometry.canGrab(Point(convert(point, from: superview)))
            else { return nil }
            return hit
        }
        override func mouseDown(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            guard BoardEraserGeometry.canGrab(Point(p)) else { return }
            onInteraction()  // 螢幕模式先切換本顯示器，Undo 與控制列才會指向同一引擎。
            window?.makeFirstResponder(self)
            startWindow = event.locationInWindow
            let canvas = Point(x: p.x + origin.x, y: p.y + origin.y)
            startCanvas = canvas
            engine.beginBoardEraser(at: canvas, grip: Point(p))
        }
        override func mouseDragged(with event: NSEvent) {
            guard let startWindow, let startCanvas else { return }
            engine.moveBoardEraser(
                to: Point(
                    x: startCanvas.x + event.locationInWindow.x - startWindow.x,
                    y: startCanvas.y - event.locationInWindow.y + startWindow.y))
        }
        override func mouseUp(with event: NSEvent) {
            mouseDragged(with: event)
            engine.finishBoardEraser()
            startWindow = nil
            startCanvas = nil
        }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 {
                cancelDrag()
            } else {
                super.keyDown(with: event)
            }
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
            resignObserver = nil
            cancelDrag()
            if let window {
                resignObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResignKeyNotification, object: window, queue: .main
                ) { [weak self] _ in self?.cancelDrag() }
            }
        }
        override func rightMouseDown(with event: NSEvent) {
            let menu = NSMenu()
            for (title, action) in [
                ("物件擦除（筆畫與圖形）", #selector(whole)), ("局部擦除（只擦筆跡）", #selector(partial)),
                ("隱藏板擦", #selector(hideEraser)),
            ] {
                let item = NSMenuItem(title: L10n.t(title), action: action, keyEquivalent: "")
                item.target = self
                if action == #selector(whole) { item.state = engine.eraserMode == .object ? .on : .off }
                if action == #selector(partial) { item.state = engine.eraserMode == .object ? .off : .on }
                menu.addItem(item)
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
        @objc private func whole() { engine.eraserMode = .object }
        @objc private func partial() { engine.eraserMode = .pixel }
        @objc private func hideEraser() { engine.setBoardEraserVisible(false) }
    }
}
