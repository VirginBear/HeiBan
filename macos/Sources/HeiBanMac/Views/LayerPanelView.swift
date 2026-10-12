import SwiftUI
import HeiBanCore

private struct LayerDragSession {
    var objectID: String
    var boardID: String
    var pageID: String?
}

private struct LayerInsertion: Equatable {
    var targetID: String
    var above: Bool
}

public struct LayerPanelView: View {
    @ObservedObject var engine: BoardEngine
    @ViewState private var dragSession: LayerDragSession?
    @ViewState private var insertion: LayerInsertion?

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    private var reversedObjects: [BoardObject] {
        engine.currentPageObjects.enumerated().sorted {
            $0.element.zIndex == $1.element.zIndex ? $0.offset > $1.offset : $0.element.zIndex > $1.element.zIndex
        }.map(\.element)
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
                                LayerDragHandle(object: object, onStart: {
                                    dragSession = LayerDragSession(objectID: object.id, boardID: engine.board.id, pageID: engine.activePageId)
                                    engine.selectedIds = [object.id]
                                }, onFinish: {
                                    dragSession = nil
                                    insertion = nil
                                })
                                .frame(width: 16, height: 24)
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
                            .frame(height: 24)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .opacity(dragSession?.objectID == object.id ? 0.4 : 1)
                            .overlay(alignment: insertion?.above == false ? .bottom : .top) {
                                if insertion?.targetID == object.id {
                                    HStack(spacing: 0) {
                                        Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                                        Rectangle().fill(Color.accentColor).frame(height: 2)
                                    }
                                    .allowsHitTesting(false)
                                    .help("插入「\(object.displayName)」\(insertion?.above == true ? "上方" : "下方")")
                                }
                            }
                            .onDrop(of: [LayerDragType.value], delegate: LayerRowDropDelegate(
                                engine: engine, targetID: object.id, session: $dragSession, insertion: $insertion))
                            .onTapGesture {
                                engine.selectedIds = [object.id]
                            }
                        }
                        // 底部留一個真正的 drop 區，最後一列也容易放到背景最底層。
                        if let last = reversedObjects.last {
                            Color.clear.frame(height: 18).contentShape(Rectangle())
                                .onDrop(of: [LayerDragType.value], delegate: LayerRowDropDelegate(
                                    engine: engine, targetID: last.id, session: $dragSession, insertion: $insertion, bottomZone: true))
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
        .onDisappear { dragSession = nil; insertion = nil }
    }
}

private struct LayerRowDropDelegate: DropDelegate {
    let engine: BoardEngine
    let targetID: String
    @Binding var session: LayerDragSession?
    @Binding var insertion: LayerInsertion?
    var bottomZone = false

    private var valid: Bool {
        guard let session, session.boardID == engine.board.id, session.pageID == engine.activePageId,
              session.objectID != targetID else { return false }
        let objects = engine.currentPageObjects
        return objects.contains { $0.id == session.objectID && $0.isLocked != true }
            && objects.contains { $0.id == targetID }
    }
    func validateDrop(info: DropInfo) -> Bool { valid && info.hasItemsConforming(to: [LayerDragType.value]) }
    func dropEntered(info: DropInfo) { updateInsertion(info) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard valid else { return DropProposal(operation: .cancel) }
        updateInsertion(info)
        return DropProposal(operation: .move)
    }
    func dropExited(info: DropInfo) {
        if insertion?.targetID == targetID { insertion = nil }
    }
    func performDrop(info: DropInfo) -> Bool {
        guard valid, let session else { return false }
        let above = !bottomZone && info.location.y < 18
        // 只接受本列表建立的 session，不從剪貼簿重建物件；中途切頁不會誤改新頁。
        engine.moveLayer(id: session.objectID, relativeTo: targetID, above: above)
        insertion = nil
        self.session = nil
        return true
    }
    private func updateInsertion(_ info: DropInfo) {
        guard valid else { return }
        let next = LayerInsertion(targetID: targetID, above: !bottomZone && info.location.y < 18)
        if insertion != next { insertion = next }
    }
}
