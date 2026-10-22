import Combine
import CoreGraphics
import Foundation

public final class BoardEraserState: ObservableObject {
    @Published public var pointer: Point?
    @Published public var grip = Point(x: 80, y: 49)
    public init() {}
}

/// Same original sprite and mirrored alpha hull as Windows. Units are screen points, never world units.
public enum BoardEraserGeometry {
    public static let width = 160.0, height = 1280.0 / 13
    public static let outline: [Point] = [
        (0.12070, 0.59146), (0.15322, 0.55488), (0.79049, 0.17480), (0.83615, 0.19411), (0.85679, 0.24187),
        (0.89181, 0.40650), (0.87930, 0.47764), (0.83615, 0.52033), (0.20763, 0.88923), (0.17198, 0.87907),
        (0.14196, 0.81606), (0.10944, 0.65854),
    ].map { Point(x: (1 - $0.0) * width, y: $0.1 * height) }
    public static func canGrab(_ p: Point) -> Bool { ConvexEraserFootprint(outline).contains(p) }
}

/// Convex half-plane clipping avoids bounding-box over-erasure at transparent angled corners.
public struct ConvexEraserFootprint {
    public let corners: [Point]
    private let edges: [(Point, Double, Double)]
    public init(_ corners: [Point]) {
        self.corners = corners
        guard corners.count >= 3, corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            edges = []
            return
        }
        let o = corners[0]
        var area = 0.0
        for i in 1..<(corners.count - 1) {
            area +=
                (corners[i].x - o.x) * (corners[i + 1].y - o.y) - (corners[i].y - o.y)
                * (corners[i + 1].x - o.x)
        }
        guard abs(area) > 1e-12 else {
            edges = []
            return
        }
        let sign = area >= 0 ? 1.0 : -1.0
        edges = corners.indices.compactMap { i in
            let a = corners[i]
            let b = corners[(i + 1) % corners.count]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let l = hypot(dx, dy)
            return l > 1e-12 ? (a, -sign * dy / l, sign * dx / l) : nil
        }
    }
    public func contains(_ p: Point, padding: Double = 0) -> Bool {
        edges.count >= 3 && edges.allSatisfy { a, nx, ny in nx * (p.x - a.x) + ny * (p.y - a.y) >= -padding }
    }
    public func clip(_ a: Point, _ b: Point, padding: Double) -> (Double, Double)? {
        guard edges.count >= 3 else { return nil }
        var enter = 0.0
        var exit = 1.0
        for (p, nx, ny) in edges {
            let from = nx * (a.x - p.x) + ny * (a.y - p.y) + padding
            let to = nx * (b.x - p.x) + ny * (b.y - p.y) + padding
            if from < 0 && to < 0 { return nil }
            if from >= 0 && to >= 0 { continue }
            let t = from / (from - to)
            if from < 0 { enter = max(enter, t) } else { exit = min(exit, t) }
            if enter > exit { return nil }
        }
        return (enter, exit)
    }
    public func split(_ points: [Point], padding: Double) -> [[Point]] {
        if points.count == 1 { return contains(points[0], padding: padding) ? [] : [points] }
        guard points.count > 1 else { return [] }
        var runs: [[Point]] = []
        var run: [Point] = []
        func at(_ a: Point, _ b: Point, _ t: Double) -> Point {
            Point(
                x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t,
                pressure: a.pressure.flatMap { ap in b.pressure.map { ap + ($0 - ap) * t } })
        }
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            if let (enter, exit) = clip(a, b, padding: padding), exit - enter > 1e-10 {
                if enter > 1e-10 {
                    if run.isEmpty { run.append(a) }
                    run.append(at(a, b, enter))
                }
                if !run.isEmpty {
                    runs.append(run)
                    run = []
                }
                if exit < 1 - 1e-10 { run = [at(a, b, exit), b] }
            } else {
                if run.isEmpty { run.append(a) }
                run.append(b)
            }
        }
        if !run.isEmpty { runs.append(run) }
        return runs
    }
}

