import HeiBanCore
import SwiftUI

/// 四邊工具列共用的樣式面板；只綁定目前螢幕的 engine，不複製編輯狀態。
struct AnnotationBrushSettings: View {
    @ObservedObject var controller: ScreenAnnotationController
    @ObservedObject var engine: BoardEngine
    private let colors = ["#ef4444", "#f59e0b", "#22c55e", "#3b82f6", "#ffffff", "#111827"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("顏色與筆刷").font(.headline)
            // 原生 popover 有自己的環境：明訂按鈕樣式及命中尺寸，避免
            // 預設灰底按鈕撐寬。格線跟隨可用寬度，不靠外層裁切色盤。
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Button { controller.setColor(color) } label: {
                        Circle().fill(Color(hex: color)).frame(width: 24, height: 24)
                            .overlay(Circle().stroke(.gray.opacity(0.5)))
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: engine.activeColor == color ? 2 : 0).padding(-3))
                            .frame(width: 36, height: 36).contentShape(Rectangle())
                    }
                    .help("註記顏色 \(color)")
                    .accessibilityLabel("註記顏色 \(color)")
                    .accessibilityAddTraits(engine.activeColor == color ? [.isSelected] : [])
                }
            }
            VStack(spacing: 6) {
                HStack {
                    Text("粗細")
                    Spacer()
                    Text("\(engine.activeStrokeWidth, specifier: "%.1f") pt").monospacedDigit()
                }
                Slider(value: Binding(get: { engine.activeStrokeWidth }, set: controller.setWidth), in: 1...32)
                    .accessibilityLabel("註記線條粗細")
            }
            VStack(spacing: 6) {
                HStack {
                    Text("透明度")
                    Spacer()
                    Text("\(Int(engine.activeOpacity * 100))%").monospacedDigit()
                }
                Slider(value: Binding(get: { engine.activeOpacity }, set: controller.setOpacity), in: 0.1...1)
                    .accessibilityLabel("註記透明度")
            }
            Text(controller.message).font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
        .padding(16)
        .frame(width: 280)
        // 面板取得自己的自然尺寸，不能沿用 64 pt 工具列的窄提案。
        .fixedSize(horizontal: true, vertical: true)
    }
}
