import SwiftUI
import AppKit
import UniformTypeIdentifiers
import HeiBanCore

public struct CanvasView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @AppStorage("HeiBan.rulerLabelColor") private var rulerLabelColor = "#FFFFFF"
    @AppStorage("HeiBan.rulerColorMode") private var rulerColorMode = "adaptive"

    public init(engine: BoardEngine) {
        self.engine = engine
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Board Background & Grid
                CanvasBackgroundView(
                    theme: engine.board.boardTheme,
                    gridStyle: engine.board.gridStyle,
                    viewport: engine.viewport,
                    canvasMode: engine.board.canvasMode,
                    canvasWidth: engine.board.canvasWidth,
                    canvasHeight: engine.board.canvasHeight,
                    backgroundColor: engine.board.backgroundColor,
                    gridColor: engine.board.gridColor
                )

                // 2. Render Board Objects
                CanvasObjectsLayer(engine: engine)
                    .mask(CanvasContentBounds(board: engine.board, viewport: engine.viewport))

                // 3. Render In-flight Stroke & GoodNotes Snapped Preview
                InFlightStrokeView(engine: engine, preview: engine.strokePreview)
                    .mask(CanvasContentBounds(board: engine.board, viewport: engine.viewport))

                // 3.5 Selection Bounding Box & Transform Handles Overlay
                if !engine.readingMode { SelectionOverlayView(engine: engine) }

                // 4. Gesture surface sits behind the ruler so ruler handles can receive drags.
                NativePointerSurface(engine: engine)

                if engine.currentTool == .eraser,
                   let point = engine.eraserCursorPoint ?? engine.hoverCursorPoint {
                    EraserCursorOverlayView(engine: engine, point: point)
                        .allowsHitTesting(false)
                        .zIndex(12)
                } else if let pt = engine.hoverCursorPoint, let d = engine.toolCursorDiameter, d > 0 {
                    HoverCursorOverlayView(point: pt, diameter: d, color: Color(hex: engine.activeColor), outline: cursorOutlineColor)
                        .allowsHitTesting(false)
                        .zIndex(13)
                }

                if !engine.readingMode {
                    PolygonVertexHandlesView(engine: engine)
                }

                // 5. Virtual Screen Ruler Overlay
                if engine.ruler.enabled && !engine.readingMode {
                    RulerOverlayView(engine: engine, appearance: RulerAppearance(
                        backgroundColor: engine.board.backgroundColor,
                        customInk: rulerColorMode == "custom" ? rulerLabelColor : nil
                    ))
                }

                PinMarkerOverlayView(engine: engine)

                if !engine.readingMode {
                    SelectionQuickActionBar(engine: engine)
                }

                // Alignment Guides
                if !engine.readingMode {
                    AlignmentGuidesOverlayView(engine: engine)
                        .zIndex(10)
                }

                // In-flight Lasso
                if engine.currentTool == .lasso {
                    LassoOverlayView(engine: engine)
                        .zIndex(11)
                }

                // Share the exact canvas origin with committed arcs, including title-bar safe areas.
                CompassOverlayView(compass: engine.compassEngine, engine: engine)
                    .zIndex(15)

                // Laser Overlay
                LaserOverlayView(laser: engine.laserEngine, viewport: engine.viewport)
                    .zIndex(14)

                // World Coordinate Ruler (R10)
                if engine.showWorldRuler && !engine.readingMode {
                    WorldRulerOverlayView(engine: engine)
                        .zIndex(16)
                }

                // NativePointerSurface handles canvas wheel input. AppKit routes
                // editor/panel scrolling to the view under the pointer instead.

                if engine.showInlineTextEditor {
                    InlineTextEditorOverlay(engine: engine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(20)
                }
            }
            .coordinateSpace(name: "canvas")
            .onDrop(of: [UTType.fileURL, UTType.image], delegate: CanvasImageDropDelegate(engine: engine))
            .onAppear {
                engine.canvasSize = geo.size
                engine.repositionRulerIfNeeded(windowSize: geo.size)
            }
            .onChange(of: geo.size) { _, size in
                engine.canvasSize = size
                engine.repositionRulerIfNeeded(windowSize: size)
            }
            .clipped()
            .focusable()
            .onKeyPress(.escape) {
                engine.cancelTransientInteraction()
                return .handled
            }
        }
    }

    private var cursorOutlineColor: Color {
        guard let rgb = NSColor(Color(hex: engine.board.backgroundColor)).usingColorSpace(.deviceRGB) else { return .white }
        let luminance = rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114
        return luminance > 0.5 ? .black : .white
    }
}

struct CanvasImageDropDelegate: DropDelegate {
    let engine: BoardEngine

    func performDrop(info: DropInfo) -> Bool {
        guard !engine.readingMode else { return false }
        let screenPoint = Point(info.location)
        let providers = info.itemProviders(for: [.fileURL, .image])
        guard !providers.isEmpty else { return false }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let urlValue = item as? URL { url = urlValue }
                    else if let urlValue = item as? NSURL { url = urlValue as URL }
                    else { url = nil }
                    guard let url, let data = try? Data(contentsOf: url) else { return }
                    DispatchQueue.main.async {
                        engine.insertDroppedImage(data, filename: url.lastPathComponent, at: screenPoint)
                    }
                }
                return true
            }

            if let imageType = provider.registeredTypeIdentifiers.first(where: {
                guard let type = UTType($0) else { return false }
                return type.conforms(to: .image) && type != .image
            }) {
                provider.loadDataRepresentation(forTypeIdentifier: imageType) { data, _ in
                    guard let data else { return }
                    let filename = "截圖.\(UTType(imageType)?.preferredFilenameExtension ?? "png")"
                    DispatchQueue.main.async {
                        engine.insertDroppedImage(data, filename: filename, at: screenPoint)
                    }
                }
                return true
            }
        }
        return false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }
}

