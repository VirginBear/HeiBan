import Combine
import CoreGraphics
import Foundation

/// Transient feedback is observed by its own overlay, not by every canvas control.
public final class DrawingAssistState: ObservableObject {
    @Published public var target: Point?
    public init() {}
}

public enum DrawingReferenceGeometry {
    /// World geometry also serves snapping and the board eraser. Existing object data is never rewritten.
    public static func outline(_ item: BoardObject) -> [Point] {
        if ["line", "arrow", "connector"].contains(item.type) {
            return [
                Point(x: item.x1 ?? item.x, y: item.y1 ?? item.y),
                Point(x: item.x2 ?? item.x + item.width, y: item.y2 ?? item.y + item.height),
            ]
        }
        if ["stroke", "highlighter", "paint"].contains(item.type) { return item.parsedPoints }
        if item.type == "curve", item.parsedPoints.count >= 3 {
            let p = item.parsedPoints
            return (0...64).map { i in
                let t = Double(i) / 64
                let u = 1 - t
                return Point(
                    x: u * u * p[0].x + 2 * u * t * p[1].x + t * t * p[2].x,
                    y: u * u * p[0].y + 2 * u * t * p[1].y + t * t * p[2].y)
            }
        }
        let cx = item.x + item.width / 2
        let cy = item.y + item.height / 2
        var local: [Point]
        if ["triangle", "quadrilateral"].contains(item.type), item.parsedPoints.count >= 3 {
            return item.parsedPoints
        }
        switch item.type {
        case "circle", "ellipse", "arc":
            let r = item.arcRadius ?? item.width / 2
            let rx = item.type == "arc" ? r : item.width / 2
            let ry = item.type == "arc" ? r : item.height / 2
            let start = item.type == "arc" ? item.arcStartAngle ?? 0 : 0
            let sweep = item.type == "arc" ? item.arcSweepAngle ?? 360 : 360
            local = (0...72).map { i in
                let a = (start + sweep * Double(i) / 72) * .pi / 180
                return Point(x: cx + rx * cos(a), y: cy + ry * sin(a))
            }
        case "diamond":
            local = [
                Point(x: cx, y: item.y), Point(x: item.x + item.width, y: cy),
                Point(x: cx, y: item.y + item.height), Point(x: item.x, y: cy),
            ]
        case "polygon", "pentagon", "star", "triangle":
            let count =
                item.type == "star"
                ? 10 : item.type == "triangle" ? 3 : max(3, min(64, item.polygonSides ?? 5))
            local = (0..<count).map { i in
                let a = -.pi / 2 + Double(i) * 2 * .pi / Double(count)
                let radius = item.type == "star" && i % 2 == 1 ? 0.44 : 1.0
                return Point(
                    x: cx + cos(a) * item.width / 2 * radius, y: cy + sin(a) * item.height / 2 * radius)
            }
        default:
            local = [
                Point(x: item.x, y: item.y), Point(x: item.x + item.width, y: item.y),
                Point(x: item.x + item.width, y: item.y + item.height),
                Point(x: item.x, y: item.y + item.height),
            ]
        }
        let a = item.rotation * .pi / 180
        return local.map { p in
            Point(
                x: cx + (p.x - cx) * cos(a) - (p.y - cy) * sin(a),
                y: cy + (p.x - cx) * sin(a) + (p.y - cy) * cos(a))
        }
    }

