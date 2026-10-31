import AppKit
import SwiftUI
import HeiBanCore

struct LaserSettingsView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var laser: LaserPointerEngine
    @ObservedObject private var paletteStore = PalettePreferencesStore.shared

    @ViewState private var hexInput = ""
    @ViewState private var isManagingPalette = false
    @ViewState private var paletteMessage: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("雷射筆設定")).font(.headline)
                Picker(L10n.t("指示方式"), selection: $laser.mode) {
                    Text(L10n.t("光點")).tag(LaserMode.point)
                    Text(L10n.t("短尾跡")).tag(LaserMode.shortTrail)
                    Text(L10n.t("線條")).tag(LaserMode.line)
                }.pickerStyle(.segmented)
                HStack {
                    Text(L10n.t("光點大小"))
                    Spacer()
                    Text("\(Int(laser.pointDiameter)) pt").monospacedDigit()
                    Circle().fill(Color(hex: laser.color))
                        .frame(width: laser.pointDiameter, height: laser.pointDiameter)
                        .frame(width: 64, height: 64)
                }
                Slider(value: $laser.pointDiameter, in: 4...64, step: 1)
                    .accessibilityLabel(L10n.t("雷射光點大小"))
                Text(L10n.t("光點以螢幕大小顯示，不受畫布縮放影響。"))
                    .font(.caption).foregroundStyle(.secondary)
                if laser.mode != .point {
                    HStack {
                        Text(L10n.t("尾跡粗細"))
                        Spacer()
                        Text("\(Int(laser.width)) pt").monospacedDigit()
                    }
                    Slider(value: $laser.width, in: 1...24, step: 1)
                        .accessibilityLabel(L10n.t("雷射尾跡粗細"))
                    HStack {
                        Text(L10n.t("消退時間"))
                        Spacer()
                        Text(String(format: "%.1f 秒", laser.fadeDuration)).monospacedDigit()
                    }
                    Slider(value: $laser.fadeDuration, in: 0.2...(laser.mode == .shortTrail ? 0.8 : 3), step: 0.1)
                        .accessibilityLabel(L10n.t("雷射消退時間"))
                }

                Divider()
                paletteSection
                customColorSection

                Toggle(L10n.t("白色亮芯"), isOn: $laser.hasWhiteCore)
                Text(L10n.t("按住滑鼠左鍵並移動即可指示，放開左鍵立即消失。選取「光點」時不顯示尾跡；切換其他工具可停止。雷射不會加入作品或匯出檔案。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .font(.system(size: 12))
        .frame(width: 310)
        .frame(maxHeight: 520)
        .onAppear { hexInput = laser.color }
        .onChange(of: laser.color) { _, color in hexInput = color }
    }

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.t("常用色")).font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(L10n.t(isManagingPalette ? "完成" : "管理")) {
                    isManagingPalette.toggle()
                    paletteMessage = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(paletteStore.loadFailed)
            }

            if paletteStore.colors.isEmpty {
                Text(L10n.t("尚無常用色，調色後按＋新增。"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(paletteStore.colors, id: \.self) { color in
                        VStack(spacing: 2) {
                            Button {
                                laser.color = color
                                hexInput = color
                                paletteMessage = nil
                            } label: {
                                Circle().fill(Color(hex: color)).frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                    .overlay(Circle().stroke(Color.accentColor, lineWidth: PalettePreferencesStore.canonical(laser.color) == color ? 2.5 : 0).padding(-3))
                                    .frame(width: 32, height: 32).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("\(L10n.t("套用顏色")) \(color)")
                            .contextMenu {
                                Button(L10n.t("移除顏色")) {
                                    updatePalette { paletteStore.remove(color) }
                                }.disabled(paletteStore.loadFailed)
                            }

                            if isManagingPalette {
                                Button {
                                    updatePalette { paletteStore.remove(color) }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help(L10n.t("移除顏色"))
                                .disabled(paletteStore.loadFailed)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    updatePalette(duplicateMessage: true) { paletteStore.add(laser.color) }
                } label: {
                    Label(L10n.t("新增目前顏色"), systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(paletteStore.loadFailed)

                Button(L10n.t("還原預設色")) {
                    updatePalette { paletteStore.reset() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(paletteStore.loadFailed)
            }

            if let message = paletteStore.loadFailed ? L10n.t("常用色未載入，原設定檔已保留。") : paletteMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var customColorSection: some View {
        HStack(spacing: 8) {
            ColorPicker(L10n.t("自訂"), selection: Binding(
                get: { Color(hex: laser.color) },
                set: {
                    let hex = Self.hexString($0)
                    laser.color = hex
                    hexInput = hex
                }
            ), supportsOpacity: true)
            .labelsHidden()

            TextField("#RRGGBB[AA]", text: $hexInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 96)
                .onSubmit {
                    applyHexInput()
                }

            Button(L10n.t("套用")) {
                applyHexInput()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func applyHexInput() {
        var clean = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("#") { clean = "#" + clean }
        guard let canonical = PalettePreferencesStore.canonical(clean) else {
            paletteMessage = L10n.t("請輸入 #RRGGBB 或 #RRGGBBAA。")
            return
        }
        laser.color = canonical
        hexInput = canonical
        paletteMessage = nil
    }

    private func updatePalette(duplicateMessage: Bool = false, _ change: () -> Bool) {
        if change() { paletteMessage = nil; return }
        switch paletteStore.lastFailure {
        case .unavailable: paletteMessage = L10n.t("常用色未載入，原設定檔已保留。")
        case .writeFailed: paletteMessage = L10n.t("常用色保存失敗，請重試。")
        case .invalidColor: paletteMessage = L10n.t("請輸入 #RRGGBB 或 #RRGGBBAA。")
        case nil: paletteMessage = duplicateMessage ? L10n.t("此顏色已在常用色") : nil
        }
    }

    private static func hexString(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#EF4444" }
        func byte(_ component: CGFloat) -> Int { min(255, max(0, Int((component * 255).rounded()))) }
        let hex = String(format: "#%02X%02X%02X%02X",
            byte(rgb.redComponent), byte(rgb.greenComponent), byte(rgb.blueComponent), byte(rgb.alphaComponent))
        return PalettePreferencesStore.canonical(hex) ?? "#EF4444"
    }
}
