import AppKit
import AVFoundation
import HeiBanCore
import SwiftUI

final class CaneSound {
    static let shared = CaneSound()
    private var player: AVAudioPlayer?
    private var loadError: String?

    private init() {
        guard let url = Bundle.module.url(forResource: "CaneSnap", withExtension: "wav") else {
            loadError = "找不到藤條音效資源 CaneSnap.wav"
            return
        }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            player = audioPlayer
        } catch {
            loadError = "藤條音效無法播放：\(error.localizedDescription)"
        }
    }

    func play(onError: ((String) -> Void)? = nil) {
        if let loadError {
            onError?(loadError)
            return
        }
        guard let player else { return }
        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        if !player.play() {
            onError?("藤條音效無法播放")
        }
    }

    func stop() {
        player?.stop()
    }
}

struct CaneArtwork: View {
    static let image: NSImage? = Bundle.module.url(forResource: "Cane", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
    var body: some View {
        if let image = Self.image {
            Image(nsImage: image).resizable()
        } else {
            HeiBanCaneIcon()
        }
    }
}

/// 一般畫布右下角藤條快捷按鈕，與板擦底邊對齊（間距 18pt），左鍵啟用藤條工具，右鍵可隱藏。
struct CaneQuickOverlay: View {
    @ObservedObject var engine: BoardEngine
    let size: CGSize

    private var layout: (width: Double, height: Double, originX: Double, originY: Double, rotation: Double) {
        let eraser = BoardEraserGeometry.displayBounds
        let unscaled = CanePose.dockBounds(width: BoardEraserGeometry.width, height: BoardEraserGeometry.height)
        let scale = max(eraser.width, eraser.height) / max(1.0, max(unscaled.width, unscaled.height))
        let w = BoardEraserGeometry.width * scale
        let h = BoardEraserGeometry.height * scale
        let cane = CanePose.dockBounds(width: w, height: h)
        var right = Double(size.width) - 20.0
        if engine.toolbarPreferences.boardEraserVisible {
            right -= eraser.width + 18.0
        }
        let bottom = Double(size.height) - 40.0
        let left = max(-cane.left, right - cane.right)
        let top = max(-cane.top, bottom - cane.bottom)
        let rot = CanePose.artworkRestRotationDegrees(width: w, height: h)
        return (w, h, left, top, rot)
    }

    var body: some View {
        if engine.toolbarPreferences.caneVisible && !engine.readingMode {
            let item = layout
            let active = engine.currentTool == .cane
            CaneArtwork()
                .rotationEffect(.degrees(item.rotation))
                .opacity(active ? 1.0 : 0.9)
                .shadow(color: active ? Color.accentColor.opacity(0.45) : .clear, radius: 6)
                .frame(width: item.width, height: item.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    engine.selectTool(.cane)
                }
                .contextMenu {
                    Button(L10n.t("隱藏藤條")) {
                        engine.setCaneVisible(false)
                    }
                }
                .position(x: item.originX + item.width * 0.5, y: item.originY + item.height * 0.5)
                .help(L10n.t("藤條：點擊切換教學拍打工具；右鍵可隱藏"))
        }
    }
}

/// 藤條教學工具畫布覆蓋層：握柄固定於滑鼠位置、45° 教學握持角、點擊揮動與 0.075s 擊中震波，絕不寫入作品物件。
struct CaneTeachingOverlay: View {
    @ObservedObject var engine: BoardEngine

