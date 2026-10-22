import SwiftUI
import HeiBanCore

// Explicit alias selects the property wrapper on SDKs that also expose a State macro.
typealias ViewState<Value> = SwiftUI.State<Value>

struct HomeView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @StateObject private var shelf = LibraryShelf(library: BoardEngine.library)
    @AppStorage("HeiBan.home.sidebar") private var sidebar = true
    @AppStorage("HeiBan.home.cardWidth") private var cardWidth = 190.0
    @AppStorage("HeiBan.home.sort") private var sort = "updated"
    @ViewState private var section = "all"
    @ViewState private var format = "all"
    @ViewState private var search = ""
    @ViewState private var settings = false
    @ViewState private var selectionMode = false
    @ViewState private var selectedBoardIDs: Set<String> = []
    @ViewState private var confirmDeleteBoards = false
    @ViewState private var showAdvancedSheet = false
    @ViewState private var renaming: BoardMetadata?
    @ViewState private var renameTitle = ""
    private let sage = Color(red: 0.24, green: 0.43, blue: 0.35)

    private var boards: [BoardMetadata] {
        let source = section == "trash" ? engine.trashedLibraryBoards : engine.libraryBoards
        return source.filter {
            (section != "favorites" || shelf.favorites.contains($0.id)) &&
            (format == "all" || $0.iconCanvasMode.rawValue == format) &&
            (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
        }.sorted {
            if sort == "title" { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if sort == "created" { return $0.createdAt > $1.createdAt }
            return $0.updatedAt > $1.updatedAt
        }
    }
    private var heading: String { section == "favorites" ? "收藏" : section == "trash" ? "垃圾桶" : "我的作品" }
    var body: some View {
        HStack(spacing: 0) {
            sidebarView
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    HeiBanLogo().frame(width: 112, height: 60)
                    Spacer()
                    Button { selectionMode.toggle(); selectedBoardIDs.removeAll() } label: { Image(systemName: selectionMode ? "checkmark.circle.fill" : "checkmark.circle") }
                        .disabled(section == "trash").help(L10n.t("選取多份作品")).accessibilityLabel(L10n.t(selectionMode ? "結束多選" : "選取多份作品"))
                    Button { engine.openFromFilePrompt() } label: { Label(L10n.t("匯入"), systemImage: "square.and.arrow.down") }
                    Button { showAdvancedSheet = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.borderedProminent).tint(sage).keyboardShortcut("n", modifiers: .command).help(L10n.t("新增筆記本、無邊界筆記或有邊界黑板"))
                    TextField(L10n.t("搜尋作品"), text: $search).textFieldStyle(.roundedBorder).frame(width: 200)
                }
                HStack {
                    Text(L10n.t(heading)).font(.title2.weight(.semibold))
                    Text("\(boards.count)").foregroundStyle(.secondary).monospacedDigit()
                    Spacer()
                    Picker(L10n.t("格式"), selection: $format) {
                        Text(L10n.t("全部格式")).tag("all"); Text(L10n.t("筆記本")).tag("notebook")
                        Text(L10n.t("無邊界筆記")).tag("infinite"); Text(L10n.t("有邊界黑板")).tag("fixed")
                    }.labelsHidden().frame(width: 132)
                    Picker(L10n.t("排序"), selection: $sort) {
                        Text(L10n.t("最近修改")).tag("updated"); Text(L10n.t("建立日期")).tag("created"); Text(L10n.t("名稱")).tag("title")
                    }.labelsHidden().frame(width: 112)
                    Menu {
                        Button(L10n.t("緊湊")) { cardWidth = 160 }; Button(L10n.t("適中")) { cardWidth = 190 }; Button(L10n.t("大圖")) { cardWidth = 250 }
                    } label: {
                        MenuDisclosureLabel(L10n.t("縮圖大小")) { Image(systemName: "square.grid.2x2").font(.system(size: 16)) }
                    }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(L10n.t("縮圖大小"))
                }
                if selectionMode {
                    HStack {
                        Text("已選 \(selectedBoardIDs.count) 份").font(.subheadline)
                        Button(L10n.t("全選目前結果")) { selectedBoardIDs = Set(boards.map(\.id)) }
                        Button(L10n.t("移到垃圾桶")) { confirmDeleteBoards = true }.disabled(selectedBoardIDs.isEmpty)
                        Spacer()
                        Button(L10n.t("完成")) { selectionMode = false; selectedBoardIDs.removeAll() }
                    }.padding(10).background(sage.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                if section == "trash" { Text(L10n.t("這裡的作品可還原，原本的筆跡、圖片與頁面都會保留。")).font(.caption).foregroundStyle(.secondary) }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth), spacing: 20)], spacing: 24) {
                        ForEach(boards) { board in card(board) }
                    }.padding(.vertical, 4)
                    if boards.isEmpty {
                        ContentUnavailableView(L10n.t(heading == "垃圾桶" ? "垃圾桶是空的" : section == "favorites" && search.isEmpty ? "收藏常用的作品" : engine.libraryBoards.isEmpty ? "第一份作品，從這裡開始" : "沒有符合的作品"), systemImage: section == "favorites" ? "star" : section == "trash" ? "trash" : "square.grid.2x2", description: Text(L10n.t(section == "favorites" ? "點作品上的星號，就能在這裡快速找到。" : "使用上方搜尋與格式篩選，或點＋建立作品。")))
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                if let error = shelf.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
                if let status = engine.statusMessage { Text(status).font(.caption).foregroundStyle(sage) }
            }.padding(24).background(Color(red: 0.98, green: 0.985, blue: 0.975))
        }
        .buttonStyle(.bordered)
        .onAppear { ensureQuickStartOnFirstLaunch(); shelf.reload(); engine.refreshLibrary() }
        .onChange(of: section) { _, _ in selectionMode = false; selectedBoardIDs.removeAll() }
        .onChange(of: search) { _, _ in retainVisibleSelection() }
        .onChange(of: format) { _, _ in retainVisibleSelection() }
        .environment(\.layoutDirection, language.direction)
        .sheet(isPresented: $settings) { NativeSettingsView() }
        .sheet(item: $renaming) { board in
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.t("重新命名黑板")).font(.headline)
                TextField(L10n.t("名稱"), text: $renameTitle).textFieldStyle(.roundedBorder)
                HStack { Spacer(); Button(L10n.t("取消")) { renaming = nil }; Button(L10n.t("儲存")) { engine.renameLibraryBoard(board.id, title: renameTitle); renaming = nil }.keyboardShortcut(.defaultAction) }
            }.padding(24).frame(width: 360)
        }
        .sheet(isPresented: $showAdvancedSheet) {
            AdvancedBoardSheet(engine: engine, isPresented: $showAdvancedSheet, initialMode: .notebook, initialTheme: .whiteboard)
        }
        .alert(L10n.t("移到垃圾桶？"), isPresented: $confirmDeleteBoards) {
            Button(L10n.t("取消"), role: .cancel) { }
            Button(L10n.t("移到垃圾桶"), role: .destructive) { engine.trashLibraryBoards(selectedBoardIDs); selectedBoardIDs.removeAll() }
        } message: { Text("所選 \(selectedBoardIDs.count) 份作品會保留在垃圾桶，可從左側還原。") }
    }
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { withAnimation(.easeInOut(duration: 0.18)) { sidebar.toggle() } } label: { Image(systemName: "sidebar.left") }.buttonStyle(.plain).help(L10n.t(sidebar ? "收合側欄" : "展開側欄"))
                if sidebar { Text(L10n.t("作品庫")).font(.headline); Spacer() }
            }.padding(.bottom, 20)
            shelfButton("all", "所有作品", "square.grid.2x2", engine.libraryBoards.count)
            shelfButton("favorites", "收藏", "star", engine.libraryBoards.filter { shelf.favorites.contains($0.id) }.count)
            shelfButton("trash", "垃圾桶", "trash", engine.trashedLibraryBoards.count)
            Spacer()
            Button { ScreenAnnotationController.shared.start() } label: {
                HStack {
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    if sidebar { Text(L10n.t("螢幕畫布")) }
                }
            }
            .buttonStyle(.plain)
            .help(L10n.t("我的螢幕就是我的畫布"))
            .accessibilityLabel(L10n.t("螢幕畫布"))
            Button { settings = true } label: {
                HStack { Image(systemName: "person.crop.circle"); if sidebar { Text(L10n.t("帳號與設定")) } }
            }.buttonStyle(.plain).help(L10n.t("帳號與設定"))
            Menu {
                Button(L10n.t("使用手冊")) { HeiBanUserGuide.shared.show() }
                Button(L10n.t("操作說明 · 全工具指南")) { openQuickStartGuideBoard() }
                Button(L10n.t("建立新的操作指南練習")) { openQuickStartGuideBoard(fresh: true) }
                Button(L10n.t("我的螢幕就是我的畫布")) { ScreenAnnotationController.shared.start() }
                Divider()
                Button(L10n.t("建立功能示範黑板")) { engine.loadShowcaseBoard() }
            } label: {
                HStack { Image(systemName: "questionmark.circle"); if sidebar { Text(L10n.t("使用說明")) } }
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).help(L10n.t("使用說明"))
        }.padding(16).padding(.top, 28).frame(width: sidebar ? 188 : 56).frame(maxHeight: .infinity)
            .background(Color(red: 0.925, green: 0.94, blue: 0.915))
    }
    private func shelfButton(_ key: String, _ title: String, _ icon: String, _ count: Int) -> some View {
        Button { section = key } label: {
            HStack(spacing: 10) { Image(systemName: icon).frame(width: 20); if sidebar { Text(L10n.t(title)); Spacer(); Text("\(count)").font(.caption).foregroundStyle(.secondary) } }
                .foregroundStyle(section == key ? sage : .primary).padding(.vertical, 10).padding(.horizontal, sidebar ? 8 : 0)
                .frame(maxWidth: .infinity, alignment: .leading).background(section == key ? sage.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).help(L10n.t(title))
    }
    private func retainVisibleSelection() { selectedBoardIDs.formIntersection(Set(boards.map(\.id))) }
    private func toggleSelection(_ id: String) { if selectedBoardIDs.contains(id) { selectedBoardIDs.remove(id) } else { selectedBoardIDs.insert(id) } }
    private func card(_ board: BoardMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if section == "trash" { engine.restoreLibraryBoard(board.id) }
                else if selectionMode { toggleSelection(board.id) }
                else { engine.openLibraryBoard(board.id) }
            } label: {
                BoardThumbnailView(board: board).id(board.id + board.updatedAt)
                    .frame(height: cardWidth * 0.85).background(Color(hex: board.backgroundColor))
                    .overlay(alignment: .topLeading) { BoardFormatBadge(board: board).scaleEffect(0.85, anchor: .topLeading).padding(7) }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedBoardIDs.contains(board.id) ? sage : Color.black.opacity(0.07), lineWidth: selectedBoardIDs.contains(board.id) ? 2 : 1))
            }.buttonStyle(.plain)
                .accessibilityLabel(section == "trash" ? "還原 \(board.title)" : selectionMode ? "\(selectedBoardIDs.contains(board.id) ? "取消選取" : "選取") \(board.title)" : "開啟 \(board.title)，\(board.canvasFormatLabel)")
                    .overlay(alignment: .bottomTrailing) {
                        if section != "trash" {
                            Button { shelf.toggleFavorite(board.id) } label: { Image(systemName: shelf.favorites.contains(board.id) ? "star.fill" : "star").foregroundStyle(shelf.favorites.contains(board.id) ? sage : .secondary).padding(7).background(.regularMaterial, in: Circle()) }
                                .buttonStyle(.plain).help(L10n.t(shelf.favorites.contains(board.id) ? "取消收藏" : "加入收藏"))
                                .accessibilityLabel("\(shelf.favorites.contains(board.id) ? "取消收藏" : "收藏") \(board.title)").padding(7)
                        }
                    }
            HStack {
                if selectionMode { Image(systemName: selectedBoardIDs.contains(board.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(sage) }
                Text(board.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                Menu {
                    if section == "trash" { Button(L10n.t("還原")) { engine.restoreLibraryBoard(board.id) } }
                    else {
                        Button(L10n.t(shelf.favorites.contains(board.id) ? "取消收藏" : "加入收藏")) { shelf.toggleFavorite(board.id) }
                        Button(L10n.t("重新命名")) { renameTitle = board.title; renaming = board }
                        Button(L10n.t("製作副本")) { engine.duplicateLibraryBoard(board.id) }
                        Divider()
                        Button(L10n.t("移到垃圾桶…"), role: .destructive) { selectedBoardIDs = [board.id]; confirmDeleteBoards = true }
                    }
                } label: {
                    MenuDisclosureLabel(L10n.t("作品的更多動作")) { Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)) }
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(L10n.t("作品的更多動作"))
            }
            Text(dateLabel(board.updatedAt)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
    private func dateLabel(_ value: String) -> String {
        let date = ISO8601DateFormatter().date(from: value)
        return date?.formatted(date: .abbreviated, time: .shortened) ?? "本機儲存"
    }

    private func quickStartGuideDocument() throws -> HeiBanDocument {
        let url = Bundle.module.url(forResource: "QuickStart-\(language.code)", withExtension: "heiban", subdirectory: "Guides")
            ?? Bundle.module.url(forResource: "QuickStart-zh-TW", withExtension: "heiban", subdirectory: "Guides")
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        return try HeiBanDocumentCodec.decode(from: Data(contentsOf: url))
    }

    private func ensureQuickStartOnFirstLaunch() {
        do {
            try QuickStartGuideStore(library: BoardEngine.library).installOnFirstLaunch(template: quickStartGuideDocument)
        } catch { guideError(error) }
    }

    private func openQuickStartGuideBoard(fresh: Bool = false) {
        guard engine.saveBeforeLeaving() else { return }
        do {
            let store = QuickStartGuideStore(library: BoardEngine.library)
            let id = try fresh ? store.createFresh(template: quickStartGuideDocument)
                : store.openOrCreate(template: quickStartGuideDocument)
            engine.refreshLibrary()
            engine.openLibraryBoard(id)
        } catch { guideError(error) }
    }

    private func guideError(_ error: Error) {
        engine.showTemporaryStatus("\(L10n.t("無法開啟操作指南"))：\(error.localizedDescription)")
    }

}

struct AdvancedBoardSheet: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool

    @ViewState<String> private var title: String = ""
    @ViewState<CanvasMode> private var mode: CanvasMode = .notebook
    @ViewState<CanvasPreset> private var preset: CanvasPreset = .a4_portrait
    @ViewState<String> private var orientation: String = "portrait"
    @ViewState<String> private var coverStyle: String = "classic_blackboard"
    @ViewState<GridStyle> private var gridStyle: GridStyle = .dots
    @ViewState<String> private var bgColor: String = "#172e25"
    @ViewState<String> private var gridColor: String = ""

    init(engine: BoardEngine, isPresented: Binding<Bool>, initialMode: CanvasMode = .notebook,
         initialTitle: String = "", initialTheme: BoardTheme = .whiteboard) {
        self.engine = engine
        self._isPresented = isPresented
        self._mode = ViewState(initialValue: initialMode)
        self._title = ViewState(initialValue: initialTitle)
        self._bgColor = ViewState(initialValue: initialTheme.defaultBackgroundColor)
        self._gridStyle = ViewState(initialValue: initialMode == .notebook ? .lines : .dots)
    }

    private let sage = Color(red: 0.24, green: 0.43, blue: 0.35)

    let covers = [
        ("classic_blackboard", "經典黑板"),
        ("vintage_leather", "復古皮革"),
        ("obsidian", "曜石黑"),
        ("kraft_paper", "溫暖牛皮"),
        ("pastel_dawn", "晨曦粉彩"),
        ("minimal_white", "現代純白")
    ]

    let bgColors = [
        ("#172e25", "墨綠黑板"),
        ("#18181b", "曜石黑"),
        ("#FAF8F5", "象牙暖白"),
        ("#ffffff", "極致純白"),
        ("#F5EADB", "溫暖牛皮"),
        ("#1e293b", "科技岩灰")
    ]

    let gridColors = [
        ("", "自適應對比"),
        ("#FFFFFF", "純白格線"),
        ("#D1D5DB", "淺灰格線"),
        ("#4B5563", "深灰格線"),
        ("#1F2937", "柔黑格線")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.t("新增筆記或黑板"))
                    .font(.headline)
                Spacer()
                Button(L10n.t("關閉")) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                Section(L10n.t("基本資訊")) {
                    TextField(L10n.t("筆記名稱"), text: $title)
                    Picker(L10n.t("畫布型態"), selection: $mode) {
                        Text(L10n.t("筆記本")).tag(CanvasMode.notebook)
                        Text(L10n.t("無邊界筆記")).tag(CanvasMode.infinite)
                        Text(L10n.t("有邊界黑板")).tag(CanvasMode.fixed)
                    }
                }

                if mode != .infinite {
                    Section(L10n.t("頁面規格")) {
                        Picker(L10n.t("尺寸標準"), selection: $preset) {
                            Text("A4 (595 × 842)").tag(CanvasPreset.a4_portrait)
                            Text("A3 (842 × 1191)").tag(CanvasPreset.a3_landscape)
                            Text(L10n.t("B5 常用 (499 × 709)")).tag(CanvasPreset.b5)
                            Text(L10n.t("16:9 簡報 (1920 × 1080)")).tag(CanvasPreset.sixteen_nine)
                            Text(L10n.t("4:3 課堂 (1440 × 1080)")).tag(CanvasPreset.four_three)
                            Text(L10n.t("1:1 正方形 (1080 × 1080)")).tag(CanvasPreset.one_one)
                            Text(L10n.t("9:16 直式 (1080 × 1920)")).tag(CanvasPreset.nine_sixteen)
                        }

                        Picker(L10n.t("版面方向"), selection: $orientation) {
                            Text(L10n.t("直向 (Portrait)")).tag("portrait")
                            Text(L10n.t("橫向 (Landscape)")).tag("landscape")
                        }
                    }
                }

                if mode == .notebook {
                    Section(L10n.t("筆記本封面")) {
                        Picker(L10n.t("封面風格"), selection: $coverStyle) {
                            ForEach(covers, id: \.0) { item in
                                Text(L10n.t(item.1)).tag(item.0)
                            }
                        }
                    }
                }

                Section(L10n.t("內頁版型與背景")) {
                    Picker(L10n.t("內文風格"), selection: $gridStyle) {
                        Text(L10n.t("• 點點 (Dots)")).tag(GridStyle.dots)
                        Text(L10n.t("⊞ 格子 (Grid)")).tag(GridStyle.grid)
                        Text(L10n.t("☰ 橫線 (Lines)")).tag(GridStyle.lines)
                        Text(L10n.t("𝄞 五線譜 (Staff)")).tag(GridStyle.staff)
                        Text(L10n.t("◻ 全白 (Blank)")).tag(GridStyle.blank)
                    }

                    Picker(L10n.t("背景底色"), selection: $bgColor) {
                        ForEach(bgColors, id: \.0) { item in
                            Text(L10n.t(item.1)).tag(item.0)
                        }
                    }

                    Picker(L10n.t("線條 / 點點顏色"), selection: $gridColor) {
                        ForEach(gridColors, id: \.0) { item in
                            Text(L10n.t(item.1)).tag(item.0)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(L10n.t("取消")) { isPresented = false }
                Button(L10n.t("建立")) {
                    createCustom()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(sage)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 530)
    }

    private func createCustom() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty ? (mode == .notebook ? "新筆記本" : "新黑板") : trimmed
        let resolvedTheme: BoardTheme = (bgColor == "#18181b") ? .dark : ((bgColor == "#ffffff" || bgColor == "#FAF8F5" || bgColor == "#F5EADB") ? .whiteboard : .blackboard)
        let resolvedGridColor = gridColor.isEmpty ? nil : gridColor

        engine.createBoard(
            title: finalTitle,
            theme: resolvedTheme,
            mode: mode,
            preset: (mode == .infinite) ? nil : preset,
            orientation: orientation,
            coverStyle: (mode == .notebook) ? coverStyle : nil,
            gridStyle: gridStyle,
            backgroundColor: bgColor,
            gridColor: resolvedGridColor
        )
    }
}

private struct BoardThumbnailView: View {
    @ObservedObject private var language = L10n.shared
    let board: BoardMetadata
    @ViewState<[BoardObject]> private var objects: [BoardObject] = []

    private var emptyInk: Color {
        let rgb = NSColor(Color(hex: board.backgroundColor)).usingColorSpace(.deviceRGB) ?? .black
        let luminance = rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114
        return (luminance > 0.5 ? Color.black : Color.white).opacity(0.5)
    }

    var body: some View {
        Canvas { context, size in
            let firstPageId = board.pages?.first?.id
            let visible = objects.filter {
                $0.isVisible != false &&
                (board.canvasMode != .notebook || $0.pageId == nil || $0.pageId == firstPageId )
            }
            guard !visible.isEmpty else {
                context.draw(Text(board.iconCanvasMode == .notebook ? "空白筆記本" : "空白黑板").font(.system(size: 13, weight: .medium)).foregroundColor(emptyInk), at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }
            let minX = visible.map(\.x).min() ?? 0
            let minY = visible.map(\.y).min() ?? 0
            let maxX = visible.map { $0.x + max(1, $0.width) }.max() ?? minX + 1
            let maxY = visible.map { $0.y + max(1, $0.height) }.max() ?? minY + 1
            let scale = min((size.width - 20) / max(1, maxX - minX), (size.height - 20) / max(1, maxY - minY))
            func frame(_ object: BoardObject) -> CGRect {
                CGRect(x: 10 + (object.x - minX) * scale, y: 10 + (object.y - minY) * scale,
                       width: max(2, object.width * scale), height: max(2, object.height * scale))
            }
            for object in visible.sorted(by: { $0.zIndex < $1.zIndex }) {
                let bounds = frame(object)
                let stroke = Color(hex: object.strokeColor).opacity(object.opacity)
                let fill = Color(hex: object.fillColor).opacity(object.opacity * object.fillOpacity)
                var itemContext = context
                if object.rotation != 0 {
                    itemContext.translateBy(x: bounds.midX, y: bounds.midY)
                    itemContext.rotate(by: Angle.degrees(object.rotation))
                    itemContext.translateBy(x: -bounds.midX, y: -bounds.midY)
                }
                switch object.type {
                case "rect", "sticky":
                    if object.fillColor != "none" { itemContext.fill(Path(roundedRect: bounds, cornerRadius: 3), with: .color(fill)) }
                    itemContext.stroke(Path(roundedRect: bounds, cornerRadius: 3), with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                    if object.type == "sticky", let text = object.text, !text.isEmpty {
                        itemContext.draw(Text(text).font(.system(size: max(5, (object.fontSize ?? 14) * scale))).foregroundColor(stroke), at: CGPoint(x: bounds.midX, y: bounds.midY))
                    }
                case "circle":
                    if object.fillColor != "none" { itemContext.fill(Path(ellipseIn: bounds), with: .color(fill)) }
                    itemContext.stroke(Path(ellipseIn: bounds), with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                case "arc":
                    let radius = (object.arcRadius ?? (object.width / 2.0)) * scale
                    let center = CGPoint(x: bounds.midX, y: bounds.midY)
                    let startDeg = object.arcStartAngle ?? 0.0
                    let sweepDeg = object.arcSweepAngle ?? 360.0
                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: Angle(degrees: startDeg),
                        endAngle: Angle(degrees: startDeg + sweepDeg),
                        clockwise: sweepDeg < 0
                    )
                    itemContext.stroke(path, with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                case "triangle", "quadrilateral", "diamond", "star":
                    let pts = object.parsedPoints
                    if pts.count >= 3 {
                        var path = Path()
                        path.move(to: CGPoint(x: 10 + (pts[0].x - minX) * scale, y: 10 + (pts[0].y - minY) * scale))
                        for pt in pts.dropFirst() {
                            path.addLine(to: CGPoint(x: 10 + (pt.x - minX) * scale, y: 10 + (pt.y - minY) * scale))
                        }
                        path.closeSubpath()
                        if object.fillColor != "none" { itemContext.fill(path, with: .color(fill)) }
                        itemContext.stroke(path, with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                    }
                case "line", "arrow", "connector":
                    let start = CGPoint(x: bounds.minX, y: bounds.minY)
                    let end = CGPoint(x: 10 + ((object.x2 ?? object.x + object.width) - minX) * scale, y: 10 + ((object.y2 ?? object.y + object.height) - minY) * scale)
                    var path = Path(); path.move(to: start); path.addLine(to: end)
                    itemContext.stroke(path, with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                case "rounded_rect":
                    let cornerR = (object.cornerRadius ?? 16.0) * scale
                    if object.fillColor != "none" { itemContext.fill(Path(roundedRect: bounds, cornerRadius: cornerR), with: .color(fill)) }
                    itemContext.stroke(Path(roundedRect: bounds, cornerRadius: cornerR), with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                case "tape":
                    itemContext.fill(Path(roundedRect: bounds, cornerRadius: 3), with: .color(Color(hex: "#f59e0b").opacity(0.85)))
                case "polygon":
                    let sides = object.polygonSides ?? 5
                    let center = Point(x: Double(bounds.midX), y: Double(bounds.midY))
                    let radius = Double(min(bounds.width, bounds.height) / 2.0)
                    let vertices = VectorMath.computePolygonVertices(center: center, radius: radius, sides: sides)
                    var path = Path()
                    for (idx, v) in vertices.enumerated() {
                        let pt = CGPoint(x: v.x, y: v.y)
                        if idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                    if object.fillColor != "none" { itemContext.fill(path, with: .color(fill)) }
                    itemContext.stroke(path, with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                case "stroke", "pen", "highlighter", "paint", "curve":
                    let points = object.parsedPoints
                    guard points.count > 1 else { continue }
                    var path = Path()
                    let start = CGPoint(x: 10 + (points[0].x - minX) * scale, y: 10 + (points[0].y - minY) * scale)
                    path.move(to: start)
                    if object.type == "curve", points.count >= 3 {
                        let control = CGPoint(x: 10 + (points[1].x - minX) * scale, y: 10 + (points[1].y - minY) * scale)
                        let end = CGPoint(x: 10 + (points[2].x - minX) * scale, y: 10 + (points[2].y - minY) * scale)
                        path.addQuadCurve(to: end, control: control)
                    } else {
                        for point in points.dropFirst() { path.addLine(to: CGPoint(x: 10 + (point.x - minX) * scale, y: 10 + (point.y - minY) * scale)) }
                    }
                    itemContext.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: max(0.8, object.strokeWidth * scale), lineCap: .round, lineJoin: .round))
                case "text":
                    if let text = object.text, !text.isEmpty {
                        itemContext.draw(Text(text).font(.system(size: max(5, (object.fontSize ?? 14) * scale))).foregroundColor(stroke), at: CGPoint(x: bounds.midX, y: bounds.midY))
                    }
                case "image":
                    if let dataURL = object.imageUrl ?? object.originalImageUrl,
                       let image = CanvasImageCache.image(for: dataURL) {
                        itemContext.draw(Image(nsImage: image), in: bounds)
                    } else if let raw = object.imageUrl?.components(separatedBy: ",").last,
                              let data = Data(base64Encoded: raw), let image = NSImage(data: data) {
                        itemContext.draw(Image(nsImage: image), in: bounds)
                    }
                default: break
                }
            }
        }
        .onAppear {
            guard objects.isEmpty else { return }
            DispatchQueue.global(qos: .utility).async {
                let library = LocalBoardLibrary()
                if let thumbData = library.thumbnailData(id: board.id),
                   let thumbDoc = try? JSONDecoder().decode(HeiBanDocument.self, from: thumbData) {
                    DispatchQueue.main.async { objects = thumbDoc.objects }
                } else {
                    let loaded = (try? library.load(id: board.id).objects) ?? (try? HeiBanDocumentCodec.decode(from: Data(contentsOf: library.trashFileURL(id: board.id))).objects) ?? []
                    DispatchQueue.main.async { objects = loaded }
                }
            }
        }
    }
}
