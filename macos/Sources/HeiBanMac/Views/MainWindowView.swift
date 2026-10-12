import AppKit
import HeiBanCore
import SwiftUI

public struct MainWindowView: View {
    @ObservedObject private var engine: BoardEngine

    public init(engine: BoardEngine) { self.engine = engine }

    public var body: some View {
        Group {
            if engine.showingHome {
                HomeView(engine: engine)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .top) {
                        CanvasView(engine: engine).ignoresSafeArea()

                        if engine.readingMode {
                            VStack {
                                HStack {
                                    Spacer()
                                    WorkspaceHeaderView(engine: engine)
                                }.padding(16)
                                Spacer()
                            }
                        } else if !engine.isImmersiveMode {
                            VStack {
                                HStack {
                                    Spacer()
                                    WorkspaceHeaderView(engine: engine)
                                }
                                .padding(.trailing, 16)
                                .padding(.top, 12)
                                Spacer()
                            }
                            ToolbarView(engine: engine, windowSize: geo.size)
                        } else {
                            // Immersive mode subtle floating restore pill
                            VStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        engine.toggleImmersiveMode()
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                            Text("退出沉浸模式")
                                        }
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.regularMaterial, in: Capsule())
                                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.trailing, 16)
                                .padding(.top, 12)
                                Spacer()
                            }
                        }

                        if !engine.isImmersiveMode {
                            VStack {
                                Spacer()
                                HStack {
                                    WorkspaceNavigationView(engine: engine)
                                    Spacer()
                                }
                                .padding(
                                    .leading, engine.toolbarDock == "left" && !engine.readingMode ? 92 : 16
                                )
                                .padding(
                                    .bottom, engine.toolbarDock == "bottom" && !engine.readingMode ? 96 : 16)
                            }
                        }

                        if !engine.readingMode && engine.showLayerPanel && !engine.isImmersiveMode {
                            VStack {
                                Spacer().frame(height: 56)
                                HStack(alignment: .top, spacing: 12) {
                                    Spacer()
                                    LayerPanelView(engine: engine)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                                .padding(.trailing, 16)
                                Spacer()
                            }
                        }

                        if !engine.readingMode && !engine.isImmersiveMode {
                            InspectorDockView(engine: engine, windowSize: geo.size)
                        }

                        // Floating Auxiliary Tool Windows
                        CalculatorPanelView(model: engine.calculator, engine: engine, workspaceSize: geo.size)
                        TimerPanelView(
                            coordinator: engine.timerCoordinator, engine: engine, workspaceSize: geo.size)
                    }
                    .coordinateSpace(name: "HeiBan.workspace")
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        // 退出保存集中在 HeiBanAppDelegate；此處再保存會重複增加修訂版號。
        // 以下觀察涵蓋 UI 直接修改資料的情況，與命令保存共用同一 debounce 排程。
        .onChange(of: engine.objects) { _, _ in engine.scheduleAutosave() }
        .onChange(of: engine.board) { previous, current in
            // A successful save only advances the revision; it must not schedule another save.
            var contentBefore = previous
            contentBefore.revision = current.revision
            if contentBefore != current { engine.scheduleAutosave() }
        }
    }
}
