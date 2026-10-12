import Foundation
import SwiftUI

/// 只翻譯 UI 字串；作品文字、名稱、內部工具 ID 與世界座標一律保留原值。
/// 各視圖訂閱此單一低頻偏好來源，切換語言不重建 BoardEngine 或清掉草稿。
final class L10n: ObservableObject {
    static let shared = L10n()
    static let languages: [(code: String, name: String)] = [
        ("zh-TW", "正體中文"), ("zh-CN", "简体中文"), ("en", "English"),
        ("ja", "日本語"), ("ko", "한국어"), ("es", "Español"), ("fr", "Français"),
        ("de", "Deutsch"), ("pt-BR", "Português (Brasil)"), ("ar", "العربية")
    ]
    @Published private(set) var code: String
    private var catalogs: [String: [String: String]] = [:]
    var locale: Locale { Locale(identifier: code) }
    var direction: LayoutDirection { code == "ar" ? .rightToLeft : .leftToRight }
    private init() {
        let saved = UserDefaults.standard.string(forKey: "HeiBan.language") ?? "zh-TW"
        code = Self.languages.contains(where: { $0.code == saved }) ? saved : "zh-TW"
    }
    func select(_ value: String) {
        guard Self.languages.contains(where: { $0.code == value }), code != value else { return }
        UserDefaults.standard.set(value, forKey: "HeiBan.language")
        code = value
    }
    static func t(_ source: String) -> String { shared.translate(source) }
    private func translate(_ source: String) -> String {
        if code == "zh-TW" { return source }
        if catalogs[code] == nil {
            let url = Bundle.module.url(forResource: code, withExtension: "json", subdirectory: "Localization")
            catalogs[code] = url.flatMap { try? Data(contentsOf: $0) }
                .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        }
        return catalogs[code]?[source] ?? source
    }
}
