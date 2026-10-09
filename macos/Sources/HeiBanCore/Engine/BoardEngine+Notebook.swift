import CoreGraphics
import Foundation

/// 多頁規則集中於此：pageId 是文件資料，切頁不另建第二個作品引擎。
extension BoardEngine {
    // MARK: - Multi-page Notebook Support (多頁筆記本支援)
    public var isNotebook: Bool {
        board.canvasMode == .notebook
    }

    public var pages: [BoardPage] {
        get { board.pages ?? [] }
        set { board.pages = newValue }
    }

    public var activePageId: String? {
        get {
            guard isNotebook else { return nil }
            if let active = board.activePageId, pages.contains(where: { $0.id == active }) {
                return active
            }
            return pages.first?.id
        }
        set {
            board.activePageId = newValue
        }
    }

    public var currentPageIndex: Int {
        guard isNotebook, let activeId = activePageId else { return 0 }
        return pages.firstIndex(where: { $0.id == activeId }) ?? 0
    }

    public var totalPages: Int {
        guard isNotebook else { return 1 }
        return max(1, pages.count)
    }

    public func isObjectOnCurrentPage(_ object: BoardObject) -> Bool {
        guard isNotebook else { return true }
        guard let currentId = activePageId else { return true }
        if let pid = object.pageId {
            return pid == currentId
        } else {
            // Downward compatibility: objects without pageId belong to page 1
            return currentId == pages.first?.id
        }
    }

    public var currentPageObjects: [BoardObject] {
        guard isNotebook else { return objects }
        return objects.filter { isObjectOnCurrentPage($0) }
    }

    @discardableResult
    public func addPage(title: String? = nil) -> BoardPage {
        cancelTransientInteraction()
        selectedIds.removeAll()

        var currentPages = pages
        if currentPages.isEmpty {
            let p1 = BoardPage(id: UUID().uuidString, title: "第 1 頁", index: 0)
            currentPages.append(p1)
        }

        let newIndex = currentPages.count
        let rawTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageTitle = (rawTitle != nil && !rawTitle!.isEmpty) ? rawTitle! : "第 \(newIndex + 1) 頁"
        let newPage = BoardPage(id: UUID().uuidString, title: pageTitle, index: newIndex)
        currentPages.append(newPage)

        let beforeBoard = board
        var afterBoard = board
        afterBoard.pages = currentPages
        afterBoard.activePageId = newPage.id
        board = afterBoard

        transactionManager.push(.updateCanvas(before: beforeBoard, after: afterBoard))
        scheduleAutosave()
        showTemporaryStatus("已新增 \(newPage.title)")
        return newPage
    }

    @discardableResult
    public func deletePage(id: String) -> Bool {
        guard isNotebook else { return false }
        guard pages.count > 1 else {
            showTemporaryStatus("筆記本至少需保留一頁")
            return false
        }
        guard let pageIndex = pages.firstIndex(where: { $0.id == id }) else { return false }

        cancelTransientInteraction()
        selectedIds.removeAll()

        let beforeBoard = board
        let objectsToDelete = objects.filter { $0.pageId == id }

        var newPages = pages
        let deletedTitle = newPages[pageIndex].title
        newPages.remove(at: pageIndex)
        for i in newPages.indices {
            newPages[i].index = i
        }

        var afterBoard = board
        afterBoard.pages = newPages

        if activePageId == id {
            let nextIndex = min(pageIndex, newPages.count - 1)
            afterBoard.activePageId = newPages[nextIndex].id
        }

        if !objectsToDelete.isEmpty {
            let idsToDelete = Set(objectsToDelete.map(\.id))
            objects.removeAll { idsToDelete.contains($0.id) }
        }
        board = afterBoard

        if !objectsToDelete.isEmpty {
            transactionManager.push(
                .composite([
                    .removeObjects(objectsToDelete),
                    .updateCanvas(before: beforeBoard, after: afterBoard),
                ]))
        } else {
            transactionManager.push(.updateCanvas(before: beforeBoard, after: afterBoard))
        }

        scheduleAutosave()
        showTemporaryStatus("已刪除 \(deletedTitle)")
        return true
    }

    public func switchPage(to pageId: String) {
        guard isNotebook, activePageId != pageId else { return }
        guard pages.contains(where: { $0.id == pageId }) else { return }
        cancelTransientInteraction()
        selectedIds.removeAll()
        board.activePageId = pageId
    }

    public func goToNextPage() {
        guard isNotebook else { return }
        let nextIdx = currentPageIndex + 1
        guard nextIdx < pages.count else { return }
        switchPage(to: pages[nextIdx].id)
    }

    public func goToPreviousPage() {
        guard isNotebook else { return }
        let prevIdx = currentPageIndex - 1
        guard prevIdx >= 0 else { return }
        switchPage(to: pages[prevIdx].id)
    }
}
