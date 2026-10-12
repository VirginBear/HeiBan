import AppKit
import HeiBanCore
import SwiftUI

public struct InspectorView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine

    private let horizontal: Bool
    private let onDragChanged: ((DragGesture.Value) -> Void)?
    private let onDragEnded: ((DragGesture.Value) -> Void)?

    public init(
        engine: BoardEngine, horizontal: Bool = false,
        onDragChanged: ((DragGesture.Value) -> Void)? = nil,
        onDragEnded: ((DragGesture.Value) -> Void)? = nil
    ) {
        self.engine = engine
        self.horizontal = horizontal
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    private let standardColors = [
        "#86efac",  // Chalk green
        "#fde047",  // Pastel yellow
        "#f97316",  // Vibrant orange
        "#fb7185",  // Coral pink
        "#60a5fa",  // Sky blue
        "#c084fc",  // Lavender
        "#ffffff",  // Chalk white
        "#1e293b",  // Slate dark
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            if engine.selectedIds.isEmpty {
                if horizontal {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.t("選取物件後調整屬性")).font(.subheadline.bold())
                            Text(L10n.t("色彩、線條、透明度與旋轉會分區顯示。")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.frame(maxHeight: .infinity)
                } else {
                    emptyState
                }
            } else {
                selectionSummary
                if horizontal {
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 18) {
                            ScrollView(.vertical) { colorsColumn }.frame(width: 248)
                            ScrollView(.vertical) { lineColumn }.frame(width: 248)
                            ScrollView(.vertical) { objectColumn }.frame(width: 248)
                        }
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            colorsColumn
                            Divider()
                            lineColumn
                            Divider()
                            objectColumn
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    private var header: some View {
        HStack {
            HStack {
                Label(L10n.t("屬性檢查器"), systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .frame(height: 26)
            .contentShape(Rectangle())
            .help(L10n.t("拖曳標題到視窗上下左右停靠"))
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named("HeiBan.workspace"))
                    .onChanged { onDragChanged?($0) }
                    .onEnded { onDragEnded?($0) })
            Button {
                engine.showInspector = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 2)

    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 12)
            Image(systemName: "hand.tap")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
            Text(L10n.t("未選取任何物件"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Text(L10n.t("在畫布上點選或框選物件，即可即時調整線條、填色、粗細與延伸方向。"))
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
            Spacer().frame(height: 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var selectionSummary: some View {
        // Selection summary
        HStack {
            Text("已選取 \(engine.selectedIds.count) 個物件")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            if engine.selectedIds.count >= 2 {
                Button(L10n.t("群組")) {
                    engine.groupSelected()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if engine.selectedObjects.contains(where: { $0.groupId != nil }) {
                Button(L10n.t("解組")) {
                    engine.ungroupSelected()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }

    }

    private var colorsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Stroke Color
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.t("線條色彩"))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if engine.selectedStrokeColor.isMixed {
                        Text(L10n.t("混合色彩"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    ForEach(standardColors, id: \.self) { hex in
                        Button {
                            engine.setSelectedStrokeColor(hex)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.primary.opacity(
                                                engine.selectedStrokeColor.valueOrNil == hex ? 0.9 : 0.2),
                                            lineWidth: engine.selectedStrokeColor.valueOrNil == hex ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    ColorPicker(
                        L10n.t("自訂線條色"),
                        selection: Binding(
                            get: { Color(hex: engine.selectedStrokeColor.valueOrNil ?? "#86efac") },
                            set: { engine.setSelectedStrokeColor(hexString($0)) }
                        )
                    )
                    .labelsHidden()
                    .frame(width: 24)
                }
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
                        ColorPicker(
                            L10n.t("起點"),
                            selection: Binding(
                                get: { Color(hex: engine.selectedGradientStart) },
                                set: {
                                    engine.setSelectedGradientColors(
                                        start: hexString($0), end: engine.selectedGradientEnd)
                                }
                            )
                        ).labelsHidden().help(L10n.t("漸層起點顏色"))
                        ColorPicker(
                            L10n.t("終點"),
                            selection: Binding(
                                get: { Color(hex: engine.selectedGradientEnd) },
                                set: {
                                    engine.setSelectedGradientColors(
                                        start: engine.selectedGradientStart, end: hexString($0))
                                }
                            )
                        ).labelsHidden().help(L10n.t("漸層終點顏色"))
                    }
                }
            }

            // 2. Fill Color
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.t("填色"))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if engine.selectedFillColor.isMixed {
                        Text(L10n.t("混合填色"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Button {
                        engine.setSelectedFillColor("none")
                    } label: {
                        Circle()
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                            .background(Circle().fill(Color.clear))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "slash.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("無填色"))

                    ForEach(standardColors.prefix(7), id: \.self) { hex in
                        Button {
                            engine.setSelectedFillColor(hex)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.primary.opacity(
                                                engine.selectedFillColor.valueOrNil == hex ? 0.9 : 0.2),
                                            lineWidth: engine.selectedFillColor.valueOrNil == hex ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    ColorPicker(
                        L10n.t("自訂填色"),
                        selection: Binding(
                            get: { Color(hex: engine.selectedFillColor.valueOrNil ?? "#fde047") },
                            set: { color in
                                engine.setSelectedFillColor(hexString(color))
                                let rgb = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
                                engine.setSelectedFillOpacity(Double(rgb.alphaComponent))
                            }
                        ), supportsOpacity: true
                    )
                    .labelsHidden()
                    .frame(width: 24)
                }
                HStack(spacing: 8) {
                    Text(L10n.t("填色透明度")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { engine.selectedFillOpacity.valueOrNil ?? 1 },
                            set: { engine.setSelectedFillOpacity($0) }
                        ),
                        in: 0...1,
                        step: 0.05
                    )
                    Text("\(Int((engine.selectedFillOpacity.valueOrNil ?? 1) * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }

    private var lineColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 3. Stroke Width
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.t("粗細"))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(
                        engine.selectedStrokeWidth.isMixed
                            ? "混合" : String(format: "%.1f pt", engine.selectedStrokeWidth.valueOrNil ?? 3.0)
                    )
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { engine.selectedStrokeWidth.valueOrNil ?? 3.0 },
                        set: { engine.setSelectedStrokeWidth($0) }
                    ),
                    in: 1.0...30.0,
                    step: 0.5
                )
            }

            // 4. Opacity
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.t("不透明度"))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(
                        engine.selectedOpacity.isMixed
                            ? "混合" : "\(Int((engine.selectedOpacity.valueOrNil ?? 1.0) * 100))%"
                    )
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { engine.selectedOpacity.valueOrNil ?? 1.0 },
                        set: { engine.setSelectedOpacity($0) }
                    ),
                    in: 0.1...1.0,
                    step: 0.05
                )
            }

            // 5. Line Style
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.t("線條樣式"))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if engine.selectedLineStyle.isMixed {
                        Text(L10n.t("混合樣式"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Picker(
                    "",
                    selection: Binding(
                        get: { engine.selectedLineStyle.valueOrNil ?? "solid" },
                        set: { engine.setSelectedLineStyle($0) }
                    )
                ) {
                    Text(L10n.t("實線")).tag("solid")
                    Text(L10n.t("虛線")).tag("dashed")
                    Text(L10n.t("點線")).tag("dotted")
                    Text(L10n.t("點劃線")).tag("dashDot")
                }
                .pickerStyle(.menu)
            }

            if engine.selectedObjects.contains(where: { $0.type == "arrow" }) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.t("箭頭大小")).font(.system(size: 11, weight: .semibold))
                    HStack {
                        Text(L10n.t("長度"))
                        Slider(
                            value: Binding(
                                get: { engine.selectedArrowHeadLength.valueOrNil ?? 16 },
                                set: { engine.setSelectedArrowHeadLength($0) }), in: 4...64)
                        Text("\(Int(engine.selectedArrowHeadLength.valueOrNil ?? 16))").monospacedDigit()
                            .frame(width: 22)
                    }
                    HStack {
                        Text(L10n.t("寬度"))
                        Slider(
                            value: Binding(
                                get: { engine.selectedArrowHeadWidth.valueOrNil ?? 10 },
                                set: { engine.setSelectedArrowHeadWidth($0) }), in: 4...48)
                        Text("\(Int(engine.selectedArrowHeadWidth.valueOrNil ?? 10))").monospacedDigit()
                            .frame(width: 22)
                    }
                }
            }

            // 6. Line Extension (Only shown when line or arrow is selected)
            if engine.selectedObjects.contains(where: { $0.type == "line" || $0.type == "arrow" }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.t("線段／箭頭延伸 (A/B)"))
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        if engine.selectedLineExtension.isMixed {
                            Text(L10n.t("混合延伸"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Picker(
                        "",
                        selection: Binding(
                            get: { engine.selectedLineExtension.valueOrNil ?? .none },
                            set: { engine.setSelectedLineExtension($0) }
                        )
                    ) {
                        ForEach(LineExtension.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var objectColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 6.1 Sticky Style & Palette (A16)
            if engine.selectedObjects.contains(where: { $0.type == "sticky" }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.t("便簽樣式"))
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        if engine.selectedStickyStyle.isMixed {
                            Text(L10n.t("混合樣式"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Picker(
                        "",
                        selection: Binding(
                            get: { engine.selectedStickyStyle.valueOrNil ?? .classic },
                            set: { engine.setSelectedStickyStyle($0) }
                        )
                    ) {
                        ForEach(StickyStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(L10n.t("便簽色盤"))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.top, 2)
                    HStack(spacing: 8) {
                        ForEach(StickyPalette.allColors, id: \.self) { hex in
                            Button {
                                engine.setSelectedStickyColor(hex)
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                engine.selectedFillColor.valueOrNil == hex
                                                    ? Color.accentColor : Color.black.opacity(0.15),
                                                lineWidth: engine.selectedFillColor.valueOrNil == hex ? 2 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if engine.selectedObjects.contains(where: { engine.isStickyTextOverflowing(object: $0) })
                    {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 11))
                                Text(L10n.t("文字超出便簽邊界"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            Button(L10n.t("自動擴展適配高度")) {
                                for obj in engine.selectedObjects where obj.type == "sticky" {
                                    engine.expandStickyToFit(id: obj.id)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.orange)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // 線段方向由 AB 兩點決定，屬性不再提供無效的 rotation 欄位。
            if engine.selectedObjects.contains(where: { !["line", "arrow"].contains($0.type) }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.t("旋轉角度"))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(
                        engine.selectedRotation.isMixed
                            ? "混合" : "\(Int(engine.selectedRotation.valueOrNil ?? 0.0))°"
                    )
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                HStack {
                    Slider(
                        value: Binding(
                            get: { engine.selectedRotation.valueOrNil ?? 0.0 },
                            set: { engine.setSelectedRotationAngle($0) }
                        ),
                        in: 0...360,
                        step: 5
                    )
                    Button(L10n.t("歸零")) {
                        engine.setSelectedRotationAngle(0.0)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
            }

            Divider()

            }

            // Quick actions
            HStack(spacing: 8) {
                Button {
                    engine.copySelected()
                    engine.pasteClipboard(offset: CGPoint(x: 24, y: 24))
                } label: {
                    Label(L10n.t("複製副本"), systemImage: "plus.square.on.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(role: .destructive) {
                    engine.deleteSelected()
                } label: {
                    Label(L10n.t("刪除"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func hexString(_ color: Color) -> String {
        let rgb = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        return String(
            format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255),
            Int(rgb.blueComponent * 255))
    }
}
