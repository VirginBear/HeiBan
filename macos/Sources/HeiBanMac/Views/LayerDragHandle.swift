import AppKit
import HeiBanCore
import SwiftUI
import UniformTypeIdentifiers

/// 私有型別只用來在本機當前圖層列表傳遞 ID，不接受外部檔案／作品物件。
enum LayerDragType {
    static let value = UTType(exportedAs: "com.bear.heiban.layer-drag", conformingTo: .data)
}

struct LayerDragHandle: NSViewRepresentable {
    let object: BoardObject
    var onStart: () -> Void
    var onFinish: () -> Void

    func makeNSView(context: Context) -> LayerGripView { LayerGripView() }
    func updateNSView(_ view: LayerGripView, context: Context) {
        view.objectID = object.id
        view.enabled = object.isLocked != true
        view.onStart = onStart
        view.onFinish = onFinish
        view.toolTip = view.enabled ? "拖曳調整圖層順序" : "先解鎖物件才能拖曳圖層"
        view.preview = {
            let renderer = ImageRenderer(content: LayerDragPreview(object: object))
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
            return renderer.nsImage
        }
        view.needsDisplay = true
    }
}

private struct LayerDragPreview: View {
    let object: BoardObject
    var body: some View {
        HStack(spacing: 8) {
            if object.type == "pin" {
                HeiBanPinIcon().frame(width: 20, height: 20)
            } else {
                Image(systemName: object.systemIconName).frame(width: 20, height: 20)
            }
            Text(object.displayName).font(.system(size: 12, weight: .medium)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.primary)
        .padding(10)
        .frame(width: 230, height: 42)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5)))
    }
}

/// AppKit 擁有拖曳的取消／放下生命週期。只握把啟動，避免跟改名／鎖定／隱藏競爭。
final class LayerGripView: NSView, NSDraggingSource {
    var objectID = ""
    var enabled = true
    var onStart: () -> Void = {}
    var onFinish: () -> Void = {}
    var preview: () -> NSImage? = { nil }
    private var mouseStart: NSPoint?
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.withAlphaComponent(enabled ? 0.6 : 0.2).setFill()
        for x in [CGFloat(5), CGFloat(10)] {
            for y in [bounds.midY - 5, bounds.midY, bounds.midY + 5] {
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) { mouseStart = convert(event.locationInWindow, from: nil) }
    override func mouseUp(with event: NSEvent) { mouseStart = nil }
    override func mouseDragged(with event: NSEvent) {
        guard enabled, let start = mouseStart, let image = preview() else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - start.x, point.y - start.y) > 3 else { return }
        mouseStart = nil
        let item = NSPasteboardItem()
        item.setString(objectID, forType: NSPasteboard.PasteboardType(LayerDragType.value.identifier))
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        draggingItem.setDraggingFrame(NSRect(origin: point, size: image.size), contents: image)
        onStart()
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onFinish() // 包含 Esc、拖出列表及失敗放下，清掉插入提示與來源淡化。
    }
}
