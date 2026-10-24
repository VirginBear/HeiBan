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
    private var showsModeTitle: Bool {
        !vertical && (!controller.controlsCollapsed || controller.controlsSize.width >= 328)
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
        .buttonStyle(.plain).padding(8)
        .frame(width: controller.controlsSize.width, height: controller.controlsSize.height,
               alignment: vertical ? .top : .leading)
        .modifier(ToolbarPanelSurface())
        .disabled(controller.isCapturing)
    }

    private var grip: some View {
        AnnotationPanelGrip(onBegin: controller.beginControlsDrag,
                            onMove: controller.moveControlsDrag, onEnd: controller.endControlsDrag)
            .frame(width: vertical ? 44 : 24, height: vertical ? 20 : 40)
            .overlay {
                Image(systemName: "line.3.horizontal")
                    .rotationEffect(.degrees(vertical ? 0 : 90))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
            .help(L10n.t("拖曳到螢幕上下左右；放開後停靠，左右自動直排"))
            .accessibilityLabel(L10n.t("移動螢幕畫布工具列"))
    }

    private var drawingButton: some View {
        Button { controller.toggleDrawing() } label: {
            HStack(spacing: 6) {
                Image(systemName: controller.isDrawing ? "cursorarrow.rays" : "pencil.tip")
                    .font(.system(size: 16))
                if showsModeTitle {
                    Text(L10n.t(controller.isDrawing ? "操作螢幕" : "繼續作畫"))
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .frame(width: showsModeTitle ? AnnotationToolbarLayout.horizontalModeButtonWidth : 32, height: 32)
            .foregroundStyle(controller.isDrawing ? Color.primary : Color(hex: "#39735a"))
            .background(controller.isDrawing ? Color.primary.opacity(0.06) : Color.green.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .fixedSize().layoutPriority(2)
        .help("\(L10n.t(controller.isDrawing ? "切換為滑鼠穿透" : "切換為作畫")) · ⌘⌥⇧D")
        .accessibilityLabel(L10n.t(controller.isDrawing ? "操作螢幕" : "繼續作畫"))
        .accessibilityValue(L10n.t(controller.isDrawing ? "作畫中" : "操作中・滑鼠穿透"))
        .accessibilityIdentifier("screen-canvas.mode")
    }

    private var horizontalControls: some View {
        HStack(spacing: 8) {
            grip
            drawingButton
            sharedTools
            closeButton
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
            grip
            drawingButton
            sharedTools
            closeButton
        }
    }

    // 和一般畫布相同的分頁與捲動方式；宿主持有分頁，切頁才改視窗大小。
    private var sharedTools: some View {
        let reserved = AnnotationToolbarLayout.expandedCommandLength(vertical: vertical)
        let length = (vertical ? controller.controlsSize.height : controller.controlsSize.width) - reserved
        return Group {
            if engine.toolbarPreferences.displayMode == "labels" {
                ToolbarToolsView(engine: engine, screenController: controller, availableLength: length,
                    externalActivePage: Binding(get: { controller.controlsPage }, set: controller.setControlsPage))
            } else {
                ScrollView(vertical ? .vertical : .horizontal) {
                    ToolbarToolsView(engine: engine, screenController: controller)
                        .fixedSize(horizontal: !vertical, vertical: vertical)
                }.scrollIndicators(.automatic)
            }
        }
        .frame(width: vertical ? nil : max(1, length - 48),
               height: vertical ? max(1, length - 42) : nil)
        .clipped().contentShape(Rectangle())
    }

    private func iconButton(_ icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 32, height: 32).contentShape(Rectangle())
        }.fixedSize().layoutPriority(2).help(L10n.t(title)).accessibilityLabel(L10n.t(title))
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
