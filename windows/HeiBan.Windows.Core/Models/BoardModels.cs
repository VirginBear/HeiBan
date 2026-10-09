using System.Text.Json;
using System.Text.Json.Serialization;

namespace HeiBan.Windows.Models;

/// <summary>
/// HeiBan 根文件結構 (依據 DOCUMENT_SCHEMA_CONTRACT.md v1.0.0)
/// 保留未知欄位；跨平台功能相容性需依移植清單驗收
/// </summary>
public sealed class HeiBanDocument
{
    [JsonPropertyName("schemaVersion")]
    public string SchemaVersion { get; set; } = "1.0.0";

    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0";

    [JsonPropertyName("board")]
    public BoardMetadata Board { get; set; } = new();

    [JsonPropertyName("objects")]
    public List<BoardObject> Objects { get; set; } = [];

    [JsonPropertyName("exportedAt")]
    public string ExportedAt { get; set; } = DateTime.UtcNow.ToString("o");

    /// <summary>
    /// 未知擴充欄位無損保留 (防未來版本資料丟失)
    /// </summary>
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? ExtraFields { get; set; }
}

/// <summary>
/// 黑板畫布全域元資料
/// </summary>
public sealed class BoardMetadata
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("title")]
    public string Title { get; set; } = "未命名黑板";

    [JsonPropertyName("ownerId")]
    public string OwnerId { get; set; } = "local_user";

    [JsonPropertyName("ownerName")]
    public string OwnerName { get; set; } = "本機使用者";

    [JsonPropertyName("ownerPhoto")]
    public string? OwnerPhoto { get; set; }

    [JsonPropertyName("backgroundColor")]
    public string BackgroundColor { get; set; } = "#172e25";

    [JsonPropertyName("gridStyle")]
    public string GridStyle { get; set; } = "dots"; // grid, dots, lines, staff, blank

    [JsonPropertyName("boardTheme")]
    public string BoardTheme { get; set; } = "blackboard"; // blackboard, dark, whiteboard, slate

    [JsonPropertyName("canvasMode")]
    public string? CanvasMode { get; set; } = "infinite"; // infinite, fixed, notebook

    [JsonPropertyName("canvasPreset")]
    public string? CanvasPreset { get; set; } = "infinite";

    [JsonPropertyName("canvasWidth")]
    public double? CanvasWidth { get; set; }

    [JsonPropertyName("canvasHeight")]
    public double? CanvasHeight { get; set; }

    [JsonPropertyName("pins")]
    public List<BoardPin>? Pins { get; set; }

    [JsonPropertyName("pages")] public List<BoardPage>? Pages { get; set; }
    [JsonPropertyName("activePageId")] public string? ActivePageId { get; set; }
    [JsonPropertyName("gridColor")] public string? GridColor { get; set; }
    [JsonPropertyName("coverStyle")] public string? CoverStyle { get; set; }
    [JsonPropertyName("orientation")] public string? Orientation { get; set; }
    [JsonPropertyName("thumbnail")]
    public string? Thumbnail { get; set; }

    [JsonPropertyName("itemCount")]
    public int? ItemCount { get; set; }

    [JsonPropertyName("revision")]
    public int Revision { get; set; } = 1;

    [JsonPropertyName("collaboratorIds")]
    public List<string>? CollaboratorIds { get; set; }

    [JsonPropertyName("memberRoles")]
    public Dictionary<string, string>? MemberRoles { get; set; }

    [JsonPropertyName("source")]
    public string? Source { get; set; } = "local"; // local, cloud

    [JsonPropertyName("createdAt")]
    public string CreatedAt { get; set; } = DateTime.UtcNow.ToString("o");

    [JsonPropertyName("updatedAt")]
    public string UpdatedAt { get; set; } = DateTime.UtcNow.ToString("o");

    [JsonExtensionData]
    public Dictionary<string, JsonElement>? ExtraFields { get; set; }
}

