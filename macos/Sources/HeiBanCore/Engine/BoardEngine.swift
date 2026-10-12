import CoreGraphics
import Foundation
import SwiftUI

/// 普通作品與螢幕註記共用的編輯狀態。
/// 主檔保留狀態及指標路由；文件、文字、圖層等命令依責任放在 BoardEngine+*.swift。
/// UI／指標命令在主執行緒呼叫；背景保存只能讀取已擷取的值型別快照。
public class BoardEngine: ObservableObject {
    public enum PointerGesture: Equatable {
        case idle
        case pan
        case moveSelection
        case marqueeSelection
        case transformSelection(TransformHandle)
        case lineEndpoint(String, LineEndpoint)
        case stroke
        case shape
        case polygon(String)
        case erasing
        case textEntry
    }

    @Published public var showingHome = true
    @Published public var libraryBoards: [BoardMetadata] = []
    @Published public var trashedLibraryBoards: [BoardMetadata] = []
    @Published public var readingMode = false
    @Published public var viewportLocked = false
    @Published public var toolbarDock = UserDefaults.standard.string(forKey: "HeiBan.toolbarDock") ?? "bottom"
    @Published public var toolbarPreferences: ToolbarPreferences = {
        if let data = UserDefaults.standard.data(forKey: "HeiBan.toolbarPreferences"),
            var decoded = try? JSONDecoder().decode(ToolbarPreferences.self, from: data)
        {
            decoded.normalize()
            return decoded
        }
        return ToolbarPreferences.createDefault()
    }()
    @Published public var board: BoardMetadata
    @Published public var objects: [BoardObject] = []
    @Published public var selectedIds: Set<String> = []
    @Published public var marqueeRect: CGRect? = nil
    @Published public var activeTransformHandle: TransformHandle? = nil
    @Published public var activeTransformDegrees: Double? = nil
    @Published public var hoveredTransformHandle: TransformHandle? = nil
    @Published public var isShiftHeld: Bool = false

    public var isToolbarVertical: Bool {
        toolbarDock == "left" || toolbarDock == "right"
            || (toolbarDock == "floating" && toolbarFloatingVertical)
    }

    public var selectedEndpointLine: BoardObject? {
        let selected = selectedObjects
        guard selected.count == 1, let object = selected.first,
              ["line", "arrow"].contains(object.type) else { return nil }
        return object
    }

    public var selectionUsesEndpoints: Bool { selectedEndpointLine != nil }

    public var selectionBoundingBox: CGRect? {
        VectorMath.selectionBounds(
            for: currentPageObjects.filter { selectedIds.contains($0.id) && $0.isVisible != false })
    }

    public func updateHoveredHandle(at screenPoint: Point?) {
        guard currentTool == .select, !selectionUsesEndpoints, let screenPoint, let selBounds = selectionBoundingBox else {
            if hoveredTransformHandle != nil { hoveredTransformHandle = nil }
            return
        }
        let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        let handle = VectorMath.hitTestHandle(point: worldPoint, bounds: selBounds, zoom: viewport.zoom)
        if hoveredTransformHandle != handle { hoveredTransformHandle = handle }
    }

    public func currentCursorType(at screenPoint: Point? = nil) -> TransformCursorType? {
        if let active = activeTransformHandle {
            return active.cursorType
        }
        if let screenPoint {
            guard currentTool == .select, !selectionUsesEndpoints, let selBounds = selectionBoundingBox else { return nil }
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            return VectorMath.hitTestHandle(point: worldPoint, bounds: selBounds, zoom: viewport.zoom)?
                .cursorType
        }
        return hoveredTransformHandle?.cursorType
    }

    private var initialTransformBounds: CGRect?
    private var initialTransformObjects: [BoardObject] = []
    private var initialRotationCenter: CGPoint?
    private var initialRotationAngle: Double = 0.0
    public var internalClipboard: [BoardObject] = []

    @Published public var currentTool: ToolType = .select
    @Published public var eraserMode: EraserMode = .object
    @Published public var eraserSize: Double = 24.0
    @Published public var eraserCursorPoint: Point?
    @Published public var hoverCursorPoint: Point?
    @Published public var hoverCursorDiameter: Double?
    @Published public var polygonDraftPoints: [Point] = []
    @Published public var polygonDraftCursorPoint: Point?
    public let rulerStore = RulerStateStore()
    public var ruler: RulerState {
        get { rulerStore.state }
        set {
            // Visibility changes affect the toolbar and canvas; pointer samples only affect the ruler.
            if newValue.enabled != rulerStore.state.enabled { objectWillChange.send() }
            rulerStore.update(newValue)
        }
    }
    @Published public var viewport: ViewportTransform = ViewportTransform(x: 200, y: 150, zoom: 1.0)
    @Published public var canvasSize = CGSize(width: 1200, height: 800)

    @Published public var penPreset = ToolStylePreset(color: "#86efac", strokeWidth: 3.5, opacity: 1.0)
    @Published public var highlighterPreset = ToolStylePreset(
        color: "#fef08a", strokeWidth: 18.0, opacity: 0.45)
    @Published public var paintPreset = ToolStylePreset(color: "#93c5fd", strokeWidth: 32.0, opacity: 0.8)
    @Published public var recentColors: [String] = ["#86efac", "#fef08a", "#93c5fd", "#ffffff", "#f472b6"]

    @Published public var activeColor: String = "#86efac"  // Chalk green
    @Published public var activeStrokeWidth: Double = 3.5
    @Published public var activeLineStyle: String = "solid"  // "solid" | "dashed"
    @Published public var activeLineExtension: LineExtension = .none
    @Published public var activeOpacity: Double = 1.0
    @Published public var activeHighlighterOpacity: Double = 0.45
    @Published public var toolbarOffset = CGSize.zero

    @Published public var showPinManager: Bool = false
    @Published public var showInspector: Bool = false
    @Published public var showEraserPopover: Bool = false
    @Published public var showExportMenu: Bool = false
    @Published public var showShapesPopover: Bool = false
    @Published public var showColorPopover: Bool = false
    @Published public var showPinPopover: Bool = false
    @Published public var showNoteInfoPopover: Bool = false
    @Published public var showInsertMenu: Bool = false
    @Published public var isImmersiveMode: Bool = false

    public let calculator = CalculatorModel()
    public let timerCoordinator = TimerCoordinator()
    public let compassEngine = CompassToolEngine()
    public let laserEngine = LaserPointerEngine()

    @Published public var activeBrushKind: BrushKind = .pen
    @Published public var lassoMode: LassoMode = .freeform
    @Published public var lassoFilter: LassoFilter = .all
    @Published public var selectAfterShapeCreation: Bool = true
    @Published public var shapeRecognitionEnabled: Bool = true
    @Published public var autoFillShapes: Bool = false
    @Published public var showWorldRuler: Bool = false
    @Published public var activeAlignmentGuides: [AlignmentGuideLine] = []
    @Published public var inFlightLassoPoints: [Point] = []

    // Batch 3: Structured Notes & Presentation (AGM-11 - AGM-14)
    @Published public var isPresentationModeActive: Bool = false
    @Published public var currentPresentationIndex: Int = 0
    @Published public var presentationFrames: [BoardObject] = []

    public func toggleCalculator() {
        if calculator.isVisible {
            calculator.isVisible = false
        } else {
            calculator.isCollapsed = false
            calculator.panelOffset = CGSize(width: 80, height: 80)
            calculator.isVisible = true
        }
    }

    public func toggleTimer() {
        if timerCoordinator.isVisible {
            timerCoordinator.isVisible = false
        } else {
            timerCoordinator.isCollapsed = false
            timerCoordinator.panelOffset = CGSize(width: 80, height: 160)
            timerCoordinator.isVisible = true
        }
    }

    public func toggleLayerPanel() {
        showLayerPanel.toggle()
    }

    public func togglePinManager() {
        showPinManager.toggle()
    }

    public func toggleViewportLock() {
        setViewportLocked(!viewportLocked)
    }

