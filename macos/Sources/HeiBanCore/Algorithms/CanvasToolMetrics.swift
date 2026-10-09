import Foundation

/// Brush widths are document units; eraser diameter is a screen-space size.
public enum CanvasToolMetrics {
    public static func strokeWidth(tool: ToolType, baseWidth: Double) -> Double {
        switch tool {
        case .highlighter: return max(12, baseWidth * 3.5)
        case .paint: return max(24, baseWidth * 8)
        default: return baseWidth
        }
    }

    public static func brushStrokeWidth(kind: BrushKind, baseWidth: Double) -> Double {
        switch kind {
        case .pen: return baseWidth
        case .fountain: return baseWidth * 1.2
        case .pencil: return max(1.5, baseWidth * 0.9)
        case .watercolor: return max(16.0, baseWidth * 4.0)
        case .highlighter: return max(14.0, baseWidth * 3.5)
        case .crayon: return max(6.0, baseWidth * 1.8)
        case .calligraphy: return max(8.0, baseWidth * 2.2)
        case .paint: return max(24.0, baseWidth * 8.0)
        }
    }

    public static func brushDiameter(tool: ToolType, baseWidth: Double, zoom: Double, kind: BrushKind? = nil) -> Double {
        if let kind = kind {
            return brushStrokeWidth(kind: kind, baseWidth: baseWidth) * zoom
        }
        return strokeWidth(tool: tool, baseWidth: baseWidth) * zoom
    }

    public static func eraserWorldRadius(screenDiameter: Double, zoom: Double) -> Double {
        screenDiameter / (2 * zoom)
    }
}
