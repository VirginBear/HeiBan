import Foundation
import CoreGraphics

public enum SelectionQuickBarPlacement: Equatable, Sendable {
    case above
    case below
}

public struct SelectionQuickActionBarState: Equatable, Sendable {
    public let isVisible: Bool
    public let placement: SelectionQuickBarPlacement
    public let center: Point
    public let selectedCount: Int
    public let allowsColor: Bool
    public let allowsStrokeWidth: Bool
    public let allowsFill: Bool
    public let allowsLock: Bool
    public let isLocked: Bool

    public init(
        isVisible: Bool,
        placement: SelectionQuickBarPlacement,
        center: Point,
        selectedCount: Int,
        allowsColor: Bool,
        allowsStrokeWidth: Bool,
        allowsFill: Bool,
        allowsLock: Bool,
        isLocked: Bool
    ) {
        self.isVisible = isVisible
        self.placement = placement
        self.center = center
        self.selectedCount = selectedCount
        self.allowsColor = allowsColor
        self.allowsStrokeWidth = allowsStrokeWidth
        self.allowsFill = allowsFill
        self.allowsLock = allowsLock
        self.isLocked = isLocked
    }
}

public enum SelectionQuickActionCoordinator {
    public static func computeState(
        selectedObjects: [BoardObject],
        bounds: Rect?,
        viewport: ViewportTransform,
        canvasSize: CGSize,
        barSize: CGSize = CGSize(width: 220, height: 36),
        topMargin: CGFloat = 64
    ) -> SelectionQuickActionBarState {
        guard !selectedObjects.isEmpty, let bounds = bounds else {
            return SelectionQuickActionBarState(
                isVisible: false,
                placement: .above,
                center: Point(x: 0, y: 0),
                selectedCount: 0,
                allowsColor: false,
                allowsStrokeWidth: false,
                allowsFill: false,
                allowsLock: false,
                isLocked: false
            )
        }

        let screenOrigin = VectorMath.worldToScreen(Point(x: bounds.minX, y: bounds.minY), viewport: viewport)
        let screenW = bounds.width * viewport.zoom
        let screenH = bounds.height * viewport.zoom
        let screenRect = CGRect(x: screenOrigin.x, y: screenOrigin.y, width: screenW, height: screenH)

        let placement: SelectionQuickBarPlacement
        let centerY: CGFloat
        // 旋轉點在包圍框上方 25 pt，快速列底緣再留 12 pt；不覆蓋命中區。
        let handleClearance: CGFloat = 42
        if screenRect.minY - barSize.height - handleClearance >= topMargin {
            placement = .above
            centerY = screenRect.minY - barSize.height / 2 - handleClearance
        } else {
            placement = .below
            centerY = min(canvasSize.height - barSize.height / 2 - 12, screenRect.maxY + barSize.height / 2 + 8)
        }

        let minX = barSize.width / 2 + 16
        let maxX = max(minX, canvasSize.width - barSize.width / 2 - 16)
        let clampedX = min(max(screenRect.midX, minX), maxX)

        let editable = selectedObjects.allSatisfy { $0.isLocked != true }
        let strokeTypes: Set<String> = ["stroke", "pen", "highlighter", "paint", "curve", "arc",
                                        "rect", "circle", "triangle", "quadrilateral", "diamond", "star", "polygon", "pentagon", "rounded_rect", "ellipse", "line", "arrow"]
        let colorTypes = strokeTypes.union(["text", "sticky"])
        let fillTypes: Set<String> = ["rect", "circle", "triangle", "quadrilateral", "diamond", "star", "polygon", "pentagon", "rounded_rect", "ellipse", "sticky"]
        let allowsColor = editable && selectedObjects.allSatisfy { colorTypes.contains($0.type) }
        let allowsStrokeWidth = editable && selectedObjects.allSatisfy { strokeTypes.contains($0.type) }
        let allowsFill = editable && selectedObjects.allSatisfy { fillTypes.contains($0.type) }
        let allLocked = selectedObjects.allSatisfy { $0.isLocked == true }

        return SelectionQuickActionBarState(
            isVisible: true,
            placement: placement,
            center: Point(x: Double(clampedX),
                          y: Double(min(max(barSize.height / 2 + 12, centerY),
                                        max(barSize.height / 2 + 12, canvasSize.height - barSize.height / 2 - 12)))),
            selectedCount: selectedObjects.count,
            allowsColor: allowsColor,
            allowsStrokeWidth: allowsStrokeWidth,
            allowsFill: allowsFill,
            allowsLock: true,
            isLocked: allLocked
        )
    }
}
