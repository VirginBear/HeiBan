import CoreGraphics
import Foundation

/// 操作契約；座標為畫布／螢幕時由各欄位與呼叫點明確說明。
public enum LineEndpoint: String, Equatable {
    case start
    case end
}

public struct LineEndpointPreview: Equatable {
    public var objectID: String
    public var endpoint: LineEndpoint
    public var point: Point

    public init(objectID: String, endpoint: LineEndpoint, point: Point) {
        self.objectID = objectID
        self.endpoint = endpoint
        self.point = point
    }
}

public struct ToolStylePreset: Codable, Equatable {
    public var color: String
    public var strokeWidth: Double
    public var opacity: Double

    public init(color: String, strokeWidth: Double, opacity: Double) {
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
    }
}

public enum SubmenuDirection: String, Equatable {
    case leading
    case trailing
    case top
    case bottom
}

public enum ScreenCaptureMode: Equatable {
    case region
    case display(index: Int)
}

/// 單一工具設定呈現請求，不寫入作品或Undo。宿主只建立一個popover錨點。
public enum BoardToolSettings: String, Identifiable {
    case color, shapes, eraser, laser, ruler
    public var id: String { rawValue }
}
