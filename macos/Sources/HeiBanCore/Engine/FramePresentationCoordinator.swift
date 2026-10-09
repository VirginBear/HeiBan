import Foundation
import CoreGraphics

/// Coordinator for AGM-11: Canvas Frames and Presentation Mode
public final class FramePresentationCoordinator {
    
    /// Finds objects on the canvas that are geographically inside the frame.
    /// Excludes other frames to avoid recursive nesting.
    public static func findContainedObjects(frame: BoardObject, in objects: [BoardObject]) -> [String] {
        guard frame.type == "frame" else { return [] }
        let frameRect = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
        
        var containedIds: [String] = []
        for obj in objects {
            // Cannot contain self or another frame
            if obj.id == frame.id || obj.type == "frame" { continue }
            
            // Check bounding box overlap / containment
            let objRect = CGRect(x: obj.x, y: obj.y, width: max(1, obj.width), height: max(1, obj.height))
            let center = CGPoint(x: objRect.midX, y: objRect.midY)
            
            if frameRect.contains(center) || frameRect.contains(objRect) {
                containedIds.append(obj.id)
            }
        }
        return containedIds
    }
    
    /// Translates a frame and all of its associated child objects by the given delta.
    public static func moveFrame(
        frameId: String,
        delta: CGSize,
        objects: [BoardObject]
    ) -> [BoardObject] {
        guard let frame = objects.first(where: { $0.id == frameId && $0.type == "frame" }) else {
            return objects
        }
        
        let childIdSet = Set(frame.childIds ?? [])
        let targetsToMove = childIdSet.union([frameId])
        
        return objects.map { obj in
            guard targetsToMove.contains(obj.id) else { return obj }
            var moved = obj
            moved.x += Double(delta.width)
            moved.y += Double(delta.height)
            
            if let x1 = moved.x1, let y1 = moved.y1 {
                moved.x1 = x1 + Double(delta.width)
                moved.y1 = y1 + Double(delta.height)
            }
            if let x2 = moved.x2, let y2 = moved.y2 {
                moved.x2 = x2 + Double(delta.width)
                moved.y2 = y2 + Double(delta.height)
            }
            
            // If stroke points are present, offset points as well
            if let ptsStr = moved.points, !ptsStr.isEmpty,
               let ptsData = ptsStr.data(using: .utf8),
               var pts = try? JSONDecoder().decode([Point].self, from: ptsData) {
                for i in 0..<pts.count {
                    pts[i].x += Double(delta.width)
                    pts[i].y += Double(delta.height)
                }
                if let encoded = try? JSONEncoder().encode(pts),
                   let newPtsStr = String(data: encoded, encoding: .utf8) {
                    moved.points = newPtsStr
                }
            }
            moved.updatedAt = ISO8601DateFormatter().string(from: Date())
            return moved
        }
    }
    
    /// Deep-duplicates a frame and all of its associated child objects with remapped IDs.
    public static func duplicateFrame(
        frameId: String,
        delta: CGSize = CGSize(width: 40, height: 40),
        in objects: [BoardObject]
    ) -> (newFrame: BoardObject, newChildren: [BoardObject])? {
        guard let frame = objects.first(where: { $0.id == frameId && $0.type == "frame" }) else {
            return nil
        }
        
        let childIds = frame.childIds ?? []
        let children = objects.filter { childIds.contains($0.id) && $0.id != frameId && $0.type != "frame" }
        
        var idMapping: [String: String] = [:]
        var duplicatedChildren: [BoardObject] = []
        
        for child in children {
            let newId = UUID().uuidString
            idMapping[child.id] = newId
            
            var dup = child
            dup.id = newId
            dup.x += Double(delta.width)
            dup.y += Double(delta.height)
            if let x1 = dup.x1, let y1 = dup.y1 {
                dup.x1 = x1 + Double(delta.width)
                dup.y1 = y1 + Double(delta.height)
            }
            if let x2 = dup.x2, let y2 = dup.y2 {
                dup.x2 = x2 + Double(delta.width)
                dup.y2 = y2 + Double(delta.height)
            }
            
            if let ptsStr = dup.points, !ptsStr.isEmpty,
               let ptsData = ptsStr.data(using: .utf8),
               var pts = try? JSONDecoder().decode([Point].self, from: ptsData) {
                for i in 0..<pts.count {
                    pts[i].x += Double(delta.width)
                    pts[i].y += Double(delta.height)
                }
                if let encoded = try? JSONEncoder().encode(pts),
                   let newPtsStr = String(data: encoded, encoding: .utf8) {
                    dup.points = newPtsStr
                }
            }
            dup.updatedAt = ISO8601DateFormatter().string(from: Date())
            duplicatedChildren.append(dup)
        }
        
        var newFrame = frame
        newFrame.id = UUID().uuidString
        newFrame.x += Double(delta.width)
        newFrame.y += Double(delta.height)
        newFrame.childIds = duplicatedChildren.map { $0.id }
        if let title = frame.frameTitle {
            newFrame.frameTitle = "\(title) 副本"
        }
        newFrame.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        return (newFrame, duplicatedChildren)
    }
    
    /// Filters and orders frames for presentation slideshow.
    public static func orderedFrames(from objects: [BoardObject]) -> [BoardObject] {
        return objects
            .filter { $0.type == "frame" }
            .sorted { a, b in
                if a.zIndex != b.zIndex {
                    return a.zIndex < b.zIndex
                }
                if abs(a.y - b.y) > 20 {
                    return a.y < b.y
                }
                return a.x < b.x
            }
    }
    
    /// Computes the optimal ViewportTransform to frame an object centered on screen.
    public static func fitViewport(
        for frame: BoardObject,
        canvasSize: CGSize,
        padding: Double = 60.0
    ) -> ViewportTransform {
        let availableW = max(100.0, Double(canvasSize.width) - padding * 2.0)
        let availableH = max(100.0, Double(canvasSize.height) - padding * 2.0)
        
        let targetZoomW = availableW / max(10.0, frame.width)
        let targetZoomH = availableH / max(10.0, frame.height)
        let zoom = max(0.1, min(4.0, min(targetZoomW, targetZoomH)))
        
        let frameCenterX = frame.x + frame.width / 2.0
        let frameCenterY = frame.y + frame.height / 2.0
        
        let targetX = Double(canvasSize.width / 2.0) - frameCenterX * zoom
        let targetY = Double(canvasSize.height / 2.0) - frameCenterY * zoom
        
        return ViewportTransform(x: targetX, y: targetY, zoom: zoom)
    }
    
    public static func nextFrameIndex(currentIndex: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(currentIndex + 1, total - 1)
    }
    
    public static func prevFrameIndex(currentIndex: Int) -> Int {
        return max(currentIndex - 1, 0)
    }
}
