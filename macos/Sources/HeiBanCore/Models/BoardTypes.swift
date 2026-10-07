import Foundation
import CoreGraphics

public typealias ToolType = String
public extension ToolType {
    static let select = "select"
    static let pen = "pen"
    static let curve = "curve"
    static let highlighter = "highlighter"
    static let paint = "paint"
    static let eraser = "eraser"
    static let ruler = "ruler"
    static let rect = "rect"
    static let circle = "circle"
    static let triangle = "triangle"
    static let quadrilateral = "quadrilateral"
    static let diamond = "diamond"
    static let arrow = "arrow"
    static let line = "line"
    static let star = "star"
    static let text = "text"
    static let sticky = "sticky"
    static let image = "image"
    static let pin = "pin"
    static let laser = "laser"
}

public enum EraserMode: String, Codable, CaseIterable {
    case object = "object"
    case pixel = "pixel"
    case partial = "partial"

    public var isPartial: Bool {
        self == .pixel || self == .partial
    }
}

public enum BoardTheme: String, Codable, CaseIterable {
    case blackboard = "blackboard"
    case dark = "dark"
    case whiteboard = "whiteboard"
    case slate = "slate"

    public var defaultBackgroundColor: String {
        switch self {
        case .blackboard: return "#172e25"
        case .dark: return "#18181b"
        case .whiteboard: return "#ffffff"
        case .slate: return "#1e293b"
        }
    }

    public var displayName: String {
        switch self {
        case .blackboard: return "經典墨綠黑板"
        case .dark: return "極致炭黑"
        case .whiteboard: return "簡約純白板"
        case .slate: return "科技岩灰"
        }
    }
}

public enum GridStyle: String, Codable, CaseIterable {
    case grid = "grid"
    case dots = "dots"
    case lines = "lines"
    case staff = "staff"
    case blank = "blank"

    public var displayName: String {
        switch self {
        case .grid: return "網格線"
        case .dots: return "點陣網格"
        case .lines: return "橫線筆記"
        case .staff: return "五線譜"
        case .blank: return "純淨空白"
        }
    }
}

public enum CanvasMode: String, Codable, CaseIterable {
    case fixed = "fixed"
    case infinite = "infinite"
    case notebook = "notebook"
}

public enum CanvasPreset: String, Codable, CaseIterable {
    case infinite = "infinite"
    case a4_portrait = "a4_portrait"
    case a4_landscape = "a4_landscape"
    case a3_landscape = "a3_landscape"
    case sixteen_nine = "16_9"
    case four_three = "4_3"
    case one_one = "1_1"
    case nine_sixteen = "9_16"
    case b5 = "b5"
    case notebook = "notebook"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .infinite: return "無邊界畫布"
        case .a4_portrait: return "A4 直式 (595 × 842)"
        case .a4_landscape: return "A4 橫式 (842 × 595)"
        case .a3_landscape: return "A3 橫式 (1191 × 842)"
        case .sixteen_nine: return "16:9 簡報 (1920 × 1080)"
        case .four_three: return "4:3 課堂 (1440 × 1080)"
        case .one_one: return "1:1 正方形 (1080 × 1080)"
        case .nine_sixteen: return "9:16 手機/直式 (1080 × 1920)"
        case .b5: return "B5 筆記 (499 × 709)"
        case .notebook: return "多頁筆記本 (A4 分頁)"
        case .custom: return "自訂尺寸"
        }
    }

    public func defaultDimensions() -> (width: Double, height: Double)? {
        switch self {
        case .infinite:
            return nil
        case .a4_portrait, .notebook:
            return (width: 595.0, height: 842.0)
        case .a4_landscape:
            return (width: 842.0, height: 595.0)
        case .a3_landscape:
            return (width: 1191.0, height: 842.0)
        case .sixteen_nine:
            return (width: 1920.0, height: 1080.0)
        case .four_three:
            return (width: 1440.0, height: 1080.0)
        case .one_one:
            return (width: 1080.0, height: 1080.0)
        case .nine_sixteen:
            return (width: 1080.0, height: 1920.0)
        case .b5:
            return (width: 499.0, height: 709.0)
        case .custom:
            return (width: 1200.0, height: 800.0)
        }
    }

    public var dimensions: (width: Double, height: Double) {
        defaultDimensions() ?? (1920.0, 1080.0)
    }
}

