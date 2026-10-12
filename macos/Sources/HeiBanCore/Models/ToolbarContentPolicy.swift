import Foundation

/// 共用工具偏好；螢幕模式只排除視角導航及固定尾端命令，不覆寫使用者清單。
public enum ToolbarContentPolicy {
    public static func isAvailable(_ id: String, screen: Bool) -> Bool {
        !screen || !["pins", "viewLock", "clearAll"].contains(id)
    }
    public static func visibleIDs(_ preferences: ToolbarPreferences, screen: Bool) -> [String] {
        preferences.visibleItemIds.filter { isAvailable($0, screen: screen) }.flatMap { id in
            screen && id == "undoRedo" ? ["undo", "redo"] : [id]
        }
    }
    public static func screenItemCount(_ preferences: ToolbarPreferences) -> Int {
        visibleIDs(preferences, screen: true).count + 1 // 共用「更多」入口。
    }
}
