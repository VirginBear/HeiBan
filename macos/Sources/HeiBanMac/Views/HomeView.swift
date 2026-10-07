import SwiftUI
import HeiBanCore

// Explicit alias selects the property wrapper on SDKs that also expose a State macro.
typealias ViewState<Value> = SwiftUI.State<Value>

struct HomeView: View {
    @ObservedObject var engine: BoardEngine
    @ViewState<String> private var title = ""
    @ViewState<BoardTheme> private var theme: BoardTheme = .blackboard
    @ViewState<String> private var search = ""
    @ViewState<Bool> private var settings = false
    @ViewState<BoardMetadata?> private var renaming: BoardMetadata?
    @ViewState<String> private var renameTitle = ""
    @ViewState<Set<String>> private var selectedBoardIDs = []
    @ViewState<Bool> private var confirmDeleteBoards = false
    @ViewState<HomeCanvasChoice> private var canvasChoice = .infinite
    @ViewState<Bool> private var showAdvancedSheet = false
    private let sage = Color(red: 0.24, green: 0.43, blue: 0.35)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Label("黑板", systemImage: "square.and.pencil").font(.system(size: 27, weight: .semibold))
                Spacer()
                Button { settings = true } label: { Label("帳號與設定", systemImage: "person.crop.circle") }
                Button { engine.openFromFilePrompt() } label: { Label("匯入黑板", systemImage: "folder") }
                Button { engine.loadShowcaseBoard() } label: { Label("示範黑板", systemImage: "sparkles") }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("留一片空間，給你的想法。") .font(.system(size: 32, weight: .medium))
                Text("在 Mac 上寫、畫、整理。黑板自動保存在這台電腦。") .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Image(systemName: "plus.square.fill").font(.title).foregroundStyle(sage)
                TextField("替新黑板取個名字", text: $title).textFieldStyle(.plain)
                    .onSubmit { create() }
                Picker("格式", selection: $canvasChoice) {
                    ForEach(HomeCanvasChoice.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 175)
                Picker("底色", selection: $theme) {
                    ForEach(BoardTheme.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.frame(width: 130)
                Button("建立") { create() }.buttonStyle(.borderedProminent).tint(sage)
                Button {
                    showAdvancedSheet = true
                } label: {
                    Label("自訂筆記…", systemImage: "slider.horizontal.3")
                }
            }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 18))
            HStack {
                Text("我的黑板").font(.title2.weight(.semibold))
                Text("\(engine.libraryBoards.count)").foregroundStyle(.secondary)
                Spacer()
                TextField("搜尋黑板", text: $search).textFieldStyle(.roundedBorder).frame(width: 240)
            }
            if !selectedBoardIDs.isEmpty {
                HStack(spacing: 12) {
                    Text("已選取 \(selectedBoardIDs.count) 張").font(.subheadline.weight(.medium))
                    Button("全選") {
                        selectedBoardIDs = Set(engine.libraryBoards.map(\.id))
                    }
                    Button("刪除") { confirmDeleteBoards = true }
                        .buttonStyle(.borderedProminent).tint(.red)
                    Button("取消選取") { selectedBoardIDs.removeAll() }
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 20)], spacing: 20) {
                    ForEach(engine.libraryBoards.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }) { board in
                        VStack(alignment: .leading, spacing: 12) {
                            Button { engine.openLibraryBoard(board.id) } label: {
                                BoardThumbnailView(board: board).frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityLabel("開啟 \(board.title)")
                            HStack {
                                Text(board.title).font(.headline).lineLimit(1)
                                Spacer()
                                Button {
                                    if selectedBoardIDs.contains(board.id) { selectedBoardIDs.remove(board.id) }
                                    else { selectedBoardIDs.insert(board.id) }
                                } label: {
                                    Image(systemName: selectedBoardIDs.contains(board.id) ? "checkmark.circle.fill" : "circle.dashed")
                                        .foregroundStyle(selectedBoardIDs.contains(board.id) ? sage : .secondary)
                                }
                                .buttonStyle(.plain)
                                .help("選取黑板以批次刪除")
                                Menu {
                                    Button("重新命名") { renameTitle = board.title; renaming = board }
                                    Button("製作副本") { engine.duplicateLibraryBoard(board.id) }
                                    Button(selectedBoardIDs.contains(board.id) ? "取消選取" : "選取") {
                                        if selectedBoardIDs.contains(board.id) { selectedBoardIDs.remove(board.id) }
                                        else { selectedBoardIDs.insert(board.id) }
                                    }
                                    Divider()
                                    Button("刪除黑板…", role: .destructive) {
                                        selectedBoardIDs = [board.id]
                                        confirmDeleteBoards = true
                                    }
                                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22)
                            }.contentShape(Rectangle())
                            Text("\(board.itemCount ?? 0) 個物件 · 本機儲存").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedBoardIDs.contains(board.id) ? sage : .clear, lineWidth: 2))
                    }
                }
                if engine.libraryBoards.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView("第一張黑板，從這裡開始", systemImage: "square.and.pencil", description: Text("輸入名稱後建立，或匯入現有的黑板檔案。"))
                        Button {
                            engine.loadShowcaseBoard()
                        } label: {
                            Label("載入全功能示範黑板", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(sage)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
            if let status = engine.statusMessage { Text(status).foregroundStyle(sage) }
        }.padding(40).background(Color(red: 0.95, green: 0.96, blue: 0.94))
            .sheet(isPresented: $settings) { NativeSettingsView() }
            .sheet(item: $renaming) { board in
                VStack(alignment: .leading, spacing: 16) {
                    Text("重新命名黑板").font(.headline)
                    TextField("名稱", text: $renameTitle).textFieldStyle(.roundedBorder)
                    HStack { Spacer(); Button("取消") { renaming = nil }; Button("儲存") { engine.renameLibraryBoard(board.id, title: renameTitle); renaming = nil }.keyboardShortcut(.defaultAction) }
                }.padding(24).frame(width: 360)
            }
            .sheet(isPresented: $showAdvancedSheet) {
                AdvancedBoardSheet(engine: engine, isPresented: $showAdvancedSheet)
            }
            .alert("刪除所選黑板？", isPresented: $confirmDeleteBoards) {
                Button("取消", role: .cancel) { }
                Button("刪除", role: .destructive) {
                    engine.deleteLibraryBoards(selectedBoardIDs)
                    selectedBoardIDs.removeAll()
                }
            } message: {
                Text("將刪除 \(selectedBoardIDs.count) 張黑板及其本機備份，此操作無法復原。")
            }
    }

    private func create() {
        switch canvasChoice {
        case .infinite:
            engine.createBoard(title: title, theme: theme, mode: .infinite)
        case .notebook:
            engine.createBoard(title: title, theme: theme, mode: .notebook, preset: .notebook)
        case .notebookStaff:
            engine.createBoard(title: title, theme: theme, mode: .notebook, preset: .notebook, gridStyle: .staff)
        case .sixteenNine:
            engine.createBoard(title: title, theme: theme, mode: .fixed, preset: .sixteen_nine)
        case .fourThree:
            engine.createBoard(title: title, theme: theme, mode: .fixed, preset: .four_three)
        case .oneOne:
            engine.createBoard(title: title, theme: theme, mode: .fixed, preset: .one_one)
        case .nineSixteen:
            engine.createBoard(title: title, theme: theme, mode: .fixed, preset: .nine_sixteen)
        case .a4Portrait:
            engine.createBoard(title: title, theme: theme, mode: .fixed, preset: .a4_portrait)
        case .a4Landscape:
            engine.createBoard(title: title, theme: theme, mode: .fixed, preset: .a4_landscape)
        case .b5:
            engine.createBoard(title: title, theme: theme, mode: .fixed, preset: .b5)
        }
        title = ""
    }
}