    private func renderCane(in context: inout GraphicsContext, now: Double) {
        guard let worldPoint = engine.cane.point else { return }
        let p = VectorMath.worldToScreen(worldPoint, viewport: engine.viewport)
        let active = engine.cane.isActive(now: now)
        let elapsed = active ? max(0, now - engine.cane.startedAt) : -1
        let t = active ? min(1, elapsed / CaneFeedback.duration) : 1
        let swing = active ? CanePose.swingDegrees(elapsed: elapsed) : 0
        let impactProgress = active && elapsed >= CanePose.impactSeconds
            ? min(1, (elapsed - CanePose.impactSeconds) / (CaneFeedback.duration - CanePose.impactSeconds))
            : -1

        // 0.075s 杖尖擊中瞬間在杖尖位置繪製琥珀色擴散震波與短暫閃點
        if impactProgress >= 0 {
            let fade = 1.0 - impactProgress
            let tipAngle = (CanePose.restDegrees - swing) * .pi / 180.0
            let tipX = p.x + cos(tipAngle) * 188.0
            let tipY = p.y - sin(tipAngle) * 188.0
            let tipCenter = CGPoint(x: tipX, y: tipY)

            let r1 = CGFloat(8.0 + 34.0 * impactProgress)
            let ring1 = Path(ellipseIn: CGRect(x: tipCenter.x - r1, y: tipCenter.y - r1, width: r1 * 2, height: r1 * 2))
            context.stroke(ring1, with: .color(Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.78 * fade)), lineWidth: CGFloat(max(1.2, 2.8 * fade)))

            let r2 = CGFloat(3.0 + 20.0 * impactProgress)
            let ring2 = Path(ellipseIn: CGRect(x: tipCenter.x - r2, y: tipCenter.y - r2, width: r2 * 2, height: r2 * 2))
            context.stroke(ring2, with: .color(Color(red: 254/255, green: 243/255, blue: 199/255).opacity(0.68 * fade)), lineWidth: CGFloat(max(1.0, 1.8 * fade)))

            if impactProgress < 0.36 {
                let flashFade = 1.0 - impactProgress / 0.36
                let rf = CGFloat(3.8 * flashFade)
                let flash = Path(ellipseIn: CGRect(x: tipCenter.x - rf, y: tipCenter.y - rf, width: rf * 2, height: rf * 2))
                context.fill(flash, with: .color(Color(red: 255/255, green: 251/255, blue: 235/255).opacity(0.78 * flashFade)))
            }
        }

        let w = 248.0
        let h = 152.0
        let gripX = w * 0.09
        let gripY = h * 0.90
        let angleDegrees = CanePose.artworkRestRotationDegrees(width: w, height: h) - swing
        let alpha = active ? (0.98 - 0.08 * t) : 0.92

        context.drawLayer { layer in
            layer.opacity = alpha
            layer.translateBy(x: p.x, y: p.y)
            layer.rotate(by: .degrees(angleDegrees))
            layer.translateBy(x: -gripX, y: -gripY)
            if let nsImage = CaneArtwork.image {
                layer.draw(Image(nsImage: nsImage), in: CGRect(x: 0, y: 0, width: w, height: h))
            } else {
                var fallback = Path()
                fallback.move(to: CGPoint(x: gripX, y: gripY))
                fallback.addLine(to: CGPoint(x: w * 0.92, y: h * 0.12))
                layer.stroke(fallback, with: .color(Color(red: 180/255, green: 118/255, blue: 58/255)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
    }

    var body: some View {
        let _ = engine.caneRenderTick
        let now = ProcessInfo.processInfo.systemUptime
        let activeStrike = engine.cane.isActive(now: now)
        if (engine.currentTool == .cane || activeStrike) && engine.cane.point != nil {
            if activeStrike {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let tickNow = ProcessInfo.processInfo.systemUptime + timeline.date.timeIntervalSinceNow
                    Canvas { context, _ in
                        renderCane(in: &context, now: tickNow)
                    }
                }
                .allowsHitTesting(false)
            } else {
                Canvas { context, _ in
                    renderCane(in: &context, now: ProcessInfo.processInfo.systemUptime)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

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
        let eraser = BoardEraserGeometry.displayBounds
        let right = Double(size.width) - 20.0
        let bottom = Double(size.height) - 40.0
        let left = max(-eraser.left, right - eraser.right)
        let top = max(-eraser.top, bottom - eraser.bottom)
        return CGPoint(x: left, y: top)
    }
    private var spriteTransform: CGAffineTransform {
        let t = BoardEraserGeometry.imageTransform
        let cx = BoardEraserGeometry.width / 2
        let cy = BoardEraserGeometry.height / 2
        let m = CGAffineTransform(a: t.m11, b: t.m12, c: t.m21, d: t.m22, tx: t.m31, ty: t.m32)
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
