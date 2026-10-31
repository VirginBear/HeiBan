import SwiftUI
import HeiBanCore

struct ToolbarCustomizeSheet: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool

    var screenContext = false

    private var allOrderedKeys: [String] {
        var result: [String] = []
        var seen = Set<String>()
        for id in engine.toolbarPreferences.activeItemIds {
            if seen.insert(id).inserted && ToolbarPreferences.allDefinitions.contains(where: { $0.id == id }) {
                result.append(id)
            }
        }
        for id in engine.toolbarPreferences.hiddenItemIds {
            if seen.insert(id).inserted && ToolbarPreferences.allDefinitions.contains(where: { $0.id == id }) {
                result.append(id)
            }
        }
        for def in ToolbarPreferences.allDefinitions {
            if seen.insert(def.id).inserted {
                result.append(def.id)
            }
        }
        return result.filter { ToolbarContentPolicy.isAvailable($0, screen: screenContext) }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.t("自訂工具列")).font(.headline)
                Spacer()
                Button(L10n.t("全選")) {
                    for id in allOrderedKeys { engine.setToolbarItemHidden(id:id,hidden:false) }
                }.buttonStyle(.bordered).controlSize(.small)
                Button(L10n.t("恢復預設")) {
                    engine.resetToolbarPreferences()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(L10n.t("勾選以在工具列中顯示，點擊箭頭可調整前後順序。隱藏的工具仍可由工具列的「更多」按鈕快速啟用。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(L10n.t("工具列格式"),selection:Binding(get:{engine.toolbarPreferences.displayMode},set:{engine.toolbarPreferences.displayMode=$0;engine.saveToolbarPreferences()})) {
                Text(L10n.t("只有圖示")).tag("icons")
                Text(L10n.t("圖示與文字（分頁）")).tag("labels")
            }
            Text(L10n.t("常用欄可獨立勾選；選取、雷射筆與藤條固定顯示")).font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(allOrderedKeys.enumerated()), id: \.element) { index, id in
                        if let def = ToolbarPreferences.allDefinitions.first(where: { $0.id == id }) {
                            let isVisible = !engine.toolbarPreferences.hiddenItemIds.contains(id) && engine.toolbarPreferences.activeItemIds.contains(id)
                            let isFixed = ToolbarPreferences.isFixedTool(id)
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(
                                    get: { isVisible },
                                    set: { show in
                                        engine.setToolbarItemHidden(id: id, hidden: !show)
                                    }
                                ))
                                .labelsHidden()
                                .disabled(isFixed)
                                if !isFixed {
                                    Toggle(L10n.t("常用"),isOn:Binding(get:{engine.toolbarPreferences.commonItemIds.contains(id)},set:{ value in
                                        if value { engine.toolbarPreferences.commonItemIds.append(id);engine.toolbarPreferences.setItemHidden(id:id,hidden:false) }
                                        else { engine.toolbarPreferences.commonItemIds.removeAll { $0==id } }
                                        engine.toolbarPreferences.normalize();engine.saveToolbarPreferences()
                                    })).toggleStyle(.checkbox).font(.caption)
                                }

                                Group {
                                    if id=="magnet" { HeiBanMagnetIcon() }
                                    else if id=="compass" { HeiBanCompassIcon() }
                                    else if id=="cane" { HeiBanCaneIcon() }
                                    else { Image(systemName:def.icon) }
                                }.frame(width:22).foregroundColor(.accentColor)

                                Text(L10n.t(def.displayName))
                                    .font(.system(size: 13))

                                Spacer()

                                Button {
                                    if let currentIdx = engine.toolbarPreferences.activeItemIds.firstIndex(of: id), currentIdx > ToolbarPreferences.fixedTools.count {
                                        engine.moveToolbarItem(id: id, to: currentIdx - 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .buttonStyle(.borderless)
                                .disabled(isFixed || !isVisible || (engine.toolbarPreferences.activeItemIds.firstIndex(of: id) ?? 0) <= ToolbarPreferences.fixedTools.count)

                                Button {
                                    if let currentIdx = engine.toolbarPreferences.activeItemIds.firstIndex(of: id),
                                       currentIdx < engine.toolbarPreferences.activeItemIds.count - 1 {
                                        engine.moveToolbarItem(id: id, to: currentIdx + 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .buttonStyle(.borderless)
                                .disabled(isFixed || !isVisible || (engine.toolbarPreferences.activeItemIds.firstIndex(of: id) ?? 0) >= engine.toolbarPreferences.activeItemIds.count - 1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .frame(maxHeight: 340)

            HStack {
                Spacer()
                Button(L10n.t("完成")) {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
