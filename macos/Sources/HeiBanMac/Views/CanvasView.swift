import SwiftUI
import AppKit
import UniformTypeIdentifiers
import HeiBanCore

public struct CanvasView: View {
    @ObservedObject var engine: BoardEngine
    @AppStorage("HeiBan.rulerLabelColor") private var rulerLabelColor = "#FFFFFF"

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

                // 3. Render In-flight Stroke & GoodNotes Snapped Preview
                InFlightStrokeView(engine: engine, preview: engine.strokePreview)

                // 3.5 Selection Bounding Box & Transform Handles Overlay
                SelectionOverlayView(engine: engine)

                // 4. Gesture surface sits behind the ruler so ruler handles can receive drags.
                NativePointerSurface(engine: engine)

                if engine.currentTool == .eraser,
                   let point = engine.eraserCursorPoint ?? engine.hoverCursorPoint {
                    EraserCursorOverlayView(engine: engine, point: point)
                        .allowsHitTesting(false)
                        .zIndex(12)
                } else if let pt = engine.hoverCursorPoint, let d = engine.hoverCursorDiameter, d > 0 {
                    HoverCursorOverlayView(point: pt, diameter: d)
                        .allowsHitTesting(false)
                        .zIndex(13)
                }

                LineEndpointHandlesView(engine: engine, preview: engine.strokePreview)
                PolygonVertexHandlesView(engine: engine)

                // 5. Virtual Screen Ruler Overlay
                if engine.ruler.enabled {
                    RulerOverlayView(engine: engine, labelColor: rulerLabelColor)
                }

                PinMarkerOverlayView(engine: engine)

                // Wheel zoom is anchored to the pointer, like CAD editors.
                ScrollWheelMonitor { point, deltaX, deltaY, shift in
                    engine.handleScrollWheel(at: point, deltaX: deltaX, deltaY: deltaY, shift: shift)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            .onKeyPress(.space) {
                engine.isHoldingSpace = true
                return .handled
            }
            .onKeyPress(.escape) {
                engine.cancelTransientInteraction()
                return .handled
            }
        }
    }
}

private struct CanvasImageDropDelegate: DropDelegate {
    let engine: BoardEngine

    func performDrop(info: DropInfo) -> Bool {
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
    @ObservedObject var engine: BoardEngine

    var body: some View {
        ForEach(engine.board.pins ?? []) { pin in
            let pinWorld = pin.resolveWorldPosition(canvasSize: engine.canvasSize)
            let point = VectorMath.worldToScreen(pinWorld, viewport: engine.viewport)
            VStack(spacing: 2) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Color.accentColor, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                Text(pin.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
            }
            .contentShape(Rectangle())
            .onTapGesture { engine.jumpToPin(pin) }
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named("canvas"))
                    .onChanged { engine.updatePinDrag(id: pin.id, at: Point($0.location)) }
                    .onEnded { _ in engine.endPinDrag(id: pin.id) }
            )
            .position(x: point.x, y: point.y)
            .zIndex(15)
            .help("圖釘：\(pin.name)；點擊返回此視角")
        }
    }
}

private struct PolygonVertexHandlesView: View {
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

private struct EraserCursorOverlayView: View {
    @ObservedObject var engine: BoardEngine
    let point: Point

    var body: some View {
        let diameter = engine.eraserSize * engine.viewport.zoom
        Circle()
            .fill(Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.24))
            .overlay(
                Circle()
                    .stroke(Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 3, height: 3)
            )
            .frame(width: max(8, diameter), height: max(8, diameter))
            .position(x: point.x, y: point.y)
    }
}

private struct HoverCursorOverlayView: View {
    let point: Point
    let diameter: Double

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.22))
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
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
            .frame(width: max(4, diameter), height: max(4, diameter))
            .position(x: point.x, y: point.y)
    }
}

private struct PolygonVertexHandleView: View {
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
            .help("拖曳調整多邊形頂點")
    }
}

// MARK: - Canvas Objects Rendering Layer
struct CanvasObjectsLayer: View {
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

