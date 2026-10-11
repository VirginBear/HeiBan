import SwiftUI
import AppKit
import HeiBanCore

// Keep drag updates local: moving the toolbar must not redraw the canvas engine.
public struct ToolbarView: View {
    @ObservedObject var engine: BoardEngine
    let windowSize: CGSize
    @ViewState private var horizontalLength: CGFloat = 900
    @ViewState private var verticalLength: CGFloat = 760
    @ViewState private var dragOrigin: CGPoint?
    @ViewState private var translation = CGSize.zero
    @ViewState private var dropTarget: String?

    public init(engine: BoardEngine, windowSize: CGSize) {
        self.engine = engine
        self.windowSize = windowSize
    }

    private var vertical: Bool { engine.isToolbarVertical }
    private var panelSize: CGSize {
        // The handle stays outside the scroll area; only tools overflow in small windows.
        if vertical {
            return CGSize(width: 72, height: min(verticalLength + 44, max(100, windowSize.height - 88)))
        }
        return CGSize(width: min(horizontalLength + 48, max(100, windowSize.width - 32)), height: 64)
    }
    private var center: CGPoint {
        let resting = engine.toolbarPosition(in: windowSize, panelSize: panelSize)
        guard let origin = dragOrigin else { return resting }
        return engine.clampPanelCenter(
            CGPoint(x: origin.x + translation.width, y: origin.y + translation.height),
            panelSize: panelSize, windowSize: windowSize, margin: 8)
    }

    public var body: some View {
        ZStack {
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Image(systemName: "line.3.horizontal")
                    .rotationEffect(.degrees(vertical ? 0 : 90))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(dragOrigin == nil ? Color.secondary : Color.accentColor)
                    .frame(width: vertical ? 44 : 24, height: vertical ? 20 : 40)
                    .contentShape(Rectangle())
                    .accessibilityLabel("移動工具列")
                    .help("拖曳到左右邊緣直排，上下邊緣橫排；在畫布內放開可浮動")
                    .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("HeiBan.workspace"))
                        .onChanged { value in
                            if dragOrigin == nil { dragOrigin = engine.toolbarPosition(in: windowSize, panelSize: panelSize) }
                            translation = value.translation
                            dropTarget = engine.toolbarDropTarget(at: value.location, in: windowSize)
                        }
                        .onEnded { value in
                            let origin = dragOrigin ?? engine.toolbarPosition(in: windowSize, panelSize: panelSize)
                            let destination = CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height)
                            engine.placeToolbar(center: destination, dropPoint: value.location,
                                                windowSize: windowSize, panelSize: panelSize)
                            dragOrigin = nil
                            translation = .zero
                            dropTarget = nil
                        })
                ScrollView(vertical ? .vertical : .horizontal) {
                    ToolbarToolsView(engine: engine)
                        .fixedSize(horizontal: !vertical, vertical: vertical)
                        .background(GeometryReader { geometry in
                            Color.clear
                                .onAppear { recordContentSize(geometry.size) }
                                .onChange(of: geometry.size) { _, size in recordContentSize(size) }
                        })
                }
                .scrollIndicators(.automatic)
            }
            .padding(8)
            .frame(width: panelSize.width, height: panelSize.height)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.98), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .position(center)

            if let target = dropTarget {
                let isSide = target == "left" || target == "right"
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.65), lineWidth: 2))
                    .frame(width: isSide ? 76 : min(windowSize.width - 32, 480),
                           height: isSide ? min(windowSize.height - 88, 360) : 64)
                    .overlay(Text(isSide ? "直排" : "橫排").font(.caption.bold()).foregroundStyle(Color.accentColor))
                    .position(x: target == "left" ? 46 : target == "right" ? windowSize.width - 46 : windowSize.width / 2,
                              y: target == "top" ? 96 : target == "bottom" ? windowSize.height - 40 : (windowSize.height + 56) / 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .transaction { $0.animation = nil }
        .onAppear { engine.toolbarLayoutSize = panelSize }
        .onChange(of: panelSize) { _, size in engine.toolbarLayoutSize = size }
        .onChange(of: windowSize) { _, size in engine.repositionPanelsIfNeeded(windowSize: size) }
    }
    private func recordContentSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if vertical { verticalLength = size.height } else { horizontalLength = size.width }
    }
}