public struct BoardPage: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var index: Int
    public var createdAt: String
    public var updatedAt: String

    public init(
        id: String = UUID().uuidString,
        title: String = "第 1 頁",
        index: Int = 0,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        updatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.title = title
        self.index = index
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum CanvasError: Error, LocalizedError, Equatable {
    case cannotDowngradeInfiniteCanvas
    case invalidFixedDimensions

    public var errorDescription: String? {
        switch self {
        case .cannotDowngradeInfiniteCanvas:
            return "禁止將無限畫布降級為固定畫布（A10 規範：避免內容被無形截斷）"
        case .invalidFixedDimensions:
            return "固定畫布尺寸無效，寬度與高度必須至少為 100 點"
        }
    }
}

public enum StickyStyle: String, Codable, CaseIterable {
    case classic = "classic"
    case washi = "washi"
    case cat = "cat"
    case notebook = "notebook"
    case grid = "grid"
    case soft = "soft"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "soft_card" || raw == "soft" {
            self = .soft
        } else if let val = StickyStyle(rawValue: raw) {
            self = val
        } else {
            self = .classic
        }
    }

    public var displayName: String {
        switch self {
        case .classic: return "經典折角"
        case .washi: return "和紙膠帶"
        case .cat: return "貓咪萌爪"
        case .notebook: return "活頁筆記"
        case .grid: return "方格幾何"
        case .soft: return "柔和卡片"
        }
    }
}

public struct StickyPalette {
    public static let yellow = "#fef08a"
    public static let pink = "#fbcfe8"
    public static let green = "#bbf7d0"
    public static let blue = "#bae6fd"
    public static let purple = "#e9d5ff"
    public static let orange = "#fed7aa"
    public static let allColors = [yellow, pink, green, blue, purple, orange]
}

public enum LineExtension: String, Codable, CaseIterable {
    case none = "none"
    case start = "start"
    case end = "end"
    case both = "both"

    public var displayName: String {
        switch self {
        case .none: return "線段"
        case .start: return "A 點延伸"
        case .end: return "B 點延伸"
        case .both: return "雙向延伸"
        }
    }
}

public enum PropertyValue<T: Equatable>: Equatable {
    case none
    case mixed
    case value(T)

    public var valueOrNil: T? {
        if case .value(let val) = self { return val }
        return nil
    }

    public var isMixed: Bool {
        if case .mixed = self { return true }
        return false
    }
}

public struct Point: Codable, Equatable, Hashable {
    public var x: Double
    public var y: Double
    public var pressure: Double?

    public init(x: Double, y: Double, pressure: Double? = nil) {
        self.x = x
        self.y = y
        self.pressure = pressure
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }

    public init(_ cgPoint: CGPoint, pressure: Double? = nil) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
        self.pressure = pressure
    }
}

private final class DecodedPointArray: NSObject {
    let values: [Point]
    init(_ values: [Point]) { self.values = values }
}

private enum BoardPointCache {
    static let storage: NSCache<NSString, DecodedPointArray> = {
        let cache = NSCache<NSString, DecodedPointArray>()
        cache.countLimit = 4096
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func points(id: String, updatedAt: String, json: String) -> [Point] {
        let key = "\(id):\(updatedAt):\(json.count):\(json.hashValue)" as NSString
        if let cached = storage.object(forKey: key) { return cached.values }
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([Point].self, from: data) else { return [] }
        storage.setObject(DecodedPointArray(values), forKey: key, cost: values.count * MemoryLayout<Point>.stride)
        return values
    }
}

public struct BoardPin: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var x: Double
    public var y: Double
    public var zoom: Double
    public var createdAt: String
    public var isWorldSpace: Bool?

