import SwiftUI
import AppKit
import HeiBanCore

public struct TopNavView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @ViewState private var showLaserSettings = false
    @ViewState private var showBackgroundSettings = false
    @ViewState private var showNoteInfoPopover = false
    @ViewState private var showToolbarCustomizer = false
    @Binding private var headerPinned: Bool
    private var onPanelChanged: (Bool) -> Void
    private var panelOpen: Bool {
        showLaserSettings || showBackgroundSettings || showNoteInfoPopover || showToolbarCustomizer
    }

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

    public init(engine: BoardEngine, headerPinned: Binding<Bool> = .constant(false), onPanelChanged: @escaping (Bool) -> Void = { _ in }) {
        self.engine = engine
        self._headerPinned = headerPinned
        self.onPanelChanged = onPanelChanged
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
            .help(L10n.t("回到作品庫"))

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
                engine.togglePinManager()
            } label: {
                HeiBanPinIcon()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.accentColor)
            }
            .help(L10n.t("圖釘視角導航"))
            .popover(isPresented: $engine.showPinManager) {
                PinManagerPopover(engine: engine, isPresented: $engine.showPinManager)
            }

            // 4. "+" Insert Menu (Categorized)
            insertMenu

            // 5. "⋯" More Menu
            moreMenu

            Divider().frame(height: 16)

            // 6. Compact Status Light Indicator
            statusIndicatorView
            Button { headerPinned.toggle() } label: {
                Image(systemName: headerPinned ? "eye.fill" : "eye")
                    .font(.system(size: 12))
                    .foregroundStyle(headerPinned ? Color.accentColor : .secondary)
                    .frame(width: 24, height: 24)
            }
            .help(headerPinned ? "取消固定：離開後自動隱藏導覽列" : "固定導覽列")
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
        .onChange(of: panelOpen) { _, open in onPanelChanged(open) }
        .onDisappear { onPanelChanged(false) }
    }

    // MARK: - Insert Menu
    @ViewBuilder
    private var insertMenu: some View {
        Menu {
            Section("內容") {
                Button {
                    engine.beginInlineTextEntry(at: worldCenterPoint, kind: .text)
                } label: {
                    Label(L10n.t("文字"), systemImage: "textformat")
                }

                Button {
                    engine.beginInlineTextEntry(at: worldCenterPoint, kind: .sticky)
                } label: {
                    Label(L10n.t("便條紙"), systemImage: "note.text")
                }

                Button {
                    engine.captureScreenAndPaste()
                } label: {
                    Label(L10n.t("截圖置入…"), systemImage: "camera.viewfinder")
                }

                Button {
                    engine.importImageFromFilePrompt()
                } label: {
                    Label(L10n.t("圖片匯入…"), systemImage: "photo.badge.plus")
                }
            }

            Section("輔助工具") {
                Button { ScreenAnnotationController.shared.start() } label: {
                    Label(L10n.t("我的螢幕就是我的畫布"), systemImage: "rectangle.and.pencil.and.ellipsis")
                }
                Button(L10n.t("雷射筆設定…")) { showLaserSettings = true }

                Button {
                    engine.toggleCompass()
                } label: {
                    Label(L10n.t("圓規"), systemImage: "circle.circle")
                }

                Button {
                    engine.toggleCalculator()
                } label: {
                    Label(L10n.t("計算機"), systemImage: "plus.forwardslash.minus")
                }

                Button {
                    engine.toggleTimer()
                } label: {
                    Label(L10n.t("計時器"), systemImage: "timer")
                }
            }
        } label: {
            MenuDisclosureLabel(L10n.t("插入內容或輔助工具")) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18, height: 24)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: true)
        .help(L10n.t("插入內容或輔助工具"))
    }

    // MARK: - More Menu
    @ViewBuilder
    private var moreMenu: some View {
        Menu {
            Section("筆記") {
                Button {
                    showNoteInfoPopover = true
                } label: {
                    Label(L10n.t("筆記資訊與改名…"), systemImage: "info.circle")
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
                Button(L10n.t("自訂背景與格線…")) { showBackgroundSettings = true }
            }

            Section("圖層與屬性") {
                Button {
                    engine.toggleLayerPanel()
                } label: {
                    Label(L10n.t("物件圖層"), systemImage: "square.3.layers.3d")
                }

                Button {
                    engine.showInspector.toggle()
                } label: {
                    Label(L10n.t("物件屬性"), systemImage: "slider.horizontal.3")
                }
            }

            Section("文件與匯出") {
                Button(L10n.t("匯入／開啟…")) { engine.openFromFilePrompt() }
                Button(L10n.t("另存黑板專案…")) { engine.saveToFilePrompt() }
                Button(L10n.t("PNG 圖片…")) { engine.exportPNGPrompt() }
                Button(L10n.t("PDF 向量文件…")) { engine.exportPDFPrompt() }
                Button(L10n.t("SVG 向量圖檔…")) { engine.exportSVGPrompt() }
                Button(L10n.t("離線 HTML…")) { engine.exportHTMLPrompt() }
            }

            Section("使用說明") {
                Button(L10n.t("黑板使用手冊")) { HeiBanUserGuide.shared.show() }
            }

            Section("偏好設定") {
                Button {
                    showToolbarCustomizer = true
                } label: {
                    Label(L10n.t("自訂工具列…"), systemImage: "wrench.and.screwdriver")
                }
            }
        } label: {
            MenuDisclosureLabel(L10n.t("更多")) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18, height: 24)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: true)
        .help(L10n.t("筆記資訊、背景、圖層、匯出與偏好"))
    }

    // MARK: - Status Indicator (MAC-TB-03)
    private var statusIndicatorView: some View {
        ZStack {
            switch engine.saveFeedbackState {
            case .failed(let detail):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#CF4860"))
                    .help("儲存失敗：\(detail)")
            case .saving:
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 14, height: 14)
                    .help(L10n.t("儲存中…"))
            case .unsaved:
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#A87929"))
                    .help(L10n.t("尚未儲存完成：存在尚未寫入本機磁碟的變更"))
            case .saved(let detail):
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#39735A"))
                    .help(detail)
            }
        }
        .frame(width: 22, height: 22, alignment: .center)
        .contentShape(Rectangle())
    }

    // MARK: - Note Info Popover
    private var noteInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text(L10n.t("筆記資訊與改名"))
                    .font(.system(size: 13, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("筆記名稱")).font(.caption).foregroundStyle(.secondary)
                TextField(L10n.t("筆記標題"), text: $engine.board.title)
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
                Button(L10n.t("完成")) {
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
            Text(L10n.t("畫布背景與格線")).font(.headline)

            ColorPicker(L10n.t("背景顏色"), selection: Binding(
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

            Picker(L10n.t("格線顏色"), selection: Binding(
                get: { engine.board.gridColor ?? "" },
                set: { engine.updateGridColor($0.isEmpty ? nil : $0) }
            )) {
                Text(L10n.t("自適應")).tag("")
                Text(L10n.t("白色")).tag("#ffffff")
                Text(L10n.t("淺灰")).tag("#94a3b8")
                Text(L10n.t("深灰")).tag("#475569")
                Text(L10n.t("柔黑")).tag("#18181b")
            }

            HStack {
                Spacer()
                Button(L10n.t("完成")) { showBackgroundSettings = false }
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
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool
    @ViewState private var pinSearchQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                HeiBanPinIcon().frame(width: 20, height: 20).foregroundStyle(Color.accentColor)
                Text(L10n.t("圖釘視角導航")).font(.system(size: 13, weight: .bold))
            }

            // Add pin input
            HStack {
                TextField(L10n.t("新圖釘名稱 (如：板書起點)"), text: $engine.newPinName)
                    .textFieldStyle(.roundedBorder)

                Button(L10n.t("新增")) {
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
                TextField(L10n.t("搜尋圖釘…"), text: $pinSearchQuery)
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
                                        .foregroundStyle(Color(hex: pin.effectiveColor))
                                }
                                .buttonStyle(.plain)
                                .disabled(engine.viewportLocked)
                                .accessibilityLabel("前往圖釘：\(pin.name)")
                                .help("前往圖釘：\(pin.name)")

                                TextField(L10n.t("圖釘名稱"), text: Binding(
                                    get: { engine.board.pins?.first(where: { $0.id == pin.id })?.name ?? pin.name },
                                    set: { engine.renamePin(id: pin.id, name: $0) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: pin.effectiveTextColor))

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
                            .contextMenu {
                                Menu(L10n.t("圖釘主體顏色")) {
                                    Button(L10n.t("藍綠色（預設）")) { engine.updatePinColor(id: pin.id, color: "#39B9DC", textColor: pin.textColor) }
                                    Button(L10n.t("珊瑚粉")) { engine.updatePinColor(id: pin.id, color: "#fb7185", textColor: pin.textColor) }
                                    Button(L10n.t("琥珀黃")) { engine.updatePinColor(id: pin.id, color: "#f59e0b", textColor: pin.textColor) }
                                    Button(L10n.t("翡翠綠")) { engine.updatePinColor(id: pin.id, color: "#10b981", textColor: pin.textColor) }
                                    Button(L10n.t("靛藍紫")) { engine.updatePinColor(id: pin.id, color: "#6366f1", textColor: pin.textColor) }
                                    Button(L10n.t("深石墨")) { engine.updatePinColor(id: pin.id, color: "#475569", textColor: pin.textColor) }
                                }
                                Menu(L10n.t("圖釘文字顏色")) {
                                    Button(L10n.t("森林深綠（預設）")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#397056") }
                                    Button(L10n.t("純白")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#ffffff") }
                                    Button(L10n.t("深灰黑")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#1e293b") }
                                    Button(L10n.t("珊瑚紅")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#e11d48") }
                                    Button(L10n.t("琥珀棕")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#b45309") }
                                    Button(L10n.t("靛青")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#1e40af") }
                                }
                                Divider()
                                Button(L10n.t("刪除圖釘"), role: .destructive) { engine.removePin(id: pin.id) }
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            if engine.viewportLocked {
                Text(L10n.t("視角已鎖定，解除鎖定後即可跳轉"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}