private struct ToolbarToolsView: View {
    @ObservedObject var engine: BoardEngine
    @ObservedObject var laser: LaserPointerEngine
    @ViewState private var showLaserSettings = false
    @ViewState private var showRulerSettings = false
    @ViewState private var showMorePopover = false
    @ViewState private var showCustomizeSheet = false

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
        self.laser = engine.laserEngine
    }

    private var vertical: Bool { engine.isToolbarVertical }

    public var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
        layout {
            ForEach(engine.toolbarPreferences.visibleItemIds, id: \.self) { id in
                renderToolItem(id: id)
            }

            // More & Customize Toolbar Button
            Button {
                showMorePopover.toggle()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
                    .foregroundColor(showMorePopover ? Color.accentColor : Color.primary)
                    .frame(width: 32, height: 32)
                    .background(showMorePopover ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("更多工具與自訂工具列")
            .popover(isPresented: $showMorePopover, arrowEdge: settingsArrowEdge) {
                VStack(alignment: .leading, spacing: 6) {
                    if !engine.toolbarPreferences.hiddenItems.isEmpty {
                        Text("已隱藏工具")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        ForEach(engine.toolbarPreferences.hiddenItems) { def in
                            Button {
                                triggerTool(id: def.id)
                                showMorePopover = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: def.icon)
                                        .frame(width: 20)
                                        .foregroundColor(.accentColor)
                                    Text(def.displayName)
                                        .font(.system(size: 13))
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        Divider()
                    }

                    Button {
                        showMorePopover = false
                        showCustomizeSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .frame(width: 20)
                                .foregroundColor(.accentColor)
                            Text("自訂工具列…")
                                .font(.system(size: 13))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .frame(width: 190)
            }
            .sheet(isPresented: $showCustomizeSheet) {
                ToolbarCustomizeSheet(engine: engine, isPresented: $showCustomizeSheet)
            }
        }
    }

    private var settingsArrowEdge: Edge {
        switch engine.toolbarDock {
        case "left": return .leading
        case "right": return .trailing
        case "bottom": return .bottom
        default: return .top
        }
    }

    @ViewBuilder
    private func renderToolItem(id: String) -> some View {
        switch id {
        case "select":
            ToolButton(
                icon: "cursorarrow",
                tooltip: "選取 / 平移 (Space + 拖曳)",
                isSelected: engine.currentTool == .select
            ) {
                engine.selectTool(.select)
            }
        case "pen":
            ToolButton(
                icon: "pencil",
                tooltip: "鋼筆 / 向量筆 (停頓自動轉幾何圖形)",
                isSelected: engine.currentTool == .pen
            ) {
                engine.selectTool(.pen)
            }
        case "curve":
            ToolButton(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                tooltip: "曲線筆：描出弧線後可拖曳控制點微調",
                isSelected: engine.currentTool == .curve
            ) {
                engine.selectTool(.curve)
            }
        case "highlighter":
            ToolButton(
                icon: "highlighter",
                tooltip: "螢光筆",
                isSelected: engine.currentTool == .highlighter
            ) {
                engine.selectTool(.highlighter)
            }
        case "paint":
            ToolButton(
                icon: "paintbrush.pointed.fill",
                tooltip: "油漆筆刷（大面積著色）",
                isSelected: engine.currentTool == .paint
            ) {
                engine.selectTool(.paint)
            }
        case "eraser":
            ToolButton(
                icon: "eraser.fill",
                tooltip: "橡皮擦（點按此工具設定模式與大小）",
                isSelected: engine.currentTool == .eraser
            ) {
                if engine.currentTool != .eraser { engine.selectTool(.eraser) }
                engine.showEraserPopover = true
            }
            .popover(isPresented: $engine.showEraserPopover, arrowEdge: settingsArrowEdge) {
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
        case "ruler":
            ToolButton(
                icon: "ruler.fill",
                tooltip: "螢幕尺（點角度數字或右鍵開啟尺規設定）",
                isSelected: engine.ruler.enabled
            ) {
                engine.ruler.enabled.toggle()
                engine.showTemporaryStatus(engine.ruler.enabled ? "已啟用螢幕尺" : "已關閉螢幕尺")
            }
            .contextMenu {
                Button("尺規角度與配色…") { showRulerSettings = true }
            }
            .popover(isPresented: $showRulerSettings, arrowEdge: settingsArrowEdge) {
                RulerSettingsView(engine: engine)
            }
        case "shapes":
            Button {
                engine.showShapesPopover.toggle()
            } label: {
                Image(systemName: "square.on.circle")
                    .font(.system(size: 15))
                    .foregroundColor([ToolType.rect, ToolType.roundedRect, ToolType.circle, ToolType.triangle, ToolType.polygon, ToolType.quadrilateral, ToolType.diamond, ToolType.star, ToolType.line, ToolType.arrow, ToolType.connector].contains(engine.currentTool) ? Color.accentColor : Color.primary)
                    .frame(width: 32, height: 32)
                    .background(engine.showShapesPopover ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $engine.showShapesPopover, arrowEdge: settingsArrowEdge) {
                ShapesMenuView(engine: engine, isPresented: $engine.showShapesPopover)
            }
        case "sticky":
            ToolButton(
                icon: "note.text",
                tooltip: "便條紙",
                isSelected: engine.currentTool == .sticky
            ) {
                engine.selectTool(.sticky)
            }
        case "text":
            ToolButton(
                icon: "textformat",
                tooltip: "文字（T）",
                isSelected: engine.currentTool == .text,
                glyph: "T"
            ) {
                engine.selectTool(.text)
            }
        case "laser":
            ToolButton(
                icon: "rays",
                tooltip: "雷射筆：移動即有尾跡，再點一次開啟設定",
                isSelected: engine.currentTool == .laser || engine.laserEngine.isEnabled
            ) {
                if engine.currentTool == .laser {
                    showLaserSettings = true
                } else {
                    engine.selectTool(.laser)
                    engine.laserEngine.isEnabled = true
                }
            }
            .popover(isPresented: $showLaserSettings, arrowEdge: settingsArrowEdge) {
                LaserSettingsView(laser: engine.laserEngine)
            }
            .contextMenu {
                Button("雷射筆設定…") { showLaserSettings = true }
                Button("停止雷射筆") { engine.selectTool(.select) }
            }
        case "tape":
            ToolButton(
                icon: "eye.slash",
                tooltip: "遮題膠帶（點擊切換遮蔽/揭示）",
                isSelected: engine.currentTool == .tape
            ) {
                engine.selectTool(.tape)
            }
        case "lasso":
            ToolButton(
                icon: "lasso",
                tooltip: "套索工具（自由圈選或矩形選取）",
                isSelected: engine.currentTool == .lasso
            ) {
                engine.selectTool(.lasso)
            }
        case "screenshot":
            ToolButton(
                icon: "camera.viewfinder",
                tooltip: "螢幕截圖並置入 (Mac 原生截圖)",
                isSelected: false
            ) {
                engine.captureScreenAndPaste()
            }
        case "image":
            ToolButton(
                icon: "photo.badge.plus",
                tooltip: "選擇圖片匯入；也可把桌面截圖或圖片檔直接拖到畫布",
                isSelected: false
            ) {
                engine.importImageFromFilePrompt()
            }
        case "color":
            Button { engine.showColorPopover.toggle() } label: {
                Circle().fill(Color(hex: laser.isEnabled ? laser.color : engine.activeColor)).frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.secondary, lineWidth: 1)).frame(width: 32, height: 32)
            }.buttonStyle(.plain).help(laser.isEnabled ? "雷射筆顏色與光點大小" : "筆刷顏色、粗細與透明度")
            .popover(isPresented: $engine.showColorPopover, arrowEdge: settingsArrowEdge) {
                if laser.isEnabled {
                    LaserSettingsView(laser: laser)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("筆刷設定").font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("筆刷類型").font(.caption.bold())
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(BrushKind.allCases, id: \.self) { kind in
                                        Button {
                                            engine.activeBrushKind = kind
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: kind.systemIconName)
                                                Text(kind.displayName).font(.caption2)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(engine.activeBrushKind == kind ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(engine.activeBrushKind == kind ? Color.accentColor : Color.clear, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        if engine.ruler.enabled {
                            Button("尺規角度與配色…") {
                                engine.showColorPopover = false
                                DispatchQueue.main.async { showRulerSettings = true }
                            }
                        }
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

                        Text("筆寬").font(.caption.weight(.medium))
                        HStack(spacing: 4) {
                            ForEach(strokeSizes, id: \.self) { sz in
                                Button { engine.activeStrokeWidth = sz } label: {
                                    Text(CanvasToolMetrics.strokeWidth(tool: engine.currentTool, baseWidth: sz).formatted(.number.precision(.fractionLength(0...1))))
                                        .font(.caption.monospacedDigit())
                                        .frame(minWidth: 28, minHeight: 26)
                                        .background(engine.activeStrokeWidth == sz ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                                .help("筆寬 \(CanvasToolMetrics.strokeWidth(tool: engine.currentTool, baseWidth: sz).formatted()) pt")
                            }
                        }

                        let diameter = engine.activeBrushWidth * engine.viewport.zoom
                        Text("實際大小 · 畫布上直徑 \(diameter.formatted(.number.precision(.fractionLength(0...1)))) pt")
                            .font(.caption).foregroundStyle(.secondary)
                        ScrollView([.horizontal, .vertical]) {
                            Circle()
                                .fill(Color(hex: engine.activeColor).opacity(engine.currentTool == .highlighter ? engine.activeHighlighterOpacity : engine.activeOpacity))
                                .frame(width: diameter, height: diameter)
                                .frame(width: max(240, diameter + 24), height: max(80, diameter + 24))
                        }
                        .frame(height: 100)
                        .background(Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("與目前畫布縮放相同的筆刷尺寸預覽")
                        Text("目前畫布縮放 \(Int((engine.viewport.zoom * 100).rounded()))%；大筆刷可捲動查看。")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(width: 290)
                }
            }
        case "lineStyle":
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
        case "layers":
            ToolButton(
                icon: "square.3.layers.3d",
                tooltip: "物件圖層 (M)",
                isSelected: engine.showLayerPanel
            ) {
                engine.toggleLayerPanel()
            }
        case "pins":
            Button {
                engine.togglePinManager()
            } label: {
                HeiBanPinIcon()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(engine.showPinManager ? Color.accentColor : Color.primary)
                    .frame(width: 32, height: 32)
                    .background(engine.showPinManager ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("圖釘視角導航")
            .accessibilityLabel("圖釘視角導航")
            .accessibilityValue(engine.showPinManager ? "已啟用" : "未啟用")
            .accessibilityAddTraits(engine.showPinManager ? [.isSelected, .isButton] : [.isButton])
        case "compass":
            ToolButton(
                icon: "circle.circle",
                tooltip: "圓規（再次點擊關閉）",
                isSelected: engine.compassEngine.isEnabled
            ) {
                engine.toggleCompass()
            }
        case "calculator":
            ToolButton(
                icon: "plus.forwardslash.minus",
                tooltip: "計算機（再次點擊關閉）",
                isSelected: engine.calculator.isVisible
            ) {
                engine.toggleCalculator()
            }
        case "timer":
            ToolButton(
                icon: "timer",
                tooltip: "計時器（再次點擊關閉）",
                isSelected: engine.timerCoordinator.isVisible
            ) {
                engine.toggleTimer()
            }
        case "viewLock":
            ToolButton(
                icon: engine.viewportLocked ? "lock.fill" : "lock.open",
                tooltip: engine.viewportLocked ? "鎖定視角：已鎖定畫布縮放與平移" : "鎖定視角：點擊鎖定畫布",
                isSelected: engine.viewportLocked
            ) {
                engine.toggleViewportLock()
            }
        case "undoRedo":
            HStack(spacing: 4) {
                Button {
                    engine.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(!engine.canUndo)
                .opacity(engine.canUndo ? 1.0 : 0.35)
                .help("復原 (Cmd+Z)")

                Button {
                    engine.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(!engine.canRedo)
                .opacity(engine.canRedo ? 1.0 : 0.35)
                .help("重做 (Cmd+Shift+Z)")
            }
        case "dock":
            Menu {
                Button("靠左 · 直向") { dock("left") }
                Button("靠右 · 直向") { dock("right") }
                Button("靠上 · 橫向") { dock("top") }
                Button("靠下 · 橫向") { dock("bottom") }
            } label: {
                MenuDisclosureLabel("工具列停靠位置") { Image(systemName: "rectangle.3.group").font(.system(size: 16)) }
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("工具列停靠位置")
        case "clearAll":
            Button {
                engine.clearAll()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("清空黑板")
        default:
            EmptyView()
        }
    }

    private func triggerTool(id: String) {
        switch id {
        case "select": engine.selectTool(.select)
        case "pen": engine.selectTool(.pen)
        case "curve": engine.selectTool(.curve)
        case "highlighter": engine.selectTool(.highlighter)
        case "paint": engine.selectTool(.paint)
        case "eraser":
            if engine.currentTool != .eraser { engine.selectTool(.eraser) }
            engine.showEraserPopover = true
        case "ruler":
            engine.ruler.enabled.toggle()
            engine.showTemporaryStatus(engine.ruler.enabled ? "已啟用螢幕尺" : "已關閉螢幕尺")
        case "shapes": engine.showShapesPopover = true
        case "sticky": engine.selectTool(.sticky)
        case "text": engine.selectTool(.text)
        case "laser":
            if engine.currentTool == .laser {
                showLaserSettings = true
            } else {
                engine.selectTool(.laser)
                engine.laserEngine.isEnabled = true
            }
        case "tape": engine.selectTool(.tape)
        case "lasso": engine.selectTool(.lasso)
        case "screenshot": engine.captureScreenAndPaste()
        case "image": engine.importImageFromFilePrompt()
        case "color": engine.showColorPopover = true
        case "lineStyle": engine.activeLineStyle = (engine.activeLineStyle == "solid") ? "dashed" : "solid"
        case "layers": engine.toggleLayerPanel()
        case "pins": engine.togglePinManager()
        case "compass": engine.toggleCompass()
        case "calculator": engine.toggleCalculator()
        case "timer": engine.toggleTimer()
        case "viewLock": engine.toggleViewportLock()
        case "clearAll": engine.clearAll()
        default: break
        }
    }

    private func dock(_ edge: String) {
        engine.setToolbarDock(edge)
    }
}

// MARK: - Shapes Menu Popover
struct ShapesMenuView: View {
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool

    let shapes = [
        ("rect", "矩形", "rectangle"),
        ("rounded_rect", "圓角矩形", "rectangle.roundedtop"),
        ("circle", "圓形 / 橢圓", "circle"),
        ("triangle", "三角形", "triangle"),
        ("polygon", "多邊形", "hexagon"),
        ("quadrilateral", "四邊形", "square.on.square"),
        ("diamond", "菱形", "diamond"),
        ("star", "星形", "star"),
        ("line", "直線", "line.diagonal"),
        ("arrow", "箭頭", "arrow.up.right"),
        ("connector", "連接線", "arrow.triangle.branch")
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
    var glyph: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let glyph {
                    Text(glyph).font(.system(size: 19, weight: .medium, design: .serif))
                } else {
                    Image(systemName: icon).font(.system(size: 15))
                }
            }
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
