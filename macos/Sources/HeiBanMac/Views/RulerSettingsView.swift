import SwiftUI
import AppKit
import HeiBanCore

struct RulerSettingsView: View {
    let engine: BoardEngine
    @ObservedObject private var rulerStore: RulerStateStore
    @AppStorage("HeiBan.rulerColorMode") private var colorMode = "adaptive"
    @AppStorage("HeiBan.rulerLabelColor") private var customColor = "#FFFFFF"
    @ViewState private var angleText = ""
    @ViewState private var angleError: String?
    @FocusState private var editingAngle: Bool
    @Environment(\.dismiss) private var dismiss

    init(engine: BoardEngine) {
        self.engine = engine
        _rulerStore = ObservedObject(wrappedValue: engine.rulerStore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("尺規設定").font(.headline)
                Spacer()
                Button("關閉") { dismiss() }
            }
            HStack {
                Text("角度")
                TextField("例如 12.5", text: $angleText)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .focused($editingAngle)
                    .onSubmit(applyAngle)
                    .accessibilityLabel("尺規角度，精度零點一度")
                Text("°")
                Button("套用", action: applyAngle)
            }
            HStack {
                Button("−0.1°") { adjustAngle(-0.1) }
                Button("+0.1°") { adjustAngle(0.1) }
                Spacer()
                Button("水平 0.0°") {
                    engine.setRulerAngle(0)
                    syncAngle()
                }
            }
            if let angleError {
                Text(angleError).font(.caption).foregroundStyle(.red)
            }
            Text("輸入後按 Return 套用。支援負角度，旋轉仍以選定的固定點為中心。")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Picker("配色", selection: $colorMode) {
                Text("自適應（預設）").tag("adaptive")
                Text("自訂刻度與文字").tag("custom")
            }
            if colorMode == "custom" {
                ColorPicker("刻度與角度文字", selection: Binding(
                    get: { Color(hex: customColor) },
                    set: { color in
                        guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                        customColor = String(format: "#%02X%02X%02X", Int(round(rgb.redComponent * 255)), Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255)))
                    }
                ), supportsOpacity: false)
            }
            Text("白底使用深色刻度，暗底使用淺色刻度；尺身與角度底色也會一起調整。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("尺身透明度")
                Slider(value: Binding(get: { rulerStore.state.opacity }, set: { engine.ruler.opacity = $0 }), in: 0.12...0.75)
            }
            .font(.caption)
        }
        .padding(18).frame(width: 330)
        .onAppear(perform: syncAngle)
        .onChange(of: rulerStore.state.angle) { _, _ in
            if !editingAngle { syncAngle() }
        }
    }

    private func parsedAngle() -> Double? {
        let text = angleText.replacingOccurrences(of: "°", with: "").replacingOccurrences(of: "−", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(text), value.isFinite else { return nil }
        return value
    }

    private func applyAngle() {
        guard let value = parsedAngle() else {
            angleError = "請輸入有效角度，例如 12.5 或 −30.0。"
            return
        }
        engine.setRulerAngle(value)
        syncAngle()
    }

    private func adjustAngle(_ delta: Double) {
        guard let value = parsedAngle() else { applyAngle(); return }
        engine.setRulerAngle(value + delta)
        syncAngle()
    }

    private func syncAngle() {
        angleText = String(format: "%.1f", rulerStore.state.angle)
        angleError = nil
    }
}
