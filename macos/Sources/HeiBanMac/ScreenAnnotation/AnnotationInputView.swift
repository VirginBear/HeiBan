import AppKit
import Combine
import HeiBanCore
import SwiftUI

/// AppKit 保有透明底層與文字輸入生命週期，SwiftUI 共用指標面及尺／圓規等互動元件。
/// 空白畫布也必須命中，不能依註記已有的可見像素決定是否接收滑鼠。
final class AnnotationInputView: NSView {
    let engine: BoardEngine
    private var editor: NSHostingView<AnnotationTextEditorPanel>?
    private var editorSubscription: AnyCancellable?

    init(engine: BoardEngine, size: CGSize, onInteraction: @escaping () -> Void) {
        self.engine = engine
        super.init(frame: .zero)
        frame = NSRect(origin: .zero, size: size)
        autoresizingMask = [.width, .height]
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.t("透明螢幕畫布"))
        let renderer = AnnotationRenderHost(rootView: ScreenAnnotationCanvas(engine: engine, onInteraction: { [weak self] in
            self?.window?.makeKey()
            onInteraction()
        }))
        renderer.frame = bounds
        renderer.autoresizingMask = [.width, .height]
        addSubview(renderer)
        // 只觀察編輯生命週期／錨點，不為每個滑鼠樣本重新排原生子視圖。
        editorSubscription = Publishers.CombineLatest(engine.$showInlineTextEditor, engine.$inlineTextPoint)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateEditor() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // hitTest 的輸入在父視圖座標；不要將 NSScreen 的全域 origin 混入落筆座標。
        let local = convert(point, from: superview)
        guard !isHidden, bounds.contains(local) else { return nil }
        if let editor, editor.frame.contains(local),
           // NSView.hitTest 接收父視圖座標；local 已是 editor 的父視圖座標。
           let hit = editor.hitTest(local) { return hit }
        // 共用指標面與互動工具疊層保留正常 SwiftUI 命中：尺／圓規／輔助面板不能被父輸入層攔截。
        for child in subviews.reversed() where child !== editor {
            if let hit = child.hitTest(local) { return hit }
        }
        return self
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
        if engine.showInlineTextEditor { engine.commitInlineTextEntry() }
        pointerReceiver?.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeKey()
        if engine.showInlineTextEditor { engine.commitInlineTextEntry() }
        pointerReceiver?.rightMouseDown(with: event)
    }

    /// 真正取樣與鍵盤路由的唯一 PointerView；父 host 不再建立第二套事件監聽器。
    var pointerReceiver: NativePointerSurface.PointerView? {
        func find(in view: NSView) -> NativePointerSurface.PointerView? {
            if let pointer = view as? NativePointerSurface.PointerView { return pointer }
            for child in view.subviews { if let pointer = find(in: child) { return pointer } }
            return nil
        }
        return find(in: self)
    }

    override func layout() {
        super.layout()
        positionEditor()
    }

    private func updateEditor() {
        guard engine.showInlineTextEditor else {
            if let editor {
                if let responder = window?.firstResponder as? NSView, responder.isDescendant(of: editor) {
                    window?.makeFirstResponder(pointerReceiver)
                }
                editor.removeFromSuperview()
                self.editor = nil
            }
            return
        }
        if editor == nil {
            let host = NSHostingView(rootView: AnnotationTextEditorPanel(engine: engine))
            host.sizingOptions = []
            editor = host
            addSubview(host)
        }
        positionEditor()
        window?.makeKey()
    }

    private func positionEditor() {
        guard let editor else { return }
        // 留出四邊工具列空間；使用每螢幕本地、向下為正的座標。
        let margin: CGFloat = 84
        let width = min(440, max(1, bounds.width - 2 * margin))
        let height = min(260, max(1, bounds.height - 2 * margin))
        let x = min(max(margin, engine.inlineTextPoint.x), max(margin, bounds.width - margin - width))
        let y = min(max(margin, engine.inlineTextPoint.y), max(margin, bounds.height - margin - height))
        editor.frame = NSRect(x: x, y: y, width: width, height: height)
    }
}

private struct AnnotationTextEditorPanel: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    var body: some View {
        InlineTextEditorPanel(engine: engine)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.16)))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
    }
}

private final class AnnotationRenderHost: NSHostingView<ScreenAnnotationCanvas> {
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
