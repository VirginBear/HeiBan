import AppKit
import SwiftUI
import HeiBanCore

/// Deliver native mouse samples directly, without SwiftUI drag recognition/layout per sample.
struct NativePointerSurface: NSViewRepresentable {
    let engine: BoardEngine
    func makeNSView(context: Context) -> PointerView { PointerView(engine: engine) }
    func updateNSView(_ view: PointerView, context: Context) { view.engine = engine }
    static func dismantleNSView(_ view: PointerView, coordinator: ()) { view.engine.holdTimer?.invalidate() }

    final class PointerView: NSView {
        var engine: BoardEngine
        private var start: CGPoint?
        private var middleStart: CGPoint?
        private var magnification = 1.0
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }
        init(engine: BoardEngine) { self.engine = engine; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
        private func point(_ event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }
        private func translation(_ point: CGPoint) -> CGSize {
            guard let start else { return .zero }
            return CGSize(width: point.x - start.x, height: point.y - start.y)
        }
        override func flagsChanged(with event: NSEvent) {
            engine.isShiftHeld = event.modifierFlags.contains(.shift)
            super.flagsChanged(with: event)
        }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .cursorUpdate], owner: self, userInfo: nil))
        }
        override func mouseEntered(with event: NSEvent) { updateEraserCursor(event); updatePolygonCursor(event); updateTransformCursor(event); updateHoverToolCursor(event) }
        override func mouseMoved(with event: NSEvent) { updateEraserCursor(event); updatePolygonCursor(event); updateTransformCursor(event); updateHoverToolCursor(event) }
        override func mouseExited(with event: NSEvent) {
            engine.updateEraserCursor(at: nil)
            engine.updateHoverCursor(at: nil, diameter: nil)
            engine.updateHoveredHandle(at: nil)
            CursorHelper.setCursor(for: nil)
        }
        override func cursorUpdate(with event: NSEvent) { updateTransformCursor(event) }
        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            let location = point(event)
            start = location
            updateEraserCursor(event)
            updatePolygonCursor(event)
            let isShift = event.modifierFlags.contains(.shift)
            engine.beginPointerGesture(at: Point(location), isShift: isShift, clickCount: event.clickCount)
            updateTransformCursor(event)
            scheduleHold()
        }
        override func mouseDragged(with event: NSEvent) {
            guard start != nil else { return }
            let location = point(event)
            updateEraserCursor(event)
            updatePolygonCursor(event)
            let isShift = event.modifierFlags.contains(.shift)
            engine.updatePointerGesture(at: Point(location), translation: translation(location), isShift: isShift)
            updateTransformCursor(event)
            scheduleHold()
        }
        override func mouseUp(with event: NSEvent) {
            guard start != nil else { return }
            let location = point(event)
            let isShift = event.modifierFlags.contains(.shift)
            // Preserve a held recognized shape; movement samples already updated its preview.
            if engine.strokePreview.snappedShape == nil {
                engine.updatePointerGesture(at: Point(location), translation: translation(location), isShift: isShift)
            }
            engine.holdTimer?.invalidate()
            engine.holdTimer = nil
            engine.endPointerGesture(translation: translation(location))
            updateTransformCursor(event)
            start = nil
        }
        override func rightMouseDown(with event: NSEvent) {
            let location = point(event)
            let world = VectorMath.screenToWorld(Point(location), viewport: engine.viewport)
            if let hit = engine.currentPageObjects.reversed().first(where: {
                $0.isVisible != false && $0.isLocked != true &&
                VectorMath.isPointNearObject(point: world, object: $0, threshold: 8 / engine.viewport.zoom)
            }) {
                if !engine.selectedIds.contains(hit.id) { engine.selectedIds = [hit.id] }
            } else {
                engine.selectedIds.removeAll()
            }

            let menu = NSMenu()
            let hasSelection = !engine.selectedIds.isEmpty
            let delete = NSMenuItem(title: "刪除", action: #selector(deleteFromContext(_:)), keyEquivalent: "")
            delete.target = self
            delete.isEnabled = hasSelection
            menu.addItem(delete)
            let copy = NSMenuItem(title: "複製", action: #selector(copyFromContext(_:)), keyEquivalent: "")
            copy.target = self
            copy.isEnabled = hasSelection
            menu.addItem(copy)
            let clone = NSMenuItem(title: "建立副本", action: #selector(cloneFromContext(_:)), keyEquivalent: "")
            clone.target = self
            clone.isEnabled = hasSelection
            menu.addItem(clone)
            let cut = NSMenuItem(title: "剪下", action: #selector(cutFromContext(_:)), keyEquivalent: "")
            cut.target = self
            cut.isEnabled = hasSelection
            menu.addItem(cut)
            menu.addItem(.separator())
            let paste = NSMenuItem(title: "貼上", action: #selector(pasteFromContext(_:)), keyEquivalent: "")
            paste.target = self
            paste.isEnabled = !engine.internalClipboard.isEmpty || NSPasteboard.general.string(forType: .string) != nil
            menu.addItem(paste)
            menu.popUp(positioning: nil, at: location, in: self)
        }

        override func otherMouseDown(with event: NSEvent) {
            guard event.buttonNumber == 2 else { super.otherMouseDown(with: event); return }
            middleStart = point(event)
            engine.endPanGesture()
        }
        override func otherMouseDragged(with event: NSEvent) {
            guard event.buttonNumber == 2, let middleStart else { super.otherMouseDragged(with: event); return }
            let location = point(event)
            engine.updatePanGesture(translation: CGSize(width: location.x - middleStart.x, height: location.y - middleStart.y))
        }
        override func otherMouseUp(with event: NSEvent) {
            guard event.buttonNumber == 2 else { super.otherMouseUp(with: event); return }
            middleStart = nil
            engine.endPanGesture()
        }

        private func updateEraserCursor(_ event: NSEvent) {
            engine.updateEraserCursor(at: engine.currentTool == .eraser ? Point(point(event)) : nil)
        }
        private func updatePolygonCursor(_ event: NSEvent) {
            engine.updatePolygonDraftCursor(at: Point(point(event)))
        }
        private func updateTransformCursor(_ event: NSEvent) {
            let loc = point(event)
            let pt = Point(loc)
            engine.updateHoveredHandle(at: pt)
            if let cursorType = engine.currentCursorType(at: pt) {
                CursorHelper.setCursor(for: cursorType)
            } else if engine.currentTool == .select {
                CursorHelper.setCursor(for: nil)
            }
        }
        private func updateHoverToolCursor(_ event: NSEvent) {
            let loc = point(event)
            let pt = Point(loc)
            let zoom = engine.viewport.zoom
            if engine.currentTool == .eraser {
                let diameter = engine.eraserSize * zoom
                engine.updateHoverCursor(at: pt, diameter: diameter)
            } else if [.pen, .highlighter, .paint].contains(engine.currentTool) {
                let multiplier = engine.currentTool == .highlighter ? 3.5 : (engine.currentTool == .paint ? 8.0 : 1.0)
                let minWidth = engine.currentTool == .highlighter ? 12.0 : (engine.currentTool == .paint ? 24.0 : 4.0)
                let width = max(minWidth, engine.activeStrokeWidth * multiplier)
                let diameter = max(4, width * zoom)
                engine.updateHoverCursor(at: pt, diameter: diameter)
            } else {
                engine.updateHoverCursor(at: nil, diameter: nil)
            }
        }

        @objc private func deleteFromContext(_ sender: Any?) { engine.deleteSelected() }
        @objc private func copyFromContext(_ sender: Any?) { engine.copySelected() }
        @objc private func cloneFromContext(_ sender: Any?) {
            engine.copySelected()
            engine.pasteClipboard(offset: CGPoint(x: 24, y: 24))
        }
        @objc private func cutFromContext(_ sender: Any?) { engine.cutSelected() }
        @objc private func pasteFromContext(_ sender: Any?) { engine.pasteClipboard(offset: CGPoint(x: 24, y: 24)) }
        private func scheduleHold() {
            guard [ToolType.pen, .highlighter, .paint].contains(engine.currentTool) else { return }
            engine.holdTimer?.invalidate()
            engine.holdTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
                guard let self, self.start != nil else { return }
                self.engine.checkGoodnotesShapeSnap()
                if self.engine.strokePreview.snappedShape != nil {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
            }
        }
        override func keyDown(with event: NSEvent) {
            let isCmd = event.modifierFlags.contains(.command)
            let isShift = event.modifierFlags.contains(.shift)
            let isOpt = event.modifierFlags.contains(.option)
            let chars = event.charactersIgnoringModifiers

            let action = KeyboardShortcutCoordinator.resolveKeyAction(
                characters: chars,
                keyCode: event.keyCode,
                isCommand: isCmd,
                isShift: isShift,
                isOption: isOpt,
                isTextEditing: engine.inlineTextEditing,
                hasMarkedText: false
            )

            guard let action = action else {
                super.keyDown(with: event)
                return
            }

            switch action {
            case .newBoard:
                engine.createBoard(title: "未命名黑板")
            case .openBoard:
                engine.openFromFilePrompt()
            case .save:
                engine.saveToFilePrompt()
            case .saveAs:
                engine.saveToFilePrompt()
            case .undo:
                engine.undo()
            case .redo:
                engine.redo()
            case .copy:
                engine.copySelected()
            case .cut:
                engine.cutSelected()
            case .paste:
                engine.pasteClipboard()
            case .selectAll:
                engine.selectedIds = Set(engine.currentPageObjects.map(\.id))
            case .duplicate:
                engine.duplicateSelected()
            case .delete:
                engine.deleteSelected()
            case .group:
                engine.groupSelected()
            case .ungroup:
                engine.ungroupSelected()
            case .escape:
                engine.holdTimer?.invalidate()
                engine.cancelTransientInteraction()
                start = nil
            case .spaceDown:
                engine.isHoldingSpace = true
            case .spaceUp:
                engine.isHoldingSpace = false
            case .switchTool(let tool):
                engine.selectTool(tool)
            case .toggleInspector:
                engine.showInspector.toggle()
            case .toggleLayerPanel:
                engine.showLayerPanel.toggle()
            }
        }
        override func keyUp(with event: NSEvent) {
            if event.keyCode == 49 { engine.isHoldingSpace = false }
            else { super.keyUp(with: event) }
        }
        override func magnify(with event: NSEvent) {
            if event.phase == .began { magnification = 1 }
            magnification *= max(0.01, 1 + event.magnification)
            engine.updateMagnificationGesture(scale: magnification, around: Point(point(event)))
            if event.phase == .ended || event.phase == .cancelled {
                engine.endMagnificationGesture()
                magnification = 1
            }
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = self.window {
                NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                    self?.engine.handleWindowBlur()
                }
            }
        }

        override func scrollWheel(with event: NSEvent) {
            let location = point(event)
            let isShift = event.modifierFlags.contains(.shift)
            let isCmd = event.modifierFlags.contains(.command)
            let isOpt = event.modifierFlags.contains(.option)
            let deltaX = Double(event.scrollingDeltaX)
            let deltaY = Double(event.scrollingDeltaY)

            if event.hasPreciseScrollingDeltas && !isCmd && !isOpt {
                if isShift {
                    let dx = abs(deltaX) > 0 ? deltaX : deltaY
                    engine.panViewport(delta: CGSize(width: dx, height: 0))
                } else {
                    engine.panViewport(delta: CGSize(width: deltaX, height: deltaY))
                }
            } else {
                engine.handleScrollWheel(at: Point(location), deltaX: deltaX, deltaY: deltaY, shift: isShift)
            }
        }

        override func resignFirstResponder() -> Bool {
            engine.handleWindowBlur()
            return super.resignFirstResponder()
        }
    }
}
