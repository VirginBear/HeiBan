import SwiftUI
import HeiBanCore

/// Placement preferences are workspace state, independent of document history.
struct InspectorDockView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    let windowSize: CGSize
    @AppStorage("HeiBan.inspector.dock") private var savedEdge = "right"
    @AppStorage("HeiBan.inspector.alongEdge") private var alongEdge = 0.5
    @ViewState private var dragOrigin: CGPoint?
    @ViewState private var translation = CGSize.zero
    @ViewState private var dropTarget: String?

    private var edge: String { ["left", "right", "top", "bottom"].contains(savedEdge) ? savedEdge : "right" }
    private var vertical: Bool { edge == "left" || edge == "right" }
    private var size: CGSize {
        if engine.showInspector {
            if !vertical {
                let sideInsets: CGFloat = engine.toolbarDock == "left" || engine.toolbarDock == "right" ? 124 : 32
                return CGSize(width: min(842, max(260, windowSize.width - sideInsets)),
                              height: engine.selectedIds.isEmpty ? 156 : min(264, max(180, windowSize.height * 0.36)))
            }
            let top: CGFloat = engine.toolbarDock == "top" ? 144 : 64
            let bottom: CGFloat = engine.toolbarDock == "bottom" ? 96 : 76
            return CGSize(width: 280, height: engine.selectedIds.isEmpty ? 220 : min(520, max(220, windowSize.height - top - bottom - 16)))
        }
        return vertical ? CGSize(width: 40, height: 44) : CGSize(width: 94, height: 36)
    }
    private var limits: CGRect {
        let left: CGFloat = engine.toolbarDock == "left" ? 92 : 16
        let right: CGFloat = (engine.toolbarDock == "right" ? 92 : 16) +
            (engine.showInspector && engine.showLayerPanel && edge == "right" ? 292 : 0)
        let top: CGFloat = engine.toolbarDock == "top" ? 144 : 64
        let bottom: CGFloat = engine.toolbarDock == "bottom" ? 96 : 76
        let minX = left + size.width / 2
        let minY = top + size.height / 2
        let maxX = max(minX, windowSize.width - right - size.width / 2)
        let maxY = max(minY, windowSize.height - bottom - size.height / 2)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    private var restingCenter: CGPoint {
        let ratio = min(1, max(0, alongEdge))
        switch edge {
        case "left": return CGPoint(x: limits.minX, y: limits.minY + limits.height * ratio)
        case "right": return CGPoint(x: limits.maxX, y: limits.minY + limits.height * ratio)
        case "top": return CGPoint(x: limits.minX + limits.width * ratio, y: limits.minY)
        default: return CGPoint(x: limits.minX + limits.width * ratio, y: limits.maxY)
        }
    }
    private var center: CGPoint {
        guard let origin = dragOrigin else { return restingCenter }
        return engine.clampPanelCenter(CGPoint(x: origin.x + translation.width, y: origin.y + translation.height),
                                       panelSize: size, windowSize: windowSize, margin: 12)
    }
    private func nearestEdge(to point: CGPoint) -> String {
        [("left", abs(point.x)), ("right", abs(windowSize.width - point.x)),
         ("top", abs(point.y)), ("bottom", abs(windowSize.height - point.y))]
            .min(by: { $0.1 < $1.1 })?.0 ?? "right"
    }
    private func dragChanged(_ value: DragGesture.Value) {
        if dragOrigin == nil { dragOrigin = restingCenter }
        translation = value.translation
        dropTarget = nearestEdge(to: value.location)
    }
    private func dragEnded(_ value: DragGesture.Value) {
        let destination = center
        let nextEdge = nearestEdge(to: value.location)
        let ratio = (nextEdge == "left" || nextEdge == "right")
            ? (destination.y - limits.minY) / max(1, limits.height)
            : (destination.x - limits.minX) / max(1, limits.width)
        alongEdge = min(1, max(0, ratio))
        savedEdge = nextEdge
        dragOrigin = nil
        translation = .zero
        dropTarget = nil
    }
    private var drag: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("HeiBan.workspace"))
            .onChanged(dragChanged).onEnded(dragEnded)
    }

    var body: some View {
        ZStack {
            Group {
                if engine.showInspector {
                    InspectorView(engine: engine, horizontal: !vertical, onDragChanged: dragChanged, onDragEnded: dragEnded)
                } else {
                    Button { engine.showInspector = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 14, weight: .semibold))
                            if !vertical { Text(L10n.t("屬性")).font(.system(size: 12, weight: .medium)).lineLimit(1) }
                        }
                        .frame(width: size.width, height: size.height)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .highPriorityGesture(drag)
                    .help(L10n.t("點擊開啟屬性；拖曳標籤到視窗上下左右停靠"))
                    .accessibilityLabel(L10n.t("屬性，拖曳可切換停靠位置"))
                }
            }
            .frame(width: size.width, height: size.height)
            .contextMenu {
                Button(L10n.t("停靠左側")) { savedEdge = "left" }
                Button(L10n.t("停靠右側")) { savedEdge = "right" }
                Button(L10n.t("停靠上方")) { savedEdge = "top" }
                Button(L10n.t("停靠下方")) { savedEdge = "bottom" }
            }
            .position(center)

            if let target = dropTarget {
                let side = target == "left" || target == "right"
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.65), lineWidth: 2))
                    .frame(width: side ? 52 : 180, height: side ? 180 : 36)
                    .position(x: target == "left" ? 30 : target == "right" ? windowSize.width - 30 : windowSize.width / 2,
                              y: target == "top" ? 26 : target == "bottom" ? windowSize.height - 26 : windowSize.height / 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .transaction { $0.animation = nil }
    }
}
