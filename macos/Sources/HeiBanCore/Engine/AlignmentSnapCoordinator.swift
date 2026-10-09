import Foundation
import CoreGraphics

public struct AlignmentGuideLine: Identifiable, Equatable, Sendable {
    public let id: String
    public let isVertical: Bool
    public let position: Double     // X coordinate if vertical, Y if horizontal
    public let start: Double        // Y min if vertical, X min if horizontal
    public let end: Double          // Y max if vertical, X max if horizontal

    public init(id: String = UUID().uuidString, isVertical: Bool, position: Double, start: Double, end: Double) {
        self.id = id
        self.isVertical = isVertical
        self.position = position
        self.start = start
        self.end = end
    }
}

public struct AlignmentSnapResult: Equatable, Sendable {
    public let snappedDeltaX: Double
    public let snappedDeltaY: Double
    public let guides: [AlignmentGuideLine]

    public init(snappedDeltaX: Double, snappedDeltaY: Double, guides: [AlignmentGuideLine]) {
        self.snappedDeltaX = snappedDeltaX
        self.snappedDeltaY = snappedDeltaY
        self.guides = guides
    }
}

public enum AlignmentSnapCoordinator {
    /// Compute snapping for a moving bounding box against reference objects
    public static func computeSnap(
        movingBounds: CGRect,
        proposedDelta: CGSize,
        referenceObjects: [BoardObject],
        threshold: Double = 6.0
    ) -> AlignmentSnapResult {
        let proposedBounds = movingBounds.offsetBy(dx: proposedDelta.width, dy: proposedDelta.height)
        var deltaX = proposedDelta.width
        var deltaY = proposedDelta.height
        var guides: [AlignmentGuideLine] = []

        let movingLeft = Double(proposedBounds.minX)
        let movingCenterX = Double(proposedBounds.midX)
        let movingRight = Double(proposedBounds.maxX)

        let movingTop = Double(proposedBounds.minY)
        let movingCenterY = Double(proposedBounds.midY)
        let movingBottom = Double(proposedBounds.maxY)

        var bestDiffX: Double = threshold + 1
        var bestSnapX: Double?
        var bestGuideX: AlignmentGuideLine?

        var bestDiffY: Double = threshold + 1
        var bestSnapY: Double?
        var bestGuideY: AlignmentGuideLine?

        for ref in referenceObjects {
            let refLeft = min(ref.x, ref.x + ref.width)
            let refRight = max(ref.x, ref.x + ref.width)
            let refCenterX = (refLeft + refRight) / 2.0

            let refTop = min(ref.y, ref.y + ref.height)
            let refBottom = max(ref.y, ref.y + ref.height)
            let refCenterY = (refTop + refBottom) / 2.0

            // Test X alignments (Left-to-Left, Center-to-Center, Right-to-Right, Left-to-Right, Right-to-Left)
            let xPairs: [(Double, Double)] = [
                (movingLeft, refLeft),
                (movingCenterX, refCenterX),
                (movingRight, refRight),
                (movingLeft, refRight),
                (movingRight, refLeft)
            ]

            for (mX, rX) in xPairs {
                let diff = abs(mX - rX)
                if diff <= threshold && diff < bestDiffX {
                    bestDiffX = diff
                    let correction = rX - mX
                    bestSnapX = Double(proposedDelta.width) + correction
                    let yMin = min(movingTop, refTop)
                    let yMax = max(movingBottom, refBottom)
                    bestGuideX = AlignmentGuideLine(isVertical: true, position: rX, start: yMin, end: yMax)
                }
            }

            // Test Y alignments (Top-to-Top, Center-to-Center, Bottom-to-Bottom, Top-to-Bottom, Bottom-to-Top)
            let yPairs: [(Double, Double)] = [
                (movingTop, refTop),
                (movingCenterY, refCenterY),
                (movingBottom, refBottom),
                (movingTop, refBottom),
                (movingBottom, refTop)
            ]

            for (mY, rY) in yPairs {
                let diff = abs(mY - rY)
                if diff <= threshold && diff < bestDiffY {
                    bestDiffY = diff
                    let correction = rY - mY
                    bestSnapY = Double(proposedDelta.height) + correction
                    let xMin = min(movingLeft, refLeft)
                    let xMax = max(movingRight, refRight)
                    bestGuideY = AlignmentGuideLine(isVertical: false, position: rY, start: xMin, end: xMax)
                }
            }
        }

        if let snapX = bestSnapX {
            deltaX = snapX
            if let g = bestGuideX { guides.append(g) }
        }
        if let snapY = bestSnapY {
            deltaY = snapY
            if let g = bestGuideY { guides.append(g) }
        }

        return AlignmentSnapResult(snappedDeltaX: deltaX, snappedDeltaY: deltaY, guides: guides)
    }
}
