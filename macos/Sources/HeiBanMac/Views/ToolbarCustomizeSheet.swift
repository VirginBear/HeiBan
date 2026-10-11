import SwiftUI
import HeiBanCore

struct ToolbarCustomizeSheet: View {
    @ObservedObject var engine: BoardEngine
    @Binding var isPresented: Bool

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
        return result
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("自訂工具列").font(.headline)
                Spacer()
                Button("恢復預設") {
                    engine.resetToolbarPreferences()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("勾選以在工具列中顯示，點擊箭頭可調整前後順序。隱藏的工具仍可由工具列的「更多」按鈕快速啟用。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(allOrderedKeys.enumerated()), id: \.element) { index, id in
                        if let def = ToolbarPreferences.allDefinitions.first(where: { $0.id == id }) {
                            let isVisible = !engine.toolbarPreferences.hiddenItemIds.contains(id) && engine.toolbarPreferences.activeItemIds.contains(id)
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(
                                    get: { isVisible },
                                    set: { show in
                                        engine.setToolbarItemHidden(id: id, hidden: !show)
                                    }
                                ))
                                .labelsHidden()

                                Image(systemName: def.icon)
                                    .frame(width: 22)
                                    .foregroundColor(.accentColor)

                                Text(def.displayName)
                                    .font(.system(size: 13))

                                Spacer()

                                Button {
                                    if let currentIdx = engine.toolbarPreferences.activeItemIds.firstIndex(of: id), currentIdx > 0 {
                                        engine.moveToolbarItem(id: id, to: currentIdx - 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .buttonStyle(.borderless)
                                .disabled(!isVisible || (engine.toolbarPreferences.activeItemIds.firstIndex(of: id) ?? 0) == 0)

                                Button {
                                    if let currentIdx = engine.toolbarPreferences.activeItemIds.firstIndex(of: id),
                                       currentIdx < engine.toolbarPreferences.activeItemIds.count - 1 {
                                        engine.moveToolbarItem(id: id, to: currentIdx + 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .buttonStyle(.borderless)
                                .disabled(!isVisible || (engine.toolbarPreferences.activeItemIds.firstIndex(of: id) ?? 0) >= engine.toolbarPreferences.activeItemIds.count - 1)
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
                Button("完成") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
