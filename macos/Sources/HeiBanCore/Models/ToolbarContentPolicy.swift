import CoreGraphics
import Foundation

/// 共用工具偏好；螢幕模式只排除視角導航及固定尾端命令，不覆寫使用者清單。
public enum ToolbarContentPolicy {
    public static func isAvailable(_ id: String, screen: Bool) -> Bool {
        !screen || !["pins", "viewLock"].contains(id)
    }
    public static func visibleIDs(_ preferences: ToolbarPreferences, screen: Bool) -> [String] {
        preferences.visibleItemIds.filter { isAvailable($0, screen: screen) }.flatMap { id in
            screen && id == "undoRedo" ? ["undo", "redo"] : [id]
        }
    }
    public static let pages = ["common", "drawing", "insert", "organize"]
    public static let pageTitles = ["常用", "繪圖", "插入", "管理"]
    public static func page(for id: String) -> String {
        if [
            "pen", "curve", "highlighter", "paint", "eraser", "ruler", "shapes", "color", "lineStyle",
            "magnet", "compass", "laser",
        ].contains(id) {
            return "drawing"
        }
        if ["sticky", "text", "image", "screenshot", "tape", "calculator", "timer"].contains(id) {
            return "insert"
        }
        return "organize"
    }
    public static func pageIDs(_ preferences: ToolbarPreferences, screen: Bool, page: String) -> [String] {
        visibleIDs(preferences, screen: screen).filter { id in
            guard id != "select" else { return false }
            if page != "common" { return Self.page(for: id) == page }
            return preferences.commonItemIds.contains(id)
                || (["undo", "redo"].contains(id) && preferences.commonItemIds.contains("undoRedo"))
        }
    }
    public static func screenItemCount(_ preferences: ToolbarPreferences) -> Int {
        visibleIDs(preferences, screen: true).count + 1  // 共用「更多」入口。
    }

    /// 橫排每個工具磚寬度（含圖示與雙行文字），確保 12 個繪圖工具也能在一般電腦螢幕一列完整平鋪無捲軸。
    public static let horizontalTileWidth: CGFloat = 62
    public static let horizontalTileSpacing: CGFloat = 4
    public static let verticalTileHeight: CGFloat = 44
    public static let verticalTileSpacing: CGFloat = 3

    /// 計算指定分頁在單列平鋪時可容納的工具數（僅在極窄視窗才啟用換組箭頭，一般電腦視窗皆可全數平鋪）。
    public static func pageCapacity(
        itemCount: Int,
        availableLength: CGFloat,
        vertical: Bool
    ) -> Int {
        guard itemCount > 0 else { return 1 }
        let unit = vertical ? (verticalTileHeight + verticalTileSpacing) : (horizontalTileWidth + horizontalTileSpacing)
        let fullSpan = CGFloat(itemCount) * unit - (vertical ? verticalTileSpacing : horizontalTileSpacing)
        if fullSpan <= availableLength {
            return itemCount
        }
        // 當極窄視窗無法一次平鋪時，預留換組箭頭空間 (44pt)
        let pagedSpan = max(unit, availableLength - 44)
        return max(1, Int((pagedSpan + (vertical ? verticalTileSpacing : horizontalTileSpacing)) / unit))
    }

    /// 計算一般畫布工具列面板的緊湊自適應尺寸（消除右側多餘留白，並確保繪圖分頁完整平鋪）。
    public static func panelSize(
        preferences: ToolbarPreferences,
        page: String,
        vertical: Bool,
        windowSize: CGSize,
        screen: Bool = false
    ) -> CGSize {
        if preferences.displayMode == "labels" {
            let items = pageIDs(preferences, screen: screen, page: page)
            let count = max(1, items.count)
            if vertical {
                let maxPanelHeight = max(220, windowSize.height - 88)
                let fixedChrome: CGFloat = 148 // 握把 + 選取 + 分頁選單 + 更多 + 上下內距
                let availForTools = max(verticalTileHeight, maxPanelHeight - fixedChrome)
                let cap = pageCapacity(itemCount: count, availableLength: availForTools, vertical: true)
                let shownCount = min(count, cap)
                let needsPaging = cap < count
                let toolsHeight = CGFloat(shownCount) * verticalTileHeight
                    + CGFloat(max(0, shownCount - 1)) * verticalTileSpacing
                    + (needsPaging ? 44 : 0)
                let minTabsHeight: CGFloat = 140
                let totalHeight = min(maxPanelHeight, max(minTabsHeight, fixedChrome + toolsHeight))
                return CGSize(width: 148, height: totalHeight)
            } else {
                let maxPanelWidth = max(280, windowSize.width - 32)
                let fixedChrome: CGFloat = 136 // 握把(24) + 選取(44) + 更多(44) + 間距與左右內距(24)
                let availForTools = max(horizontalTileWidth, maxPanelWidth - fixedChrome)
                let cap = pageCapacity(itemCount: count, availableLength: availForTools, vertical: false)
                let shownCount = min(count, cap)
                let needsPaging = cap < count
                let toolsWidth = CGFloat(shownCount) * horizontalTileWidth
                    + CGFloat(max(0, shownCount - 1)) * horizontalTileSpacing
                    + (needsPaging ? 44 : 0)
                // 分頁標籤列（常用／繪圖／插入／管理）最小寬度約 220pt，確保切換到工具較少的分頁時標籤列也完整顯示
                let minBodyWidth: CGFloat = 236
                let totalWidth = min(maxPanelWidth, fixedChrome + max(minBodyWidth, toolsWidth))
                return CGSize(width: totalWidth, height: 108)
            }
        }

        let visibleCount = max(1, visibleIDs(preferences, screen: screen).count + 1)
        if vertical {
            let contentH = CGFloat(visibleCount) * 36 - 4
            return CGSize(width: 68, height: min(contentH + 48, max(120, windowSize.height - 88)))
        } else {
            let contentW = CGFloat(visibleCount) * 38 - 6
            return CGSize(width: min(contentW + 52, max(160, windowSize.width - 32)), height: 58)
        }
    }
}
