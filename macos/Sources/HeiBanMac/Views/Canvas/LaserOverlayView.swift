import SwiftUI
import HeiBanCore

struct LaserOverlayView: View {
    @ObservedObject var laser: LaserPointerEngine
    let viewport: ViewportTransform

    var body: some View {
        if laser.isEnabled && laser.hasVisibleSamples {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let now = ProcessInfo.processInfo.systemUptime + timeline.date.timeIntervalSinceNow
                Canvas { context, _ in
                    let lifetime = laser.mode == .point ? 0.3 :
                        (laser.mode == .shortTrail ? min(0.8, laser.fadeDuration) : laser.fadeDuration)
                    let duration = max(0.2, lifetime)
                    var samples = laser.samples.filter { now - $0.timestamp < duration }
                    if laser.isPressed, samples.isEmpty, let held = laser.samples.last {
                        samples = [held]
                    }
                    guard let last = samples.last else { return }
                    let color = Color(hex: laser.color)
                    let width = CGFloat(max(1, laser.width))
                    if laser.mode != .point {
                        // 保留手勢邊界；移出再移回畫布不能連到前一次尾跡。
                        var trails: [[LaserSample]] = []
                        for sample in samples {
                            if sample.startsNewTrail || trails.isEmpty { trails.append([]) }
                            trails[trails.count - 1].append(sample)
                        }
                        for trail in trails where trail.count > 1 {
                            let geometry = LaserTrailGeometry(samples: trail, viewport: viewport)
                            let alpha = max(0, min(1, 1 - (now - trail.last!.timestamp) / duration))
                            context.drawLayer { glow in
                                glow.addFilter(.blur(radius: max(2, width * 0.8)))
                                glow.fill(geometry.ribbon(width: width * 2, now: now, duration: duration),
                                          with: .color(color.opacity(alpha * 0.55)))
                            }
                            context.fill(geometry.ribbon(width: width, now: now, duration: duration),
                                         with: .color(color.opacity(alpha)))
                            if laser.hasWhiteCore {
                                context.fill(geometry.ribbon(width: max(0.5, width * 0.24), now: now, duration: duration),
                                             with: .color(.white.opacity(alpha * 0.85)))
                            }
                        }
                    }
                    let point = VectorMath.worldToScreen(last.point, viewport: viewport)
                    let radius = CGFloat(max(4, laser.pointDiameter)) / 2
                    let alpha = laser.isPressed ? 1.0 : max(0, min(1, 1 - (now - last.timestamp) / duration))
                    let center = CGPoint(x: point.x, y: point.y)
                    let haloRadius = radius * 2.4
                    let halo = Path(ellipseIn: CGRect(x: center.x - haloRadius, y: center.y - haloRadius,
                                                     width: haloRadius * 2, height: haloRadius * 2))
                    let gradient = Gradient(stops: [
                        .init(color: laser.hasWhiteCore ? .white.opacity(alpha) : color.opacity(alpha), location: 0),
                        .init(color: color.opacity(alpha), location: 0.24),
                        .init(color: color.opacity(alpha * 0.5), location: 0.42),
                        .init(color: color.opacity(0), location: 1),
                    ])
                    context.fill(halo, with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: haloRadius))
                }
            }.allowsHitTesting(false)
        }
    }
}
