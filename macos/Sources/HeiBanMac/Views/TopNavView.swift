import SwiftUI
import HeiBanCore

public struct TopNavView: View {
    @ObservedObject var engine: BoardEngine

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button { engine.returnHome() } label: { Image(systemName: "house") }.buttonStyle(.plain).help("回到我的黑板")
            // App Branding & Title
            HStack(spacing: 8) {
                Image(systemName: "square.fill.and.line.vertical.and.square.fill")
                    .foregroundColor(Color.accentColor)
                    .font(.system(size: 16))

                TextField("黑板標題", text: $engine.board.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: 240)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))

            if engine.isNotebook {
                HStack(spacing: 8) {
                    Button {
                        engine.goToPreviousPage()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.currentPageIndex <= 0)
                    .help("上一頁")

                    Menu {
                        ForEach(engine.pages) { page in
                            Button {
                                engine.switchPage(to: page.id)
                            } label: {
                                HStack {
                                    Text(page.title)
                                    if page.id == engine.activePageId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            if let activeId = engine.activePageId {
                                engine.deletePage(id: activeId)
                            }
                        } label: {
                            Label("刪除當前頁面", systemImage: "trash")
                        }
                        .disabled(engine.totalPages <= 1)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 11))
                            Text("第 \(engine.currentPageIndex + 1) / \(engine.totalPages) 頁")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .menuStyle(.borderlessButton)

                    Button {
                        engine.goToNextPage()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.currentPageIndex >= engine.totalPages - 1)
                    .help("下一頁")

                    Button {
                        engine.addPage()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("新增筆記頁面")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            Label(
                engine.autosaveStatus.hasPrefix("自動儲存失敗") ? "儲存失敗" : (engine.autosaveStatus == "儲存中…" ? "儲存中" : "本機已存"),
                systemImage: engine.autosaveStatus.hasPrefix("自動儲存失敗") ? "exclamationmark.icloud" : (engine.autosaveStatus == "儲存中…" ? "arrow.triangle.2.circlepath" : "internaldrive")
            )
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(engine.autosaveStatus.hasPrefix("自動儲存失敗") ? .orange : .secondary)
                .frame(width: 82, alignment: .leading)
                .help("\(engine.autosaveStatus)；黑板會自動儲存在本機")
                .accessibilityLabel("儲存狀態：\(engine.autosaveStatus)")

            Spacer()

            // Theme Selector Menu
            Menu {
                ForEach(BoardTheme.allCases, id: \.self) { theme in
                    Button {
                        engine.board.boardTheme = theme
                        engine.board.backgroundColor = theme.defaultBackgroundColor
                    } label: {
                        HStack {
                            Text(theme.displayName)
                            if engine.board.boardTheme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette")
                    Text(engine.board.boardTheme.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton)

            // Grid Style Selector Menu
            Menu {
                ForEach(GridStyle.allCases, id: \.self) { grid in
                    Button {
                        engine.board.gridStyle = grid
                    } label: {
                        HStack {
                            Text(grid.displayName)
                            if engine.board.gridStyle == grid {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.2x2")
                    Text(engine.board.gridStyle.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton)

            // Pin Viewport Manager Button
            Button {
                engine.showPinPopover.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pin.fill")
                        .foregroundColor(Color.accentColor)
                    Text("圖釘 (\(engine.board.pins?.count ?? 0))")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $engine.showPinPopover) {
                PinManagerPopover(engine: engine, isPresented: $engine.showPinPopover)
            }

            // Layer Panel Toggle Button (A24)
            Button {
                engine.showLayerPanel.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.3.layers.3d")
                        .foregroundColor(engine.showLayerPanel ? Color.accentColor : Color.primary)
                    Text("圖層 (\(engine.currentPageObjects.count))")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(engine.showLayerPanel ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("開啟／關閉圖層面板 (A24)")

            // Inspector Toggle Button (A07, W11)
            Button {
                engine.showInspector.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(engine.showInspector ? Color.accentColor : Color.primary)
                    Text("屬性")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(engine.showInspector ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("開啟／關閉物件屬性檢查器 (A07)")

            // Zoom Controls
            HStack(spacing: 4) {
                Button {
                    engine.viewport.zoom = max(0.08, engine.viewport.zoom / 1.15)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                Text("\(Int(engine.viewport.zoom * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(width: 44)
                    .onTapGesture {
                        withAnimation {
                            engine.viewport.zoom = 1.0
                        }
                    }
                    .help("點擊重設為 100%")

                Button {
                    engine.viewport.zoom = min(8.0, engine.viewport.zoom * 1.15)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))

            // File IO Buttons
            HStack(spacing: 6) {
                Button {
                    engine.openFromFilePrompt()
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("開啟黑板專案檔 (.blackboard.json)")

                Button {
                    engine.saveToFilePrompt()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("儲存為黑板專案檔 (.blackboard.json)")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.97))
        .overlay(alignment: .bottom) {
            if let msg = engine.statusMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.92), in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                    .offset(y: 34)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Pin Manager Popover
struct PinManagerPopover: View {
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📍 圖釘視角導航 (Bookmarks)")
                .font(.system(size: 13, weight: .bold))

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

            Divider()

            let pins = engine.board.pins ?? []
            if pins.isEmpty {
                Text("尚無圖釘，點選新增將當前視角存為書籤！")
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
                                    isPresented = false
                                } label: {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)

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
        }
        .padding(14)
        .frame(width: 280)
    }
}
