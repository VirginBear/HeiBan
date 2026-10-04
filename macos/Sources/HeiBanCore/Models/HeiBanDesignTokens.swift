import Foundation

public struct HeiBanDesignTokens {
    // Spacing scale (Apple HIG)
    public static let spacingXXS: Double = 2.0
    public static let spacingXS: Double = 4.0
    public static let spacingSM: Double = 8.0
    public static let spacingMD: Double = 12.0
    public static let spacingLG: Double = 16.0
    public static let spacingXL: Double = 24.0

    // Corner radii
    public static let radiusSM: Double = 6.0
    public static let radiusMD: Double = 10.0
    public static let radiusLG: Double = 14.0
    public static let radiusPill: Double = 999.0

    // Theme color constants
    public static let blackboardBackground: String = "#172e25"
    public static let blackboardPrimaryText: String = "#f1f5f9"
    public static let blackboardSecondaryText: String = "#94a3b8"

    public static let whiteboardBackground: String = "#f8fafc"
    public static let whiteboardPrimaryText: String = "#0f172a"
    public static let whiteboardSecondaryText: String = "#64748b"

    public static let accentColor: String = "#22c55e"
    public static let destructiveColor: String = "#ef4444"

    // WCAG 2.1 Contrast Ratio Calculator
    public static func contrastRatio(_ hex1: String, _ hex2: String) -> Double {
        let l1 = relativeLuminance(from: hex1)
        let l2 = relativeLuminance(from: hex2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(from hex: String) -> Double {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        guard cleanHex.count == 6, let rgb = UInt64(cleanHex, radix: 16) else { return 0.0 }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        func linearize(_ c: Double) -> Double {
            if c <= 0.04045 {
                return c / 12.92
            } else {
                return pow((c + 0.055) / 1.055, 2.4)
            }
        }

        let rLin = linearize(r)
        let gLin = linearize(g)
        let bLin = linearize(b)

        return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
    }
}
