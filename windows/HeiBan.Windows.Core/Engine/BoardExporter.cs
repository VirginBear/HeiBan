using System.Globalization;
using System.Net;
using System.Text;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;
public sealed record ExportArea(double X,double Y,double Width,double Height);
public static class BoardExporter
{
    public static ExportArea Bounds(BoardMetadata board,IEnumerable<BoardObject> source,bool selection=false)
    {
        if(!selection&&board.CanvasMode is "fixed" or "notebook")return new(0,0,board.CanvasWidth??595,board.CanvasHeight??842);
        var objects=source.Where(o=>o.IsVisible!=false).ToArray();if(objects.Length==0)return new(0,0,800,600);
        var bounds=objects.Select(o=>{
            var corners=new[]{new InkPoint(o.X,o.Y),new InkPoint(o.X+o.Width,o.Y),new InkPoint(o.X+o.Width,o.Y+o.Height),new InkPoint(o.X,o.Y+o.Height)}.Select(p=>ObjectHandles.ToWorld(o,p));
            return VectorMath.ComputeBoundingBox(corners.ToArray(),Math.Max(o.StrokeWidth,24));
        }).ToArray();var left=bounds.Min(b=>b.MinX)-16;var top=bounds.Min(b=>b.MinY)-16;
        return new(left,top,Math.Max(1,bounds.Max(b=>b.MaxX)-left+16),Math.Max(1,bounds.Max(b=>b.MaxY)-top+16));
    }
    private static string N(double value)=>double.IsFinite(value)?value.ToString("0.###",CultureInfo.InvariantCulture):"0";
    private static string E(string? value)=>WebUtility.HtmlEncode(value??"");
    private static string Decoration(bool underline,bool strike)=>underline||strike?string.Join(' ',new[]{underline?"underline":"",strike?"line-through":""}.Where(value=>value.Length>0)):"none";
    private static string Color(string? value)=>value is not null&&(value=="none"||value=="transparent"||System.Text.RegularExpressions.Regex.IsMatch(value,"^#[0-9a-fA-F]{3,8}$"))?value:"none";
    public static string Svg(HeiBanDocument document,IEnumerable<BoardObject> source,ExportArea area)
    {
        var b=new StringBuilder();b.Append($"<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"{N(area.Width)}\" height=\"{N(area.Height)}\" viewBox=\"{N(area.X)} {N(area.Y)} {N(area.Width)} {N(area.Height)}\"><title>{E(document.Board.Title)}</title>");
        b.Append($"<defs><clipPath id=\"export-area\"><rect x=\"{N(area.X)}\" y=\"{N(area.Y)}\" width=\"{N(area.Width)}\" height=\"{N(area.Height)}\"/></clipPath></defs><g clip-path=\"url(#export-area)\">");
        b.Append($"<rect x=\"{N(area.X)}\" y=\"{N(area.Y)}\" width=\"{N(area.Width)}\" height=\"{N(area.Height)}\" fill=\"{Color(document.Board.BackgroundColor)}\"/>");
        if(document.Board.GridStyle is "grid" or "dots" or "lines" or "staff")
        {
            var step=document.Board.GridStyle=="staff"?12:32;var id="background-grid";var ink=Color(document.Board.GridColor??"#76877D");
            b.Append($"<defs><pattern id=\"{id}\" width=\"{step}\" height=\"{(document.Board.GridStyle=="staff"?96:step)}\" patternUnits=\"userSpaceOnUse\">");
            if(document.Board.GridStyle=="dots")b.Append($"<circle cx=\"1\" cy=\"1\" r=\"1\" fill=\"{ink}\" opacity=\".25\"/>");
            else if(document.Board.GridStyle=="staff")for(var i=0;i<5;i++)b.Append($"<path d=\"M0 {i*12}H12\" stroke=\"{ink}\" opacity=\".25\"/>");
            else b.Append($"<path d=\"M0 0H32{(document.Board.GridStyle=="grid"?" M0 0V32":"")}\" stroke=\"{ink}\" opacity=\".25\"/>");
            b.Append($"</pattern></defs><rect x=\"{N(area.X)}\" y=\"{N(area.Y)}\" width=\"{N(area.Width)}\" height=\"{N(area.Height)}\" fill=\"url(#{id})\"/>");
        }
        var index=0;
        foreach(var o in source.Where(o=>o.IsVisible!=false).OrderBy(o=>o.ZIndex))
        {
            var id="obj"+index++;var x=N(o.X);var y=N(o.Y);var w=N(Math.Max(.1,o.Width));var h=N(Math.Max(.1,o.Height));
            var stroke=Color(o.StrokeColor);var fill=Color(o.FillColor);
            if(o.FillGradientStart is not null&&o.FillGradientEnd is not null){b.Append($"<defs><linearGradient id=\"{id}-gradient\" x2=\"1\" y2=\"1\"><stop stop-color=\"{Color(o.FillGradientStart)}\"/><stop offset=\"1\" stop-color=\"{Color(o.FillGradientEnd)}\"/></linearGradient></defs>");fill=$"url(#{id}-gradient)";}
            var dash=o.LineStyle switch{"dashed"=>"8 6","dotted"=>"1 5","dashdot"=>"8 4 1 4",_=>"none"};
            b.Append($"<g opacity=\"{N(Math.Clamp(o.Opacity,0,1))}\" transform=\"rotate({N(o.Rotation)} {N(o.X+o.Width/2)} {N(o.Y+o.Height/2)})\" stroke=\"{stroke}\" stroke-width=\"{N(o.StrokeWidth)}\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-dasharray=\"{dash}\" fill=\"{fill}\" fill-opacity=\"{N(o.FillOpacity is { } fo ? fo/Math.Max(.001,o.Opacity):1)}\">");
            switch(o.Type)
            {
                case "stroke":case "pen":case "highlighter":case "paint":case "curve":
                    var pts=o.ParsedPoints;
                    if(pts.Count==1)b.Append($"<circle cx=\"{N(pts[0].X)}\" cy=\"{N(pts[0].Y)}\" r=\"{N(o.StrokeWidth/2)}\" fill=\"{stroke}\" stroke=\"none\"/>");
                    else if(pts.Count>1){b.Append($"<path fill=\"none\" d=\"M{N(pts[0].X)} {N(pts[0].Y)}");for(var i=1;i<pts.Count;i++){var p0=pts[Math.Max(0,i-2)];var p1=pts[i-1];var p2=pts[i];var p3=pts[Math.Min(pts.Count-1,i+1)];b.Append($" C{N(p1.X+(p2.X-p0.X)/6)} {N(p1.Y+(p2.Y-p0.Y)/6)} {N(p2.X-(p3.X-p1.X)/6)} {N(p2.Y-(p3.Y-p1.Y)/6)} {N(p2.X)} {N(p2.Y)}");}b.Append("\"/>");}break;
                case "rect":b.Append($"<rect x=\"{x}\" y=\"{y}\" width=\"{w}\" height=\"{h}\"/>");break;
                case "circle":b.Append($"<ellipse cx=\"{N(o.X+o.Width/2)}\" cy=\"{N(o.Y+o.Height/2)}\" rx=\"{N(o.Width/2)}\" ry=\"{N(o.Height/2)}\"/>");break;
                case "arc":
                    var radius=o.ArcRadius??o.Width/2;var cx=o.X+o.Width/2;var cy=o.Y+o.Height/2;var start=(o.ArcStartAngle??0)*Math.PI/180;var sweep=Math.Clamp(o.ArcSweepAngle??360,-360,360);var end=start+sweep*Math.PI/180;
                    if(Math.Abs(sweep)>=359.999)b.Append($"<circle cx=\"{N(cx)}\" cy=\"{N(cy)}\" r=\"{N(radius)}\"/>");
                    else b.Append($"<path fill=\"none\" d=\"M{N(cx+radius*Math.Cos(start))} {N(cy+radius*Math.Sin(start))} A{N(radius)} {N(radius)} 0 {(Math.Abs(sweep)>180?1:0)} {(sweep>=0?1:0)} {N(cx+radius*Math.Cos(end))} {N(cy+radius*Math.Sin(end))}\"/>");break;
                case "line":case "arrow":
                    var ax=o.X1??o.X;var ay=o.Y1??o.Y;var bx=o.X2??o.X+o.Width;var by=o.Y2??o.Y+o.Height;var length=Math.Sqrt(Math.Pow(bx-ax,2)+Math.Pow(by-ay,2));var dx=(bx-ax)/Math.Max(.001,length);var dy=(by-ay)/Math.Max(.001,length);var reach=Math.Max(area.Width,area.Height)*4+Math.Abs(area.X)+Math.Abs(area.Y)+Math.Abs(ax)+Math.Abs(ay);
                    b.Append($"<path fill=\"none\" d=\"M{N(ax-(o.Extension is "start" or "both"?dx*reach:0))} {N(ay-(o.Extension is "start" or "both"?dy*reach:0))} L{N(bx+(o.Extension is "end" or "both"?dx*reach:0))} {N(by+(o.Extension is "end" or "both"?dy*reach:0))}\"/>");
                    if(o.Type=="arrow"&&length>.001){var head=o.ArrowHeadLength??16;var hw=o.ArrowHeadWidth??10;b.Append($"<path stroke-width=\"{N(o.StrokeWidth)}\" stroke-dasharray=\"none\" fill=\"none\" d=\"M{N(bx-dx*head-dy*hw/2)} {N(by-dy*head+dx*hw/2)} L{N(bx)} {N(by)} L{N(bx-dx*head+dy*hw/2)} {N(by-dy*head-dx*hw/2)}\"/>");}break;
                case "triangle":case "quadrilateral":case "diamond":case "pentagon":case "star":
                    var polygon=o.ParsedPoints.Count>0?o.ParsedPoints:Enumerable.Range(0,o.Type=="triangle"?3:o.Type=="pentagon"?5:o.Type=="star"?10:4).Select(i=>{var n=o.Type=="triangle"?3:o.Type=="pentagon"?5:o.Type=="star"?10:4;var a=-Math.PI/2+i*Math.PI*2/n;var r=o.Type=="star"&&i%2==1?.45:1;return new InkPoint(o.X+o.Width/2+Math.Cos(a)*o.Width/2*r,o.Y+o.Height/2+Math.Sin(a)*o.Height/2*r);}).ToArray();
                    b.Append($"<polygon points=\"{string.Join(' ',polygon.Select(p=>N(p.X)+","+N(p.Y)))}\"/>");break;
                case "tape":
                    b.Append($"<rect x=\"{x}\" y=\"{y}\" width=\"{w}\" height=\"{h}\" rx=\"5\" fill=\"{stroke}\" fill-opacity=\"{(o.IsRevealed==true?".12":".96")}\" stroke-width=\"1\" stroke-dasharray=\"{(o.IsRevealed==true?"5 4":"none")}\"/>");if(o.IsRevealed!=true){b.Append($"<defs><pattern id=\"{id}-tape\" width=\"16\" height=\"16\" patternUnits=\"userSpaceOnUse\"><path d=\"M-4 4L4-4 M0 16L16 0 M12 20L20 12\" stroke=\"white\" stroke-opacity=\".3\" stroke-width=\"4\"/></pattern></defs><rect x=\"{x}\" y=\"{y}\" width=\"{w}\" height=\"{h}\" rx=\"5\" fill=\"url(#{id}-tape)\" fill-opacity=\"1\" stroke=\"none\"/>");}break;
                case "sticky":case "text":
                    if(o.Type=="sticky")b.Append($"<rect x=\"{x}\" y=\"{y}\" width=\"{w}\" height=\"{h}\" rx=\"{(o.StickyStyle=="soft"?14:6)}\" fill=\"{(fill=="none"?"#FFF0AB":fill)}\" stroke=\"#BBC6BB\" stroke-width=\"1\"/>");
                    if(o.Type=="sticky"&&o.StickyStyle is "notebook" or "grid")
                    {for(var yy=o.Y+28;yy<o.Y+o.Height;yy+=20)b.Append($"<path d=\"M{N(o.X+8)} {N(yy)}H{N(o.X+o.Width-8)}\" fill=\"none\" stroke=\"#516A72\" stroke-opacity=\".16\" stroke-width=\"1\"/>");if(o.StickyStyle=="grid")for(var xx=o.X+28;xx<o.X+o.Width;xx+=20)b.Append($"<path d=\"M{N(xx)} {N(o.Y+8)}V{N(o.Y+o.Height-8)}\" fill=\"none\" stroke=\"#516A72\" stroke-opacity=\".16\" stroke-width=\"1\"/>");}
                    if(o.Type=="sticky"&&o.StickyStyle=="washi")b.Append($"<rect x=\"{N(o.X+o.Width*.2)}\" y=\"{N(o.Y-6)}\" width=\"{N(o.Width*.6)}\" height=\"18\" fill=\"#A8BDB0\" fill-opacity=\".6\" stroke=\"none\"/>");
                    if(o.Type=="sticky"&&o.StickyStyle=="cat")foreach(var xx in new[]{o.X+12,o.X+o.Width-12})b.Append($"<ellipse cx=\"{N(xx)}\" cy=\"{N(o.Y+6)}\" rx=\"10\" ry=\"14\" fill=\"{(fill=="none"?"#FFF0AB":fill)}\" stroke=\"none\"/>");
                    var pad=o.Type=="sticky"?12:0;var align=o.Align??"left";var tx=o.X+pad+(align=="center"?(o.Width-pad*2)/2:align=="right"?o.Width-pad*2:0);var size=o.FontSize??18;
                    b.Append($"<foreignObject x=\"{N(o.X+pad)}\" y=\"{N(o.Y+pad)}\" width=\"{N(o.Width-pad*2)}\" height=\"{N(o.Height-pad*2)}\"><div xmlns=\"http://www.w3.org/1999/xhtml\" style=\"white-space:pre-wrap;overflow-wrap:anywhere;margin:0;font-family:{E(o.FontFamily??"Microsoft JhengHei, sans-serif")};font-size:{N(size)}px;color:{stroke};font-weight:{(o.IsBold==true?"bold":"normal")};font-style:{(o.IsItalic==true?"italic":"normal")};text-align:{(align is "center" or "right"?align:"left")};text-decoration:{Decoration(o.IsUnderline==true,o.IsStrikethrough==true)}\">");
                    if(o.RichTextSpans is {Count:>0} spans)foreach(var span in spans)b.Append($"<span style=\"background-color:{Color(span.HighlightColor??"transparent")};color:{Color(span.Color??o.StrokeColor)};font-weight:{(span.IsBold==true?"bold":"normal")};font-style:{(span.IsItalic==true?"italic":"normal")};text-decoration:{Decoration(span.IsUnderline==true,span.IsStrikethrough==true)}\">{E(span.Text)}</span>");else b.Append(E(o.Text));b.Append("</div></foreignObject>");break;
                case "image":
                    if(o.ImageUrl?.StartsWith("data:image/",StringComparison.Ordinal)==true)
                    {var ow=o.OriginalWidth??o.Width;var oh=o.OriginalHeight??o.Height;var cropW=Math.Max(1,o.CropWidth??ow);var cropH=Math.Max(1,o.CropHeight??oh);b.Append($"<svg x=\"{x}\" y=\"{y}\" width=\"{w}\" height=\"{h}\" viewBox=\"{N(o.CropX??0)} {N(o.CropY??0)} {N(cropW)} {N(cropH)}\" preserveAspectRatio=\"none\" overflow=\"hidden\"><image width=\"{N(ow)}\" height=\"{N(oh)}\" href=\"{E(o.ImageUrl)}\" xlink:href=\"{E(o.ImageUrl)}\"/></svg>");}break;
            }
            b.Append("</g>");
        }
        return b.Append("</g></svg>").ToString();
    }
    public static string Html(HeiBanDocument doc,IEnumerable<BoardObject> objects,ExportArea area,bool printing=false)
    {
        var printScale=Math.Min(1,14400/Math.Max(area.Width,area.Height));var printWidth=Math.Clamp(area.Width*printScale,72,14400);var printHeight=Math.Clamp(area.Height*printScale,72,14400);
        var svg=Svg(doc,objects,area);var json=DocumentCodec.Encode(doc).Replace("<","\\u003c");
        return "<!doctype html><html lang=\"zh-Hant\"><head><meta charset=\"utf-8\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none';img-src data:;style-src 'unsafe-inline';script-src 'unsafe-inline';font-src 'none'\"><meta name=\"viewport\" content=\"width=device-width\"><title>"+E(doc.Board.Title)+"</title><style>html,body{margin:0;background:#e9ece6}svg{display:block;width:100%;height:auto} @page{size:"+N(printWidth)+"pt "+N(printHeight)+"pt;margin:0}@media print{html,body{background:transparent}svg{width:"+N(printWidth)+"pt;height:"+N(printHeight)+"pt}}</style></head><body>"+svg+"<script id=\"heiban-data\" type=\"application/json\">"+json+"</script>"+(printing?"":"<script>let z=1;addEventListener('wheel',e=>{if(e.ctrlKey){e.preventDefault();z=Math.max(.1,Math.min(8,z*Math.exp(-e.deltaY*.001)));document.querySelector('svg').style.width=(100*z)+'%'}},{passive:false})</script>")+"</body></html>";
    }
}
