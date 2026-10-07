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
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { engine.showInspector = true }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("屬性")
                                                .font(.system(size: 11, weight: .medium))
                                        }
                                        .foregroundStyle(.primary.opacity(0.85))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.regularMaterial, in: Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 16)
                                    .help("開啟屬性檢查器")
                                }
                                Spacer()
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
