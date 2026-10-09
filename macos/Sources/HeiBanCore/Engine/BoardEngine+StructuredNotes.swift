import Foundation
import CoreGraphics

extension BoardEngine {
    
    // MARK: - AGM-11: Frames & Presentation Mode
    
    @discardableResult
    public func insertFrame(
        title: String = "畫框",
        at origin: Point = Point(x: 100, y: 100),
        size: CGSize = CGSize(width: 800, height: 600)
    ) -> BoardObject {
        let frameObj = BoardObject(
            type: "frame",
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height,
            strokeColor: "#94a3b8",
            fillColor: "#0f172a",
            fillOpacity: 0.15,
            strokeWidth: 2.0,
            frameTitle: title,
            childIds: []
        )
        
        // Scan initial contained children
        var updatedFrame = frameObj
        let contained = FramePresentationCoordinator.findContainedObjects(frame: updatedFrame, in: objects)
        updatedFrame.childIds = contained
        
        objects.append(updatedFrame)
        selectedIds = [updatedFrame.id]
        transactionManager.push(.insertObjects([updatedFrame]))
        scheduleAutosave()
        return updatedFrame
    }
    
    public func captureFrameChildren(frameId: String) {
        guard let idx = objects.firstIndex(where: { $0.id == frameId && $0.type == "frame" }) else { return }
        let before = objects[idx]
        let contained = FramePresentationCoordinator.findContainedObjects(frame: before, in: objects)
        var after = before
        after.childIds = contained
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    public func moveFrame(frameId: String, delta: CGSize) {
        guard let frame = objects.first(where: { $0.id == frameId && $0.type == "frame" }) else { return }
        let childIds = Set(frame.childIds ?? [])
        let targets = childIds.union([frameId])
        let before = objects.filter { targets.contains($0.id) }
        
        let newObjects = FramePresentationCoordinator.moveFrame(frameId: frameId, delta: delta, objects: objects)
        let after = newObjects.filter { targets.contains($0.id) }
        
        self.objects = newObjects
        transactionManager.push(.modifyObjects(before: before, after: after))
        scheduleAutosave()
    }
    
    @discardableResult
    public func duplicateFrame(
        frameId: String,
        delta: CGSize = CGSize(width: 40, height: 40)
    ) -> BoardObject? {
        guard let result = FramePresentationCoordinator.duplicateFrame(frameId: frameId, delta: delta, in: objects) else {
            return nil
        }
        var toInsert = [result.newFrame]
        toInsert.append(contentsOf: result.newChildren)
        
        objects.append(contentsOf: toInsert)
        selectedIds = [result.newFrame.id]
        transactionManager.push(.insertObjects(toInsert))
        scheduleAutosave()
        return result.newFrame
    }
    
    @discardableResult
    public func startPresentation(canvasSize: CGSize) -> Bool {
        let frames = FramePresentationCoordinator.orderedFrames(from: objects)
        guard !frames.isEmpty else { return false }
        
        presentationFrames = frames
        currentPresentationIndex = 0
        isPresentationModeActive = true
        
        let targetViewport = FramePresentationCoordinator.fitViewport(
            for: frames[0],
            canvasSize: canvasSize
        )
        self.viewport = targetViewport
        return true
    }
    
    public func exitPresentation() {
        isPresentationModeActive = false
        presentationFrames.removeAll()
        currentPresentationIndex = 0
    }
    
    public func nextPresentationFrame(canvasSize: CGSize) {
        guard isPresentationModeActive, !presentationFrames.isEmpty else { return }
        let nextIdx = FramePresentationCoordinator.nextFrameIndex(
            currentIndex: currentPresentationIndex,
            total: presentationFrames.count
        )
        currentPresentationIndex = nextIdx
        let targetViewport = FramePresentationCoordinator.fitViewport(
            for: presentationFrames[nextIdx],
            canvasSize: canvasSize
        )
        self.viewport = targetViewport
    }
    
    public func prevPresentationFrame(canvasSize: CGSize) {
        guard isPresentationModeActive, !presentationFrames.isEmpty else { return }
        let prevIdx = FramePresentationCoordinator.prevFrameIndex(
            currentIndex: currentPresentationIndex
        )
        currentPresentationIndex = prevIdx
        let targetViewport = FramePresentationCoordinator.fitViewport(
            for: presentationFrames[prevIdx],
            canvasSize: canvasSize
        )
        self.viewport = targetViewport
    }
    
    public func jumpToPresentationFrame(index: Int, canvasSize: CGSize) {
        guard isPresentationModeActive, !presentationFrames.isEmpty else { return }
        let clamped = max(0, min(presentationFrames.count - 1, index))
        currentPresentationIndex = clamped
        let targetViewport = FramePresentationCoordinator.fitViewport(
            for: presentationFrames[clamped],
            canvasSize: canvasSize
        )
        self.viewport = targetViewport
    }
    
    // MARK: - AGM-12: Mind Maps
    
    @discardableResult
    public func insertMindMap(
        rootText: String = "核心主題",
        at origin: Point = Point(x: 100, y: 100)
    ) -> BoardObject {
        let mindMapObj = MindMapCoordinator.createDefaultMindMap(rootText: rootText, at: origin)
        objects.append(mindMapObj)
        selectedIds = [mindMapObj.id]
        transactionManager.push(.insertObjects([mindMapObj]))
        scheduleAutosave()
        return mindMapObj
    }
    
    @discardableResult
    public func addMindMapChild(
        mindMapId: String,
        parentNodeId: String,
        text: String = "新節點"
    ) -> String? {
        guard let idx = objects.firstIndex(where: { $0.id == mindMapId && $0.type == "mindmap" }),
              var data = objects[idx].mindMapData else { return nil }
        
        let before = objects[idx]
        guard let newId = MindMapCoordinator.addChildNode(to: parentNodeId, text: text, data: &data) else { return nil }
        
        let bounds = MindMapCoordinator.computeBounds(for: data)
        var after = before
        after.mindMapData = data
        after.width = max(after.width, bounds.width)
        after.height = max(after.height, bounds.height)
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
        return newId
    }
    
    @discardableResult
    public func addMindMapSibling(
        mindMapId: String,
        targetNodeId: String,
        text: String = "新分支"
    ) -> String? {
        guard let idx = objects.firstIndex(where: { $0.id == mindMapId && $0.type == "mindmap" }),
              var data = objects[idx].mindMapData else { return nil }
        
        let before = objects[idx]
        guard let newId = MindMapCoordinator.addSiblingNode(to: targetNodeId, text: text, data: &data) else { return nil }
        
        let bounds = MindMapCoordinator.computeBounds(for: data)
        var after = before
        after.mindMapData = data
        after.width = max(after.width, bounds.width)
        after.height = max(after.height, bounds.height)
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
        return newId
    }
    
    public func deleteMindMapNode(mindMapId: String, nodeId: String) {
        guard let idx = objects.firstIndex(where: { $0.id == mindMapId && $0.type == "mindmap" }),
              var data = objects[idx].mindMapData else { return }
        
        let before = objects[idx]
        MindMapCoordinator.deleteNode(nodeId: nodeId, data: &data)
        
        let bounds = MindMapCoordinator.computeBounds(for: data)
        var after = before
        after.mindMapData = data
        after.width = max(200.0, bounds.width)
        after.height = max(120.0, bounds.height)
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    public func reparentMindMapNode(
        mindMapId: String,
        nodeId: String,
        newParentId: String
    ) throws {
        guard let idx = objects.firstIndex(where: { $0.id == mindMapId && $0.type == "mindmap" }),
              var data = objects[idx].mindMapData else { return }
        
        let before = objects[idx]
        try MindMapCoordinator.reparentNode(nodeId: nodeId, newParentId: newParentId, data: &data)
        
        let bounds = MindMapCoordinator.computeBounds(for: data)
        var after = before
        after.mindMapData = data
        after.width = max(after.width, bounds.width)
        after.height = max(after.height, bounds.height)
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    public func toggleMindMapCollapse(mindMapId: String, nodeId: String) {
        guard let idx = objects.firstIndex(where: { $0.id == mindMapId && $0.type == "mindmap" }),
              var data = objects[idx].mindMapData else { return }
        
        let before = objects[idx]
        MindMapCoordinator.toggleCollapse(nodeId: nodeId, data: &data)
        
        var after = before
        after.mindMapData = data
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    public func updateMindMapNodeText(mindMapId: String, nodeId: String, text: String) {
        guard let idx = objects.firstIndex(where: { $0.id == mindMapId && $0.type == "mindmap" }),
              var data = objects[idx].mindMapData else { return }
        
        let before = objects[idx]
        MindMapCoordinator.updateNodeText(nodeId: nodeId, text: text, data: &data)
        
        var after = before
        after.mindMapData = data
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    // MARK: - AGM-13: Tables
    
    @discardableResult
    public func insertTable(
        rows: Int = 3,
        cols: Int = 3,
        at origin: Point = Point(x: 100, y: 100)
    ) -> BoardObject {
        let tableObj = TableCoordinator.createDefaultTable(rows: rows, cols: cols, at: origin)
        objects.append(tableObj)
        selectedIds = [tableObj.id]
        transactionManager.push(.insertObjects([tableObj]))
        scheduleAutosave()
        return tableObj
    }
    
    public func addTableRow(tableId: String, at index: Int? = nil) {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }),
              var data = objects[idx].tableData else { return }
        
        let before = objects[idx]
        TableCoordinator.addRow(at: index, data: &data)
        let dims = TableCoordinator.computeTotalDimensions(data: data)
        
        var after = before
        after.tableData = data
        after.width = dims.width
        after.height = dims.height
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    @discardableResult
    public func deleteTableRow(tableId: String, at index: Int) -> Bool {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }),
              var data = objects[idx].tableData else { return false }
        
        let before = objects[idx]
        guard TableCoordinator.deleteRow(at: index, data: &data) else { return false }
        let dims = TableCoordinator.computeTotalDimensions(data: data)
        
        var after = before
        after.tableData = data
        after.width = dims.width
        after.height = dims.height
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
        return true
    }
    
    public func addTableColumn(tableId: String, at index: Int? = nil) {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }),
              var data = objects[idx].tableData else { return }
        
        let before = objects[idx]
        TableCoordinator.addColumn(at: index, data: &data)
        let dims = TableCoordinator.computeTotalDimensions(data: data)
        
        var after = before
        after.tableData = data
        after.width = dims.width
        after.height = dims.height
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    @discardableResult
    public func deleteTableColumn(tableId: String, at index: Int) -> Bool {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }),
              var data = objects[idx].tableData else { return false }
        
