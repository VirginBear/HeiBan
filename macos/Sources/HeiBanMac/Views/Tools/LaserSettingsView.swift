import SwiftUI
import HeiBanCore

struct LaserSettingsView: View {
    @ObservedObject var laser: LaserPointerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("雷射筆設定").font(.headline)
            Picker("指示方式", selection: $laser.mode) {
                Text("光點").tag(LaserMode.point)
                Text("短尾跡").tag(LaserMode.shortTrail)
                Text("線條").tag(LaserMode.line)
            }.pickerStyle(.segmented)
            HStack {
                Text("光點大小")
                Spacer()
                Text("\(Int(laser.pointDiameter)) pt").monospacedDigit()
                Circle().fill(Color(hex: laser.color))
                    .frame(width: laser.pointDiameter, height: laser.pointDiameter)
                    .frame(width: 64, height: 64)
            }
            Slider(value: $laser.pointDiameter, in: 4...64, step: 1)
                .accessibilityLabel("雷射光點大小")
            Text("光點以螢幕大小顯示，不受畫布縮放影響。")
                .font(.caption).foregroundStyle(.secondary)
            if laser.mode != .point {
                HStack {
                    Text("尾跡粗細")
                    Spacer()
                    Text("\(Int(laser.width)) pt").monospacedDigit()
                }
                Slider(value: $laser.width, in: 1...24, step: 1)
                    .accessibilityLabel("雷射尾跡粗細")
                HStack {
                    Text("消退時間")
                    Spacer()
                    Text(String(format: "%.1f 秒", laser.fadeDuration)).monospacedDigit()
                }
                Slider(value: $laser.fadeDuration, in: 0.2...(laser.mode == .shortTrail ? 0.8 : 3), step: 0.1)
                    .accessibilityLabel("雷射消退時間")
            }
            HStack(spacing: 10) {
                Text("光點顏色")
                Spacer()
                ForEach(["#ef4444", "#22c55e", "#3b82f6", "#f59e0b", "#d946ef"], id: \.self) { hex in
                    Button { laser.color = hex } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.primary, lineWidth: laser.color == hex ? 2 : 0))
                    }.buttonStyle(.plain).accessibilityLabel("雷射色彩 \(hex)")
                }
            }
            Toggle("白色亮芯", isOn: $laser.hasWhiteCore)
            Text("移動滑鼠即可指示，拖曳也會留下暫時尾跡。選取「光點」時不顯示尾跡；切換其他工具可停止。雷射不會加入作品或匯出檔案。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 310)
    }
}
