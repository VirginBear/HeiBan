import AppKit
import HeiBanCore

/// Provides dynamic native cursors for transform handles (resize, diagonal, rotate).
public final class CursorHelper {
    public static let shared = CursorHelper()

    public private(set) lazy var resizeDiagonalNWSE: NSCursor = {
        makeDiagonalCursor(isNWSE: true)
    }()

    public private(set) lazy var resizeDiagonalNESW: NSCursor = {
        makeDiagonalCursor(isNWSE: false)
    }()

    public private(set) lazy var rotateCursor: NSCursor = {
        makeRotateCursor()
    }()

    private init() {}

    /// Activates the cursor corresponding to the given transform type.
    /// If nil, resets to the standard arrow cursor.
    public static func setCursor(for type: TransformCursorType?) {
        guard let type else {
            NSCursor.arrow.set()
            return
        }
        switch type {
        case .resizeHorizontal:
            NSCursor.resizeLeftRight.set()
        case .resizeVertical:
            NSCursor.resizeUpDown.set()
        case .resizeDiagonalNWSE:
            shared.resizeDiagonalNWSE.set()
        case .resizeDiagonalNESW:
            shared.resizeDiagonalNESW.set()
        case .rotate:
            shared.rotateCursor.set()
        }
    }

    // MARK: - Vector Cursor Generators

    private func makeDiagonalCursor(isNWSE: Bool) -> NSCursor {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current?.cgContext
            ctx?.saveGState()
            defer { ctx?.restoreGState() }

            // Center coordinate system at (12, 12)
            ctx?.translateBy(x: 12, y: 12)
            // NWSE is -45 degrees, NESW is 45 degrees
            let angle: CGFloat = isNWSE ? -45.0 * .pi / 180.0 : 45.0 * .pi / 180.0
            ctx?.rotate(by: angle)

            let path = NSBezierPath()
            // Shaft from -8 to +8
            path.move(to: NSPoint(x: -8, y: 0))
            path.line(to: NSPoint(x: 8, y: 0))

            // Left / top arrowhead
            path.move(to: NSPoint(x: -8, y: 0))
            path.line(to: NSPoint(x: -3, y: -4))
            path.move(to: NSPoint(x: -8, y: 0))
            path.line(to: NSPoint(x: -3, y: 4))

            // Right / bottom arrowhead
            path.move(to: NSPoint(x: 8, y: 0))
            path.line(to: NSPoint(x: 3, y: -4))
            path.move(to: NSPoint(x: 8, y: 0))
            path.line(to: NSPoint(x: 3, y: 4))

            // White high-contrast outline
            NSColor.white.setStroke()
            path.lineWidth = 3.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            // Dark inner core
            NSColor(calibratedWhite: 0.1, alpha: 1.0).setStroke()
            path.lineWidth = 1.5
            path.stroke()

            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }

    private func makeRotateCursor() -> NSCursor {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current?.cgContext
            ctx?.saveGState()
            defer { ctx?.restoreGState() }

            let center = NSPoint(x: 12, y: 12)
            let radius: CGFloat = 6.5

            // Circular arc clockwise
            let arcPath = NSBezierPath()
            arcPath.appendArc(withCenter: center, radius: radius, startAngle: 30, endAngle: 280, clockwise: false)

            // Arrowhead tip at ~280 degrees
            let rad = 280.0 * .pi / 180.0
            let tipX = center.x + radius * cos(rad)
            let tipY = center.y + radius * sin(rad)

            let arrowPath = NSBezierPath()
            arrowPath.move(to: NSPoint(x: tipX, y: tipY))
            arrowPath.line(to: NSPoint(x: tipX - 4.5, y: tipY - 0.5))
            arrowPath.move(to: NSPoint(x: tipX, y: tipY))
            arrowPath.line(to: NSPoint(x: tipX - 1.5, y: tipY + 4.5))

            let fullPath = NSBezierPath()
            fullPath.append(arcPath)
            fullPath.append(arrowPath)

            // White high-contrast outline
            NSColor.white.setStroke()
            fullPath.lineWidth = 3.5
            fullPath.lineCapStyle = .round
            fullPath.lineJoinStyle = .round
            fullPath.stroke()

            // Dark inner core
            NSColor(calibratedWhite: 0.1, alpha: 1.0).setStroke()
            fullPath.lineWidth = 1.5
            fullPath.stroke()

            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }
}
