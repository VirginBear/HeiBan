import SwiftUI
import AppKit
import HeiBanCore

public struct SelectionQuickActionBar: View {
    @ObservedObject var engine: BoardEngine
    @ViewState private var barSize = CGSize(width: 220, height: 36)
    @ViewState private var showColorPopover = false
    @ViewState private var showWidthPopover = false
    @ViewState private var showFillPopover = false

    private let standardColors = [
        ("#86efac", "翠綠"),
        ("#fef08a", "淺黃"),
        ("#93c5fd", "湖藍"),
        ("#ffffff", "純白"),
        ("#f472b6", "淺粉"),
        ("#fb923c", "暖橘"),
        ("#c084fc", "粉紫")
    ]

    private let strokeSizes: [Double] = [2.0, 4.0, 8.0, 16.0, 32.0]

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    public var body: some View {
        let state = engine.selectionQuickBarState(for: barSize)
        if state.isVisible {
            HStack(spacing: 6) {
                // 文字格式集中到文字框右鍵，純文字選取不再重複顯示改色入口。
                if state.allowsColor && !engine.selectedObjects.allSatisfy({ $0.type == "text" || $0.type == "sticky" }) {
                    colorPickerSection
                }
                if state.allowsStrokeWidth {
                    strokeWidthSection
                }
                if state.allowsFill {
                    fillSection
                }
                Divider().frame(width: 1, height: 16)
                actionButtons(state: state)
                moreMenu(state: state)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .fixedSize(horizontal: true, vertical: true)
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear { barSize = geometry.size }
                    .onChange(of: geometry.size) { _, size in barSize = size }
            })
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            .position(x: CGFloat(state.center.x), y: CGFloat(state.center.y))
            .zIndex(18)
        }
    }

    @ViewBuilder
    private var colorPickerSection: some View {
        Button {
            showColorPopover.toggle()
        } label: {
            Circle()
                .fill(Color(hex: engine.selectedStrokeColor.valueOrNil ?? engine.activeColor))
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help("修改選取物件色彩")
        .popover(isPresented: $showColorPopover) {
            VStack(alignment: .leading, spacing: 8) {
                Text("線條色彩").font(.caption.bold())
                HStack(spacing: 5) {
                    ForEach(standardColors, id: \.0) { hex, name in
                        QuickColorSwatch(
                            hex: hex,
                            name: name,
                            isSelected: engine.selectedStrokeColor.valueOrNil == hex
                        ) {
                            engine.setSelectedStrokeColor(hex)
                            showColorPopover = false
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var strokeWidthSection: some View {
        Button {
            showWidthPopover.toggle()
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help("粗細設定")
        .popover(isPresented: $showWidthPopover) {
            VStack(alignment: .leading, spacing: 8) {
                Text("線條粗細").font(.caption.bold())
                HStack(spacing: 4) {
                    ForEach(strokeSizes, id: \.self) { sz in
                        Button {
                            engine.setSelectedStrokeWidth(sz)
                            showWidthPopover = false
                        } label: {
                            Text("\(Int(sz))")
                                .font(.caption.monospacedDigit())
                                .frame(minWidth: 26, minHeight: 24)
                                .background(engine.selectedStrokeWidth.valueOrNil == sz ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var fillSection: some View {
        Button {
            showFillPopover.toggle()
        } label: {
            Image(systemName: "square.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: engine.selectedFillColor.valueOrNil ?? "#ffffff").opacity(0.8))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help("填色與透明度")
        .popover(isPresented: $showFillPopover) {
            VStack(alignment: .leading, spacing: 8) {
                Text("形狀填色").font(.caption.bold())
                HStack(spacing: 5) {
                    Button("無填色") {
                        engine.setSelectedFillColor("none")
                        showFillPopover = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    ForEach(standardColors, id: \.0) { hex, name in
                        QuickColorSwatch(
                            hex: hex,
                            name: name,
                            isSelected: engine.selectedFillColor.valueOrNil == hex
                        ) {
                            engine.setSelectedFillColor(hex)
                            showFillPopover = false
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func actionButtons(state: SelectionQuickActionBarState) -> some View {
        Button {
            engine.duplicateSelected()
        } label: {
            Image(systemName: "plus.square.on.square")
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help("製作副本 (Cmd+D)")

        if engine.selectedObjects.contains(where: { $0.type == "tape" }) {
            Button {
                for obj in engine.selectedObjects where obj.type == "tape" {
                    engine.toggleTapeRevealed(id: obj.id)
                }
            } label: {
                let allRevealed = engine.selectedObjects.filter({ $0.type == "tape" }).allSatisfy({ $0.isRevealed == true })
                Image(systemName: allRevealed ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color.accentColor)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("切換遮題揭示／遮蔽")
        }

        Button {
            engine.deleteSelected()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 13))
                .foregroundColor(.red.opacity(0.85))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help("刪除選取物件 (Delete)")
    }

    @ViewBuilder
    private func moreMenu(state: SelectionQuickActionBarState) -> some View {
        Menu {
            Button("拷貝 (Cmd+C)") { engine.copySelected() }
            Button(state.isLocked ? "解鎖物件" : "鎖定物件") { engine.toggleSelectedLock() }
            Button("選取內容截圖") { engine.copySelectionAsImage() }
            Divider()
            Button("置於頂層") { engine.bringSelectedToFront() }
            Button("置於底層") { engine.sendSelectedToBack() }
            if state.selectedCount >= 2 {
                Button("群組 (Cmd+G)") { engine.groupSelected() }
            }
            if engine.selectedObjects.contains(where: { $0.groupId != nil }) {
                Button("解散群組 (Cmd+Shift+G)") { engine.ungroupSelected() }
            }
            Divider()
            Button("詳細屬性…") { engine.showInspector = true }
        } label: {
            MenuDisclosureLabel("物件更多動作") {
                Image(systemName: "ellipsis").font(.system(size: 14, weight: .semibold))
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: true)
        .help("更多動作")
    }
}

private struct QuickColorSwatch: View {
    let hex: String
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 0))
            .onTapGesture { onSelect() }
            .help(name)
    }
}