    public init(
        id: String = UUID().uuidString,
        name: String,
        x: Double,
        y: Double,
        zoom: Double = 1.0,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        isWorldSpace: Bool? = true
    ) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.zoom = zoom
        self.createdAt = createdAt
        self.isWorldSpace = isWorldSpace
    }

    public func resolveWorldPosition(canvasSize: CGSize) -> Point {
        if isWorldSpace == true {
            return Point(x: x, y: y)
        }
        let screenCenterX = Double(canvasSize.width / 2)
        let screenCenterY = Double(canvasSize.height / 2)
        let worldX = (screenCenterX - x) / zoom
        let worldY = (screenCenterY - y) / zoom
        return Point(x: worldX, y: worldY)
    }
}

public struct AnyCodingKey: CodingKey, Hashable {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    public init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }
}

public struct TextSpan: Codable, Equatable, Hashable {
    public var text: String
    public var isBold: Bool?
    public var isItalic: Bool?
    public var isUnderline: Bool?
    public var isStrikethrough: Bool?
    public var color: String?
    public var highlightColor: String?

    public init(
        text: String,
        isBold: Bool? = nil,
        isItalic: Bool? = nil,
        isUnderline: Bool? = nil,
        isStrikethrough: Bool? = nil,
        color: String? = nil,
        highlightColor: String? = nil
    ) {
        self.text = text
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.color = color
        self.highlightColor = highlightColor
    }
}

public struct BoardObject: Codable, Identifiable, Equatable {
    public var id: String
    public var boardId: String
    public var type: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public var x1: Double?
    public var y1: Double?
    public var x2: Double?
    public var y2: Double?
    public var extensionMode: LineExtension?

    public var points: String?
    public var strokeColor: String
    public var fillColor: String
    public var fillOpacity: Double
    public var fillGradientStart: String?
    public var fillGradientEnd: String?
    public var strokeWidth: Double
    public var lineStyle: String? // "solid" | "dashed"
    public var arrowHeadLength: Double?
    public var arrowHeadWidth: Double?
    public var opacity: Double
    public var rotation: Double
    public var zIndex: Int

    public var text: String?
    public var fontSize: Double?
    public var fontFamily: String?
    public var stickyStyle: StickyStyle?
    public var isBold: Bool?
    public var isItalic: Bool?
    public var isUnderline: Bool?
    public var isStrikethrough: Bool?
    public var highlightColor: String?
    public var align: String?
    public var richTextSpans: [TextSpan]?

    public var imageUrl: String?
    public var originalImageUrl: String?
    public var originalWidth: Double?
    public var originalHeight: Double?
    public var cropX: Double?
    public var cropY: Double?
    public var cropWidth: Double?
    public var cropHeight: Double?

