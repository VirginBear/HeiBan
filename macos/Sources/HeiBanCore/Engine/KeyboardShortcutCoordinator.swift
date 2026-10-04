import Foundation

public enum ShortcutAction: Equatable {
    case newBoard
    case openBoard
    case save
    case saveAs
    case undo
    case redo
    case copy
    case cut
    case paste
    case selectAll
    case duplicate
    case delete
    case group
    case ungroup
    case escape
    case spaceDown
    case spaceUp
    case switchTool(ToolType)
    case toggleInspector
    case toggleLayerPanel
}

public struct InputDeviceCapability: Equatable, Identifiable {
    public var id: String { deviceType }
    public var deviceType: String
    public var isSupported: Bool
    public var features: [String]
    public var notes: String

    public init(deviceType: String, isSupported: Bool, features: [String], notes: String) {
        self.deviceType = deviceType
        self.isSupported = isSupported
        self.features = features
        self.notes = notes
    }
}

public final class KeyboardShortcutCoordinator {
    public static let shared = KeyboardShortcutCoordinator()

    public static let supportedDevices: [InputDeviceCapability] = [
        InputDeviceCapability(
            deviceType: "macOS Trackpad (內建/巧控板)",
            isSupported: true,
            features: ["兩指平移", "雙指縮放 (Pinch-to-zoom)", "震動反饋 (Haptic Feedback)", "智慧縮放雙擊"],
            notes: "完全原生支援，幾何縮放以游標為錨點零漂移"
        ),
        InputDeviceCapability(
            deviceType: "標準滑鼠 (Magic Mouse / 三鍵滾輪滑鼠)",
            isSupported: true,
            features: ["滾輪縮放 (Option+滾輪/直接滾輪)", "按住空白鍵拖曳畫布", "左鍵選取/繪製", "右鍵上下文選單"],
            notes: "完全支援無障礙操作"
        ),
        InputDeviceCapability(
            deviceType: "專業繪圖板 (Wacom / Huion / XP-Pen)",
            isSupported: true,
            features: ["筆尖壓力感應 (0.0 ~ 1.0)", "筆桿按鈕右鍵/橡皮擦映射", "懸停指標 (Hover Preview)"],
            notes: "透過 NSEvent.pressure 讀取原生連續筆壓"
        ),
        InputDeviceCapability(
            deviceType: "遠端桌面 / 觸控螢幕輸入",
            isSupported: true,
            features: ["單點觸控等同左鍵", "長按呼叫上下文選單", "無壓感平滑 Catmull-Rom 插值補償"],
            notes: "即使無壓感亦具備擬真粉筆與平滑筆劃渲染"
        )
    ]

    public static func resolveKeyAction(
        characters: String?,
        keyCode: UInt16,
        isCommand: Bool,
        isShift: Bool,
        isOption: Bool,
        isTextEditing: Bool,
        hasMarkedText: Bool
    ) -> ShortcutAction? {
        // A25 規範：文字編輯或輸入法組字中（IME composition）時，絕對不搶佔任何按鍵！
        if isTextEditing || hasMarkedText {
            // 僅允許特定控制鍵退出或換行
            if keyCode == 53 && !hasMarkedText { // Esc
                return .escape
            }
            return nil
        }

        // 1. 空白鍵平移 (Space: keyCode 49)
        if keyCode == 49 && !isCommand && !isOption {
            return .spaceDown
        }

        // 2. Esc (keyCode 53)
        if keyCode == 53 {
            return .escape
        }

        // 3. Delete / Backspace (keyCode 51, 117)
        if (keyCode == 51 || keyCode == 117) && !isCommand {
            return .delete
        }

        // 4. Command 組合鍵
        if isCommand {
            guard let char = characters?.lowercased().first else { return nil }
            switch char {
            case "n": return .newBoard
            case "o": return .openBoard
            case "s": return isShift ? .saveAs : .save
            case "z": return isShift ? .redo : .undo
            case "c": return .copy
            case "x": return .cut
            case "v": return .paste
            case "a": return .selectAll
            case "d": return .duplicate
            case "g": return isShift ? .ungroup : .group
            default: break
            }
        }

        // 5. 單鍵工具快捷鍵 (無 Command、無 Option)
        if !isCommand && !isOption && !isShift {
            guard let char = characters?.lowercased().first else { return nil }
            switch char {
            case "v": return .switchTool(.select)
            case "p": return .switchTool(.pen)
            case "h": return .switchTool(.highlighter)
            case "b": return .switchTool(.paint)
            case "e": return .switchTool(.eraser)
            case "r": return .switchTool(.rect)
            case "c": return .switchTool(.circle)
            case "l": return .switchTool(.line)
            case "a": return .switchTool(.arrow)
            case "t": return .switchTool(.text)
            case "s": return .switchTool(.sticky)
            case "i": return .toggleInspector
            case "m": return .toggleLayerPanel
            default: break
            }
        }

        return nil
    }
}
