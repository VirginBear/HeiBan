import CoreGraphics
import Foundation

/// 筆畫／橡皮擦的開始、取樣與提交。暫態預覽不寫文件，放開後形成一筆可復原交易。
extension BoardEngine {
    public func startStroke(at screenPt: Point) {
        // 落筆時鎖定尺的同一側邊；超出尺長仍投影在該直線，不能中途跳到另一側。
        rulerStrokeEdge = nil
        if ruler.enabled {
            let snap = VectorMath.snapToRulerEdge(
                screenPt: screenPt, ruler: ruler, stopSnappingBeyondEnds: false)
            if snap.snapped {
                let angle = ruler.angle * .pi / 180
                let dx = screenPt.x - ruler.screenCenterX
                let dy = screenPt.y - ruler.screenCenterY
                let localY = -dx * sin(angle) + dy * cos(angle)
                rulerStrokeEdge = localY < 0 ? -ruler.height / 2 : ruler.height / 2
            }
        }
        let snappedScreen: Point
        if let edge = rulerStrokeEdge {
            snappedScreen = pointProjectedToRulerEdge(screenPt, edge: edge)
        } else {
            snappedScreen =
                ruler.enabled
                ? VectorMath.snapToRulerEdge(screenPt: screenPt, ruler: ruler).screenPt : screenPt
        }
        let worldPt = VectorMath.screenToWorld(rulerStrokeEdge == nil ? snapDrawingScreenPoint(snappedScreen) : snappedScreen, viewport: viewport)
        holdStartScreenPoint = screenPt
        strokePreview.begin(with: worldPt)
    }

    public func appendStrokePoint(at screenPt: Point) {
        guard !strokePreview.points.isEmpty else { return }
        let snappedScreen: Point
        if ruler.enabled, let edge = rulerStrokeEdge {
            snappedScreen = pointProjectedToRulerEdge(screenPt, edge: edge)
        } else {
            snappedScreen =
                ruler.enabled
                ? VectorMath.snapToRulerEdge(screenPt: screenPt, ruler: ruler, stopSnappingBeyondEnds: false)
                    .screenPt : screenPt
        }
        let worldPt = VectorMath.screenToWorld(rulerStrokeEdge == nil ? snapDrawingScreenPoint(snappedScreen) : snappedScreen, viewport: viewport)
        if let last = strokePreview.points.last,
            hypot(worldPt.x - last.x, worldPt.y - last.y) * viewport.zoom < 0.25
        {
            return
        }

        // If user moves beyond hold threshold (12 pt screen space), cancel snapped shape and update hold anchor
        if let hold = holdStartScreenPoint {
            let dist = hypot(screenPt.x - hold.x, screenPt.y - hold.y)
            if dist > 12.0 {
                holdStartScreenPoint = screenPt
                if strokePreview.snappedShape != nil {
                    strokePreview.snappedShape = nil
                }
            }
        } else {
            holdStartScreenPoint = screenPt
        }

        strokePreview.append(worldPt)
    }

    private func pointProjectedToRulerEdge(_ point: Point, edge: Double) -> Point {
        let angle = ruler.angle * .pi / 180
        let dx = point.x - ruler.screenCenterX
        let dy = point.y - ruler.screenCenterY
        let localX = dx * cos(angle) + dy * sin(angle)
        let localClampedX = max(-ruler.width / 2, min(ruler.width / 2, localX))
        return Point(
            x: ruler.screenCenterX + localClampedX * cos(angle) - edge * sin(angle),
            y: ruler.screenCenterY + localClampedX * sin(angle) + edge * cos(angle),
            pressure: point.pressure
        )
    }

    /// Triggered when user holds still at the end of a stroke for 1.0±0.2s (A09)
    public func checkGoodnotesShapeSnap() {
        guard strokePreview.points.count >= 5 else { return }
        if let shape = ShapeRecognizer.recognize(points: strokePreview.points) {
            // Match Windows' screen-space straightness check; an open arc must not become a line.
            if shape.type == "line" && !StraightStrokeRecognizer.isEligible(strokePreview.points,zoom:viewport.zoom) { return }
            strokePreview.snappedShape = shape
        }
    }

