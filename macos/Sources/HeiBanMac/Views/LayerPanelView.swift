import SwiftUI
import HeiBanCore

public struct LayerPanelView: View {
    @ObservedObject var engine: BoardEngine

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    private var reversedObjects: [BoardObject] {
        engine.currentPageObjects.sorted { $0.zIndex > $1.zIndex }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.3.layers.3d")
                    .foregroundColor(Color.accentColor)
                    .font(.system(size: 13, weight: .bold))
                Text("圖層 (\(engine.currentPageObjects.count))")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    engine.showLayerPanel = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            // Quick Reorder & Layer Action Buttons
            HStack(spacing: 8) {
                Button {
                    engine.bringToFront(ids: engine.selectedIds)
                } label: {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedIds.isEmpty)
                .help("置於頂層")

                Button {
                    engine.bringForward(ids: engine.selectedIds)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedIds.isEmpty)
                .help("上移一層")

                Button {
                    engine.sendBackward(ids: engine.selectedIds)
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedIds.isEmpty)
                .help("下移一層")

                Button {
                    engine.sendToBack(ids: engine.selectedIds)
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedIds.isEmpty)
                .help("置於底層")

                Spacer()

                Button {
                    engine.toggleLock(ids: engine.selectedIds)
                } label: {
                    Image(systemName: "lock")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedIds.isEmpty)
                .help("切換鎖定")

                Button {
                    engine.toggleVisibility(ids: engine.selectedIds)
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedIds.isEmpty)
                .help("切換顯示／隱藏")

                Button {
                    engine.removeObjects(ids: engine.selectedIds)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedIds.isEmpty)
                .help("刪除選取物件")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.02))

            Divider()

            // Layer Items List
            if engine.currentPageObjects.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "square.dashed")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("黑板尚無圖層物件")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(reversedObjects) { object in
                            let isSelected = engine.selectedIds.contains(object.id)
                            HStack(spacing: 8) {
                                Group {
                                    if object.type == "pin" {
                                        HeiBanPinIcon().frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: object.systemIconName).font(.system(size: 11))
                                    }
                                }
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                .frame(width: 16)

                                if engine.editingLayerId == object.id {
                                    TextField("名稱", text: $engine.editingLayerName, onCommit: {
                                        engine.setCustomName(id: object.id, name: engine.editingLayerName)
                                        engine.editingLayerId = nil
                                    })
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                } else {
                                    Text(object.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .lineLimit(1)
                                        .onTapGesture(count: 2) {
                                            engine.editingLayerId = object.id
                                            engine.editingLayerName = object.name ?? ""
                                        }
                                }

                                Spacer()

                                // Lock button
                                Button {
                                    let current = object.isLocked ?? false
                                    engine.setObjectLocked(id: object.id, isLocked: !current)
                                } label: {
                                    Image(systemName: (object.isLocked ?? false) ? "lock.fill" : "lock.open")
                                        .font(.system(size: 10))
                                        .foregroundColor((object.isLocked ?? false) ? .orange : .secondary.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .help((object.isLocked ?? false) ? "已鎖定（無法選取或擦除）" : "未鎖定")

                                // Visibility button
                                Button {
                                    let current = object.isVisible ?? true
                                    engine.setObjectVisible(id: object.id, isVisible: !current)
                                } label: {
                                    Image(systemName: (object.isVisible ?? true) ? "eye" : "eye.slash")
                                        .font(.system(size: 10))
                                        .foregroundColor((object.isVisible ?? true) ? .secondary : .secondary.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .help((object.isVisible ?? true) ? "顯示中" : "已隱藏")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                engine.selectedIds = [object.id]
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 380)
            }
        }
        .frame(width: 270)
        .background(Color.white.opacity(0.97), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}
