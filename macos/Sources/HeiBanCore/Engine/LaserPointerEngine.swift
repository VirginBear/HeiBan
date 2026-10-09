import Foundation
import CoreGraphics

public enum LaserMode: String, Codable, CaseIterable, Sendable {
    case point = "point"           // 光點
    case shortTrail = "shortTrail" // 短尾跡
    case line = "line"             // 線條模式
}

public struct LaserSample: Equatable, Sendable {
    public let point: Point
    public let timestamp: TimeInterval
    public let startsNewTrail: Bool

    public init(point: Point, timestamp: TimeInterval, startsNewTrail: Bool = false) {
        self.point = point
        self.timestamp = timestamp
        self.startsNewTrail = startsNewTrail
    }
}

public final class LaserPointerEngine: ObservableObject, @unchecked Sendable {
    @Published public var isEnabled: Bool = false
    @Published public var mode: LaserMode = .shortTrail {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "HeiBan.laser.mode") }
    }
    @Published public var color: String = "#ef4444" {
        didSet { UserDefaults.standard.set(color, forKey: "HeiBan.laser.color") }
    } // Default laser red
    @Published public var width: Double = 8.0 {
        didSet { UserDefaults.standard.set(width, forKey: "HeiBan.laser.width") }
    }
    /// Diameter in screen points, independent of canvas zoom.
    @Published public var pointDiameter: Double = 16.0 {
        didSet { UserDefaults.standard.set(pointDiameter, forKey: "HeiBan.laser.pointDiameter") }
    }
    @Published public var hasWhiteCore: Bool = true {
        didSet { UserDefaults.standard.set(hasWhiteCore, forKey: "HeiBan.laser.hasWhiteCore") }
    }
    @Published public var fadeDuration: Double = 0.8 {
        didSet { UserDefaults.standard.set(fadeDuration, forKey: "HeiBan.laser.fadeDuration") }
    } // Seconds
    // Pointer samples are read at display cadence by the overlay. Publishing each
    // mouse sample would invalidate the view hierarchy before the next frame.
    public private(set) var samples: [LaserSample] = []

    @Published public private(set) var hasVisibleSamples = false
    private var expiryTimer: Timer?
    private var startsNewTrail = true

    public let maxCapacity: Int = 500 // Upper bound to guarantee no memory leak during long presentations

    public init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "HeiBan.laser.mode"), let saved = LaserMode(rawValue: raw) { mode = saved }
        if let saved = defaults.string(forKey: "HeiBan.laser.color") { color = saved }
        if let saved = defaults.object(forKey: "HeiBan.laser.width") as? Double, saved.isFinite { width = min(24, max(1, saved)) }
        if let saved = defaults.object(forKey: "HeiBan.laser.fadeDuration") as? Double, saved.isFinite { fadeDuration = min(3, max(0.2, saved)) }
        if let saved = defaults.object(forKey: "HeiBan.laser.hasWhiteCore") as? Bool { hasWhiteCore = saved }
        if let saved = UserDefaults.standard.object(forKey: "HeiBan.laser.pointDiameter") as? Double, saved.isFinite {
            pointDiameter = min(64, max(4, saved))
        }
    }

    public func beginTrail() { startsNewTrail = true }

    public func addSample(point: Point, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        purgeExpiredSamples(currentTime: timestamp)
        if let last = samples.last, last.point == point, timestamp - last.timestamp < 1.0 / 120.0 { return }
        let sample = LaserSample(point: point, timestamp: timestamp, startsNewTrail: startsNewTrail)
        startsNewTrail = false
        samples.append(sample)
        if !hasVisibleSamples { hasVisibleSamples = true }
        if expiryTimer == nil {
            expiryTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.purgeExpiredSamples()
                if self.samples.isEmpty { self.clear() }
            }
        }
        if samples.count > maxCapacity {
            samples.removeFirst(samples.count - maxCapacity)
        }
    }

    public func purgeExpiredSamples(currentTime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard !samples.isEmpty else { return }
        switch mode {
        case .point:
            // Point mode keeps only the latest sample if it's recent (within 0.3s)
            if let last = samples.last, currentTime - last.timestamp <= 0.3 {
                samples = [last]
            } else {
                samples.removeAll(keepingCapacity: true)
            }
        case .shortTrail:
            let cutoff = currentTime - max(0.2, min(fadeDuration, 0.8))
            samples.removeAll { $0.timestamp < cutoff }
        case .line:
            let cutoff = currentTime - max(0.2, fadeDuration)
            samples.removeAll { $0.timestamp < cutoff }
        }
    }

    public func clear() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        samples.removeAll(keepingCapacity: true)
        startsNewTrail = true
        if hasVisibleSamples { hasVisibleSamples = false }
    }

    deinit { expiryTimer?.invalidate() }

    public func cleanupOnDeactivate() {
        clear()
        isEnabled = false
    }
}
