import SwiftUI
import HeiBanCore

struct WorkspaceNavigationView: View {
    @ObservedObject var engine: BoardEngine
    var body: some View {
        HStack(spacing: 8) {
            Button { engine.setNavigationZoom(engine.viewport.zoom / 1.15) } label: { Image(systemName: "minus") }.disabled(engine.viewportLocked).help("縮小")
            Menu {
                Button("適合頁面／內容") { engine.fitNavigationView() }
                Button("回到原點與 100%") { engine.resetNavigationView() }
                Divider()
                ForEach([25, 50, 75, 100, 150, 200], id: \.self) { percent in Button("\(percent)%") { engine.setNavigationZoom(Double(percent) / 100) } }
            } label: {
                MenuDisclosureLabel("\(Int((engine.viewport.zoom * 100).rounded()))%") { Text("\(Int((engine.viewport.zoom * 100).rounded()))%").font(.system(size: 12, weight: .medium, design: .monospaced)) }
            }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().disabled(engine.viewportLocked).help("縮放、適合內容、回到原點")
            Button { engine.setNavigationZoom(engine.viewport.zoom * 1.15) } label: { Image(systemName: "plus") }.disabled(engine.viewportLocked).help("放大")
            Divider().frame(height: 18)
            Button { engine.setViewportLocked(!engine.viewportLocked) } label: { Image(systemName: engine.viewportLocked ? "lock.fill" : "lock.open") }
                .foregroundStyle(engine.viewportLocked ? Color.accentColor : .primary).help(engine.viewportLocked ? "解除視角鎖定" : "鎖定視角：避免平移與縮放")
            Button { engine.setReadingMode(!engine.readingMode) } label: { Image(systemName: engine.readingMode ? "pencil" : "hand.draw") }
                .help(engine.readingMode ? "回到編輯模式" : "閱讀模式：拖曳移動畫布，不會畫線")

            if engine.isNotebook {
                Divider().frame(height: 18)
                HStack(spacing: 6) {
                    Button { engine.goToPreviousPage() } label: { Image(systemName: "chevron.left") }
                        .disabled(engine.currentPageIndex <= 0).help("上一頁")
                    Menu {
                        ForEach(engine.pages) { page in Button(page.title) { engine.switchPage(to: page.id) } }
                        Divider()
                        Button("新增頁面") { engine.addPage() }
                        Button("刪除目前頁面", role: .destructive) { if let id = engine.activePageId { engine.deletePage(id: id) } }
                            .disabled(engine.totalPages <= 1)
                    } label: {
                        MenuDisclosureLabel("\(engine.currentPageIndex + 1) / \(engine.totalPages)") { Text("\(engine.currentPageIndex + 1) / \(engine.totalPages)").monospacedDigit().font(.system(size: 11, weight: .medium)) }
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("切換筆記本頁面")
                    Button { engine.goToNextPage() } label: { Image(systemName: "chevron.right") }
                        .disabled(engine.currentPageIndex >= engine.totalPages - 1).help("下一頁")
                    Button { engine.addPage() } label: { Image(systemName: "plus") }.help("新增頁面")
                }
                .font(.system(size: 12))
            }
        }
        .buttonStyle(.plain).padding(.horizontal, 14).padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule()).overlay(Capsule().stroke(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .fixedSize(horizontal: true, vertical: true)
    }
}

struct ReadingNavigationView: View {
    @ObservedObject var engine: BoardEngine
    @Binding var headerPinned: Bool
    var onPanelChanged: (Bool) -> Void
    @ViewState private var showPins = false
    @ViewState private var pinSearchQuery = ""
    var body: some View {
        HStack(spacing: 16) {
            Button { engine.returnHome() } label: { Image(systemName: "chevron.left") }.help("回到作品庫")
            Text(engine.board.title).font(.system(size: 12, weight: .medium)).lineLimit(1).frame(maxWidth: 180)
            if engine.isNotebook {
                Button { engine.goToPreviousPage() } label: { Image(systemName: "chevron.left") }
                    .disabled(engine.currentPageIndex <= 0).help("上一頁")
                Menu {
                    ForEach(engine.pages) { page in Button(page.title) { engine.switchPage(to: page.id) } }
                } label: { MenuDisclosureLabel("\(engine.currentPageIndex + 1) / \(engine.totalPages)") { Text("\(engine.currentPageIndex + 1) / \(engine.totalPages)").monospacedDigit() } }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("前往頁面")
                Button { engine.goToNextPage() } label: { Image(systemName: "chevron.right") }
                    .disabled(engine.currentPageIndex >= engine.totalPages - 1).help("下一頁")
            }
            Button { engine.setReadingMode(false) } label: { Image(systemName: "pencil") }.help("回到編輯模式")
            Button { showPins.toggle() } label: { HeiBanPinIcon().frame(width: 22, height: 22) }
                .accessibilityLabel("圖釘導航").help("圖釘導航")
                .popover(isPresented: $showPins) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { HeiBanPinIcon().frame(width: 20, height: 20); Text("圖釘導航").font(.headline) }

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

                        let allPins = engine.board.pins ?? []
                        let pins = PinSearchFilter.filter(pins: allPins, query: pinSearchQuery)

                        if pins.isEmpty {
                            Text(allPins.isEmpty ? "尚無圖釘" : "找不到符合的圖釘").foregroundStyle(.secondary).font(.caption)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(pins) { pin in
                                        Button {
                                            engine.jumpToPin(pin)
                                            if !engine.viewportLocked { showPins = false }
                                        } label: {
                                            HStack {
                                                HeiBanPinIcon()
                                                    .frame(width: 20, height: 20)
                                                    .foregroundStyle(Color(hex: pin.effectiveColor))
                                                Text(pin.name)
                                                    .foregroundStyle(Color(hex: pin.effectiveTextColor))
                                                    .lineLimit(1)
                                                Spacer()
                                                Text("\(Int(pin.zoom * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(engine.viewportLocked)
                                        .contextMenu {
                                            Menu("圖釘主體顏色") {
                                                Button("藍綠色（預設）") { engine.updatePinColor(id: pin.id, color: "#39B9DC", textColor: pin.textColor) }
                                                Button("珊瑚粉") { engine.updatePinColor(id: pin.id, color: "#fb7185", textColor: pin.textColor) }
                                                Button("琥珀黃") { engine.updatePinColor(id: pin.id, color: "#f59e0b", textColor: pin.textColor) }
                                                Button("翡翠綠") { engine.updatePinColor(id: pin.id, color: "#10b981", textColor: pin.textColor) }
                                                Button("靛藍紫") { engine.updatePinColor(id: pin.id, color: "#6366f1", textColor: pin.textColor) }
                                                Button("深石墨") { engine.updatePinColor(id: pin.id, color: "#475569", textColor: pin.textColor) }
                                            }
                                            Menu("圖釘文字顏色") {
                                                Button("森林深綠（預設）") { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#397056") }
                                                Button("純白") { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#ffffff") }
                                                Button("深灰黑") { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#1e293b") }
                                                Button("珊瑚紅") { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#e11d48") }
                                                Button("琥珀棕") { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#b45309") }
                                                Button("靛青") { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#1e40af") }
                                            }
                                            Divider()
                                            Button("刪除圖釘", role: .destructive) { engine.removePin(id: pin.id) }
                                        }
                                    }
                                }
                            }.frame(maxHeight: 220)
                        }
                        if engine.viewportLocked { Text("請先解除左下角的視角鎖定").font(.caption).foregroundStyle(.secondary) }
                    }.padding(16).frame(width: 260)
                }
            Button { headerPinned.toggle() } label: {
                Image(systemName: headerPinned ? "eye.fill" : "eye")
            }.help(headerPinned ? "取消固定導覽列" : "固定導覽列")
        }.buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule()).shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            .fixedSize(horizontal: true, vertical: true)
            .onChange(of: showPins) { _, open in onPanelChanged(open) }
            .onDisappear { onPanelChanged(false) }
    }
}
