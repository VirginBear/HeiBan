import CoreGraphics
import HeiBanCore
import SwiftUI

/// 一次手勢只產生一個連續輪廓；透明度不能分桶後逐段 round-cap，否則交界會變成珠狀亮點。
/// 取樣仍由 LaserPointerEngine 擁有，這裡唯讀轉換螢幕座標，不寫入作品或 Undo。
struct LaserTrailGeometry {
    struct Knot {
        var point: CGPoint
        var time: Double
    }
    let knots: [Knot]

    init(samples: [LaserSample], viewport: ViewportTransform) {
        let raw = samples.map { sample in
            let p = VectorMath.worldToScreen(sample.point, viewport: viewport)
            return Knot(point: CGPoint(x: p.x, y: p.y), time: sample.timestamp)
        }
        guard let first = raw.first else { knots = []; return }
        var output = [first]
        var start = first
        for index in raw.indices {
            let control = raw[index]
            let end = index + 1 < raw.count ? Self.mix(control, raw[index + 1], 0.5) : control
            let length = hypot(control.point.x - start.point.x, control.point.y - start.point.y)
                + hypot(end.point.x - control.point.x, end.point.y - control.point.y)
            // 二次曲線在控制點凸包內，避免 Catmull-Rom 在急轉彎／稀疏點時超衝。
            // 每個來源段最多 24 次，保留引擎最多 500 點的有界工作量。
            let steps = max(1, min(24, Int(ceil(length / 3))))
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                let value = Self.mix(Self.mix(start, control, t), Self.mix(control, end, t), t)
                if let last = output.last,
                   hypot(value.point.x - last.point.x, value.point.y - last.point.y) < 0.2 {
                    output[output.count - 1] = value
                } else {
                    output.append(value)
                }
            }
            start = end
        }
        knots = output
    }

    private static func mix(_ a: Knot, _ b: Knot, _ t: Double) -> Knot {
        Knot(point: CGPoint(x: a.point.x + (b.point.x - a.point.x) * t,
                            y: a.point.y + (b.point.y - a.point.y) * t),
             time: a.time + (b.time - a.time) * t)
    }

    func ribbon(width: CGFloat, now: Double, duration: Double) -> Path {
        guard knots.count > 1 else { return Path() }
        var left: [CGPoint] = [], right: [CGPoint] = []
        var tangents: [CGVector] = []
        for index in knots.indices {
            let previous = knots[max(0, index - 1)].point
            let next = knots[min(knots.count - 1, index + 1)].point
            let length = max(0.001, hypot(next.x - previous.x, next.y - previous.y))
            let tangent = CGVector(dx: (next.x - previous.x) / length, dy: (next.y - previous.y) / length)
            // 以時間連續收細尾端，整條只有一個外輪廓，沒有每段端帽／透明度跳階。
            let freshness = max(0, min(1, 1 - (now - knots[index].time) / duration))
            let radius = width / 2 * CGFloat(sqrt(freshness))
            let point = knots[index].point
            left.append(CGPoint(x: point.x - tangent.dy * radius, y: point.y + tangent.dx * radius))
            right.append(CGPoint(x: point.x + tangent.dy * radius, y: point.y - tangent.dx * radius))
            tangents.append(tangent)
        }
        var path = Path()
        path.move(to: left[0])
        for p in left.dropFirst() { path.addLine(to: p) }
        let head = knots.last!.point, tip = tangents.last!
        let headRadius = hypot(left.last!.x - head.x, left.last!.y - head.y)
        path.addQuadCurve(to: right.last!, control: CGPoint(x: head.x + tip.dx * headRadius * 2,
                                                          y: head.y + tip.dy * headRadius * 2))
        for p in right.dropLast().reversed() { path.addLine(to: p) }
        let tail = knots[0].point, back = tangents[0]
        let tailRadius = hypot(left[0].x - tail.x, left[0].y - tail.y)
        path.addQuadCurve(to: left[0], control: CGPoint(x: tail.x - back.dx * tailRadius * 2,
                                                      y: tail.y - back.dy * tailRadius * 2))
        path.closeSubpath()
        return path
    }
}