    public static func references(_ item: BoardObject) -> [Point] {
        let cx = item.x + item.width / 2
        let cy = item.y + item.height / 2
        if ["circle", "ellipse", "arc"].contains(item.type) {
            let a = item.rotation * .pi / 180
            let rx = item.type == "arc" ? item.arcRadius ?? item.width / 2 : item.width / 2
            let ry = item.type == "arc" ? rx : item.height / 2
            var points = [Point(x: cx, y: cy)]
            for (x, y) in [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)] {
                let dx = x * rx
                let dy = y * ry
                points.append(Point(x: cx + dx * cos(a) - dy * sin(a), y: cy + dx * sin(a) + dy * cos(a)))
            }
            if item.type == "arc", let first = outline(item).first, let last = outline(item).last {
                points += [first, last]
            }
            return points
        }
        let vertices = outline(item)
        let polygon = [
            "rect", "rounded_rect", "triangle", "quadrilateral", "diamond", "polygon", "pentagon", "star",
        ].contains(item.type)
        var points = vertices
        if polygon || ["line", "arrow", "connector"].contains(item.type) {
            let n = polygon ? vertices.count : max(0, vertices.count - 1)
            for i in 0..<n {
                let a = vertices[i]
                let b = vertices[(i + 1) % vertices.count]
                points.append(Point(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
            }
        }
        if ["rect", "rounded_rect"].contains(item.type) { points.append(Point(x: cx, y: cy)) }
        return points
    }
}

/// Cell size equals snap radius; each pointer sample visits at most nine nearby buckets.
public final class MagnetSnapIndex {
    /// Freehand brushes follow pointer samples; magnet snapping applies only to geometric construction tools.
    public static func supportsConstructionTool(_ tool: ToolType) -> Bool {
        [
            .curve, .line, .arrow, .rect, .roundedRect, .circle, .triangle, .quadrilateral, .diamond,
            .polygon, .star, .connector,
        ].contains(tool)
    }

    private struct Cell: Hashable {
        let x: Int64
        let y: Int64
    }
    private var cells: [Cell: [Point]] = [:]
    private let radius: Double
    public init(objects: [BoardObject], radius: Double) {
        self.radius = radius.isFinite && radius > 0 ? radius : 10
        for item in objects where item.isVisible != false {
            for point in DrawingReferenceGeometry.references(item) where point.x.isFinite && point.y.isFinite
            {
                if let key = cell(point) { cells[key, default: []].append(point) }
            }
        }
    }
    private func cell(_ p: Point) -> Cell? {
        let x = floor(p.x / radius)
        let y = floor(p.y / radius)
        guard x.isFinite, y.isFinite, abs(x) < Double(Int64.max / 2), abs(y) < Double(Int64.max / 2) else {
            return nil
        }
        return Cell(x: Int64(x), y: Int64(y))
    }
    public func snap(_ point: Point) -> Point? {
        guard let key = cell(point) else { return nil }
        var result: Point?
        var best = radius * radius
        for dx in -1...1 {
            for dy in -1...1 {
                for p in cells[Cell(x: key.x + Int64(dx), y: key.y + Int64(dy))] ?? [] {
                    let distance = (p.x - point.x) * (p.x - point.x) + (p.y - point.y) * (p.y - point.y)
                    if distance <= best {
                        best = distance
                        result = Point(x: p.x, y: p.y, pressure: point.pressure)
                    }
                }
            }
        }
        return result
    }
}

extension BoardEngine {
    public func toggleMagnet() {
        toolbarPreferences.magnetEnabled.toggle()
        drawingAssist.target = nil
        saveToolbarPreferences()
    }
    public func snapDrawingScreenPoint(_ point: Point, allowCompassCenter: Bool = false) -> Point {
        guard toolbarPreferences.magnetEnabled,
            allowCompassCenter || MagnetSnapIndex.supportsConstructionTool(currentTool)
        else {
            drawingAssist.target = nil
            return point
        }
        if magnetIndex == nil || magnetIndexRevision != drawingGeometryRevision
            || magnetIndexPage != activePageId || magnetIndexZoom != viewport.zoom
        {
            magnetIndex = MagnetSnapIndex(objects: currentPageObjects, radius: 10 / max(0.01, viewport.zoom))
            magnetIndexRevision = drawingGeometryRevision
            magnetIndexPage = activePageId
            magnetIndexZoom = viewport.zoom
        }
        let world = VectorMath.screenToWorld(point, viewport: viewport)
        let target = magnetIndex?.snap(world)
        if drawingAssist.target != target { drawingAssist.target = target }
        guard let target else { return point }
        return Point(
            x: target.x * viewport.zoom + viewport.x, y: target.y * viewport.zoom + viewport.y,
            pressure: point.pressure)
    }
    public func updateMagnetHover(at point: Point?) {
        guard let point, !readingMode, MagnetSnapIndex.supportsConstructionTool(currentTool) else {
            if drawingAssist.target != nil { drawingAssist.target = nil }
            return
        }
        _ = snapDrawingScreenPoint(point)
    }
}
