import Foundation

public enum CanvasHUDFormatter {
    public static func formatDimensions(width: Double, height: Double) -> String {
        let w = max(1, Int(round(width)))
        let h = max(1, Int(round(height)))
        return "\(w) × \(h) pt"
    }

    public static func formatRotation(degrees: Double) -> String {
        var normalized = degrees.truncatingRemainder(dividingBy: 360.0)
        if normalized < 0 { normalized += 360.0 }
        return String(format: "%.1f°", normalized)
    }

    public static func formatLength(length: Double) -> String {
        return "L: \(Int(round(length))) pt"
    }
}

public enum PinSearchFilter {
    public static func filter(pins: [BoardPin], query: String) -> [BoardPin] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pins }
        return pins.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
