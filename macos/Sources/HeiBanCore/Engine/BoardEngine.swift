import Foundation
import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

public enum LineEndpoint: String, Equatable {
    case start
    case end
}

public struct LineEndpointPreview: Equatable {
    public var objectID: String
    public var endpoint: LineEndpoint
    public var point: Point

    public init(objectID: String, endpoint: LineEndpoint, point: Point) {
        self.objectID = objectID
        self.endpoint = endpoint
        self.point = point
    }
}

public final class StrokePreviewStore: ObservableObject {
    @Published public private(set) var points: [Point] = []
    @Published public var snappedShape: RecognizedShape?
    @Published public var shapeObject: BoardObject?
    @Published public var selectionOffset: CGSize = .zero
    @Published public var lineEndpoint: LineEndpointPreview?

    /// A single sealed path keeps the renderer from issuing one stroke draw per chunk.
    /// Chunks are still built incrementally so pointer updates only append a small tail.
    public private(set) var stablePath = Path()
    public private(set) var activePath = Path()
    public private(set) var tailPath = Path()
    private var activeSegments = 0

    public init() {}

    public func begin(with point: Point) {
        stablePath = Path()
        activePath = Path()
        activePath.move(to: point.cgPoint)
        activeSegments = 0
        tailPath = Path()
        tailPath.move(to: point.cgPoint)
        tailPath.addLine(to: CGPoint(x: point.x + 0.01, y: point.y))
        points = [point]
        snappedShape = nil
        shapeObject = nil
    }

    public func append(_ point: Point) {
        points.append(point)
        snappedShape = nil
        let count = points.count
        if count >= 3 {
            VectorMath.appendSmoothSegment(to: &activePath, points: points, index: count - 3)
            activeSegments += 1
            if activeSegments == 64 {
                stablePath.addPath(activePath)
                activePath = Path()
                activePath.move(to: points[count - 2].cgPoint)
                activeSegments = 0
            }
        }
        tailPath = Path()
        if count >= 2 {
            tailPath.move(to: points[count - 2].cgPoint)
            VectorMath.appendSmoothSegment(to: &tailPath, points: points, index: count - 2)
        }
    }

    public func reset() {
        stablePath = Path()
        activePath = Path()
        tailPath = Path()
        activeSegments = 0
        points.removeAll(keepingCapacity: true)
        snappedShape = nil
        shapeObject = nil
        selectionOffset = .zero
        lineEndpoint = nil
    }
}

public struct ToolStylePreset: Codable, Equatable {
    public var color: String
    public var strokeWidth: Double
    public var opacity: Double

    public init(color: String, strokeWidth: Double, opacity: Double) {
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
    }
}

public enum SubmenuDirection: String, Equatable {
    case leading
    case trailing
    case top
    case bottom
}

public enum ScreenCaptureMode: Equatable {
    case region
    case display(index: Int)
}

public class BoardEngine: ObservableObject {
    public enum PointerGesture: Equatable {
        case idle
        case pan
        case moveSelection
        case marqueeSelection
        case transformSelection(TransformHandle)
        case stroke
        case shape
        case polygon(String)
        case erasing
        case textEntry
    }

    @Published public var showingHome = true
    @Published public var libraryBoards: [BoardMetadata] = []
    @Published public var toolbarDock = UserDefaults.standard.string(forKey: "HeiBan.toolbarDock") ?? "bottom"
    @Published public var board: BoardMetadata
    @Published public var objects: [BoardObject] = []
    @Published public var selectedIds: Set<String> = []
    @Published public var marqueeRect: CGRect? = nil
    @Published public var activeTransformHandle: TransformHandle? = nil
    @Published public var hoveredTransformHandle: TransformHandle? = nil
    @Published public var isShiftHeld: Bool = false

    public var isToolbarVertical: Bool {
        toolbarDock == "left" || toolbarDock == "right"
    }

    public var selectionBoundingBox: CGRect? {
        VectorMath.selectionBounds(for: currentPageObjects.filter { selectedIds.contains($0.id) && $0.isVisible != false })
    }

    public func updateHoveredHandle(at screenPoint: Point?) {
        guard currentTool == .select, let screenPoint, let selBounds = selectionBoundingBox else {
            hoveredTransformHandle = nil
            return
        }
        let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        hoveredTransformHandle = VectorMath.hitTestHandle(point: worldPoint, bounds: selBounds, zoom: viewport.zoom)
    }

