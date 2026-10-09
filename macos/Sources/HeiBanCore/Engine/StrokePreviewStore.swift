import CoreGraphics
import SwiftUI

/// 筆畫的高頻暫態資料獨立發布，避免每個游標取樣刷新整個作品與工具列。
public final class StrokePreviewStore: ObservableObject {
    @Published public private(set) var points: [Point] = []
    @Published public var snappedShape: RecognizedShape?
    @Published public var shapeObject: BoardObject?
    @Published public var selectionOffset: CGSize = .zero
    @Published public var lineEndpoint: LineEndpointPreview?

    /// A single sealed path keeps the renderer from issuing one stroke draw per chunk.
    /// Chunks are still built incrementally so pointer updates only append a small tail.
    public private(set) var stablePath = Path()
    public private(set) var activePath = Path()
    public private(set) var tailPath = Path()
    private var activeSegments = 0

    public init() {}

    public func begin(with point: Point) {
        stablePath = Path()
        activePath = Path()
        activePath.move(to: point.cgPoint)
        activeSegments = 0
        tailPath = Path()
        tailPath.move(to: point.cgPoint)
        tailPath.addLine(to: CGPoint(x: point.x + 0.01, y: point.y))
        points = [point]
        snappedShape = nil
        shapeObject = nil
    }

    public func append(_ point: Point) {
        points.append(point)
        snappedShape = nil
        let count = points.count
        if count >= 3 {
            VectorMath.appendSmoothSegment(to: &activePath, points: points, index: count - 3)
            activeSegments += 1
            if activeSegments == 64 {
                stablePath.addPath(activePath)
                activePath = Path()
                activePath.move(to: points[count - 2].cgPoint)
                activeSegments = 0
            }
        }
        tailPath = Path()
        if count >= 2 {
            tailPath.move(to: points[count - 2].cgPoint)
            VectorMath.appendSmoothSegment(to: &tailPath, points: points, index: count - 2)
        }
    }

    public func reset() {
        stablePath = Path()
        activePath = Path()
        tailPath = Path()
        activeSegments = 0
        points.removeAll(keepingCapacity: true)
        snappedShape = nil
        shapeObject = nil
        selectionOffset = .zero
        lineEndpoint = nil
    }
}
