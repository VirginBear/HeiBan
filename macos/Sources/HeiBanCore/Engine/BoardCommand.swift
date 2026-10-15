import Foundation

/// Represents an atomic, reversible editing transaction command (A04 & A24).
public enum BoardCommand: Equatable {
    /// Insertion of one or more objects (e.g. stroke completed, shape/sticky/text added)
    case insertObjects([BoardObject])
    /// Removal of one or more objects (e.g. eraser swipe completed, delete key)
    case removeObjects([BoardObject])
    /// In-place modification of objects (transform/move, style change, text edit, lock, visibility, rename)
    case modifyObjects(before: [BoardObject], after: [BoardObject])
    /// Snapshot replacement for one board-eraser gesture; preserves legacy page IDs and metadata.
    case replaceObjects(before: [BoardObject], after: [BoardObject])
    /// Layer reordering (bring forward/backward, bring to front/back, drag reorder)
    case reorderObjects(before: [BoardObject], after: [BoardObject])
    /// Canvas metadata change (title, theme, background, grid style)
    case updateCanvas(before: BoardMetadata, after: BoardMetadata)
    /// Bookmark pins update (add, remove, rename pin)
    case updatePins(before: [BoardPin]?, after: [BoardPin]?)
    /// Complete canvas clear
    case clearCanvas(clearedObjects: [BoardObject])
    /// Group of multiple commands executed as a single atomic transaction
    case composite([BoardCommand])
}

/// Bounded-memory transaction manager for Undo / Redo history.
public final class TransactionManager {
    public let maxCapacity: Int
    public private(set) var undoStack: [BoardCommand] = []
    public private(set) var redoStack: [BoardCommand] = []

    public init(maxCapacity: Int = 50) {
        self.maxCapacity = max(1, maxCapacity)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func push(_ command: BoardCommand) {
        undoStack.append(command)
        redoStack.removeAll(keepingCapacity: true)
        if undoStack.count > maxCapacity {
            undoStack.removeFirst(undoStack.count - maxCapacity)
        }
    }

    public func popUndo() -> BoardCommand? {
        guard let command = undoStack.popLast() else { return nil }
        redoStack.append(command)
        return command
    }

    public func popRedo() -> BoardCommand? {
        guard let command = redoStack.popLast() else { return nil }
        undoStack.append(command)
        return command
    }

    public func clear() {
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
    }
}
