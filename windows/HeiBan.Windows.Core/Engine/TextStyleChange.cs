using System.Text.Json;
using System.Text;
using System.Text.RegularExpressions;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public sealed record TextStyleChange(double? Size=null,string? Color=null,string? Family=null,
    string? Align=null,double? Opacity=null,bool? Bold=null,bool? Italic=null,bool? Underline=null);

/// <summary>Text-only changes shared by regular and screen canvases. Null means untouched, including mixed values.</summary>
public static class TextStyles
{
    public static BoardObject? CreatePastedText(string text,BoardObject style,InkPoint center,double availableWidth,double coordinateScale=1)
    {
        if(string.IsNullOrWhiteSpace(text))return null;
        var item=DocumentCodec.Clone(style);
        item.Id=Guid.NewGuid().ToString();
        item.Type="text";
        item.Text=text.Replace("\r\n","\n",StringComparison.Ordinal).Replace('\r','\n');
        item.RichTextSpans=null;
        item.FillColor="none";
        item.Width=Math.Min(400*coordinateScale,Math.Max(80*coordinateScale,availableWidth*.75));
        item.Height=Math.Max(48*coordinateScale,(item.FontSize??18)*2);
        item.Rotation=0;
        GrowHeight(item);
        // Native editing includes line padding beyond the saved glyph bounds.
        item.Height+=24*coordinateScale;
        item.X=center.X-item.Width/2;
        item.Y=center.Y-item.Height/2;
        return item;
    }
    public static bool ValidColor(string value)=>Regex.IsMatch(value,"^#[0-9a-fA-F]{6}$");
    public static bool Apply(BoardObject item,TextStyleChange change,double coordinateScale=1)
    {
        if(item.IsLocked==true||item.Type is not("text" or "sticky")||
            change.Size is { } size&&!double.IsFinite(size)||change.Opacity is { } opacity&&!double.IsFinite(opacity))return false;
        var before=JsonSerializer.Serialize(item,DocumentCodec.Options);
        if(change.Size is { } fontSize)item.FontSize=Math.Clamp(fontSize,8,144)*coordinateScale;
        if(change.Color is { } color&&ValidColor(color))item.StrokeColor=color;
        if(change.Family is { } family&&!string.IsNullOrWhiteSpace(family))item.FontFamily=family.Trim();
        if(change.Align is "left" or "center" or "right" or "justify")item.Align=change.Align;
        if(change.Opacity is { } alpha)item.Opacity=Math.Clamp(alpha,.05,1);
        if(change.Bold is { } bold)item.IsBold=bold;
        if(change.Italic is { } italic)item.IsItalic=italic;
        if(change.Underline is { } underline)item.IsUnderline=underline;
        foreach(var span in item.RichTextSpans??[])
        {
            if(change.Size.HasValue)span.FontSize=null;
            if(change.Family is { } appliedFamily&&!string.IsNullOrWhiteSpace(appliedFamily))span.FontFamily=null;
            if(change.Color is { } spanColor&&ValidColor(spanColor))span.Color=spanColor;
            if(change.Bold is { } spanBold)span.IsBold=spanBold;
            if(change.Italic is { } spanItalic)span.IsItalic=spanItalic;
            if(change.Underline is { } spanUnderline)span.IsUnderline=spanUnderline;
        }
        if(change.Size.HasValue)GrowHeight(item);
        if(before==JsonSerializer.Serialize(item,DocumentCodec.Options))return false;
        item.UpdatedAt=DateTime.UtcNow.ToString("o");return true;
    }
    public static bool ApplySelection(EditorSession session,TextStyleChange change,double coordinateScale=1)
    {
        var generation=session.Generation;session.Begin();
        foreach(var item in session.SelectedObjects)Apply(item,change,coordinateScale);
        session.Commit();return session.Generation!=generation;
    }
    // Same conservative width estimate as the Mac baseline; native layout remains authoritative.
    public static void GrowHeight(BoardObject item)
    {
        if(item.Type!="text")return;
        // Vertical text wraps into columns within its height; horizontal line estimates do not apply.
        if(item.TextDirection=="vertical-rl")return;
        var size=Math.Max(item.FontSize??24,item.RichTextSpans is {Count:>0} spans?spans.Max(span=>span.FontSize??0):0);var width=Math.Max(20,item.Width-28);var lines=0;
        foreach(var line in (item.Text??"").Split('\n'))
        {
            var used=0d;var count=1;
            foreach(var rune in line.EnumerateRunes())
            {var advance=size*(rune.IsAscii ? .55 : 1.05);if(used+advance>width&&used>0){count++;used=advance;}else used+=advance;}
            lines+=count;
        }
        item.Height=Math.Max(item.Height,Math.Ceiling(lines*size*1.35));
    }
}