    /// Commit stroke to permanent objects
    public func endStroke() {
        guard !strokePreview.points.isEmpty else { return }
        rulerStrokeEdge = nil
        defer {
            holdStartScreenPoint = nil
            strokePreview.reset()
        }

        // If user triggered shape snap (A09: 保留色彩、粗細、透明度與虛線，一次復原)
        if let shape = strokePreview.snappedShape {
            let newObj: BoardObject
            switch shape.type {
            case "line":
                newObj = BoardObject(
                    boardId: board.id,
                    type: "line",
                    x: shape.x,
                    y: shape.y,
                    width: shape.width,
                    height: shape.height,
                    x1: shape.x1 ?? shape.x,
                    y1: shape.y1 ?? shape.y,
                    x2: shape.x2 ?? (shape.x + shape.width),
                    y2: shape.y2 ?? (shape.y + shape.height),
                    strokeColor: activeColor,
                    strokeWidth: activeBrushWidth,
                    lineStyle: activeLineStyle,
                    opacity: currentTool == .highlighter ? activeHighlighterOpacity : activeOpacity,
                    zIndex: objects.count + 1
                )
            case "circle", "ellipse":
                newObj = BoardObject(
                    boardId: board.id,
                    type: shape.type,
                    x: shape.x,
                    y: shape.y,
                    width: shape.width,
                    height: shape.height,
                    strokeColor: activeColor,
                    fillColor: "none",
                    strokeWidth: activeBrushWidth,
                    lineStyle: activeLineStyle,
                    opacity: currentTool == .highlighter ? activeHighlighterOpacity : activeOpacity,
                    zIndex: objects.count + 1
                )
            default:  // rect
                newObj = BoardObject(
                    boardId: board.id,
                    type: "rect",
                    x: shape.x,
                    y: shape.y,
                    width: shape.width,
                    height: shape.height,
                    strokeColor: activeColor,
                    fillColor: "none",
                    strokeWidth: activeBrushWidth,
                    lineStyle: activeLineStyle,
                    opacity: currentTool == .highlighter ? activeHighlighterOpacity : activeOpacity,
                    zIndex: objects.count + 1
                )
            }
            appendInZOrder(newObj)
            transactionManager.push(.insertObjects([newObj]))
            scheduleAutosave()
            return
        }

        // Normal freehand stroke
        guard !strokePreview.points.isEmpty else { return }
        let sourcePoints = strokePreview.points
        let savedPoints: [Point]
        if currentTool == .curve, sourcePoints.count >= 3 {
            let start = sourcePoints[0]
            let end = sourcePoints[sourcePoints.count - 1]
            let chordLength = max(0.001, hypot(end.x - start.x, end.y - start.y))
            let candidate =
                sourcePoints.dropFirst().dropLast().max { lhs, rhs in
                    abs((end.x - start.x) * (start.y - lhs.y) - (start.x - lhs.x) * (end.y - start.y))
                        < abs((end.x - start.x) * (start.y - rhs.y) - (start.x - rhs.x) * (end.y - start.y))
                } ?? sourcePoints[sourcePoints.count / 2]
            let chordOffset =
                ((end.x - start.x) * (start.y - candidate.y) - (start.x - candidate.x) * (end.y - start.y))
                / chordLength
            let control = Point(
                x: 2 * candidate.x - (start.x + end.x) / 2, y: 2 * candidate.y - (start.y + end.y) / 2)
            savedPoints = abs(chordOffset) < 0.5 ? [start, candidate, end] : [start, control, end]
        } else {
            savedPoints = sourcePoints
        }
        guard let pointsData = try? JSONEncoder().encode(savedPoints),
            let pointsStr = String(data: pointsData, encoding: .utf8)
        else {
            return
        }

        let strokeType =
            currentTool == .curve
            ? "curve"
            : (currentTool == .highlighter ? "highlighter" : (currentTool == .paint ? "paint" : "stroke"))
        let opacity = (currentTool == .highlighter) ? activeHighlighterOpacity : activeOpacity
        let strokeWidth = activeBrushWidth

        let box = VectorMath.computeBoundingBox(points: savedPoints, strokeWidth: strokeWidth)
        let newObj = BoardObject(
            boardId: board.id,
            type: strokeType,
            x: box.minX,
            y: box.minY,
            width: box.width,
            height: box.height,
            points: pointsStr,
            strokeColor: activeColor,
            strokeWidth: strokeWidth,
            lineStyle: activeLineStyle,
            opacity: opacity,
            zIndex: objects.count + 1,
            brushKind: activeBrushKind.rawValue,
            textureSeed: Int.random(in: 1...10000)
        )
        appendInZOrder(newObj)
        transactionManager.push(.insertObjects([newObj]))
        scheduleAutosave()
    }

    public var activeBrushWidth: Double {
        CanvasToolMetrics.brushDiameter(
            tool: currentTool, baseWidth: activeStrokeWidth, zoom: 1.0, kind: activeBrushKind)
    }

    public var toolCursorDiameter: Double? {
        if readingMode || isHoldingSpace { return nil }
        if currentTool == .eraser { return eraserSize }
        if [.pen, .curve, .highlighter, .paint].contains(currentTool) {
            return CanvasToolMetrics.brushDiameter(
                tool: currentTool, baseWidth: activeStrokeWidth, zoom: viewport.zoom, kind: activeBrushKind)
        }
        return nil
    }

    public func updateEraserCursor(at point: Point?) {
        if eraserCursorPoint != point { eraserCursorPoint = point }
    }
    public func updateHoverCursor(at point: Point?, diameter: Double?) {
        if hoverCursorPoint != point { hoverCursorPoint = point }
        if hoverCursorDiameter != diameter { hoverCursorDiameter = diameter }
    }

    public var hoverPosition: Point? {
        get { hoverCursorPoint }
        set { hoverCursorPoint = newValue }
    }

