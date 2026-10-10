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
    public static bool ValidColor(string value)=>Regex.IsMatch(value,"^#[0-9a-fA-F]{6}$");
    public static bool Apply(BoardObject item,TextStyleChange change,double coordinateScale=1)
    {
        if(item.IsLocked==true||item.Type is not("text" or "sticky")||
            change.Size is { } size&&!double.IsFinite(size)||change.Opacity is { } opacity&&!double.IsFinite(opacity))return false;
        var before=JsonSerializer.Serialize(item,DocumentCodec.Options);
        if(change.Size is { } fontSize){item.FontSize=Math.Clamp(fontSize,8,144)*coordinateScale;GrowHeight(item);}
        if(change.Color is { } color&&ValidColor(color))item.StrokeColor=color;
        if(change.Family is { } family&&!string.IsNullOrWhiteSpace(family))item.FontFamily=family.Trim();
        if(change.Align is "left" or "center" or "right")item.Align=change.Align;
        if(change.Opacity is { } alpha)item.Opacity=Math.Clamp(alpha,.05,1);
        if(change.Bold is { } bold)item.IsBold=bold;
        if(change.Italic is { } italic)item.IsItalic=italic;
        if(change.Underline is { } underline)item.IsUnderline=underline;
        foreach(var span in item.RichTextSpans??[])
        {
            if(change.Color is { } spanColor&&ValidColor(spanColor))span.Color=spanColor;
            if(change.Bold is { } spanBold)span.IsBold=spanBold;
            if(change.Italic is { } spanItalic)span.IsItalic=spanItalic;
            if(change.Underline is { } spanUnderline)span.IsUnderline=spanUnderline;
        }
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
        var size=item.FontSize??24;var width=Math.Max(20,item.Width-28);var lines=0;
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
