import AppKit

/// 普通 floating 層會被其他程式的工具／演示視窗蓋住。使用 statusBar 上一層，
/// 同時留在系統 popup menu 以下，讓控制列的選單與 popover 仍可正常顯示。
enum AnnotationWindowPolicy {
    static let canvasLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    static let controlsLevel = NSWindow.Level(rawValue: canvasLevel.rawValue + 1)
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary,
        .stationary, .ignoresCycle,
    ]
}