    public var hasUnsavedDraftOrChanges: Bool {
        if inlineTextEditing && !textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    public var saveFeedbackState: BoardSaveFeedbackState {
        if autosaveStatus.contains("失敗") || autosaveStatus.contains("無法") {
            return .failed(detail: autosaveStatus)
        }
        if autosaveStatus == "儲存中…" || autosaveStatus == "儲存中" {
            return .saving
        }
        if hasUnsavedDraftOrChanges {
            return .unsaved
        }
        return BoardSaveFeedbackState.resolve(status: autosaveStatus)
    }

    public func toggleLaser() {
        if laserEngine.isEnabled {
            laserEngine.cleanupOnDeactivate()
            if currentTool == .laser { selectTool(.select) }
        } else {
            selectTool(.laser)
            laserEngine.isEnabled = true
            showTemporaryStatus("已啟用雷射筆指示")
        }
    }

    public func toggleWorldRuler() {
        showWorldRuler.toggle()
    }

    public func toggleTapeRevealed(id: String) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let before = objects[index]
        var obj = before
        let current = obj.isRevealed ?? false
        obj.isRevealed = !current
        obj.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = obj
        transactionManager.push(.modifyObjects(before: [before], after: [obj]))
        scheduleAutosave()
    }

    public func revealAllTapes() {
        var updated = false
        for i in 0..<objects.count {
            if objects[i].type == "tape" && (objects[i].isRevealed != true) {
                objects[i].isRevealed = true
                objects[i].updatedAt = ISO8601DateFormatter().string(from: Date())
                updated = true
            }
        }
        if updated {
            scheduleAutosave()
        }
    }

    public func hideAllTapes() {
        var updated = false
        for i in 0..<objects.count {
            if objects[i].type == "tape" && (objects[i].isRevealed == true) {
                objects[i].isRevealed = false
                objects[i].updatedAt = ISO8601DateFormatter().string(from: Date())
                updated = true
            }
        }
        if updated {
            scheduleAutosave()
        }
    }

    public func updateConnectedLines() {
        let objectMap = Dictionary(uniqueKeysWithValues: objects.map { ($0.id, $0) })
        var changed = false
        for i in 0..<objects.count {
            if objects[i].type == "connector" {
                var conn = objects[i]
                if let startId = conn.startObjectId, let startObj = objectMap[startId] {
                    let newX1 = startObj.x + startObj.width / 2.0
                    let newY1 = startObj.y + startObj.height / 2.0
                    if conn.x1 != newX1 || conn.y1 != newY1 {
                        conn.x1 = newX1
                        conn.y1 = newY1
                        changed = true
                    }
                }
                if let endId = conn.endObjectId, let endObj = objectMap[endId] {
                    let newX2 = endObj.x + endObj.width / 2.0
                    let newY2 = endObj.y + endObj.height / 2.0
                    if conn.x2 != newX2 || conn.y2 != newY2 {
                        conn.x2 = newX2
                        conn.y2 = newY2
                        changed = true
                    }
                }
                if changed {
                    conn.x = min(conn.x1 ?? conn.x, conn.x2 ?? conn.x)
                    conn.y = min(conn.y1 ?? conn.y, conn.y2 ?? conn.y)
                    conn.width = abs((conn.x2 ?? conn.x) - (conn.x1 ?? conn.x))
                    conn.height = abs((conn.y2 ?? conn.y) - (conn.y1 ?? conn.y))
                    objects[i] = conn
                }
            }
        }
    }

    public func detachDeletedObjectsFromConnectors(deletedIds: Set<String>) {
        for i in 0..<objects.count {
            if objects[i].type == "connector" {
                var conn = objects[i]
                var changed = false
                if let startId = conn.startObjectId, deletedIds.contains(startId) {
                    conn.startObjectId = nil
                    changed = true
                }
                if let endId = conn.endObjectId, deletedIds.contains(endId) {
                    conn.endObjectId = nil
                    changed = true
                }
                if changed {
                    objects[i] = conn
                }
            }
        }
    }

    public func toggleCompass() {
        compassEngine.isEnabled.toggle()
        if compassEngine.isEnabled {
            compassEngine.prepare()
            compassEngine.strokeColor = activeColor
            compassEngine.strokeWidth = activeStrokeWidth
            compassEngine.lineStyle = activeLineStyle
            // Place compass center at viewport world center
            let centerScreen = Point(x: Double(canvasSize.width / 2.0), y: Double(canvasSize.height / 2.0))
            compassEngine.center = VectorMath.screenToWorld(centerScreen, viewport: viewport)
            showTemporaryStatus("先調整圓規位置與起點，點圓心鎖定後再拖筆尖畫弧")
        }
    }

    public func toggleImmersiveMode() {
        isImmersiveMode.toggle()
        showTemporaryStatus(isImmersiveMode ? "已進入沉浸模式（按 Esc 或移至頂部恢復）" : "已退出沉浸模式")
    }

    public var selectionQuickBarState: SelectionQuickActionBarState {
        selectionQuickBarState(for: CGSize(width: 220, height: 36))
    }

    public func selectionQuickBarState(for barSize: CGSize) -> SelectionQuickActionBarState {
        SelectionQuickActionCoordinator.computeState(
            selectedObjects: selectedObjects,
            bounds: selectionBoundingBox.map {
                Rect(
                    minX: Double($0.minX), minY: Double($0.minY), maxX: Double($0.maxX), maxY: Double($0.maxY)
                )
            },
            viewport: viewport,
            canvasSize: canvasSize,
            barSize: barSize
        )
    }

    public func saveToolbarPreferences() {
        if let encoded = try? JSONEncoder().encode(toolbarPreferences) {
            UserDefaults.standard.set(encoded, forKey: "HeiBan.toolbarPreferences")
            NotificationCenter.default.post(name: Notification.Name("HeiBan.toolbarPreferencesChanged"), object: self)
        }
    }

    public func resetToolbarPreferences() {
        toolbarPreferences.resetToDefaults()
        saveToolbarPreferences()
    }

    public func setToolbarItemHidden(id: String, hidden: Bool) {
        toolbarPreferences.setItemHidden(id: id, hidden: hidden)
        saveToolbarPreferences()
    }

    public func moveToolbarItem(id: String, to index: Int) {
        toolbarPreferences.moveItem(id: id, to: index)
        saveToolbarPreferences()
    }

    public func closeAllTransientPanels() {
        showColorPopover = false
        showEraserPopover = false
        showShapesPopover = false
    }

    public func openBrushSettings() {
        showEraserPopover = false
        showShapesPopover = false
        showColorPopover = true
    }

    public func openEraserSettings() {
        showColorPopover = false
        showShapesPopover = false
        showEraserPopover = true
    }

    public func openShapesSettings() {
        showColorPopover = false
        showEraserPopover = false
        showShapesPopover = true
    }
    @Published public var showLayerPanel: Bool = false
    @Published public var editingLayerId: String? = nil
    @Published public var editingLayerName: String = ""
    @Published public var newPinName: String = ""
    @Published public var isHoldingSpace: Bool = false
    @Published public var statusMessage: String? = nil
    @Published public var showTextEditor = false
    @Published public var showInlineTextEditor = false
    @Published public var editingTextObjectId: String? = nil
    public var inlineTextEditing: Bool { showInlineTextEditor || editingTextObjectId != nil }
    @Published public var editingRichTextSpans: [TextSpan] = []
    @Published public var editingFontFamily = "PingFang TC"
    @Published public var editingFontSize = 24.0
    @Published public var editingTextAlign = "left"
    @Published public var editingTextColor = "#86efac"
    @Published public var editingTextOpacity = 1.0
    @Published public var inlineTextFormatAction: String?
    @Published public var inlineTextFormatRevision = 0
    @Published public var inlineTextPoint = Point(x: 0, y: 0)
    @Published public var textDraft = ""
    @Published public var textEntryKind: ToolType = .text
    @Published public var autosaveStatus = "尚未儲存"
    @Published public var damagedBoards: [DamagedBoardFileInfo] = []

