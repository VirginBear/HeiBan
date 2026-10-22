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
}
