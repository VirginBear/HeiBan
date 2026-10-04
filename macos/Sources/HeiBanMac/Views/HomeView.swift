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
    private let sage = Color(red: 0.24, green: 0.43, blue: 0.35)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Label("黑板", systemImage: "square.and.pencil").font(.system(size: 27, weight: .semibold))
                Spacer()
                Button { settings = true } label: { Label("帳號與設定", systemImage: "person.crop.circle") }
                Button { engine.openFromFilePrompt() } label: { Label("匯入黑板", systemImage: "folder") }
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
                }.frame(width: 150)
                Picker("底色", selection: $theme) {
                    ForEach(BoardTheme.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.frame(width: 140)
                Button("建立黑板") { create() }.buttonStyle(.borderedProminent).tint(sage)
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
                    ContentUnavailableView("第一張黑板，從這裡開始", systemImage: "square.and.pencil", description: Text("輸入名稱後建立，或匯入現有的黑板檔案。"))
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
        }
        title = ""
    }
}

private enum HomeCanvasChoice: String, CaseIterable, Identifiable {
    case infinite = "♾️ 無邊界黑板"
    case notebook = "📓 多頁筆記本"
    case sixteenNine = "📄 16:9 簡報"
    case fourThree = "📄 4:3 課堂"
    case oneOne = "📄 1:1 正方形"
    case nineSixteen = "📄 9:16 直式"
    case a4Portrait = "📄 A4 直式"
    case a4Landscape = "📄 A4 橫式"

    var id: String { rawValue }
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
