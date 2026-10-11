import AppKit
import SwiftUI

/// Only the grip moves the native panel. Sliders and buttons never drag the window.
struct AnnotationPanelGrip: NSViewRepresentable {
    var onBegin: (NSPoint) -> Void
    var onMove: (NSPoint) -> Void
    var onEnd: (NSPoint) -> Void

    func makeNSView(context: Context) -> GripView {
        let view = GripView(frame: .zero)
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ nsView: GripView, context: Context) {
        nsView.onBegin = onBegin
        nsView.onMove = onMove
        nsView.onEnd = onEnd
    }

    final class GripView: NSView {
        var onBegin: ((NSPoint) -> Void)?
        var onMove: ((NSPoint) -> Void)?
        var onEnd: ((NSPoint) -> Void)?
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "移動螢幕畫布控制列")?
                .draw(in: bounds.insetBy(dx: 2, dy: 5))
        }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
        override func mouseDown(with event: NSEvent) {
            onBegin?(NSEvent.mouseLocation)
        }
        override func mouseDragged(with event: NSEvent) {
            onMove?(NSEvent.mouseLocation)
        }
        override func mouseUp(with event: NSEvent) { onEnd?(NSEvent.mouseLocation) }
    }
}