    public var isLocked: Bool?
    public var isVisible: Bool?
    public var name: String?
    public var groupId: String?
    public var createdBy: String
    public var creatorName: String?
    public var updatedAt: String
    public var pageId: String?
    public var extraFields: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, boardId, type, x, y, width, height
        case x1, y1, x2, y2
        case extensionMode = "extension"
        case points, strokeColor, fillColor, fillOpacity, fillGradientStart, fillGradientEnd, strokeWidth, lineStyle, arrowHeadLength, arrowHeadWidth, opacity, rotation, zIndex
        case text, fontSize, fontFamily, stickyStyle, isBold, isItalic, isUnderline, isStrikethrough, highlightColor, align
        case richTextSpans
        case imageUrl, originalImageUrl, originalWidth, originalHeight
        case cropX, cropY, cropWidth, cropHeight
        case isLocked, isVisible, name, groupId, createdBy, creatorName, updatedAt, pageId
    }

    public init(
        id: String = UUID().uuidString,
        boardId: String = "board_main",
        type: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        x1: Double? = nil,
        y1: Double? = nil,
        x2: Double? = nil,
        y2: Double? = nil,
        extensionMode: LineExtension? = nil,
        points: String? = nil,
        strokeColor: String = "#86efac",
        fillColor: String = "none",
        fillOpacity: Double = 1.0,
        fillGradientStart: String? = nil,
        fillGradientEnd: String? = nil,
        strokeWidth: Double = 3.0,
        lineStyle: String? = "solid",
        arrowHeadLength: Double? = nil,
        arrowHeadWidth: Double? = nil,
        opacity: Double = 1.0,
        rotation: Double = 0.0,
        zIndex: Int = 1,
        text: String? = nil,
        fontSize: Double? = nil,
        fontFamily: String? = nil,
        stickyStyle: StickyStyle? = nil,
        isBold: Bool? = nil,
        isItalic: Bool? = nil,
        isUnderline: Bool? = nil,
        isStrikethrough: Bool? = nil,
        highlightColor: String? = nil,
        align: String? = nil,
        richTextSpans: [TextSpan]? = nil,
        imageUrl: String? = nil,
        originalImageUrl: String? = nil,
        originalWidth: Double? = nil,
        originalHeight: Double? = nil,
        cropX: Double? = nil,
        cropY: Double? = nil,
        cropWidth: Double? = nil,
        cropHeight: Double? = nil,
        isLocked: Bool? = false,
        isVisible: Bool? = true,
        name: String? = nil,
        groupId: String? = nil,
        createdBy: String = "local_mac",
        creatorName: String? = "Mac 使用者",
        pageId: String? = nil,
        updatedAt: String = ISO8601DateFormatter().string(from: Date()),
        extraFields: [String: AnyCodableValue]? = nil
    ) {
        self.id = id
        self.boardId = boardId
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.extensionMode = extensionMode
        self.points = points
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.fillOpacity = fillOpacity
        self.fillGradientStart = fillGradientStart
        self.fillGradientEnd = fillGradientEnd
        self.strokeWidth = strokeWidth
        self.lineStyle = lineStyle
        self.arrowHeadLength = arrowHeadLength
        self.arrowHeadWidth = arrowHeadWidth
        self.opacity = opacity
        self.rotation = rotation
        self.zIndex = zIndex
        self.text = text
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.stickyStyle = stickyStyle
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.highlightColor = highlightColor
        self.align = align
        self.richTextSpans = richTextSpans
        self.imageUrl = imageUrl
        self.originalImageUrl = originalImageUrl
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.cropX = cropX
        self.cropY = cropY
        self.cropWidth = cropWidth
        self.cropHeight = cropHeight
        self.isLocked = isLocked
        self.isVisible = isVisible
        self.name = name
        self.groupId = groupId
        self.createdBy = createdBy
        self.creatorName = creatorName
        self.pageId = pageId
        self.updatedAt = updatedAt
        self.extraFields = extraFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.boardId = try container.decode(String.self, forKey: .boardId)
        self.type = try container.decode(String.self, forKey: .type)
        self.x = try container.decode(Double.self, forKey: .x)
        self.y = try container.decode(Double.self, forKey: .y)
        self.width = try container.decode(Double.self, forKey: .width)
        self.height = try container.decode(Double.self, forKey: .height)

        self.x1 = try container.decodeIfPresent(Double.self, forKey: .x1)
        self.y1 = try container.decodeIfPresent(Double.self, forKey: .y1)
        self.x2 = try container.decodeIfPresent(Double.self, forKey: .x2)
        self.y2 = try container.decodeIfPresent(Double.self, forKey: .y2)
        self.extensionMode = try container.decodeIfPresent(LineExtension.self, forKey: .extensionMode)

        self.points = try container.decodeIfPresent(String.self, forKey: .points)
        self.strokeColor = try container.decodeIfPresent(String.self, forKey: .strokeColor) ?? "#ffffff"
        self.fillColor = try container.decodeIfPresent(String.self, forKey: .fillColor) ?? "none"
        self.fillOpacity = try container.decodeIfPresent(Double.self, forKey: .fillOpacity) ?? 1.0
        self.fillGradientStart = try container.decodeIfPresent(String.self, forKey: .fillGradientStart)
        self.fillGradientEnd = try container.decodeIfPresent(String.self, forKey: .fillGradientEnd)
        self.strokeWidth = try container.decodeIfPresent(Double.self, forKey: .strokeWidth) ?? 2.0
        self.lineStyle = try container.decodeIfPresent(String.self, forKey: .lineStyle)
        self.arrowHeadLength = try container.decodeIfPresent(Double.self, forKey: .arrowHeadLength)
        self.arrowHeadWidth = try container.decodeIfPresent(Double.self, forKey: .arrowHeadWidth)
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        self.rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0.0
        self.zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0

        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize)
        self.fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily)
        self.stickyStyle = try container.decodeIfPresent(StickyStyle.self, forKey: .stickyStyle)
        self.isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold)
        self.isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic)
        self.isUnderline = try container.decodeIfPresent(Bool.self, forKey: .isUnderline)
        self.isStrikethrough = try container.decodeIfPresent(Bool.self, forKey: .isStrikethrough)
        self.highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
        self.align = try container.decodeIfPresent(String.self, forKey: .align)
        self.richTextSpans = try container.decodeIfPresent([TextSpan].self, forKey: .richTextSpans)

        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        self.originalImageUrl = try container.decodeIfPresent(String.self, forKey: .originalImageUrl)
        self.originalWidth = try container.decodeIfPresent(Double.self, forKey: .originalWidth)
        self.originalHeight = try container.decodeIfPresent(Double.self, forKey: .originalHeight)
        self.cropX = try container.decodeIfPresent(Double.self, forKey: .cropX)
        self.cropY = try container.decodeIfPresent(Double.self, forKey: .cropY)
        self.cropWidth = try container.decodeIfPresent(Double.self, forKey: .cropWidth)
        self.cropHeight = try container.decodeIfPresent(Double.self, forKey: .cropHeight)

        self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
        self.isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        self.createdBy = try container.decode(String.self, forKey: .createdBy)
        self.creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.pageId = try container.decodeIfPresent(String.self, forKey: .pageId)

        // Capture unknown extra fields
        let dynamicContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        let knownKeys = Set(CodingKeys.allCases.map { $0.stringValue })
        var extra: [String: AnyCodableValue] = [:]
        for key in dynamicContainer.allKeys {
            if !knownKeys.contains(key.stringValue) {
                if let val = try? dynamicContainer.decode(AnyCodableValue.self, forKey: key) {
                    extra[key.stringValue] = val
                }
            }
        }
        self.extraFields = extra.isEmpty ? nil : extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(boardId, forKey: .boardId)
        try container.encode(type, forKey: .type)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)

        try container.encodeIfPresent(x1, forKey: .x1)
        try container.encodeIfPresent(y1, forKey: .y1)
        try container.encodeIfPresent(x2, forKey: .x2)
        try container.encodeIfPresent(y2, forKey: .y2)
        try container.encodeIfPresent(extensionMode, forKey: .extensionMode)

        try container.encodeIfPresent(points, forKey: .points)
        try container.encode(strokeColor, forKey: .strokeColor)
        try container.encode(fillColor, forKey: .fillColor)
        try container.encode(fillOpacity, forKey: .fillOpacity)
        try container.encodeIfPresent(fillGradientStart, forKey: .fillGradientStart)
        try container.encodeIfPresent(fillGradientEnd, forKey: .fillGradientEnd)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encodeIfPresent(lineStyle, forKey: .lineStyle)
        try container.encodeIfPresent(arrowHeadLength, forKey: .arrowHeadLength)
        try container.encodeIfPresent(arrowHeadWidth, forKey: .arrowHeadWidth)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(zIndex, forKey: .zIndex)

        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(fontFamily, forKey: .fontFamily)
        try container.encodeIfPresent(stickyStyle, forKey: .stickyStyle)
        try container.encodeIfPresent(isBold, forKey: .isBold)
        try container.encodeIfPresent(isItalic, forKey: .isItalic)
        try container.encodeIfPresent(isUnderline, forKey: .isUnderline)
        try container.encodeIfPresent(isStrikethrough, forKey: .isStrikethrough)
        try container.encodeIfPresent(highlightColor, forKey: .highlightColor)
        try container.encodeIfPresent(align, forKey: .align)
        try container.encodeIfPresent(richTextSpans, forKey: .richTextSpans)

        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(originalImageUrl, forKey: .originalImageUrl)
        try container.encodeIfPresent(originalWidth, forKey: .originalWidth)
        try container.encodeIfPresent(originalHeight, forKey: .originalHeight)
        try container.encodeIfPresent(cropX, forKey: .cropX)
        try container.encodeIfPresent(cropY, forKey: .cropY)
        try container.encodeIfPresent(cropWidth, forKey: .cropWidth)
        try container.encodeIfPresent(cropHeight, forKey: .cropHeight)

        try container.encodeIfPresent(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(isVisible, forKey: .isVisible)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(creatorName, forKey: .creatorName)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(pageId, forKey: .pageId)

        // Re-encode extra fields
        if let extraFields = extraFields {
            var dynamicContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, val) in extraFields {
                if let codingKey = AnyCodingKey(stringValue: key) {
                    try dynamicContainer.encode(val, forKey: codingKey)
                }
            }
        }
    }

    public var displayName: String {
        if let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        switch type {
        case "pen", "stroke": return "手寫筆跡"
        case "curve": return "曲線"
        case "highlighter": return "螢光筆劃記"
        case "paint": return "油漆塗鴉"
        case "rect": return "矩形"
        case "circle": return "圓形"
        case "triangle": return "三角形"
        case "diamond": return "菱形"
        case "star": return "星形"
        case "line": return "直線"
        case "arrow": return "箭頭"
        case "text":
            if let text = text, !text.isEmpty {
                let snippet = text.prefix(12)
                return "文字 (\(snippet))"
            }
            return "文字"
        case "sticky":
            if let text = text, !text.isEmpty {
                let snippet = text.prefix(12)
                return "便條紙 (\(snippet))"
            }
            return "便條紙"
        case "image": return "置入圖片"
        case "pin": return "實體圖釘"
        default: return type
        }
    }

    public var systemIconName: String {
        switch type {
        case "pen", "stroke": return "pencil.tip"
        case "curve": return "point.topleft.down.to.point.bottomright.curvepath"
        case "highlighter": return "highlighter"
        case "paint": return "paintbrush.fill"
        case "rect": return "rectangle"
        case "circle": return "circle"
        case "triangle": return "triangle"
        case "diamond": return "diamond"
        case "star": return "star"
        case "line": return "line.diagonal"
        case "arrow": return "arrow.up.right"
        case "text": return "textformat"
        case "sticky": return "note.text"
        case "image": return "photo"
        case "pin": return "location.north.circle"
        default: return "square.on.circle"
        }
    }

    public var parsedPoints: [Point] {
        guard let points else { return [] }
        return BoardPointCache.points(id: id, updatedAt: updatedAt, json: points)
    }
}