    // Keep high-frequency pointer updates out of the board-level publisher so
    // toolbars, menus, and the committed object layer do not refresh per point.
    public let strokePreview = StrokePreviewStore()
    public var holdTimer: Timer? = nil

    // 同一個手勢共用這些暫態狀態；internal 供 HeiBanCore 延伸檔使用，不對 Mac UI 公開。
    // Transaction Manager for Undo / Redo & Layers (A04 & A24)
    public let transactionManager = TransactionManager(maxCapacity: 50)
    var activeEraserDeletedObjects: [BoardObject] = []
    var activeEraserInsertedObjects: [BoardObject] = []
    var isEraserSwipeActive: Bool = false
    private var previousPanTranslation = CGSize.zero
    private var previousRulerTranslation = CGSize.zero
    private var rulerDragStart: Point?
    private var rulerCenterAtDragStart = CGPoint.zero
    var pinDragBefore: BoardPin?
    private var polygonDragBefore: [String: BoardObject] = [:]
    private var previousToolbarTranslation = CGSize.zero
    public var toolbarLayoutSize: CGSize?
    private var toolbarFloatingVertical = UserDefaults.standard.bool(forKey: "HeiBan.toolbarFloatingVertical")
    public private(set) var pointerGesture: PointerGesture = .idle
    private var pointerGestureStart: Point?
    var textEntryPoint = Point(x: 0, y: 0)
    var originalTextObject: BoardObject?
    private var previousMagnificationScale = 1.0
    /// 只管理保存排程與版本封套；畫布物件仍由此引擎擁有。
    let persistence: BoardPersistenceState

    public init(restoreSession: Bool = true, persistenceEnabled: Bool = true) {
        self.persistence = BoardPersistenceState(enabled: persistenceEnabled)
        self.board = BoardMetadata(
            id: "board_\(UUID().uuidString.prefix(8))",
            title: "未命名黑板",
            backgroundColor: "#172e25",
            gridStyle: .grid,
            boardTheme: .blackboard,
            pins: []
        )
        if restoreSession {
            restoreAutosave()
            if let url = Self.autosaveURL, FileManager.default.fileExists(atPath: url.path),
                (try? Self.library.load(id: board.id)) == nil
            {
                try? Self.library.save(HeiBanDocument(board: board, objects: objects))
            }
            if let latest = try? Self.library.load(id: board.id) {
                persistence.header = BoardPersistenceState.DocumentHeader(latest)
                board = latest.board
                objects = latest.objects.sorted { $0.zIndex < $1.zIndex }
            }
            refreshLibrary()
            let savedOffset = UserDefaults.standard.array(forKey: "HeiBan.toolbarOffset") as? [Double]
            if let savedOffset, savedOffset.count == 2 {
                toolbarOffset = CGSize(width: savedOffset[0], height: savedOffset[1])
            }
        }
    }

    public static let library = LocalBoardLibrary()

    // MARK: - Undo / Redo & History (A04)
    public var canUndo: Bool { transactionManager.canUndo }
    public var canRedo: Bool { transactionManager.canRedo }

    public func clearHistory() {
        transactionManager.clear()
    }

    public func updatePanGesture(translation: CGSize) {
        guard !viewportLocked else { return }
        let delta = CGSize(
            width: translation.width - previousPanTranslation.width,
            height: translation.height - previousPanTranslation.height
        )
        viewport.x += delta.width
        viewport.y += delta.height
        previousPanTranslation = translation
    }

    public func endPanGesture() {
        previousPanTranslation = .zero
    }

    public func panViewport(delta: CGSize) {
        guard !viewportLocked else { return }
        viewport.x += delta.width
        viewport.y += delta.height
    }

    public func updateRulerDrag(translation: CGSize) {
        var next = ruler
        next.screenCenterX += translation.width - previousRulerTranslation.width
        next.screenCenterY += translation.height - previousRulerTranslation.height
        ruler = next
        previousRulerTranslation = translation
    }

    public func updateRulerDrag(start: Point, current: Point) {
        if rulerDragStart != start {
            rulerDragStart = start
            rulerCenterAtDragStart = CGPoint(x: ruler.screenCenterX, y: ruler.screenCenterY)
        }
        var next = ruler
        next.screenCenterX = Double(rulerCenterAtDragStart.x) + current.x - start.x
        next.screenCenterY = Double(rulerCenterAtDragStart.y) + current.y - start.y
        ruler = next
    }

    public func endRulerDrag() {
        previousRulerTranslation = .zero
        rulerDragStart = nil
    }

    public func updateToolbarDrag(translation: CGSize) {
        toolbarOffset = CGSize(
            width: toolbarOffset.width + translation.width - previousToolbarTranslation.width,
            height: toolbarOffset.height + translation.height - previousToolbarTranslation.height)
        previousToolbarTranslation = translation
    }

    public func endToolbarDrag() {
        previousToolbarTranslation = .zero
        let anchorX =
            toolbarDock == "left"
            ? 46.0 : toolbarDock == "right" ? canvasSize.width - 46 : canvasSize.width / 2
        let anchorY =
            toolbarDock == "top"
            ? 106.0 : toolbarDock == "bottom" ? canvasSize.height - 48 : canvasSize.height / 2
        let x = anchorX + toolbarOffset.width
        let y = anchorY + toolbarOffset.height
        let distances: [(String, Double)] = [
            ("left", abs(x)),
            ("right", abs(canvasSize.width - x)),
            ("top", abs(y - 64)),
            ("bottom", abs(canvasSize.height - y)),
        ]
        if let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 < 110 {
            toolbarDock = nearest.0
            toolbarOffset = .zero
        } else {
            toolbarDock = "floating"
        }
        persistToolbarPlacement()
    }

    public func setToolbarDock(_ edge: String) {
        guard ["left", "right", "top", "bottom"].contains(edge) else { return }
        toolbarFloatingVertical = edge == "left" || edge == "right"
        toolbarDock = edge
        toolbarOffset = .zero
        persistToolbarPlacement()
    }

    /// Use the handle's drop point, so a long toolbar can still dock on either side.
    public func toolbarDropTarget(at point: CGPoint, in windowSize: CGSize) -> String? {
        let distances: [(String, CGFloat)] = [
            ("left", abs(point.x)), ("right", abs(windowSize.width - point.x)),
            ("top", abs(point.y - 56)), ("bottom", abs(windowSize.height - point.y)),
        ]
        guard let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 < 88 else { return nil }
        return nearest.0
    }

    public func placeToolbar(center: CGPoint, dropPoint: CGPoint, windowSize: CGSize, panelSize: CGSize) {
        if let edge = toolbarDropTarget(at: dropPoint, in: windowSize) {
            setToolbarDock(edge)
        } else {
            // Keep the current orientation when undocking, avoiding a jump at release.
            toolbarFloatingVertical = isToolbarVertical
            let clamped = clampPanelCenter(center, panelSize: panelSize, windowSize: windowSize, margin: 8)
            toolbarOffset = CGSize(
                width: clamped.x - windowSize.width / 2,
                height: clamped.y - (windowSize.height - 48))
            toolbarDock = "floating"
            persistToolbarPlacement()
        }
    }

    private func persistToolbarPlacement() {
        UserDefaults.standard.set(toolbarFloatingVertical, forKey: "HeiBan.toolbarFloatingVertical")
        UserDefaults.standard.set(toolbarDock, forKey: "HeiBan.toolbarDock")
        UserDefaults.standard.set(
            [toolbarOffset.width, toolbarOffset.height], forKey: "HeiBan.toolbarOffset")
    }

