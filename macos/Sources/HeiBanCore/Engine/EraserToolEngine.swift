import Foundation

public enum EraserToolEngine {
    /// 在世界座標裁剪整條線段，而不是只刪除落入圓內的取樣點。
    /// 沒碰到時回傳原物件；切開時複製完整物件、烘焙旋轉，保留筆刷及未知欄位。
    public static func sliceStroke(
        object: BoardObject, eraserCenter: Point, eraserRadius: Double
    ) -> [BoardObject] {
        let source = object.parsedPoints
        guard !source.isEmpty, eraserRadius.isFinite, eraserRadius >= 0 else { return [object] }
        var points = source
        if object.type == "curve", source.count >= 3 {
            points = (0...96).map { step in
                let t = Double(step) / 96
                let u = 1 - t
                var p = interpolate(source[0], source[2], t)
                p.x = u * u * source[0].x + 2 * u * t * source[1].x + t * t * source[2].x
                p.y = u * u * source[0].y + 2 * u * t * source[1].y + t * t * source[2].y
                return p
            }
        }
        let angle = object.rotation * .pi / 180
        if angle != 0 {
            let cx = object.x + object.width / 2
            let cy = object.y + object.height / 2
            points = points.map { point in
                var p = point
                let dx = p.x - cx
                let dy = p.y - cy
                p.x = cx + dx * cos(angle) - dy * sin(angle)
                p.y = cy + dx * sin(angle) + dy * cos(angle)
                return p
            }
        }
        let radius = eraserRadius + max(0, object.strokeWidth / 2)
        let r2 = radius * radius
        func inside(_ p: Point) -> Bool {
            let dx = p.x - eraserCenter.x
            let dy = p.y - eraserCenter.y
            return dx * dx + dy * dy < r2
        }
        if points.count == 1 { return inside(points[0]) ? [] : [object] }
        var changed = false
        var runs: [[Point]] = []
        var run: [Point] = []
        func append(_ p: Point) {
            if let last = run.last, hypot(last.x - p.x, last.y - p.y) < 1e-9 { return }
            run.append(p)
        }
        func flush() {
            if run.count >= 2 { runs.append(run) }
            run.removeAll(keepingCapacity: true)
        }
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let ox = a.x - eraserCenter.x
            let oy = a.y - eraserCenter.y
            let aa = dx * dx + dy * dy
            var cuts = [0.0, 1.0]
            if aa > 1e-18 {
                let bb = 2 * (ox * dx + oy * dy)
                let cc = ox * ox + oy * oy - r2
                let discriminant = bb * bb - 4 * aa * cc
                if discriminant > 0 {
                    let root = sqrt(discriminant)
                    for t in [(-bb - root) / (2 * aa), (-bb + root) / (2 * aa)] where t > 0 && t < 1 {
                        cuts.append(t)
                    }
                }
            }
            cuts.sort()
            for j in 1..<cuts.count {
                let lo = cuts[j - 1]
                let hi = cuts[j]
                if inside(interpolate(a, b, (lo + hi) / 2)) {
                    changed = true
                    flush()
                } else {
                    append(interpolate(a, b, lo))
                    append(interpolate(a, b, hi))
                }
            }
        }
        flush()
        guard changed else { return [object] }
        return runs.compactMap { points in
            guard let data = try? JSONEncoder().encode(points), let json = String(data: data, encoding: .utf8)
            else { return nil }
            var part = object
            part.id = UUID().uuidString
            part.type = object.type == "curve" ? "stroke" : object.type
            part.rotation = 0
            part.x = points.map(\.x).min() ?? object.x
            part.y = points.map(\.y).min() ?? object.y
            part.width = max(1, (points.map(\.x).max() ?? part.x) - part.x)
            part.height = max(1, (points.map(\.y).max() ?? part.y) - part.y)
            part.points = json
            return part
        }
    }

    private static func interpolate(_ a: Point, _ b: Point, _ t: Double) -> Point {
        // 新交點沿用最近端點的擴充欄位；已知壓力線性插值，不重建成失去metadata的新點。
        var p = t < 0.5 ? a : b
        p.x = a.x + (b.x - a.x) * t
        p.y = a.y + (b.y - a.y) * t
        if let pa = a.pressure, let pb = b.pressure { p.pressure = pa + (pb - pa) * t }
        return p
    }
}
