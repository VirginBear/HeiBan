import Foundation
import Combine
import AppKit

public enum TimerMode: String, Codable, CaseIterable, Sendable {
    case stopwatch = "stopwatch"
    case countdown = "countdown"

    public var displayName: String {
        switch self {
        case .stopwatch: return "正計時"
        case .countdown: return "倒數計時"
        }
    }
}

public enum TimerStatus: String, Codable, CaseIterable, Sendable {
    case stopped = "stopped"
    case running = "running"
    case paused = "paused"
    case timesUp = "timesUp"

    public var displayName: String {
        switch self {
        case .stopped: return "已停止"
        case .running: return "計時中"
        case .paused: return "已暫停"
        case .timesUp: return "時間到"
        }
    }
}

public final class TimerCoordinator: ObservableObject {
    @Published public var mode: TimerMode = .stopwatch
    @Published public var status: TimerStatus = .stopped
    @Published public var elapsedSeconds: Double = 0.0
    @Published public var countdownDuration: Double = 300.0 // 5 minutes default
    @Published public var remainingSeconds: Double = 300.0
    @Published public var isVisible: Bool = false
    @Published public var isCollapsed: Bool = false
    @Published public var panelOffset: CGSize = CGSize(width: 80, height: 160)
    @Published public var didAlertTimesUp: Bool = false

    // Monotonic tracking state
    private var sessionStartUptime: Double = 0.0
    private var accumulatedElapsed: Double = 0.0
    private var timerCancellable: AnyCancellable?

    public init() {}

    // MARK: - Lifecycle & Controls

    public func start() {
        guard status != .running else { return }

        let now = ProcessInfo.processInfo.systemUptime
        sessionStartUptime = now
        status = .running
        didAlertTimesUp = false

        startTicker()
    }

    public func pause() {
        guard status == .running else { return }

        let now = ProcessInfo.processInfo.systemUptime
        accumulatedElapsed += max(0, now - sessionStartUptime)
        status = .paused
        stopTicker()
        updateDisplayTimes()
    }

    public func resume() {
        guard status == .paused else { return }
        start()
    }

    public func reset() {
        stopTicker()
        sessionStartUptime = 0.0
        accumulatedElapsed = 0.0
        elapsedSeconds = 0.0
        remainingSeconds = countdownDuration
        status = .stopped
        didAlertTimesUp = false
    }

    public func togglePlayPause() {
        switch status {
        case .stopped:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        case .timesUp:
            reset()
            start()
        }
    }

    public func setCountdownDuration(seconds: Double) {
        guard seconds > 0, !seconds.isNaN, !seconds.isInfinite else { return }
        countdownDuration = seconds
        if status == .stopped {
            remainingSeconds = seconds
        }
    }

    public func selectPresetMinutes(_ minutes: Int) {
        let secs = Double(minutes * 60)
        mode = .countdown
        reset()
        setCountdownDuration(seconds: secs)
    }

    // MARK: - Time Calculation with Monotonic Clock

    public func updateDisplayTimes(referenceUptime: Double? = nil) {
        let now = referenceUptime ?? ProcessInfo.processInfo.systemUptime
        let currentSession = (status == .running) ? max(0, now - sessionStartUptime) : 0.0
        let totalElapsed = accumulatedElapsed + currentSession
        elapsedSeconds = totalElapsed

        if mode == .countdown {
            let remain = max(0, countdownDuration - totalElapsed)
            remainingSeconds = remain
            if remain <= 0 && status == .running {
                status = .timesUp
                stopTicker()
                if !didAlertTimesUp {
                    didAlertTimesUp = true
                    NSSound.beep()
                }
            }
        }
    }

    private func startTicker() {
        stopTicker()
        // 100ms ticker for smooth visual feedback without flooding CPU
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDisplayTimes()
            }
    }

    private func stopTicker() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Formatting

    public func formattedTimeString() -> String {
        let targetSeconds = (mode == .countdown) ? remainingSeconds : elapsedSeconds
        let total = max(0, Int(targetSeconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let tenths = Int((targetSeconds.truncatingRemainder(dividingBy: 1.0)) * 10)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else if mode == .countdown {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "%02d:%02d.%1d", minutes, seconds, tenths)
        }
    }

    // MARK: - Board Canvas Integration

    @discardableResult
    public func insertTimeToBoard(engine: BoardEngine) -> BoardObject {
        let timeStr = formattedTimeString()
        let prefix = (mode == .countdown) ? "⏳ 倒數計時" : "⏱️ 正計時用時"
        let fullText = "\(prefix)：\(timeStr)"

        let centerScreen = Point(x: Double(engine.canvasSize.width / 2.0), y: Double(engine.canvasSize.height / 2.0))
        let centerWorld = VectorMath.screenToWorld(centerScreen, viewport: engine.viewport)

        let obj = BoardObject(
            type: "text",
            x: centerWorld.x - 80.0,
            y: centerWorld.y - 20.0,
            width: 180.0,
            height: 44.0,
            strokeColor: engine.activeColor,
            fillColor: "none",
            strokeWidth: 2.0,
            text: fullText,
            fontSize: 20.0,
            fontFamily: "Menlo",
            isBold: true,
            pageId: engine.activePageId
        )

        engine.addObject(obj)
        engine.selectedIds = [obj.id]
        engine.showTemporaryStatus("已將用時插入畫布")
        return obj
    }
}
