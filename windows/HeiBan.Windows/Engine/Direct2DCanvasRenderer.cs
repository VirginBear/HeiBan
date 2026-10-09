using System.Numerics;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Brushes;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas.Text;
using global::Windows.Foundation;
using global::Windows.UI;

namespace HeiBan.Windows.Engine;

/// <summary>Committed world-space geometry cache. Pointer previews never serialize points to JSON.</summary>
public sealed class Direct2DCanvasRenderer : IDisposable
{
    private readonly Dictionary<string, (string Key, CanvasGeometry Geometry)> _geometry = [];
    private readonly Dictionary<string, CanvasBitmap> _images = [];
    private readonly List<CanvasGeometry> _liveBlocks=[];
    private InkPoint? _liveFirst;
    private int _liveEnd;
    public void ResetLive()
    {foreach(var geometry in _liveBlocks)geometry.Dispose();_liveBlocks.Clear();_liveEnd=0;_liveFirst=null;}
    public event Action? ResourcesChanged;
    public static Color HexToColor(string? hex, float opacity=1)
    {
        if (string.IsNullOrEmpty(hex) || hex is "none" or "transparent") return Color.FromArgb(0,0,0,0);
        hex=hex.TrimStart('#');
        if (hex.Length==3) hex=string.Concat(hex.Select(c => new string(c,2)));
        if (!uint.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out var n)) return Color.FromArgb(255,32,48,40);
        byte alpha = hex.Length==8 ? (byte)n : (byte)255; // Contract colors use #RRGGBBAA.
        if(hex.Length==8) n >>= 8;
        return Color.FromArgb((byte)(alpha*Math.Clamp(opacity,0,1)),(byte)(n>>16),(byte)(n>>8),(byte)n);
    }
    public async Task LoadImagesAsync(ICanvasResourceCreator device, IEnumerable<BoardObject> objects)
    {
        foreach(var source in objects.Where(o=>o.Type=="image").Select(o=>o.ImageUrl).Where(s=>s is not null).Distinct())
        {
            if(_images.ContainsKey(source!))continue;
            // Local embedded images only. Opening a board never silently downloads remote images.
            if(!source!.StartsWith("data:image/",StringComparison.Ordinal))continue;
            try
            {
                var bytes=Convert.FromBase64String(source[(source.IndexOf(',')+1)..]);
                using var stream=new MemoryStream(bytes);
                _images[source]=await CanvasBitmap.LoadAsync(device,stream.AsRandomAccessStream());
            }
            catch (Exception e) when(e is FormatException or ArgumentException or System.Runtime.InteropServices.COMException) { }
        }
        ResourcesChanged?.Invoke();
    }
    public void ClearCache()
    {
        ResetLive();
        foreach(var value in _geometry.Values)value.Geometry.Dispose(); _geometry.Clear();
        foreach(var value in _images.Values)value.Dispose(); _images.Clear();
    }
    public void Prune(IEnumerable<BoardObject> objects)
    {
        var ids=objects.Select(o=>o.Id).ToHashSet();
        foreach(var id in _geometry.Keys.Where(id=>!ids.Contains(id)).ToArray()){_geometry[id].Geometry.Dispose();_geometry.Remove(id);}
    }
    public void Dispose()=>ClearCache();
    public void RenderBackground(CanvasDrawingSession ds,BoardMetadata board,ViewportTransform vp,float width,float height)
    {
        var bounded=board.CanvasMode is "fixed" or "notebook";
        ds.Clear(HexToColor(bounded ? "#e9ece6" : board.BackgroundColor));
        var save=ds.Transform; ds.Transform=Matrix3x2.CreateScale((float)vp.Zoom)*Matrix3x2.CreateTranslation((float)vp.X,(float)vp.Y);
        var bounds=bounded ? new Rect(0,0,board.CanvasWidth??595,board.CanvasHeight??842)
            : new Rect(-vp.X/vp.Zoom,-vp.Y/vp.Zoom,width/vp.Zoom,height/vp.Zoom);
        ds.FillRectangle(bounds,HexToColor(board.BackgroundColor));
        using(var clip=ds.CreateLayer(1,bounds))
        {
            var bg=HexToColor(board.BackgroundColor); var dark=(bg.R*0.2126+bg.G*0.7152+bg.B*0.0722)<128;
            var grid=string.IsNullOrEmpty(board.GridColor) ? HexToColor(dark?"#ffffff":"#263f32",.16f) : HexToColor(board.GridColor,.5f);
            double step=board.GridStyle=="staff"?12:32;
            while(step*vp.Zoom<12)step*=2;
            var left=Math.Max(bounds.X,Math.Floor((-vp.X/vp.Zoom)/step)*step);
            var top=Math.Max(bounds.Y,Math.Floor((-vp.Y/vp.Zoom)/step)*step);
            var right=Math.Min(bounds.Right,(width-vp.X)/vp.Zoom); var bottom=Math.Min(bounds.Bottom,(height-vp.Y)/vp.Zoom);
            if(board.GridStyle=="dots")
                for(var x=left;x<right;x+=step)for(var y=top;y<bottom;y+=step)ds.FillCircle((float)x,(float)y,(float)(1/vp.Zoom),grid);
            else if(board.GridStyle is "grid" or "lines" or "staff")
            {
                if(board.GridStyle=="grid")for(var x=left;x<right;x+=step)ds.DrawLine((float)x,(float)top,(float)x,(float)bottom,grid,(float)(1/vp.Zoom));
                for(var y=top;y<bottom;y+=step)
                {if(board.GridStyle=="staff" && ((int)Math.Round(y/step)%8+8)%8>=5)continue;
                    ds.DrawLine((float)left,(float)y,(float)right,(float)y,grid,(float)(1/vp.Zoom));}
            }
        }
        ds.Transform=save;
    }
    public void RenderObjects(CanvasDrawingSession ds,IEnumerable<BoardObject> objects,ViewportTransform vp,float width,float height)
    {
        var world=new VectorMath.RectBounds(-vp.X/vp.Zoom,-vp.Y/vp.Zoom,(width-vp.X)/vp.Zoom,(height-vp.Y)/vp.Zoom);
        var old=ds.Transform; var view=Matrix3x2.CreateScale((float)vp.Zoom)*Matrix3x2.CreateTranslation((float)vp.X,(float)vp.Y);
        foreach(var o in objects.OrderBy(o=>o.ZIndex))
        {
            if(o.IsVisible==false)continue;
            // Conservative radius handles rotation, stroke padding and sticky decorations.
            var radius=Math.Sqrt(o.Width*o.Width+o.Height*o.Height)/2+o.StrokeWidth+32;
            var cx=o.X+o.Width/2;var cy=o.Y+o.Height/2;
            if(!world.Intersects(new(cx-radius,cy-radius,cx+radius,cy+radius)))continue;
            ds.Transform=Matrix3x2.CreateRotation((float)(o.Rotation*Math.PI/180),new((float)cx,(float)cy))*view;
            RenderObject(ds,o);
        }
        ds.Transform=old;
    }
    private void RenderObject(CanvasDrawingSession ds,BoardObject o)
    {
        var rect=new Rect(o.X,o.Y,Math.Max(.1,o.Width),Math.Max(.1,o.Height));
        var stroke=HexToColor(o.StrokeColor,(float)o.Opacity);
        using var style=new CanvasStrokeStyle { StartCap=CanvasCapStyle.Round,EndCap=CanvasCapStyle.Round,LineJoin=CanvasLineJoin.Round,
            DashStyle=o.LineStyle switch {"dashed"=>CanvasDashStyle.Dash,"dotted"=>CanvasDashStyle.Dot,"dashdot"=>CanvasDashStyle.DashDot,_=>CanvasDashStyle.Solid} };
        if(o.Type is "stroke" or "pen" or "highlighter" or "paint" or "curve")
        {
            if(o.ParsedPoints.Count==1){var p=o.ParsedPoints[0];ds.FillCircle((float)p.X,(float)p.Y,(float)(o.StrokeWidth/2),stroke);return;}
            var key=o.Points??"";
            if(!_geometry.TryGetValue(o.Id,out var entry)||entry.Key!=key)
            {
                entry.Geometry?.Dispose(); var geometry=Path(ds,o.ParsedPoints,false,true);
                if(geometry is null)return;entry=(key,geometry);_geometry[o.Id]=entry;
            }
            ds.DrawGeometry(entry.Geometry,HexToColor(o.StrokeColor,(float)o.Opacity),(float)o.StrokeWidth,style);
            return;
        }
        using ICanvasBrush fill= !string.IsNullOrEmpty(o.FillGradientStart)&&!string.IsNullOrEmpty(o.FillGradientEnd)
            ? new CanvasLinearGradientBrush(ds,HexToColor(o.FillGradientStart,(float)(o.FillOpacity??o.Opacity)),HexToColor(o.FillGradientEnd,(float)(o.FillOpacity??o.Opacity)))
              {StartPoint=new((float)o.X,(float)o.Y),EndPoint=new((float)(o.X+o.Width),(float)(o.Y+o.Height))}
            : new CanvasSolidColorBrush(ds,HexToColor(o.FillColor,(float)(o.FillOpacity??o.Opacity)));
        switch(o.Type)
        {
            case "rect":ds.FillRectangle(rect,fill);ds.DrawRectangle(rect,stroke,(float)o.StrokeWidth,style);break;
            case "circle":
                ds.FillEllipse((float)(o.X+o.Width/2),(float)(o.Y+o.Height/2),(float)(o.Width/2),(float)(o.Height/2),fill);
                ds.DrawEllipse((float)(o.X+o.Width/2),(float)(o.Y+o.Height/2),(float)(o.Width/2),(float)(o.Height/2),stroke,(float)o.StrokeWidth,style);break;
            case "arc":
                var arcR = (float)(o.ArcRadius ?? (o.Width / 2.0));
                var arcCx = (float)(o.X + o.Width / 2.0);
                var arcCy = (float)(o.Y + o.Height / 2.0);
                var arcStart = (float)(o.ArcStartAngle ?? 0.0);
                var arcSweep = (float)(o.ArcSweepAngle ?? 360.0);
                if (Math.Abs(arcSweep) >= 360.0f)
                {
                    if (o.FillColor != "none") ds.FillEllipse(arcCx, arcCy, arcR, arcR, fill);
                    ds.DrawEllipse(arcCx, arcCy, arcR, arcR, stroke, (float)o.StrokeWidth, style);
                }
                else
                {
                    float startRad = arcStart * (float)Math.PI / 180.0f;
                    float sweepRad = arcSweep * (float)Math.PI / 180.0f;
                    float startX = arcCx + arcR * (float)Math.Cos(startRad);
                    float startY = arcCy + arcR * (float)Math.Sin(startRad);
                    using var arcBuilder = new CanvasPathBuilder(ds);
                    arcBuilder.BeginFigure(startX, startY);
                    arcBuilder.AddArc(new Vector2(arcCx, arcCy), arcR, arcR, startRad, sweepRad);
                    arcBuilder.EndFigure(CanvasFigureLoop.Open);
                    using var arcGeom = CanvasGeometry.CreatePath(arcBuilder);
                    ds.DrawGeometry(arcGeom, stroke, (float)o.StrokeWidth, style);
                }
                break;
            case "line": case "arrow":
                var a=new Vector2((float)(o.X1??o.X),(float)(o.Y1??o.Y));var b=new Vector2((float)(o.X2??o.X+o.Width),(float)(o.Y2??o.Y+o.Height));
                ds.DrawLine(a,b,stroke,(float)o.StrokeWidth,style);
                if(o.Type=="arrow" && Vector2.Distance(a,b)>.01f)
                {
                    var d=Vector2.Normalize(b-a);var n=new Vector2(-d.Y,d.X);var len=(float)(o.ArrowHeadLength??Math.Max(12,o.StrokeWidth*4));var w=(float)(o.ArrowHeadWidth??len*.5);
                    ds.DrawLine(b,b-d*len+n*w/2,stroke,(float)o.StrokeWidth,style);ds.DrawLine(b,b-d*len-n*w/2,stroke,(float)o.StrokeWidth,style);
                }break;
            case "triangle":case "quadrilateral":case "diamond":case "pentagon":case "star":
                using(var path=Path(ds,Polygon(o),true,false))if(path is not null){ds.FillGeometry(path,fill);ds.DrawGeometry(path,stroke,(float)o.StrokeWidth,style);}break;
            case "text":RenderText(ds,o,rect,stroke);break;
            case "sticky":
                ds.FillRoundedRectangle(rect,6,6,HexToColor(o.FillColor=="none"?"#fff0ab":o.FillColor,(float)o.Opacity));
                ds.DrawRoundedRectangle(rect,6,6,HexToColor("#314d3f",.2f),1);
                RenderText(ds,o,new Rect(o.X+12,o.Y+12,Math.Max(1,o.Width-24),Math.Max(1,o.Height-24)),stroke);break;
            case "image":
                if(o.ImageUrl is not null && _images.TryGetValue(o.ImageUrl,out var bitmap))ds.DrawImage(bitmap,rect,new Rect(0,0,bitmap.SizeInPixels.Width,bitmap.SizeInPixels.Height),(float)o.Opacity);
                else ds.DrawRectangle(rect,HexToColor("#7d9386"),1);break;
            case "pin":DrawPin(ds,new((float)(o.X+o.Width/2),(float)(o.Y+o.Height/2)),1);break;
        }
    }
    private static void RenderText(CanvasDrawingSession ds,BoardObject o,Rect rect,Color color)
    {
        using var format=new CanvasTextFormat { FontFamily=o.FontFamily?.Split(',')[0]??"Microsoft JhengHei",FontSize=(float)(o.FontSize??18),
            FontWeight=new global::Windows.UI.Text.FontWeight {Weight=(ushort)(o.IsBold==true?700:400)},
            FontStyle=o.IsItalic==true?global::Windows.UI.Text.FontStyle.Italic:global::Windows.UI.Text.FontStyle.Normal,
            HorizontalAlignment=o.Align switch {"center"=>CanvasHorizontalAlignment.Center,"right"=>CanvasHorizontalAlignment.Right,_=>CanvasHorizontalAlignment.Left},WordWrapping=CanvasWordWrapping.Wrap };
        ds.DrawText(o.Text??"",rect,color,format);
    }
    public static IReadOnlyList<InkPoint> Polygon(BoardObject o)
    {
        if(o.ParsedPoints.Count>0)return o.ParsedPoints;
        var n=o.Type=="triangle"?3:o.Type=="pentagon"?5:o.Type=="star"?10:4;
        return Enumerable.Range(0,n).Select(i=>{var a=-Math.PI/2+i*Math.PI*2/n;var r=o.Type=="star"&&i%2==1?.45:1;
            return new InkPoint(o.X+o.Width/2+Math.Cos(a)*o.Width/2*r,o.Y+o.Height/2+Math.Sin(a)*o.Height/2*r);}).ToArray();
    }
    private static CanvasGeometry? Path(ICanvasResourceCreator device,IReadOnlyList<InkPoint> pts,bool closed,bool smooth)
    {
        if(pts.Count==0)return null;
        using var b=new CanvasPathBuilder(device);b.BeginFigure((float)pts[0].X,(float)pts[0].Y);
        for(var i=1;i<pts.Count;i++)
        {
            if(!smooth){b.AddLine((float)pts[i].X,(float)pts[i].Y);continue;}
            var p0=pts[Math.Max(0,i-2)];var p1=pts[i-1];var p2=pts[i];var p3=pts[Math.Min(pts.Count-1,i+1)];
            b.AddCubicBezier(new((float)(p1.X+(p2.X-p0.X)/6),(float)(p1.Y+(p2.Y-p0.Y)/6)),
                new((float)(p2.X-(p3.X-p1.X)/6),(float)(p2.Y-(p3.Y-p1.Y)/6)),new((float)p2.X,(float)p2.Y));
        }
        b.EndFigure(closed?CanvasFigureLoop.Closed:CanvasFigureLoop.Open);return CanvasGeometry.CreatePath(b);
    }
    public void RenderLiveStroke(CanvasDrawingSession ds,IReadOnlyList<InkPoint> points,ViewportTransform vp,string color,double width,double opacity)
    {
        if(points.Count==0)return;
        if(!ReferenceEquals(_liveFirst,points[0]) || points.Count<=_liveEnd){ResetLive();_liveFirst=points[0];}
        // A cubic segment becomes stable once its next sample is present. Cache 64-segment blocks.
        while(points.Count-2-_liveEnd>=64)
        {_liveBlocks.Add(SegmentPath(ds,points,_liveEnd+1,_liveEnd+64));_liveEnd+=64;}
        var old=ds.Transform;ds.Transform=Matrix3x2.CreateScale((float)vp.Zoom)*Matrix3x2.CreateTranslation((float)vp.X,(float)vp.Y);
        using var style=new CanvasStrokeStyle{StartCap=CanvasCapStyle.Round,EndCap=CanvasCapStyle.Round,LineJoin=CanvasLineJoin.Round};
        var ink=HexToColor(color,(float)opacity);
        // One opacity layer prevents translucent highlighter blocks accumulating alpha at joins.
        using(var layer=ds.CreateLayer((float)opacity))
        {
            ink=HexToColor(color);
            foreach(var block in _liveBlocks)ds.DrawGeometry(block,ink,(float)width,style);
            if(points.Count>1){using var tail=SegmentPath(ds,points,_liveEnd+1,points.Count-1);ds.DrawGeometry(tail,ink,(float)width,style);}
            else ds.FillCircle((float)points[0].X,(float)points[0].Y,(float)(width/2),ink);
        }
        ds.Transform=old;
    }
    private static CanvasGeometry SegmentPath(ICanvasResourceCreator device,IReadOnlyList<InkPoint> points,int start,int end)
    {
        using var path=new CanvasPathBuilder(device);var first=points[start-1];path.BeginFigure((float)first.X,(float)first.Y);
        for(var i=start;i<=end;i++)
        {
            var a=points[Math.Max(0,i-2)];var b=points[i-1];var c=points[i];var d=points[Math.Min(points.Count-1,i+1)];
            path.AddCubicBezier(new((float)(b.X+(c.X-a.X)/6),(float)(b.Y+(c.Y-a.Y)/6)),
                new((float)(c.X-(d.X-b.X)/6),(float)(c.Y-(d.Y-b.Y)/6)),new((float)c.X,(float)c.Y));
        }
        path.EndFigure(CanvasFigureLoop.Open);return CanvasGeometry.CreatePath(path);
    }
    public void RenderSelection(CanvasDrawingSession ds,BoardObject? o,ViewportTransform vp)
    {
        if(o is null)return;
        Vector2 Screen(InkPoint p){var s=vp.WorldToScreen(p.X,p.Y);return new((float)s.X,(float)s.Y);}
        var blue=HexToColor("#328dce");var white=HexToColor("#ffffff");
        if(o.Type is not ("line" or "arrow"))
        {
            var outline=ObjectHandles.Outline(o).Select(Screen).ToArray();
            for(var i=0;i<4;i++)ds.DrawLine(outline[i],outline[(i+1)%4],blue,1.5f);
        }
        using var label=new CanvasTextFormat{FontSize=11,FontFamily="Segoe UI"};
        foreach(var handle in ObjectHandles.Get(o,vp.Zoom))
        {
            var p=Screen(handle.Point);
            if(handle.Kind=="rotate")
            {
                ds.DrawLine(Screen(ObjectHandles.ToWorld(o,new(o.X+o.Width/2,o.Y))),p,blue,1);
                ds.FillCircle(p,7,white);ds.DrawCircle(p,7,blue,1.5f);
            }
            else if(handle.Kind=="resize")
            {ds.FillRectangle(p.X-4,p.Y-4,8,8,white);ds.DrawRectangle(p.X-4,p.Y-4,8,8,blue,1.5f);}
            else if(handle.Kind is "arc_start" or "arc_end")
            {
                var orange=HexToColor("#f97316");
                ds.FillCircle(p,6,white);ds.DrawCircle(p,6,orange,2f);
                ds.DrawText(handle.Kind=="arc_start"?"起":"訖",p.X+8,p.Y-14,orange,label);
            }
            else
            {
                ds.FillCircle(p,6,white);ds.DrawCircle(p,6,blue,1.5f);
                if(handle.Kind=="endpoint")ds.DrawText(handle.Index==0?"A":"B",p.X+9,p.Y-18,blue,label);
            }
        }
    }
    public void RenderCompass(CanvasDrawingSession ds,CompassToolEngine compass,ViewportTransform vp)
    {
        if(!compass.IsEnabled)return;
        var centerScreen=vp.WorldToScreen(compass.Center.X,compass.Center.Y);
        var cx=(float)centerScreen.X;var cy=(float)centerScreen.Y;
        var radiusScreen=(float)(compass.Radius*vp.Zoom);if(radiusScreen<2)radiusScreen=2;
        var guideColor=HexToColor("#06b6d4",.45f);
        var accentColor=HexToColor("#328dce");
        var orangeColor=HexToColor("#f97316");
        var whiteColor=HexToColor("#ffffff");
        using(var guideStyle=new CanvasStrokeStyle{DashStyle=CanvasDashStyle.Dash})
        {
            ds.DrawEllipse(cx,cy,radiusScreen,radiusScreen,guideColor,1.5f,guideStyle);
        }
        if(compass.IsDrawingArc&&Math.Abs(compass.SweepAngle)>.1)
        {
            var startRad=(float)(compass.StartAngle*Math.PI/180.0);
            var sweepRad=(float)(compass.SweepAngle*Math.PI/180.0);
            var arcStartPx=cx+radiusScreen*(float)Math.Cos(startRad);
            var arcStartPy=cy+radiusScreen*(float)Math.Sin(startRad);
            using var arcBuilder=new CanvasPathBuilder(ds);
            arcBuilder.BeginFigure(arcStartPx,arcStartPy);
            arcBuilder.AddArc(new Vector2(cx,cy),radiusScreen,radiusScreen,startRad,sweepRad);
            arcBuilder.EndFigure(CanvasFigureLoop.Open);
            using var arcGeom=CanvasGeometry.CreatePath(arcBuilder);
            var strokeCol=HexToColor(compass.StrokeColor);
            var strokeW=(float)(compass.StrokeWidth*vp.Zoom);
            using var arcStyle=new CanvasStrokeStyle
            {
                StartCap=CanvasCapStyle.Round,
                EndCap=CanvasCapStyle.Round,
                DashStyle=compass.LineStyle switch{"dashed"=>CanvasDashStyle.Dash,"dotted"=>CanvasDashStyle.Dot,_=>CanvasDashStyle.Solid}
            };
            ds.DrawGeometry(arcGeom,strokeCol,strokeW,arcStyle);
        }
        var rx=cx+radiusScreen*.65f;var ry=cy;
        ds.DrawLine(cx,cy,rx,ry,HexToColor("#06b6d4",.35f),1f);
        ds.FillCircle(rx,ry,9,whiteColor);ds.DrawCircle(rx,ry,9,accentColor,2f);
        using(var textFormat=new CanvasTextFormat{FontSize=10,FontFamily="Segoe UI Variable, Segoe UI",FontWeight=Microsoft.UI.Text.FontWeights.SemiBold})
        {
            var rLabel=$"R: {(int)Math.Round(compass.Radius)} pt";
            ds.DrawText(rLabel,rx+12,ry-7,HexToColor("#243c33"),textFormat);
        }
        var centerFill=compass.IsArmed?orangeColor:whiteColor;
        var centerStroke=compass.IsArmed?orangeColor:accentColor;
        var innerDot=compass.IsArmed?whiteColor:accentColor;
        ds.FillCircle(cx,cy,11,centerFill);ds.DrawCircle(cx,cy,11,centerStroke,2f);ds.FillCircle(cx,cy,3.5f,innerDot);
        var pencilRad=(float)(compass.CurrentPencilAngle*Math.PI/180.0);
        var px=cx+radiusScreen*(float)Math.Cos(pencilRad);var py=cy+radiusScreen*(float)Math.Sin(pencilRad);
        ds.DrawLine(cx,cy,px,py,HexToColor("#f97316",.35f),1f);
        var pencilTipCol=HexToColor(compass.StrokeColor);
        ds.FillCircle(px,py,12,pencilTipCol);ds.DrawCircle(px,py,12,whiteColor,2f);ds.FillCircle(px,py,3.5f,whiteColor);
        var pillText=compass.IsArmed?"● 圓心已鎖定 · 拖筆尖畫弧":"○ 準備階段 · 點圓心鎖定";
        using(var pillFormat=new CanvasTextFormat{FontSize=11,FontFamily="Segoe UI Variable, Segoe UI",FontWeight=Microsoft.UI.Text.FontWeights.Medium})
        {
            var pillBg=compass.IsArmed?HexToColor("#ffedd5",.92f):HexToColor("#f0fdf4",.92f);
            var pillBorder=compass.IsArmed?HexToColor("#f97316"):HexToColor("#22c55e");
            var pillFg=compass.IsArmed?HexToColor("#c2410c"):HexToColor("#15803d");
            var pillRect=new Rect(cx-70,cy+18,140,22);
            ds.FillRoundedRectangle(pillRect,6,6,pillBg);ds.DrawRoundedRectangle(pillRect,6,6,pillBorder,1);
            ds.DrawText(pillText,(float)pillRect.X+6,(float)pillRect.Y+3,pillFg,pillFormat);
        }
    }
    public static void DrawPin(CanvasDrawingSession ds,Vector2 center,float scale)
    {
        var old=ds.Transform;ds.Transform=Matrix3x2.CreateRotation(MathF.PI*35/180)*Matrix3x2.CreateScale(scale)*Matrix3x2.CreateTranslation(center)*old;
        var blue=HexToColor("#39b9dc");var green=HexToColor("#234b43");
        ds.DrawLine(0,8,0,19,HexToColor("#dce8e3"),3);ds.FillEllipse(0,7,10,3,blue);ds.DrawEllipse(0,7,10,3,green,1.2f);
        ds.FillRectangle(-5,-6,10,13,blue);ds.DrawRectangle(-5,-6,10,13,green,1.2f);ds.FillEllipse(0,-6,7,3,blue);ds.DrawEllipse(0,-6,7,3,green,1.2f);ds.Transform=old;
    }
    public void RenderHover(CanvasDrawingSession ds,Vector2 pointer,bool eraser,double diameter,ViewportTransform vp)
    {
        var r=(float)(diameter*vp.Zoom/2);ds.FillCircle(pointer,r,HexToColor(eraser?"#f46e87":"#396a53",.22f));
        ds.DrawCircle(pointer,r,HexToColor(eraser?"#cf4860":"#ffffff"),1.2f);ds.DrawCircle(pointer,r+1,HexToColor("#234b43"),.6f);
    }
    public void RenderLaser(CanvasDrawingSession ds,LaserPointerEngine laser,ViewportTransform vp,double now)
    {
        var samples=laser.Samples;
        if(samples.Count==0)return;
        for(var i=0;i<samples.Count;i++)
        {
            var sample=samples[i];var position=vp.WorldToScreen(sample.Point.X,sample.Point.Y);
            var point=new Vector2((float)position.X,(float)position.Y);
            var opacity=(float)Math.Clamp(1-(now-sample.Timestamp)/Math.Clamp(laser.FadeDuration,.1,10),0,1);
            if(laser.Mode!="point"&&i>0&&!sample.StartsTrail)
            {
                var previous=vp.WorldToScreen(samples[i-1].Point.X,samples[i-1].Point.Y);
                ds.DrawLine(new((float)previous.X,(float)previous.Y),point,HexToColor(laser.Color,opacity),(float)laser.Width);
                if(laser.WhiteCore)ds.DrawLine(new((float)previous.X,(float)previous.Y),point,HexToColor("#FFFFFF",opacity*.85f),(float)laser.Width*.25f);
            }
            if(i==samples.Count-1)
            {
                var radius=(float)laser.PointDiameter/2;
                ds.FillCircle(point,radius*1.4f,HexToColor(laser.Color,opacity*.2f));
                ds.FillCircle(point,radius,HexToColor(laser.Color,opacity));
                if(laser.WhiteCore)ds.FillCircle(point,radius*.28f,HexToColor("#FFFFFF",opacity));
            }
        }
    }

}
