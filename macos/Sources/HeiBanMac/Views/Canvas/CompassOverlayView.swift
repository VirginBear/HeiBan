import SwiftUI
import HeiBanCore

public struct CompassOverlayView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var compass: CompassToolEngine
    @ObservedObject var engine: BoardEngine

    public init(compass: CompassToolEngine, engine: BoardEngine) {
        self.compass = compass
        self.engine = engine
    }

    public var body: some View {
        if compass.isEnabled {
            let centerScreen = compass.screenCenter(viewport: engine.viewport)
            let radiusScreen = compass.screenRadius(viewport: engine.viewport)
            let pencilScreen = compass.screenRadiusEndpoint(angleDeg: compass.currentPencilAngle, viewport: engine.viewport)
            let radiusHandleScreen = compass.screenRadiusEndpoint(angleDeg: 0.0, viewport: engine.viewport)

            ZStack {
                // 1. Auxiliary Dashed Circle Guide (Temporary Layer Only)
                Circle()
                    .stroke(
                        Color.cyan.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
                    .frame(width: max(2, radiusScreen * 2.0), height: max(2, radiusScreen * 2.0))
                    .position(x: centerScreen.x, y: centerScreen.y)
                    .allowsHitTesting(false)

                // 2. Active Arc Drawing Stroke Preview
                if compass.isDrawingArc && abs(compass.sweepAngle) > 0.1 {
                    Path { path in
                        let startDeg = compass.startAngle
                        let sweepDeg = compass.sweepAngle
                        path.addArc(
                            center: CGPoint(x: centerScreen.x, y: centerScreen.y),
                            radius: radiusScreen,
                            startAngle: Angle(degrees: startDeg),
                            endAngle: Angle(degrees: startDeg + sweepDeg),
                            clockwise: sweepDeg < 0
                        )
                    }
                    .stroke(
                        Color(hex: compass.strokeColor),
                        style: StrokeStyle(lineWidth: compass.strokeWidth * engine.viewport.zoom, lineCap: .round)
                    )
                    .allowsHitTesting(false)
                }

                // 3. Center Pivot Handle (Drag to move compass)
                centerPivotHandle(centerScreen: centerScreen)

                // 4. Radius Adjustment Handle
                radiusHandle(screenPos: radiusHandleScreen, centerScreen: centerScreen)

                // 5. Pencil Tip Handle (Drag along circumference to draw arc)
                pencilTipHandle(screenPos: pencilScreen, centerScreen: centerScreen)

                // 6. Floating Control Pill near Center Pivot
                floatingControlPill(centerScreen: centerScreen, radiusScreen: radiusScreen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "compassOverlay")
        }
    }

    // MARK: - Center Pivot Handle
    private func centerPivotHandle(centerScreen: Point) -> some View {
        ZStack {
            Circle()
                .fill(compass.isArmed ? Color.orange : Color.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 3)

            Circle()
                .stroke(compass.isArmed ? Color.orange : Color.accentColor, lineWidth: 2)
                .frame(width: 22, height: 22)

            Circle()
                .fill(compass.isArmed ? Color.white : Color.accentColor)
                .frame(width: 6, height: 6)
        }
        .position(x: centerScreen.x, y: centerScreen.y)
        .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("compassOverlay"))
                .onChanged { gesture in
                    let worldPt = VectorMath.screenToWorld(Point(gesture.location), viewport: engine.viewport)
                    compass.moveCenter(to: worldPt)
                }
        )
        .simultaneousGesture(TapGesture().onEnded { compass.toggleArmed() })
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { compass.toggleArmed() }
        .accessibilityLabel(compass.isArmed ? "圓規已鎖定，點擊回到準備" : "圓規準備中，點擊鎖定並開始繪製")
        .help(compass.isArmed ? "圓心已鎖定；再次點擊可調整位置與起點" : "拖曳移動圓心，點一下鎖定後才能畫弧")
    }

    // MARK: - Radius Handle
    private func radiusHandle(screenPos: Point, centerScreen: Point) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.2), radius: 2)

                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }

            Text("R: \(Int(compass.radius.rounded())) pt")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 2)
        }
        .position(x: screenPos.x + 36, y: screenPos.y)
        .gesture(
            DragGesture(coordinateSpace: .named("compassOverlay"))
                .onChanged { gesture in
                    guard !compass.isArmed else { return }
                    let dx = gesture.location.x - centerScreen.x
                    let dy = gesture.location.y - centerScreen.y
                    let screenDist = hypot(dx, dy)
                    let worldRadius = screenDist / engine.viewport.zoom
                    compass.adjustRadius(to: worldRadius)
                }
        )
        .help(L10n.t("拖曳調整圓規半徑"))
    }

    // MARK: - Pencil Tip Handle
    private func pencilTipHandle(screenPos: Point, centerScreen: Point) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: compass.strokeColor))
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.25), radius: 3)

            Image(systemName: "pencil.tip")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .position(x: screenPos.x, y: screenPos.y)
        .gesture(
            DragGesture(coordinateSpace: .named("compassOverlay"))
                .onChanged { gesture in
                    let dx = gesture.location.x - centerScreen.x
                    let dy = gesture.location.y - centerScreen.y
                    let angleRad = atan2(dy, dx)
                    var angleDeg = angleRad * 180.0 / Double.pi
                    if angleDeg < 0 { angleDeg += 360.0 }

                    if !compass.isArmed {
                        compass.positionPencil(atAngle: angleDeg)
                    } else if !compass.isDrawingArc {
                        compass.startArc(atAngle: angleDeg)
                    } else {
                        compass.updateSweep(toAngle: angleDeg)
                    }
                }
                .onEnded { _ in
                    if compass.isDrawingArc {
                        compass.finishArcDrawing()
                        if abs(compass.sweepAngle) >= 0.5 {
                            compass.commitArc(engine: engine, returnToSelect: true)
                        }
                    }
                }
        )
        .help(compass.isArmed ? "拖曳筆尖畫弧，放開建立可編輯物件" : "拖曳筆尖設定起點，不會畫線；準備好後點圓心")
    }

    // MARK: - Floating Control Pill
    private func floatingControlPill(centerScreen: Point, radiusScreen: Double) -> some View {
        HStack(spacing: 8) {
            Text(compass.isArmed ? "已鎖定 · 拖筆尖畫弧" : "準備 · 點圓心開始")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(compass.isArmed ? Color.orange : Color.secondary)
            Button {
                compass.drawFullCircle(engine: engine, returnToSelect: true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle")
                    Text(L10n.t("整圓"))
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help(L10n.t("一鍵繪製完整圓形"))

            if compass.isDrawingArc && abs(compass.sweepAngle) > 0.1 {
                Button {
                    compass.commitArc(engine: engine, returnToSelect: true)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text(L10n.t("完成圓弧"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(Color.green)
                }
                .buttonStyle(.plain)
            }

            Button {
                compass.isEnabled = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help(L10n.t("收起圓規"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .position(x: min(max(155, centerScreen.x), max(155, engine.canvasSize.width - 155)),
                  y: max(24, centerScreen.y - max(36.0, radiusScreen + 28.0)))
    }
}
