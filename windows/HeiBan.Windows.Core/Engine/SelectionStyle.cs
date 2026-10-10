using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;
public static class SelectionStyle
{
    // Copy only changed style fields; coordinates, identity, contents and locked objects stay independent.
    private static readonly string[] Fields=["StrokeColor","StrokeWidth","Opacity","FillColor","FillOpacity","FillGradientStart","FillGradientEnd","LineStyle","Extension","FontSize","FontFamily","IsBold","IsItalic","IsUnderline","IsStrikethrough","Align","StickyStyle","BrushKind"];
    public static void ApplyChanged(BoardObject before,BoardObject after,IEnumerable<BoardObject> targets)
    {
        foreach(var name in Fields)
        {
            var property=typeof(BoardObject).GetProperty(name)!;var old=property.GetValue(before);var value=property.GetValue(after);
            if(Equals(old,value))continue;
            foreach(var target in targets.Where(o=>o.Id!=after.Id&&o.IsLocked!=true))
            {
                if(name is "FontSize" or "FontFamily" or "IsBold" or "IsItalic" or "IsUnderline" or "IsStrikethrough" or "Align"&&target.Type is not("text" or "sticky"))continue;
                if(name=="StickyStyle"&&target.Type!="sticky")continue;
                property.SetValue(target,value);
            }
        }
    }
}
