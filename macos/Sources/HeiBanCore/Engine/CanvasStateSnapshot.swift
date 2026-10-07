import Foundation

public struct HoverPreviewSnapshot: Equatable {
    public var position: Point?
    public var radius: Double
    public var cursorShape: TransformCursorType?
    public var tool: ToolType

    public init(
        position: Point? = nil,
        radius: Double = 0,
        cursorShape: TransformCursorType? = nil,
        tool: ToolType = .select
    ) {
        self.position = position
        self.radius = radius
        self.cursorShape = cursorShape
        self.tool = tool
    }
}

public struct CanvasStateSnapshot: Equatable {
    public var selectedObjectIds: Set<String>
    public var selectionBounds: Rect?
    public var selectionRotation: Double
    public var activeTransformHandle: TransformHandle?
    public var hoverPreview: HoverPreviewSnapshot
    public var rulerState: RulerState
    public var isEraserActive: Bool
    public var currentTool: ToolType
    public var isNotebook: Bool
    public var activePageId: String?

    public var hasActiveSelection: Bool {
        !selectedObjectIds.isEmpty && selectionBounds != nil
    }

    public init(
        selectedObjectIds: Set<String> = [],
        selectionBounds: Rect? = nil,
        selectionRotation: Double = 0.0,
        activeTransformHandle: TransformHandle? = nil,
        hoverPreview: HoverPreviewSnapshot = HoverPreviewSnapshot(),
        rulerState: RulerState = RulerState(),
        isEraserActive: Bool = false,
        currentTool: ToolType = .select,
        isNotebook: Bool = false,
        activePageId: String? = nil
    ) {
        self.selectedObjectIds = selectedObjectIds
        self.selectionBounds = selectionBounds
        self.selectionRotation = selectionRotation
        self.activeTransformHandle = activeTransformHandle
        self.hoverPreview = hoverPreview
        self.rulerState = rulerState
        self.isEraserActive = isEraserActive
        self.currentTool = currentTool
        self.isNotebook = isNotebook
        self.activePageId = activePageId
    }
}
