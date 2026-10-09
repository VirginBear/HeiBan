using System.Text.Json;
using System.Text.Json.Serialization;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public static class DocumentCodec
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = false
    };
    public static string Encode(HeiBanDocument document) => JsonSerializer.Serialize(document, Options);
    public static T Clone<T>(T value) => JsonSerializer.Deserialize<T>(JsonSerializer.Serialize(value, Options), Options)!;
    public static HeiBanDocument Decode(string json)
    {
        using var root = JsonDocument.Parse(json);
        if (root.RootElement.ValueKind != JsonValueKind.Object || !root.RootElement.TryGetProperty("board", out _) ||
            !root.RootElement.TryGetProperty("objects", out var objects) || objects.ValueKind != JsonValueKind.Array)
            throw new InvalidDataException("檔案缺少黑板或物件資料。");
        var doc = JsonSerializer.Deserialize<HeiBanDocument>(json, Options) ?? throw new InvalidDataException("無效的黑板文件。");
        if (!Version.TryParse(doc.SchemaVersion, out var version) || version.Major > 1)
            throw new NotSupportedException($"不支援文件版本 {doc.SchemaVersion}，請使用較新的黑板開啟。");
        if (doc.Board is null || doc.Objects is null || string.IsNullOrWhiteSpace(doc.Board.Id))
            throw new InvalidDataException("黑板識別資料損壞。");
        foreach (var o in doc.Objects)
        {
            if (!double.IsFinite(o.X) || !double.IsFinite(o.Y) || !double.IsFinite(o.Width) || !double.IsFinite(o.Height))
                throw new InvalidDataException("物件座標損壞。");
            _ = o.ParsedPoints; // Reject malformed embedded point data before exposing an editable document.
        }
        return doc;
    }
}
