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
        if(cane.Point is not { } point)return null;
        var at=viewport.WorldToScreen(point.X,point.Y);
        // Includes the entire swing about its handle and the short impact rays.
        return new(at.X-210*density,at.Y-210*density,250*density,250*density);
    }
    internal void RenderCane(CanvasDrawingSession ds,CaneFeedback cane,ViewportTransform viewport,double now,double density=1)
    {
        if(cane.Point is not { } point)return;
        var elapsed=now-cane.StartedAt;var at=viewport.WorldToScreen(point.X,point.Y);
        // Input follows the lower-right hand grip, never the free upper-left tip.
        var grip=new Vector2((float)at.X,(float)at.Y);var scale=(float)density;
        var swinging=cane.IsActive(now);
        var restRotation=_caneArt is { } artwork?CanePose.ArtworkRestRotationDegrees(artwork.Bounds.Width,artwork.Bounds.Height):CanePose.RestDegrees-Math.Atan2(98,156)*180/Math.PI;
        var angle=(restRotation+CanePose.SwingDegrees(elapsed))*Math.PI/180;
        var rotation=Matrix3x2.CreateRotation((float)angle);
        var restHeight=_caneArt is { } art?180*(float)(art.Bounds.Height/art.Bounds.Width)*.83f:98;
        var tip=grip+Vector2.Transform(new Vector2(-156,-restHeight)*scale,rotation);
        var bend=(tip+grip)/2+Vector2.Transform(new Vector2(-3,3)*scale,rotation);
        const float opacity=1;
        if(_caneArt is { } sprite)
        {
            var old=ds.Transform;
            ds.Transform=Matrix3x2.CreateTranslation(-grip)*rotation*Matrix3x2.CreateTranslation(grip)*old;
            var width=180*scale;var height=width*sprite.Bounds.Height/sprite.Bounds.Width;
            try{ds.DrawImage(sprite,new Rect(grip.X-width*.92,grip.Y-height*.90,width,height),sprite.Bounds);}
            finally{ds.Transform=old;}
        }
        else
        {
            using var builder=new CanvasPathBuilder(ds);builder.BeginFigure(grip);builder.AddQuadraticBezier(bend,tip);builder.EndFigure(CanvasFigureLoop.Open);
            using var path=CanvasGeometry.CreatePath(builder);
            using var style=new CanvasStrokeStyle{StartCap=CanvasCapStyle.Round,EndCap=CanvasCapStyle.Round};
            ds.DrawGeometry(path,HexToColor("#FFFFFF",opacity*.85f),7*scale,style);
            ds.DrawGeometry(path,HexToColor("#795333",opacity),4.2f*scale,style);
            ds.DrawGeometry(path,HexToColor("#D7AE72",opacity),1.9f*scale,style);
            var direction=Vector2.Normalize(tip-grip);var across=new Vector2(-direction.Y,direction.X);
            for(var i=1;i<7;i++)
            {var p=Vector2.Lerp(grip,tip,i/7f);ds.DrawLine(p-across*2.3f*scale,p+across*2.3f*scale,HexToColor("#805C3B",opacity),1.2f*scale);}
            ds.DrawLine(grip,Vector2.Lerp(grip,tip,.18f),HexToColor("#78907C"),7*scale,style);
        }
        if(swinging&&elapsed is >=.065 and <.16)
        {
            var flash=(float)(1-(elapsed-.065)/.095);
            for(var i=0;i<5;i++)
            {var a=(float)(i*Math.PI*.4-.4);var d=new Vector2(MathF.Cos(a),MathF.Sin(a));ds.DrawLine(tip+d*10*scale,tip+d*(16+9*(1-flash))*scale,HexToColor("#C79145",flash),1.8f*scale);}
        }
    }
}
