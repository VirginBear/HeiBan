import SwiftUI
import AppKit

struct RulerAppearance: Equatable {
    let ink: String
    let body: String
    let badge: String

    init(backgroundColor: String, customInk: String? = nil) {
        let rgb = NSColor(Color(hex: backgroundColor)).usingColorSpace(.deviceRGB) ?? .black
        let light = rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114 > 0.5
        ink = customInk ?? (light ? "#263B32" : "#F1FAF5")
        body = light ? "#C3D7CC" : "#3C6250"
        badge = light ? "#F5FAF7" : "#172E25"
    }
}
