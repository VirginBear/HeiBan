import AppKit
import HeiBanCore
import SwiftUI

/// 四邊工具列共用的樣式面板；只綁定目前螢幕的 engine，不污染其他顯示器。
struct AnnotationBrushSettings: View {
    @ObservedObject var controller: ScreenAnnotationController
    @ObservedObject var engine: BoardEngine

    @ViewState private var hexInput = ""

    private let colors = ["#ef4444", "#f59e0b", "#22c55e", "#3b82f6", "#ffffff", "#111827"]
    private var currentColor: String { controller.selectedStrokeColorForControls }
    private var currentWidth: Double { controller.selectedStrokeWidthForControls }
    private var currentOpacity: Double { controller.selectedOpacityForControls }

    private var activeLineStyle: String {
        if controller.hasSelectedStyleTarget {
            return engine.selectedLineStyle.valueOrNil ?? "solid"
        }
        return engine.activeLineStyle
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                // 1. 筆刷／線條色彩與預設色票
                strokeColorSection

                // 2. 自訂顏色與 Hex 輸入
                customColorSection

                // 3. 最近使用色彩
                recentColorsSection

                // 4. 線條樣式 (實線 / 虛線 / 點線 / 點劃線)
                lineStyleSection

                // 5. 粗細與不透明度 (非文字、非圖片)
                if !controller.hasSelectedStyleTarget || controller.hasSelectedStrokeTarget {
                    strokeGeometrySection
                }

                // 6. 填色、填色不透明度與漸層 (幾何圖形或便籤)
                if !controller.hasSelectedStyleTarget || controller.hasSelectedFillTarget {
                    fillSection
                }

                // 7. 箭頭大小
                if controller.hasSelectedArrowTarget {
                    arrowSettingsSection
                }

                // 8. 線段延伸
                if controller.hasSelectedLineOrArrowTarget {
                    lineExtensionSection
                }

                Text(controller.message).font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var headerSection: some View {
        HStack {
            Text("顏色與樣式").font(.headline)
            Spacer()
            if controller.hasSelectedStyleTarget {
                Text("\(engine.selectedObjects.count) 個選取物件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
    }

    private var strokeColorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("線條顏色").font(.system(size: 11, weight: .semibold))
                Spacer()
                if controller.hasSelectedStyleTarget && engine.selectedStrokeColor.isMixed {
                    Text("混合顏色").font(.caption2).foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        controller.setColor(color)
                        hexInput = color
                    } label: {
                        Circle().fill(Color(hex: color)).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: currentColor.lowercased() == color.lowercased() ? 2.5 : 0).padding(-3))
                            .frame(width: 32, height: 32).contentShape(Rectangle())
                    }
                    .help("註記顏色 \(color)")
                    .accessibilityLabel("註記顏色 \(color)")
                }
            }
        }
    }

    private var customColorSection: some View {
        HStack(spacing: 8) {
            ColorPicker("自訂", selection: Binding(
                get: { Color(hex: currentColor) },
                set: {
                    let hex = Self.hexString($0)
                    controller.setColor(hex)
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

            Button("套用") {
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
                    Text("最近使用").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(engine.recentColors.prefix(8), id: \.self) { color in
                            Button {
                                controller.setColor(color)
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
                Text("線條樣式").font(.system(size: 11, weight: .semibold))
                Spacer()
                if controller.hasSelectedStyleTarget && engine.selectedLineStyle.isMixed {
                    Text("混合樣式").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Picker("", selection: Binding(
                get: { activeLineStyle },
                set: { controller.setLineStyle($0) }
            )) {
                Text("實線").tag("solid")
                Text("虛線").tag("dashed")
                Text("點線").tag("dotted")
                Text("點劃線").tag("dashDot")
            }
            .pickerStyle(.segmented)
        }
    }

    private var strokeGeometrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 5) {
                HStack {
                    Text("粗細")
                    Spacer()
                    Text("\(currentWidth, specifier: "%.1f") pt").monospacedDigit()
                }
                Slider(value: Binding(get: { currentWidth }, set: controller.setWidth), in: 1...32)
                    .accessibilityLabel("線條粗細")
            }
            VStack(spacing: 5) {
                HStack {
                    Text("不透明度")
                    Spacer()
                    Text("\(Int(currentOpacity * 100))%").monospacedDigit()
                }
                Slider(value: Binding(get: { currentOpacity }, set: controller.setOpacity), in: 0.1...1)
                    .accessibilityLabel("線條透明度")
            }
        }
    }

    private var fillSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text("填色").font(.system(size: 11, weight: .semibold))
                Spacer()
                if controller.hasSelectedStyleTarget && engine.selectedFillColor.isMixed {
                    Text("混合填色").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Button {
                    controller.setFillColor("none")
                } label: {
                    Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        .background(Circle().fill(Color.clear))
                        .frame(width: 20, height: 20)
                        .overlay(Image(systemName: "slash.circle").font(.system(size: 12)).foregroundStyle(.secondary))
                }
                .help("無填色")

                ForEach(colors.prefix(4), id: \.self) { hex in
                    Button {
                        controller.setFillColor(hex)
                    } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: (engine.selectedFillColor.valueOrNil ?? "").lowercased() == hex.lowercased() ? 2 : 0).padding(-2))
                    }
                    .help("填色 \(hex)")
                }

                ColorPicker("自訂填色", selection: Binding(
                    get: { Color(hex: engine.selectedFillColor.valueOrNil ?? "#3b82f6") },
                    set: { color in
                        let hex = Self.hexString(color)
                        controller.setFillColor(hex)
                    }
                ), supportsOpacity: false)
                .labelsHidden()
            }

            // 填色不透明度
            VStack(spacing: 4) {
                HStack {
                    Text("填色透明度").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((engine.selectedFillOpacity.valueOrNil ?? 1.0) * 100))%").font(.caption).monospacedDigit()
                }
                Slider(value: Binding(
                    get: { engine.selectedFillOpacity.valueOrNil ?? 1.0 },
                    set: { controller.setFillOpacity($0) }
                ), in: 0...1)
            }

            // 漸層填色
            if controller.hasSelectedStyleTarget {
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
                        ColorPicker("起點", selection: Binding(
                            get: { Color(hex: engine.selectedGradientStart) },
                            set: { engine.setSelectedGradientColors(start: Self.hexString($0), end: engine.selectedGradientEnd) }
                        )).labelsHidden().help("漸層起點")
                        ColorPicker("終點", selection: Binding(
                            get: { Color(hex: engine.selectedGradientEnd) },
                            set: { engine.setSelectedGradientColors(start: engine.selectedGradientStart, end: Self.hexString($0)) }
                        )).labelsHidden().help("漸層終點")
                    }
                }
            }
        }
    }

    private var arrowSettingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("箭頭大小").font(.system(size: 11, weight: .semibold))
            HStack {
                Text("長度")
                Slider(value: Binding(
                    get: { engine.selectedArrowHeadLength.valueOrNil ?? 16.0 },
                    set: { controller.setArrowHeadLength($0) }
                ), in: 4...64)
                Text("\(Int(engine.selectedArrowHeadLength.valueOrNil ?? 16.0))").monospacedDigit().frame(width: 24)
            }
            HStack {
                Text("寬度")
                Slider(value: Binding(
                    get: { engine.selectedArrowHeadWidth.valueOrNil ?? 10.0 },
                    set: { controller.setArrowHeadWidth($0) }
                ), in: 4...48)
                Text("\(Int(engine.selectedArrowHeadWidth.valueOrNil ?? 10.0))").monospacedDigit().frame(width: 24)
            }
        }
    }

    private var lineExtensionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text("線段延伸").font(.system(size: 11, weight: .semibold))
                Spacer()
                if engine.selectedLineExtension.isMixed {
                    Text("混合").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Picker("", selection: Binding(
                get: { engine.selectedLineExtension.valueOrNil ?? .none },
                set: { controller.setLineExtension($0) }
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
            controller.setColor(clean)
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