private enum HomeCanvasChoice: String, CaseIterable, Identifiable {
    case infinite = "♾️ 無邊界黑板"
    case notebook = "📓 多頁筆記本 (A4)"
    case notebookStaff = "🎼 五線譜筆記本 (A4)"
    case b5 = "📄 B5 常用規格"
    case sixteenNine = "📄 16:9 簡報"
    case fourThree = "📄 4:3 課堂"
    case oneOne = "📄 1:1 正方形"
    case nineSixteen = "📄 9:16 直式"
    case a4Portrait = "📄 A4 直式"
    case a4Landscape = "📄 A4 橫式"

    var id: String { rawValue }
}

struct AdvancedBoardSheet: View {
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
                Text("自訂筆記本與畫布規格")
                    .font(.headline)
                Spacer()
                Button("關閉") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                Section("基本資訊") {
                    TextField("筆記名稱", text: $title)
                    Picker("畫布型態", selection: $mode) {
                        Text("📓 多頁筆記本").tag(CanvasMode.notebook)
                        Text("♾️ 無邊界黑板").tag(CanvasMode.infinite)
                        Text("📄 單頁固定畫布").tag(CanvasMode.fixed)
                    }
                }

                if mode != .infinite {
                    Section("頁面規格") {
                        Picker("尺寸標準", selection: $preset) {
                            Text("A4 (595 × 842)").tag(CanvasPreset.a4_portrait)
                            Text("A3 (842 × 1191)").tag(CanvasPreset.a3_landscape)
                            Text("B5 常用 (499 × 709)").tag(CanvasPreset.b5)
                            Text("16:9 簡報 (1920 × 1080)").tag(CanvasPreset.sixteen_nine)
                            Text("4:3 課堂 (1440 × 1080)").tag(CanvasPreset.four_three)
                            Text("1:1 正方形 (1080 × 1080)").tag(CanvasPreset.one_one)
                            Text("9:16 直式 (1080 × 1920)").tag(CanvasPreset.nine_sixteen)
                        }

                        Picker("版面方向", selection: $orientation) {
                            Text("直向 (Portrait)").tag("portrait")
                            Text("橫向 (Landscape)").tag("landscape")
                        }
                    }
                }

