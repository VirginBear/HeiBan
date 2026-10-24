import AppKit
import HeiBanCore
import SwiftUI

/// 一般與透明畫布共用樣式面板；選取物件與新筆刷使用相同引擎交易入口。
struct ToolbarBrushSettings: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @ObservedObject private var paletteStore = PalettePreferencesStore.shared

    private var style: ToolbarStyleActions { ToolbarStyleActions(engine: engine) }

    @ViewState private var hexInput = ""
    @ViewState private var isManagingPalette = false
    @ViewState private var paletteMessage: String?

    private var currentColor: String { style.selectedStrokeColorForControls }
    private var currentWidth: Double { style.selectedStrokeWidthForControls }
    private var currentOpacity: Double { style.selectedOpacityForControls }

    private var activeLineStyle: String {
        if style.hasSelectedStyleTarget {
            return engine.selectedLineStyle.valueOrNil ?? "solid"
        }
        return engine.activeLineStyle
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                // 1. 常用色盤 (可增刪、管理、還原預設色)
                paletteSection

                // 2. 自訂顏色與 Hex 輸入
                customColorSection

                // 3. 最近使用色彩
                recentColorsSection

                // 4. 線條樣式 (實線 / 虛線 / 點線 / 點劃線)
                lineStyleSection

                // 5. 粗細與不透明度 (非文字、非圖片)
                if !style.hasSelectedStyleTarget || style.hasSelectedStrokeTarget {
                    strokeGeometrySection
                }

                // 6. 填色、填色不透明度與漸層 (幾何圖形或便籤)
                if style.hasSelectedFillTarget {
                    fillSection
                }

                // 7. 箭頭大小
                if style.hasSelectedArrowTarget {
                    arrowSettingsSection
                }

                // 8. 線段延伸
                if style.hasSelectedLineOrArrowTarget {
                    lineExtensionSection
                }

                if !style.hasSelectedStyleTarget { brushPreview }
            }
            .padding(16)
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
        .frame(width: 284)
        .frame(maxHeight: 520)
        .onAppear {
            hexInput = currentColor
        }
    }

    // MARK: - Sections

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
                                style.setColor(color)
                                hexInput = color
                                paletteMessage = nil
                            } label: {
                                Circle().fill(Color(hex: color)).frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                    .overlay(Circle().stroke(Color.accentColor, lineWidth: currentColor.lowercased() == color.lowercased() ? 2.5 : 0).padding(-3))
                                    .frame(width: 32, height: 32).contentShape(Rectangle())
                            }
                            .help("註記顏色 \(color)")
                            .accessibilityLabel("註記顏色 \(color)")
                            .contextMenu {
                                Button(L10n.t("移除顏色")) {
                                    paletteStore.remove(color)
                                }
                            }

                            if isManagingPalette {
                                Button {
                                    paletteStore.remove(color)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help(L10n.t("移除此顏色"))
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    let canon = PalettePreferencesStore.canonical(currentColor) ?? currentColor
                    if paletteStore.add(canon) {
                        paletteMessage = nil
                    } else {
                        paletteMessage = L10n.t("此顏色已在常用色")
                    }
                } label: {
                    Label(L10n.t("新增目前顏色"), systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(L10n.t("還原預設色")) {
                    paletteStore.reset()
                    paletteMessage = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let message = paletteMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
    private var brushPreview: some View {
        let diameter = engine.activeBrushWidth * engine.viewport.zoom
        let clampedDiameter = min(76.0, max(2.0, diameter))
        return VStack(alignment: .leading, spacing: 5) {
            Text("實際大小 · 畫布上直徑 \(diameter.formatted(.number.precision(.fractionLength(0...1)))) pt")
                .font(.caption).foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .fill(Color(hex: engine.activeColor).opacity(style.selectedOpacityForControls))
                    .frame(width: clampedDiameter, height: clampedDiameter)
            }
            .frame(width: 252, height: 84)
            .clipped()
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(L10n.t("與目前畫布縮放相同的筆刷尺寸預覽"))
        }
    }

    private var headerSection: some View {
        HStack {
            Text(L10n.t("顏色與樣式")).font(.headline)
            Spacer()
            if style.hasSelectedStyleTarget {
                Text("\(engine.selectedObjects.count) 個選取物件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
    }


    private var customColorSection: some View {
        HStack(spacing: 8) {
            ColorPicker(L10n.t("自訂"), selection: Binding(
                get: { Color(hex: currentColor) },
                set: {
                    let hex = Self.hexString($0)
                    style.setColor(hex)
                    hexInput = hex
                }
            ), supportsOpacity: false)
            .labelsHidden()

            TextField("#RRGGBB", text: $hexInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 90)
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

    private var recentColorsSection: some View {
        Group {
            if !engine.recentColors.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("最近使用")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(engine.recentColors.prefix(8), id: \.self) { color in
                            Button {
                                style.setColor(color)
                                hexInput = color
                            } label: {
                                Circle().fill(Color(hex: color)).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.gray.opacity(0.35), lineWidth: 1))
                                    .overlay(Circle().stroke(Color.accentColor, lineWidth: currentColor.lowercased() == color.lowercased() ? 2 : 0).padding(-2))
                                    .frame(width: 24, height: 24).contentShape(Rectangle())
                            }
                            .help("使用色彩 \(color)")
                        }
                    }
                }
            }
        }
    }

    private var lineStyleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.t("線條樣式")).font(.system(size: 11, weight: .semibold))
                Spacer()
                if style.hasSelectedStyleTarget && engine.selectedLineStyle.isMixed {
                    Text(L10n.t("混合樣式")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Picker("", selection: Binding(
                get: { activeLineStyle },
                set: { style.setLineStyle($0) }
            )) {
                Text(L10n.t("實線")).tag("solid")
                Text(L10n.t("虛線")).tag("dashed")
                Text(L10n.t("點線")).tag("dotted")
                Text(L10n.t("點劃線")).tag("dashDot")
            }
            .pickerStyle(.segmented)
        }
    }

    private var strokeGeometrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 5) {
                HStack {
                    Text(L10n.t("粗細"))
                    Spacer()
                    Text("\(currentWidth, specifier: "%.1f") pt").monospacedDigit()
                }
                Slider(value: Binding(get: { currentWidth }, set: style.setWidth), in: 1...64)
                    .accessibilityLabel(L10n.t("線條粗細"))
            }
            VStack(spacing: 5) {
                HStack {
                    Text(L10n.t("不透明度"))
                    Spacer()
                    Text("\(Int(currentOpacity * 100))%").monospacedDigit()
                }
                Slider(value: Binding(get: { currentOpacity }, set: style.setOpacity), in: 0.1...1)
                    .accessibilityLabel(L10n.t("線條透明度"))
            }
        }
    }

    private var fillSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text(L10n.t("填色")).font(.system(size: 11, weight: .semibold))
                Spacer()
                if style.hasSelectedStyleTarget && engine.selectedFillColor.isMixed {
                    Text(L10n.t("混合填色")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Button {
                    style.setFillColor("none")
                } label: {
                    Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        .background(Circle().fill(Color.clear))
                        .frame(width: 20, height: 20)
                        .overlay(Image(systemName: "slash.circle").font(.system(size: 12)).foregroundStyle(.secondary))
                }
                .help(L10n.t("無填色"))

                let fillSwatches = paletteStore.colors.isEmpty ? PalettePreferencesStore.defaultColors : paletteStore.colors
                ForEach(fillSwatches.prefix(4), id: \.self) { hex in
                    Button {
                        style.setFillColor(hex)
                    } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: (engine.selectedFillColor.valueOrNil ?? "").lowercased() == hex.lowercased() ? 2 : 0).padding(-2))
                    }
                    .help("填色 \(hex)")
                }

                ColorPicker(L10n.t("自訂填色"), selection: Binding(
                    get: { Color(hex: engine.selectedFillColor.valueOrNil ?? "#3b82f6") },
                    set: { color in
                        let hex = Self.hexString(color)
                        style.setFillColor(hex)
                    }
                ), supportsOpacity: false)
                .labelsHidden()
            }

            // 填色不透明度
            VStack(spacing: 4) {
                HStack {
                    Text(L10n.t("填色透明度")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((engine.selectedFillOpacity.valueOrNil ?? 1.0) * 100))%").font(.caption).monospacedDigit()
                }
                Slider(value: Binding(
                    get: { engine.selectedFillOpacity.valueOrNil ?? 1.0 },
                    set: { style.setFillOpacity($0) }
                ), in: 0...1)
            }

            // 漸層填色
            if style.hasSelectedStyleTarget {
                HStack(spacing: 8) {
                    Button {
                        engine.toggleSelectedGradient()
                    } label: {
                        Label(engine.selectedGradientEnabled ? "停用漸層" : "漸層填色", systemImage: "paintpalette")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if engine.selectedGradientEnabled {
                        ColorPicker(L10n.t("起點"), selection: Binding(
                            get: { Color(hex: engine.selectedGradientStart) },
                            set: { engine.setSelectedGradientColors(start: Self.hexString($0), end: engine.selectedGradientEnd) }
                        )).labelsHidden().help(L10n.t("漸層起點"))
                        ColorPicker(L10n.t("終點"), selection: Binding(
                            get: { Color(hex: engine.selectedGradientEnd) },
                            set: { engine.setSelectedGradientColors(start: engine.selectedGradientStart, end: Self.hexString($0)) }
                        )).labelsHidden().help(L10n.t("漸層終點"))
                    }
                }
            }
        }
    }

    private var arrowSettingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(L10n.t("箭頭大小")).font(.system(size: 11, weight: .semibold))
            HStack {
                Text(L10n.t("長度"))
                Slider(value: Binding(
                    get: { engine.selectedArrowHeadLength.valueOrNil ?? 16.0 },
                    set: { style.setArrowHeadLength($0) }
                ), in: 4...64)
                Text("\(Int(engine.selectedArrowHeadLength.valueOrNil ?? 16.0))").monospacedDigit().frame(width: 24)
            }
            HStack {
                Text(L10n.t("寬度"))
                Slider(value: Binding(
                    get: { engine.selectedArrowHeadWidth.valueOrNil ?? 10.0 },
                    set: { style.setArrowHeadWidth($0) }
                ), in: 4...48)
                Text("\(Int(engine.selectedArrowHeadWidth.valueOrNil ?? 10.0))").monospacedDigit().frame(width: 24)
            }
        }
    }

    private var lineExtensionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text(L10n.t("線段延伸")).font(.system(size: 11, weight: .semibold))
                Spacer()
                if engine.selectedLineExtension.isMixed {
                    Text(L10n.t("混合")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Picker("", selection: Binding(
                get: { engine.selectedLineExtension.valueOrNil ?? .none },
                set: { style.setLineExtension($0) }
            )) {
                ForEach(LineExtension.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Helpers

    private func applyHexInput() {
        var clean = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("#") { clean = "#" + clean }
        let hexDigits = clean.dropFirst()
        if hexDigits.count == 6 && hexDigits.allSatisfy({ $0.isHexDigit }) {
            style.setColor(clean)
            hexInput = clean
        }
    }

    private static func hexString(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return "#ef4444" }
        return String(
            format: "#%02X%02X%02X",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }
}

/// 跨畫布共享樣式命令：有選取時只改所選物件，沒有選取時只改之後落筆的預設。
/// 不直接修改 board.objects，讓 Undo、鎖定及文件保存沿用核心規則。
private struct ToolbarStyleActions {
    let engine: BoardEngine
    var hasSelectedStyleTarget: Bool { !engine.selectedObjects.isEmpty }
    var selectedStrokeColorForControls: String {
        engine.selectedStrokeColor.valueOrNil ?? engine.selectedObjects.first?.strokeColor
            ?? engine.activeColor
    }
    var selectedStrokeWidthForControls: Double {
        engine.selectedStrokeWidth.valueOrNil ?? engine.selectedObjects.first?.strokeWidth
            ?? engine.activeStrokeWidth
    }
    var selectedOpacityForControls: Double {
        engine.selectedOpacity.valueOrNil ?? engine.selectedObjects.first?.opacity
            ?? (engine.currentTool == .highlighter ? engine.activeHighlighterOpacity : engine.activeOpacity)
    }

    var hasSelectedStrokeTarget: Bool {
        engine.selectedObjects.contains(where: { $0.type != "text" && $0.type != "image" })
    }
    var hasSelectedFillTarget: Bool {
        engine.selectedObjects.contains(where: {
            ["rect", "circle", "ellipse", "triangle", "quadrilateral", "diamond", "star", "sticky"].contains($0.type)
        })
    }
    var hasSelectedArrowTarget: Bool {
        engine.selectedObjects.contains(where: { $0.type == "arrow" })
    }
    var hasSelectedLineOrArrowTarget: Bool {
        engine.selectedObjects.contains(where: { $0.type == "line" || $0.type == "arrow" })
    }

    func setColor(_ color: String) {
        if hasSelectedStyleTarget {
            engine.setSelectedStrokeColor(color)
            engine.registerRecentColor(color)
            return
        }
        engine.updateCurrentToolStyle(color: color)
        engine.registerRecentColor(color)
    }
    func setWidth(_ width: Double) {
        if hasSelectedStyleTarget {
            engine.setSelectedStrokeWidth(width)
            return
        }
        engine.activeStrokeWidth = width
    }
    func setOpacity(_ opacity: Double) {
        if hasSelectedStyleTarget {
            engine.setSelectedOpacity(opacity)
            return
        }
        if engine.currentTool == .highlighter { engine.activeHighlighterOpacity = opacity }
        else { engine.activeOpacity = opacity }
    }
    func setLineStyle(_ style: String) {
        if hasSelectedStyleTarget {
            engine.setSelectedLineStyle(style)
            return
        }
        engine.activeLineStyle = style
    }
    func setFillColor(_ color: String) {
        if hasSelectedStyleTarget {
            engine.setSelectedFillColor(color)
        }
    }
    func setFillOpacity(_ opacity: Double) {
        if hasSelectedStyleTarget {
            engine.setSelectedFillOpacity(opacity)
        }
    }
    func setArrowHeadLength(_ length: Double) {
        if hasSelectedStyleTarget {
            engine.setSelectedArrowHeadLength(length)
        }
    }
    func setArrowHeadWidth(_ width: Double) {
        if hasSelectedStyleTarget {
            engine.setSelectedArrowHeadWidth(width)
        }
    }
    func setLineExtension(_ mode: LineExtension) {
        if hasSelectedStyleTarget {
            engine.setSelectedLineExtension(mode)
        }
    }

}