extension BoardEngine {
    public func setBoardEraserVisible(_ visible: Bool) {
        if !visible { cancelBoardEraser() }
        toolbarPreferences.boardEraserVisible = visible
        saveToolbarPreferences()
    }
    public func beginBoardEraser(at pointer: Point, grip: Point) {
        guard !readingMode, !showingHome, BoardEraserGeometry.canGrab(grip) else { return }
        commitInlineTextEntry()
        let previousTool = currentTool
        cancelTransientInteraction()
        currentTool = previousTool
        boardEraserOriginal = objects
        boardEraserContext = board.id + ":" + (activePageId ?? "")
        boardEraser.grip = grip
        boardEraser.pointer = pointer
        moveBoardEraser(to: pointer)
    }
    public func moveBoardEraser(to pointer: Point) {
        guard boardEraserOriginal != nil, boardEraserContext == board.id + ":" + (activePageId ?? "") else {
            return
        }
        let last = boardEraser.pointer ?? pointer
        let steps = max(1, Int(ceil(hypot(pointer.x - last.x, pointer.y - last.y) / 5)))
        // Build one replacement list per native event. Intermediate samples cover fast drags without gaps.
        var draft = objects
        for i in 1...steps {
            let p = Point(
                x: last.x + (pointer.x - last.x) * Double(i) / Double(steps),
                y: last.y + (pointer.y - last.y) * Double(i) / Double(steps))
            let footprint = ConvexEraserFootprint(
                BoardEraserGeometry.outline.map {
                    VectorMath.screenToWorld(
                        Point(x: p.x - boardEraser.grip.x + $0.x, y: p.y - boardEraser.grip.y + $0.y),
                        viewport: viewport)
                })
            draft = draft.flatMap { item -> [BoardObject] in
                guard isObjectOnCurrentPage(item), item.isVisible != false, item.isLocked != true,
                    Self.isEraserEligible(item.type)
                else { return [item] }
                let points = DrawingReferenceGeometry.outline(item)
                let padding = max(0, item.strokeWidth / 2)
                guard !points.isEmpty else { return [item] }
                if eraserMode != .object {
                    guard ["stroke", "curve", "highlighter", "paint"].contains(item.type) else {
                        return [item]
                    }
                    let runs = footprint.split(points, padding: padding)
                    if runs.count == 1 && runs[0] == points { return [item] }
                    return runs.filter { $0.count >= 2 }.map { run in
                        // Copy the complete object, including unknown fields and brush metadata.
                        var segment = item
                        segment.id = UUID().uuidString
                        segment.type = item.type == "curve" ? "stroke" : item.type
                        segment.x = run.map(\.x).min() ?? item.x
                        segment.y = run.map(\.y).min() ?? item.y
                        segment.width = max(1, (run.map(\.x).max() ?? item.x) - segment.x)
                        segment.height = max(1, (run.map(\.y).max() ?? item.y) - segment.y)
                        segment.rotation = 0
                        segment.points = (try? JSONEncoder().encode(run)).flatMap {
                            String(data: $0, encoding: .utf8)
                        }
                        return segment
                    }
                }
                if points.contains(where: { footprint.contains($0, padding: padding) }) { return [] }
                let open = ["stroke", "curve", "highlighter", "paint", "line", "arrow", "connector", "arc"]
                    .contains(item.type)
                let count = open ? max(0, points.count - 1) : points.count
                for j in 0..<count {
                    if footprint.clip(points[j], points[(j + 1) % points.count], padding: padding) != nil {
                        return []
                    }
                }
                if !open && item.fillColor != "none" {
                    let path = CGMutablePath()
                    path.addLines(between: points.map { CGPoint(x: $0.x, y: $0.y) })
                    path.closeSubpath()
                    if footprint.corners.contains(where: { path.contains(CGPoint(x: $0.x, y: $0.y)) }) {
                        return []
                    }
                }
                return [item]
            }
        }
        if draft != objects { objects = draft }
        boardEraser.pointer = pointer
    }
    public func finishBoardEraser() {
        guard let before = boardEraserOriginal else { return }
        boardEraserOriginal = nil
        boardEraserContext = nil
        boardEraser.pointer = nil
        guard before != objects else { return }
        transactionManager.push(.replaceObjects(before: before, after: objects))
        scheduleAutosave()
    }
    public func cancelBoardEraser() {
        guard let original = boardEraserOriginal else { return }
        objects = original
        boardEraserOriginal = nil
        boardEraserContext = nil
        boardEraser.pointer = nil
    }
}
