import SwiftUI
import HeiBanCore

struct LaserOverlayView: View {
    @ObservedObject var laser: LaserPointerEngine
    let viewport: ViewportTransform

    var body: some View {
        // No display timer is active after switching away from the laser tool.
        if laser.isEnabled && laser.hasVisibleSamples {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                // Capture the tick in the Canvas value so SwiftUI cannot reuse a
                // closure that only depends on the unchanged sample-array identity.
                let now = ProcessInfo.processInfo.systemUptime + timeline.date.timeIntervalSinceNow
                Canvas { context, _ in
                    let lifetime = laser.mode == .point ? 0.3 :
                        (laser.mode == .shortTrail ? min(0.8, laser.fadeDuration) : laser.fadeDuration)
                    let duration = max(0.2, lifetime)
                    // Rendering is read-only. Expired samples are removed on the next input.
                    let samples = laser.samples.filter { now - $0.timestamp < duration }
                    guard let last = samples.last else { return }
                    let color = Color(hex: laser.color)
                    let width = CGFloat(max(1, laser.width))

                    if laser.mode != .point, samples.count > 1 {
                        // Batch connected segments by opacity instead of issuing three
                        // draw calls per mouse sample (up to 1,497 calls previously).
                        var paths = Array(repeating: Path(), count: 24)
                        for index in 1..<samples.count {
                            let previous = samples[index - 1]
                            let current = samples[index]
                            // A new gesture after a pause must not draw a connecting line.
                            guard !current.startsNewTrail else { continue }
                            let opacity = max(0, min(1, 1 - (now - current.timestamp) / duration))
                            let bucket = min(23, Int(opacity * 24))
                            let a = VectorMath.worldToScreen(previous.point, viewport: viewport)
                            let b = VectorMath.worldToScreen(current.point, viewport: viewport)
                            let start = CGPoint(x: a.x, y: a.y)
                            if paths[bucket].currentPoint != start { paths[bucket].move(to: start) }
                            paths[bucket].addLine(to: CGPoint(x: b.x, y: b.y))
                        }
                        for index in paths.indices where !paths[index].isEmpty {
                            let alpha = Double(index + 1) / 24
                            context.stroke(paths[index], with: .color(color.opacity(0.3 * alpha)),
                                           style: StrokeStyle(lineWidth: width * 2.2, lineCap: .round, lineJoin: .round))
                            context.stroke(paths[index], with: .color(color.opacity(alpha)),
                                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                            if laser.hasWhiteCore {
                                context.stroke(paths[index], with: .color(.white.opacity(0.9 * alpha)),
                                               style: StrokeStyle(lineWidth: max(1, width * 0.3), lineCap: .round, lineJoin: .round))
                            }
                        }
                    }
                    let point = VectorMath.worldToScreen(last.point, viewport: viewport)
                    let radius = CGFloat(max(4, laser.pointDiameter)) / 2
                    let alpha = max(0, 1 - (now - last.timestamp) / duration)
                    let center = CGPoint(x: point.x, y: point.y)
                    func dot(_ radius: CGFloat) -> Path {
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                               width: radius * 2, height: radius * 2))
                    }
                    context.fill(dot(radius * 2.1), with: .color(color.opacity(0.25 * alpha)))
                    context.fill(dot(radius), with: .color(color.opacity(alpha)))
                    if laser.hasWhiteCore {
                        context.fill(dot(radius * 0.35), with: .color(.white.opacity(alpha)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
