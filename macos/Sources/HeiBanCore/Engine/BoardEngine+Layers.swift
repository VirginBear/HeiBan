import CoreGraphics
import Foundation

/// 物件圖層、群組、選取與剪貼簿操作；幾何、歷史與儲存沿用同一份作品資料。
extension BoardEngine {
    /// 圖層列表由上往下代表前景到背景。拖曳只在放下時呼叫，一次復原整個排序。
    public func moveLayer(id: String, relativeTo targetID: String, above: Bool) {
        // 非法重複 ID 不能交給既有 reorderObjects 的 ID map，否則可能覆蓋物件。
        guard Set(objects.map(\.id)).count == objects.count else {
            statusMessage = "作品含有重複物件識別碼，無法拖曳排序。請保留原稿。"
            return
        }
        let pageObjects = currentPageObjects.enumerated().sorted {
            $0.element.zIndex == $1.element.zIndex ? $0.offset < $1.offset : $0.element.zIndex < $1.element.zIndex
        }.map(\.element)
        guard id != targetID,
              let source = pageObjects.first(where: { $0.id == id }), source.isLocked != true,
              pageObjects.contains(where: { $0.id == targetID }) else { return }
        var pageIDs = pageObjects.map(\.id)
        let previousIDs = pageIDs
        pageIDs.removeAll { $0 == id }
        guard let index = pageIDs.firstIndex(of: targetID) else { return }
        pageIDs.insert(id, at: index + (above ? 1 : 0))
        guard pageIDs != previousIDs else { return }

        // 當頁 ID 只替換全文件排序中的當頁槽位，不把其他頁物件當成遺漏資料追加。
        let pageIDSet = Set(pageIDs)
        var iterator = pageIDs.makeIterator()
        let ordered = objects.enumerated().sorted {
            $0.element.zIndex == $1.element.zIndex ? $0.offset < $1.offset : $0.element.zIndex < $1.element.zIndex
        }.map(\.element)
        let allIDs = ordered.map { pageIDSet.contains($0.id) ? (iterator.next() ?? $0.id) : $0.id }
        reorderObjects(newOrder: allIDs)
    }

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

    public func bringSelectedToFront() {
        bringToFront(ids: selectedIds)
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

    public func sendSelectedToBack() {
        sendToBack(ids: selectedIds)
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

    public func toggleSelectedLock() {
        toggleLock(ids: selectedIds)
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
            let groupMembers = objects.filter {
                $0.groupId == gid && $0.isLocked != true && $0.isVisible != false
            }
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
            targetIds = Set(
                objects.filter { $0.groupId == gid && $0.isLocked != true && $0.isVisible != false }.map(\.id)
            )
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
                    let groupMembers = currentPageObjects.filter {
                        $0.groupId == gid && $0.isLocked != true && $0.isVisible != false
                    }
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
        let selected = objects.filter {
            selectedIds.contains($0.id) && $0.isVisible != false && $0.isLocked != true
        }
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
            (selectedIds.contains($0.id) || ($0.groupId != nil && selectedGids.contains($0.groupId!)))
                && $0.groupId != nil && $0.isVisible != false && $0.isLocked != true
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
            let jsonStr = String(data: data, encoding: .utf8)
        {
            pasteboardService?.copyString(jsonStr)
        }
    }

    public func copySelectionAsImage() {
        guard let bounds = selectionBoundingBox, bounds.width > 0, bounds.height > 0 else { return }
        showTemporaryStatus("已截取選取內容")
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
            let decoded = try? JSONDecoder().decode([BoardObject].self, from: data)
        {
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
        detachDeletedObjectsFromConnectors(deletedIds: toDeleteIds)
        selectedIds.subtract(toDeleteIds)
        transactionManager.push(.removeObjects(toDelete))
        scheduleAutosave()
    }

    public func scaleSelected(from oldBounds: CGRect, to newBounds: CGRect, preserveAspectRatio: Bool = false)
    {
        let selected = objects.filter { selectedIds.contains($0.id) && $0.isLocked != true }
        guard !selected.isEmpty, oldBounds.width > 0, oldBounds.height > 0 else { return }
        var after: [BoardObject] = []
        for obj in selected {
            let transformed = VectorMath.transformObject(
                object: obj, from: oldBounds, to: newBounds, preserveAspectRatio: preserveAspectRatio)
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
}
