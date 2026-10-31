import AppKit
import HeiBanCore

/// Provides dynamic native cursors for transform handles (resize, diagonal, rotate) and active tools.
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

    public private(set) lazy var transparentCursor: NSCursor = {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        return NSCursor(image: image, hotSpot: NSPoint(x: 4, y: 4))
    }()

    private var toolCursors: [String: NSCursor] = [:]

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

    /// Activates the cursor for the current canvas tool (1.0.18 Windows parity).
    public static func setToolCursor(tool: ToolType) {
        if tool == .select {
            NSCursor.arrow.set()
            return
        }
        if tool == .cane {
            // 藤條在畫布上由實體素材跟隨握柄點位，隱藏系統游標避免遮擋握柄。
            shared.transparentCursor.set()
            return
        }
        if let cached = shared.toolCursors[tool] {
            cached.set()
            return
        }
        let created = shared.makeToolBadgeCursor(tool: tool)
        shared.toolCursors[tool] = created
        created.set()
    }

    // MARK: - Vector Cursor Generators

    private func makeToolBadgeCursor(tool: ToolType) -> NSCursor {
        let size = NSSize(width: 28, height: 28)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.saveGState()
            defer { ctx.restoreGState() }

            // 1. Hotspot crosshair at (4, 4)
            let cross = CGMutablePath()
            cross.move(to: CGPoint(x: 1, y: 4))
            cross.addLine(to: CGPoint(x: 7, y: 4))
            cross.move(to: CGPoint(x: 4, y: 1))
            cross.addLine(to: CGPoint(x: 4, y: 7))

            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(3.0)
            ctx.addPath(cross)
            ctx.strokePath()

            ctx.setStrokeColor(NSColor(calibratedWhite: 0.1, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.4)
            ctx.addPath(cross)
            ctx.strokePath()

            // 2. Tool badge at lower-right (offset 7, 7, scaled from 24x24 to ~18x18)
            ctx.translateBy(x: 7, y: 7)
            ctx.scaleBy(x: 0.75, y: 0.75)

            let badge = Self.toolBadgePath(for: tool)
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(3.8)
            ctx.addPath(badge)
            ctx.strokePath()

            ctx.setStrokeColor(NSColor(calibratedWhite: 0.1, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.8)
            ctx.addPath(badge)
            ctx.strokePath()

            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 4, y: 4))
    }

    private static func toolBadgePath(for tool: ToolType) -> CGPath {
        let p = CGMutablePath()
        switch tool {
        case .pen:
            p.move(to: CGPoint(x: 4, y: 20))
            p.addLine(to: CGPoint(x: 9, y: 19))
            p.addLine(to: CGPoint(x: 19, y: 9))
            p.addLine(to: CGPoint(x: 15, y: 5))
            p.addLine(to: CGPoint(x: 5, y: 15))
            p.closeSubpath()
        case .curve:
            p.move(to: CGPoint(x: 4, y: 18))
            p.addCurve(to: CGPoint(x: 20, y: 6), control1: CGPoint(x: 8, y: 4), control2: CGPoint(x: 16, y: 20))
        case .highlighter:
            p.move(to: CGPoint(x: 6, y: 18))
            p.addLine(to: CGPoint(x: 16, y: 8))
            p.addLine(to: CGPoint(x: 19, y: 11))
            p.addLine(to: CGPoint(x: 9, y: 21))
            p.closeSubpath()
            p.move(to: CGPoint(x: 4, y: 21))
            p.addLine(to: CGPoint(x: 10, y: 21))
        case .paint:
            p.addRoundedRect(in: CGRect(x: 5, y: 5, width: 14, height: 7), cornerWidth: 2, cornerHeight: 2)
            p.move(to: CGPoint(x: 12, y: 12))
            p.addLine(to: CGPoint(x: 12, y: 20))
        case .eraser:
            p.move(to: CGPoint(x: 8, y: 6))
            p.addLine(to: CGPoint(x: 19, y: 13))
            p.addLine(to: CGPoint(x: 14, y: 20))
            p.addLine(to: CGPoint(x: 4, y: 13))
            p.closeSubpath()
        case .laser:
            p.addEllipse(in: CGRect(x: 9, y: 9, width: 6, height: 6))
            for (ax, ay, bx, by) in [(12.0, 3.0, 12.0, 6.0), (12.0, 18.0, 12.0, 21.0), (3.0, 12.0, 6.0, 12.0), (18.0, 12.0, 21.0, 12.0)] {
                p.move(to: CGPoint(x: ax, y: ay))
                p.addLine(to: CGPoint(x: bx, y: by))
            }
        case .line:
            p.move(to: CGPoint(x: 5, y: 19))
            p.addLine(to: CGPoint(x: 19, y: 5))
        case .arrow, .connector:
            p.move(to: CGPoint(x: 5, y: 19))
            p.addLine(to: CGPoint(x: 19, y: 5))
            p.move(to: CGPoint(x: 12, y: 5))
            p.addLine(to: CGPoint(x: 19, y: 5))
            p.addLine(to: CGPoint(x: 19, y: 12))
        case .rect, .roundedRect:
            p.addRoundedRect(in: CGRect(x: 5, y: 6, width: 14, height: 12), cornerWidth: 2, cornerHeight: 2)
        case .circle:
            p.addEllipse(in: CGRect(x: 5, y: 5, width: 14, height: 14))
        case .triangle:
            p.move(to: CGPoint(x: 12, y: 5))
            p.addLine(to: CGPoint(x: 20, y: 19))
            p.addLine(to: CGPoint(x: 4, y: 19))
            p.closeSubpath()
        case .diamond, .quadrilateral, .polygon, .star:
            p.move(to: CGPoint(x: 12, y: 4))
            p.addLine(to: CGPoint(x: 20, y: 12))
            p.addLine(to: CGPoint(x: 12, y: 20))
            p.addLine(to: CGPoint(x: 4, y: 12))
            p.closeSubpath()
        case .sticky:
            p.addRect(CGRect(x: 5, y: 5, width: 14, height: 14))
            p.move(to: CGPoint(x: 14, y: 19))
            p.addLine(to: CGPoint(x: 19, y: 14))
        case .text:
            p.move(to: CGPoint(x: 6, y: 6))
            p.addLine(to: CGPoint(x: 18, y: 6))
            p.move(to: CGPoint(x: 12, y: 6))
            p.addLine(to: CGPoint(x: 12, y: 19))
        case .tape:
            p.addRoundedRect(in: CGRect(x: 4, y: 8, width: 16, height: 8), cornerWidth: 2, cornerHeight: 2)
        case .lasso:
            p.addEllipse(in: CGRect(x: 5, y: 6, width: 14, height: 11))
        default:
            p.addEllipse(in: CGRect(x: 8, y: 8, width: 8, height: 8))
        }
        return p
    }

    private func makeDiagonalCursor(isNWSE: Bool) -> NSCursor {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size, flipped: false) { _ in
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
        let image = NSImage(size: size, flipped: false) { _ in
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
