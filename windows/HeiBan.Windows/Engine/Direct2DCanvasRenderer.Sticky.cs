using System.Numerics;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Brushes;
using Microsoft.Graphics.Canvas.Geometry;
using global::Windows.Foundation;

namespace HeiBan.Windows.Engine;

public sealed partial class Direct2DCanvasRenderer
{
    private static void RenderStickyPaper(CanvasDrawingSession ds,BoardObject o,Rect rect)
    {
        var opacity=(float)Math.Clamp(o.Opacity,0,1);var color=HexToColor(o.FillColor=="none"?"#FFF0AB":o.FillColor,(float)(o.FillOpacity??o.Opacity));
        var corner=o.StickyStyle=="soft"?12:2;
        // Decorations stay within the existing conservative cull padding and follow object rotation.
        for(var i=4;i>=1;i--)ds.FillRoundedRectangle(new Rect(rect.X+i,rect.Y+i*1.5,rect.Width,rect.Height),corner+1,corner+1,HexToColor("#243A2C",opacity*.035f));
        var light=color;light.R=(byte)(color.R+(255-color.R)*.12);light.G=(byte)(color.G+(255-color.G)*.12);light.B=(byte)(color.B+(255-color.B)*.12);
        var alpha=(float)(o.FillOpacity??o.Opacity);
        using var paper=new CanvasLinearGradientBrush(ds,o.FillGradientStart is null?light:HexToColor(o.FillGradientStart,alpha),o.FillGradientEnd is null?color:HexToColor(o.FillGradientEnd,alpha)){StartPoint=new((float)rect.X,(float)rect.Y),EndPoint=new((float)rect.X,(float)rect.Bottom)};
        ds.FillRoundedRectangle(rect,corner,corner,paper);ds.DrawRoundedRectangle(rect,corner,corner,HexToColor("#665835",opacity*.2f),.7f);
        ds.FillRectangle(new Rect(rect.X+1,rect.Y+1,Math.Max(1,rect.Width-2),Math.Min(22,rect.Height/5)),HexToColor("#9E8140",opacity*.07f));
        if(o.StickyStyle is "notebook" or "grid")
        {
            for(var y=rect.Y+36;y<rect.Bottom-8;y+=22)ds.DrawLine((float)rect.X+10,(float)y,(float)rect.Right-10,(float)y,HexToColor("#516A72",opacity*.14f),.7f);
            if(o.StickyStyle=="grid")for(var x=rect.X+32;x<rect.Right-8;x+=22)ds.DrawLine((float)x,(float)rect.Y+24,(float)x,(float)rect.Bottom-8,HexToColor("#516A72",opacity*.12f),.7f);
            else ds.DrawLine((float)rect.X+26,(float)rect.Y+24,(float)rect.X+26,(float)rect.Bottom-8,HexToColor("#C47872",opacity*.2f),1);
        }
        if(o.StickyStyle=="washi")
        {
            var tape=new Rect(rect.X+rect.Width*.22,rect.Y-7,rect.Width*.56,20);
            ds.FillRectangle(tape,HexToColor("#B0C9BF",opacity*.75f));
            using var clip=ds.CreateLayer(1,tape);
            for(var x=tape.X-20;x<tape.Right;x+=14)ds.DrawLine((float)x,(float)tape.Bottom,(float)x+20,(float)tape.Y,HexToColor("#FFFFFF",opacity*.28f),5);
        }
        else if(o.StickyStyle=="cat")
        {
            using var ears=new CanvasPathBuilder(ds);ears.BeginFigure(new Vector2((float)rect.X+8,(float)rect.Y+3));ears.AddLine(new Vector2((float)rect.X+12,(float)rect.Y-9));ears.AddLine(new Vector2((float)rect.X+26,(float)rect.Y+3));ears.EndFigure(CanvasFigureLoop.Closed);
            ears.BeginFigure(new Vector2((float)rect.Right-26,(float)rect.Y+3));ears.AddLine(new Vector2((float)rect.Right-12,(float)rect.Y-9));ears.AddLine(new Vector2((float)rect.Right-8,(float)rect.Y+3));ears.EndFigure(CanvasFigureLoop.Closed);
            using var geometry=CanvasGeometry.CreatePath(ears);ds.FillGeometry(geometry,paper);
        }
        else if(o.StickyStyle is null or "classic")
        {
            var fold=(float)Math.Min(20,Math.Min(rect.Width,rect.Height)/5);
            using var path=new CanvasPathBuilder(ds);path.BeginFigure(new Vector2((float)rect.Right-fold,(float)rect.Bottom));path.AddLine(new Vector2((float)rect.Right-fold,(float)rect.Bottom-fold));path.AddLine(new Vector2((float)rect.Right,(float)rect.Bottom-fold));path.EndFigure(CanvasFigureLoop.Closed);
            using var curl=CanvasGeometry.CreatePath(path);ds.FillGeometry(curl,HexToColor("#FFFFFF",opacity*.55f));ds.DrawGeometry(curl,HexToColor("#8D7647",opacity*.24f),.7f);
        }
    }
}