public typealias HeiBanBoard = BoardMetadata

public struct BoardMetadata: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var ownerId: String
    public var ownerName: String
    public var ownerPhoto: String?
    public var backgroundColor: String
    public var gridStyle: GridStyle
    public var boardTheme: BoardTheme
    public var canvasMode: CanvasMode?
    public var canvasPreset: CanvasPreset?
    public var canvasWidth: Double?
    public var canvasHeight: Double?
    public var pins: [BoardPin]?
    public var thumbnail: String?
    public var itemCount: Int?
    public var revision: Int?
    public var collaboratorIds: [String]?
    public var createdAt: String
    public var updatedAt: String
    public var pages: [BoardPage]?
    public var activePageId: String?
    public var coverStyle: String?
    public var orientation: String?
    public var gridColor: String?
    public var memberRoles: [String: String]?
    public var source: String?
    public var extraFields: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, title, ownerId, ownerName, ownerPhoto, backgroundColor, gridStyle, boardTheme
        case canvasMode, canvasPreset, canvasWidth, canvasHeight, pins, thumbnail, itemCount, revision
        case collaboratorIds, memberRoles, source, createdAt, updatedAt, pages, activePageId, coverStyle, orientation, gridColor
    }

    public init(
        id: String = "board_main",
        title: String = "新黑板",
        ownerId: String = "local_mac",
        ownerName: String = "Mac 使用者",
        ownerPhoto: String? = nil,
        backgroundColor: String = "#172e25",
        gridStyle: GridStyle = .grid,
        boardTheme: BoardTheme = .blackboard,
        canvasMode: CanvasMode? = .infinite,
        canvasPreset: CanvasPreset? = .infinite,
        canvasWidth: Double? = nil,
        canvasHeight: Double? = nil,
        pins: [BoardPin]? = [],
        thumbnail: String? = nil,
        itemCount: Int? = 0,
        revision: Int? = 1,
        collaboratorIds: [String]? = nil,
        memberRoles: [String: String]? = nil,
        source: String? = nil,
        pages: [BoardPage]? = nil,
        activePageId: String? = nil,
        coverStyle: String? = nil,
        orientation: String? = nil,
        gridColor: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        updatedAt: String = ISO8601DateFormatter().string(from: Date()),
        extraFields: [String: AnyCodableValue]? = nil
    ) {
        self.id = id
        self.title = title
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.ownerPhoto = ownerPhoto
        self.backgroundColor = backgroundColor
        self.gridStyle = gridStyle
        self.boardTheme = boardTheme
        self.canvasMode = canvasMode
        self.canvasPreset = canvasPreset
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.pins = pins
        self.thumbnail = thumbnail
        self.itemCount = itemCount
        self.revision = revision
        self.collaboratorIds = collaboratorIds
        self.memberRoles = memberRoles
        self.source = source
        self.pages = pages
        self.activePageId = activePageId
        self.coverStyle = coverStyle
        self.orientation = orientation
        self.gridColor = gridColor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.extraFields = extraFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.ownerId = try container.decode(String.self, forKey: .ownerId)
        self.ownerName = try container.decode(String.self, forKey: .ownerName)
        self.ownerPhoto = try container.decodeIfPresent(String.self, forKey: .ownerPhoto)
        self.backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        self.gridStyle = try container.decode(GridStyle.self, forKey: .gridStyle)
        self.boardTheme = try container.decode(BoardTheme.self, forKey: .boardTheme)
        self.canvasMode = try container.decodeIfPresent(CanvasMode.self, forKey: .canvasMode)
        self.canvasPreset = try container.decodeIfPresent(CanvasPreset.self, forKey: .canvasPreset)
        self.canvasWidth = try container.decodeIfPresent(Double.self, forKey: .canvasWidth)
        self.canvasHeight = try container.decodeIfPresent(Double.self, forKey: .canvasHeight)
        self.pins = try container.decodeIfPresent([BoardPin].self, forKey: .pins)
        self.thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        self.itemCount = try container.decodeIfPresent(Int.self, forKey: .itemCount)
        self.revision = try container.decodeIfPresent(Int.self, forKey: .revision)
        self.collaboratorIds = try container.decodeIfPresent([String].self, forKey: .collaboratorIds)
        self.memberRoles = try container.decodeIfPresent([String: String].self, forKey: .memberRoles)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.pages = try container.decodeIfPresent([BoardPage].self, forKey: .pages)
        self.activePageId = try container.decodeIfPresent(String.self, forKey: .activePageId)
        self.coverStyle = try container.decodeIfPresent(String.self, forKey: .coverStyle)
        self.orientation = try container.decodeIfPresent(String.self, forKey: .orientation)
        self.gridColor = try container.decodeIfPresent(String.self, forKey: .gridColor)

        // Capture unknown extra fields
        let dynamicContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        let knownKeys = Set(CodingKeys.allCases.map { $0.stringValue })
        var extra: [String: AnyCodableValue] = [:]
        for key in dynamicContainer.allKeys {
            if !knownKeys.contains(key.stringValue) {
                if let val = try? dynamicContainer.decode(AnyCodableValue.self, forKey: key) {
                    extra[key.stringValue] = val
                }
            }
        }
        self.extraFields = extra.isEmpty ? nil : extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(ownerName, forKey: .ownerName)
        try container.encodeIfPresent(ownerPhoto, forKey: .ownerPhoto)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(gridStyle, forKey: .gridStyle)
        try container.encode(boardTheme, forKey: .boardTheme)
        try container.encodeIfPresent(canvasMode, forKey: .canvasMode)
        try container.encodeIfPresent(canvasPreset, forKey: .canvasPreset)
        try container.encodeIfPresent(canvasWidth, forKey: .canvasWidth)
        try container.encodeIfPresent(canvasHeight, forKey: .canvasHeight)
        try container.encodeIfPresent(pins, forKey: .pins)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try container.encodeIfPresent(itemCount, forKey: .itemCount)
        try container.encodeIfPresent(revision, forKey: .revision)
        try container.encodeIfPresent(collaboratorIds, forKey: .collaboratorIds)
        try container.encodeIfPresent(memberRoles, forKey: .memberRoles)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(pages, forKey: .pages)
        try container.encodeIfPresent(activePageId, forKey: .activePageId)
        try container.encodeIfPresent(coverStyle, forKey: .coverStyle)
        try container.encodeIfPresent(orientation, forKey: .orientation)
        try container.encodeIfPresent(gridColor, forKey: .gridColor)

        if let extraFields = extraFields {
            var dynamicContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, val) in extraFields {
                if let codingKey = AnyCodingKey(stringValue: key) {
                    try dynamicContainer.encode(val, forKey: codingKey)
                }
            }
        }
    }
}