                if mode == .notebook {
                    Section("筆記本封面") {
                        Picker("封面風格", selection: $coverStyle) {
                            ForEach(covers, id: \.0) { item in
                                Text(item.1).tag(item.0)
                            }
                        }
                    }
                }

                Section("內頁版型與背景") {
                    Picker("內文風格", selection: $gridStyle) {
                        Text("• 點點 (Dots)").tag(GridStyle.dots)
                        Text("⊞ 格子 (Grid)").tag(GridStyle.grid)
                        Text("☰ 橫線 (Lines)").tag(GridStyle.lines)
                        Text("𝄞 五線譜 (Staff)").tag(GridStyle.staff)
                        Text("◻ 全白 (Blank)").tag(GridStyle.blank)
                    }

                    Picker("背景底色", selection: $bgColor) {
                        ForEach(bgColors, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }

                    Picker("線條 / 點點顏色", selection: $gridColor) {
                        ForEach(gridColors, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                Button("建立") {
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
    let board: BoardMetadata
    @ViewState<[BoardObject]> private var objects: [BoardObject] = []

    var body: some View {
        Canvas { context, size in
            let firstPageId = board.pages?.first?.id
            let visible = objects.filter {
                $0.isVisible != false &&
                (board.canvasMode != .notebook || $0.pageId == nil || $0.pageId == firstPageId || $0.pageId == board.activePageId)
            }
            guard !visible.isEmpty else {
                context.draw(Text("空白黑板").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.45)), at: CGPoint(x: size.width / 2, y: size.height / 2))
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
                switch object.type {
                case "rect", "sticky":
                    if object.fillColor != "none" { context.fill(Path(roundedRect: bounds, cornerRadius: 3), with: .color(fill)) }
                    context.stroke(Path(roundedRect: bounds, cornerRadius: 3), with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                    if object.type == "sticky", let text = object.text, !text.isEmpty {
                        context.draw(Text(text).font(.system(size: max(5, (object.fontSize ?? 14) * scale))).foregroundColor(stroke), at: CGPoint(x: bounds.midX, y: bounds.midY))
                    }
                case "circle":
                    if object.fillColor != "none" { context.fill(Path(ellipseIn: bounds), with: .color(fill)) }
                    context.stroke(Path(ellipseIn: bounds), with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
                case "line", "arrow":
                    let start = CGPoint(x: bounds.minX, y: bounds.minY)
                    let end = CGPoint(x: 10 + ((object.x2 ?? object.x + object.width) - minX) * scale, y: 10 + ((object.y2 ?? object.y + object.height) - minY) * scale)
                    var path = Path(); path.move(to: start); path.addLine(to: end)
                    context.stroke(path, with: .color(stroke), lineWidth: max(0.7, object.strokeWidth * scale))
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
                    context.stroke(path, with: .color(stroke), style: StrokeStyle(lineWidth: max(0.8, object.strokeWidth * scale), lineCap: .round, lineJoin: .round))
                case "text":
                    if let text = object.text, !text.isEmpty {
                        context.draw(Text(text).font(.system(size: max(5, (object.fontSize ?? 14) * scale))).foregroundColor(stroke), at: CGPoint(x: bounds.midX, y: bounds.midY))
                    }
                case "image":
                    if let raw = object.imageUrl?.components(separatedBy: ",").last,
                       let data = Data(base64Encoded: raw), let image = NSImage(data: data) {
                        context.draw(Image(nsImage: image), in: bounds)
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
                    let loaded = (try? library.load(id: board.id).objects) ?? []
                    DispatchQueue.main.async { objects = loaded }
                }
            }
        }
    }
}