    public func currentCursorType(at screenPoint: Point? = nil) -> TransformCursorType? {
        if let active = activeTransformHandle {
            return active.cursorType
        }
        if let screenPoint {
            guard currentTool == .select, let selBounds = selectionBoundingBox else { return nil }
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
            return VectorMath.hitTestHandle(point: worldPoint, bounds: selBounds, zoom: viewport.zoom)?.cursorType
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
    @Published public var ruler: RulerState = RulerState()
    @Published public var viewport: ViewportTransform = ViewportTransform(x: 200, y: 150, zoom: 1.0)
    @Published public var canvasSize = CGSize(width: 1200, height: 800)

    @Published public var penPreset = ToolStylePreset(color: "#86efac", strokeWidth: 3.5, opacity: 1.0)
    @Published public var highlighterPreset = ToolStylePreset(color: "#fef08a", strokeWidth: 18.0, opacity: 0.45)
    @Published public var paintPreset = ToolStylePreset(color: "#93c5fd", strokeWidth: 32.0, opacity: 0.8)
    @Published public var recentColors: [String] = ["#86efac", "#fef08a", "#93c5fd", "#ffffff", "#f472b6"]

    @Published public var activeColor: String = "#86efac" // Chalk green
    @Published public var activeStrokeWidth: Double = 3.5
    @Published public var activeLineStyle: String = "solid" // "solid" | "dashed"
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

    // Transaction Manager for Undo / Redo & Layers (A04 & A24)
    public let transactionManager = TransactionManager(maxCapacity: 50)
    private var activeEraserDeletedObjects: [BoardObject] = []
    private var activeEraserInsertedObjects: [BoardObject] = []
    private var isEraserSwipeActive: Bool = false
    private var previousPanTranslation = CGSize.zero
    private var previousRulerTranslation = CGSize.zero
    private var rulerDragStart: Point?
    private var rulerCenterAtDragStart = CGPoint.zero
    private var pinDragBefore: BoardPin?
    private var polygonDragBefore: [String: BoardObject] = [:]
    private var previousToolbarTranslation = CGSize.zero
    public private(set) var pointerGesture: PointerGesture = .idle
    private var pointerGestureStart: Point?
    private var textEntryPoint = Point(x: 0, y: 0)
    private var originalTextObject: BoardObject?
    private var previousMagnificationScale = 1.0
    private var autosaveWorkItem: DispatchWorkItem?
    private var autosaveGeneration = 0
    private static let autosaveQueue = DispatchQueue(label: "com.bear.HeiBan.autosave", qos: .utility)

    public init(restoreSession: Bool = true) {
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
               (try? Self.library.load(id: board.id)) == nil {
                try? Self.library.save(HeiBanDocument(board: board, objects: objects))
            }
            if let latest = try? Self.library.load(id: board.id) {
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


    public var document: HeiBanDocument {
        HeiBanDocument(board: board, objects: objects)
    }

    private static var autosaveURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("HeiBan", isDirectory: true)
            .appendingPathComponent("current.blackboard.json")
    }

    private func restoreAutosave() {
        guard let url = Self.autosaveURL,
              let data = try? Data(contentsOf: url),
              let document = try? HeiBanDocumentCodec.decode(from: data) else { return }
        board = document.board
        objects = document.objects.sorted { $0.zIndex < $1.zIndex }
        autosaveStatus = "已還原上次工作"
    }

    public func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        autosaveGeneration += 1
        let generation = autosaveGeneration
        let work = DispatchWorkItem { [weak self] in self?.writeAutosaveSnapshot(generation: generation) }
        autosaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
        autosaveStatus = "儲存中…"
    }

    private func writeAutosaveSnapshot(generation: Int) {
        guard let url = Self.autosaveURL else {
            autosaveStatus = "無法取得自動儲存位置"
            return
        }
        var document = HeiBanDocument(schemaVersion: "1.0.0", version: "1.0", board: board, objects: objects)
        let nextRev = (board.revision ?? 0) + 1
        document.board.revision = nextRev

        Self.autosaveQueue.async { [weak self] in
            do {
                let data = try HeiBanDocumentCodec.encode(document)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                try Self.library.save(document)
                DispatchQueue.main.async {
                    guard self?.autosaveGeneration == generation else { return }
                    self?.board.revision = nextRev
                    self?.refreshLibrary()
                    self?.autosaveStatus = "本機已儲存 \(Date.now.formatted(date: .omitted, time: .shortened))"
                }
            } catch {
                DispatchQueue.main.async {
                    guard self?.autosaveGeneration == generation else { return }
                    self?.autosaveStatus = "自動儲存失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    public static let library = LocalBoardLibrary()

    public func refreshLibrary() {
        do {
            let result = try Self.library.inspectLibrary()
            libraryBoards = result.validBoards
            damagedBoards = result.damagedFiles
        } catch {
            showTemporaryStatus("無法讀取黑板資料庫：\(error.localizedDescription)")
        }
    }

    public func recoverDamagedBoard(id: String) {
        do {
            let restored = try Self.library.restoreFromBackup(id: id)
            refreshLibrary()
            showTemporaryStatus("已從備份成功恢復黑板：\(restored.board.title)")
        } catch {
            showTemporaryStatus("恢復失敗：\(error.localizedDescription)")
        }
    }

    @discardableResult
    public func saveBeforeLeaving() -> Bool {
        if showingHome && objects.isEmpty && !libraryBoards.contains(where: { $0.id == board.id }) { return true }
        autosaveWorkItem?.cancel()
        autosaveGeneration += 1
        var document = HeiBanDocument(schemaVersion: "1.0.0", version: "1.0", board: board, objects: objects)
        let nextRev = (board.revision ?? 0) + 1
        document.board.revision = nextRev
        board.revision = nextRev

        do {
            // Serialize with pending background saves so an older snapshot cannot overwrite this one.
            try Self.autosaveQueue.sync {
                try Self.library.save(document)
                if let url = Self.autosaveURL {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let data = try HeiBanDocumentCodec.encode(document)
                    try data.write(to: url, options: .atomic)
                }
            }
            refreshLibrary()
            autosaveStatus = "本機已儲存 \(Date.now.formatted(date: .omitted, time: .shortened))"
            return true
        } catch {
            autosaveStatus = "儲存失敗：\(error.localizedDescription)"
            showTemporaryStatus("儲存失敗，保留目前黑板：\(error.localizedDescription)")
            return false
        }
    }

    public func flushAutosave() { _ = saveBeforeLeaving() }

    public func returnHome() {
        guard saveBeforeLeaving() else { return }
        cancelTransientInteraction()
        showingHome = true
    }

    public func openLibraryBoard(_ id: String) {
        guard saveBeforeLeaving() else { return }
        do { activate(try Self.library.load(id: id)) }
        catch { showTemporaryStatus("開啟失敗：\(error.localizedDescription)") }
    }

    public func createBoard(
        title: String,
        theme: BoardTheme = .dark,
        mode: CanvasMode = .infinite,
        preset: CanvasPreset? = nil,
        width: Double? = nil,
        height: Double? = nil,
        orientation: String? = nil,
        coverStyle: String? = nil,
        gridStyle: GridStyle = .dots,
        backgroundColor: String? = nil,
        gridColor: String? = nil
    ) {
        guard saveBeforeLeaving() else { return }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? "未命名黑板" : title

        var meta = BoardMetadata(
            id: UUID().uuidString,
            title: finalTitle,
            backgroundColor: backgroundColor ?? theme.defaultBackgroundColor,
            gridStyle: gridStyle,
            boardTheme: theme,
            coverStyle: coverStyle,
            orientation: orientation,
            gridColor: gridColor
        )
        meta.canvasMode = mode

        switch mode {
        case .infinite:
            meta.canvasPreset = .infinite
            meta.canvasWidth = nil
            meta.canvasHeight = nil
            meta.pages = nil
            meta.activePageId = nil
        case .fixed:
            let resolvedPreset = preset ?? .sixteen_nine
            meta.canvasPreset = resolvedPreset
            var w = width ?? resolvedPreset.dimensions.width
            var h = height ?? resolvedPreset.dimensions.height
            if orientation == "landscape" || orientation == "橫向" {
                if w < h { swap(&w, &h) }
            } else if orientation == "portrait" || orientation == "直向" {
                if w > h { swap(&w, &h) }
            }
            meta.canvasWidth = w
            meta.canvasHeight = h
            meta.pages = nil
            meta.activePageId = nil
        case .notebook:
            let resolvedPreset = preset ?? .notebook
            meta.canvasPreset = resolvedPreset
            var w = width ?? resolvedPreset.dimensions.width
            var h = height ?? resolvedPreset.dimensions.height
            if orientation == "landscape" || orientation == "橫向" {
                if w < h { swap(&w, &h) }
            } else if orientation == "portrait" || orientation == "直向" {
                if w > h { swap(&w, &h) }
            }
            meta.canvasWidth = w
            meta.canvasHeight = h
            let firstPage = BoardPage(id: UUID().uuidString, title: "第 1 頁", index: 0)
            meta.pages = [firstPage]
            meta.activePageId = firstPage.id
        }

        activate(HeiBanDocument(board: meta, objects: []))
        scheduleAutosave()
    }

    // MARK: - Multi-page Notebook Support (多頁筆記本支援)
    public var isNotebook: Bool {
        board.canvasMode == .notebook
    }

    public var pages: [BoardPage] {
        get { board.pages ?? [] }
        set { board.pages = newValue }
    }

    public var activePageId: String? {
        get {
            guard isNotebook else { return nil }
            if let active = board.activePageId, pages.contains(where: { $0.id == active }) {
                return active
            }
            return pages.first?.id
        }
        set {
            board.activePageId = newValue
        }
    }

    public var currentPageIndex: Int {
        guard isNotebook, let activeId = activePageId else { return 0 }
        return pages.firstIndex(where: { $0.id == activeId }) ?? 0
    }

    public var totalPages: Int {
        guard isNotebook else { return 1 }
        return max(1, pages.count)
    }

    public func isObjectOnCurrentPage(_ object: BoardObject) -> Bool {
        guard isNotebook else { return true }
        guard let currentId = activePageId else { return true }
        if let pid = object.pageId {
            return pid == currentId
        } else {
            // Downward compatibility: objects without pageId belong to page 1
            return currentId == pages.first?.id
        }
    }

    public var currentPageObjects: [BoardObject] {
        guard isNotebook else { return objects }
        return objects.filter { isObjectOnCurrentPage($0) }
    }

    @discardableResult
    public func addPage(title: String? = nil) -> BoardPage {
        cancelTransientInteraction()
        selectedIds.removeAll()

        var currentPages = pages
        if currentPages.isEmpty {
            let p1 = BoardPage(id: UUID().uuidString, title: "第 1 頁", index: 0)
            currentPages.append(p1)
        }

        let newIndex = currentPages.count
        let rawTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageTitle = (rawTitle != nil && !rawTitle!.isEmpty) ? rawTitle! : "第 \(newIndex + 1) 頁"
        let newPage = BoardPage(id: UUID().uuidString, title: pageTitle, index: newIndex)
        currentPages.append(newPage)

        let beforeBoard = board
        var afterBoard = board
        afterBoard.pages = currentPages
        afterBoard.activePageId = newPage.id
        board = afterBoard

        transactionManager.push(.updateCanvas(before: beforeBoard, after: afterBoard))
        scheduleAutosave()
        showTemporaryStatus("已新增 \(newPage.title)")
        return newPage
    }

    @discardableResult
    public func deletePage(id: String) -> Bool {
        guard isNotebook else { return false }
        guard pages.count > 1 else {
            showTemporaryStatus("筆記本至少需保留一頁")
            return false
        }
        guard let pageIndex = pages.firstIndex(where: { $0.id == id }) else { return false }

        cancelTransientInteraction()
        selectedIds.removeAll()

        let beforeBoard = board
        let objectsToDelete = objects.filter { $0.pageId == id }

        var newPages = pages
        let deletedTitle = newPages[pageIndex].title
        newPages.remove(at: pageIndex)
        for i in newPages.indices {
            newPages[i].index = i
        }

        var afterBoard = board
        afterBoard.pages = newPages

        if activePageId == id {
            let nextIndex = min(pageIndex, newPages.count - 1)
            afterBoard.activePageId = newPages[nextIndex].id
        }

        if !objectsToDelete.isEmpty {
            let idsToDelete = Set(objectsToDelete.map(\.id))
            objects.removeAll { idsToDelete.contains($0.id) }
        }
        board = afterBoard

        if !objectsToDelete.isEmpty {
            transactionManager.push(.composite([
                .removeObjects(objectsToDelete),
                .updateCanvas(before: beforeBoard, after: afterBoard)
            ]))
        } else {
            transactionManager.push(.updateCanvas(before: beforeBoard, after: afterBoard))
        }

        scheduleAutosave()
        showTemporaryStatus("已刪除 \(deletedTitle)")
        return true
    }

    public func switchPage(to pageId: String) {
        guard isNotebook, activePageId != pageId else { return }
        guard pages.contains(where: { $0.id == pageId }) else { return }
        cancelTransientInteraction()
        selectedIds.removeAll()
        board.activePageId = pageId
    }

    public func goToNextPage() {
        guard isNotebook else { return }
        let nextIdx = currentPageIndex + 1
        guard nextIdx < pages.count else { return }
        switchPage(to: pages[nextIdx].id)
    }

    public func goToPreviousPage() {
        guard isNotebook else { return }
        let prevIdx = currentPageIndex - 1
        guard prevIdx >= 0 else { return }
        switchPage(to: pages[prevIdx].id)
    }


    public func duplicateLibraryBoard(_ id: String) {
        guard saveBeforeLeaving() else { return }
        do {
            var document = try Self.library.load(id: id)
            document.board.id = UUID().uuidString
            document.board.title += " 副本"
            for index in document.objects.indices { document.objects[index].boardId = document.board.id }
            try Self.autosaveQueue.sync { try Self.library.save(document) }
            refreshLibrary()
        } catch { showTemporaryStatus("複製失敗：\(error.localizedDescription)") }
    }

    public func renameLibraryBoard(_ id: String, title: String) {
        guard saveBeforeLeaving() else { return }
        do {
            var document = try Self.library.load(id: id)
            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            document.board.title = cleaned
            try Self.autosaveQueue.sync { try Self.library.save(document) }
            if board.id == id { board.title = cleaned }
            refreshLibrary()
        } catch { showTemporaryStatus("重新命名失敗：\(error.localizedDescription)") }
    }

    public func deleteLibraryBoards(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        do {
            for id in ids { try Self.library.delete(id: id) }
            if ids.contains(board.id) && !showingHome {
                cancelTransientInteraction()
                showingHome = true
            }
            refreshLibrary()
            showTemporaryStatus("已刪除 \(ids.count) 張黑板")
        } catch {
            showTemporaryStatus("刪除黑板失敗：\(error.localizedDescription)")
        }
    }

    private func activate(_ document: HeiBanDocument) {
        cancelTransientInteraction()
        transactionManager.clear()
        board = document.board
        objects = document.objects.sorted { $0.zIndex < $1.zIndex }
        selectedIds.removeAll()
        viewport = ViewportTransform(x: 200, y: 150, zoom: 1)
        showingHome = false
    }

    // MARK: - Undo / Redo & History (A04)
    public var canUndo: Bool { transactionManager.canUndo }
    public var canRedo: Bool { transactionManager.canRedo }

    public func clearHistory() {
        transactionManager.clear()
    }

    public func updatePanGesture(translation: CGSize) {
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
        viewport.x += delta.width
        viewport.y += delta.height
    }

    public func updateRulerDrag(translation: CGSize) {
        ruler.screenCenterX += translation.width - previousRulerTranslation.width
        ruler.screenCenterY += translation.height - previousRulerTranslation.height
        previousRulerTranslation = translation
    }

    public func updateRulerDrag(start: Point, current: Point) {
        if rulerDragStart != start {
            rulerDragStart = start
            rulerCenterAtDragStart = CGPoint(x: ruler.screenCenterX, y: ruler.screenCenterY)
        }
        ruler.screenCenterX = Double(rulerCenterAtDragStart.x) + current.x - start.x
        ruler.screenCenterY = Double(rulerCenterAtDragStart.y) + current.y - start.y
    }

    public func endRulerDrag() {
        previousRulerTranslation = .zero
        rulerDragStart = nil
    }

    public func updateToolbarDrag(translation: CGSize) {
        toolbarOffset.width += translation.width - previousToolbarTranslation.width
        toolbarOffset.height += translation.height - previousToolbarTranslation.height
        previousToolbarTranslation = translation
    }

    public func endToolbarDrag() {
        previousToolbarTranslation = .zero
        let anchorX = toolbarDock == "left" ? 46.0 : toolbarDock == "right" ? canvasSize.width - 46 : canvasSize.width / 2
        let anchorY = toolbarDock == "top" ? 106.0 : toolbarDock == "bottom" ? canvasSize.height - 48 : canvasSize.height / 2
        let x = anchorX + toolbarOffset.width
        let y = anchorY + toolbarOffset.height
        let distances: [(String, Double)] = [
            ("left", abs(x)),
            ("right", abs(canvasSize.width - x)),
            ("top", abs(y - 64)),
            ("bottom", abs(canvasSize.height - y))
        ]
        if let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 < 110 {
            toolbarDock = nearest.0
            toolbarOffset = .zero
        } else {
            toolbarDock = "floating"
        }
        UserDefaults.standard.set(toolbarDock, forKey: "HeiBan.toolbarDock")
        UserDefaults.standard.set([toolbarOffset.width, toolbarOffset.height], forKey: "HeiBan.toolbarOffset")
    }

    public func toolbarPosition(in windowSize: CGSize) -> CGPoint {
        let base: CGPoint
        switch toolbarDock {
        case "left":
            base = CGPoint(x: 46.0, y: windowSize.height / 2)
        case "right":
            base = CGPoint(x: windowSize.width - 46.0, y: windowSize.height / 2)
        case "top":
            base = CGPoint(x: windowSize.width / 2, y: 106.0)
        case "bottom":
            base = CGPoint(x: windowSize.width / 2, y: windowSize.height - 48.0)
        default: // floating
            base = CGPoint(x: windowSize.width / 2, y: windowSize.height - 48.0)
        }
        let posX = base.x + toolbarOffset.width
        let posY = base.y + toolbarOffset.height
        return clampPanelCenter(CGPoint(x: posX, y: posY),
                                panelSize: CGSize(width: isToolbarVertical ? 64 : 420, height: isToolbarVertical ? 420 : 64),
                                windowSize: windowSize,
                                margin: 4.0)
    }

    public func clampPanelCenter(_ center: CGPoint, panelSize: CGSize, windowSize: CGSize, margin: Double = 0.0) -> CGPoint {
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

    public func updateCurrentToolStyle(color: String? = nil, strokeWidth: Double? = nil, opacity: Double? = nil) {
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
            penPreset = ToolStylePreset(color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .highlighter:
            highlighterPreset = ToolStylePreset(color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .paint:
            paintPreset = ToolStylePreset(color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        default:
            penPreset = ToolStylePreset(color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
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
        ruler.angle = newAngle * 180 / .pi
        ruler.screenCenterX = oldPivot.x - pivotLocalX * cos(newAngle) + pivotLocalY * sin(newAngle)
        ruler.screenCenterY = oldPivot.y - pivotLocalX * sin(newAngle) - pivotLocalY * cos(newAngle)
    }

    /// Resets virtual ruler pivot to default center (W15, A13).
    public func resetRulerPivot() {
        ruler.pivotRatio = 0.5
        ruler.pivotEdge = "center"
    }

    /// Ensures virtual ruler stays reachable within visible window after resize (W15, A13).
    public func repositionRulerIfNeeded(windowSize: CGSize) {
        guard windowSize.width > 100 && windowSize.height > 100 else { return }
        let margin: Double = 60.0
        let minX = margin
        let maxX = max(margin, Double(windowSize.width) - margin)
        let minY = margin
        let maxY = max(margin, Double(windowSize.height) - margin)
        ruler.screenCenterX = min(max(ruler.screenCenterX, minX), maxX)
        ruler.screenCenterY = min(max(ruler.screenCenterY, minY), maxY)
    }

    public func handleScrollWheel(at screenPoint: Point, deltaX: Double, deltaY: Double, shift: Bool) {
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
        let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        if strokePreview.lineEndpoint?.objectID != objectID || strokePreview.lineEndpoint?.endpoint != endpoint {
            strokePreview.lineEndpoint = LineEndpointPreview(objectID: objectID, endpoint: endpoint, point: worldPoint)
        } else {
            strokePreview.lineEndpoint?.point = worldPoint
        }
    }

    public func endLineEndpointDrag() {
        guard let preview = strokePreview.lineEndpoint,
              let index = objects.firstIndex(where: { $0.id == preview.objectID }) else { return }
        var updated = objects[index]
        let previousX = preview.endpoint == .start ? updated.x1 ?? updated.x : updated.x2 ?? updated.x + updated.width
        let previousY = preview.endpoint == .start ? updated.y1 ?? updated.y : updated.y2 ?? updated.y + updated.height
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
              ["triangle", "quadrilateral", "curve"].contains(objects[objectIndex].type) else { return }
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
            polygonDraftCursorPoint = nil
            return
        }
        polygonDraftCursorPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
    }

    public func endPolygonVertexDrag(objectID: String) {
        guard let before = polygonDragBefore.removeValue(forKey: objectID),
              let after = objects.first(where: { $0.id == objectID }) else { return }
        guard before != after else { return }
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }

    public var isPointerGestureActive: Bool { pointerGesture != .idle }

    public func beginPointerGesture(at screenPoint: Point, isShift: Bool = false, clickCount: Int = 1) {
        guard pointerGesture == .idle else { return }
        pointerGestureStart = screenPoint
        self.isShiftHeld = isShift

        if isHoldingSpace {
            pointerGesture = .pan
            return
        }

        if currentTool == .select {
            let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)

            if clickCount >= 2,
               let textObject = currentPageObjects.reversed().first(where: {
                   ($0.type == "text" || $0.type == "sticky") && $0.isVisible != false && $0.isLocked != true &&
                   VectorMath.isPointNearObject(point: worldPoint, object: $0, threshold: 8 / viewport.zoom)
               }) {
                beginEditingText(object: textObject)
                return
            }

            // 1. Check if user clicked on any transform handle of the current selection!
            if let selBounds = selectionBoundingBox,
               let handle = VectorMath.hitTestHandle(point: worldPoint, bounds: selBounds, zoom: viewport.zoom) {
                pointerGesture = .transformSelection(handle)
                activeTransformHandle = handle
                initialTransformBounds = selBounds
                initialTransformObjects = objects.filter { selectedIds.contains($0.id) }
                initialRotationCenter = CGPoint(x: selBounds.midX, y: selBounds.midY)
                initialRotationAngle = atan2(worldPoint.y - Double(selBounds.midY), worldPoint.x - Double(selBounds.midX)) * 180.0 / Double.pi
                return
            }

            // 2. Check if user hit an object on canvas
            if let hit = currentPageObjects.reversed().first(where: {
                $0.isVisible != false && $0.isLocked != true &&
                VectorMath.isPointNearObject(point: worldPoint, object: $0, threshold: 8 / viewport.zoom)
            }) {
                if isShiftHeld {
                    toggleObjectSelection(id: hit.id)
                    pointerGesture = .idle
                    return
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

        if currentTool == .pen || currentTool == .curve || currentTool == .highlighter || currentTool == .paint {
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
            beginInlineTextEntry(at: VectorMath.screenToWorld(screenPoint, viewport: viewport), kind: currentTool)
        }
    }

    public func updatePointerGesture(at screenPoint: Point, translation: CGSize, isShift: Bool = false) {
        self.isShiftHeld = isShift
        switch pointerGesture {
        case .idle:
            break
        case .pan:
            updatePanGesture(translation: translation)
        case .moveSelection:
            strokePreview.selectionOffset = translation
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
                let currentAngle = atan2(worldPoint.y - Double(center.y), worldPoint.x - Double(center.x)) * 180.0 / Double.pi
                let delta = currentAngle - initialRotationAngle
                for initial in initialTransformObjects {
                    let rotated = VectorMath.rotateObject(object: initial, around: center, deltaDegrees: delta)
                    if let idx = objects.firstIndex(where: { $0.id == rotated.id }) {
                        objects[idx] = rotated
                    }
                }
            } else {
                let newBounds = computeTransformedBounds(handle: handle, origBounds: origBounds, currentPoint: worldPoint, preserveAspect: isShiftHeld)
                for initial in initialTransformObjects {
                    let scaled = VectorMath.transformObject(object: initial, from: origBounds, to: newBounds, preserveAspectRatio: isShiftHeld)
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
        switch pointerGesture {
        case .idle, .pan, .textEntry, .polygon:
            break
        case .erasing:
            endEraserSwipe()
        case .moveSelection:
            let dx = translation.width / viewport.zoom
            let dy = translation.height / viewport.zoom
            if (dx != 0 || dy != 0), !selectedIds.isEmpty {
                let before = objects.filter { selectedIds.contains($0.id) }
                var after: [BoardObject] = []
                objects = objects.map { object in
                    guard selectedIds.contains(object.id) else { return object }
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
                transactionManager.push(.modifyObjects(before: before, after: after))
                scheduleAutosave()
            }
            strokePreview.selectionOffset = .zero
        case .marqueeSelection:
            if let rect = marqueeRect {
                selectObjectsInBox(rect: rect, isShiftPressed: isShiftHeld)
            }
            marqueeRect = nil
        case .transformSelection:
            if let _ = initialTransformBounds, !initialTransformObjects.isEmpty {
                let after = objects.filter { selectedIds.contains($0.id) }
                transactionManager.push(.modifyObjects(before: initialTransformObjects, after: after))
                scheduleAutosave()
            }
            activeTransformHandle = nil
            initialTransformBounds = nil
            initialTransformObjects = []
            initialRotationCenter = nil
        case .stroke:
            endStroke()
        case .shape:
            if let object = strokePreview.shapeObject,
               max(object.width, object.height) >= 3 {
                appendInZOrder(object)
                selectedIds = [object.id]
                transactionManager.push(.insertObjects([object]))
                scheduleAutosave()
                currentTool = .select
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
    }

    /// Selects a tool. If the specified tool is already active, toggles back to .select (A05, A11).
    public func selectTool(_ tool: ToolType) {
        if !polygonDraftPoints.isEmpty {
            polygonDraftPoints.removeAll()
            polygonDraftCursorPoint = nil
        }

        // 1. Save current tool preset
        switch currentTool {
        case .pen:
            penPreset = ToolStylePreset(color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .highlighter:
            highlighterPreset = ToolStylePreset(color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
        case .paint:
            paintPreset = ToolStylePreset(color: activeColor, strokeWidth: activeStrokeWidth, opacity: activeOpacity)
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
    }

    /// Cleans up modifier states and transient gestures when window loses focus (A11).
    public func handleWindowBlur() {
        isHoldingSpace = false
        isShiftHeld = false
        if pointerGesture == .pan {
            pointerGesture = .idle
            pointerGestureStart = nil
            previousPanTranslation = .zero
        }
    }

    public func commitTextEntry() {
        let content = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            showTextEditor = false
            textDraft = ""
            currentTool = .select
        }
        guard !content.isEmpty else { return }

        let isSticky = textEntryKind == .sticky
        let object = BoardObject(
            boardId: board.id,
            type: isSticky ? "sticky" : "text",
            x: textEntryPoint.x,
            y: textEntryPoint.y,
            width: isSticky ? 260 : 320,
            height: isSticky ? 200 : 80,
            strokeColor: isSticky ? "#1f2937" : activeColor,
            fillColor: isSticky ? "#fef08a" : "none",
            strokeWidth: 1,
            opacity: activeOpacity,
            zIndex: objects.count + 1,
            text: content,
            fontSize: isSticky ? 16 : 24
        )
        addObject(object)
        selectedIds = [object.id]
    }

    public func cancelTextEntry() {
        showTextEditor = false
        textDraft = ""
        currentTool = .select
    }

    // MARK: - Native inline text editing (A15)
    public func beginInlineTextEntry(at point: Point, kind: ToolType) {
        guard kind == .text || kind == .sticky else { return }
        if kind == .sticky {
            let sticky = BoardObject(
                boardId: board.id,
                type: "sticky",
                x: point.x,
                y: point.y,
                width: 260,
                height: 210,
                strokeColor: "#1f2937",
                fillColor: StickyPalette.yellow,
                strokeWidth: 1,
                zIndex: (objects.map(\.zIndex).max() ?? 0) + 1,
                text: "",
                fontSize: 16,
                fontFamily: "PingFang TC",
                stickyStyle: .classic
            )
            addObject(sticky)
            selectedIds = [sticky.id]
            beginEditingText(object: sticky)
            return
        }
        showTextEditor = false
        showInlineTextEditor = true
        editingTextObjectId = nil
        originalTextObject = nil
        textEntryKind = kind
        textEntryPoint = point
        inlineTextPoint = point
        textDraft = ""
        editingRichTextSpans = []
        editingFontFamily = "PingFang TC"
        editingFontSize = kind == .sticky ? 16 : 24
        editingTextAlign = "left"
        editingTextColor = kind == .sticky ? "#1f2937" : activeColor
        editingTextOpacity = activeOpacity
        currentTool = .select
    }

    public func beginEditingText(object: BoardObject) {
        guard object.type == "text" || object.type == "sticky" else { return }
        showTextEditor = false
        showInlineTextEditor = true
        editingTextObjectId = object.id
        originalTextObject = object
        textEntryKind = object.type
        textEntryPoint = Point(x: object.x, y: object.y)
        inlineTextPoint = textEntryPoint
        textDraft = object.text ?? ""
        editingRichTextSpans = object.richTextSpans ?? []
        editingFontFamily = object.fontFamily ?? "PingFang TC"
        editingFontSize = object.fontSize ?? (object.type == "sticky" ? 16 : 24)
        editingTextAlign = object.align ?? "left"
        editingTextColor = object.strokeColor
        editingTextOpacity = object.opacity
        selectedIds = [object.id]
    }

    public func commitInlineTextEntry() {
        let content = textDraft
        defer {
            showInlineTextEditor = false
            textDraft = ""
            editingTextObjectId = nil
            originalTextObject = nil
            editingRichTextSpans = []
            currentTool = .select
        }

        if let original = originalTextObject, let index = objects.firstIndex(where: { $0.id == original.id }) {
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if original.type == "sticky" {
                    var updated = original
                    updated.text = ""
                    if let index = objects.firstIndex(where: { $0.id == original.id }) { objects[index] = updated }
                    transactionManager.push(.modifyObjects(before: [original], after: [updated]))
                    scheduleAutosave()
                    return
                }
                // Emptying an existing text item follows the same undoable delete semantics as other edits.
                objects.remove(at: index)
                selectedIds.remove(original.id)
                transactionManager.push(.removeObjects([original]))
                scheduleAutosave()
                return
            }
            var updated = original
            updated.text = content
            updated.richTextSpans = normalizedRichTextSpans(editingRichTextSpans, plainText: content)
            updated.fontFamily = editingFontFamily
            updated.fontSize = editingFontSize
            updated.align = editingTextAlign
            updated.strokeColor = editingTextColor
            updated.opacity = editingTextOpacity
            updated.updatedAt = ISO8601DateFormatter().string(from: Date())
            guard updated != original else { return }
            objects[index] = updated
            transactionManager.push(.modifyObjects(before: [original], after: [updated]))
            scheduleAutosave()
            return
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let isSticky = textEntryKind == .sticky
        let object = BoardObject(
            boardId: board.id,
            type: isSticky ? "sticky" : "text",
            x: textEntryPoint.x,
            y: textEntryPoint.y,
            width: isSticky ? 260 : 320,
            height: isSticky ? 200 : 100,
            strokeColor: editingTextColor,
            fillColor: isSticky ? "#fef08a" : "none",
            strokeWidth: 1,
            opacity: editingTextOpacity,
            zIndex: objects.count + 1,
            text: content,
            fontSize: editingFontSize,
            fontFamily: editingFontFamily,
            align: editingTextAlign,
            richTextSpans: normalizedRichTextSpans(editingRichTextSpans, plainText: content)
        )
        addObject(object)
        selectedIds = [object.id]
    }

    public func cancelInlineTextEntry() {
        showInlineTextEditor = false
        textDraft = ""
        editingTextObjectId = nil
        originalTextObject = nil
        editingRichTextSpans = []
        currentTool = .select
    }

    public func requestInlineTextFormat(_ action: String) {
        guard ["bold", "italic", "underline", "strikethrough", "highlight"].contains(action) || action.hasPrefix("color:#") else { return }
        inlineTextFormatAction = action
        inlineTextFormatRevision &+= 1
    }

    public func updateObjectRichText(id: String, spans: [TextSpan]) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
              objects[index].type == "text" || objects[index].type == "sticky" else { return }
        let before = objects[index]
        var updated = before
        let filtered = spans.filter { !$0.text.isEmpty }
        updated.richTextSpans = filtered.isEmpty ? nil : filtered
        if !filtered.isEmpty {
            updated.text = filtered.map(\.text).joined()
        }
        guard updated != before else { return }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [before], after: [updated]))
        scheduleAutosave()
    }

    public func updateObjectTypography(id: String, fontFamily: String?, fontSize: Double?, align: String?) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
              objects[index].type == "text" || objects[index].type == "sticky" else { return }
        let before = objects[index]
        var updated = before
        if let fontFamily { updated.fontFamily = fontFamily }
        if let fontSize { updated.fontSize = max(8, min(144, fontSize)) }
        if let align, ["left", "center", "right"].contains(align) { updated.align = align }
        guard updated != before else { return }
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [before], after: [updated]))
        scheduleAutosave()
    }

    private func normalizedRichTextSpans(_ spans: [TextSpan], plainText: String) -> [TextSpan]? {
        guard !spans.isEmpty else { return nil }
        let filtered = spans.filter { !$0.text.isEmpty }
        guard !filtered.isEmpty else { return nil }
        let joined = filtered.map(\.text).joined()
        return joined == plainText ? filtered : [TextSpan(text: plainText)]
    }

    private func isShapeTool(_ tool: ToolType) -> Bool {
        [ToolType.rect, .circle, .diamond, .star, .line, .arrow].contains(tool)
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
        currentTool = .select
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
            fillColor: "none",
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
        let line = currentTool == .line || currentTool == .arrow

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
            strokeColor: activeColor,
            fillColor: "none",
            strokeWidth: activeStrokeWidth,
            lineStyle: activeLineStyle,
            opacity: activeOpacity,
            zIndex: objects.count + 1
        )
    }

    private static func translatedPointsJSON(_ json: String, dx: Double, dy: Double) -> String? {
        guard let data = json.data(using: .utf8),
              var points = try? JSONDecoder().decode([Point].self, from: data) else { return nil }
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

    // MARK: - Selected Object Properties & Mixed Values (A07)
    public var selectedObjects: [BoardObject] {
        objects.filter { selectedIds.contains($0.id) }
    }

    public var selectedStrokeColor: PropertyValue<String> {
        let colors = Set(selectedObjects.map(\.strokeColor))
        if colors.isEmpty { return .none }
        if colors.count == 1, let val = colors.first { return .value(val) }
        return .mixed
    }

    public var selectedFillColor: PropertyValue<String> {
        let colors = Set(selectedObjects.map(\.fillColor))
        if colors.isEmpty { return .none }
        if colors.count == 1, let val = colors.first { return .value(val) }
        return .mixed
    }

    public var selectedStrokeWidth: PropertyValue<Double> {
        let widths = Set(selectedObjects.map(\.strokeWidth))
        if widths.isEmpty { return .none }
        if widths.count == 1, let val = widths.first { return .value(val) }
        return .mixed
    }

    public var selectedOpacity: PropertyValue<Double> {
        let ops = Set(selectedObjects.map(\.opacity))
        if ops.isEmpty { return .none }
        if ops.count == 1, let val = ops.first { return .value(val) }
        return .mixed
    }

    public var selectedLineStyle: PropertyValue<String> {
        let styles = Set(selectedObjects.compactMap { $0.lineStyle ?? "solid" })
        if styles.isEmpty { return .none }
        if styles.count == 1, let val = styles.first { return .value(val) }
        return .mixed
    }

    public var selectedRotation: PropertyValue<Double> {
        let rots = Set(selectedObjects.map(\.rotation))
        if rots.isEmpty { return .none }
        if rots.count == 1, let val = rots.first { return .value(val) }
        return .mixed
    }

    public var selectedLineExtension: PropertyValue<LineExtension> {
        let lineObjs = selectedObjects.filter { $0.type == "line" || $0.type == "arrow" }
        let exts = Set(lineObjs.map { $0.extensionMode ?? .none })
        if exts.isEmpty { return .none }
        if exts.count == 1, let val = exts.first { return .value(val) }
        return .mixed
    }

    public var selectedArrowHeadLength: PropertyValue<Double> {
        let values = Set(selectedObjects.filter { $0.type == "arrow" }.map { $0.arrowHeadLength ?? 16 })
        if values.isEmpty { return .none }
        if values.count == 1, let value = values.first { return .value(value) }
        return .mixed
    }

    public var selectedArrowHeadWidth: PropertyValue<Double> {
        let values = Set(selectedObjects.filter { $0.type == "arrow" }.map { $0.arrowHeadWidth ?? 10 })
        if values.isEmpty { return .none }
        if values.count == 1, let value = values.first { return .value(value) }
        return .mixed
    }

    public var selectedStickyStyle: PropertyValue<StickyStyle> {
        let styles = Set(selectedObjects.filter { $0.type == "sticky" }.map { $0.stickyStyle ?? .classic })
        if styles.isEmpty { return .none }
        if styles.count == 1, let s = styles.first { return .value(s) }
        return .mixed
    }

    public func setSelectedStickyStyle(_ style: StickyStyle) {
        let stickies = selectedObjects.filter { $0.type == "sticky" && $0.isLocked != true }
        guard !stickies.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in stickies {
            var updated = obj
            updated.stickyStyle = style
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: stickies, after: after))
        scheduleAutosave()
    }

    public func setSelectedStickyColor(_ color: String) {
        setSelectedFillColor(color)
    }

    public func isStickyTextOverflowing(object: BoardObject) -> Bool {
        guard object.type == "sticky", let text = object.text, !text.isEmpty else { return false }
        let padding: Double = 28
        let availWidth = max(20, object.width - padding)
        let availHeight = max(20, object.height - padding)
        let fontSize = object.fontSize ?? 16
        let lineHeight = fontSize * 1.35

        let lines = text.components(separatedBy: "\n")
        var totalLines = 0
        for line in lines {
            if line.isEmpty {
                totalLines += 1
                continue
            }
            var lineWidth: Double = 0
            var lineWrapCount = 1
            for char in line {
                let charWidth: Double = char.isASCII ? fontSize * 0.55 : fontSize * 1.05
                if lineWidth + charWidth > availWidth && lineWidth > 0 {
                    lineWrapCount += 1
                    lineWidth = charWidth
                } else {
                    lineWidth += charWidth
                }
            }
            totalLines += lineWrapCount
        }
        let estimatedContentHeight = Double(totalLines) * lineHeight
        return estimatedContentHeight > availHeight
    }

    public func expandStickyToFit(id: String) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
              objects[index].type == "sticky",
              let text = objects[index].text, !text.isEmpty else { return }
        let before = objects[index]
        let padding: Double = 28
        let availWidth = max(20, before.width - padding)
        let fontSize = before.fontSize ?? 16
        let lineHeight = fontSize * 1.35

        let lines = text.components(separatedBy: "\n")
        var totalLines = 0
        for line in lines {
            if line.isEmpty {
                totalLines += 1
                continue
            }
            var lineWidth: Double = 0
            var lineWrapCount = 1
            for char in line {
                let charWidth: Double = char.isASCII ? fontSize * 0.55 : fontSize * 1.05
                if lineWidth + charWidth > availWidth && lineWidth > 0 {
                    lineWrapCount += 1
                    lineWidth = charWidth
                } else {
                    lineWidth += charWidth
                }
            }
            totalLines += lineWrapCount
        }
        let requiredHeight = ceil(Double(totalLines) * lineHeight + padding + 16)
        guard requiredHeight > before.height else { return }

        var updated = before
        updated.height = requiredHeight
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [before], after: [updated]))
        scheduleAutosave()
    }

    public var selectedGradientStart: String { selectedObjects.first?.fillGradientStart ?? selectedObjects.first?.fillColor ?? "#fde047" }
    public var selectedGradientEnd: String { selectedObjects.first?.fillGradientEnd ?? "#60a5fa" }
    public var selectedGradientEnabled: Bool { selectedObjects.contains { $0.fillGradientStart != nil && $0.fillGradientEnd != nil } }

    public func setSelectedStrokeColor(_ color: String) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in selected {
            var updated = obj
            updated.strokeColor = color
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func setSelectedFillColor(_ color: String) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in selected {
            var updated = obj
            updated.fillColor = color
            updated.fillGradientStart = nil
            updated.fillGradientEnd = nil
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public var selectedFillOpacity: PropertyValue<Double> {
        let values = Set(selectedObjects.filter { ["rect", "circle", "ellipse", "triangle", "quadrilateral", "diamond", "star", "sticky"].contains($0.type) }.map(\.fillOpacity))
        if values.isEmpty { return .none }
        if values.count == 1, let value = values.first { return .value(value) }
        return .mixed
    }

    public func setSelectedFillOpacity(_ opacity: Double) {
        modifySelectedObjects { object in object.fillOpacity = min(1, max(0, opacity)) }
    }

    private func modifySelectedObjects(_ update: (inout BoardObject) -> Void) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for object in selected {
            var changed = object
            update(&changed)
            changed.updatedAt = now
            after.append(changed)
            if let index = objects.firstIndex(where: { $0.id == changed.id }) { objects[index] = changed }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func toggleSelectedGradient() {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let disable = selected.allSatisfy { $0.fillGradientStart != nil && $0.fillGradientEnd != nil }
        setSelectedGradientColors(start: disable ? nil : selectedGradientStart, end: disable ? nil : selectedGradientEnd)
    }

    public func setSelectedGradientColors(start: String?, end: String?) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for object in selected {
            var updated = object
            updated.fillGradientStart = start
            updated.fillGradientEnd = end
            if let start, let end {
                if updated.fillColor == "none" { updated.fillColor = start }
            }
            updated.updatedAt = now
            after.append(updated)
            if let index = objects.firstIndex(where: { $0.id == object.id }) { objects[index] = updated }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func setSelectedStrokeWidth(_ width: Double) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in selected {
            var updated = obj
            updated.strokeWidth = width
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func setSelectedOpacity(_ opacity: Double) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in selected {
            var updated = obj
            updated.opacity = max(0.05, min(1.0, opacity))
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func setSelectedLineStyle(_ style: String) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in selected {
            var updated = obj
            updated.lineStyle = style
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func setSelectedArrowHeadLength(_ value: Double) { modifySelectedArrows { $0.arrowHeadLength = value } }
    public func setSelectedArrowHeadWidth(_ value: Double) { modifySelectedArrows { $0.arrowHeadWidth = value } }

    private func modifySelectedArrows(_ update: (inout BoardObject) -> Void) {
        let selected = selectedObjects.filter { $0.type == "arrow" && $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for object in selected {
            var changed = object
            update(&changed)
            changed.updatedAt = now
            after.append(changed)
            if let index = objects.firstIndex(where: { $0.id == changed.id }) { objects[index] = changed }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func setSelectedRotationAngle(_ degrees: Double) {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in selected {
            var updated = obj
            updated.rotation = degrees.truncatingRemainder(dividingBy: 360.0)
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func setSelectedLineExtension(_ extensionMode: LineExtension) {
        let matching = objects.filter { selectedIds.contains($0.id) && ($0.type == "line" || $0.type == "arrow") && $0.isLocked != true }
        guard matching.contains(where: { $0.extensionMode != extensionMode }) else {
            activeLineExtension = extensionMode
            return
        }
        let before = matching
        var after: [BoardObject] = []
        let now = ISO8601DateFormatter().string(from: Date())
        objects = objects.map { object in
            guard selectedIds.contains(object.id), (object.type == "line" || object.type == "arrow"), object.isLocked != true else { return object }
            var updated = object
            updated.extensionMode = extensionMode
            updated.updatedAt = now
            after.append(updated)
            return updated
        }
        activeLineExtension = extensionMode
        transactionManager.push(.modifyObjects(before: before, after: after))
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

    private func appendInZOrder(_ object: BoardObject) {
        var obj = object
        if isNotebook && obj.pageId == nil {
            obj.pageId = activePageId
        }
        objects.append(obj)
        if objects.count > 1 && objects[objects.count - 2].zIndex > obj.zIndex {
            objects.sort { $0.zIndex < $1.zIndex }
        }
    }

    public private(set) var holdStartScreenPoint: Point?
    private var rulerStrokeEdge: Double?

    public func startStroke(at screenPt: Point) {
        rulerStrokeEdge = nil
        if ruler.enabled {
            let snap = VectorMath.snapToRulerEdge(screenPt: screenPt, ruler: ruler, stopSnappingBeyondEnds: false)
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
            snappedScreen = ruler.enabled ? VectorMath.snapToRulerEdge(screenPt: screenPt, ruler: ruler).screenPt : screenPt
        }
        let worldPt = VectorMath.screenToWorld(snappedScreen, viewport: viewport)
        holdStartScreenPoint = screenPt
        strokePreview.begin(with: worldPt)
    }

    public func appendStrokePoint(at screenPt: Point) {
        guard !strokePreview.points.isEmpty else { return }
        let snappedScreen: Point
        if ruler.enabled, let edge = rulerStrokeEdge {
            snappedScreen = pointProjectedToRulerEdge(screenPt, edge: edge)
        } else {
            snappedScreen = ruler.enabled ? VectorMath.snapToRulerEdge(screenPt: screenPt, ruler: ruler, stopSnappingBeyondEnds: false).screenPt : screenPt
        }
        let worldPt = VectorMath.screenToWorld(snappedScreen, viewport: viewport)
        if let last = strokePreview.points.last,
           hypot(worldPt.x - last.x, worldPt.y - last.y) * viewport.zoom < 0.25 { return }

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
                    strokeWidth: activeStrokeWidth,
                    lineStyle: activeLineStyle,
                    opacity: activeOpacity,
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
                    strokeWidth: activeStrokeWidth,
                    lineStyle: activeLineStyle,
                    opacity: activeOpacity,
                    zIndex: objects.count + 1
                )
            default: // rect
                newObj = BoardObject(
                    boardId: board.id,
                    type: "rect",
                    x: shape.x,
                    y: shape.y,
                    width: shape.width,
                    height: shape.height,
                    strokeColor: activeColor,
                    fillColor: "none",
                    strokeWidth: activeStrokeWidth,
                    lineStyle: activeLineStyle,
                    opacity: activeOpacity,
                    zIndex: objects.count + 1
                )
            }
            appendInZOrder(newObj)
            selectedIds = [newObj.id]
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
            let candidate = sourcePoints.dropFirst().dropLast().max { lhs, rhs in
                abs((end.x - start.x) * (start.y - lhs.y) - (start.x - lhs.x) * (end.y - start.y)) <
                abs((end.x - start.x) * (start.y - rhs.y) - (start.x - rhs.x) * (end.y - start.y))
            } ?? sourcePoints[sourcePoints.count / 2]
            let chordOffset = ((end.x - start.x) * (start.y - candidate.y) - (start.x - candidate.x) * (end.y - start.y)) / chordLength
            let control = Point(x: 2 * candidate.x - (start.x + end.x) / 2, y: 2 * candidate.y - (start.y + end.y) / 2)
            savedPoints = abs(chordOffset) < 0.5 ? [start, candidate, end] : [start, control, end]
        } else {
            savedPoints = sourcePoints
        }
        guard let pointsData = try? JSONEncoder().encode(savedPoints),
              let pointsStr = String(data: pointsData, encoding: .utf8) else {
            return
        }

        let strokeType = currentTool == .curve ? "curve" : (currentTool == .highlighter ? "highlighter" : (currentTool == .paint ? "paint" : "stroke"))
        let opacity = (currentTool == .highlighter) ? activeHighlighterOpacity : activeOpacity
        let strokeWidth: Double
        if currentTool == .highlighter {
            strokeWidth = max(12.0, activeStrokeWidth * 3.5)
        } else if currentTool == .paint {
            strokeWidth = max(24.0, activeStrokeWidth * 8.0)
        } else {
            strokeWidth = activeStrokeWidth
        }

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
            zIndex: objects.count + 1
        )
        appendInZOrder(newObj)
        if currentTool == .curve { selectedIds = [newObj.id] }
        transactionManager.push(.insertObjects([newObj]))
        scheduleAutosave()
        if currentTool == .curve { currentTool = .select }
    }

    public func updateEraserCursor(at point: Point?) { eraserCursorPoint = point }
    public func updateHoverCursor(at point: Point?, diameter: Double?) {
        hoverCursorPoint = point
        hoverCursorDiameter = diameter
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
            isEraserActive: isEraserSwipeActive || pointerGesture == .erasing,
            currentTool: currentTool,
            isNotebook: isNotebook,
            activePageId: activePageId
        )
    }

    // MARK: - Eraser Engine (A04 & A24 & A14)
    public func beginEraserSwipe() {
        isEraserSwipeActive = true
        activeEraserDeletedObjects.removeAll(keepingCapacity: true)
        activeEraserInsertedObjects.removeAll(keepingCapacity: true)
    }

    public func eraseAt(screenPt: Point) {
        let worldPt = VectorMath.screenToWorld(screenPt, viewport: viewport)
        let hitThreshold = max(6.0, (eraserSize / 2.0) / viewport.zoom)

        if eraserMode == .object {
            var newlyDeleted: [BoardObject] = []
            objects.removeAll { obj in
                // A24: Locked and hidden objects must not be erased
                if obj.isLocked == true || obj.isVisible == false { return false }
                if isNotebook && !isObjectOnCurrentPage(obj) { return false }
                guard Self.isEraserEligible(obj.type) else { return false }
                if VectorMath.isPointNearObject(point: worldPt, object: obj, threshold: max(18.0 / viewport.zoom, hitThreshold)) {
                    newlyDeleted.append(obj)
                    return true
                }
                return false
            }

            if !newlyDeleted.isEmpty {
                let delIds = Set(newlyDeleted.map(\.id))
                selectedIds.subtract(delIds)
                activeEraserDeletedObjects.append(contentsOf: newlyDeleted)
                if !isEraserSwipeActive && pointerGesture != .erasing {
                    endEraserSwipe()
                }
            }
        } else {
            // Partial / Vector Splitting mode (W16, A14) via EraserToolEngine
            var toRemoveIds = Set<String>()
            var newlySplitSegments: [BoardObject] = []

            for obj in objects {
                if obj.isLocked == true || obj.isVisible == false { continue }
                if isNotebook && !isObjectOnCurrentPage(obj) { continue }

                if obj.type == "stroke" || obj.type == "highlighter" || obj.type == "paint" || obj.type == "curve" {
                    let segments = EraserToolEngine.sliceStroke(object: obj, eraserCenter: worldPt, eraserRadius: hitThreshold)
                    if segments != [obj] {
                        toRemoveIds.insert(obj.id)
                        if let insIdx = activeEraserInsertedObjects.firstIndex(where: { $0.id == obj.id }) {
                            activeEraserInsertedObjects.remove(at: insIdx)
                        } else {
                            activeEraserDeletedObjects.append(obj)
                        }

                        for segment in segments {
                            newlySplitSegments.append(segment)
                            activeEraserInsertedObjects.append(segment)
                        }
                    }
                }
            }

            if !toRemoveIds.isEmpty || !newlySplitSegments.isEmpty {
                objects.removeAll { toRemoveIds.contains($0.id) }
                selectedIds.subtract(toRemoveIds)
                for seg in newlySplitSegments {
                    appendInZOrder(seg)
                }

                if !isEraserSwipeActive && pointerGesture != .erasing {
                    endEraserSwipe()
                }
            }
        }
    }

    private static func isEraserEligible(_ type: String) -> Bool {
        ["stroke", "pen", "highlighter", "paint", "curve", "rect", "circle", "ellipse", "triangle", "quadrilateral", "diamond", "star", "line", "arrow"].contains(type)
    }

    public func endEraserSwipe() {
        isEraserSwipeActive = false
        var commands: [BoardCommand] = []
        if !activeEraserDeletedObjects.isEmpty {
            commands.append(.removeObjects(activeEraserDeletedObjects))
        }
        if !activeEraserInsertedObjects.isEmpty {
            commands.append(.insertObjects(activeEraserInsertedObjects))
        }

        if commands.count == 1 {
            transactionManager.push(commands[0])
            scheduleAutosave()
        } else if commands.count > 1 {
            transactionManager.push(.composite(commands))
            scheduleAutosave()
        }
        activeEraserDeletedObjects.removeAll(keepingCapacity: true)
        activeEraserInsertedObjects.removeAll(keepingCapacity: true)
    }

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
    public func updateBoardTitle(_ title: String) {
        let prev = board
        var updated = board
        updated.title = title
        board = updated
        transactionManager.push(.updateCanvas(before: prev, after: updated))
        scheduleAutosave()
    }

    public func updateBoardTheme(_ theme: BoardTheme) {
        let prev = board
        var updated = board
        updated.boardTheme = theme
        updated.backgroundColor = theme.defaultBackgroundColor
        board = updated
        transactionManager.push(.updateCanvas(before: prev, after: updated))
        scheduleAutosave()
    }

    public func updateGridStyle(_ grid: GridStyle) {
        let prev = board
        var updated = board
        updated.gridStyle = grid
        board = updated
        transactionManager.push(.updateCanvas(before: prev, after: updated))
        scheduleAutosave()
    }

    // MARK: - Canvas Mode & Dimensions Management (W13, A10)
    public var canDowngradeToFixed: Bool {
        // A10: 固定升級無限保留內容，無限沒有降級操作 (禁止無限降級)
        return board.canvasMode != .infinite
    }

    public func configureCanvas(
        mode: CanvasMode,
        preset: CanvasPreset,
        customWidth: Double? = nil,
        customHeight: Double? = nil
    ) throws {
        // Check for forbidden infinite -> fixed downgrade (A10)
        if (board.canvasMode == .infinite || board.canvasMode == nil) && mode == .fixed {
            throw CanvasError.cannotDowngradeInfiniteCanvas
        }

        let prev = board
        var updated = board
        updated.canvasMode = mode
        updated.canvasPreset = preset

        if mode == .fixed {
            let dims = preset.defaultDimensions()
            let w = customWidth ?? dims?.width ?? 1200.0
            let h = customHeight ?? dims?.height ?? 800.0
            guard w >= 100.0, h >= 100.0 else {
                throw CanvasError.invalidFixedDimensions
            }
            updated.canvasWidth = w
            updated.canvasHeight = h
        } else {
            updated.canvasWidth = nil
            updated.canvasHeight = nil
        }

        board = updated
        transactionManager.push(.updateCanvas(before: prev, after: updated))
        scheduleAutosave()
    }

    public func upgradeToInfiniteCanvas() {
        guard board.canvasMode != .infinite else { return }
        let prev = board
        var updated = board
        updated.canvasMode = .infinite
        updated.canvasPreset = .infinite
        board = updated
        transactionManager.push(.updateCanvas(before: prev, after: updated))
        showTemporaryStatus("已無損升級為無限畫布")
        scheduleAutosave()
    }

    public func resizeFixedCanvas(width: Double, height: Double) throws {
        guard board.canvasMode == .fixed else { return }
        guard width >= 100.0, height >= 100.0 else {
            throw CanvasError.invalidFixedDimensions
        }
        let prev = board
        var updated = board
        updated.canvasWidth = width
        updated.canvasHeight = height
        board = updated
        transactionManager.push(.updateCanvas(before: prev, after: updated))
        scheduleAutosave()
    }

    public func isObjectOutOfBounds(_ object: BoardObject) -> Bool {
        guard board.canvasMode == .fixed,
              let cw = board.canvasWidth, let ch = board.canvasHeight else {
            return false
        }
        let objMaxX = object.x + object.width
        let objMaxY = object.y + object.height
        return object.x < 0 || object.y < 0 || objMaxX > cw || objMaxY > ch
    }

    public func outOfBoundsObjects() -> [BoardObject] {
        guard board.canvasMode == .fixed else { return [] }
        return objects.filter { isObjectOutOfBounds($0) }
    }

    public func fitCanvasToObjects() {
        guard board.canvasMode == .fixed, !objects.isEmpty else { return }
        var maxX = board.canvasWidth ?? 800.0
        var maxY = board.canvasHeight ?? 600.0
        for obj in objects {
            maxX = max(maxX, obj.x + obj.width + 40.0)
            maxY = max(maxY, obj.y + obj.height + 40.0)
        }
        try? resizeFixedCanvas(width: maxX, height: maxY)
    }

    // MARK: - Pin Management (A04 & A17)
    public func addPin(name: String, at worldPoint: Point? = nil) {
        let prevPins = board.pins
        let pinPoint: Point
        if let worldPoint {
            pinPoint = worldPoint
        } else {
            pinPoint = VectorMath.screenToWorld(
                Point(x: Double(canvasSize.width / 2), y: Double(canvasSize.height / 2)),
                viewport: viewport
            )
        }
        let newPin = BoardPin(
            name: name,
            x: pinPoint.x,
            y: pinPoint.y,
            zoom: viewport.zoom,
            isWorldSpace: true
        )
        if board.pins == nil {
            board.pins = []
        }
        board.pins?.append(newPin)
        transactionManager.push(.updatePins(before: prevPins, after: board.pins))
        showTemporaryStatus("已新增實體圖釘：\(name)")
        scheduleAutosave()
    }

    public func removePin(id: String) {
        let prevPins = board.pins
        board.pins?.removeAll { $0.id == id }
        transactionManager.push(.updatePins(before: prevPins, after: board.pins))
        scheduleAutosave()
    }

    public func renamePin(id: String, name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = board.pins?.firstIndex(where: { $0.id == id }) else { return }
        let prevPins = board.pins
        board.pins?[index].name = cleaned
        transactionManager.push(.updatePins(before: prevPins, after: board.pins))
        scheduleAutosave()
    }

    public func updatePinDrag(id: String, at screenPoint: Point) {
        guard let index = board.pins?.firstIndex(where: { $0.id == id }) else { return }
        if pinDragBefore == nil { pinDragBefore = board.pins?[index] }
        let worldPoint = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        board.pins?[index].x = worldPoint.x
        board.pins?[index].y = worldPoint.y
        board.pins?[index].isWorldSpace = true
    }

    public func endPinDrag(id: String) {
        guard let before = pinDragBefore, let after = board.pins?.first(where: { $0.id == id }) else { return }
        pinDragBefore = nil
        guard before != after else { return }
        let beforeList = board.pins?.map { $0.id == id ? before : $0 }
        transactionManager.push(.updatePins(before: beforeList, after: board.pins))
        scheduleAutosave()
    }

    public func targetViewportForPin(_ pin: BoardPin, canvasSize: CGSize, anchorRatio: Point = Point(x: 0.20, y: 0.20)) -> ViewportTransform {
        let worldPos = pin.resolveWorldPosition(canvasSize: canvasSize)
        let targetZoom = pin.zoom
        let anchorScreenX = Double(canvasSize.width) * anchorRatio.x
        let anchorScreenY = Double(canvasSize.height) * anchorRatio.y
        let targetX = anchorScreenX - worldPos.x * targetZoom
        let targetY = anchorScreenY - worldPos.y * targetZoom
        return ViewportTransform(x: targetX, y: targetY, zoom: targetZoom)
    }

    public func migratePinsToWorldSpace(canvasSize: CGSize) {
        guard let pins = board.pins else { return }
        var updated: [BoardPin] = []
        var changed = false
        for var pin in pins {
            if pin.isWorldSpace != true {
                let wp = pin.resolveWorldPosition(canvasSize: canvasSize)
                pin.x = wp.x
                pin.y = wp.y
                pin.isWorldSpace = true
                changed = true
            }
            updated.append(pin)
        }
        if changed {
            board.pins = updated
            scheduleAutosave()
        }
    }

    // MARK: - Layer & Object Ordering Management (A24)

    public func reorderObjects(newOrder: [String]) {
        let prev = objects
        var idMap: [String: BoardObject] = [:]
        for obj in objects { idMap[obj.id] = obj }
        var reordered: [BoardObject] = []
        for (index, id) in newOrder.enumerated() {
            if var obj = idMap[id] {
                obj.zIndex = index + 1
                reordered.append(obj)
            }
        }
        let includedIds = Set(newOrder)
        for var obj in objects where !includedIds.contains(obj.id) {
            obj.zIndex = reordered.count + 1
            reordered.append(obj)
        }
        objects = reordered
        transactionManager.push(.reorderObjects(before: prev, after: objects))
        scheduleAutosave()
    }

    public func bringToFront(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let prev = objects
        let moving = objects.filter { ids.contains($0.id) }
        let rest = objects.filter { !ids.contains($0.id) }
        var updated = rest + moving
        for i in updated.indices { updated[i].zIndex = i + 1 }
        objects = updated
        transactionManager.push(.reorderObjects(before: prev, after: objects))
        scheduleAutosave()
    }

    public func sendToBack(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let prev = objects
        let moving = objects.filter { ids.contains($0.id) }
        let rest = objects.filter { !ids.contains($0.id) }
        var updated = moving + rest
        for i in updated.indices { updated[i].zIndex = i + 1 }
        objects = updated
        transactionManager.push(.reorderObjects(before: prev, after: objects))
        scheduleAutosave()
    }

    public func bringForward(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let prev = objects
        var updated = objects
        for i in stride(from: updated.count - 2, through: 0, by: -1) {
            if ids.contains(updated[i].id) && !ids.contains(updated[i + 1].id) {
                updated.swapAt(i, i + 1)
            }
        }
        for i in updated.indices { updated[i].zIndex = i + 1 }
        objects = updated
        transactionManager.push(.reorderObjects(before: prev, after: objects))
        scheduleAutosave()
    }

    public func sendBackward(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let prev = objects
        var updated = objects
        for i in 1..<updated.count {
            if ids.contains(updated[i].id) && !ids.contains(updated[i - 1].id) {
                updated.swapAt(i, i - 1)
            }
        }
        for i in updated.indices { updated[i].zIndex = i + 1 }
        objects = updated
        transactionManager.push(.reorderObjects(before: prev, after: objects))
        scheduleAutosave()
    }

    public func setObjectLocked(id: String, isLocked: Bool) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let prev = objects[index]
        var updated = prev
        updated.isLocked = isLocked
        objects[index] = updated
        if isLocked {
            selectedIds.remove(id)
        }
        transactionManager.push(.modifyObjects(before: [prev], after: [updated]))
        scheduleAutosave()
    }

    public func toggleLock(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        var before: [BoardObject] = []
        var after: [BoardObject] = []
        let allLocked = ids.allSatisfy { id in objects.first(where: { $0.id == id })?.isLocked == true }
        let newLock = !allLocked
        for i in objects.indices {
            if ids.contains(objects[i].id) {
                before.append(objects[i])
                objects[i].isLocked = newLock
                after.append(objects[i])
            }
        }
        if newLock {
            selectedIds.subtract(ids)
        }
        transactionManager.push(.modifyObjects(before: before, after: after))
        scheduleAutosave()
    }

    public func setObjectVisible(id: String, isVisible: Bool) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let prev = objects[index]
        var updated = prev
        updated.isVisible = isVisible
        objects[index] = updated
        if !isVisible {
            selectedIds.remove(id)
        }
        transactionManager.push(.modifyObjects(before: [prev], after: [updated]))
        scheduleAutosave()
    }

    public func toggleVisibility(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        var before: [BoardObject] = []
        var after: [BoardObject] = []
        let allVisible = ids.allSatisfy { id in objects.first(where: { $0.id == id })?.isVisible != false }
        let newVisible = !allVisible
        for i in objects.indices {
            if ids.contains(objects[i].id) {
                before.append(objects[i])
                objects[i].isVisible = newVisible
                after.append(objects[i])
            }
        }
        if !newVisible {
            selectedIds.subtract(ids)
        }
        transactionManager.push(.modifyObjects(before: before, after: after))
        scheduleAutosave()
    }

    public func setCustomName(id: String, name: String) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let prev = objects[index]
        var updated = prev
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmed.isEmpty ? nil : trimmed
        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [prev], after: [updated]))
        scheduleAutosave()
    }

    public func selectObjectOnCanvas(id: String) {
        guard let obj = objects.first(where: { $0.id == id }) else { return }
        guard obj.isLocked != true, obj.isVisible != false else { return }
        if let gid = obj.groupId, !gid.isEmpty {
            let groupMembers = objects.filter { $0.groupId == gid && $0.isLocked != true && $0.isVisible != false }
            selectedIds = Set(groupMembers.map(\.id))
        } else {
            selectedIds = [id]
        }
    }

    public func toggleObjectSelection(id: String) {
        guard let obj = objects.first(where: { $0.id == id }) else { return }
        guard obj.isLocked != true, obj.isVisible != false else { return }
        let targetIds: Set<String>
        if let gid = obj.groupId, !gid.isEmpty {
            targetIds = Set(objects.filter { $0.groupId == gid && $0.isLocked != true && $0.isVisible != false }.map(\.id))
        } else {
            targetIds = [id]
        }
        if selectedIds.isSuperset(of: targetIds) {
            selectedIds.subtract(targetIds)
        } else {
            selectedIds.formUnion(targetIds)
        }
    }

    public func selectObjectsInBox(rect: CGRect, isShiftPressed: Bool) {
        var matchedIds = Set<String>()
        for obj in currentPageObjects {
            guard obj.isVisible != false, obj.isLocked != true else { continue }
            if VectorMath.objectIntersectsRect(object: obj, rect: rect) {
                if let gid = obj.groupId, !gid.isEmpty {
                    let groupMembers = currentPageObjects.filter { $0.groupId == gid && $0.isLocked != true && $0.isVisible != false }
                    for m in groupMembers { matchedIds.insert(m.id) }
                } else {
                    matchedIds.insert(obj.id)
                }
            }
        }
        if isShiftPressed {
            selectedIds.formUnion(matchedIds)
        } else {
            selectedIds = matchedIds
        }
    }

    public func groupSelected() {
        let selected = objects.filter { selectedIds.contains($0.id) && $0.isVisible != false && $0.isLocked != true }
        guard selected.count >= 2 else { return }
        let newGroupId = "group_" + UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in selected {
            var updated = obj
            updated.groupId = newGroupId
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func ungroupSelected() {
        let selectedGids = Set(objects.filter { selectedIds.contains($0.id) }.compactMap(\.groupId))
        let matching = objects.filter {
            (selectedIds.contains($0.id) || ($0.groupId != nil && selectedGids.contains($0.groupId!))) &&
            $0.groupId != nil && $0.isVisible != false && $0.isLocked != true
        }
        guard !matching.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var after: [BoardObject] = []
        for obj in matching {
            var updated = obj
            updated.groupId = nil
            updated.updatedAt = now
            after.append(updated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = updated
            }
        }
        transactionManager.push(.modifyObjects(before: matching, after: after))
        scheduleAutosave()
    }

    public func copySelected() {
        let selected = objects.filter { selectedIds.contains($0.id) }
        guard !selected.isEmpty else { return }
        internalClipboard = selected
        if let data = try? JSONEncoder().encode(selected),
           let jsonStr = String(data: data, encoding: .utf8) {
            pasteboardService?.copyString(jsonStr)
        }
    }

    public func cutSelected() {
        copySelected()
        deleteSelected()
    }

    public func pasteClipboard(offset: CGPoint = CGPoint(x: 20, y: 20)) {
        var sourceObjects = internalClipboard
        if sourceObjects.isEmpty,
           let clipStr = pasteboardService?.pasteString(),
           let data = clipStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([BoardObject].self, from: data) {
            sourceObjects = decoded
        }
        guard !sourceObjects.isEmpty else { return }

        var groupMap: [String: String] = [:]
        for obj in sourceObjects {
            if let gid = obj.groupId, groupMap[gid] == nil {
                groupMap[gid] = "group_" + UUID().uuidString
            }
        }

        var maxZ = objects.map(\.zIndex).max() ?? 0
        let now = ISO8601DateFormatter().string(from: Date())
        var newObjects: [BoardObject] = []

        for obj in sourceObjects {
            var pasted = obj
            pasted.id = UUID().uuidString
            if let gid = obj.groupId {
                pasted.groupId = groupMap[gid]
            }
            pasted.x += Double(offset.x)
            pasted.y += Double(offset.y)
            if let x1 = pasted.x1 { pasted.x1 = x1 + Double(offset.x) }
            if let y1 = pasted.y1 { pasted.y1 = y1 + Double(offset.y) }
            if let x2 = pasted.x2 { pasted.x2 = x2 + Double(offset.x) }
            if let y2 = pasted.y2 { pasted.y2 = y2 + Double(offset.y) }
            if let pts = pasted.points {
                pasted.points = Self.translatedPointsJSON(pts, dx: Double(offset.x), dy: Double(offset.y))
            }
            maxZ += 1
            pasted.zIndex = maxZ
            pasted.updatedAt = now
            if isNotebook {
                pasted.pageId = activePageId
            }
            newObjects.append(pasted)
        }

        objects.append(contentsOf: newObjects)
        selectedIds = Set(newObjects.map(\.id))
        transactionManager.push(.insertObjects(newObjects))
        scheduleAutosave()
    }

    public func duplicateSelected() {
        guard !selectedIds.isEmpty else { return }
        copySelected()
        pasteClipboard(offset: CGPoint(x: 24, y: 24))
    }

    public func deleteSelected() {
        let toDelete = objects.filter { selectedIds.contains($0.id) && $0.isLocked != true }
        guard !toDelete.isEmpty else { return }
        let toDeleteIds = Set(toDelete.map(\.id))
        objects.removeAll(where: { toDeleteIds.contains($0.id) })
        selectedIds.subtract(toDeleteIds)
        transactionManager.push(.removeObjects(toDelete))
        scheduleAutosave()
    }

    public func scaleSelected(from oldBounds: CGRect, to newBounds: CGRect, preserveAspectRatio: Bool = false) {
        let selected = objects.filter { selectedIds.contains($0.id) && $0.isLocked != true }
        guard !selected.isEmpty, oldBounds.width > 0, oldBounds.height > 0 else { return }
        var after: [BoardObject] = []
        for obj in selected {
            let transformed = VectorMath.transformObject(object: obj, from: oldBounds, to: newBounds, preserveAspectRatio: preserveAspectRatio)
            after.append(transformed)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = transformed
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

    public func rotateSelected(deltaDegrees: Double) {
        let selected = objects.filter { selectedIds.contains($0.id) && $0.isLocked != true }
        guard !selected.isEmpty else { return }
        guard let bounds = VectorMath.selectionBounds(for: selected) else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var after: [BoardObject] = []
        for obj in selected {
            let rotated = VectorMath.rotateObject(object: obj, around: center, deltaDegrees: deltaDegrees)
            after.append(rotated)
            if let idx = objects.firstIndex(where: { $0.id == obj.id }) {
                objects[idx] = rotated
            }
        }
        transactionManager.push(.modifyObjects(before: selected, after: after))
        scheduleAutosave()
    }

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

    public func jumpToPin(_ pin: BoardPin) {
        let target = targetViewportForPin(pin, canvasSize: canvasSize)
        viewport = target
        showTemporaryStatus("已飛至圖釘：\(pin.name)")
    }

    // MARK: - Image Assets, Non-Destructive 8-Way Crop & Multi-Screen Capture (W20, A18, A19)
    public func importImage(data: Data, originalSize: CGSize, fileName: String? = nil) -> BoardObject {
        let base64 = "data:image/png;base64," + data.base64EncodedString()
        let maxDisplayW = 420.0
        let scale = min(1.0, maxDisplayW / max(1.0, Double(originalSize.width)))
        let w = Double(originalSize.width) * scale
        let h = Double(originalSize.height) * scale

        let centerScreen = Point(x: Double(canvasSize.width / 2), y: Double(canvasSize.height / 2))
        let worldCenter = VectorMath.screenToWorld(centerScreen, viewport: viewport)

        let imageObj = BoardObject(
            boardId: board.id,
            type: "image",
            x: worldCenter.x - w / 2,
            y: worldCenter.y - h / 2,
            width: w,
            height: h,
            zIndex: objects.count + 1,
            imageUrl: base64,
            originalWidth: Double(originalSize.width),
            originalHeight: Double(originalSize.height)
        )

        addObject(imageObj)
        selectedIds = [imageObj.id]
        scheduleAutosave()
        return imageObj
    }

    public func isImageCropped(id: String) -> Bool {
        guard let obj = objects.first(where: { $0.id == id }) else { return false }
        return obj.cropWidth != nil && obj.cropHeight != nil
    }

    public func cropImage(id: String, cropRect: CGRect) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let prev = objects[index]
        var updated = prev
        updated.cropX = cropRect.origin.x
        updated.cropY = cropRect.origin.y
        updated.cropWidth = cropRect.width
        updated.cropHeight = cropRect.height

        if let origW = prev.originalWidth, origW > 0 {
            let scale = prev.width / origW
            updated.width = cropRect.width * scale
            updated.height = cropRect.height * scale
        }

        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [prev], after: [updated]))
        scheduleAutosave()
    }

    public func resetImageCrop(id: String) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let prev = objects[index]
        var updated = prev
        updated.cropX = nil
        updated.cropY = nil
        updated.cropWidth = nil
        updated.cropHeight = nil

        if let origW = prev.originalWidth, let origH = prev.originalHeight, origW > 0, origH > 0 {
            let maxDisplayW = 420.0
            let scale = min(1.0, maxDisplayW / origW)
            updated.width = origW * scale
            updated.height = origH * scale
        }

        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [prev], after: [updated]))
        scheduleAutosave()
    }

    public func makeScreenCaptureArguments(mode: ScreenCaptureMode, outputPath: String) -> [String] {
        switch mode {
        case .region:
            return ["-i", outputPath]
        case .display(let idx):
            return ["-D", "\(idx)", outputPath]
        }
    }

    public func handleScreenCaptureResult(exitCode: Int32, tempFileURL: URL?) {
        guard exitCode == 0, let tempFileURL, FileManager.default.fileExists(atPath: tempFileURL.path) else {
            showTemporaryStatus("已取消截圖")
            if let tempFileURL {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
            return
        }

        guard let data = try? Data(contentsOf: tempFileURL),
              let (pixelWidth, pixelHeight) = imageDecoderService?.getImageDimensions(from: data) ?? CoreImageDecoder.getDimensions(from: data) else {
            showTemporaryStatus("載入截圖失敗")
            try? FileManager.default.removeItem(at: tempFileURL)
            return
        }

        _ = importImage(data: data, originalSize: CGSize(width: pixelWidth, height: pixelHeight))
        try? FileManager.default.removeItem(at: tempFileURL)
        showTemporaryStatus("已將螢幕截圖置入黑板！")
    }

    public func computeRetinaLogicalSize(pixelWidth: Double, pixelHeight: Double, backingScale: Double) -> CGSize {
        let scale = max(1.0, backingScale)
        return CGSize(width: pixelWidth / scale, height: pixelHeight / scale)
    }

    public func captureScreen(mode: ScreenCaptureMode = .region) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("screencapture_\(UUID().uuidString).png")

        showTemporaryStatus(mode == .region ? "請框選螢幕截圖區域..." : "擷取顯示器中...")
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = self.makeScreenCaptureArguments(mode: mode, outputPath: tempURL.path)
            try? task.run()
            task.waitUntilExit()

            DispatchQueue.main.async {
                self.handleScreenCaptureResult(exitCode: task.terminationStatus, tempFileURL: tempURL)
            }
        }
    }

    public func captureScreenAndPaste() {
        captureScreen(mode: .region)
    }

    public func pasteImageFromClipboard() {
        guard let (data, width, height) = pasteboardService?.pasteImageData() else {
            showTemporaryStatus("剪貼簿無可用圖片")
            return
        }

        _ = importImage(data: data, originalSize: CGSize(width: width, height: height))
        showTemporaryStatus("已將剪貼簿圖片置入黑板！")
    }

    /// Import local image files as editable image objects on the current board.
    /// The original bytes are embedded in the board document so saving the board
    /// preserves the imported image without a separate asset folder.
    public func importImageFromFilePrompt() {
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        dialogService.runOpenPanel(allowedExtensions: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff"], allowsMultiple: true) { [weak self] urls in
            guard let self = self, let urls = urls, !urls.isEmpty else { return }

            let centerScreen = Point(x: Double(self.canvasSize.width / 2), y: Double(self.canvasSize.height / 2))
            let worldCenter = VectorMath.screenToWorld(centerScreen, viewport: self.viewport)
            var imported: [BoardObject] = []
            var failures: [String] = []

            for (index, url) in urls.enumerated() {
                do {
                    let data = try Data(contentsOf: url)
                    guard let (pixelWidth, pixelHeight) = self.imageDecoderService?.getImageDimensions(from: data) ?? CoreImageDecoder.getDimensions(from: data),
                          pixelWidth > 0, pixelHeight > 0 else {
                        failures.append(url.lastPathComponent)
                        continue
                    }

                    let maxDisplayWidth = 420.0
                    let scale = min(1.0, maxDisplayWidth / pixelWidth)
                    let width = pixelWidth * scale
                    let height = pixelHeight * scale
                    let offset = Double(index) * 28
                    let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                    let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"

                    let object = BoardObject(
                        boardId: self.board.id,
                        type: "image",
                        x: worldCenter.x - width / 2 + offset,
                        y: worldCenter.y - height / 2 + offset,
                        width: width,
                        height: height,
                        zIndex: self.objects.count + imported.count + 1,
                        imageUrl: dataURL,
                        originalImageUrl: dataURL,
                        originalWidth: pixelWidth,
                        originalHeight: pixelHeight,
                        cropX: 0,
                        cropY: 0,
                        cropWidth: pixelWidth,
                        cropHeight: pixelHeight,
                        name: url.lastPathComponent
                    )
                    imported.append(object)
                } catch {
                    failures.append(url.lastPathComponent)
                }
            }

            guard !imported.isEmpty else {
                self.showTemporaryStatus(failures.isEmpty ? "沒有匯入圖片" : "無法讀取圖片：\(failures.joined(separator: "、"))")
                return
            }

            imported.forEach(self.addObject)
            self.selectedIds = Set(imported.map(\.id))
            self.scheduleAutosave()
            let suffix = failures.isEmpty ? "" : "；\(failures.count) 個檔案無法讀取"
            self.showTemporaryStatus("已匯入 \(imported.count) 張圖片，可直接選取、移動並隨白板儲存\(suffix)")
        }
    }

    public func insertDroppedImage(_ data: Data, filename: String, at screenPoint: Point) {
        guard let (pixelWidth, pixelHeight) = imageDecoderService?.getImageDimensions(from: data) ?? CoreImageDecoder.getDimensions(from: data),
              pixelWidth > 0, pixelHeight > 0 else {
            showTemporaryStatus("無法讀取拖入的圖片")
            return
        }
        let scale = min(1.0, 420.0 / pixelWidth)
        let width = pixelWidth * scale
        let height = pixelHeight * scale
        let world = VectorMath.screenToWorld(screenPoint, viewport: viewport)
        let mimeType = UTType(filenameExtension: URL(fileURLWithPath: filename).pathExtension)?.preferredMIMEType ?? "image/png"
        let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"
        let object = BoardObject(
            boardId: board.id,
            type: "image",
            x: world.x - width / 2,
            y: world.y - height / 2,
            width: width,
            height: height,
            zIndex: (objects.map(\.zIndex).max() ?? 0) + 1,
            imageUrl: dataURL,
            originalImageUrl: dataURL,
            originalWidth: pixelWidth,
            originalHeight: pixelHeight,
            name: filename
        )
        addObject(object)
        selectedIds = [object.id]
        showTemporaryStatus("已將 \(filename) 放入畫布")
    }

    // MARK: - Save and Load (.blackboard.json)
    public func exportToJsonData() throws -> Data {
        let doc = HeiBanDocument(
            schemaVersion: "1.0.0",
            version: "1.0",
            board: board,
            objects: objects
        )
        return try HeiBanDocumentCodec.encode(doc, prettyPrinted: true)
    }

    public func loadFromJsonData(_ data: Data) throws {
        let doc = try HeiBanDocumentCodec.decode(from: data)
        guard saveBeforeLeaving() else { return }
        activate(doc)
        scheduleAutosave()
        showTemporaryStatus("成功載入黑板檔案：\(doc.board.title)")
    }

    public func loadShowcaseBoard() {
        guard saveBeforeLeaving() else { return }
        if let doc = FeatureShowcaseDocument.makeDocument() {
            activate(doc)
            scheduleAutosave()
            showTemporaryStatus("已載入功能示範黑板")
        } else {
            showTemporaryStatus("載入示範黑板失敗")
        }
    }

    public func save(to url: URL) throws {
        let data = try exportToJsonData()
        try data.write(to: url)
    }

    public func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try loadFromJsonData(data)
    }

    public func saveToFilePrompt() {
        let cleanTitle = board.title.replacingOccurrences(of: "/", with: "_")
        let defaultName = "\(cleanTitle).blackboard.json"

        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        dialogService.runSavePanel(defaultName: defaultName, allowedExtensions: ["blackboard.json", "json"]) { [weak self] url in
            guard let self = self, let url = url else { return }
            do {
                try self.save(to: url)
                self.showTemporaryStatus("已儲存黑板至檔案")
            } catch {
                self.showTemporaryStatus("儲存失敗: \(error.localizedDescription)")
            }
        }
    }

    public func openFromFilePrompt() {
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        dialogService.runOpenPanel(allowedExtensions: ["blackboard.json", "json", "heiban"], allowsMultiple: false) { [weak self] urls in
            guard let self = self, let url = urls?.first else { return }
            do {
                try self.load(from: url)
            } catch {
                self.showTemporaryStatus("載入失敗: \(error.localizedDescription)")
            }
        }
    }

    public func exportHTMLPrompt() {
        let defaultName = "\(board.title.isEmpty ? "黑板" : board.title).html"
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        let exporter = BoardExporter(document: document)
        let htmlStr: String
        do {
            htmlStr = try exporter.exportHTML(scope: .allObjects, selectedIds: selectedIds)
        } catch {
            showTemporaryStatus("匯出 HTML 失敗：\(error.localizedDescription)")
            return
        }

        dialogService.runSavePanel(defaultName: defaultName, allowedExtensions: ["html"]) { [weak self] url in
            guard let self = self, let url = url else { return }
            do {
                try htmlStr.write(to: url, atomically: true, encoding: .utf8)
                self.showTemporaryStatus("已匯出 HTML 離線網頁檔")
            } catch {
                self.showTemporaryStatus("儲存 HTML 失敗：\(error.localizedDescription)")
            }
        }
    }

    public func exportSVGPrompt() {
        let defaultName = "\(board.title.isEmpty ? "黑板" : board.title).svg"
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        let exporter = BoardExporter(document: document)
        let svgStr: String
        do {
            svgStr = try exporter.exportSVG(scope: .allObjects, selectedIds: selectedIds)
        } catch {
            showTemporaryStatus("匯出 SVG 失敗：\(error.localizedDescription)")
            return
        }

        dialogService.runSavePanel(defaultName: defaultName, allowedExtensions: ["svg"]) { [weak self] url in
            guard let self = self, let url = url else { return }
            do {
                try svgStr.write(to: url, atomically: true, encoding: .utf8)
                self.showTemporaryStatus("已匯出 SVG 向量圖")
            } catch {
                self.showTemporaryStatus("儲存 SVG 失敗：\(error.localizedDescription)")
            }
        }
    }

    public func exportPDFPrompt() {
        let defaultName = "\(board.title.isEmpty ? "黑板" : board.title).pdf"
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        let exporter = BoardExporter(document: document)
        let pdfData: Data
        do {
            pdfData = try exporter.exportPDF(scope: .allObjects, selectedIds: selectedIds)
        } catch {
            showTemporaryStatus("匯出 PDF 失敗：\(error.localizedDescription)")
            return
        }

        dialogService.runSavePanel(defaultName: defaultName, allowedExtensions: ["pdf"]) { [weak self] url in
            guard let self = self, let url = url else { return }
            do {
                try pdfData.write(to: url)
                self.showTemporaryStatus("已匯出 PDF 文件")
            } catch {
                self.showTemporaryStatus("儲存 PDF 失敗：\(error.localizedDescription)")
            }
        }
    }

    public func exportPNGPrompt() {
        let defaultName = "\(board.title.isEmpty ? "黑板" : board.title).png"
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        let exporter = BoardExporter(document: document)
        let pngData: Data
        do {
            pngData = try exporter.exportPNG(scope: .allObjects, selectedIds: selectedIds, scale: 2.0)
        } catch {
            showTemporaryStatus("匯出 PNG 失敗：\(error.localizedDescription)")
            return
        }

        dialogService.runSavePanel(defaultName: defaultName, allowedExtensions: ["png"]) { [weak self] url in
            guard let self = self, let url = url else { return }
            do {
                try pngData.write(to: url)
                self.showTemporaryStatus("已匯出 PNG 高清圖")
            } catch {
                self.showTemporaryStatus("儲存 PNG 失敗：\(error.localizedDescription)")
            }
        }
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

