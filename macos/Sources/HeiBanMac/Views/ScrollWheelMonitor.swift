import AppKit
import SwiftUI
import HeiBanCore

/// Observes wheel input without taking mouse/touch events away from the canvas.
struct ScrollWheelMonitor: NSViewRepresentable {
    let onScroll: (Point, Double, Double, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        context.coordinator.view = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: PassthroughView, context: Context) {
        context.coordinator.onScroll = onScroll
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: PassthroughView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    final class Coordinator {
        weak var view: PassthroughView?
        var onScroll: (Point, Double, Double, Bool) -> Void
        private var monitor: Any?

        init(onScroll: @escaping (Point, Double, Double, Bool) -> Void) {
            self.onScroll = onScroll
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let view = self.view, event.window === view.window,
                      view.window != nil else { return event }
                let pointInView = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(pointInView) else { return event }
                let point = Point(x: pointInView.x, y: view.bounds.height - pointInView.y)
                self.onScroll(
                    point,
                    Double(event.scrollingDeltaX),
                    Double(event.scrollingDeltaY),
                    event.modifierFlags.contains(.shift)
                )
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit { removeMonitor() }
    }
}
