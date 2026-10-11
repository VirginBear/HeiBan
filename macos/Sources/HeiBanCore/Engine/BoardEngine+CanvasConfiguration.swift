import CoreGraphics
import Foundation

/// 畫布尺寸、背景與圖釘的永久資料；圖釘位置使用世界座標，只有呈現時換算到螢幕。
extension BoardEngine {
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

    public func updateBoardBackgroundColor(_ color: String) {
        guard board.backgroundColor != color else { return }
        let before = board
        board.backgroundColor = color
        transactionManager.push(.updateCanvas(before: before, after: board))
        scheduleAutosave()
    }

    public func updateGridColor(_ color: String?) {
        guard board.gridColor != color else { return }
        let before = board
        board.gridColor = color
        transactionManager.push(.updateCanvas(before: before, after: board))
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
            let cw = board.canvasWidth, let ch = board.canvasHeight
        else {
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

    public func updatePinColor(id: String, color: String?, textColor: String?) {
        guard let index = board.pins?.firstIndex(where: { $0.id == id }) else { return }
        let current = board.pins![index]
        if current.color == color && current.textColor == textColor {
            return
        }
        let prevPins = board.pins
        board.pins?[index].color = color
        board.pins?[index].textColor = textColor
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
        guard let before = pinDragBefore, let after = board.pins?.first(where: { $0.id == id }) else {
            return
        }
        pinDragBefore = nil
        guard before != after else { return }
        let beforeList = board.pins?.map { $0.id == id ? before : $0 }
        transactionManager.push(.updatePins(before: beforeList, after: board.pins))
        scheduleAutosave()
    }

    public func targetViewportForPin(
        _ pin: BoardPin, canvasSize: CGSize, anchorRatio: Point = Point(x: 0.20, y: 0.20)
    ) -> ViewportTransform {
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
}
