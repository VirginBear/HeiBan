using System.Numerics;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using global::Windows.Foundation;

namespace HeiBan.Windows.Engine;

public sealed partial class Direct2DCanvasRenderer
{
    internal static Rect? CaneBounds(CaneFeedback cane,ViewportTransform viewport,double now,double density=1)
    {
        if(!cane.IsActive(now)||cane.Point is not { } point)return null;
        var at=viewport.WorldToScreen(point.X,point.Y);
        // Includes the entire swing about its handle and the short impact rays.
        return new(at.X-270*density,at.Y-270*density,360*density,360*density);
    }
    internal void RenderCane(CanvasDrawingSession ds,CaneFeedback cane,ViewportTransform viewport,double now,double density=1)
    {
        if(!cane.IsActive(now)||cane.Point is not { } point)return;
        var elapsed=now-cane.StartedAt;var at=viewport.WorldToScreen(point.X,point.Y);
        var hit=new Vector2((float)at.X,(float)at.Y);var scale=(float)density;
        var grip=hit-new Vector2(100,100)*scale;
        var angle=elapsed<.075?-1.05*Math.Pow(1-elapsed/.075,2):-.28*Math.Sin(Math.Min(1,(elapsed-.075)/.20)*Math.PI);
        var rotation=Matrix3x2.CreateRotation((float)angle);
        var tip=grip+Vector2.Transform(new Vector2(100,100)*scale,rotation);
        var bend=(tip+grip)/2+Vector2.Transform(new Vector2(-3,6)*scale,rotation);
        var opacity=(float)Math.Clamp((CaneFeedback.Duration-elapsed)/.09,0,1);
        using var builder=new CanvasPathBuilder(ds);builder.BeginFigure(grip);builder.AddQuadraticBezier(bend,tip);builder.EndFigure(CanvasFigureLoop.Open);
        using var path=CanvasGeometry.CreatePath(builder);
        using var style=new CanvasStrokeStyle{StartCap=CanvasCapStyle.Round,EndCap=CanvasCapStyle.Round};
        ds.DrawGeometry(path,HexToColor("#FFFFFF",opacity*.85f),7*scale,style);
        ds.DrawGeometry(path,HexToColor("#795333",opacity),4.2f*scale,style);
        ds.DrawGeometry(path,HexToColor("#D7AE72",opacity),1.9f*scale,style);
        var direction=Vector2.Normalize(tip-grip);var across=new Vector2(-direction.Y,direction.X);
        for(var i=1;i<7;i++)
        {var p=Vector2.Lerp(grip,tip,i/7f);ds.DrawLine(p-across*2.3f*scale,p+across*2.3f*scale,HexToColor("#805C3B",opacity),1.2f*scale);}
        if(elapsed is >=.065 and <.17)
        {
            var flash=(float)(1-(elapsed-.065)/.105);
            for(var i=0;i<5;i++)
            {var a=(float)(i*Math.PI*.4-.4);var d=new Vector2(MathF.Cos(a),MathF.Sin(a));ds.DrawLine(hit+d*10*scale,hit+d*(16+9*(1-flash))*scale,HexToColor("#C79145",flash),1.8f*scale);}
        }
    }
}