    public func toolbarPosition(in windowSize: CGSize, panelSize: CGSize? = nil, topClearance: CGFloat = 64) -> CGPoint {
        let size =
            panelSize ?? toolbarLayoutSize
            ?? CGSize(width: isToolbarVertical ? 64 : 420, height: isToolbarVertical ? 420 : 64)
        let base: CGPoint
        switch toolbarDock {
        case "left":
            base = CGPoint(x: size.width / 2 + 12, y: (windowSize.height + 56) / 2)
        case "right":
            base = CGPoint(x: windowSize.width - size.width / 2 - 12, y: (windowSize.height + 56) / 2)
        case "top":
            base = CGPoint(x: windowSize.width / 2, y: topClearance + size.height / 2)
        case "bottom":
            base = CGPoint(x: windowSize.width / 2, y: windowSize.height - 48.0)
        default:  // floating
            base = CGPoint(x: windowSize.width / 2, y: windowSize.height - 48.0)
        }
        let posX = base.x + toolbarOffset.width
        let posY = base.y + toolbarOffset.height
        return clampPanelCenter(
            CGPoint(x: posX, y: posY),
            panelSize: size,
            windowSize: windowSize,
            margin: 4.0)
    }

    public func clampPanelCenter(
        _ center: CGPoint, panelSize: CGSize, windowSize: CGSize, margin: Double = 0.0
    ) -> CGPoint {
        let halfW = panelSize.width / 2.0
        let halfH = panelSize.height / 2.0
        let minX = halfW + margin
        let maxX = max(minX, windowSize.width - halfW - margin)
        let minY = halfH + margin
        let maxY = max(minY, windowSize.height - halfH - margin)
        let clampedX = max(minX, min(maxX, center.x))
        let clampedY = max(minY, min(maxY, center.y))
        return CGPoint(x: clampedX, y: clampedY)
    }

    public func repositionPanelsIfNeeded(windowSize: CGSize) {
        if toolbarDock == "floating" {
            let clamped = toolbarPosition(in: windowSize)
            let base = CGPoint(x: windowSize.width / 2, y: windowSize.height - 48.0)
            toolbarOffset = CGSize(width: clamped.x - base.x, height: clamped.y - base.y)
        }
    }

    public func submenuDirection(forDock dock: String) -> SubmenuDirection {
        switch dock {
        case "left":
            return .trailing
        case "right":
            return .leading
        case "top":
            return .bottom
        case "bottom":
            return .top
        default:
            return .top
        }
    }

