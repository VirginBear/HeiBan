import SwiftUI
import AppKit

enum HeiBanBrand {
    static let logo = NSImage(contentsOf: Bundle.module.url(forResource: "HeiBanLogo", withExtension: "png")!)!
    static let appIcon = NSImage(contentsOf: Bundle.module.url(forResource: "HeiBanAppIcon", withExtension: "png")!)!
}

struct HeiBanLogo: View {
    @ObservedObject private var language = L10n.shared
    var body: some View {
        Image(nsImage: HeiBanBrand.logo)
            .resizable().interpolation(.high).scaledToFit()
            .accessibilityLabel(L10n.t("黑板：手寫筆記 Logo"))
    }
}
