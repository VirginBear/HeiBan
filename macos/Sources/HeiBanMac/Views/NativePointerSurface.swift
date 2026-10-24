import AppKit
import SwiftUI
import HeiBanCore

/// Deliver native mouse samples directly, without SwiftUI drag recognition/layout per sample.
struct NativePointerSurface: NSViewRepresentable {
    let engine: BoardEngine
    var onInteraction: (() -> Void)? = nil
    var screenAnnotation = false
    func makeNSView(context: Context) -> PointerView { let view = PointerView(engine: engine, onInteraction: onInteraction); view.screenAnnotation = screenAnnotation; return view }
    func updateNSView(_ view: PointerView, context: Context) { view.engine = engine; view.onInteraction = onInteraction; view.screenAnnotation = screenAnnotation }
    static func dismantleNSView(_ view: PointerView, coordinator: ()) {
        view.engine.holdTimer?.invalidate()
        view.engine.cancelEraserSwipe()
    }

    // 螢幕註記覆寫空白區域／首點命中，仍共用同一套筆畫、選取與鍵盤路由。
    class PointerView: NSView {
        var engine: BoardEngine
        var screenAnnotation = false
        var onInteraction: (() -> Void)?
        private var start: CGPoint?
        private var middleStart: CGPoint?
        private var magnification = 1.0
        private var windowObserver: NSObjectProtocol?
        private var hoverMonitor: Any?
        private let textContext = TextStyleContextMenu()
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        init(engine: BoardEngine, onInteraction: (() -> Void)?) { self.engine = engine; self.onInteraction = onInteraction; super.init(frame: .zero) }
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
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
        }
        override func mouseEntered(with event: NSEvent) { onInteraction?(); updateEraserCursor(event); updatePolygonCursor(event); updateTransformCursor(event); updateHoverToolCursor(event) }
        override func mouseMoved(with event: NSEvent) {
            engine.updateMagnetHover(at: Point(point(event)))
            if engine.laserEngine.isEnabled && !engine.isHoldingSpace {
                engine.laserEngine.addSample(point: VectorMath.screenToWorld(Point(point(event)), viewport: engine.viewport))
            }
            updateEraserCursor(event); updatePolygonCursor(event); updateTransformCursor(event); updateHoverToolCursor(event)
        }
        override func mouseExited(with event: NSEvent) {
            engine.updateMagnetHover(at: nil)
            engine.laserEngine.beginTrail()
            engine.updateEraserCursor(at: nil)
            engine.updateHoverCursor(at: nil, diameter: nil)
            engine.updateHoveredHandle(at: nil)
            CursorHelper.setCursor(for: nil)
        }
        override func cursorUpdate(with event: NSEvent) {
            updateTransformCursor(event)
            updateEraserCursor(event)
            updateHoverToolCursor(event)
        }
        override func mouseDown(with event: NSEvent) {
            onInteraction?()
            if screenAnnotation {
                window?.makeKey()
                if engine.showInlineTextEditor { engine.commitInlineTextEntry() }
            }
            window?.makeFirstResponder(self)
            let location = point(event)
            start = location
            updateEraserCursor(event)
            updatePolygonCursor(event)
            updateHoverToolCursor(event)
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
            updateHoverToolCursor(event)
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
            guard !engine.readingMode else { return }
            if engine.showInlineTextEditor { engine.commitInlineTextEntry() }
            onInteraction?()
            window?.makeFirstResponder(self)
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
            let delete = NSMenuItem(title: L10n.t("刪除"), action: #selector(deleteFromContext(_:)), keyEquivalent: "")
            delete.target = self
            delete.isEnabled = hasSelection
            menu.addItem(delete)
            let copy = NSMenuItem(title: L10n.t("複製"), action: #selector(copyFromContext(_:)), keyEquivalent: "")
            copy.target = self
            copy.isEnabled = hasSelection
            menu.addItem(copy)
            let clone = NSMenuItem(title: L10n.t("建立副本"), action: #selector(cloneFromContext(_:)), keyEquivalent: "")
            clone.target = self
            clone.isEnabled = hasSelection
            menu.addItem(clone)
            let cut = NSMenuItem(title: L10n.t("剪下"), action: #selector(cutFromContext(_:)), keyEquivalent: "")
            cut.target = self
            cut.isEnabled = hasSelection
            menu.addItem(cut)
            menu.addItem(.separator())
            let paste = NSMenuItem(title: L10n.t("貼上"), action: #selector(pasteFromContext(_:)), keyEquivalent: "")
            paste.target = self
            paste.isEnabled = NSPasteboard.general.string(forType: .string) != nil || MacPlatformPasteboardService.containsImage
            menu.addItem(paste)
            textContext.append(to: menu, engine: engine, view: self, point: location)
            menu.popUp(positioning: nil, at: location, in: self)
        }

        override func otherMouseDown(with event: NSEvent) {
            guard event.buttonNumber == 2 else { super.otherMouseDown(with: event); return }
            middleStart = point(event)
            engine.endPanGesture()
            NSCursor.closedHand.set()
        }
        override func otherMouseDragged(with event: NSEvent) {
            guard event.buttonNumber == 2, let middleStart else { super.otherMouseDragged(with: event); return }
            let location = point(event)
            NSCursor.closedHand.set()
            engine.updatePanGesture(translation: CGSize(width: location.x - middleStart.x, height: location.y - middleStart.y))
        }
        override func otherMouseUp(with event: NSEvent) {
            guard event.buttonNumber == 2 else { super.otherMouseUp(with: event); return }
            middleStart = nil
            engine.endPanGesture()
            updateTransformCursor(event)
        }

        private func updateEraserCursor(_ event: NSEvent) {
            engine.updateEraserCursor(at: engine.currentTool == .eraser ? Point(point(event)) : nil)
        }
        private func updatePolygonCursor(_ event: NSEvent) {
            engine.updatePolygonDraftCursor(at: Point(point(event)))
        }
        private func updateTransformCursor(_ event: NSEvent) {
            if middleStart != nil {
                NSCursor.closedHand.set()
                return
            }
            if engine.laserEngine.isEnabled && !engine.isHoldingSpace {
                NSCursor.crosshair.set()
                return
            }
            if engine.readingMode || engine.isHoldingSpace { NSCursor.openHand.set(); return }
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
            if engine.laserEngine.isEnabled {
                // Laser positions belong to its display-rate buffer, not BoardEngine's
                // published cursor state (which would redraw the entire canvas).
                engine.updateHoverCursor(at: nil, diameter: nil)
                return
            }
            guard let diameter = engine.toolCursorDiameter, diameter > 0 else {
                engine.updateHoverCursor(at: nil, diameter: nil)
                return
            }
            engine.updateHoverCursor(at: Point(point(event)), diameter: diameter)
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
            guard !engine.readingMode && !engine.isHoldingSpace else { return }
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
            if engine.readingMode {
                switch action {
                case .spaceDown, .spaceUp, .escape, .switchTool, .openBoard, .save, .saveAs, .newBoard: break
                default: return
                }
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
            guard !engine.inlineTextEditing && !engine.showTextEditor else { return }
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
            if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
            windowObserver = nil
            if let hoverMonitor { NSEvent.removeMonitor(hoverMonitor) }
            hoverMonitor = nil
            if let window = self.window {
                window.acceptsMouseMovedEvents = true
                hoverMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel, .keyDown, .keyUp]) { [weak self] event in
                    guard let self, event.window === self.window else { return event }
                    if event.type == .keyDown || event.type == .keyUp {
                        guard event.keyCode == 49, !self.engine.inlineTextEditing, !self.engine.showTextEditor,
                              !(self.window?.firstResponder is NSTextView) else { return event }
                        self.engine.isHoldingSpace = event.type == .keyDown
                        if event.type == .keyDown { NSCursor.openHand.set() } else { NSCursor.arrow.set() }
                        return nil
                    }
                    let location = self.point(event)
                    if self.bounds.contains(location) {
                        self.updateEraserCursor(event)
                        self.updateHoverToolCursor(event)
                    } else {
                        self.engine.updateEraserCursor(at: nil)
                        self.engine.updateHoverCursor(at: nil, diameter: nil)
                    }
                    return event
                }
                windowObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                    self?.engine.handleWindowBlur()
                    self?.engine.updateEraserCursor(at: nil)
                    self?.engine.updateHoverCursor(at: nil, diameter: nil)
                }
            }
        }

        deinit {
            if let hoverMonitor { NSEvent.removeMonitor(hoverMonitor) }
            if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
        }

        override func scrollWheel(with event: NSEvent) {
            // Text entry owns scrolling until it is committed or cancelled,
            // including events at its scroll limits or outside the editor panel.
            guard !engine.inlineTextEditing && !engine.showTextEditor else { return }
            let location = point(event)
            let isShift = event.modifierFlags.contains(.shift)
            let isCmd = event.modifierFlags.contains(.command)
            let isOpt = event.modifierFlags.contains(.option)
            let deltaX = Double(event.scrollingDeltaX)
            let deltaY = Double(event.scrollingDeltaY)

            // Physical mouse wheel zooms around its cursor. Trackpad two-finger
            // scrolling pans; Cmd/Option scrolling explicitly zooms on either device.
            let trackpadScroll = event.hasPreciseScrollingDeltas &&
                (!event.phase.isEmpty || !event.momentumPhase.isEmpty)
            let zooms = !trackpadScroll || isCmd || isOpt
            if !zooms || isShift {
                if isShift {
                    let dx = abs(deltaX) > 0 ? deltaX : deltaY
                    engine.panViewport(delta: CGSize(width: dx, height: 0))
                } else {
                    engine.panViewport(delta: CGSize(width: deltaX, height: deltaY))
                }
            } else {
                // Discrete mouse wheels report their forward direction independently
                // of the system's natural scrolling preference: up should zoom in.
                let zoomDelta = !trackpadScroll && event.isDirectionInvertedFromDevice ? -deltaY : deltaY
                engine.handleScrollWheel(at: Point(location), deltaX: 0, deltaY: zoomDelta, shift: false)
            }
        }

        override func resignFirstResponder() -> Bool {
            engine.handleWindowBlur()
            return super.resignFirstResponder()
        }
    }
}
