import SwiftUI
import AppKit
import HeiBanCore

public struct MainWindowView: View {
    @ObservedObject private var engine: BoardEngine

    public init(engine: BoardEngine) { self.engine = engine }

    public var body: some View {
        Group {
            if engine.showingHome {
                HomeView(engine: engine)
            } else {
                GeometryReader { geo in
                    let vertical = engine.toolbarDock == "left" || engine.toolbarDock == "right"
                    ZStack(alignment: .top) {
                        CanvasView(engine: engine).ignoresSafeArea()
                        VStack { TopNavView(engine: engine); Spacer() }
                        ToolbarView(engine: engine)
                            .frame(width: vertical ? 64 : min(geo.size.width - 32, 800),
                                   height: vertical ? min(geo.size.height - 150, 700) : 60)
                            .position(engine.toolbarPosition(in: geo.size))

                        if engine.showInspector || engine.showLayerPanel {
                            VStack {
                                Spacer().frame(height: 56)
                                HStack(alignment: .top, spacing: 12) {
                                    Spacer()
                                    if engine.showInspector {
                                        InspectorView(engine: engine)
                                            .transition(.move(edge: .trailing).combined(with: .opacity))
                                    }
                                    if engine.showLayerPanel {
                                        LayerPanelView(engine: engine)
                                            .transition(.move(edge: .trailing).combined(with: .opacity))
                                    }
                                }
                                .padding(.trailing, 16)
                                Spacer()
                            }
                        }

                        if !engine.showInspector {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button {
                                        withAnimation(.easeOut(duration: 0.18)) { engine.showInspector = true }
                                    } label: {
                                        VStack(spacing: 5) {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("屬性")
                                                .font(.system(size: 10, weight: .semibold))
                                        }
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                        .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10, bottomTrailingRadius: 0, topTrailingRadius: 0))
                                        .overlay(alignment: .leading) { Rectangle().fill(Color.accentColor.opacity(0.55)).frame(width: 2) }
                                    }
                                    .buttonStyle(.plain)
                                    .help("開啟屬性檢查器")
                                }
                                Spacer()
                            }
                            .transition(.opacity)
                        }
                    }
                    .onChange(of: geo.size) { _, newSize in
                        engine.repositionPanelsIfNeeded(windowSize: newSize)
                    }
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in engine.flushAutosave() }
        .onChange(of: engine.objects) { _, _ in engine.scheduleAutosave() }
        .onChange(of: engine.board) { _, _ in engine.scheduleAutosave() }
    }
}
