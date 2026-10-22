import SwiftUI
import AppKit
import HeiBanCore

// Keep drag updates local: moving the toolbar must not redraw the canvas engine.
public struct ToolbarView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    let windowSize: CGSize
    let topClearance: CGFloat
    @ViewState private var horizontalLength: CGFloat = 900
    @ViewState private var verticalLength: CGFloat = 760
    @ViewState private var dragOrigin: CGPoint?
    @ViewState private var translation = CGSize.zero
    @ViewState private var dropTarget: String?

    public init(engine: BoardEngine, windowSize: CGSize, topClearance: CGFloat = 64) {
        self.engine = engine
        self.windowSize = windowSize
        self.topClearance = topClearance
    }

    private var vertical: Bool { engine.isToolbarVertical }
    private var panelSize: CGSize {
        if engine.toolbarPreferences.displayMode == "labels" {
            return vertical ? CGSize(width:160,height:min(660,max(200,windowSize.height-88))) : CGSize(width:min(1120,max(260,windowSize.width-32)),height:116)
        }
        // The handle stays outside the scroll area; only tools overflow in small windows.
        if vertical {
            return CGSize(width: 72, height: min(verticalLength + 44, max(100, windowSize.height - 88)))
        }
        return CGSize(width: min(horizontalLength + 48, max(100, windowSize.width - 32)), height: 64)
    }
    private var center: CGPoint {
        let resting = engine.toolbarPosition(in: windowSize, panelSize: panelSize, topClearance: topClearance)
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
                    .accessibilityLabel(L10n.t("移動工具列"))
                    .help(L10n.t("拖曳到左右邊緣直排，上下邊緣橫排；在畫布內放開可浮動"))
                    .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("HeiBan.workspace"))
                        .onChanged { value in
                            if dragOrigin == nil { dragOrigin = engine.toolbarPosition(in: windowSize, panelSize: panelSize, topClearance: topClearance) }
                            translation = value.translation
                            dropTarget = engine.toolbarDropTarget(at: value.location, in: windowSize)
                        }
                        .onEnded { value in
                            let origin = dragOrigin ?? engine.toolbarPosition(in: windowSize, panelSize: panelSize, topClearance: topClearance)
                            let destination = CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height)
                            engine.placeToolbar(center: destination, dropPoint: value.location,
                                                windowSize: windowSize, panelSize: panelSize)
                            dragOrigin = nil
                            translation = .zero
                            dropTarget = nil
                        })
                if engine.toolbarPreferences.displayMode == "labels" {
                    ToolbarToolsView(engine:engine,availableLength:vertical ? panelSize.height-48 : panelSize.width-64)
                } else {
                    ScrollView(vertical ? .vertical : .horizontal) {
                        ToolbarToolsView(engine: engine)
                            .fixedSize(horizontal: !vertical, vertical: vertical)
                            .background(GeometryReader { geometry in
                                Color.clear.onAppear { recordContentSize(geometry.size) }
                                    .onChange(of: geometry.size) { _, size in recordContentSize(size) }
                            })
                    }.scrollIndicators(.automatic)
                }
            }
            .padding(8)
            .frame(width: panelSize.width, height: panelSize.height)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.98), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .position(center)
            .animation(dragOrigin == nil ? .easeOut(duration: 0.16) : nil, value: topClearance)

            if let target = dropTarget {
                let isSide = target == "left" || target == "right"
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.65), lineWidth: 2))
                    .frame(width: isSide ? 76 : min(windowSize.width - 32, 480),
                           height: isSide ? min(windowSize.height - 88, 360) : 64)
                    .overlay(Text(L10n.t(isSide ? "直排" : "橫排")).font(.caption.bold()).foregroundStyle(Color.accentColor))
                    .position(x: target == "left" ? 46 : target == "right" ? windowSize.width - 46 : windowSize.width / 2,
                              y: target == "top" ? topClearance + 32 : target == "bottom" ? windowSize.height - 40 : (windowSize.height + 56) / 2)
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

