import Foundation
import CoreGraphics

public enum MindMapError: Error, LocalizedError, Equatable {
    case circularHierarchy
    case cannotReparentRoot
    case nodeNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .circularHierarchy:
            return "無法將節點移至其自身或其子節點下（防循環階層保護）"
        case .cannotReparentRoot:
            return "根主題節點無法變更父節點"
        case .nodeNotFound(let id):
            return "找不到指定的導圖節點：\(id)"
        }
    }
}

/// Coordinator for AGM-12: Interactive Mind Maps and Flowcharts
public final class MindMapCoordinator {
    
    /// Creates a fresh default mind map with a root node and two sample branches.
    public static func createDefaultMindMap(
        rootText: String = "核心主題",
        at origin: Point = Point(x: 100, y: 100)
    ) -> BoardObject {
        let rootId = UUID().uuidString
        let child1Id = UUID().uuidString
        let child2Id = UUID().uuidString
        
        let rootNode = MindMapNode(
            id: rootId,
            text: rootText,
            parentId: nil,
            childrenIds: [child1Id, child2Id],
            color: "#6366f1",
            relativeX: 0,
            relativeY: 0
        )
        
        let child1 = MindMapNode(
            id: child1Id,
            text: "分支 1",
            parentId: rootId,
            childrenIds: [],
            color: "#3b82f6",
            relativeX: 180,
            relativeY: -45
        )
        
        let child2 = MindMapNode(
            id: child2Id,
            text: "分支 2",
            parentId: rootId,
            childrenIds: [],
            color: "#10b981",
            relativeX: 180,
            relativeY: 45
        )
        
        var mindMapData = MindMapData(
            rootId: rootId,
            nodes: [
                rootId: rootNode,
                child1Id: child1,
                child2Id: child2
            ],
            theme: "default"
        )
        layoutTree(&mindMapData)
        let bounds = computeBounds(for: mindMapData)
        
        return BoardObject(
            type: "mindmap",
            x: origin.x,
            y: origin.y,
            width: max(320.0, bounds.width),
            height: max(160.0, bounds.height),
            strokeColor: "#6366f1",
            fillColor: "#1e1e2e",
            strokeWidth: 2.0,
            mindMapData: mindMapData
        )
    }
    
    /// Adds a child node under the specified parent.
    @discardableResult
    public static func addChildNode(
        to parentId: String,
        text: String = "新節點",
        data: inout MindMapData
    ) -> String? {
        guard var parent = data.nodes[parentId] else {
            return nil
        }
        
        let newId = UUID().uuidString
        let newNode = MindMapNode(
            id: newId,
            text: text,
            parentId: parentId,
            childrenIds: [],
            color: parent.color ?? "#3b82f6"
        )
        
        parent.childrenIds.append(newId)
        data.nodes[parentId] = parent
        data.nodes[newId] = newNode
        layoutTree(&data)
        return newId
    }
    
    /// Adds a sibling node adjacent to the target node.
    @discardableResult
    public static func addSiblingNode(
        to targetId: String,
        text: String = "新分支",
        data: inout MindMapData
    ) -> String? {
        guard let targetNode = data.nodes[targetId] else {
            return nil
        }
        
        if let parentId = targetNode.parentId {
            return addChildNode(to: parentId, text: text, data: &data)
        } else {
            // Target is root: add child to root
            return addChildNode(to: targetId, text: text, data: &data)
        }
    }
    
    /// Recursively collects all descendant node IDs for a given node.
    public static func collectSubtreeIds(for nodeId: String, in data: MindMapData) -> Set<String> {
        var result: Set<String> = [nodeId]
        guard let node = data.nodes[nodeId] else { return result }
        
        for childId in node.childrenIds {
            result.formUnion(collectSubtreeIds(for: childId, in: data))
        }
        return result
    }
    
    /// Checks whether reparenting would form a circular hierarchy cycle.
    public static func wouldCreateCycle(
        nodeId: String,
        newParentId: String,
        data: MindMapData
    ) -> Bool {
        if nodeId == newParentId { return true }
        let subtree = collectSubtreeIds(for: nodeId, in: data)
        return subtree.contains(newParentId)
    }
    
    /// Reparents a node to a new parent with topological cycle prevention.
    public static func reparentNode(
        nodeId: String,
        newParentId: String,
        data: inout MindMapData
    ) throws {
        if nodeId == data.rootId {
            throw MindMapError.cannotReparentRoot
        }
        if wouldCreateCycle(nodeId: nodeId, newParentId: newParentId, data: data) {
            throw MindMapError.circularHierarchy
        }
        guard var target = data.nodes[nodeId] else {
            throw MindMapError.nodeNotFound(nodeId)
        }
        guard var newParent = data.nodes[newParentId] else {
            throw MindMapError.nodeNotFound(newParentId)
        }
        
        // Remove from old parent
        if let oldParentId = target.parentId,
           var oldParent = data.nodes[oldParentId] {
            oldParent.childrenIds.removeAll { $0 == nodeId }
            data.nodes[oldParentId] = oldParent
        }
        
        // Set new parent
        target.parentId = newParentId
        newParent.childrenIds.append(nodeId)
        data.nodes[nodeId] = target
        data.nodes[newParentId] = newParent
        
        layoutTree(&data)
    }
    
