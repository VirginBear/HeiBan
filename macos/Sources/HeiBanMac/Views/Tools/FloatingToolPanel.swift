import SwiftUI

/// Panels share one drag policy: title only, stable workspace coordinates, bounded position.
struct FloatingToolPanel<Content: View>: View {
    let title: String
    let symbol: String
    let width: CGFloat
    let workspaceSize: CGSize
    @Binding var offset: CGSize
    @Binding var isCollapsed: Bool
    @Binding var isVisible: Bool
    @ViewBuilder var content: () -> Content
    @ViewState private var measuredSize = CGSize.zero
    @ViewState private var dragOrigin: CGSize?

    private func bounded(_ proposed: CGSize) -> CGSize {
        CGSize(
            width: min(max(12, proposed.width), max(12, workspaceSize.width - measuredSize.width - 12)),
            height: min(max(12, proposed.height), max(12, workspaceSize.height - measuredSize.height - 12))
        )
    }

    var body: some View {
        let origin = bounded(offset)
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: symbol).foregroundStyle(Color.accentColor)
                    Text(title).fontWeight(.semibold)
                    Spacer(minLength: 12)
                }
                .font(.system(size: 13))
                .frame(height: 26)
                .contentShape(Rectangle())
                .help("拖曳標題移動\(title)")
                .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("HeiBan.workspace"))
                    .onChanged { value in
                        if dragOrigin == nil { dragOrigin = bounded(offset) }
                        guard let start = dragOrigin else { return }
                        offset = bounded(CGSize(width: start.width + value.translation.width,
                                                height: start.height + value.translation.height))
                    }
                    .onEnded { _ in dragOrigin = nil })

                Button { isCollapsed.toggle() } label: {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .frame(width: 24, height: 26)
                }
                .help(isCollapsed ? "展開\(title)" : "收合\(title)")
                Button { isVisible = false } label: {
                    Image(systemName: "xmark").frame(width: 24, height: 26)
                }
                .help("關閉\(title)")
            }
            .buttonStyle(.plain)
            if !isCollapsed {
                content().padding(.top, 8)
            }
        }
        .frame(width: width)
        .padding(12)
        .fixedSize(horizontal: true, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 5)
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear { measuredSize = geometry.size; offset = bounded(offset) }
                .onChange(of: geometry.size) { _, size in measuredSize = size; offset = bounded(offset) }
        })
        .position(x: origin.width + measuredSize.width / 2,
                  y: origin.height + measuredSize.height / 2)
        .onChange(of: workspaceSize) { _, _ in offset = bounded(offset) }
    }
}
