import HeiBanCore
import SwiftUI

/// 同一組命令依停靠邊重排；視窗幾何／偏好仍由原生控制器持有。
struct ScreenAnnotationControls: View {
    @ObservedObject var controller: ScreenAnnotationController
    var body: some View {
        ScreenAnnotationToolControls(controller: controller, engine: controller.activeEngine)
            .frame(width: controller.controlsSize.width, height: controller.controlsSize.height)
    }
}

private struct ScreenAnnotationToolControls: View {
    @ObservedObject var controller: ScreenAnnotationController
    @ObservedObject var engine: BoardEngine
    @ViewState private var laserSettings = false
    @ViewState private var eraserSettings = false
    @ViewState private var brushSettings = false
    private let annotationTools: [(tool: String, icon: String, title: String)] = [
        (.select, "cursorarrow", "選取"), (.pen, "pencil", "畫筆"), (.highlighter, "highlighter", "螢光筆"),
        (.line, "line.diagonal", "直線"), (.arrow, "arrow.up.right", "箭頭"),
        (.curve, "scribble", "曲線"),
        (.rect, "square", "矩形"), (.circle, "circle", "圓"),
        (.text, "textformat", "文字（T）"),
        (.eraser, "eraser", "橡皮擦"), (.laser, "rays", "雷射筆"),
    ]
    private var vertical: Bool { controller.controlsDock.isVertical }
    private var horizontalToolAreaWidth: CGFloat { max(32, controller.controlsSize.width - 310) }
    private var horizontalToolColumns: [GridItem] {
        let count = max(1, min(annotationTools.count, Int((horizontalToolAreaWidth + 4) / 36)))
        return Array(repeating: GridItem(.fixed(32), spacing: 4, alignment: .center), count: count)
    }
    private var horizontalToolRows: Int {
        let columns = max(1, min(annotationTools.count, Int((horizontalToolAreaWidth + 4) / 36)))
        return (annotationTools.count + columns - 1) / columns
    }
    private var verticalColumnsCount: Int {
        controller.controlsSize.width >= 80 ? 2 : 1
    }
    private var verticalColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(32), spacing: 4, alignment: .center), count: verticalColumnsCount)
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
        .buttonStyle(.plain).font(.system(size: 14)).padding(vertical ? 8 : 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.gray.opacity(0.2)))
        .disabled(controller.isCapturing)
    }

    private var grip: some View {
        AnnotationPanelGrip(onBegin: controller.beginControlsDrag,
                            onMove: controller.moveControlsDrag, onEnd: controller.endControlsDrag)
            .frame(width: 24, height: 30)
            .help("拖曳到螢幕上下左右；放開後停靠，左右自動直排")
            .accessibilityLabel("移動螢幕畫布工具列")
    }

    private var drawingButton: some View {
        Button { controller.toggleDrawing() } label: {
            Group {
                if vertical {
                    Image(systemName: controller.isDrawing ? "pencil.tip" : "cursorarrow")
                } else {
                    Label(controller.isDrawing ? "作畫" : "操作",
                          systemImage: controller.isDrawing ? "pencil.tip" : "cursorarrow")
                }
            }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(controller.isDrawing ? Color.orange : Color.green)
                .frame(width: vertical ? 32 : 62, height: 32)
                .contentShape(Rectangle())
        }.help("\(controller.isDrawing ? "作畫中" : "操作中・滑鼠穿透")；⌘⌥⇧D 切換\n\(controller.message)")
            .accessibilityLabel(controller.isDrawing ? "切換為滑鼠穿透" : "切換為作畫")
    }

    private var horizontalControls: some View {
        HStack(spacing: 6) {
            grip
            drawingButton
            Divider().frame(height: 22)
            // 依螢幕實際寬度換列；固定控制與工具按鈕分開，所有工具不需捲動尋找。
            LazyVGrid(columns: horizontalToolColumns, alignment: .leading, spacing: 4) { toolButtons }
                .frame(width: horizontalToolAreaWidth, height: CGFloat(horizontalToolRows) * 36, alignment: .leading)
            Divider().frame(height: 22)
            undoButton
            redoButton
            captureButton
            layersButton
            moreMenu
            brushSettingsButton
            Divider().frame(height: 22)
            clearButton
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
            VStack(spacing: 4) { grip; drawingButton }
            Divider()
            // 空間不足時切換為雙欄，杜絕 ScrollView 滾動隱藏按鈕
            LazyVGrid(columns: verticalColumns, spacing: 4) {
                toolButtons
                undoButton
                redoButton
                captureButton
                layersButton
                brushSettingsButton
            }
            Divider()
            VStack(spacing: 4) { clearButton; moreMenu; closeButton }
        }
    }

    private var toolButtons: some View {
        ForEach(annotationTools, id: \.tool) { item in
            Button {
                if item.tool == .laser && engine.currentTool == .laser {
                    laserSettings = true
                } else if item.tool == .eraser && engine.currentTool == .eraser {
                    eraserSettings = true
                } else {
                    controller.selectTool(item.tool)
                }
            } label: {
                Group {
                    if item.tool == .text { Text("T").font(.system(size: 18, weight: .medium, design: .serif)) }
                    else { Image(systemName: item.icon) }
                }
                .frame(width: 32, height: 32)
                .background(engine.currentTool == item.tool ? Color.accentColor.opacity(0.15) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .help(item.title + (item.tool == .eraser || item.tool == .laser ? "：再次點擊開啟設定" : ""))
            .accessibilityLabel(item.title)
            .popover(isPresented: Binding(get: { laserSettings && item.tool == .laser }, set: { laserSettings = $0 }),
                     arrowEdge: popoverEdge) {
                LaserSettingsView(laser: engine.laserEngine)
            }
            .popover(isPresented: Binding(get: { eraserSettings && item.tool == .eraser }, set: { eraserSettings = $0 }),
                     arrowEdge: popoverEdge) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("橡皮擦").font(.headline)
                    Picker("模式", selection: $engine.eraserMode) {
                        Text("物件").tag(EraserMode.object)
                        Text("像素").tag(EraserMode.pixel)
                    }.pickerStyle(.segmented)
                    Text("範圍 \(Int(engine.eraserSize)) pt")
                    Slider(value: $engine.eraserSize, in: 4...120, step: 2)
                }.padding(16).frame(width: 260)
            }
        }
    }

    private var brushSettingsButton: some View {
        Button { brushSettings = true } label: {
            Circle().fill(Color(hex: engine.activeColor)).frame(width: 22, height: 22)
                .overlay(Circle().stroke(.gray.opacity(0.5)))
                .frame(width: 32, height: 32).contentShape(Rectangle())
        }
        .help("顏色、粗細、線型與填色")
        .accessibilityLabel("開啟註記樣式設定")
        .popover(isPresented: $brushSettings, arrowEdge: popoverEdge) {
            AnnotationBrushSettings(controller: controller, engine: engine)
        }
    }

    private func iconButton(_ icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 30, height: 32).contentShape(Rectangle())
        }.help(title).accessibilityLabel(title)
    }
    private var undoButton: some View {
        iconButton("arrow.uturn.backward", title: "復原這個螢幕的註記", action: engine.undo).disabled(!engine.canUndo)
    }
    private var redoButton: some View {
        iconButton("arrow.uturn.forward", title: "重做", action: engine.redo).disabled(!engine.canRedo)
    }
    private var clearButton: some View {
        iconButton("trash", title: "一鍵清空所有螢幕註記（可復原，不結束螢幕畫布）", action: controller.clearAnnotations)
    }
    private var closeButton: some View {
        iconButton("xmark", title: "結束螢幕畫布 · ⌘⌥⇧X", action: controller.stop)
    }
    private var captureButton: some View {
        iconButton("camera", title: "截圖並儲存 PNG · ⌘⌥⇧S", action: controller.captureScreen)
    }
    private var expandButton: some View {
        iconButton("arrow.up.left.and.arrow.down.right", title: "展開螢幕畫布工具列") {
            controller.setControlsCollapsed(false)
        }
    }
    private var layersButton: some View {
        Button {
            engine.showLayerPanel.toggle()
        } label: {
            Image(systemName: "square.3.layers.3d")
                .frame(width: 32, height: 32)
                .background(
                    engine.showLayerPanel ? Color.accentColor.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .help("物件圖層")
        .accessibilityLabel("開啟物件圖層面板")
    }
    private var moreMenu: some View {
        Menu {
            Button("收合工具列") { controller.setControlsCollapsed(true) }
            Menu("工具列位置") {
                ForEach(AnnotationToolbarDock.allCases, id: \.rawValue) { dock in
                    Button { controller.setControlsDock(dock) } label: {
                        if controller.controlsDock == dock { Label(dock.title, systemImage: "checkmark") }
                        else { Text(dock.title) }
                    }
                }
            }
            Divider()
            Button("截圖並儲存 PNG　⌘⌥⇧S") { controller.captureScreen() }
            Button("儲存可編輯註記 .heiban…") { controller.saveEditable() }
            Button("物件圖層") { engine.showLayerPanel = true }
            Button("一鍵清空畫布（可復原）") { controller.clearAnnotations() }
            Button("使用手冊") { controller.showUserGuide() }
            Divider()
            Text(controller.message)
        } label: {
            if vertical {
                Image(systemName: "ellipsis").frame(width: 32, height: 32)
            } else {
                MenuDisclosureLabel("螢幕畫布更多") { Image(systemName: "ellipsis").frame(width: 18, height: 24) }
            }
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("螢幕畫布更多設定").accessibilityLabel("螢幕畫布更多設定")
            .popover(isPresented: $engine.showLayerPanel, arrowEdge: popoverEdge) {
                LayerPanelView(engine: engine).frame(width: 280, height: 440)
            }
    }
}
