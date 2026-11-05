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
        var bounds=new Rect(at.X-210*density,at.Y-210*density,250*density,250*density);
        if(cane.CrackGrip is { } anchor&&now<cane.CrackStartedAt+CaneFeedback.CrackDuration)
        {
            var center=CrackCenter(anchor,viewport,density);var visual=CaneCrackGeometry.VisualBounds;
            bounds.Union(new Rect(center.X+visual.Left*density,center.Y+visual.Top*density,visual.Width*density,visual.Height*density));
        }
        return bounds;
    }
    private static Vector2 CrackCenter(InkPoint grip,ViewportTransform viewport,double density)
    {
        var at=viewport.WorldToScreen(grip.X,grip.Y);
        // Shipped cane: 180 DIP wide, upper-left tip at impact angle 45 degrees.
        var length=Math.Sqrt(156*156+Math.Pow(180*984d/1600*.83,2));
        var offset=(float)(length/Math.Sqrt(2)*density);
        return new((float)at.X-offset,(float)at.Y-offset);
    }
    private CanvasGeometry? _caneShard;
    private void ClearCaneShard(){_caneShard?.Dispose();_caneShard=null;}
    private void RenderCaneCrack(CanvasDrawingSession ds,CaneFeedback cane,ViewportTransform viewport,double now,double density)
    {
        if(cane.CrackGrip is not { } anchor||cane.CrackOpacity(now) is not >0)return;
        var center=CrackCenter(anchor,viewport,density);var alpha=(float)cane.CrackOpacity(now);var scale=(float)density;
        foreach(var segment in CaneCrackGeometry.Segments)
        {
            var a=center+new Vector2((float)segment.X1,(float)segment.Y1)*scale*(float)CaneCrackGeometry.DisplayScale;
            var b=center+new Vector2((float)segment.X2,(float)segment.Y2)*scale*(float)CaneCrackGeometry.DisplayScale;
            ds.DrawLine(a,b,HexToColor("#263C37",alpha*.85f),1.5f*scale);
            ds.DrawLine(a+new Vector2(.4f,.4f)*scale,b+new Vector2(.4f,.4f)*scale,HexToColor("#FFFFFF",alpha*.95f),.7f*scale);
        }
        var elapsed=now-cane.CrackStartedAt;
        for(var i=0;i<CaneCrackGeometry.ShardCount;i++)
        {
            var p=CaneCrackGeometry.Particle(i,elapsed);if(p.Opacity<=0)continue;
            var at=center+new Vector2((float)p.X,(float)p.Y)*scale;
            var radius=(float)p.Size*scale;
            var shade=HexToColor("#FFFFFF",(float)p.Opacity*.9f);var edge=HexToColor("#36574B",(float)p.Opacity*.7f);
            _caneShard??=CanvasGeometry.CreatePolygon(ds,[new Vector2(1,0),new Vector2(-.65f,.7f),new Vector2(-.8f,-.45f)]);
            var old=ds.Transform;
            ds.Transform=Matrix3x2.CreateScale(radius)*Matrix3x2.CreateRotation((float)p.Angle)*Matrix3x2.CreateTranslation(at)*old;
            try{ds.FillGeometry(_caneShard,shade);ds.DrawGeometry(_caneShard,edge,.65f*scale/radius);}
            finally{ds.Transform=old;}
        }
    }
    internal void RenderCane(CanvasDrawingSession ds,CaneFeedback cane,ViewportTransform viewport,double now,double density=1)
    {
        if(cane.Point is not { } point)return;
        RenderCaneCrack(ds,cane,viewport,now,density);
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