/// <summary>
/// 黑板向量幾何、手寫筆跡、便簽與文字物件
/// </summary>
public sealed class BoardObject
{
    // Matches the existing Mac v1 optional name field; identifiers remain unchanged.
    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("boardId")]
    public string BoardId { get; set; } = string.Empty;

    /// <summary>
    /// 物件型別：stroke, highlighter, paint, curve, rect, circle, triangle, diamond, arrow, line, star, text, sticky, image, pin
    /// </summary>
    [JsonPropertyName("type")]
    public string Type { get; set; } = "stroke";

    [JsonPropertyName("x")]
    public double X { get; set; }

    [JsonPropertyName("y")]
    public double Y { get; set; }

    [JsonPropertyName("width")]
    public double Width { get; set; }

    [JsonPropertyName("height")]
    public double Height { get; set; }

    [JsonPropertyName("x1")]
    public double? X1 { get; set; }

    [JsonPropertyName("y1")]
    public double? Y1 { get; set; }

    [JsonPropertyName("x2")]
    public double? X2 { get; set; }

    [JsonPropertyName("y2")]
    public double? Y2 { get; set; }

    [JsonPropertyName("extension")]
    public string? Extension { get; set; } // none, start, end, both

    /// <summary>
    /// 筆跡點 JSON 字串 (序列化之 Point[] 陣列，含座標與壓感)
    /// </summary>
    [JsonPropertyName("points")]
    public string? Points { get => _points; set { _points = value; _parsedPoints = null; } }
    private string? _points;
    private List<InkPoint>? _parsedPoints;
    [JsonIgnore]
    public IReadOnlyList<InkPoint> ParsedPoints => _parsedPoints ??= string.IsNullOrWhiteSpace(Points)
        ? [] : JsonSerializer.Deserialize<List<InkPoint>>(Points) ?? [];
    [JsonIgnore]
    public bool IsErasable => Type is "stroke" or "pen" or "highlighter" or "paint" or "curve"
        or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "line" or "arrow" or "star" or "pentagon" or "arc" or "tape";

    [JsonPropertyName("strokeColor")]
    public string StrokeColor { get; set; } = "#ffffff";

    [JsonPropertyName("fillColor")]
    public string FillColor { get; set; } = "none";

    [JsonPropertyName("strokeWidth")]
    public double StrokeWidth { get; set; } = 2.0;

    [JsonPropertyName("lineStyle")]
    public string LineStyle { get; set; } = "solid"; // solid, dashed

    [JsonPropertyName("opacity")]
    public double Opacity { get; set; } = 1.0;

    [JsonPropertyName("rotation")]
    public double Rotation { get; set; } = 0.0;

    [JsonPropertyName("zIndex")]
    public int ZIndex { get; set; } = 0;

    [JsonPropertyName("fillOpacity")] public double? FillOpacity { get; set; }
    [JsonPropertyName("arrowHeadLength")] public double? ArrowHeadLength { get; set; }
    [JsonPropertyName("arrowHeadWidth")] public double? ArrowHeadWidth { get; set; }

    [JsonPropertyName("brushKind")] public string? BrushKind { get; set; }
    [JsonPropertyName("isRevealed")] public bool? IsRevealed { get; set; }
    [JsonPropertyName("tapeStyle")] public string? TapeStyle { get; set; }

    // === 圓弧與圓規欄位 (W-N04, 對齊 Mac schema) ===
    [JsonPropertyName("arcRadius")] public double? ArcRadius { get; set; }
    [JsonPropertyName("arcStartAngle")] public double? ArcStartAngle { get; set; }
    [JsonPropertyName("arcSweepAngle")] public double? ArcSweepAngle { get; set; }
    // === 文字與富文本欄位 ===
    [JsonPropertyName("text")]
    public string? Text { get; set; }

    [JsonPropertyName("fontSize")]
    public double? FontSize { get; set; } = 18.0;

    [JsonPropertyName("fontFamily")]
    public string? FontFamily { get; set; } = "Segoe UI Variable, Microsoft JhengHei";

    [JsonPropertyName("align")]
    public string? Align { get; set; } = "left";

    [JsonPropertyName("isBold")]
    public bool? IsBold { get; set; }

    [JsonPropertyName("isItalic")]
    public bool? IsItalic { get; set; }

    [JsonPropertyName("isUnderline")]
    public bool? IsUnderline { get; set; }

    [JsonPropertyName("isStrikethrough")]
    public bool? IsStrikethrough { get; set; }

    [JsonPropertyName("highlightColor")]
    public string? HighlightColor { get; set; }

    [JsonPropertyName("richTextSpans")]
    public List<TextSpan>? RichTextSpans { get; set; }

    // === 便簽風格 ===
    [JsonPropertyName("stickyStyle")]
    public string? StickyStyle { get; set; } // classic, washi, cat, notebook, grid, soft

    // === 漸層支援 ===
    [JsonPropertyName("fillGradientStart")]
    public string? FillGradientStart { get; set; }

    [JsonPropertyName("fillGradientEnd")]
    public string? FillGradientEnd { get; set; }

    // === 圖片與非破壞性 8 向裁切 ===
    [JsonPropertyName("imageUrl")]
    public string? ImageUrl { get; set; }

    [JsonPropertyName("originalImageUrl")]
    public string? OriginalImageUrl { get; set; }

    [JsonPropertyName("originalWidth")]
    public double? OriginalWidth { get; set; }

    [JsonPropertyName("originalHeight")]
    public double? OriginalHeight { get; set; }

    [JsonPropertyName("cropX")]
    public double? CropX { get; set; }

    [JsonPropertyName("cropY")]
    public double? CropY { get; set; }

    [JsonPropertyName("cropWidth")]
    public double? CropWidth { get; set; }

    [JsonPropertyName("cropHeight")]
    public double? CropHeight { get; set; }

    // === 多頁筆記本關聯 ===
    [JsonPropertyName("pageId")]
    public string? PageId { get; set; }

    // === 狀態與擁有者 ===
    [JsonPropertyName("isLocked")]
    public bool? IsLocked { get; set; }

    [JsonPropertyName("isVisible")]
    public bool? IsVisible { get; set; } = true;

    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = "local_user";

    [JsonPropertyName("creatorName")]
    public string? CreatorName { get; set; }

    [JsonPropertyName("updatedAt")]
    public string UpdatedAt { get; set; } = DateTime.UtcNow.ToString("o");

    [JsonExtensionData]
    public Dictionary<string, JsonElement>? ExtraFields { get; set; }
}

