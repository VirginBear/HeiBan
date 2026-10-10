using System.Globalization;
using System.Text.RegularExpressions;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public sealed record LayerListEntry(string ObjectId, string Title, string TypeLabel, string IconKey, bool IsLocked, bool IsVisible=true)
{
    public string Description => TypeLabel + (IsLocked ? " · 已鎖定" : "") + (IsVisible ? "" : " · 已隱藏");
}

/// <summary>Presentation never changes document IDs or writes generated names into the file.</summary>
public static class LayerPresentation
{
    public static IReadOnlyList<LayerListEntry> Build(IEnumerable<BoardObject> objects)
    {
        var counts = new Dictionary<string, int>();
        var rows = new List<(BoardObject Object, LayerListEntry Entry)>();
        foreach (var item in objects)
        {
            var (label, icon) = Describe(item.Type);
            counts[label] = counts.GetValueOrDefault(label) + 1;
            var name = Compact(item.Name);
            var text = item.Type is "text" or "sticky" ? Compact(item.Text) : "";
            var title = name.Length > 0 ? name : text.Length > 0
                ? $"{label}：{text}" : $"{label} {counts[label]}";
            rows.Add((item, new(item.Id, title, label, icon, item.IsLocked == true, item.IsVisible!=false)));
        }
        // Assign numbers in document order so changing z-order does not rename objects.
        return rows.OrderByDescending(row => row.Object.ZIndex).Select(row => row.Entry).ToArray();
    }

    private static string Compact(string? value)
    {
        var cleaned = Regex.Replace(value ?? "", @"[\s\x00-\x1F\x7F]+", " ").Trim();
        var elements = StringInfo.ParseCombiningCharacters(cleaned);
        return elements.Length <= 28 ? cleaned : cleaned[..elements[28]] + "…";
    }

    private static (string Label, string Icon) Describe(string type) => type switch
    {
        "stroke" or "pen" => ("手寫筆跡", "pen"),
        "highlighter" => ("螢光筆跡", "highlighter"), "paint" => ("油漆筆跡", "paint"),
        "line" => ("直線", "line"), "arrow" => ("箭頭", "arrow"),
        "rect" or "rounded_rect" => ("矩形", "rect"), "circle" => ("圓形", "circle"),
        "triangle" => ("三角形", "triangle"), "quadrilateral" => ("四邊形", "quadrilateral"),
        "diamond" => ("菱形", "diamond"), "pentagon" => ("五角形", "star"), "star" => ("星形", "star"),
        "curve" => ("曲線", "curve"), "arc" => ("圓弧", "compass"),
        "text" => ("文字", "text"), "sticky" => ("便條紙", "sticky"), "image" => ("圖片", "image"),
        "pin" => ("圖釘", "pin"), "tape" => ("遮題膠帶", "rect"),
        "frame" => ("畫框", "rect"), "table" => ("表格", "rect"), "formula" => ("公式", "text"),
        "mindmap" => ("心智圖", "shapes"), "connector" => ("連接線", "line"),
        _ => ("其他物件", "shapes")
    };
}
