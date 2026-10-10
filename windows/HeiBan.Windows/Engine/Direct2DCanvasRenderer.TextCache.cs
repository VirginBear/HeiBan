using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas.Text;
using global::Windows.Foundation;
using global::Windows.UI;

namespace HeiBan.Windows.Engine;

public sealed partial class Direct2DCanvasRenderer
{
    private readonly record struct TextKey(string Text,string Family,float Size,float Width,float Height,
        bool Bold,bool Italic,bool Underline,bool Strike,string? Align,double Opacity);
    private sealed record TextEntry(TextKey Key,TextSpan[] Spans,CanvasTextLayout Layout,(Rect Bounds,Color Color)[] Highlights);
    private readonly Dictionary<string,TextEntry> _textLayouts=[];
    private readonly Dictionary<string,CanvasStrokeStyle> _strokeStyles=[];
    internal long TextLayoutBuilds {get;private set;}
    internal bool BypassTextCache {get;set;}
    private CanvasStrokeStyle StrokeStyle(string line)
    {
        if(_strokeStyles.TryGetValue(line,out var style))return style;
        return _strokeStyles[line]=new CanvasStrokeStyle{StartCap=CanvasCapStyle.Round,EndCap=CanvasCapStyle.Round,DashCap=CanvasCapStyle.Round,LineJoin=CanvasLineJoin.Round,
            DashStyle=line switch{"dashed"=>CanvasDashStyle.Dash,"dotted"=>CanvasDashStyle.Dot,"dashdot"=>CanvasDashStyle.DashDot,_=>CanvasDashStyle.Solid}};
    }
    private void ClearTextCache()
    {
        foreach(var entry in _textLayouts.Values)entry.Layout.Dispose();_textLayouts.Clear();
        foreach(var style in _strokeStyles.Values)style.Dispose();_strokeStyles.Clear();
    }
    private void PruneTextCache(HashSet<string> ids)
    {
        foreach(var id in _textLayouts.Keys.Where(id=>!ids.Contains(id)).ToArray()){_textLayouts[id].Layout.Dispose();_textLayouts.Remove(id);}
    }
    private static bool SameSpans(List<TextSpan>? spans,TextSpan[] cached)
    {
        if((spans?.Count??0)!=cached.Length)return false;
        for(var i=0;i<cached.Length;i++)
        {
            var a=spans![i];var b=cached[i];
            if(a.Text!=b.Text||a.IsBold!=b.IsBold||a.IsItalic!=b.IsItalic||a.IsUnderline!=b.IsUnderline||a.IsStrikethrough!=b.IsStrikethrough||a.Color!=b.Color||a.HighlightColor!=b.HighlightColor)return false;
        }
        return true;
    }
    private void RenderText(CanvasDrawingSession ds,BoardObject o,Rect rect,Color color)
    {
        var key=new TextKey(o.Text??"",o.FontFamily?.Split(',')[0]??"Microsoft JhengHei",(float)(o.FontSize??18),(float)rect.Width,(float)rect.Height,
            o.IsBold==true,o.IsItalic==true,o.IsUnderline==true,o.IsStrikethrough==true,o.Align,o.Opacity);
        if(BypassTextCache||!_textLayouts.TryGetValue(o.Id,out var entry)||entry.Key!=key||!SameSpans(o.RichTextSpans,entry.Spans))
        {
            if(_textLayouts.Remove(o.Id,out var previous))previous.Layout.Dispose();
            using var format=new CanvasTextFormat{FontFamily=key.Family,FontSize=key.Size,
                FontWeight=new global::Windows.UI.Text.FontWeight{Weight=(ushort)(key.Bold?700:400)},
                FontStyle=key.Italic?global::Windows.UI.Text.FontStyle.Italic:global::Windows.UI.Text.FontStyle.Normal,
                HorizontalAlignment=key.Align switch{"center"=>CanvasHorizontalAlignment.Center,"right"=>CanvasHorizontalAlignment.Right,_=>CanvasHorizontalAlignment.Left},WordWrapping=CanvasWordWrapping.Wrap};
            var layout=new CanvasTextLayout(ds,key.Text,format,key.Width,key.Height);var count=key.Text.Length;
            if(count>0){layout.SetUnderline(0,count,key.Underline);layout.SetStrikethrough(0,count,key.Strike);}
            var spans=(o.RichTextSpans??[]).Select(DocumentCodec.Clone).ToArray();var offset=0;
            foreach(var span in spans)
            {
                var length=Math.Min(span.Text.Length,count-offset);if(length<=0)break;
                layout.SetFontWeight(offset,length,new global::Windows.UI.Text.FontWeight{Weight=(ushort)(span.IsBold==true?700:400)});
                layout.SetFontStyle(offset,length,span.IsItalic==true?global::Windows.UI.Text.FontStyle.Italic:global::Windows.UI.Text.FontStyle.Normal);
                layout.SetUnderline(offset,length,span.IsUnderline==true);layout.SetStrikethrough(offset,length,span.IsStrikethrough==true);
                if(span.Color is not null)layout.SetColor(offset,length,HexToColor(span.Color,(float)o.Opacity));offset+=length;
            }
            var highlights=new List<(Rect,Color)>();offset=0;
            foreach(var span in spans)
            {
                var length=Math.Min(span.Text.Length,count-offset);if(length<=0)break;
                if(span.HighlightColor is not null)foreach(var region in layout.GetCharacterRegions(offset,length))highlights.Add((region.LayoutBounds,HexToColor(span.HighlightColor,(float)o.Opacity)));
                offset+=length;
            }
            entry=new(key,spans,layout,highlights.ToArray());_textLayouts[o.Id]=entry;TextLayoutBuilds++;
        }
        foreach(var h in entry.Highlights)ds.FillRectangle(new Rect(rect.X+h.Bounds.X,rect.Y+h.Bounds.Y,h.Bounds.Width,h.Bounds.Height),h.Color);
        ds.DrawTextLayout(entry.Layout,(float)rect.X,(float)rect.Y,color);
    }
}
