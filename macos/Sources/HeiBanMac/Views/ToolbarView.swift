import AppKit
import HeiBanCore
import SwiftUI

// Keep drag updates local: moving the toolbar must not redraw the canvas engine.
public struct ToolbarView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    let windowSize: CGSize
    let topClearance: CGFloat
    @ViewState private var activePage: String = "common"
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
        ToolbarContentPolicy.panelSize(preferences: engine.toolbarPreferences,
            page: activePage, vertical: vertical, windowSize: windowSize)
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
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Image(systemName: "line.3.horizontal")
                    .rotationEffect(.degrees(vertical ? 0 : 90))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(dragOrigin == nil ? Color.secondary : Color.accentColor)
                    .frame(width: vertical ? 44 : 24, height: vertical ? 20 : 40)
                    .contentShape(Rectangle())
                    .accessibilityLabel(L10n.t("移動工具列"))
                    .help(L10n.t("拖曳到左右邊緣直排，上下邊緣橫排；在畫布內放開可浮動"))
                    .gesture(
                        DragGesture(minimumDistance: 2, coordinateSpace: .named("HeiBan.workspace"))
                            .onChanged { value in
                                if dragOrigin == nil {
                                    dragOrigin = engine.toolbarPosition(
                                        in: windowSize, panelSize: panelSize, topClearance: topClearance)
                                }
                                translation = value.translation
                                dropTarget = engine.toolbarDropTarget(at: value.location, in: windowSize)
                            }
                            .onEnded { value in
                                let origin =
                                    dragOrigin
                                    ?? engine.toolbarPosition(
                                        in: windowSize, panelSize: panelSize, topClearance: topClearance)
                                let destination = CGPoint(
                                    x: origin.x + value.translation.width,
                                    y: origin.y + value.translation.height)
                                engine.placeToolbar(
                                    center: destination, dropPoint: value.location,
                                    windowSize: windowSize, panelSize: panelSize)
                                dragOrigin = nil
                                translation = .zero
                                dropTarget = nil
                            })
                if engine.toolbarPreferences.displayMode == "labels" {
                    ToolbarToolsView(
                        engine: engine,
                        availableLength: vertical
                            ? max(120, windowSize.height - 88) : max(280, windowSize.width - 32),
                        externalActivePage: $activePage
                    )
                } else {
                    ScrollView(vertical ? .vertical : .horizontal) {
                        ToolbarToolsView(engine: engine)
                            .fixedSize(horizontal: !vertical, vertical: vertical)
                    }.scrollIndicators(.automatic)
                }
            }
            .padding(8)
            .frame(width: panelSize.width, height: panelSize.height, alignment: vertical ? .top : .leading)
            .modifier(ToolbarPanelSurface())
            .position(center)
            .animation(dragOrigin == nil ? .easeOut(duration: 0.16) : nil, value: topClearance)

            if let target = dropTarget {
                let isSide = target == "left" || target == "right"
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(
                            Color.accentColor.opacity(0.65), lineWidth: 2)
                    )
                    .frame(
                        width: isSide ? 76 : min(windowSize.width - 32, 480),
                        height: isSide ? min(windowSize.height - 88, 360) : 64
                    )
                    .overlay(
                        Text(L10n.t(isSide ? "直排" : "橫排")).font(.caption.bold()).foregroundStyle(
                            Color.accentColor)
                    )
                    .position(
                        x: target == "left"
                            ? 46 : target == "right" ? windowSize.width - 46 : windowSize.width / 2,
                        y: target == "top"
                            ? topClearance + 32
                            : target == "bottom" ? windowSize.height - 40 : (windowSize.height + 56) / 2
                    )
                    .allowsHitTesting(false)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .transaction { $0.animation = nil }
        .onAppear { engine.toolbarLayoutSize = panelSize }
        .onChange(of: panelSize) { _, size in engine.toolbarLayoutSize = size }
        .onChange(of: windowSize) { _, size in engine.repositionPanelsIfNeeded(windowSize: size) }
    }

}