/// <summary>
/// 畫布實體圖釘
/// </summary>
public sealed class BoardPin
{
    [JsonPropertyName("isWorldSpace")] public bool? IsWorldSpace { get; set; } = true;
    [JsonExtensionData] public Dictionary<string, JsonElement>? ExtraFields { get; set; }
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("boardId")]
    public string BoardId { get; set; } = string.Empty;

    [JsonPropertyName("x")]
    public double X { get; set; }

    [JsonPropertyName("y")]
    public double Y { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = "重要圖釘";

    [JsonPropertyName("zoom")]
    public double Zoom { get; set; } = 1.0;

    [JsonPropertyName("createdAt")]
    public string CreatedAt { get; set; } = DateTime.UtcNow.ToString("o");
}

/// <summary>
/// 手寫筆壓感點資料結構
/// </summary>
public sealed class InkPoint
{
    [JsonExtensionData] public Dictionary<string, JsonElement>? ExtraFields { get; set; }
    [JsonPropertyName("x")]
    public double X { get; set; }

    [JsonPropertyName("y")]
    public double Y { get; set; }

    [JsonPropertyName("pressure")]
    public double Pressure { get; set; } = 0.5;

    [JsonPropertyName("tiltX")]
    public double? TiltX { get; set; }

    [JsonPropertyName("tiltY")]
    public double? TiltY { get; set; }

    public InkPoint() { }

    public InkPoint(double x, double y, double pressure = 0.5)
    {
        X = x;
        Y = y;
        Pressure = pressure;
    }
}

/// <summary>
/// 富文本段落格式
/// </summary>
public sealed class TextSpan
{
    [JsonExtensionData] public Dictionary<string, JsonElement>? ExtraFields { get; set; }
    [JsonPropertyName("text")]
    public string Text { get; set; } = string.Empty;

    [JsonPropertyName("isBold")]
    public bool? IsBold { get; set; }

    [JsonPropertyName("isItalic")]
    public bool? IsItalic { get; set; }

    [JsonPropertyName("isUnderline")]
    public bool? IsUnderline { get; set; }

    [JsonPropertyName("isStrikethrough")]
    public bool? IsStrikethrough { get; set; }

    [JsonPropertyName("highlightColor")]
    public string? HighlightColor { get; set; }

    [JsonPropertyName("color")]
    public string? Color { get; set; }
}

/// <summary>
/// 視圖轉換狀態 (世界座標 <-> 螢幕座標)
/// </summary>
public sealed class ViewportTransform
{
    public double X { get; set; } = 0.0;
    public double Y { get; set; } = 0.0;
    public double Zoom { get; set; } = 1.0;

    public InkPoint ScreenToWorld(double screenX, double screenY) =>
        new((screenX - X) / Zoom, (screenY - Y) / Zoom);

    public InkPoint WorldToScreen(double worldX, double worldY) =>
        new(worldX * Zoom + X, worldY * Zoom + Y);
}

public sealed class BoardPage
{
    [JsonPropertyName("id")] public string Id { get; set; } = Guid.NewGuid().ToString();
    [JsonPropertyName("title")] public string Title { get; set; } = "第 1 頁";
    [JsonPropertyName("index")] public int Index { get; set; }
    [JsonPropertyName("createdAt")] public string CreatedAt { get; set; } = DateTime.UtcNow.ToString("o");
    [JsonPropertyName("updatedAt")] public string UpdatedAt { get; set; } = DateTime.UtcNow.ToString("o");
    [JsonExtensionData] public Dictionary<string, JsonElement>? ExtraFields { get; set; }
}
