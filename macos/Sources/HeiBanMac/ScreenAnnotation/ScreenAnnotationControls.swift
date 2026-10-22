import HeiBanCore
import SwiftUI

/// 同一組命令依停靠邊重排；視窗幾何／偏好仍由原生控制器持有。
struct ScreenAnnotationControls: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var controller: ScreenAnnotationController
    var body: some View {
        ScreenAnnotationToolControls(controller: controller, engine: controller.activeEngine)
            .frame(width: controller.controlsSize.width, height: controller.controlsSize.height)
    }
}

private struct ScreenAnnotationToolControls: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var controller: ScreenAnnotationController
    @ObservedObject var engine: BoardEngine
    private var vertical: Bool { controller.controlsDock.isVertical }
    private var itemCount: Int { ToolbarContentPolicy.screenItemCount(engine.toolbarPreferences) }
    private var columns: Int {
        vertical ? max(1, Int((controller.controlsSize.width - 12) / 36)) :
            AnnotationToolbarLayout.horizontalColumns(width: controller.controlsSize.width, itemCount: itemCount)
    }
    private var popoverEdge: Edge {
        switch controller.controlsDock {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }
    var body: some View {
        Group {
            if controller.controlsCollapsed { collapsedControls }
            else if vertical { verticalControls }
            else { horizontalControls }
        }
        .preferredColorScheme(.light).tint(Color(hex:"#39735a"))
        .buttonStyle(.plain).font(.system(size: 14)).padding(vertical ? 8 : 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.gray.opacity(0.2)))
        .disabled(controller.isCapturing)
    }

    private var grip: some View {
        AnnotationPanelGrip(onBegin: controller.beginControlsDrag,
                            onMove: controller.moveControlsDrag, onEnd: controller.endControlsDrag)
            .frame(width: 24, height: 30)
            .help(L10n.t("拖曳到螢幕上下左右；放開後停靠，左右自動直排"))
            .accessibilityLabel(L10n.t("移動螢幕畫布工具列"))
    }

    private var drawingButton: some View {
        Button { controller.toggleDrawing() } label: {
            Group {
                if vertical {
                    Image(systemName: controller.isDrawing ? "pencil.tip" : "cursorarrow")
                } else {
                    Label(L10n.t(controller.isDrawing ? "作畫" : "操作"),
                          systemImage: controller.isDrawing ? "pencil.tip" : "cursorarrow")
                }
            }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(controller.isDrawing ? Color.orange : Color.green)
                .frame(width: vertical ? 32 : 62, height: 32)
                .contentShape(Rectangle())
        }.help("\(controller.isDrawing ? "作畫中" : "操作中・滑鼠穿透")；⌘⌥⇧D 切換\n\(controller.message)")
            .accessibilityLabel(L10n.t(controller.isDrawing ? "切換為滑鼠穿透" : "切換為作畫"))
    }

    private var horizontalControls: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) { grip; drawingButton }.frame(width: 92)
            Divider().frame(width: 1, height: 22)
            sharedTools
                .frame(width: max(32, controller.controlsSize.width - AnnotationToolbarLayout.horizontalFixedWidth))
            Divider().frame(width: 1, height: 22)
            // 清空與退出在固定尾端，新增工具只增加中段列數，不能把退出推出 NSPanel。
            HStack(spacing: 6) { clearButton; closeButton }.frame(width: 70)
        }
    }

    private var collapsedControls: some View {
        Group {
            if vertical {
                VStack(spacing: 5) {
                    grip
                    drawingButton
                    Divider()
                    clearButton
                    moreMenu
                    expandButton
                    closeButton
                }
            } else {
                HStack(spacing: 6) {
                    grip
                    drawingButton
                    Divider().frame(height: 22)
                    clearButton
                    moreMenu
                    expandButton
                    closeButton
                }
            }
        }
    }

    private var verticalControls: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) { grip; drawingButton }
            Divider()
            sharedTools
            Divider()
            VStack(spacing: 4) { clearButton; closeButton }
        }
    }

    // 共用一般畫布的圖示、排序、設定與更多入口；这里只負責螢幕視窗的固定命令。
    private var sharedTools: some View {
        ToolbarToolsView(engine: engine, screenController: controller, columns: columns, availableLength: vertical ? controller.controlsSize.height-194 : controller.controlsSize.width-224)
    }

    private func iconButton(_ icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 32, height: 32).contentShape(Rectangle())
        }.help(L10n.t(title)).accessibilityLabel(L10n.t(title))
    }
    private var clearButton: some View {
        iconButton("trash", title: "一鍵清空所有螢幕註記（可復原，不結束螢幕畫布）", action: controller.clearAnnotations)
    }
    private var closeButton: some View {
        iconButton("xmark", title: "結束螢幕畫布 · ⌘⌥⇧X", action: controller.stop)
    }
    private var expandButton: some View {
        iconButton("arrow.up.left.and.arrow.down.right", title: "展開螢幕畫布工具列") {
            controller.setControlsCollapsed(false)
        }
    }
    private var moreMenu: some View {
        Menu {
            Button(L10n.t("收合工具列")) { controller.setControlsCollapsed(true) }
            Menu(L10n.t("工具列位置")) {
                ForEach(AnnotationToolbarDock.allCases, id: \.rawValue) { dock in
                    Button { controller.setControlsDock(dock) } label: {
                        if controller.controlsDock == dock { Label(L10n.t(dock.title), systemImage: "checkmark") }
                        else { Text(L10n.t(dock.title)) }
                    }
                }
            }
            Divider()
            Button(L10n.t("截圖並儲存 PNG　⌘⌥⇧S")) { controller.captureScreen() }
            Button(L10n.t("儲存可編輯註記 .heiban…")) { controller.saveEditable() }
            Button(L10n.t("物件圖層")) { engine.showLayerPanel = true }
            Button(L10n.t("一鍵清空畫布（可復原）")) { controller.clearAnnotations() }
            Button(L10n.t("使用手冊")) { controller.showUserGuide() }
            Divider()
            Text(controller.message)
        } label: {
            Image(systemName: "ellipsis.circle").frame(width: 32, height: 32)
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help(L10n.t("螢幕畫布更多設定")).accessibilityLabel(L10n.t("螢幕畫布更多設定"))
            .popover(isPresented: $engine.showLayerPanel, arrowEdge: popoverEdge) {
                LayerPanelView(engine: engine).frame(width: 280, height: 440)
            }
    }
}