private struct PinMarkerOverlayView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine

    var body: some View {
        ForEach(engine.board.pins ?? []) { pin in
            let pinWorld = pin.resolveWorldPosition(canvasSize: engine.canvasSize)
            let point = VectorMath.worldToScreen(pinWorld, viewport: engine.viewport)
            let pinColor = Color(hex: pin.effectiveColor)
            let textColor = Color(hex: pin.effectiveTextColor)
            VStack(spacing: 2) {
                HeiBanPinIcon()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(pinColor)
                    .padding(4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.75), lineWidth: 1))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                Text(pin.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
            }
            .contentShape(Rectangle())
            .onTapGesture { engine.jumpToPin(pin) }
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named("canvas"))
                    .onChanged { if !engine.readingMode { engine.updatePinDrag(id: pin.id, at: Point($0.location)) } }
                    .onEnded { _ in engine.endPinDrag(id: pin.id) }
            )
            .contextMenu {
                Button(L10n.t("前往此圖釘視角")) {
                    engine.jumpToPin(pin)
                }
                Divider()
                Menu(L10n.t("圖釘主體顏色")) {
                    Button(L10n.t("藍綠色（預設）")) { engine.updatePinColor(id: pin.id, color: "#39B9DC", textColor: pin.textColor) }
                    Button(L10n.t("珊瑚粉")) { engine.updatePinColor(id: pin.id, color: "#fb7185", textColor: pin.textColor) }
                    Button(L10n.t("琥珀黃")) { engine.updatePinColor(id: pin.id, color: "#f59e0b", textColor: pin.textColor) }
                    Button(L10n.t("翡翠綠")) { engine.updatePinColor(id: pin.id, color: "#10b981", textColor: pin.textColor) }
                    Button(L10n.t("靛藍紫")) { engine.updatePinColor(id: pin.id, color: "#6366f1", textColor: pin.textColor) }
                    Button(L10n.t("深石墨")) { engine.updatePinColor(id: pin.id, color: "#475569", textColor: pin.textColor) }
                }
                Menu(L10n.t("圖釘文字顏色")) {
                    Button(L10n.t("森林深綠（預設）")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#397056") }
                    Button(L10n.t("純白")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#ffffff") }
                    Button(L10n.t("深灰黑")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#1e293b") }
                    Button(L10n.t("珊瑚紅")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#e11d48") }
                    Button(L10n.t("琥珀棕")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#b45309") }
                    Button(L10n.t("靛青")) { engine.updatePinColor(id: pin.id, color: pin.color, textColor: "#1e40af") }
                }
                Divider()
                Button(L10n.t("刪除圖釘"), role: .destructive) {
                    engine.removePin(id: pin.id)
                }
            }
            .position(x: point.x, y: point.y)
            .zIndex(15)
            .help("圖釘：\(pin.name)；點擊返回此視角")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("圖釘：\(pin.name)")
            .accessibilityAddTraits(.isButton)
        }
    }
}

struct PolygonVertexHandlesView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine

    var body: some View {
        ForEach(engine.selectedObjects.filter { ["triangle", "quadrilateral", "curve"].contains($0.type) }) { object in
            ForEach(Array(object.parsedPoints.enumerated()), id: \.offset) { index, point in
                PolygonVertexHandleView(
                    engine: engine,
                    objectID: object.id,
                    index: index,
                    point: VectorMath.worldToScreen(point, viewport: engine.viewport)
                )
            }
        }
    }
}

struct EraserCursorOverlayView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    let point: Point

    var body: some View {
        let diameter = engine.eraserSize
        Circle()
            .fill(Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.24))
            .overlay(
                Circle()
                    .strokeBorder(Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 3, height: 3)
            )
            .frame(width: diameter, height: diameter)
            .position(x: point.x, y: point.y)
    }
}

private struct HoverCursorOverlayView: View {
    @ObservedObject private var language = L10n.shared
    let point: Point
    let diameter: Double
    let color: Color
    let outline: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .overlay(
                Circle()
                    .strokeBorder(outline.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            )
            .overlay(
                Group {
                    if diameter >= 8 {
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 2.5, height: 2.5)
                    }
                }
            )
            .frame(width: diameter, height: diameter)
            .position(x: point.x, y: point.y)
    }
}

private struct PolygonVertexHandleView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    let objectID: String
    let index: Int
    let point: Point

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 2)
            .position(x: point.x, y: point.y)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                    .onChanged { engine.updatePolygonVertex(objectID: objectID, index: index, at: Point($0.location)) }
                    .onEnded { _ in engine.endPolygonVertexDrag(objectID: objectID) }
            )
            .help(L10n.t("拖曳調整多邊形頂點"))
    }
}

// MARK: - Canvas Objects Rendering Layer
struct CanvasObjectsLayer: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var engine: BoardEngine
    @ViewState<CGSize> private var offset = CGSize.zero
    @ViewState<LineEndpointPreview?> private var endpoint: LineEndpointPreview?
    @ViewState<BoardObject?> private var shape: BoardObject?

    var body: some View {
        CanvasObjectsView(engine: engine, selectionOffset: offset, lineEndpoint: endpoint, shapeObject: shape)
            .onReceive(engine.strokePreview.$selectionOffset.removeDuplicates()) { offset = $0 }
            .onReceive(engine.strokePreview.$lineEndpoint.removeDuplicates()) { endpoint = $0 }
            .onReceive(engine.strokePreview.$shapeObject.removeDuplicates()) { shape = $0 }
    }
}
