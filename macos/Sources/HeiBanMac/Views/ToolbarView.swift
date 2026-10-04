import SwiftUI
import AppKit
import HeiBanCore

public struct ToolbarView: View {
    @ObservedObject var engine: BoardEngine
    @AppStorage("HeiBan.rulerLabelColor") private var rulerLabelColor = "#FFFFFF"

    let paletteColors = [
        ("#86efac", "粉筆翠綠"),
        ("#fef08a", "粉筆淺黃"),
        ("#93c5fd", "科技湖藍"),
        ("#ffffff", "粉筆純白"),
        ("#f472b6", "櫻花淺粉"),
        ("#fb923c", "活潑暖橘"),
        ("#c084fc", "夢幻粉紫")
    ]

    let strokeSizes: [Double] = [2.0, 3.5, 6.0, 10.0, 18.0, 32.0]

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    private var vertical: Bool { engine.toolbarDock == "left" || engine.toolbarDock == "right" }
    public var body: some View {
        ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 32)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { engine.updateToolbarDrag(translation: $0.translation) }
                        .onEnded { _ in engine.endToolbarDrag() }
                )
                .help("拖曳手柄移動工具列（位置會記住）")

            // 1. Navigation / Select Tool
            ToolButton(
                icon: "cursorarrow",
                tooltip: "選取 / 平移 (Space + 拖曳)",
                isSelected: engine.currentTool == .select
            ) {
                engine.selectTool(.select)
            }

            Divider().frame(height: vertical ? 4 : 20)

            // 2. Freehand Pen
            ToolButton(
                icon: "pencil",
                tooltip: "鋼筆 / 向量筆 (停頓自動轉幾何圖形)",
                isSelected: engine.currentTool == .pen
            ) {
                engine.selectTool(.pen)
            }

            ToolButton(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                tooltip: "曲線筆：描出弧線後可拖曳控制點微調",
                isSelected: engine.currentTool == .curve
            ) {
                engine.selectTool(.curve)
            }

            // 3. Highlighter
            ToolButton(
                icon: "highlighter",
                tooltip: "螢光筆",
                isSelected: engine.currentTool == .highlighter
            ) {
                engine.selectTool(.highlighter)
            }

            ToolButton(
                icon: "paintbrush.pointed.fill",
                tooltip: "油漆筆刷（大面積著色）",
                isSelected: engine.currentTool == .paint
            ) {
                engine.selectTool(.paint)
            }

            // 4. Eraser
            ToolButton(
                icon: "eraser.fill",
                tooltip: "橡皮擦（點按此工具設定模式與大小）",
                isSelected: engine.currentTool == .eraser
            ) {
                engine.selectTool(.eraser)
                engine.showEraserPopover = true
            }
            .popover(isPresented: $engine.showEraserPopover) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("橡皮擦").font(.headline)
                    Picker("模式", selection: $engine.eraserMode) {
                        Text("物件擦除").tag(EraserMode.object)
                        Text("像素擦除").tag(EraserMode.pixel)
                    }
                    .pickerStyle(.segmented)
                    Text(engine.eraserMode == .object ? "擦除筆畫或幾何圖形" : "只擦除筆畫上的局部區域")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("大小")
                        Slider(value: $engine.eraserSize, in: 4...120, step: 2)
                        Text("\(Int(engine.eraserSize)) pt").monospacedDigit().frame(width: 46, alignment: .trailing)
                    }
                    .font(.caption)
                }
                .padding(16)
                .frame(width: 300)
            }

            // 5. Virtual Ruler
            ToolButton(
                icon: "ruler.fill",
                tooltip: "螢幕尺 (磁吸邊緣)",
                isSelected: engine.ruler.enabled
            ) {
                engine.ruler.enabled.toggle()
                engine.showTemporaryStatus(engine.ruler.enabled ? "已啟用螢幕尺" : "已關閉螢幕尺")
            }


            Divider().frame(height: vertical ? 4 : 20)

            // 6. Shapes Popover
            Button {
                engine.showShapesPopover.toggle()
            } label: {
                Image(systemName: "square.on.circle")
                    .font(.system(size: 15))
                    .foregroundColor([ToolType.rect, .circle, .triangle, .quadrilateral, .diamond, .star, .line, .arrow].contains(engine.currentTool) ? Color.accentColor : Color.primary)
                    .frame(width: 32, height: 32)
                    .background(engine.showShapesPopover ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $engine.showShapesPopover) {
                ShapesMenuView(engine: engine, isPresented: $engine.showShapesPopover)
            }

            // 7. Sticky Note
            ToolButton(
                icon: "note.text",
                tooltip: "便條紙",
                isSelected: engine.currentTool == .sticky
            ) {
                engine.selectTool(.sticky)
            }

            // 8. Text
            ToolButton(
                icon: "textformat",
                tooltip: "文字",
                isSelected: engine.currentTool == .text
            ) {
                engine.selectTool(.text)
            }

            // 9. macOS Native Screenshot Tool
            ToolButton(
                icon: "camera.viewfinder",
                tooltip: "螢幕截圖並置入 (Mac 原生截圖)",
                isSelected: false
            ) {
                engine.captureScreenAndPaste()
            }

            ToolButton(
                icon: "photo.badge.plus",
                tooltip: "選擇圖片匯入；也可把桌面截圖或圖片檔直接拖到畫布",
                isSelected: false
            ) {
                engine.importImageFromFilePrompt()
            }

            Divider().frame(height: vertical ? 4 : 20)

            Button { engine.showColorPopover.toggle() } label: {
                Circle().fill(Color(hex: engine.activeColor)).frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.secondary, lineWidth: 1)).frame(width: 32, height: 32)
            }.buttonStyle(.plain).help("筆刷顏色、粗細與透明度")
            .popover(isPresented: $engine.showColorPopover) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("筆刷設定").font(.headline)
                    if engine.ruler.enabled {
                        Text("直尺透明度").font(.caption)
                        Slider(value: $engine.ruler.opacity, in: 0.12...0.75)
                        ColorPicker("刻度與角度文字", selection: Binding(
                            get: { Color(hex: rulerLabelColor) },
                            set: { color in
                                let rgb = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
                                rulerLabelColor = String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
                            }
                        ))
                    }
            // 10. Color Palette Selector
            HStack(spacing: 5) {
                ForEach(paletteColors, id: \.0) { hex, name in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: engine.activeColor == hex ? 2.5 : 0)
                        )
                        .shadow(radius: engine.activeColor.lowercased() == hex.lowercased() ? 2 : 0)
                        .onTapGesture {
                            engine.updateCurrentToolStyle(color: hex)
                        }
                        .help(name)
                        .accessibilityLabel(name)
                }
            }

            if !engine.recentColors.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("最近色彩").font(.system(size: 10)).foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        ForEach(engine.recentColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Color.white, lineWidth: engine.activeColor.lowercased() == hex.lowercased() ? 2 : 0))
                                .onTapGesture {
                                    engine.updateCurrentToolStyle(color: hex)
                                }
                                .help("最近色彩 \(hex)")
                                .accessibilityLabel("最近色彩 \(hex)")
                        }
                    }
                }
            }

            ColorPicker(
                "自訂色彩",
                selection: Binding(
                    get: { Color(hex: engine.activeColor) },
                    set: { color in
                        let rgb = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.systemGreen
                        let hex = String(
                            format: "#%02X%02X%02X",
                            Int(rgb.redComponent * 255),
                            Int(rgb.greenComponent * 255),
                            Int(rgb.blueComponent * 255)
                        )
                        engine.updateCurrentToolStyle(color: hex)
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 30, height: 30)
            .help("開啟 macOS 色輪選擇自訂顏色")

            HStack(spacing: 5) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(
                    value: Binding(
                        get: { engine.currentTool == .highlighter ? engine.activeHighlighterOpacity : engine.activeOpacity },
                        set: { value in
                            if engine.currentTool == .highlighter {
                                engine.activeHighlighterOpacity = value
                            } else {
                                engine.activeOpacity = value
                            }
                        }
                    ),
                    in: 0.05...1.0
                )
                .frame(width: 72)
                .help("目前工具透明度")
            }

            Divider().frame(height: vertical ? 4 : 20)

            // 11. Stroke Width
            HStack(spacing: 4) {
                ForEach(strokeSizes, id: \.self) { sz in
                    Circle()
                        .fill(engine.activeStrokeWidth == sz ? Color.primary : Color.secondary.opacity(0.5))
                        .frame(width: CGFloat(min(20, sz * 0.5 + 4)), height: CGFloat(min(20, sz * 0.5 + 4)))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            engine.activeStrokeWidth = sz
                        }
                        .help("筆寬 \(Int(sz))pt")
                }
            }

                }.padding(18).frame(width: 290)
            }

            // 12. Solid / Dashed Toggle
            Button {
                engine.activeLineStyle = (engine.activeLineStyle == "solid") ? "dashed" : "solid"
            } label: {
                Image(systemName: engine.activeLineStyle == "dashed" ? "ellipsis" : "minus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(engine.activeLineStyle == "dashed" ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help(engine.activeLineStyle == "dashed" ? "虛線模式" : "實線模式")

            Menu {
                ForEach(LineExtension.allCases, id: \.self) { extensionMode in
                    Button {
                        engine.setSelectedLineExtension(extensionMode)
                        engine.activeLineExtension = extensionMode
                    } label: {
                        if engine.activeLineExtension == extensionMode {
                            Label(extensionMode.displayName, systemImage: "checkmark")
                        } else {
                            Text(extensionMode.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.left.and.right")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .help("設定直線端點延伸方式")

            Divider().frame(height: vertical ? 4 : 20)

            // 13. Undo & Redo
            Button {
                engine.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!engine.canUndo)
            .opacity(engine.canUndo ? 1.0 : 0.35)
            .help("復原 (Cmd+Z)")

            Button {
                engine.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!engine.canRedo)
            .opacity(engine.canRedo ? 1.0 : 0.35)
            .help("重做 (Cmd+Shift+Z)")

            Menu {
                Button("靠左 · 直向") { dock("left") }
                Button("靠右 · 直向") { dock("right") }
                Button("靠上 · 橫向") { dock("top") }
                Button("靠下 · 橫向") { dock("bottom") }
            } label: { Image(systemName: "rectangle.3.group").frame(width: 32, height: 32) }
            .menuStyle(.borderlessButton).help("工具列停靠位置")
            // 14. Clear All
            Button {
                engine.clearAll()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("清空黑板")
        }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.97), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
    private func dock(_ edge: String) {
        engine.toolbarDock = edge
        engine.toolbarOffset = .zero
        engine.endToolbarDrag()
    }
}

// MARK: - Shapes Menu Popover
struct ShapesMenuView: View {
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool

    let shapes = [
        ("rect", "矩形", "rectangle"),
        ("circle", "圓形 / 橢圓", "circle"),
        ("triangle", "三角形", "triangle"),
        ("quadrilateral", "四邊形", "square.on.square"),
        ("diamond", "菱形", "diamond"),
        ("star", "星形", "star"),
        ("line", "直線", "line.diagonal"),
        ("arrow", "箭頭", "arrow.up.right")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("插入幾何形狀")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 6)

            ForEach(shapes, id: \.0) { type, title, icon in
                Button {
                    engine.selectTool(type)
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .frame(width: 20)
                        Text(title)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 170)
    }
}

// MARK: - Generic Tool Button Helper
struct ToolButton: View {
    let icon: String
    let tooltip: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(isSelected ? Color.accentColor : Color.primary)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
        .accessibilityValue(isSelected ? "已啟用" : "未啟用")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