    public var hoverRadius: Double {
        get { (hoverCursorDiameter ?? 0) / 2.0 }
        set { hoverCursorDiameter = newValue * 2.0 }
    }

    public func captureCanvasStateSnapshot() -> CanvasStateSnapshot {
        let selBounds: Rect? = selectionBoundingBox.map { box in
            Rect(minX: box.minX, minY: box.minY, maxX: box.maxX, maxY: box.maxY)
        }
        return CanvasStateSnapshot(
            selectedObjectIds: selectedIds,
            selectionBounds: selBounds,
            selectionRotation: 0.0,
            activeTransformHandle: activeTransformHandle,
            hoverPreview: HoverPreviewSnapshot(
                position: hoverPosition,
                radius: hoverRadius,
                cursorShape: currentCursorType(),
                tool: currentTool
            ),
            rulerState: ruler,
            isEraserActive: isEraserSwipeActive || pointerGesture == .erasing || isBoardEraserActive,
            currentTool: currentTool,
            isNotebook: isNotebook,
            activePageId: activePageId
        )
    }

    // MARK: - Eraser transaction
    public func beginEraserSwipe() {
        finishBoardEraser()
        resetCircularEraserState()
        circularEraser.original = objects
        circularEraser.previewObjects = objects
        circularEraser.boardID = board.id
        circularEraser.pageID = activePageId
        circularEraser.revision = drawingGeometryRevision
        isEraserSwipeActive = true
    }

    private var circularEraserSessionIsCurrent: Bool {
        circularEraser.boardID == board.id && circularEraser.pageID == activePageId
            && circularEraser.revision == drawingGeometryRevision
    }

    public func eraseAt(screenPt: Point) {
        guard screenPt.x.isFinite, screenPt.y.isFinite else { return }
        let implicitGesture = !isEraserSwipeActive
        if implicitGesture { beginEraserSwipe() }
        guard circularEraserSessionIsCurrent else { cancelEraserSwipe(); return }
        let radius = CanvasToolMetrics.eraserWorldRadius(screenDiameter: eraserSize, zoom: viewport.zoom)
        let start = circularEraser.lastScreenPoint ?? screenPt
        let steps = max(1, Int(ceil(hypot(screenPt.x-start.x, screenPt.y-start.y)/5)))
        var draft = circularEraser.previewObjects ?? objects
        for step in 1...steps {
            let t = Double(step)/Double(steps)
            let world = VectorMath.screenToWorld(
                Point(x: start.x+(screenPt.x-start.x)*t, y: start.y+(screenPt.y-start.y)*t), viewport: viewport)
            draft = draft.flatMap { item -> [BoardObject] in
                guard isObjectOnCurrentPage(item), item.isLocked != true, item.isVisible != false,
                      Self.isEraserEligible(item.type) else { return [item] }
                if eraserMode == .object {
                    return VectorMath.isPointNearObject(point: world, object: item, threshold: radius) ? [] : [item]
                }
                guard ["stroke", "highlighter", "paint", "curve"].contains(item.type) else { return [item] }
                // 未旋轉的筆跡才可直接用儲存的bounds做保守排除。
                if item.rotation == 0 && item.type != "curve" {
                    let margin = radius + max(2, item.strokeWidth)
                    if world.x < item.x-margin || world.x > item.x+item.width+margin
                        || world.y < item.y-margin || world.y > item.y+item.height+margin { return [item] }
                }
                return EraserToolEngine.sliceStroke(object: item, eraserCenter: world, eraserRadius: radius)
            }
        }
        if draft != circularEraser.previewObjects { circularEraser.previewObjects = draft }
        circularEraser.lastScreenPoint = screenPt
        if implicitGesture { endEraserSwipe() }
    }

    public static func isEraserEligible(_ type: String) -> Bool {
        ["stroke", "pen", "highlighter", "paint", "curve", "rect", "circle", "ellipse", "triangle",
         "quadrilateral", "diamond", "star", "line", "arrow", "arc", "rounded_rect", "polygon",
         "connector", "pentagon"].contains(type)
    }

    public func endEraserSwipe() {
        guard let before = circularEraser.original else { return }
        let after = circularEraserSessionIsCurrent ? circularEraser.previewObjects : nil
        cancelEraserSwipe()
        guard let after, before != after else { return }
        objects = after
        selectedIds.formIntersection(Set(after.map(\.id)))
        transactionManager.push(.replaceObjects(before: before, after: after))
        scheduleAutosave()
    }

    public func cancelEraserSwipe() {
        resetCircularEraserState()
        clearCircularEraserPointerGesture()
    }

    private func resetCircularEraserState() {
        circularEraser.previewObjects = nil
        circularEraser.original = nil
        circularEraser.boardID = nil
        circularEraser.pageID = nil
        circularEraser.revision = nil
        circularEraser.lastScreenPoint = nil
        if isEraserSwipeActive { isEraserSwipeActive = false }
    }
}
