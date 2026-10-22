import Combine
import Foundation

/// 指標只發布此渲染預覽，永久物件／文件／Undo在放開以前完全不變。
public final class CircularEraserState: ObservableObject {
    @Published public internal(set) var previewObjects: [BoardObject]?
    var original: [BoardObject]?
    var boardID: String?
    var pageID: String?
    var revision: UInt64?
    var lastScreenPoint: Point?
    public init() {}
}
