import CoreGraphics
import Foundation

extension BoardEngine {
    public func setReadingMode(_ enabled: Bool) {
        if inlineTextEditing { commitInlineTextEntry() }
        if showTextEditor { commitTextEntry() }
        cancelTransientInteraction()
        endMagnificationGesture()
        showPinPopover = false
        readingMode = enabled
        if enabled {
            showInspector = false
            showLayerPanel = false
        }
    }
    public func setViewportLocked(_ locked: Bool) {
        if inlineTextEditing { commitInlineTextEntry() }
        if showTextEditor { commitTextEntry() }
        let tool = currentTool
        cancelTransientInteraction()
        endMagnificationGesture()
        currentTool = tool
        viewportLocked = locked
    }
    public func setNavigationZoom(_ zoom: Double) {
        guard zoom.isFinite, !viewportLocked, !isPointerGestureActive, !inlineTextEditing, !showTextEditor
        else { return }
        let center = Point(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let world = VectorMath.screenToWorld(center, viewport: viewport)
        let next = max(0.08, min(8, zoom))
        viewport = ViewportTransform(x: center.x - world.x * next, y: center.y - world.y * next, zoom: next)
    }
    public func fitNavigationView() {
        guard !viewportLocked, !isPointerGestureActive, !inlineTextEditing, !showTextEditor else { return }
        let bounds: CGRect
        if board.canvasMode != .infinite {
            bounds = CGRect(x: 0, y: 0, width: board.canvasWidth ?? 595, height: board.canvasHeight ?? 842)
        } else {
            let visible = currentPageObjects.filter { $0.isVisible != false }
            guard !visible.isEmpty else {
                resetNavigationView()
                return
            }
            bounds = visible.map(Self.navigationBounds).reduce(CGRect.null) { $0.union($1) }
        }
        let zoom = max(
            0.08,
            min(
                8,
                min(
                    max(1, canvasSize.width - 100) / bounds.width,
                    max(1, canvasSize.height - 140) / bounds.height)))
        viewport = ViewportTransform(
            x: canvasSize.width / 2 - bounds.midX * zoom, y: canvasSize.height / 2 - bounds.midY * zoom,
            zoom: zoom)
    }
    public func resetNavigationView() {
        guard !viewportLocked, !isPointerGestureActive, !inlineTextEditing, !showTextEditor else { return }
        viewport = ViewportTransform(
            x: canvasSize.width / 2 - (board.canvasMode == .infinite ? 0 : (board.canvasWidth ?? 595) / 2),
            y: board.canvasMode == .infinite ? canvasSize.height / 2 : 96, zoom: 1)
    }
    private static func navigationBounds(_ object: BoardObject) -> CGRect {
        let base =
            VectorMath.selectionBounds(for: [object])
            ?? CGRect(x: object.x, y: object.y, width: max(1, object.width), height: max(1, object.height))
        let polygonHasWorldPoints =
            ["triangle", "quadrilateral"].contains(object.type) && object.points != nil
        let rotates =
            object.rotation != 0
            && !["stroke", "highlighter", "paint", "curve", "line", "arrow"].contains(object.type)
            && !polygonHasWorldPoints
        var rect = base
        if rotates {
            let cx = object.x + object.width / 2
            let cy = object.y + object.height / 2
            let angle = object.rotation * .pi / 180
            let c = cos(angle)
            let s = sin(angle)
            let corners = [
                CGPoint(x: base.minX, y: base.minY), CGPoint(x: base.maxX, y: base.minY),
                CGPoint(x: base.maxX, y: base.maxY), CGPoint(x: base.minX, y: base.maxY),
            ].map { p in
                CGPoint(x: cx + (p.x - cx) * c - (p.y - cy) * s, y: cy + (p.x - cx) * s + (p.y - cy) * c)
            }
            let minX = corners.map(\.x).min()!
            let minY = corners.map(\.y).min()!
            rect = CGRect(
                x: minX, y: minY, width: corners.map(\.x).max()! - minX,
                height: corners.map(\.y).max()! - minY)
        }
        let padding = max(0, object.strokeWidth / 2)
        return rect.insetBy(dx: -padding, dy: -padding)
    }
}