struct ToolbarToolsView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @ObservedObject var laser: LaserPointerEngine
    @ViewState private var showLaserSettings = false
    @ViewState private var showRulerSettings = false
    @ViewState private var showMorePopover = false
    @ViewState private var requestedSettingsID: String?
    @ViewState private var showCustomizeSheet = false

    let screenController: ScreenAnnotationController?
    let columns: Int?
    let availableLength: CGFloat
    @ViewState private var activePage = "common"
    @ViewState private var pageOffset = 0

    init(engine: BoardEngine, screenController: ScreenAnnotationController? = nil, columns: Int? = nil, availableLength: CGFloat = 600) {
        self.engine = engine
        self.laser = engine.laserEngine
        self.screenController = screenController
        self.columns = columns
        self.availableLength = availableLength
    }

    private var vertical: Bool { screenController?.controlsDock.isVertical ?? engine.isToolbarVertical }

    private var visibleIDs: [String] {
        ToolbarContentPolicy.visibleIDs(engine.toolbarPreferences, screen: screenController != nil)
    }
    private var usesLabels: Bool { engine.toolbarPreferences.displayMode == "labels" }
    private var pageIDs: [String] {
        ToolbarContentPolicy.pageIDs(engine.toolbarPreferences, screen: screenController != nil, page: activePage)
    }
    // 預留常駐選取、更多、兩個換組箭頭及間距，再計算實際能容納的工具。
    private var pageCapacity: Int {
        max(1, Int((availableLength - (vertical ? 144 : 116)) / (vertical ? 50 : 76)))
    }
    private var currentPageOffset: Int {
        min(pageOffset, max(0, ((pageIDs.count - 1) / pageCapacity) * pageCapacity))
    }
    private var shownPageIDs: [String] {
        Array(pageIDs.dropFirst(currentPageOffset).prefix(pageCapacity))
    }
    private var renderedIDs: [String] { usesLabels ? ["select"] + shownPageIDs : visibleIDs }
    private var overflowIDs: [String] {
        let candidates = ToolbarPreferences.allDefinitions
            .filter { ToolbarContentPolicy.isAvailable($0.id, screen: screenController != nil) }
            .flatMap { item in
                screenController != nil && item.id == "undoRedo" ? ["undo", "redo"] : [item.id]
            }
        let overflow = candidates.filter { !renderedIDs.contains($0) }
        // 程式請求設定時把錨點放到可見首列，避免它在 More 捲動區底部仍被裁掉。
        guard let requestedSettingsID, overflow.contains(requestedSettingsID) else { return overflow }
        return [requestedSettingsID] + overflow.filter { $0 != requestedSettingsID }
    }
    private func revealSettings(_ id: String) {
        guard !renderedIDs.contains(id) else { return }
        requestedSettingsID = id
        showMorePopover = true
    }
    private func toolTitle(_ id: String) -> String {
        if id == "undo" { return "復原" }
        if id == "redo" { return "重做" }
        return ToolbarPreferences.allDefinitions.first { $0.id == id }?.displayName ?? id
    }

    var body: some View {
        Group {
            if engine.toolbarPreferences.displayMode == "labels" { labeledTools }
            else if let columns {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: columns), spacing: 4) {
                    items
                }
            } else {
                let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
                layout { items }
            }
        }
        .onAppear {
            // 首頁期間一般工具列不在 view tree；再次打開時也需讀到螢幕模式已保存的偏好。
            if let data = UserDefaults.standard.data(forKey: "HeiBan.toolbarPreferences"),
               let preferences = try? JSONDecoder().decode(ToolbarPreferences.self, from: data),
               preferences != engine.toolbarPreferences {
                engine.toolbarPreferences = preferences
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HeiBan.toolbarPreferencesChanged"))) { notification in
            guard let source = notification.object as? BoardEngine, source !== engine,
                  source.toolbarPreferences != engine.toolbarPreferences else { return }
            engine.toolbarPreferences = source.toolbarPreferences
        }
        .onChange(of: engine.showColorPopover) { _, show in if show { revealSettings("color") } }
        .onChange(of: engine.showShapesPopover) { _, show in if show { revealSettings("shapes") } }
        .onChange(of: engine.showEraserPopover) { _, show in if show { revealSettings("eraser") } }
        .onChange(of: engine.toolbarPreferences) { _, _ in pageOffset=0;screenController?.toolbarPreferencesChanged() }
        .onChange(of: availableLength) { _, _ in pageOffset=0 }
        .onChange(of: showMorePopover) { _, show in if !show { requestedSettingsID = nil } }
    }

    private var labeledTools: some View {
        let shell = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
        return shell {
            renderToolItem(id: "select")
            VStack(spacing: 4) {
                pageSelector
                // 頁容量解決一般窄視窗；更小的宿主仍可捲動中段，固定命令不被推出面板。
                ScrollView(vertical ? .vertical : .horizontal) {
                    pageTools.fixedSize(horizontal: !vertical, vertical: vertical)
                }
                .scrollIndicators(.automatic)
            }
            .frame(width: vertical ? 116 : max(1, availableLength - 76),
                   height: vertical ? max(1, availableLength - 72) : 86)
            moreButton
        }
        .frame(width: vertical ? 116 : max(1, availableLength),
               height: vertical ? max(1, availableLength) : 86)
        .onChange(of: activePage) { _, _ in pageOffset = 0 }
    }

    private var pageTabsWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 11)
        return ToolbarContentPolicy.pageTitles.reduce(CGFloat(12)) { width, title in
            width + (L10n.t(title) as NSString).size(withAttributes: [.font: font]).width + 20
        }
    }

    @ViewBuilder private var pageSelector: some View {
        if vertical || pageTabsWidth > availableLength - 76 {
            Picker(L10n.t("工具分頁"), selection: $activePage) {
                ForEach(Array(ToolbarContentPolicy.pages.enumerated()), id: \.element) { index, id in
                    Text(L10n.t(ToolbarContentPolicy.pageTitles[index])).tag(id)
                }
            }.labelsHidden().frame(width: 116)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(ToolbarContentPolicy.pages.enumerated()), id: \.element) { index, id in
                    Button(L10n.t(ToolbarContentPolicy.pageTitles[index])) { activePage = id }
                        .buttonStyle(.plain).padding(.horizontal, 10).padding(.vertical, 3)
                        .background(activePage == id ? Color.accentColor.opacity(0.16) : Color.clear, in: Capsule())
                }
            }.font(.system(size: 11)).fixedSize()
        }
    }

    private var pageTools: some View {
        let row = vertical ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 4))
        return row {
            Button { pageOffset = max(0, currentPageOffset - pageCapacity) } label: {
                Image(systemName: vertical ? "chevron.up" : "chevron.left").frame(width: 18, height: 22)
            }.disabled(currentPageOffset == 0).help(L10n.t("上一組工具"))
            ForEach(shownPageIDs, id: \.self) { id in
                let tile = vertical ? AnyLayout(HStackLayout(spacing: 5)) : AnyLayout(VStackLayout(spacing: 2))
                tile {
                    renderToolItem(id: id)
                    Text(L10n.t(toolTitle(id))).font(.system(size: 10)).lineLimit(2)
                        .multilineTextAlignment(.center)
                }.frame(width: vertical ? 116 : 72, height: vertical ? 48 : 58)
            }
            if shownPageIDs.isEmpty {
                Text(L10n.t("由自訂工具列加入常用工具")).font(.caption2).frame(width: 72)
            }
            Button { pageOffset = currentPageOffset + pageCapacity } label: {
                Image(systemName: vertical ? "chevron.down" : "chevron.right").frame(width: 18, height: 22)
            }.disabled(currentPageOffset + pageCapacity >= pageIDs.count).help(L10n.t("下一組工具"))
        }
    }

    @ViewBuilder private var items: some View {
        ForEach(visibleIDs, id: \.self) { id in renderToolItem(id: id) }
        moreButton
    }

    private var moreButton: some View {
        ToolButton(icon: "ellipsis.circle", tooltip: "更多工具與自訂工具列", isSelected: showMorePopover) {
            showMorePopover.toggle()
        }
        .popover(isPresented: $showMorePopover, arrowEdge: settingsArrowEdge) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // 隱藏、其他分頁及下一組工具都保留同一元件，讓設定永遠有真實錨點。
                    ForEach(overflowIDs, id: \.self) { id in
                        HStack(spacing: 12) {
                            renderToolItem(id: id)
                            Text(L10n.t(toolTitle(id))).font(.system(size: 13))
                            Spacer()
                        }
                    }
                    Divider()
                    Picker(L10n.t("工具列格式"), selection:Binding(get:{engine.toolbarPreferences.displayMode},set:{engine.toolbarPreferences.displayMode=$0;engine.saveToolbarPreferences()})) {
                        Text(L10n.t("只有圖示")).tag("icons")
                        Text(L10n.t("圖示與文字（分頁）")).tag("labels")
                    }
                    if screenController == nil {
                        Toggle(L10n.t("顯示板擦"),isOn:Binding(get:{engine.toolbarPreferences.boardEraserVisible},set:{engine.setBoardEraserVisible($0)}))
                    }
                    Button(L10n.t("自訂工具列…")) {
                        showMorePopover = false
                        DispatchQueue.main.async { showCustomizeSheet = true }
                    }
                    if let controller = screenController {
                        Divider()
                        Menu(L10n.t("工具列位置")) {
                            ForEach(AnnotationToolbarDock.allCases, id: \.rawValue) { edge in
                                Button(L10n.t(edge.title)) { showMorePopover = false; controller.setControlsDock(edge) }
                            }
                        }
                        Button(L10n.t("收合工具列")) { showMorePopover = false; controller.setControlsCollapsed(true) }
                        Button(L10n.t("儲存可編輯註記 .heiban…")) { controller.saveEditable() }
                        Button(L10n.t("使用手冊")) { controller.showUserGuide() }
                        Text(controller.message).font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(12)
            }.frame(width: 260).frame(maxHeight: 520)
        }
        .popover(isPresented: Binding(get: { screenController != nil && engine.showLayerPanel },
                                      set: { if screenController != nil { engine.showLayerPanel = $0 } }),
                 arrowEdge: settingsArrowEdge) {
            LayerPanelView(engine: engine).frame(width: 280, height: 440)
        }
        // NSPanel 內使用 popover，避免 sheet 搶走透明畫布的鍵盤／視窗生命週期。
        .popover(isPresented: $showCustomizeSheet, arrowEdge: settingsArrowEdge) {
            ToolbarCustomizeSheet(engine: engine, isPresented: $showCustomizeSheet,
                                  screenContext: screenController != nil)
        }
    }

    private var settingsArrowEdge: Edge {
        switch screenController?.controlsDock.rawValue ?? engine.toolbarDock {
        case "left": return .leading
        case "right": return .trailing
        case "bottom": return .bottom
        default: return .top
        }
    }

    @ViewBuilder
    private func renderToolItem(id: String) -> some View {
        switch id {
        case "magnet":
            ToolButton(icon:"heiban.magnet",tooltip:"磁鐵",isSelected:engine.toolbarPreferences.magnetEnabled) { engine.toggleMagnet() }
        case "select":
            ToolButton(
                icon: "cursorarrow",
                tooltip: screenController == nil ? "選取 / 平移 (Space + 拖曳)" : "選取",
                isSelected: engine.currentTool == .select
            ) {
                selectTool(.select)
            }
        case "pen":
            ToolButton(
                icon: "pencil",
                tooltip: "鋼筆 / 向量筆 (停頓自動轉幾何圖形)",
                isSelected: engine.currentTool == .pen
            ) {
                selectTool(.pen)
            }
        case "curve":
            ToolButton(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                tooltip: "曲線筆：描出弧線後可拖曳控制點微調",
                isSelected: engine.currentTool == .curve
            ) {
                selectTool(.curve)
            }
        case "highlighter":
            ToolButton(
                icon: "highlighter",
                tooltip: "螢光筆",
                isSelected: engine.currentTool == .highlighter
            ) {
                selectTool(.highlighter)
            }
        case "paint":
            ToolButton(
                icon: "paintbrush.pointed.fill",
                tooltip: "油漆筆刷（大面積著色）",
                isSelected: engine.currentTool == .paint
            ) {
                selectTool(.paint)
            }
        case "eraser":
            ToolButton(
                icon: "eraser.fill",
                tooltip: "橡皮擦（點按此工具設定模式與大小）",
                isSelected: engine.currentTool == .eraser
            ) {
                if engine.currentTool != .eraser { selectTool(.eraser) }
                engine.showEraserPopover = true
            }
            .popover(isPresented: $engine.showEraserPopover, arrowEdge: settingsArrowEdge) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("橡皮擦")).font(.headline)
                    Picker(L10n.t("模式"), selection: $engine.eraserMode) {
                        Text(L10n.t("物件擦除")).tag(EraserMode.object)
                        Text(L10n.t("像素擦除")).tag(EraserMode.pixel)
                    }
                    .pickerStyle(.segmented)
                    Text(engine.eraserMode == .object ? "擦除筆畫或幾何圖形" : "只擦除筆畫上的局部區域")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(L10n.t("大小"))
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
                screenController?.setDrawing(true)
                engine.ruler.enabled.toggle()
                engine.showTemporaryStatus(engine.ruler.enabled ? "已啟用螢幕尺" : "已關閉螢幕尺")
            }
            .contextMenu {
                Button(L10n.t("尺規角度與配色…")) { showRulerSettings = true }
            }
            .popover(isPresented: $showRulerSettings, arrowEdge: settingsArrowEdge) {
                RulerSettingsView(engine: engine)
            }
        case "shapes":
            Button {
                screenController?.setDrawing(true)
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
                ShapesMenuView(engine: engine, isPresented: $engine.showShapesPopover, onSelect: selectTool)
            }
        case "sticky":
            ToolButton(
                icon: "note.text",
                tooltip: "便條紙",
                isSelected: engine.currentTool == .sticky
            ) {
                selectTool(.sticky)
            }
        case "text":
            ToolButton(
                icon: "textformat",
                tooltip: "文字（T）",
                isSelected: engine.currentTool == .text,
                glyph: "T"
            ) {
                selectTool(.text)
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
                    selectTool(.laser)
                    engine.laserEngine.isEnabled = true
                }
            }
            .popover(isPresented: $showLaserSettings, arrowEdge: settingsArrowEdge) {
                LaserSettingsView(laser: engine.laserEngine)
            }
            .contextMenu {
                Button(L10n.t("雷射筆設定…")) { showLaserSettings = true }
                Button(L10n.t("停止雷射筆")) { selectTool(.select) }
            }
        case "tape":
            ToolButton(
                icon: "eye.slash",
                tooltip: "遮題膠帶（點擊切換遮蔽/揭示）",
                isSelected: engine.currentTool == .tape
            ) {
                selectTool(.tape)
            }
        case "lasso":
            ToolButton(
                icon: "lasso",
                tooltip: "套索工具（自由圈選或矩形選取）",
                isSelected: engine.currentTool == .lasso
            ) {
                selectTool(.lasso)
            }
        case "screenshot":
            ToolButton(
                icon: "camera.viewfinder",
                tooltip: screenController == nil ? "螢幕截圖並置入 (Mac 原生截圖)" : "截圖並儲存 PNG · ⌘⌥⇧S",
                isSelected: false
            ) {
                captureScreenshot()
            }
        case "image":
            ToolButton(
                icon: "photo.badge.plus",
                tooltip: "選擇圖片匯入；也可把桌面截圖或圖片檔直接拖到畫布",
                isSelected: false
            ) {
                importImage()
            }
        case "color":
            Button { engine.showColorPopover.toggle() } label: {
                Circle().fill(Color(hex: laser.isEnabled ? laser.color : (engine.selectedStrokeColor.valueOrNil ?? engine.activeColor))).frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.secondary, lineWidth: 1)).frame(width: 32, height: 32)
            }.buttonStyle(.plain).help(laser.isEnabled ? "雷射筆顏色與光點大小" : "筆刷顏色、粗細與透明度")
            .popover(isPresented: $engine.showColorPopover, arrowEdge: settingsArrowEdge) {
                if laser.isEnabled {
                    LaserSettingsView(laser: laser)
                } else {
                    ToolbarBrushSettings(engine: engine)
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
                screenController?.setDrawing(true)
                if screenController != nil { showMorePopover = false }
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
            .help(L10n.t("圖釘視角導航"))
            .accessibilityLabel(L10n.t("圖釘視角導航"))
            .accessibilityValue(engine.showPinManager ? "已啟用" : "未啟用")
            .accessibilityAddTraits(engine.showPinManager ? [.isSelected, .isButton] : [.isButton])
        case "compass":
            ToolButton(
                icon: "circle.circle",
                tooltip: "圓規（再次點擊關閉）",
                isSelected: engine.compassEngine.isEnabled
            ) {
                screenController?.setDrawing(true)
                engine.toggleCompass()
            }
        case "calculator":
            ToolButton(
                icon: "plus.forwardslash.minus",
                tooltip: "計算機（再次點擊關閉）",
                isSelected: engine.calculator.isVisible
            ) {
                screenController?.setDrawing(true)
                engine.toggleCalculator()
            }
        case "timer":
            ToolButton(
                icon: "timer",
                tooltip: "計時器（再次點擊關閉）",
                isSelected: engine.timerCoordinator.isVisible
            ) {
                screenController?.setDrawing(true)
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
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
            layout { undoButton; redoButton }
        case "undo": undoButton
        case "redo": redoButton
        case "dock":
            Menu {
                Button(L10n.t("靠左 · 直向")) { dock("left") }
                Button(L10n.t("靠右 · 直向")) { dock("right") }
                Button(L10n.t("靠上 · 橫向")) { dock("top") }
                Button(L10n.t("靠下 · 橫向")) { dock("bottom") }
            } label: {
                MenuDisclosureLabel(L10n.t("工具列停靠位置")) { Image(systemName: "rectangle.3.group").font(.system(size: 16)) }
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(L10n.t("工具列停靠位置"))
        case "clearAll":
            Button {
                clearCanvas()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L10n.t("清空黑板"))
        default:
            EmptyView()
        }
    }

    private var undoButton: some View {
        ToolButton(icon: "arrow.uturn.backward", tooltip: "復原 (Cmd+Z)", isSelected: false, action: engine.undo)
            .disabled(!engine.canUndo)
    }
    private var redoButton: some View {
        ToolButton(icon: "arrow.uturn.forward", tooltip: "重做 (Cmd+Shift+Z)", isSelected: false, action: engine.redo)
            .disabled(!engine.canRedo)
    }
    private func selectTool(_ tool: ToolType) {
        if let controller = screenController { controller.selectTool(tool) }
        else { engine.selectTool(tool) }
    }
    private func captureScreenshot() {
        if let controller = screenController { controller.captureScreen() }
        else { engine.captureScreenAndPaste() }
    }
    private func importImage() {
        if let controller = screenController { controller.importImage() }
        else { engine.importImageFromFilePrompt() }
    }
    private func clearCanvas() {
        if let controller = screenController { controller.clearAnnotations() }
        else { engine.clearAll() }
    }
    private func dock(_ edge: String) {
        if let controller = screenController, let dock = AnnotationToolbarDock(rawValue: edge) {
            controller.setControlsDock(dock)
        } else { engine.setToolbarDock(edge) }
    }
}

// MARK: - Shapes Menu Popover
struct ShapesMenuView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool

    var onSelect: ((ToolType) -> Void)? = nil

    private let primaryShapes: [(ToolType, String, String)] = [
        (.line, "直線", "line.diagonal"),
        (.arrow, "箭頭", "arrow.up.right"),
        (.rect, "矩形", "rectangle"),
        (.circle, "圓形", "circle"),
        (.triangle, "三角形", "triangle"),
        (.quadrilateral, "四邊形", "square"),
        (.diamond, "菱形", "diamond"),
        (.polygon, "五角形", "pentagon"),
        (.star, "星形", "star"),
    ]

    private let extraShapes: [(ToolType, String, String)] = [
        (.roundedRect, "圓角矩形", "rectangle.roundedtop"),
        (.connector, "連接線", "arrow.triangle.branch"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("插入幾何形狀"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(72), spacing: 8), count: 3), spacing: 8) {
                ForEach(primaryShapes, id: \.0) { type, title, icon in
                    shapeCell(type: type, title: title, icon: icon)
                }
            }

            HStack(spacing: 8) {
                ForEach(extraShapes, id: \.0) { type, title, icon in
                    Button {
                        if let onSelect { onSelect(type) } else { engine.selectTool(type) }
                        isPresented = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(L10n.t(title))
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            engine.currentTool == type ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(engine.currentTool == type ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Toggle(L10n.t("自動填滿圖形"), isOn: $engine.autoFillShapes)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 12))
                .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(width: 252)
    }

    private func shapeCell(type: ToolType, title: String, icon: String) -> some View {
        let active = engine.currentTool == type
        return Button {
            if let onSelect { onSelect(type) } else { engine.selectTool(type) }
            isPresented = false
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 22)
                Text(L10n.t(title))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(active ? Color.accentColor : Color.primary)
            .frame(width: 72, height: 56)
            .background(
                active ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(active ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Generic Tool Button Helper
struct ToolButton: View {
    @ObservedObject private var language = L10n.shared
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
                    if icon == "circle.circle" { HeiBanCompassIcon() }
                    else if icon == "heiban.magnet" { HeiBanMagnetIcon() }
                    else { Image(systemName: icon).font(.system(size: 15)) }
                }
            }
                .foregroundColor(isSelected ? Color.accentColor : Color.primary)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(L10n.t(tooltip))
        .accessibilityLabel(L10n.t(tooltip))
        .accessibilityValue(L10n.t(isSelected ? "已啟用" : "未啟用"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
