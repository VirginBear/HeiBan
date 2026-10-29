import SwiftUI
import HeiBanCore

extension Color {
    init(hex: String) {
        let components = HexColorComponents(hex: hex) ?? HexColorComponents(hex: "#86EFAC")!
        self.init(.sRGB, red: components.red, green: components.green,
                  blue: components.blue, opacity: components.alpha)
    }
}

func dashPattern(for style: String?, zoom: Double) -> [CGFloat] {
    let unit = CGFloat(zoom)
    switch style ?? "solid" {
    case "dashed": return [8 * unit, 6 * unit]
    case "dotted": return [1.5 * unit, 5 * unit]
    case "dashDot": return [8 * unit, 4 * unit, 1.5 * unit, 4 * unit]
    default: return []
    }
}