struct ToolbarToolsView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @ObservedObject var laser: LaserPointerEngine
    private var activeSettings: ToolSettings? {
        get { engine.presentedToolSettings }
        nonmutating set { engine.presentedToolSettings = newValue }
    }
    @ViewState private var showMorePopover = false
    @ViewState private var showCustomizeSheet = false

    let screenController: ScreenAnnotationController?
    let columns: Int?
    let availableLength: CGFloat
    var externalActivePage: Binding<String>? = nil
    @ViewState private var internalActivePage = "common"
    @ViewState private var pageOffset = 0

    init(
        engine: BoardEngine,
        screenController: ScreenAnnotationController? = nil,
        columns: Int? = nil,
        availableLength: CGFloat = 600,
        externalActivePage: Binding<String>? = nil
    ) {
        self.engine = engine
        self.laser = engine.laserEngine
        self.screenController = screenController
        self.columns = columns
        self.availableLength = availableLength
        self.externalActivePage = externalActivePage
    }

    private var activePage: String {
        externalActivePage?.wrappedValue ?? internalActivePage
    }

    private func setActivePage(_ page: String) {
        guard page != activePage else { return }
        closeTransientToolPopovers()
        pageOffset = 0
        if let externalActivePage {
            externalActivePage.wrappedValue = page
        } else {
            internalActivePage = page
        }
    }

    private func closeTransientToolPopovers() {
        engine.showColorPopover = false
        engine.showShapesPopover = false
        engine.showEraserPopover = false
        activeSettings = nil
        showMorePopover = false
    }

    private var vertical: Bool { screenController?.controlsDock.isVertical ?? engine.isToolbarVertical }

    private var visibleIDs: [String] {
        ToolbarContentPolicy.visibleIDs(engine.toolbarPreferences, screen: screenController != nil)
    }
    private var usesLabels: Bool { engine.toolbarPreferences.displayMode == "labels" }
    private var pageIDs: [String] {
        ToolbarContentPolicy.pageIDs(
            engine.toolbarPreferences, screen: screenController != nil, page: activePage)
    }
    private var toolsAvailableLength: CGFloat {
        max(ToolbarContentPolicy.horizontalTileWidth, availableLength - (vertical ? ToolbarContentPolicy.verticalChrome : ToolbarContentPolicy.horizontalChrome))
    }
    private var pageCapacity: Int {
        ToolbarContentPolicy.pageCapacity(
            itemCount: pageIDs.count,
            availableLength: toolsAvailableLength,
            vertical: vertical
        )
    }
    private var needsPaging: Bool {
        pageCapacity < pageIDs.count
    }
    private var currentPageOffset: Int {
        min(pageOffset, max(0, ((pageIDs.count - 1) / pageCapacity) * pageCapacity))
    }
    private var shownPageIDs: [String] {
        Array(pageIDs.dropFirst(currentPageOffset).prefix(pageCapacity))
    }
    private var renderedIDs: [String] { usesLabels ? ToolbarPreferences.fixedTools + shownPageIDs : visibleIDs }
    private typealias ToolSettings = BoardToolSettings

    private var overflowIDs: [String] {
        ToolbarPreferences.allDefinitions
            .filter { ToolbarContentPolicy.isAvailable($0.id, screen: screenController != nil) }
            .map(\.id)
            .filter { !renderedIDs.contains($0) }
    }

    private func presentSettings(_ settings: ToolSettings) {
        // 設定只有這一個host，不依賴工具是否在目前分頁／組或被隱藏。
        // 等More關閉後才開新面板，避免兩個NSPopover同時爭用原生視窗。
        let wasShowingMore = showMorePopover
        showMorePopover = false
        if wasShowingMore {
            DispatchQueue.main.async { activeSettings = settings }
        } else {
            activeSettings = settings
        }
    }

    private func toolTitle(_ id: String) -> String {
        if id == "undo" { return "復原" }
        if id == "redo" { return "重做" }
        return ToolbarPreferences.allDefinitions.first { $0.id == id }?.displayName ?? id
    }

    var body: some View {
        Group {
            if engine.toolbarPreferences.displayMode == "labels" {
                labeledTools
            } else if let columns {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: columns), spacing: 4
                ) {
                    items
                }
            } else {
                let layout =
                    vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
                layout { items }
            }
        }
        .onAppear {
            if let data = UserDefaults.standard.data(forKey: "HeiBan.toolbarPreferences"),
                let preferences = try? JSONDecoder().decode(ToolbarPreferences.self, from: data),
                preferences != engine.toolbarPreferences
            {
                engine.toolbarPreferences = preferences
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("HeiBan.toolbarPreferencesChanged"))
        ) { notification in
            guard let source = notification.object as? BoardEngine, source !== engine,
                source.toolbarPreferences != engine.toolbarPreferences
            else { return }
            engine.toolbarPreferences = source.toolbarPreferences
        }
        .onChange(of: engine.toolbarPreferences) { _, _ in
            pageOffset = 0
            screenController?.toolbarPreferencesChanged()
        }
        .onChange(of: availableLength) { _, _ in pageOffset = 0 }
        .popover(
            item: Binding(get: { activeSettings }, set: { activeSettings = $0 }), arrowEdge: settingsArrowEdge
        ) { settings in
            settingsContent(settings)
        }
    }

    private var labeledTools: some View {
        let shell = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
        return shell {
            labeledToolTile(id: "select")
            labeledToolTile(id: "laser")
            labeledToolTile(id: "cane")
            VStack(alignment: .leading, spacing: 4) {
                pageSelector
                // 移除內部捲動拉桿（ScrollView），直接以單列平鋪顯示目前分頁工具。
                pageTools
            }
            .frame(maxWidth: vertical ? 124 : nil, alignment: .leading)
            moreButton
        }
    }

    @ViewBuilder private var pageSelector: some View {
        let pageBinding = Binding<String>(
            get: { activePage },
            set: { setActivePage($0) }
        )
        if vertical {
            Picker(L10n.t("工具分頁"), selection: pageBinding) {
                ForEach(Array(ToolbarContentPolicy.pages.enumerated()), id: \.element) { index, id in
                    Text(L10n.t(ToolbarContentPolicy.pageTitles[index])).tag(id)
                }
            }.labelsHidden().frame(width: 120)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(ToolbarContentPolicy.pages.enumerated()), id: \.element) { index, id in
                    let isSelected = activePage == id
                    Button {
                        setActivePage(id)
                    } label: {
                        Text(L10n.t(ToolbarContentPolicy.pageTitles[index]))
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
                                in: Capsule()
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize()
        }
    }

    private var pageTools: some View {
        let row =
            vertical
            ? AnyLayout(VStackLayout(spacing: ToolbarContentPolicy.verticalTileSpacing))
            : AnyLayout(HStackLayout(spacing: ToolbarContentPolicy.horizontalTileSpacing))
        return row {
            if needsPaging {
                Button {
                    pageOffset = max(0, currentPageOffset - pageCapacity)
                } label: {
                    Image(systemName: vertical ? "chevron.up" : "chevron.left")
                        .frame(width: 20, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(currentPageOffset == 0)
                .help(L10n.t("上一組工具"))
            }
            ForEach(shownPageIDs, id: \.self) { id in
                labeledToolTile(id: id)
            }
            if shownPageIDs.isEmpty {
                Text(L10n.t("由自訂工具列加入常用工具"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: vertical ? 120 : 140, height: vertical ? 44 : 58, alignment: .leading)
            }
            if needsPaging {
                Button {
                    pageOffset = currentPageOffset + pageCapacity
                } label: {
                    Image(systemName: vertical ? "chevron.down" : "chevron.right")
                        .frame(width: 20, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(currentPageOffset + pageCapacity >= pageIDs.count)
                .help(L10n.t("下一組工具"))
            }
        }
    }

    @ViewBuilder private func labeledToolTile(id: String) -> some View {
        if id == "dock" {
            Menu {
                dockActions
            } label: {
                toolTileLabel(id: id)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        } else if id == "undoRedo" {
            HStack(spacing: 2) {
                historyTile(id: "undo")
                historyTile(id: "redo")
            }.frame(
                width: vertical ? 124 : ToolbarContentPolicy.horizontalTileWidth,
                height: vertical ? ToolbarContentPolicy.verticalTileHeight : 58)
        } else {
            Button {
                performToolAction(id)
            } label: {
                toolTileLabel(id: id)
            }
            .buttonStyle(.plain).disabled(toolDisabled(id))
            .contextMenu { toolContextMenu(id) }
        }
    }

    private func toolTileLabel(id: String) -> some View {
        let tile = vertical ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(spacing: 2))
        let hasColorLine = ToolbarContentPolicy.hasToolColor(id)
        let isColorActive = ToolbarContentPolicy.isToolColorActive(toolKey: id, currentTool: engine.currentTool)
        return tile {
            VStack(spacing: 2) {
                toolGlyph(id).frame(width: 28, height: 22)
                if hasColorLine {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: engine.activeColor))
                        .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                        .frame(width: 22, height: 3)
                        .opacity(isColorActive ? 1.0 : 0.0)
                }
            }
            .frame(width: 28, height: 28)
            Text(L10n.t(toolTitle(id))).font(.system(size: 10)).lineLimit(2)
                .multilineTextAlignment(vertical ? .leading : .center)
            if vertical { Spacer(minLength: 0) }
        }
        .padding(.horizontal, vertical ? 6 : 2)
        .frame(
            width: vertical ? 124 : (ToolbarPreferences.isFixedTool(id) ? 48 : ToolbarContentPolicy.horizontalTileWidth),
            height: vertical ? ToolbarContentPolicy.verticalTileHeight : 58
        )
        .background(
            toolSelected(id) ? Color.accentColor.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(Rectangle())
    }

    private func historyTile(id: String) -> some View {
        Button {
            performToolAction(id)
        } label: {
            VStack(spacing: 3) {
                toolGlyph(id).frame(width: 20, height: 20)
                Text(L10n.t(toolTitle(id))).font(.system(size: 9)).lineLimit(1)
            }.frame(maxWidth: .infinity).frame(height: 40).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(toolDisabled(id))
            .help(L10n.t(toolTitle(id))).accessibilityLabel(L10n.t(toolTitle(id)))
    }

    private func drawingTool(_ id: String) -> ToolType? {
        [
            "select": ToolType.select, "cane": .cane, "pen": .pen, "curve": .curve, "highlighter": .highlighter,
            "paint": .paint, "sticky": .sticky, "text": .text, "tape": .tape, "lasso": .lasso,
        ][id]
    }

    /// 圖示、整塊圖文磚及More只有這份命令路由；設定呈現與操作命令分開。
    private func performToolAction(_ id: String) {
        if let tool = drawingTool(id) {
            selectTool(tool)
            return
        }
        switch id {
        case "magnet": engine.toggleMagnet()
        case "eraser":
            if engine.currentTool != .eraser { selectTool(.eraser) }
            presentSettings(.eraser)
        case "boardEraser":
            screenController?.setDrawing(true)
            engine.setBoardEraserVisible(!engine.toolbarPreferences.boardEraserVisible)
        case "ruler":
            screenController?.setDrawing(true)
            engine.ruler.enabled.toggle()
        case "shapes":
            screenController?.setDrawing(true)
            presentSettings(.shapes)
        case "laser":
            let resumingScreen = screenController?.isDrawing == false
            screenController?.setDrawing(true)
            if engine.currentTool == .laser && !resumingScreen {
                presentSettings(.laser)
            } else {
                if engine.currentTool != .laser { selectTool(.laser) }
                engine.laserEngine.isEnabled = true
            }
        case "screenshot": captureScreenshot()
        case "image": importImage()
        case "color": presentSettings(.color)
        case "lineStyle":
            let style = engine.selectedLineStyle.valueOrNil ?? engine.activeLineStyle
            let next = style == "solid" ? "dashed" : "solid"
            if engine.selectedIds.isEmpty {
                engine.activeLineStyle = next
            } else {
                engine.setSelectedLineStyle(next)
            }
        case "layers":
            screenController?.setDrawing(true)
            engine.toggleLayerPanel()
        case "pins": engine.togglePinManager()
        case "compass":
            screenController?.setDrawing(true)
            engine.toggleCompass()
        case "calculator":
            screenController?.setDrawing(true)
            engine.toggleCalculator()
        case "timer":
            screenController?.setDrawing(true)
            engine.toggleTimer()
        case "viewLock": engine.toggleViewportLock()
        case "undo": if engine.canUndo { engine.undo() }
        case "redo": if engine.canRedo { engine.redo() }
        case "clearAll": clearCanvas()
        default: break  // dock及undoRedo由完整Menu／獨立歷史按鈕提供語義。
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
                VStack(alignment: .leading, spacing: 6) {
                    // 隱藏與其他分頁工具以單一輕量按鈕呈現，不在 Overflow 重複掛載 .popover，杜絕多重 NSHostingView 搶奪錨點崩潰。
                    ForEach(overflowIDs, id: \.self) { id in
                        overflowToolRow(id: id)
                    }
                    Divider()
                    Picker(
                        L10n.t("工具列格式"),
                        selection: Binding(
                            get: { engine.toolbarPreferences.displayMode },
                            set: {
                                engine.toolbarPreferences.displayMode = $0
                                engine.saveToolbarPreferences()
                            })
                    ) {
                        Text(L10n.t("只有圖示")).tag("icons")
                        Text(L10n.t("圖示與文字（分頁）")).tag("labels")
                    }
                    Toggle(
                        L10n.t("顯示板擦"),
                        isOn: Binding(
                            get: { engine.toolbarPreferences.boardEraserVisible },
                            set: { engine.setBoardEraserVisible($0) }))
                    if screenController == nil {
                        Toggle(
                            L10n.t("顯示藤條"),
                            isOn: Binding(
                                get: { engine.toolbarPreferences.caneVisible },
                                set: { engine.setCaneVisible($0) }))
                    }
                    Button(L10n.t("自訂工具列…")) {
                        showMorePopover = false
                        DispatchQueue.main.async { showCustomizeSheet = true }
                    }
                    if let controller = screenController {
                        Divider()
                        Menu(L10n.t("工具列位置")) {
                            ForEach(AnnotationToolbarDock.allCases, id: \.rawValue) { edge in
                                Button(L10n.t(edge.title)) {
                                    showMorePopover = false
                                    controller.setControlsDock(edge)
                                }
                            }
                        }
                        Button(L10n.t("收合工具列")) {
                            showMorePopover = false
                            controller.setControlsCollapsed(true)
                        }
                        Button(L10n.t("儲存可編輯註記 .heiban…")) { controller.saveEditable() }
                        Button(L10n.t("使用手冊")) { controller.showUserGuide() }
                        Text(controller.message).font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(12)
            }.frame(width: 260).frame(maxHeight: 480)
        }
        .popover(
            isPresented: Binding(
                get: { screenController != nil && engine.showLayerPanel },
                set: { if screenController != nil { engine.showLayerPanel = $0 } }),
            arrowEdge: settingsArrowEdge
        ) {
            LayerPanelView(engine: engine).frame(width: 280, height: 440)
        }
        // NSPanel 內使用 popover，避免 sheet 搶走透明畫布的鍵盤／視窗生命週期。
        .popover(isPresented: $showCustomizeSheet, arrowEdge: settingsArrowEdge) {
            ToolbarCustomizeSheet(
                engine: engine, isPresented: $showCustomizeSheet,
                screenContext: screenController != nil)
        }
    }

    @ViewBuilder private func overflowToolRow(id: String) -> some View {
        if id == "dock" {
            Menu {
                dockActions
            } label: {
                overflowLabel(id)
            }.buttonStyle(.plain)
        } else if id == "undoRedo" {
            HStack {
                undoButton
                redoButton
                Text(L10n.t(toolTitle(id)))
                Spacer()
            }
        } else {
            Button {
                // 一般命令先關More；設定命令自行等原生popover退出再呈現。
                if ["color", "shapes", "eraser"].contains(id) {
                    performToolAction(id)
                } else {
                    showMorePopover = false
                    DispatchQueue.main.async { performToolAction(id) }
                }
            } label: {
                overflowLabel(id)
            }
            .buttonStyle(.plain).disabled(toolDisabled(id))
            .contextMenu { toolContextMenu(id) }
        }
    }

    private func overflowLabel(_ id: String) -> some View {
        HStack(spacing: 10) {
            toolGlyph(id).frame(width: 24, height: 24)
            Text(L10n.t(toolTitle(id))).font(.system(size: 13))
            Spacer()
        }.contentShape(Rectangle())
    }

    private var settingsArrowEdge: Edge {
        switch screenController?.controlsDock.rawValue ?? engine.toolbarDock {
        case "left": return .leading
        case "right": return .trailing
        case "bottom": return .bottom
        default: return .top
        }
    }

    @ViewBuilder private func renderToolItem(id: String) -> some View {
        if id == "dock" {
            Menu {
                dockActions
            } label: {
                toolGlyph(id).frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        } else if id == "undoRedo" {
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
            layout {
                undoButton
                redoButton
            }
        } else {
            Button {
                performToolAction(id)
            } label: {
                let hasColor = ToolbarContentPolicy.hasToolColor(id)
                let isColorActive = ToolbarContentPolicy.isToolColorActive(toolKey: id, currentTool: engine.currentTool)
                VStack(spacing: 1) {
                    toolGlyph(id).frame(width: 32, height: 26)
                    if hasColor {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: engine.activeColor))
                            .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                            .frame(width: 18, height: 2.5)
                            .opacity(isColorActive ? 1.0 : 0.0)
                    }
                }
                .frame(width: 32, height: 32)
                .background(
                    toolSelected(id) ? Color.accentColor.opacity(0.2) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(toolDisabled(id)).help(L10n.t(toolTitle(id)))
                .contextMenu { toolContextMenu(id) }
        }
    }

    @ViewBuilder private var dockActions: some View {
        Button(L10n.t("靠左 · 直向")) {
            showMorePopover = false
            dock("left")
        }
        Button(L10n.t("靠右 · 直向")) {
            showMorePopover = false
            dock("right")
        }
        Button(L10n.t("靠上 · 橫向")) {
            showMorePopover = false
            dock("top")
        }
        Button(L10n.t("靠下 · 橫向")) {
            showMorePopover = false
            dock("bottom")
        }
    }

    @ViewBuilder private func toolGlyph(_ id: String) -> some View {
        if id == "boardEraser" {
            BoardEraserArtwork().frame(width: 28, height: 20)
        } else if id == "cane" {
            HeiBanCaneIcon().frame(width: 18, height: 18)
        } else if id == "magnet" {
            HeiBanMagnetIcon().frame(width: 18, height: 18)
        } else if id == "pins" {
            HeiBanPinIcon().frame(width: 18, height: 18)
        } else if id == "compass" {
            HeiBanCompassIcon().frame(width: 18, height: 18)
        } else if id == "text" {
            Text("T").font(.system(size: 20, weight: .medium, design: .serif))
        } else if id == "lineStyle" {
            Image(systemName: (engine.selectedLineStyle.valueOrNil ?? engine.activeLineStyle) == "solid" ? "minus" : "ellipsis")
                .font(.system(size: 16, weight: .bold))
        } else if id == "color" {
            Circle().fill(
                Color(
                    hex: laser.isEnabled
                        ? laser.color : (engine.selectedStrokeColor.valueOrNil ?? engine.activeColor))
            )
            .frame(width: 24, height: 24).overlay(Circle().stroke(.secondary, lineWidth: 1))
        } else {
            let icon =
                id == "undo"
                ? "arrow.uturn.backward"
                : id == "redo"
                    ? "arrow.uturn.forward"
                    : ToolbarPreferences.allDefinitions.first { $0.id == id }?.icon ?? "questionmark"
            Image(systemName: icon).font(.system(size: 16))
                .foregroundStyle(id == "clearAll" ? Color.red : Color.primary)
        }
    }

    private func toolSelected(_ id: String) -> Bool {
        if let tool = drawingTool(id) { return engine.currentTool == tool }
        switch id {
        case "boardEraser": return engine.toolbarPreferences.boardEraserVisible
        case "eraser": return engine.currentTool == .eraser
        case "laser": return engine.currentTool == .laser || laser.isEnabled
        case "ruler": return engine.ruler.enabled
        case "magnet": return engine.toolbarPreferences.magnetEnabled
        case "shapes": return activeSettings == .shapes
        case "color": return activeSettings == .color
        case "layers": return engine.showLayerPanel
        case "pins": return engine.showPinManager
        case "compass": return engine.compassEngine.isEnabled
        case "calculator": return engine.calculator.isVisible
        case "timer": return engine.timerCoordinator.isVisible
        case "viewLock": return engine.viewportLocked
        case "lineStyle": return (engine.selectedLineStyle.valueOrNil ?? engine.activeLineStyle) != "solid"
        default: return false
        }
    }
    private func toolDisabled(_ id: String) -> Bool {
        (id == "undo" && !engine.canUndo) || (id == "redo" && !engine.canRedo)
    }

    @ViewBuilder private func toolContextMenu(_ id: String) -> some View {
        if id == "ruler" { Button(L10n.t("尺規角度與配色…")) { presentSettings(.ruler) } }
        if id == "laser" {
            Button(L10n.t("雷射筆設定…")) { presentSettings(.laser) }
            Button(L10n.t("停止雷射筆")) { selectTool(.select) }
        }
        if id == "cane" && screenController == nil {
            Button(L10n.t(engine.toolbarPreferences.caneVisible ? "隱藏右下藤條快捷" : "顯示右下藤條快捷")) {
                engine.setCaneVisible(!engine.toolbarPreferences.caneVisible)
            }
        }
    }

    @ViewBuilder private func settingsContent(_ settings: ToolSettings) -> some View {
        switch settings {
        case .color:
            if laser.isEnabled {
                LaserSettingsView(laser: laser)
            } else {
                ToolbarBrushSettings(engine: engine)
            }
        case .shapes:
            ShapesMenuView(
                engine: engine,
                isPresented: Binding(
                    get: { activeSettings == .shapes }, set: { if !$0 { activeSettings = nil } }),
                onSelect: selectTool)
        case .laser: LaserSettingsView(laser: laser)
        case .ruler: RulerSettingsView(engine: engine)
        case .eraser:
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("橡皮擦")).font(.headline)
                Toggle(L10n.t("顯示板擦"), isOn: Binding(
                    get: { engine.toolbarPreferences.boardEraserVisible },
                    set: {
                        screenController?.setDrawing(true)
                        engine.setBoardEraserVisible($0)
                    }))
                Picker(L10n.t("模式"), selection: $engine.eraserMode) {
                    Text(L10n.t("物件擦除")).tag(EraserMode.object)
                    Text(L10n.t("像素擦除")).tag(EraserMode.pixel)
                }.pickerStyle(.segmented)
                Text(L10n.t(engine.eraserMode == .object ? "擦除筆畫或幾何圖形" : "只擦除筆畫上的局部區域"))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(L10n.t("大小"))
                    Slider(value: $engine.eraserSize, in: 4...120, step: 2)
                    Text("\(Int(engine.eraserSize)) pt").monospacedDigit().frame(
                        width: 46, alignment: .trailing)
                }.font(.caption)
            }.padding(16).frame(width: 300)
        }
    }

    private var undoButton: some View {
        ToolButton(
            icon: "arrow.uturn.backward", tooltip: "復原 (Cmd+Z)", isSelected: false,
            action: { performToolAction("undo") }
        )
        .disabled(!engine.canUndo)
    }
    private var redoButton: some View {
        ToolButton(
            icon: "arrow.uturn.forward", tooltip: "重做 (Cmd+Shift+Z)", isSelected: false,
            action: { performToolAction("redo") }
        )
        .disabled(!engine.canRedo)
    }
    private func selectTool(_ tool: ToolType) {
        if let controller = screenController { controller.selectTool(tool) } else { engine.selectTool(tool) }
    }
    private func captureScreenshot() {
        if let controller = screenController {
            controller.captureScreen()
        } else {
            engine.captureScreenAndPaste()
        }
    }
    private func importImage() {
        if let controller = screenController {
            controller.importImage()
        } else {
            engine.importImageFromFilePrompt()
        }
    }
    private func clearCanvas() {
        if let controller = screenController { controller.clearAnnotations() } else { engine.clearAll() }
    }
    private func dock(_ edge: String) {
        if let controller = screenController, let dock = AnnotationToolbarDock(rawValue: edge) {
            controller.setControlsDock(dock)
        } else {
            engine.setToolbarDock(edge)
        }
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
                            engine.currentTool == type
                                ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    engine.currentTool == type
                                        ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1)
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
                    if icon == "circle.circle" {
                        HeiBanCompassIcon()
                    } else if icon == "heiban.magnet" {
                        HeiBanMagnetIcon()
                    } else {
                        Image(systemName: icon).font(.system(size: 15))
                    }
                }
            }
            .foregroundColor(isSelected ? Color.accentColor : Color.primary)
            .frame(width: 32, height: 32)
            .background(
                isSelected ? Color.accentColor.opacity(0.22) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.t(tooltip))
        .accessibilityLabel(L10n.t(tooltip))
        .accessibilityValue(L10n.t(isSelected ? "已啟用" : "未啟用"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

/// 兩種畫布共用同一外殼；工具列尺寸由 Core policy 決定，NSPanel 只負責停靠。
struct ToolbarPanelSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.98),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}
