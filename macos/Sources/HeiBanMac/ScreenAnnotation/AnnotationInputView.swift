import AppKit
import HeiBanCore
import SwiftUI

/// AppKit 擁有全螢幕輸入面積；SwiftUI 子視圖只負責畫出註記。
/// 空白畫布也必須命中，不能依註記已有的可見像素決定是否接收滑鼠。
final class AnnotationInputView: NativePointerSurface.PointerView {
    init(engine: BoardEngine, size: CGSize, onInteraction: @escaping () -> Void) {
        super.init(engine: engine, onInteraction: onInteraction)
        frame = NSRect(origin: .zero, size: size)
        autoresizingMask = [.width, .height]
        setAccessibilityRole(.group)
        setAccessibilityLabel("透明螢幕畫布")
        let renderer = AnnotationRenderHost(rootView: ScreenAnnotationCanvas(engine: engine))
        renderer.frame = bounds
        renderer.autoresizingMask = [.width, .height]
        addSubview(renderer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // hitTest 的輸入在父視圖座標；不要將 NSScreen 的全域 origin 混入落筆座標。
        let local = convert(point, from: superview)
        return !isHidden && bounds.contains(local) ? self : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        // 零 alpha 的 backing 像素可能被 WindowServer 視為可穿透。保留約 1% 的
        // 中性底層確保空白區域也可落筆；操作模式仍只由 ignoresMouseEvents 控制。
        NSColor.black.withAlphaComponent(0.01).setFill()
        dirtyRect.fill()
    }

    override func mouseDown(with event: NSEvent) {
        // 非啟動 panel 取得鍵盤焦點但不啟動主視窗，第一筆也能直接落下。
        window?.makeKey()
        super.mouseDown(with: event)
    }
}

private final class AnnotationRenderHost: NSHostingView<ScreenAnnotationCanvas> {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