    /// Recursively removes a node and all of its descendants.
    public static func deleteNode(nodeId: String, data: inout MindMapData) {
        if nodeId == data.rootId {
            // Cannot delete root; reset children
            if var root = data.nodes[nodeId] {
                root.childrenIds.removeAll()
                data.nodes = [nodeId: root]
                layoutTree(&data)
            }
            return
        }
        
        let toDelete = collectSubtreeIds(for: nodeId, in: data)
        
        // Remove from parent's childrenIds
        if let target = data.nodes[nodeId],
           let parentId = target.parentId,
           var parent = data.nodes[parentId] {
            parent.childrenIds.removeAll { $0 == nodeId }
            data.nodes[parentId] = parent
        }
        
        for id in toDelete {
            data.nodes.removeValue(forKey: id)
        }
        layoutTree(&data)
    }
    
    /// Toggles the collapsed state of a node.
    public static func toggleCollapse(nodeId: String, data: inout MindMapData) {
        guard var node = data.nodes[nodeId] else { return }
        let current = node.isCollapsed ?? false
        node.isCollapsed = !current
        data.nodes[nodeId] = node
        layoutTree(&data)
    }
    
    /// Updates the text of a node.
    public static func updateNodeText(nodeId: String, text: String, data: inout MindMapData) {
        guard var node = data.nodes[nodeId] else { return }
        node.text = text
        data.nodes[nodeId] = node
        layoutTree(&data)
    }
    
    /// Deep-clones mind map data with completely new unique IDs.
    public static func cloneMindMap(data: MindMapData) -> MindMapData {
        var idMap: [String: String] = [:]
        for (id, _) in data.nodes {
            idMap[id] = UUID().uuidString
        }
        
        let newRootId = idMap[data.rootId] ?? UUID().uuidString
        var clonedNodes: [String: MindMapNode] = [:]
        
        for (oldId, node) in data.nodes {
            let newId = idMap[oldId] ?? UUID().uuidString
            var n = node
            n.id = newId
            if let p = node.parentId {
                n.parentId = idMap[p]
            }
            n.childrenIds = node.childrenIds.compactMap { idMap[$0] }
            clonedNodes[newId] = n
        }
        
        return MindMapData(
            rootId: newRootId,
            nodes: clonedNodes,
            theme: data.theme
        )
    }
    
    /// Automatically computes hierarchical 2D tree layout coordinates for all nodes.
    public static func layoutTree(_ data: inout MindMapData) {
        guard !data.nodes.isEmpty else { return }
        let nodeDict = data.nodes
        guard let root = nodeDict[data.rootId] else { return }
        
        var calculatedPositions: [String: (x: Double, y: Double)] = [:]
        
        func subtreeHeight(nodeId: String) -> Double {
            guard let node = nodeDict[nodeId] else { return 40.0 }
            if (node.isCollapsed == true) || node.childrenIds.isEmpty {
                return 48.0
            }
            var h = 0.0
            for childId in node.childrenIds {
                h += subtreeHeight(nodeId: childId)
            }
            return max(48.0, h)
        }
        
        func place(nodeId: String, x: Double, y: Double) {
            calculatedPositions[nodeId] = (x, y)
            guard let node = nodeDict[nodeId] else { return }
            if node.isCollapsed == true { return }
            
            let totalHeight = subtreeHeight(nodeId: nodeId)
            var currentY = y - totalHeight / 2.0
            
            let horizontalSpacing = 180.0
            for childId in node.childrenIds {
                let childH = subtreeHeight(nodeId: childId)
                let childY = currentY + childH / 2.0
                place(nodeId: childId, x: x + horizontalSpacing, y: childY)
                currentY += childH
            }
        }
        
        place(nodeId: root.id, x: 0, y: 0)
        
        for (id, pos) in calculatedPositions {
            if var n = data.nodes[id] {
                n.relativeX = pos.x
                n.relativeY = pos.y
                data.nodes[id] = n
            }
        }
    }
    
    /// Computes overall bounding box for the entire mind map.
    public static func computeBounds(for data: MindMapData) -> CGSize {
        var minX = 0.0, maxX = 120.0
        var minY = -30.0, maxY = 30.0
        
        for node in data.nodes.values {
            let x = node.relativeX ?? 0.0
            let y = node.relativeY ?? 0.0
            minX = min(minX, x)
            maxX = max(maxX, x + 140.0)
            minY = min(minY, y - 25.0)
            maxY = max(maxY, y + 25.0)
        }
        
        return CGSize(width: max(200.0, maxX - minX + 60.0), height: max(120.0, maxY - minY + 60.0))
    }
}
