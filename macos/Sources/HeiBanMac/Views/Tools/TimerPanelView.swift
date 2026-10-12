import SwiftUI
import HeiBanCore

public struct TimerPanelView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var coordinator: TimerCoordinator
    @ObservedObject var engine: BoardEngine

    let workspaceSize: CGSize

    public init(coordinator: TimerCoordinator, engine: BoardEngine, workspaceSize: CGSize) {
        self.coordinator = coordinator
        self.engine = engine
        self.workspaceSize = workspaceSize
    }

    public var body: some View {
        if coordinator.isVisible {
            FloatingToolPanel(title: "計時器", symbol: "timer",
                              width: 250, workspaceSize: workspaceSize,
                              offset: $coordinator.panelOffset, isCollapsed: $coordinator.isCollapsed,
                              isVisible: $coordinator.isVisible) {
                VStack(spacing: 0) {
                    modePicker
                    timeDisplayView
                    if coordinator.mode == .countdown { presetsRow }
                    Divider().padding(.vertical, 8)
                    actionControls
                }
            }
        }
    }

    // MARK: - Mode Picker
    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimerMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        coordinator.mode = mode
                        coordinator.reset()
                    }
                } label: {
                    Text(mode.displayName)
                        .font(.system(size: 11, weight: coordinator.mode == mode ? .bold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            coordinator.mode == mode ? Color.accentColor.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(coordinator.mode == mode ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }

    // MARK: - Big Time Display
    private var timeDisplayView: some View {
        VStack(spacing: 2) {
            if coordinator.status == .timesUp {
                Text(L10n.t("⏰ 時間到！"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            Text(coordinator.formattedTimeString())
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(coordinator.status == .timesUp ? Color.red : Color.primary)
                .contentTransition(.numericText())
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Countdown Presets
    private var presetsRow: some View {
        HStack(spacing: 6) {
            presetButton(minutes: 5, label: "5 分")
            presetButton(minutes: 15, label: "15 分")
            presetButton(minutes: 25, label: "25 分")
        }
        .padding(.top, 6)
    }

    private func presetButton(minutes: Int, label: String) -> some View {
        Button {
            coordinator.selectPresetMinutes(minutes)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(
                    coordinator.countdownDuration == Double(minutes * 60)
                        ? Color.accentColor.opacity(0.15)
                        : Color.primary.opacity(0.05),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Controls
    private var actionControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Play / Pause Button
                Button {
                    coordinator.togglePlayPause()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: coordinator.status == .running ? "pause.fill" : "play.fill")
                        Text(coordinator.status == .running ? "暫停" : (coordinator.status == .paused ? "續行" : "開始"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(coordinator.status == .running ? Color.orange.opacity(0.2) : Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(coordinator.status == .running ? Color.orange : Color.white)
                }
                .buttonStyle(.plain)

                // Reset Button
                Button {
                    coordinator.reset()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(L10n.t("重設"))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // Insert to Canvas Button
            Button {
                coordinator.insertTimeToBoard(engine: engine)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "text.insert")
                    Text(L10n.t("插入用時至畫布"))
                }
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(L10n.t("將當前計時器用時插入黑板為可編輯文字物件"))
        }
    }
}