public struct ViewportTransform: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var zoom: Double

    public init(x: Double = 0, y: Double = 0, zoom: Double = 1.0) {
        self.x = x
        self.y = y
        self.zoom = zoom
    }
}

public struct RulerState: Codable, Equatable {
    public var enabled: Bool
    public var screenCenterX: Double
    public var screenCenterY: Double
    public var angle: Double
    public var width: Double
    public var height: Double
    public var pivotRatio: Double
    public var pivotEdge: String
    public var opacity: Double

    public init(
        enabled: Bool = false,
        screenCenterX: Double = 600,
        screenCenterY: Double = 400,
        angle: Double = 0,
        width: Double = 1200,
        height: Double = 64,
        pivotRatio: Double = 0.5,
        pivotEdge: String = "center",
        opacity: Double = 0.38
    ) {
        self.enabled = enabled
        self.screenCenterX = screenCenterX
        self.screenCenterY = screenCenterY
        self.angle = angle
        self.width = width
        self.height = height
        self.pivotRatio = pivotRatio
        self.pivotEdge = pivotEdge
        self.opacity = opacity
    }
}

public struct HeiBanDocument: Codable, Equatable {
    public var schemaVersion: String
    public var version: String
    public var board: BoardMetadata
    public var objects: [BoardObject]
    public var exportedAt: String
    public var extraFields: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, version, board, objects, exportedAt
    }

    public init(
        schemaVersion: String = "1.0.0",
        version: String = "1.0",
        board: BoardMetadata,
        objects: [BoardObject],
        exportedAt: String = ISO8601DateFormatter().string(from: Date()),
        extraFields: [String: AnyCodableValue]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.board = board
        self.objects = objects
        self.exportedAt = exportedAt
        self.extraFields = extraFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sVer = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
        let ver = try container.decodeIfPresent(String.self, forKey: .version)
        self.schemaVersion = sVer ?? ver ?? "1.0.0"
        self.version = ver ?? sVer ?? "1.0"
        self.board = try container.decode(BoardMetadata.self, forKey: .board)
        self.objects = try container.decodeIfPresent([BoardObject].self, forKey: .objects) ?? []
        self.exportedAt = try container.decodeIfPresent(String.self, forKey: .exportedAt) ?? ISO8601DateFormatter().string(from: Date())

        let dynamicContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        let knownKeys = Set(CodingKeys.allCases.map { $0.stringValue })
        var extra: [String: AnyCodableValue] = [:]
        for key in dynamicContainer.allKeys {
            if !knownKeys.contains(key.stringValue) {
                if let val = try? dynamicContainer.decode(AnyCodableValue.self, forKey: key) {
                    extra[key.stringValue] = val
                }
            }
        }
        self.extraFields = extra.isEmpty ? nil : extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(version, forKey: .version)
        try container.encode(board, forKey: .board)
        try container.encode(objects, forKey: .objects)
        try container.encode(exportedAt, forKey: .exportedAt)

        if let extraFields = extraFields {
            var dynamicContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, val) in extraFields {
                if let codingKey = AnyCodingKey(stringValue: key) {
                    try dynamicContainer.encode(val, forKey: codingKey)
                }
            }
        }
    }
}
