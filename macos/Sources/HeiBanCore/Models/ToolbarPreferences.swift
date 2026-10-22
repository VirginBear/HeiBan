import Foundation

public struct ToolbarItemDefinition: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let icon: String
    public let isEssential: Bool

    public init(id: String, displayName: String, icon: String, isEssential: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
        self.isEssential = isEssential
    }
}

public struct ToolbarPreferences: Codable, Equatable, Sendable {
    public var activeItemIds: [String]
    public var hiddenItemIds: [String]
    public var displayMode: String = "labels"
    public var magnetEnabled: Bool = false
    public var boardEraserVisible: Bool = true
    public var commonItemIds: [String] = Self.defaultCommonItemIds
    public var defaultToolsRevision: Int = 0
    public var defaultPresentationRevision: Int = 0
    public var defaultCommonRevision: Int = 0

    public var extraFields: [String: AnyCodableValue]?

    public static let defaultCommonItemIds: [String] = [
        "pen", "highlighter", "eraser", "color", "lineStyle", "undoRedo", "magnet", "clearAll",
    ]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case activeItemIds, hiddenItemIds, displayMode, magnetEnabled, boardEraserVisible, commonItemIds
        case defaultToolsRevision, defaultPresentationRevision, defaultCommonRevision
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activeItemIds =
            try c.decodeIfPresent([String].self, forKey: .activeItemIds) ?? Self.allItemIds
        hiddenItemIds = try c.decodeIfPresent([String].self, forKey: .hiddenItemIds) ?? []
        displayMode = try c.decodeIfPresent(String.self, forKey: .displayMode) ?? "labels"
        magnetEnabled = try c.decodeIfPresent(Bool.self, forKey: .magnetEnabled) ?? false
        boardEraserVisible = try c.decodeIfPresent(Bool.self, forKey: .boardEraserVisible) ?? true
        commonItemIds =
            try c.decodeIfPresent([String].self, forKey: .commonItemIds) ?? Self.defaultCommonItemIds
        defaultToolsRevision = try c.decodeIfPresent(Int.self, forKey: .defaultToolsRevision) ?? 0
        defaultPresentationRevision =
            try c.decodeIfPresent(Int.self, forKey: .defaultPresentationRevision) ?? 0
        defaultCommonRevision = try c.decodeIfPresent(Int.self, forKey: .defaultCommonRevision) ?? 0
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)
        let known = Set(CodingKeys.allCases.map(\.stringValue))
        var extras: [String: AnyCodableValue] = [:]
        for key in dynamic.allKeys where !known.contains(key.stringValue) {
            extras[key.stringValue] = try dynamic.decode(AnyCodableValue.self, forKey: key)
        }
        extraFields = extras.isEmpty ? nil : extras
        normalize()
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(activeItemIds, forKey: .activeItemIds)
        try c.encode(hiddenItemIds, forKey: .hiddenItemIds)
        try c.encode(displayMode, forKey: .displayMode)
        try c.encode(magnetEnabled, forKey: .magnetEnabled)
        try c.encode(boardEraserVisible, forKey: .boardEraserVisible)
        try c.encode(commonItemIds, forKey: .commonItemIds)
        try c.encode(defaultToolsRevision, forKey: .defaultToolsRevision)
        try c.encode(defaultPresentationRevision, forKey: .defaultPresentationRevision)
        try c.encode(defaultCommonRevision, forKey: .defaultCommonRevision)
        var dynamic = encoder.container(keyedBy: AnyCodingKey.self)
        let known = Set(CodingKeys.allCases.map(\.stringValue))
        for (key, value) in extraFields ?? [:] where !known.contains(key) {
            try dynamic.encode(value, forKey: AnyCodingKey(stringValue: key)!)
        }
    }

    public static let streamlinedItemIds: [String] = [
        "select", "pen", "highlighter", "eraser", "ruler", "shapes", "magnet", "layers", "undoRedo",
    ]

    public static let allDefinitions: [ToolbarItemDefinition] = [
        ToolbarItemDefinition(id: "select", displayName: "選取 / 導航", icon: "cursorarrow", isEssential: true),
        ToolbarItemDefinition(id: "pen", displayName: "鋼筆 / 向量筆", icon: "pencil"),
        ToolbarItemDefinition(
            id: "curve", displayName: "曲線筆", icon: "point.topleft.down.to.point.bottomright.curvepath"),
        ToolbarItemDefinition(id: "highlighter", displayName: "螢光筆", icon: "highlighter"),
        ToolbarItemDefinition(id: "paint", displayName: "油漆筆刷", icon: "paintbrush.pointed.fill"),
        ToolbarItemDefinition(id: "eraser", displayName: "橡皮擦", icon: "eraser.fill"),
        ToolbarItemDefinition(id: "boardEraser", displayName: "板擦", icon: "eraser"),
        ToolbarItemDefinition(id: "ruler", displayName: "螢幕尺", icon: "ruler.fill"),
        ToolbarItemDefinition(id: "shapes", displayName: "幾何圖形", icon: "square.on.circle"),
        ToolbarItemDefinition(id: "sticky", displayName: "便條紙", icon: "note.text"),
        ToolbarItemDefinition(id: "text", displayName: "文字", icon: "textformat"),
        ToolbarItemDefinition(id: "laser", displayName: "雷射筆", icon: "rays"),
        ToolbarItemDefinition(id: "tape", displayName: "遮題膠帶", icon: "eye.slash"),
        ToolbarItemDefinition(id: "lasso", displayName: "套索工具", icon: "lasso"),
        ToolbarItemDefinition(id: "screenshot", displayName: "截圖置入", icon: "camera.viewfinder"),
        ToolbarItemDefinition(id: "image", displayName: "圖片匯入", icon: "photo.badge.plus"),
        ToolbarItemDefinition(id: "color", displayName: "筆刷設定", icon: "circle.fill"),
        ToolbarItemDefinition(id: "lineStyle", displayName: "實線 / 虛線", icon: "minus"),
        ToolbarItemDefinition(id: "magnet", displayName: "磁鐵", icon: "dot.squareshape.split.2x2"),
        ToolbarItemDefinition(id: "layers", displayName: "物件圖層", icon: "square.3.layers.3d"),
        ToolbarItemDefinition(id: "pins", displayName: "圖釘", icon: "pin.fill"),
        ToolbarItemDefinition(id: "compass", displayName: "圓規", icon: "circle.circle"),
        ToolbarItemDefinition(id: "calculator", displayName: "計算機", icon: "plus.forwardslash.minus"),
        ToolbarItemDefinition(id: "timer", displayName: "計時器", icon: "timer"),
        ToolbarItemDefinition(id: "undoRedo", displayName: "復原 / 重做", icon: "arrow.uturn.backward"),
        ToolbarItemDefinition(id: "dock", displayName: "停靠位置", icon: "rectangle.3.group"),
        ToolbarItemDefinition(id: "viewLock", displayName: "鎖定視角", icon: "lock.fill"),
        ToolbarItemDefinition(id: "clearAll", displayName: "清空黑板", icon: "trash"),
    ]

    public static let allItemIds: [String] = allDefinitions.map(\.id)
    public static let defaultActiveItemIds: [String] = allItemIds

    public static func createDefault() -> ToolbarPreferences {
        var prefs = ToolbarPreferences(
            activeItemIds: allItemIds,
            hiddenItemIds: []
        )
        prefs.displayMode = "labels"
        prefs.commonItemIds = defaultCommonItemIds
        prefs.defaultToolsRevision = 1
        prefs.defaultPresentationRevision = 1
        prefs.defaultCommonRevision = 1
        return prefs
    }

    public init(activeItemIds: [String]? = nil, hiddenItemIds: [String]? = nil) {
        if let activeItemIds = activeItemIds {
            self.activeItemIds = activeItemIds
            self.hiddenItemIds = hiddenItemIds ?? []
            self.defaultToolsRevision = 0
            self.defaultPresentationRevision = 0
            self.defaultCommonRevision = 0
        } else {
            self.activeItemIds = Self.allItemIds
            self.hiddenItemIds = hiddenItemIds ?? []
            self.displayMode = "labels"
            self.commonItemIds = Self.defaultCommonItemIds
            self.defaultToolsRevision = 1
            self.defaultPresentationRevision = 1
            self.defaultCommonRevision = 1
        }
    }

    public var visibleItemIds: [String] {
        activeItemIds.filter { !hiddenItemIds.contains($0) }
    }

    public var hiddenItems: [ToolbarItemDefinition] {
        hiddenItemIds.compactMap { id in Self.allDefinitions.first { $0.id == id } }
    }

    public mutating func normalize() {
        let discoverBoardEraser = !activeItemIds.contains("boardEraser") && !hiddenItemIds.contains("boardEraser")
        let allKnown = Set(Self.allDefinitions.map(\.id))
        var activeSeen = Set<String>()
        var hiddenSeen = Set<String>()

        // One-time discovery: 舊偏好若兩份清單皆缺 layers，補入可見列。使用者明確隱藏時維持隱藏。
        if !activeItemIds.contains("layers") && !hiddenItemIds.contains("layers") {
            activeItemIds.append("layers")
        }

        if !activeItemIds.contains("magnet") && !hiddenItemIds.contains("magnet") {
            activeItemIds.append("magnet")
        }
        hiddenItemIds.removeAll { $0 == "select" }
        activeItemIds.removeAll { $0 == "select" }
        activeItemIds.insert("select", at: 0)
        if displayMode != "labels" { displayMode = "icons" }
        var commonSeen = Set<String>()
        commonItemIds = commonItemIds.filter {
            allKnown.contains($0) && $0 != "select" && commonSeen.insert($0).inserted
        }
        activeItemIds = activeItemIds.filter { allKnown.contains($0) && activeSeen.insert($0).inserted }
        hiddenItemIds = hiddenItemIds.filter { allKnown.contains($0) && hiddenSeen.insert($0).inserted }

        // 其餘新增工具收納進 hiddenItemIds (更多)，避免破壞使用者既有配置
        for def in Self.allDefinitions {
            if def.id != "boardEraser", !activeSeen.contains(def.id) && !hiddenSeen.contains(def.id) {
                hiddenItemIds.append(def.id)
                hiddenSeen.insert(def.id)
            }
        }

        // Upgrade untouched earlier streamlined defaults once; preserve custom order or explicit hidden choices.
        if defaultToolsRevision < 1 {
            let expectedHidden = Set(Self.allItemIds.filter { $0 != "boardEraser" }).subtracting(Self.streamlinedItemIds)
            if activeItemIds == Self.streamlinedItemIds
                && hiddenItemIds.count == expectedHidden.count
                && Set(hiddenItemIds) == expectedHidden
            {
                activeItemIds = Self.allItemIds
                hiddenItemIds = []
            }
            defaultToolsRevision = 1
        }
        if defaultPresentationRevision < 1 {
            let oldCommon = ["pen", "highlighter", "eraser", "undoRedo", "magnet"]
            if commonItemIds == oldCommon {
                commonItemIds = Self.defaultCommonItemIds
                if displayMode == "icons" && activeItemIds == Self.allItemIds && hiddenItemIds.isEmpty {
                    displayMode = "labels"
                }
            }
            defaultPresentationRevision = 1
        }
        if defaultCommonRevision < 1 {
            if !commonItemIds.contains("clearAll") {
                commonItemIds.append("clearAll")
            }
            defaultCommonRevision = 1
        }
        // 首次提供板擦入口放在橡皮擦旁；日後明確隱藏仍尊重使用者設定。
        if discoverBoardEraser && !activeItemIds.contains("boardEraser") {
            activeItemIds.insert("boardEraser", at: (activeItemIds.firstIndex(of: "eraser") ?? 0) + 1)
        }
    }

    public mutating func resetToDefaults() {
        displayMode = "labels"
        magnetEnabled = false
        commonItemIds = Self.defaultCommonItemIds
        activeItemIds = Self.allItemIds
        hiddenItemIds = []
        defaultToolsRevision = 1
        defaultPresentationRevision = 1
        defaultCommonRevision = 1
    }

    public mutating func setItemHidden(id: String, hidden: Bool) {
        guard id != "select" else { return }
        if hidden {
            if !hiddenItemIds.contains(id) {
                hiddenItemIds.append(id)
            }
        } else {
            hiddenItemIds.removeAll { $0 == id }
            if !activeItemIds.contains(id) {
                activeItemIds.append(id)
            }
        }
    }

    public mutating func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex > 0, sourceIndex < activeItemIds.count,
            destinationIndex > 0, destinationIndex < activeItemIds.count,
            sourceIndex != destinationIndex
        else { return }
        let item = activeItemIds.remove(at: sourceIndex)
        activeItemIds.insert(item, at: destinationIndex)
    }

    public mutating func moveItem(id: String, to destinationIndex: Int) {
        guard id != "select", let sourceIndex = activeItemIds.firstIndex(of: id) else { return }
        let target = max(1, min(activeItemIds.count - 1, destinationIndex))
        moveItem(from: sourceIndex, to: target)
    }
}
