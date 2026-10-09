import HeiBanCore
import SwiftUI

/// 控制列只呼叫控制器命令；視窗、快捷鍵與文件寫入由控制器／session 管理。
struct ScreenAnnotationControls: View {
    @ObservedObject var controller: ScreenAnnotationController
    var body: some View {
        ScreenAnnotationToolControls(controller: controller, engine: controller.activeEngine)
    }
}

private struct ScreenAnnotationToolControls: View {
    @ObservedObject var controller: ScreenAnnotationController
    @ObservedObject var engine: BoardEngine
    @ViewState private var laserSettings = false
    @ViewState private var eraserSettings = false
    private let annotationTools: [(tool: String, icon: String, title: String)] = [
        (.select, "cursorarrow", "選取註記"), (.pen, "pencil", "畫筆"), (.highlighter, "highlighter", "螢光筆"),
        (.line, "line.diagonal", "直線"),
        (.arrow, "arrow.up.right", "箭頭"), (.rect, "square", "矩形"), (.circle, "circle", "圓"),
        (.eraser, "eraser", "橡皮擦"), (.laser, "rays", "雷射筆：再次點擊開啟設定"),
    ]
    private func annotationTool(_ tool: String, icon: String, title: String) -> some View {
        Button {
            if tool == .laser && engine.currentTool == .laser {
                laserSettings = true
            } else if tool == .eraser && engine.currentTool == .eraser {
                eraserSettings = true
            } else {
                controller.selectTool(tool)
            }
        } label: {
            Image(systemName: icon).frame(width: 23, height: 25)
                .background(
                    engine.currentTool == tool ? Color.accentColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        }
        .help(title)
        .popover(
            isPresented: Binding(get: { laserSettings && tool == .laser }, set: { laserSettings = $0 }),
            arrowEdge: .top
        ) {
            LaserSettingsView(laser: engine.laserEngine)
        }
        .popover(
            isPresented: Binding(get: { eraserSettings && tool == .eraser }, set: { eraserSettings = $0 }),
            arrowEdge: .top
        ) {
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
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AnnotationPanelGrip().frame(width: 22, height: 25).help("拖曳握把移動控制列")
                Button {
                    controller.toggleDrawing()
                } label: {
                    Label(
                        controller.isDrawing ? "作畫" : "操作",
                        systemImage: controller.isDrawing ? "pencil.tip" : "cursorarrow"
                    )
                    .foregroundStyle(controller.isDrawing ? Color.orange : Color.green)
                }.help("⌘⌥⇧D 切換作畫／滑鼠穿透")
                Divider().frame(height: 20)
                ForEach(annotationTools, id: \.tool) { item in
                    annotationTool(item.tool, icon: item.icon, title: item.title)
                }
                Divider().frame(height: 20)
                Button {
                    controller.activeEngine.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }.help("復原這個螢幕的註記")
                Button {
                    controller.activeEngine.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }.help("重做")
                Menu {
                    Button("截圖並儲存 PNG　⌘⌥⇧S") { controller.captureScreen() }
                    Button("儲存可編輯註記 .heiban…") { controller.saveEditable() }
                    Button("清除註記…") { controller.clearAnnotations() }
                    Button("使用手冊") { controller.showUserGuide() }
                } label: {
                    MenuDisclosureLabel("螢幕畫布更多") {
                        Image(systemName: "ellipsis").frame(width: 18, height: 24)
                    }
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                Button {
                    controller.stop()
                } label: {
                    Image(systemName: "xmark")
                }.help("結束螢幕畫布 · ⌘⌥⇧X")
            }
            HStack(spacing: 8) {
                ForEach(["#ef4444", "#f59e0b", "#22c55e", "#3b82f6", "#ffffff", "#111827"], id: \.self) {
                    color in
                    Button {
                        controller.setColor(color)
                    } label: {
                        Circle().fill(Color(hex: color)).frame(width: 20, height: 20).overlay(
                            Circle().stroke(.gray.opacity(0.4)))
                    }.accessibilityLabel("註記顏色 \(color)")
                }
                Text("粗細").font(.caption)
                Slider(
                    value: Binding(get: { engine.activeStrokeWidth }, set: controller.setWidth), in: 1...32
                ).frame(width: 75)
                Text("透明度").font(.caption)
                Slider(value: Binding(get: { engine.activeOpacity }, set: controller.setOpacity), in: 0.1...1)
                    .frame(width: 65)
                Text(controller.message).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain).font(.system(size: 14)).padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.gray.opacity(0.2)))
        .disabled(controller.isCapturing)
    }
}