    public func updateCurrentToolStyle(
        color: String? = nil, strokeWidth: Double? = nil, opacity: Double? = nil
    ) {
        if let color {
            activeColor = color
            registerRecentColor(color)
        }
        if let strokeWidth {
            activeStrokeWidth = strokeWidth
        }
        if let opacity {
            activeOpacity = opacity
        }

        switch currentTool {
        case .pen, .select:
            penPreset = ToolStylePreset(
                color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .highlighter:
            highlighterPreset = ToolStylePreset(
                color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .paint:
            paintPreset = ToolStylePreset(
                color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        default:
            penPreset = ToolStylePreset(
                color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        }
    }

    public func registerRecentColor(_ color: String) {
        var updated = recentColors.filter { $0.lowercased() != color.lowercased() }
        updated.insert(color, at: 0)
        if updated.count > 8 {
            updated = Array(updated.prefix(8))
        }
        recentColors = updated
    }

    public func updateRulerPivot(at screenPoint: Point) {
        RulerToolEngine.updatePivot(at: screenPoint, ruler: &ruler)
    }

    public func rotateRuler(toward screenPoint: Point, fromLeftEnd: Bool) {
        let oldAngle = ruler.angle * .pi / 180
        let pivotLocalX = (ruler.pivotRatio - 0.5) * ruler.width
        let pivotLocalY: Double
        switch ruler.pivotEdge {
        case "top": pivotLocalY = -ruler.height / 2
        case "bottom": pivotLocalY = ruler.height / 2
        default: pivotLocalY = 0
        }
        let oldPivot = Point(
            x: ruler.screenCenterX + pivotLocalX * cos(oldAngle) - pivotLocalY * sin(oldAngle),
            y: ruler.screenCenterY + pivotLocalX * sin(oldAngle) + pivotLocalY * cos(oldAngle)
        )
        let handleLocalX = (fromLeftEnd ? -0.5 : 0.5) * ruler.width - pivotLocalX
        let handleLocalY = -pivotLocalY
        let localAngle = atan2(handleLocalY, handleLocalX)
        let pointerAngle = atan2(screenPoint.y - oldPivot.y, screenPoint.x - oldPivot.x)
        let newAngle = pointerAngle - localAngle
        setRulerAngle(newAngle * 180 / .pi)
    }

    public func setRulerAngle(_ degrees: Double) {
        var next = ruler
        guard RulerToolEngine.setAngle(degrees, ruler: &next) else { return }
        ruler = next
    }

    /// Resets virtual ruler pivot to default center (W15, A13).
    public func resetRulerPivot() {
        var next = ruler
        next.pivotRatio = 0.5
        next.pivotEdge = "center"
        ruler = next
    }

    /// Ensures virtual ruler stays reachable within visible window after resize (W15, A13).
    public func repositionRulerIfNeeded(windowSize: CGSize) {
        guard windowSize.width > 100 && windowSize.height > 100 else { return }
        let margin: Double = 60.0
        let minX = margin
        let maxX = max(margin, Double(windowSize.width) - margin)
        let minY = margin
        let maxY = max(margin, Double(windowSize.height) - margin)
        var next = ruler
        next.screenCenterX = min(max(next.screenCenterX, minX), maxX)
        next.screenCenterY = min(max(next.screenCenterY, minY), maxY)
        ruler = next
    }

    public func handleScrollWheel(at screenPoint: Point, deltaX: Double, deltaY: Double, shift: Bool) {
        guard !viewportLocked && !inlineTextEditing && !showTextEditor else { return }
        if shift || abs(deltaX) > abs(deltaY) {
            viewport.x += deltaX + (shift ? deltaY : 0)
            if !shift { viewport.y += deltaY }
            return
        }

        let anchor = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        let factor = exp(deltaY * 0.006)
        let nextZoom = max(0.08, min(8.0, viewport.zoom * factor))
        viewport.zoom = nextZoom
        viewport.x = screenPoint.x - anchor.x * nextZoom
        viewport.y = screenPoint.y - anchor.y * nextZoom
    }

    public func updateMagnificationGesture(scale: Double, around screenPoint: Point) {
        guard !viewportLocked && !inlineTextEditing && !showTextEditor else { return }
        let factor = scale / previousMagnificationScale
        previousMagnificationScale = scale
        let anchor = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        let nextZoom = max(0.08, min(8.0, viewport.zoom * factor))
        viewport.zoom = nextZoom
        viewport.x = screenPoint.x - anchor.x * nextZoom
        viewport.y = screenPoint.y - anchor.y * nextZoom
    }

    public func endMagnificationGesture() {
        previousMagnificationScale = 1.0
    }

    public func updateLineEndpointDrag(objectID: String, endpoint: LineEndpoint, at screenPoint: Point) {
        guard let line = currentPageObjects.first(where: { $0.id == objectID }),
              ["line", "arrow"].contains(line.type), line.isLocked != true else { return }
        let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        if strokePreview.lineEndpoint?.objectID != objectID
            || strokePreview.lineEndpoint?.endpoint != endpoint
        {
            strokePreview.lineEndpoint = LineEndpointPreview(
                objectID: objectID, endpoint: endpoint, point: worldPoint)
        } else {
            strokePreview.lineEndpoint?.point = worldPoint
        }
    }

    public func endLineEndpointDrag() {
        guard let preview = strokePreview.lineEndpoint,
            let index = objects.firstIndex(where: { $0.id == preview.objectID })
        else { return }
        var updated = objects[index]
        guard updated.isLocked != true else { strokePreview.lineEndpoint = nil; return }
        // 先補全舊文件缺失的端點，水平／垂直線也能更新包圍範圍。
        updated.x1 = updated.x1 ?? updated.x
        updated.y1 = updated.y1 ?? updated.y
        updated.x2 = updated.x2 ?? updated.x + updated.width
        updated.y2 = updated.y2 ?? updated.y + updated.height
        updated.rotation = 0
        let previousX =
            preview.endpoint == .start ? updated.x1 ?? updated.x : updated.x2 ?? updated.x + updated.width
        let previousY =
            preview.endpoint == .start ? updated.y1 ?? updated.y : updated.y2 ?? updated.y + updated.height
        guard previousX != preview.point.x || previousY != preview.point.y else {
            strokePreview.lineEndpoint = nil
            return
        }
        let before = [objects[index]]
        if preview.endpoint == .start {
            updated.x1 = preview.point.x
            updated.y1 = preview.point.y
        } else {
            updated.x2 = preview.point.x
            updated.y2 = preview.point.y
        }
        if let x1 = updated.x1, let x2 = updated.x2, let y1 = updated.y1, let y2 = updated.y2 {
            updated.x = min(x1, x2)
            updated.y = min(y1, y2)
            updated.width = abs(x2 - x1)
            updated.height = abs(y2 - y1)
        }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = updated
        strokePreview.lineEndpoint = nil
        transactionManager.push(.modifyObjects(before: before, after: [updated]))
        scheduleAutosave()
    }

    public func updatePolygonVertex(objectID: String, index: Int, at screenPoint: Point) {
        guard let objectIndex = objects.firstIndex(where: { $0.id == objectID }),
            ["triangle", "quadrilateral", "curve"].contains(objects[objectIndex].type)
        else { return }
        let original = objects[objectIndex]
        guard original.parsedPoints.indices.contains(index) else { return }
        if polygonDragBefore[objectID] == nil { polygonDragBefore[objectID] = original }
        var points = original.parsedPoints
        points[index] = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        let minX = points.map(\.x).min() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxX = points.map(\.x).max() ?? minX + 1
        let maxY = points.map(\.y).max() ?? minY + 1
        var updated = original
        updated.x = minX
        updated.y = minY
        updated.width = max(1, maxX - minX)
        updated.height = max(1, maxY - minY)
        updated.points = (try? JSONEncoder().encode(points)).flatMap { String(data: $0, encoding: .utf8) }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[objectIndex] = updated
    }

    public func updatePolygonDraftCursor(at screenPoint: Point) {
        guard currentTool == .triangle || currentTool == .quadrilateral else {
            if polygonDraftCursorPoint != nil { polygonDraftCursorPoint = nil }
            return
        }
        polygonDraftCursorPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
    }

    public func endPolygonVertexDrag(objectID: String) {
        guard let before = polygonDragBefore.removeValue(forKey: objectID),
            let after = objects.first(where: { $0.id == objectID })
        else { return }
        guard before != after else { return }
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }

    public var isPointerGestureActive: Bool { pointerGesture != .idle }

    public func beginPointerGesture(at screenPoint: Point, isShift: Bool = false, clickCount: Int = 1) {
        guard pointerGesture == .idle else { return }
        pointerGestureStart = screenPoint
        if self.isShiftHeld != isShift { self.isShiftHeld = isShift }

        if isHoldingSpace {
            guard !viewportLocked else { return }
            pointerGesture = .pan
            return
        }

        if readingMode {
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            if let hitTape = currentPageObjects.reversed().first(where: {
                $0.type == "tape" && $0.isVisible != false
                    && VectorMath.isPointNearObject(
                        point: worldPoint, object: $0, threshold: 8 / viewport.zoom)
            }) {
                toggleTapeRevealed(id: hitTape.id)
                return
            }
            if laserEngine.isEnabled {
                laserEngine.beginTrail()
                laserEngine.addSample(point: worldPoint)
                return
            }
            guard !viewportLocked else { return }
            pointerGesture = .pan
            return
        }

        if currentTool == .laser || laserEngine.isEnabled {
            laserEngine.beginTrail()
            laserEngine.addSample(point: VectorMath.screenToWorld(screenPoint, viewport: viewport))
            return
        }

        if currentTool == .select {
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)

            if clickCount >= 2,
                let textObject = currentPageObjects.reversed().first(where: {
                    ($0.type == "text" || $0.type == "sticky") && $0.isVisible != false && $0.isLocked != true
                        && VectorMath.isPointNearObject(
                            point: worldPoint, object: $0, threshold: 8 / viewport.zoom)
                })
            {
                beginEditingText(object: textObject)
                return
            }

            if let line = selectedEndpointLine, line.isLocked != true {
                for endpoint in [LineEndpoint.start, .end] {
                    let point = Point(x: endpoint == .start ? line.x1 ?? line.x : line.x2 ?? line.x + line.width,
                                      y: endpoint == .start ? line.y1 ?? line.y : line.y2 ?? line.y + line.height)
                    if hypot(worldPoint.x - point.x, worldPoint.y - point.y) <= 10 / viewport.zoom {
                        pointerGesture = .lineEndpoint(line.id, endpoint)
                        updateLineEndpointDrag(objectID: line.id, endpoint: endpoint, at: screenPoint)
                        return
                    }
                }
            }
            // 單一線段只有 AB 端點；其他物件沿用包圍框與旋轉控制。
            if !selectionUsesEndpoints, let selBounds = selectionBoundingBox,
                let handle = VectorMath.hitTestHandle(
                    point: worldPoint, bounds: selBounds, zoom: viewport.zoom)
            {
                pointerGesture = .transformSelection(handle)
                activeTransformHandle = handle
                initialTransformBounds = selBounds
                initialTransformObjects = objects.filter { selectedIds.contains($0.id) }
                initialRotationCenter = CGPoint(x: selBounds.midX, y: selBounds.midY)
                initialRotationAngle =
                    atan2(worldPoint.y - Double(selBounds.midY), worldPoint.x - Double(selBounds.midX))
                    * 180.0 / Double.pi
                activeTransformDegrees = initialTransformObjects.first?.rotation ?? 0.0
                return
            }

            // 2. Check if user hit an object on canvas
            if let hit = currentPageObjects.reversed().first(where: {
                $0.isVisible != false && $0.isLocked != true
                    && VectorMath.isPointNearObject(
                        point: worldPoint, object: $0, threshold: 8 / viewport.zoom)
            }) {
                if isShiftHeld {
                    toggleObjectSelection(id: hit.id)
                    pointerGesture = .idle
                    return
                }

                if hit.type == "tape" && selectedIds.contains(hit.id) {
                    toggleTapeRevealed(id: hit.id)
                }

                if !selectedIds.contains(hit.id) {
                    selectObjectOnCanvas(id: hit.id)
                }
                strokePreview.selectionOffset = .zero
                if let extensionMode = hit.extensionMode { activeLineExtension = extensionMode }
                pointerGesture = .moveSelection
                return
            }

            // 3. Clicked empty space on canvas -> marquee selection
            if !isShiftHeld {
                selectedIds.removeAll()
            }
            pointerGesture = .marqueeSelection
            marqueeRect = CGRect(x: worldPoint.x, y: worldPoint.y, width: 0, height: 0)
            return
        }

        // The gray workspace around a finite page is for navigation, not new content.
        if currentTool != .eraser, board.canvasMode == .fixed || board.canvasMode == .notebook,
            let width = board.canvasWidth, let height = board.canvasHeight
        {
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            guard worldPoint.x >= 0, worldPoint.y >= 0, worldPoint.x <= width, worldPoint.y <= height else {
                pointerGestureStart = nil
                return
            }
        }

        if currentTool == .lasso {
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            inFlightLassoPoints = [worldPoint]
            return
        }

        if currentTool == .pen || currentTool == .curve || currentTool == .highlighter
            || currentTool == .paint
        {
            pointerGesture = .stroke
            startStroke(at: screenPoint)
        } else if currentTool == .triangle || currentTool == .quadrilateral {
            pointerGesture = .polygon(currentTool)
            addPolygonVertex(at: screenPoint, type: currentTool)
        } else if isShapeTool(currentTool) {
            pointerGesture = .shape
            updateShapePreview(at: screenPoint)
        } else if currentTool == .eraser {
            pointerGesture = .erasing
            beginEraserSwipe()
        } else if currentTool == .sticky || currentTool == .text {
            beginInlineTextEntry(
                at: VectorMath.screenToWorld(screenPoint, viewport: viewport), kind: currentTool)
        }
    }

    public func updatePointerGesture(at screenPoint: Point, translation: CGSize, isShift: Bool = false) {
        if pointerGesture == .pan {
            updatePanGesture(translation: translation)
            return
        }
        if currentTool == .laser || laserEngine.isEnabled {
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            laserEngine.addSample(point: worldPoint)
            return
        }
        if self.isShiftHeld != isShift { self.isShiftHeld = isShift }
        if currentTool == .lasso {
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            inFlightLassoPoints.append(worldPoint)
            return
        }

        switch pointerGesture {
        case .lineEndpoint(let id, let endpoint):
            updateLineEndpointDrag(objectID: id, endpoint: endpoint, at: screenPoint)
        case .idle:
            break
        case .pan:
            updatePanGesture(translation: translation)
        case .moveSelection:
            if let selBounds = selectionBoundingBox {
                let stationary = currentPageObjects.filter { !selectedIds.contains($0.id) }
                let snap = AlignmentSnapCoordinator.computeSnap(
                    movingBounds: selBounds,
                    proposedDelta: CGSize(
                        width: translation.width / viewport.zoom, height: translation.height / viewport.zoom),
                    referenceObjects: stationary,
                    threshold: 8.0 / viewport.zoom
                )
                activeAlignmentGuides = snap.guides
                strokePreview.selectionOffset = CGSize(
                    width: snap.snappedDeltaX * viewport.zoom, height: snap.snappedDeltaY * viewport.zoom)
            } else {
                strokePreview.selectionOffset = translation
            }
        case .marqueeSelection:
            guard let start = pointerGestureStart else { break }
            let worldStart = VectorMath.screenToWorld(start, viewport: viewport)
            let worldCurrent = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            let minX = min(worldStart.x, worldCurrent.x)
            let minY = min(worldStart.y, worldCurrent.y)
            let w = abs(worldCurrent.x - worldStart.x)
            let h = abs(worldCurrent.y - worldStart.y)
            let rect = CGRect(x: minX, y: minY, width: w, height: h)
            marqueeRect = rect
            selectObjectsInBox(rect: rect, isShiftPressed: isShiftHeld)
        case .transformSelection(let handle):
            guard let origBounds = initialTransformBounds else { break }
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            if handle == .rotate {
                guard let center = initialRotationCenter else { break }
                let currentAngle =
                    atan2(worldPoint.y - Double(center.y), worldPoint.x - Double(center.x)) * 180.0
                    / Double.pi
                let delta = currentAngle - initialRotationAngle
                for initial in initialTransformObjects {
                    let rotated = VectorMath.rotateObject(
                        object: initial, around: center, deltaDegrees: delta)
                    if let idx = objects.firstIndex(where: { $0.id == rotated.id }) {
                        objects[idx] = rotated
                    }
                }
                if let first = objects.first(where: { selectedIds.contains($0.id) }) {
                    activeTransformDegrees = first.rotation
                } else {
                    activeTransformDegrees = delta
                }
            } else {
                let newBounds = computeTransformedBounds(
                    handle: handle, origBounds: origBounds, currentPoint: worldPoint,
                    preserveAspect: isShiftHeld)
                for initial in initialTransformObjects {
                    let scaled = VectorMath.transformObject(
                        object: initial, from: origBounds, to: newBounds, preserveAspectRatio: isShiftHeld)
                    if let idx = objects.firstIndex(where: { $0.id == scaled.id }) {
                        objects[idx] = scaled
                    }
                }
            }
        case .stroke:
            appendStrokePoint(at: screenPoint)
        case .shape:
            updateShapePreview(at: screenPoint)
        case .polygon:
            break
        case .erasing:
            eraseAt(screenPt: screenPoint)
        case .textEntry:
            break
        }
    }

    public func endPointerGesture(translation: CGSize) {
        if currentTool == .laser || laserEngine.isEnabled, pointerGesture == .idle {
            pointerGestureStart = nil
            return
        }
        if currentTool == .lasso {
            let selected = LassoSelectionCoordinator.selectObjects(
                in: inFlightLassoPoints,
                objects: currentPageObjects,
                mode: lassoMode,
                filter: lassoFilter
            )
            selectedIds = selected
            inFlightLassoPoints.removeAll()
            pointerGesture = .idle
            pointerGestureStart = nil
            return
        }

        switch pointerGesture {
        case .idle, .pan, .textEntry, .polygon:
            break
        case .lineEndpoint:
            endLineEndpointDrag()
        case .erasing:
            endEraserSwipe()
        case .moveSelection:
            let dx = translation.width / viewport.zoom
            let dy = translation.height / viewport.zoom
            if dx != 0 || dy != 0, !selectedIds.isEmpty {
                let selectedFrames = objects.filter { selectedIds.contains($0.id) && $0.type == "frame" }
                var allEffectiveMoveIds = selectedIds
                for frame in selectedFrames {
                    if let childIds = frame.childIds {
                        allEffectiveMoveIds.formUnion(childIds)
                    }
                }
                let before = objects.filter { allEffectiveMoveIds.contains($0.id) }
                var after: [BoardObject] = []
                objects = objects.map { object in
                    guard allEffectiveMoveIds.contains(object.id) else { return object }
                    var moved = object
                    moved.x += dx
                    moved.y += dy
                    if let x1 = moved.x1 { moved.x1 = x1 + dx }
                    if let y1 = moved.y1 { moved.y1 = y1 + dy }
                    if let x2 = moved.x2 { moved.x2 = x2 + dx }
                    if let y2 = moved.y2 { moved.y2 = y2 + dy }
                    if let points = moved.points {
                        moved.points = Self.translatedPointsJSON(points, dx: dx, dy: dy)
                    }
                    moved.updatedAt = ISO8601DateFormatter().string(from: Date())
                    after.append(moved)
                    return moved
                }
                updateConnectedLines()
                transactionManager.push(.modifyObjects(before: before, after: after))
                scheduleAutosave()
            }
            activeAlignmentGuides.removeAll()
            strokePreview.selectionOffset = .zero
        case .marqueeSelection:
            if let rect = marqueeRect {
                selectObjectsInBox(rect: rect, isShiftPressed: isShiftHeld)
            }
            marqueeRect = nil
        case .transformSelection:
            if initialTransformBounds != nil, !initialTransformObjects.isEmpty {
                let after = objects.filter { selectedIds.contains($0.id) }
                transactionManager.push(.modifyObjects(before: initialTransformObjects, after: after))
                scheduleAutosave()
            }
            activeTransformHandle = nil
            activeTransformDegrees = nil
            initialTransformBounds = nil
            initialTransformObjects = []
            initialRotationCenter = nil
        case .stroke:
            endStroke()
        case .shape:
            if let object = strokePreview.shapeObject,
                max(object.width, object.height) >= 3
            {
                appendInZOrder(object)
                selectedIds = [object.id]
                transactionManager.push(.insertObjects([object]))
                scheduleAutosave()
                if selectAfterShapeCreation {
                    currentTool = .select
                }
            }
            strokePreview.shapeObject = nil
        }

        pointerGesture = .idle
        pointerGestureStart = nil
        endPanGesture()
    }

    public func cancelTransientInteraction() {
        holdTimer?.invalidate()
        holdTimer = nil
        pointerGesture = .idle
        pointerGestureStart = nil
        previousPanTranslation = .zero
        strokePreview.reset()
        selectedIds.removeAll()
        marqueeRect = nil
        activeTransformHandle = nil
        activeTransformDegrees = nil
        initialTransformBounds = nil
        initialTransformObjects = []
        initialRotationCenter = nil
        currentTool = .select
        isHoldingSpace = false
        showTextEditor = false
        showInlineTextEditor = false
        textDraft = ""
        editingTextObjectId = nil
        editingRichTextSpans = []
        originalTextObject = nil
        polygonDraftPoints.removeAll()
        polygonDraftCursorPoint = nil
        laserEngine.cleanupOnDeactivate()
        activeAlignmentGuides.removeAll()
        inFlightLassoPoints.removeAll()
        closeAllTransientPanels()
    }

    /// Selects a tool. If the specified tool is already active, toggles back to .select (A05, A11).
    public func selectTool(_ tool: ToolType) {
        if tool != .laser || currentTool == .laser { laserEngine.cleanupOnDeactivate() }
        closeAllTransientPanels()
        readingMode = false
        if !polygonDraftPoints.isEmpty {
            polygonDraftPoints.removeAll()
            polygonDraftCursorPoint = nil
        }

        // 1. Save current tool preset
        switch currentTool {
        case .pen:
            penPreset = ToolStylePreset(
                color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .highlighter:
            highlighterPreset = ToolStylePreset(
                color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .paint:
            paintPreset = ToolStylePreset(
                color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        default:
            break
        }

        if currentTool == tool {
            currentTool = .select
        } else {
            currentTool = tool
            // 2. Restore new tool preset
            switch tool {
            case .pen:
                activeColor = penPreset.color
                activeStrokeWidth = penPreset.strokeWidth
                activeOpacity = penPreset.opacity
            case .highlighter:
                activeColor = highlighterPreset.color
                activeStrokeWidth = highlighterPreset.strokeWidth
                activeOpacity = highlighterPreset.opacity
            case .paint:
                activeColor = paintPreset.color
                activeStrokeWidth = paintPreset.strokeWidth
                activeOpacity = paintPreset.opacity
            default:
                break
            }
        }
        if currentTool == .laser { laserEngine.isEnabled = true }
    }

    /// Cleans up modifier states and transient gestures when window loses focus (A11).
    public func handleWindowBlur() {
        isHoldingSpace = false
        isShiftHeld = false
        laserEngine.clear()
        activeAlignmentGuides.removeAll()
        inFlightLassoPoints.removeAll()
        if pointerGesture == .pan {
            pointerGesture = .idle
            pointerGestureStart = nil
            previousPanTranslation = .zero
        }
    }

    private func isShapeTool(_ tool: ToolType) -> Bool {
        [ToolType.rect, .circle, .diamond, .star, .line, .arrow, .roundedRect, .polygon, .connector, .tape]
            .contains(tool)
    }

    private func addPolygonVertex(at screenPoint: Point, type: String) {
        polygonDraftPoints.append(VectorMath.screenToWorld(screenPoint, viewport: viewport))
        let requiredCount = type == .triangle ? 3 : 4
        if polygonDraftPoints.count < requiredCount {
            strokePreview.shapeObject = nil
            return
        }
        let vertices = Array(polygonDraftPoints.prefix(requiredCount))
        let object = makePolygonObject(type: type, vertices: vertices)
        appendInZOrder(object)
        selectedIds = [object.id]
        transactionManager.push(.insertObjects([object]))
        scheduleAutosave()
        polygonDraftPoints.removeAll()
        polygonDraftCursorPoint = nil
        strokePreview.shapeObject = nil
        if selectAfterShapeCreation {
            currentTool = .select
        }
    }

    private func makePolygonObject(type: String, vertices: [Point]) -> BoardObject {
        let minX = vertices.map(\.x).min() ?? 0
        let minY = vertices.map(\.y).min() ?? 0
        let maxX = vertices.map(\.x).max() ?? minX + 1
        let maxY = vertices.map(\.y).max() ?? minY + 1
        let pointsData = try? JSONEncoder().encode(vertices)
        return BoardObject(
            boardId: board.id,
            type: type,
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY),
            points: pointsData.flatMap { String(data: $0, encoding: .utf8) },
            strokeColor: activeColor,
            fillColor: autoFillShapes ? activeColor : "none",
            strokeWidth: activeStrokeWidth,
            lineStyle: activeLineStyle,
            opacity: activeOpacity,
            zIndex: (objects.map(\.zIndex).max() ?? 0) + 1
        )
    }

    private func updateShapePreview(at screenPoint: Point) {
        guard let startScreen = pointerGestureStart else { return }
        let start = VectorMath.screenToWorld(startScreen, viewport: viewport)
        let end = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = max(1, abs(end.x - start.x))
        let height = max(1, abs(end.y - start.y))
        let line = currentTool == .line || currentTool == .arrow || currentTool == .connector

        let cornerRadius: Double? = currentTool == .roundedRect ? 16.0 : nil
        let polygonSides: Int? = currentTool == .polygon ? 5 : nil
        let tapeStyle: String? = currentTool == .tape ? "rect" : nil
        let isRevealed: Bool? = currentTool == .tape ? false : nil

        strokePreview.shapeObject = BoardObject(
            boardId: board.id,
            type: currentTool,
            x: minX,
            y: minY,
            width: line ? abs(end.x - start.x) : width,
            height: line ? abs(end.y - start.y) : height,
            x1: line ? start.x : nil,
            y1: line ? start.y : nil,
            x2: line ? end.x : nil,
            y2: line ? end.y : nil,
            extensionMode: line ? activeLineExtension : nil,
            strokeColor: currentTool == .tape ? "#f59e0b" : activeColor,
            fillColor: autoFillShapes ? activeColor : "none",
            strokeWidth: activeStrokeWidth,
            lineStyle: activeLineStyle,
            opacity: currentTool == .tape ? 0.95 : activeOpacity,
            zIndex: objects.count + 1,
            isRevealed: isRevealed,
            tapeStyle: tapeStyle,
            cornerRadius: cornerRadius,
            polygonSides: polygonSides
        )
    }

    static func translatedPointsJSON(_ json: String, dx: Double, dy: Double) -> String? {
        guard let data = json.data(using: .utf8),
            var points = try? JSONDecoder().decode([Point].self, from: data)
        else { return nil }
        for index in points.indices {
            points[index].x += dx
            points[index].y += dy
        }
        guard let result = try? JSONEncoder().encode(points) else { return nil }
        return String(data: result, encoding: .utf8)
    }

    // MARK: - Undo & Redo (A04)
    public func undo() {
        guard let command = transactionManager.popUndo() else { return }
        apply(command: command, isUndo: true)
        selectedIds.removeAll()
        scheduleAutosave()
    }

    public func redo() {
        guard let command = transactionManager.popRedo() else { return }
        apply(command: command, isUndo: false)
        selectedIds.removeAll()
        scheduleAutosave()
    }

    private func apply(command: BoardCommand, isUndo: Bool) {
        switch command {
        case .insertObjects(let objs):
            let ids = Set(objs.map(\.id))
            if isUndo {
                objects.removeAll { ids.contains($0.id) }
            } else {
                for obj in objs {
                    appendInZOrder(obj)
                }
            }
        case .removeObjects(let objs):
            let ids = Set(objs.map(\.id))
            if isUndo {
                for obj in objs {
                    appendInZOrder(obj)
                }
            } else {
                objects.removeAll { ids.contains($0.id) }
            }
        case .modifyObjects(let before, let after):
            let target = isUndo ? before : after
            let map = Dictionary(uniqueKeysWithValues: target.map { ($0.id, $0) })
            for i in objects.indices {
                if let updated = map[objects[i].id] {
                    objects[i] = updated
                }
            }
        case .reorderObjects(let before, let after):
            let target = isUndo ? before : after
            objects = target
        case .updateCanvas(let before, let after):
            board = isUndo ? before : after
        case .updatePins(let before, let after):
            board.pins = isUndo ? before : after
        case .clearCanvas(let cleared):
            if isUndo {
                objects = cleared
            } else {
                objects.removeAll()
            }
        case .composite(let subcommands):
            if isUndo {
                for sub in subcommands.reversed() {
                    apply(command: sub, isUndo: true)
                }
            } else {
                for sub in subcommands {
                    apply(command: sub, isUndo: false)
                }
            }
        }
    }

    // MARK: - Object Management
    public func addObject(_ obj: BoardObject) {
        appendInZOrder(obj)
        transactionManager.push(.insertObjects([obj]))
        scheduleAutosave()
    }

    @discardableResult
    public func addSticky(text: String, at worldPt: Point = Point(x: 200, y: 200)) -> BoardObject {
        var maxZ = objects.map(\.zIndex).max() ?? 0
        maxZ += 1
        var obj = BoardObject(
            boardId: board.id,
            type: "sticky",
            x: worldPt.x,
            y: worldPt.y,
            width: 200,
            height: 150,
            strokeColor: "#1f2937",
            fillColor: StickyPalette.yellow,
            strokeWidth: 1,
            zIndex: maxZ,
            text: text,
            fontSize: 16,
            fontFamily: "PingFang TC",
            stickyStyle: .classic
        )
        if isNotebook {
            obj.pageId = activePageId
        }
        addObject(obj)
        return obj
    }

    public func removeObjects(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let removed = objects.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        objects.removeAll { ids.contains($0.id) }
        selectedIds.subtract(ids)
        transactionManager.push(.removeObjects(removed))
        scheduleAutosave()
    }

    public func clearAll() {
        if isNotebook {
            let pageObjs = currentPageObjects
            guard !pageObjs.isEmpty else { return }
            let pageObjIds = Set(pageObjs.map(\.id))
            objects.removeAll { pageObjIds.contains($0.id) }
            selectedIds.removeAll()
            transactionManager.push(.removeObjects(pageObjs))
            scheduleAutosave()
        } else {
            guard !objects.isEmpty else { return }
            let prev = objects
            objects.removeAll()
            selectedIds.removeAll()
            transactionManager.push(.clearCanvas(clearedObjects: prev))
            scheduleAutosave()
        }
    }

    func appendInZOrder(_ object: BoardObject) {
        var obj = object
        if isNotebook && obj.pageId == nil {
            obj.pageId = activePageId
        }
        objects.append(obj)
        if objects.count > 1 && objects[objects.count - 2].zIndex > obj.zIndex {
            objects.sort { $0.zIndex < $1.zIndex }
        }
    }

    public internal(set) var holdStartScreenPoint: Point?
    var rulerStrokeEdge: Double?

    // MARK: - Add Geometric Shapes & Stickies
    public func addShape(type: String, at worldPt: Point) {
        let newObj: BoardObject
        switch type {
        case "sticky":
            newObj = BoardObject(
                boardId: board.id,
                type: "sticky",
                x: worldPt.x,
                y: worldPt.y,
                width: 220,
                height: 180,
                strokeColor: "#1f2937",
                fillColor: activeColor == "#86efac" ? "#fef08a" : activeColor,
                strokeWidth: 1,
                zIndex: objects.count + 1,
                text: "點擊編輯便條內容...",
                fontSize: 14
            )
        case "text":
            newObj = BoardObject(
                boardId: board.id,
                type: "text",
                x: worldPt.x,
                y: worldPt.y,
                width: 240,
                height: 40,
                strokeColor: activeColor,
                strokeWidth: 1,
                zIndex: objects.count + 1,
                text: "點擊輸入文字...",
                fontSize: 22
            )
        case "rect":
            newObj = BoardObject(
                boardId: board.id,
                type: "rect",
                x: worldPt.x,
                y: worldPt.y,
                width: 160,
                height: 110,
                strokeColor: activeColor,
                fillColor: "none",
                strokeWidth: activeStrokeWidth,
                lineStyle: activeLineStyle,
                zIndex: objects.count + 1
            )
        case "circle":
            newObj = BoardObject(
                boardId: board.id,
                type: "circle",
                x: worldPt.x,
                y: worldPt.y,
                width: 140,
                height: 140,
                strokeColor: activeColor,
                fillColor: "none",
                strokeWidth: activeStrokeWidth,
                lineStyle: activeLineStyle,
                zIndex: objects.count + 1
            )
        case "triangle":
            newObj = BoardObject(
                boardId: board.id,
                type: "triangle",
                x: worldPt.x,
                y: worldPt.y,
                width: 150,
                height: 130,
                strokeColor: activeColor,
                fillColor: "none",
                strokeWidth: activeStrokeWidth,
                lineStyle: activeLineStyle,
                zIndex: objects.count + 1
            )
        case "diamond", "star":
            newObj = BoardObject(
                boardId: board.id,
                type: type,
                x: worldPt.x,
                y: worldPt.y,
                width: 150,
                height: 130,
                strokeColor: activeColor,
                fillColor: "none",
                strokeWidth: activeStrokeWidth,
                lineStyle: activeLineStyle,
                zIndex: objects.count + 1
            )
        case "line":
            newObj = BoardObject(
                boardId: board.id,
                type: "line",
                x: worldPt.x,
                y: worldPt.y,
                width: 180,
                height: 0,
                x1: worldPt.x,
                y1: worldPt.y,
                x2: worldPt.x + 180,
                y2: worldPt.y,
                strokeColor: activeColor,
                strokeWidth: activeStrokeWidth,
                lineStyle: activeLineStyle,
                zIndex: objects.count + 1
            )
        case "arrow":
            newObj = BoardObject(
                boardId: board.id,
                type: "arrow",
                x: worldPt.x,
                y: worldPt.y,
                width: 180,
                height: 80,
                x1: worldPt.x,
                y1: worldPt.y,
                x2: worldPt.x + 180,
                y2: worldPt.y + 80,
                strokeColor: activeColor,
                strokeWidth: activeStrokeWidth,
                lineStyle: activeLineStyle,
                zIndex: objects.count + 1
            )
        default:
            return
        }
        appendInZOrder(newObj)
        selectedIds = [newObj.id]
        transactionManager.push(.insertObjects([newObj]))
        scheduleAutosave()
    }

    // MARK: - Canvas Settings Transactions (A04)
    private func computeTransformedBounds(
        handle: TransformHandle,
        origBounds: CGRect,
        currentPoint: Point,
        preserveAspect: Bool
    ) -> CGRect {
        var minX = origBounds.minX
        var minY = origBounds.minY
        var maxX = origBounds.maxX
        var maxY = origBounds.maxY

        switch handle {
        case .topLeft:
            minX = currentPoint.x
            minY = currentPoint.y
        case .topCenter:
            minY = currentPoint.y
        case .topRight:
            maxX = currentPoint.x
            minY = currentPoint.y
        case .middleRight:
            maxX = currentPoint.x
        case .bottomRight:
            maxX = currentPoint.x
            maxY = currentPoint.y
        case .bottomCenter:
            maxY = currentPoint.y
        case .bottomLeft:
            minX = currentPoint.x
            maxY = currentPoint.y
        case .middleLeft:
            minX = currentPoint.x
        case .rotate:
            return origBounds
        }

        var w = maxX - minX
        var h = maxY - minY

        if preserveAspect, origBounds.width > 0, origBounds.height > 0 {
            let aspect = origBounds.width / origBounds.height
            if abs(w) > abs(h * aspect) {
                h = (h < 0 ? -1 : 1) * abs(w / aspect)
            } else {
                w = (w < 0 ? -1 : 1) * abs(h * aspect)
            }
        }

        return CGRect(x: minX, y: minY, width: w, height: h)
    }

    public weak var dialogService: PlatformDialogService?
    public var pasteboardService: PlatformPasteboardService?
    public var imageDecoderService: PlatformImageDecoderService?
    public var screenCaptureService: PlatformScreenCaptureService?
    var screenCaptureInProgress = false

    public func jumpToPin(_ pin: BoardPin) {
        guard !viewportLocked else {
            showTemporaryStatus("請先解除視角鎖定")
            return
        }
        let target = targetViewportForPin(pin, canvasSize: canvasSize)
        viewport = target
        showTemporaryStatus("已飛至圖釘：\(pin.name)")
    }

    public func showTemporaryStatus(_ text: String) {
        statusMessage = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.statusMessage == text {
                self.statusMessage = nil
            }
        }
    }
}
