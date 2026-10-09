import SwiftUI
import AppKit
import HeiBanCore

public struct TopNavView: View {
    @ObservedObject var engine: BoardEngine
    @ViewState private var showLaserSettings = false
    @ViewState private var showBackgroundSettings = false
    @ViewState private var showNoteInfoPopover = false
    @ViewState private var showToolbarCustomizer = false

    private var saveLabel: String {
        if engine.autosaveStatus.contains("失敗") || engine.autosaveStatus.contains("無法") { return "儲存失敗" }
        if engine.autosaveStatus == "儲存中…" { return "儲存中" }
        if engine.autosaveStatus == "尚未儲存" { return "尚未儲存" }
        return "本機已存"
    }

    private var worldCenterPoint: Point {
        let centerScreen = Point(x: Double(engine.canvasSize.width / 2.0), y: Double(engine.canvasSize.height / 2.0))
        return VectorMath.screenToWorld(centerScreen, viewport: engine.viewport)
    }

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    public var body: some View {
        HStack(spacing: 12) {
            // 1. Back to Library
            Button {
                engine.returnHome()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .help("回到作品庫")

            Divider().frame(height: 16)

            // 2. Reading / Drawing Mode Switch
            Button {
                engine.setReadingMode(!engine.readingMode)
            } label: {
                Image(systemName: engine.readingMode ? "pencil" : "hand.draw")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .help(engine.readingMode ? "回到編輯模式" : "閱讀模式：拖曳移動畫布，不會畫線")

            // 3. Oblique Pin Navigation
            Button {
                engine.showPinPopover.toggle()
            } label: {
                HeiBanPinIcon()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.accentColor)
            }
            .help("圖釘視角導航")
            .popover(isPresented: $engine.showPinPopover) {
                PinManagerPopover(engine: engine, isPresented: $engine.showPinPopover)
            }

            // 4. "+" Insert Menu (Categorized)
            insertMenu

            // 5. "⋯" More Menu
            moreMenu

            Divider().frame(height: 16)

            // 6. Compact Status Light Indicator
            statusIndicatorView
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.09), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        .fixedSize(horizontal: true, vertical: true)
        .popover(isPresented: $showBackgroundSettings) {
            backgroundSettingsPopover
        }
        .popover(isPresented: $showNoteInfoPopover) {
            noteInfoPopover
        }
        .popover(isPresented: $showLaserSettings) {
            LaserSettingsView(laser: engine.laserEngine)
        }
        .sheet(isPresented: $showToolbarCustomizer) {
            ToolbarCustomizeSheet(engine: engine, isPresented: $showToolbarCustomizer)
        }
    }

    // MARK: - Insert Menu
    @ViewBuilder
    private var insertMenu: some View {
        Menu {
            Section("內容") {
                Button {
                    engine.beginInlineTextEntry(at: worldCenterPoint, kind: .text)
                } label: {
                    Label("文字", systemImage: "textformat")
                }

                Button {
                    engine.beginInlineTextEntry(at: worldCenterPoint, kind: .sticky)
                } label: {
                    Label("便條紙", systemImage: "note.text")
                }

                Button {
                    engine.captureScreenAndPaste()
                } label: {
                    Label("截圖置入…", systemImage: "camera.viewfinder")
                }

                Button {
                    engine.importImageFromFilePrompt()
                } label: {
                    Label("圖片匯入…", systemImage: "photo.badge.plus")
                }
            }

            Section("輔助工具") {
                Button { ScreenAnnotationController.shared.start() } label: {
                    Label("我的螢幕就是我的畫布", systemImage: "rectangle.and.pencil.and.ellipsis")
                }
                Button("雷射筆設定…") { showLaserSettings = true }

                Button {
                    engine.toggleCompass()
                } label: {
                    Label("圓規", systemImage: "circle.circle")
                }

                Button {
                    engine.toggleCalculator()
                } label: {
                    Label("計算機", systemImage: "plus.forwardslash.minus")
                }

                Button {
                    engine.toggleTimer()
                } label: {
                    Label("計時器", systemImage: "timer")
                }
            }
        } label: {
            MenuDisclosureLabel("插入內容或輔助工具") {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18, height: 24)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: true)
        .help("插入內容或輔助工具")
    }

    // MARK: - More Menu
    @ViewBuilder
    private var moreMenu: some View {
        Menu {
            Section("筆記") {
                Button {
                    showNoteInfoPopover = true
                } label: {
                    Label("筆記資訊與改名…", systemImage: "info.circle")
                }

                Button {
                    engine.toggleImmersiveMode()
                } label: {
                    Label(engine.isImmersiveMode ? "退出沉浸模式" : "進入沉浸模式", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }

            Section("畫布背景與格線") {
                ForEach(BoardTheme.allCases, id: \.self) { theme in
                    Button(theme.displayName) { engine.updateBoardTheme(theme) }
                }
                Button("自訂背景與格線…") { showBackgroundSettings = true }
            }

            Section("圖層與屬性") {
                Button {
                    engine.showLayerPanel.toggle()
                } label: {
                    Label("物件圖層", systemImage: "square.3.layers.3d")
                }

                Button {
                    engine.showInspector.toggle()
                } label: {
                    Label("物件屬性", systemImage: "slider.horizontal.3")
                }
            }

            Section("文件與匯出") {
                Button("匯入／開啟…") { engine.openFromFilePrompt() }
                Button("另存黑板專案…") { engine.saveToFilePrompt() }
                Button("PNG 圖片…") { engine.exportPNGPrompt() }
                Button("PDF 向量文件…") { engine.exportPDFPrompt() }
                Button("SVG 向量圖檔…") { engine.exportSVGPrompt() }
                Button("離線 HTML…") { engine.exportHTMLPrompt() }
            }

            Section("使用說明") {
                Button("黑板使用手冊") { HeiBanUserGuide.shared.show() }
            }

            Section("偏好設定") {
                Button {
                    showToolbarCustomizer = true
                } label: {
                    Label("自訂工具列…", systemImage: "wrench.and.screwdriver")
                }
            }
        } label: {
            MenuDisclosureLabel("更多") {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18, height: 24)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: true)
        .help("筆記資訊、背景、圖層、匯出與偏好")
    }

    // MARK: - Status Indicator
    private var statusIndicatorView: some View {
        Group {
            if saveLabel == "儲存失敗" {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                    Text("儲存失敗")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .help(engine.autosaveStatus)
            } else if saveLabel == "儲存中" {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 14, height: 14)
                    .help("儲存中…")
            } else {
                Circle()
                    .fill(Color.green.opacity(0.85))
                    .frame(width: 8, height: 8)
                    .help("本機已儲存：所有變更已安全寫入")
            }
        }
    }

    // MARK: - Note Info Popover
    private var noteInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("筆記資訊與改名")
                    .font(.system(size: 13, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("筆記名稱").font(.caption).foregroundStyle(.secondary)
                TextField("筆記標題", text: $engine.board.title)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: "畫布格式", value: engine.board.canvasPreset?.displayName ?? "自訂")
                infoRow(label: "建立時間", value: String(engine.board.createdAt.prefix(19)))
                infoRow(label: "最後修改", value: String(engine.board.updatedAt.prefix(19)))
                infoRow(label: "物件數量", value: "\(engine.objects.count) 個物件")
                infoRow(label: "儲存狀態", value: engine.autosaveStatus)
            }
            .font(.system(size: 11))

            HStack {
                Spacer()
                Button("完成") {
                    showNoteInfoPopover = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.primary).lineLimit(1)
        }
    }

    // MARK: - Background Settings Popover
    private var backgroundSettingsPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("畫布背景與格線").font(.headline)

            ColorPicker("背景顏色", selection: Binding(
                get: { Color(hex: engine.board.backgroundColor) },
                set: { color in
                    guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                    let hex = String(
                        format: "#%02X%02X%02X",
                        Int(round(rgb.redComponent * 255)),
                        Int(round(rgb.greenComponent * 255)),
                        Int(round(rgb.blueComponent * 255))
                    )
                    engine.updateBoardBackgroundColor(hex)
                }
            ), supportsOpacity: false)

            Picker("格線顏色", selection: Binding(
                get: { engine.board.gridColor ?? "" },
                set: { engine.updateGridColor($0.isEmpty ? nil : $0) }
            )) {
                Text("自適應").tag("")
                Text("白色").tag("#ffffff")
                Text("淺灰").tag("#94a3b8")
                Text("深灰").tag("#475569")
                Text("柔黑").tag("#18181b")
            }

            HStack {
                Spacer()
                Button("完成") { showBackgroundSettings = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

// MARK: - Pin Manager Popover
struct PinManagerPopover: View {
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool
    @ViewState private var pinSearchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                HeiBanPinIcon().frame(width: 20, height: 20).foregroundStyle(Color.accentColor)
                Text("圖釘視角導航").font(.system(size: 13, weight: .bold))
            }

            // Add pin input
            HStack {
                TextField("新圖釘名稱 (如：板書起點)", text: $engine.newPinName)
                    .textFieldStyle(.roundedBorder)

                Button("新增") {
                    let name = engine.newPinName.trimmingCharacters(in: .whitespacesAndNewlines)
                    engine.addPin(name: name.isEmpty ? "視角 \(Int.random(in: 10...99))" : name)
                    engine.newPinName = ""
                }
            }

            // Search pins input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("搜尋圖釘…", text: $pinSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !pinSearchQuery.isEmpty {
                    Button {
                        pinSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

            Divider()

            let allPins = engine.board.pins ?? []
            let pins = PinSearchFilter.filter(pins: allPins, query: pinSearchQuery)
            if pins.isEmpty {
                Text(allPins.isEmpty ? "尚無圖釘，點選新增將當前視角存為書籤！" : "找不到符合的圖釘")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(pins) { pin in
                            HStack {
                                Button {
                                    engine.jumpToPin(pin)
                                    if !engine.viewportLocked { isPresented = false }
                                } label: {
                                    HeiBanPinIcon().frame(width: 20, height: 20)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(engine.viewportLocked)
                                .accessibilityLabel("前往圖釘：\(pin.name)")
                                .help("前往圖釘：\(pin.name)")

                                TextField("圖釘名稱", text: Binding(
                                    get: { engine.board.pins?.first(where: { $0.id == pin.id })?.name ?? pin.name },
                                    set: { engine.renamePin(id: pin.id, name: $0) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .medium))

                                Text("\(Int(pin.zoom * 100))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Button {
                                    engine.removePin(id: pin.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            if engine.viewportLocked {
                Text("視角已鎖定，解除鎖定後即可跳轉")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}