        let before = objects[idx]
        guard TableCoordinator.deleteColumn(at: index, data: &data) else { return false }
        let dims = TableCoordinator.computeTotalDimensions(data: data)
        
        var after = before
        after.tableData = data
        after.width = dims.width
        after.height = dims.height
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
        return true
    }
    
    public func updateTableCell(tableId: String, row: Int, col: Int, text: String) {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }),
              var data = objects[idx].tableData else { return }
        
        let before = objects[idx]
        TableCoordinator.setCellText(row: row, col: col, text: text, data: &data)
        
        var after = before
        after.tableData = data
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    public func mergeTableCells(tableId: String, fromRow: Int, fromCol: Int, toRow: Int, toCol: Int) {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }),
              var data = objects[idx].tableData else { return }
        
        let before = objects[idx]
        TableCoordinator.mergeCells(fromRow: fromRow, fromCol: fromCol, toRow: toRow, toCol: toCol, data: &data)
        
        var after = before
        after.tableData = data
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    public func unmergeTableCell(tableId: String, row: Int, col: Int) {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }),
              var data = objects[idx].tableData else { return }
        
        let before = objects[idx]
        TableCoordinator.unmergeCell(row: row, col: col, data: &data)
        
        var after = before
        after.tableData = data
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    public func importDelimitedTextToTable(tableId: String, text: String, delimiter: Character = "\t") {
        guard let idx = objects.firstIndex(where: { $0.id == tableId && $0.type == "table" }) else { return }
        let before = objects[idx]
        let data = TableCoordinator.importFromDelimitedText(text, delimiter: delimiter)
        let dims = TableCoordinator.computeTotalDimensions(data: data)
        
        var after = before
        after.tableData = data
        after.width = dims.width
        after.height = dims.height
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
    
    // MARK: - AGM-14: Formulas
    
    @discardableResult
    public func insertFormula(
        latex: String = "\\frac{a}{b}",
        at origin: Point = Point(x: 100, y: 100),
        fontSize: Double = 24.0
    ) -> BoardObject {
        let layoutResult = LaTeXParserEngine.layout(latex: latex, baseFontSize: fontSize)
        let formulaObj = BoardObject(
            type: "formula",
            x: origin.x,
            y: origin.y,
            width: max(40.0, layoutResult.bounds.width),
            height: max(30.0, layoutResult.bounds.height),
            strokeColor: activeColor.isEmpty ? "#ffffff" : activeColor,
            fillColor: "none",
            strokeWidth: 2.0,
            latex: latex,
            formulaFontSize: fontSize
        )
        
        objects.append(formulaObj)
        selectedIds = [formulaObj.id]
        transactionManager.push(.insertObjects([formulaObj]))
        scheduleAutosave()
        return formulaObj
    }
    
    public func updateFormula(id: String, latex: String, fontSize: Double? = nil) {
        guard let idx = objects.firstIndex(where: { $0.id == id && $0.type == "formula" }) else { return }
        let before = objects[idx]
        let baseSize = fontSize ?? before.formulaFontSize ?? 24.0
        let layoutResult = LaTeXParserEngine.layout(latex: latex, baseFontSize: baseSize)
        
        var after = before
        after.latex = latex
        after.formulaFontSize = baseSize
        after.width = max(40.0, layoutResult.bounds.width)
        after.height = max(30.0, layoutResult.bounds.height)
        after.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        objects[idx] = after
        transactionManager.push(.modifyObjects(before: [before], after: [after]))
        scheduleAutosave()
    }
}
