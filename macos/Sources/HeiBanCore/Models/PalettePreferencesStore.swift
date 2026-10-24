import Foundation

public struct PalettePreferences: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var colors: [String] = []
    public var extraFields: [String: AnyCodableValue]?

    public init(schemaVersion: Int = 1, colors: [String] = [], extraFields: [String: AnyCodableValue]? = nil) {
        self.schemaVersion = schemaVersion
        self.colors = colors
        self.extraFields = extraFields
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, colors
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        colors = try c.decodeIfPresent([String].self, forKey: .colors) ?? []
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)
        let known = Set(CodingKeys.allCases.map(\.stringValue))
        var extras: [String: AnyCodableValue] = [:]
        for key in dynamic.allKeys where !known.contains(key.stringValue) {
            extras[key.stringValue] = try dynamic.decode(AnyCodableValue.self, forKey: key)
        }
        extraFields = extras.isEmpty ? nil : extras
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(colors, forKey: .colors)
        var dynamic = encoder.container(keyedBy: AnyCodingKey.self)
        let known = Set(CodingKeys.allCases.map(\.stringValue))
        for (key, value) in extraFields ?? [:] where !known.contains(key) {
            try dynamic.encode(value, forKey: AnyCodingKey(stringValue: key)!)
        }
    }
}

/// 跨一般畫布與螢幕畫布共用的常用色盤存儲；原子寫入 Settings/palette.json。
public final class PalettePreferencesStore: ObservableObject {
    public static let defaultColors: [String] = [
        "#86EFAC", "#FEF08A", "#93C5FD", "#FFFFFF", "#F472B6", "#FB923C", "#C084FC", "#24533D"
    ]

    @Published public private(set) var colors: [String] = defaultColors
    public private(set) var loadFailed: Bool = false
    public private(set) var fileURL: URL

    private var preferences: PalettePreferences = PalettePreferences(colors: defaultColors)
    private let queue = DispatchQueue(label: "com.heiban.palettePreferences", qos: .utility)

    public static let shared = PalettePreferencesStore()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = ProcessInfo.processInfo.environment["HEIBAN_DATA_DIRECTORY"]
                .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
                ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("HeiBan", isDirectory: true)
            self.fileURL = base.appendingPathComponent("Settings/palette.json")
        }
        load()
    }

    public static func canonical(_ color: String?) -> String? {
        guard let color = color?.trimmingCharacters(in: .whitespacesAndNewlines),
              color.hasPrefix("#") else { return nil }
        let hex = color.dropFirst()
        guard hex.count == 6 || hex.count == 8, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        let upper = color.uppercased()
        if upper.count == 9 && upper.hasSuffix("FF") {
            return String(upper.prefix(7))
        }
        return upper
    }

    public func reload() {
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.colors = Self.defaultColors
            self.preferences = PalettePreferences(colors: Self.defaultColors)
            self.loadFailed = false
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(PalettePreferences.self, from: data)
            guard decoded.schemaVersion == 1 else {
                throw CocoaError(.coderReadCorrupt)
            }
            var seen = Set<String>()
            var clean: [String] = []
            for c in decoded.colors {
                if let canon = Self.canonical(c), seen.insert(canon).inserted {
                    clean.append(canon)
                }
            }
            self.preferences = decoded
            self.preferences.colors = clean
            self.colors = clean
            self.loadFailed = false
        } catch {
            self.loadFailed = true
        }
    }

    @discardableResult
    public func add(_ color: String) -> Bool {
        guard !loadFailed, let canon = Self.canonical(color) else { return false }
        if colors.contains(canon) { return false }
        var next = colors
        next.append(canon)
        return persist(next)
    }

    @discardableResult
    public func remove(_ color: String) -> Bool {
        guard !loadFailed else { return false }
        let target = Self.canonical(color) ?? color.uppercased()
        var next = colors
        guard let idx = next.firstIndex(of: target) else { return false }
        next.remove(at: idx)
        return persist(next)
    }

    @discardableResult
    public func reset() -> Bool {
        guard !loadFailed else { return false }
        return persist(Self.defaultColors)
    }

    private func persist(_ newColors: [String]) -> Bool {
        var nextPrefs = preferences
        nextPrefs.colors = newColors
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(nextPrefs)
            try data.write(to: fileURL, options: .atomic)
            self.preferences = nextPrefs
            self.colors = newColors
            NotificationCenter.default.post(name: Notification.Name("HeiBan.palettePreferencesChanged"), object: self)
            return true
        } catch {
            return false
        }
    }
}
