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

    public static let allDefinitions: [ToolbarItemDefinition] = [
        ToolbarItemDefinition(id: "select", displayName: "選取 / 導航", icon: "cursorarrow", isEssential: true),
        ToolbarItemDefinition(id: "pen", displayName: "鋼筆 / 向量筆", icon: "pencil"),
        ToolbarItemDefinition(id: "curve", displayName: "曲線筆", icon: "point.topleft.down.to.point.bottomright.curvepath"),
        ToolbarItemDefinition(id: "highlighter", displayName: "螢光筆", icon: "highlighter"),
        ToolbarItemDefinition(id: "paint", displayName: "油漆筆刷", icon: "paintbrush.pointed.fill"),
        ToolbarItemDefinition(id: "eraser", displayName: "橡皮擦", icon: "eraser.fill"),
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
        ToolbarItemDefinition(id: "lineExtension", displayName: "射線延伸", icon: "arrow.left.and.right"),
        ToolbarItemDefinition(id: "undoRedo", displayName: "復原 / 重做", icon: "arrow.uturn.backward"),
        ToolbarItemDefinition(id: "dock", displayName: "停靠位置", icon: "rectangle.3.group"),
        ToolbarItemDefinition(id: "clearAll", displayName: "清空黑板", icon: "trash")
    ]

    public static let defaultActiveItemIds: [String] = allDefinitions.map(\.id)

    public init(activeItemIds: [String]? = nil, hiddenItemIds: [String]? = nil) {
        self.activeItemIds = activeItemIds ?? Self.defaultActiveItemIds
        self.hiddenItemIds = hiddenItemIds ?? []
    }

    public var visibleItemIds: [String] {
        activeItemIds.filter { !hiddenItemIds.contains($0) }
    }

    public var hiddenItems: [ToolbarItemDefinition] {
        hiddenItemIds.compactMap { id in Self.allDefinitions.first { $0.id == id } }
    }

    public mutating func resetToDefaults() {
        activeItemIds = Self.defaultActiveItemIds
        hiddenItemIds = []
    }

    public mutating func setItemHidden(id: String, hidden: Bool) {
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
        guard sourceIndex >= 0, sourceIndex < activeItemIds.count,
              destinationIndex >= 0, destinationIndex < activeItemIds.count,
              sourceIndex != destinationIndex else { return }
        let item = activeItemIds.remove(at: sourceIndex)
        activeItemIds.insert(item, at: destinationIndex)
    }

    public mutating func moveItem(id: String, to destinationIndex: Int) {
        guard let sourceIndex = activeItemIds.firstIndex(of: id) else { return }
        moveItem(from: sourceIndex, to: destinationIndex)
    }
}
