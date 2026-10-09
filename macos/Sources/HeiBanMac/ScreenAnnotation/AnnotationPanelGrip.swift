import AppKit
import SwiftUI

/// Only the grip moves the native panel. Sliders and buttons never drag the window.
struct AnnotationPanelGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> GripView { GripView(frame: .zero) }
    func updateNSView(_ nsView: GripView, context: Context) {}

    final class GripView: NSView {
        private var mouseOrigin = CGPoint.zero
        private var windowOrigin = CGPoint.zero
        override var mouseDownCanMoveWindow: Bool { false }
        override func draw(_ dirtyRect: NSRect) {
            NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "移動螢幕畫布控制列")?
                .draw(in: bounds.insetBy(dx: 2, dy: 5))
        }
        override func mouseDown(with event: NSEvent) {
            mouseOrigin = NSEvent.mouseLocation
            windowOrigin = window?.frame.origin ?? .zero
        }
        override func mouseDragged(with event: NSEvent) {
            guard let window else { return }
            let point = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? window.screen
            var origin = CGPoint(x: windowOrigin.x + point.x - mouseOrigin.x, y: windowOrigin.y + point.y - mouseOrigin.y)
            if let frame = screen?.visibleFrame {
                origin.x = min(max(frame.minX, origin.x), max(frame.minX, frame.maxX - window.frame.width))
                origin.y = min(max(frame.minY, origin.y), max(frame.minY, frame.maxY - window.frame.height))
            }
            window.setFrameOrigin(origin)
        }
    }
}
