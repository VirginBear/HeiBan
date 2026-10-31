import CoreGraphics
import Foundation

public struct ToolArtBounds: Equatable, Sendable {
    public let left: Double
    public let top: Double
    public let right: Double
    public let bottom: Double

    public var width: Double { max(0.0, right - left) }
    public var height: Double { max(0.0, bottom - top) }

    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    public static func from(_ points: [Point]) -> ToolArtBounds {
        var left = Double.greatestFiniteMagnitude
        var top = Double.greatestFiniteMagnitude
        var right = -Double.greatestFiniteMagnitude
        var bottom = -Double.greatestFiniteMagnitude
        for point in points {
            left = min(left, point.x)
            top = min(top, point.y)
            right = max(right, point.x)
            bottom = max(bottom, point.y)
        }
        return points.isEmpty
            ? ToolArtBounds(left: 0, top: 0, right: 0, bottom: 0)
            : ToolArtBounds(left: left, top: top, right: right, bottom: bottom)
    }
}

public final class CaneFeedback {
    public static let duration: Double = 0.26

    public private(set) var point: Point?
    public private(set) var startedAt: Double = -.infinity

    public init() {}

    public func isActive(now: Double) -> Bool {
        point != nil && now - startedAt >= 0 && now - startedAt < Self.duration
    }

    @discardableResult
    public func move(_ nextPoint: Point) -> Bool {
        guard nextPoint.x.isFinite && nextPoint.y.isFinite else { return false }
        if let current = point, abs(current.x - nextPoint.x) < 0.01 && abs(current.y - nextPoint.y) < 0.01 {
            return false
        }
        point = nextPoint
        return true
    }

    public func strike(_ nextPoint: Point, now: Double) {
        guard nextPoint.x.isFinite && nextPoint.y.isFinite && now.isFinite else { return }
        point = nextPoint
        startedAt = now
    }

    public func clear() {
        point = nil
        startedAt = -.infinity
    }
}

public enum CanePose {
    public static let restDegrees: Double = 45.0
    public static let raisedDegrees: Double = 75.0
    public static let impactSeconds: Double = 0.075

    // Cane.png 原始透明後的杖身凸包（alpha >= 128），供右下快捷與教學定位避開透明留白。
    private static let body: [(Double, Double)] = [
        (0.05664, 0.90366), (0.05989, 0.89228), (0.14193, 0.80854), (0.37174, 0.59309),
        (0.49154, 0.48415), (0.91602, 0.10447), (0.92253, 0.10122), (0.92904, 0.10122),
        (0.93424, 0.10447), (0.93880, 0.10854), (0.94141, 0.11423), (0.94271, 0.11789),
        (0.94336, 0.12033), (0.94336, 0.13089), (0.94206, 0.13415), (0.93815, 0.14146),
        (0.93359, 0.14634), (0.85807, 0.21463), (0.50651, 0.53171), (0.12305, 0.90569),
        (0.09766, 0.92846), (0.08854, 0.93577), (0.08073, 0.93984), (0.07617, 0.94146),
        (0.07161, 0.94228), (0.06836, 0.94228), (0.06510, 0.94065), (0.06185, 0.93740),
        (0.05924, 0.93333), (0.05794, 0.92927), (0.05664, 0.92033), (0.05664, 0.90366),
    ]

    public static func artworkRestRotationDegrees(width: Double, height: Double) -> Double {
        restDegrees - atan2(height * 0.83, width * 0.87) * 180.0 / .pi
    }

    public static func swingDegrees(elapsed: Double) -> Double {
        if !elapsed.isFinite || elapsed < 0 || elapsed >= CaneFeedback.duration {
            return 0
        }
        if elapsed < 0.035 {
            return (raisedDegrees - restDegrees) * sin(elapsed / 0.035 * .pi * 0.5)
        }
        if elapsed < impactSeconds {
            return (raisedDegrees - restDegrees) * (1.0 - sin((elapsed - 0.035) / 0.04 * .pi * 0.5))
        }
        let recovery = (elapsed - impactSeconds) / (CaneFeedback.duration - impactSeconds)
        return 8.0 * sin(recovery * .pi)
    }

    public static func dockBounds(width: Double, height: Double) -> ToolArtBounds {
        let radians = artworkRestRotationDegrees(width: width, height: height) * .pi / 180.0
        let c = cos(radians)
        let s = sin(radians)
        let cx = width * 0.5
        let cy = height * 0.5
        return ToolArtBounds.from(body.map { u, v in
            let dx = u * width - cx
            let dy = v * height - cy
            return Point(x: cx + dx * c - dy * s, y: cy + dx * s + dy * c)
        })
    }
}
