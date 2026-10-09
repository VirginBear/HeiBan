import SwiftUI
import AppKit

/// AppKit extracts the first image/text from Menu labels. A cached composite image
/// preserves the complete layout, including the trailing disclosure and its gap.
struct MenuDisclosureLabel<Content: View>: View {
    let accessibilityName: String
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    init(_ accessibilityName: String, @ViewBuilder content: @escaping () -> Content) {
        self.accessibilityName = accessibilityName
        self.content = content
    }

    var body: some View {
        let label = HStack(spacing: 8) {
            content()
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14, height: 18)
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 4)
        .frame(minHeight: 28)
        .fixedSize(horizontal: true, vertical: true)
        Image(nsImage: MenuLabelImageCache.image(name: accessibilityName, scheme: colorScheme,
                                                scale: displayScale, content: label))
            .renderingMode(.original)
            .accessibilityLabel(accessibilityName)
    }
}

@MainActor
private enum MenuLabelImageCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let result = NSCache<NSString, NSImage>()
        result.countLimit = 128
        return result
    }()

    static func image<Content: View>(name: String, scheme: ColorScheme, scale: CGFloat, content: Content) -> NSImage {
        let key = "\(name)|\(scheme)|\(scale)" as NSString
        if let existing = cache.object(forKey: key) { return existing }
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, scheme))
        renderer.scale = scale
        let image = renderer.nsImage ?? NSImage(size: CGSize(width: 40, height: 28))
        image.accessibilityDescription = name
        cache.setObject(image, forKey: key)
        return image
    }
}
