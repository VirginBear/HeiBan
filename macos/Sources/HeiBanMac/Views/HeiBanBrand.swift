import SwiftUI
import AppKit

enum HeiBanBrand {
    static let logo = NSImage(contentsOf: Bundle.module.url(forResource: "HeiBanLogo", withExtension: "png")!)!
    static let appIcon = NSImage(contentsOf: Bundle.module.url(forResource: "HeiBanAppIcon", withExtension: "png")!)!
}

struct HeiBanLogo: View {
    var body: some View {
        Image(nsImage: HeiBanBrand.logo)
            .resizable().interpolation(.high).scaledToFit()
            .accessibilityLabel("黑板：手寫筆記 Logo")
    }
}
