using System.Numerics;
using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Brushes;
using Microsoft.Graphics.Canvas.Effects;
using Microsoft.Graphics.Canvas.Geometry;

namespace HeiBan.Windows.Engine;

public sealed partial class Direct2DCanvasRenderer
{
    private readonly record struct LaserKnot(Vector2 Point,double Timestamp);
    private readonly List<LaserKnot> _laserRaw=[],_laserSmooth=[];
    private readonly List<Vector2> _laserLeft=[],_laserRight=[];
    private CanvasRadialGradientBrush? _laserTipBrush;
    private (string Color,bool WhiteCore) _laserTipStyle;

    public void RenderLaser(CanvasDrawingSession ds,LaserPointerEngine laser,ViewportTransform vp,double now,double density=1)
    {
        if(laser.Samples.Count==0)return;
        using var trace=InputLatencyTrace.Measure(InputStage.LaserRender);
        var samples=laser.Samples;var width=(float)(laser.Width*density);
        var lifetime=laser.Lifetime;
        if(laser.Mode!="point")
        {
            _laserRaw.Clear();
            foreach(var sample in samples)
            {
                if(sample.StartsTrail&&_laserRaw.Count>0){RenderLaserTrail(ds,laser,width,now,lifetime,(float)density);_laserRaw.Clear();}
                var at=vp.WorldToScreen(sample.Point.X,sample.Point.Y);
                _laserRaw.Add(new(new((float)at.X,(float)at.Y),laser.IsPressed&&ReferenceEquals(sample,samples[^1])?now:sample.Timestamp));
            }
            if(_laserRaw.Count>0)RenderLaserTrail(ds,laser,width,now,lifetime,(float)density);
        }
        var last=samples[^1];var opacity=laser.IsPressed?1:LaserFreshness(now,last.Timestamp,lifetime);
        if(opacity<=0)return;
        var position=vp.WorldToScreen(last.Point.X,last.Point.Y);
        if(_laserTipBrush is null||_laserTipStyle!=(laser.Color,laser.WhiteCore))
        {
            _laserTipBrush?.Dispose();
            _laserTipBrush=new CanvasRadialGradientBrush(ds,new CanvasGradientStop[]
            {
                new(){Position=0,Color=HexToColor(laser.WhiteCore?"#FFFFFF":laser.Color)},
                new(){Position=.24f,Color=HexToColor(laser.Color)},
                new(){Position=.42f,Color=HexToColor(laser.Color,.5f)},
                new(){Position=1,Color=HexToColor(laser.Color,0)}
            });
            _laserTipStyle=(laser.Color,laser.WhiteCore);
        }
        var tipRadius=(float)(laser.PointDiameter*density*1.2);
        _laserTipBrush.Center=new((float)position.X,(float)position.Y);
        _laserTipBrush.RadiusX=_laserTipBrush.RadiusY=tipRadius;_laserTipBrush.Opacity=opacity;
        ds.FillCircle(_laserTipBrush.Center,tipRadius,_laserTipBrush);
    }

    private void RenderLaserTrail(CanvasDrawingSession ds,LaserPointerEngine laser,float width,double now,double lifetime,float density)
    {
        if(_laserRaw.Count<2)return;
        var opacity=LaserFreshness(now,_laserRaw[^1].Timestamp,lifetime);if(opacity<=0)return;
        SmoothLaser(density);
        // One continuous ribbon avoids per-segment seams. A quadratic midpoint
        // construction stays inside the input hull instead of overshooting corners.
        using var glow=LaserRibbon(ds,width*2,now,lifetime);
        using(var commands=new CanvasCommandList(ds))
        {
            using(var draw=commands.CreateDrawingSession())draw.FillGeometry(glow,HexToColor(laser.Color,opacity*.55f));
            using var blur=new GaussianBlurEffect{Source=commands,BlurAmount=Math.Max(2*density,width*.8f),Optimization=EffectOptimization.Speed,BorderMode=EffectBorderMode.Soft};
            ds.DrawImage(blur);
        }
        using var body=LaserRibbon(ds,width,now,lifetime);
        ds.FillGeometry(body,HexToColor(laser.Color,opacity));
        if(laser.WhiteCore)
        {
            using var core=LaserRibbon(ds,Math.Max(.5f*density,width*.24f),now,lifetime);
            ds.FillGeometry(core,HexToColor("#FFFFFF",opacity*.85f));
        }
    }

    private static float LaserFreshness(double now,double timestamp,double lifetime)=>(float)Math.Clamp(1-(now-timestamp)/lifetime,0,1);
    private void SmoothLaser(float density)
    {
        _laserSmooth.Clear();_laserSmooth.Add(_laserRaw[0]);var start=_laserRaw[0];
        for(var i=0;i<_laserRaw.Count;i++)
        {
            var control=_laserRaw[i];var end=i+1<_laserRaw.Count?MixLaser(control,_laserRaw[i+1],.5f):control;
            var length=Vector2.Distance(start.Point,control.Point)+Vector2.Distance(control.Point,end.Point);
            var steps=Math.Clamp((int)Math.Ceiling(length/Math.Max(.1f,3*density)),1,24);
            for(var j=1;j<=steps;j++)
            {
                var t=(float)j/steps;var knot=MixLaser(MixLaser(start,control,t),MixLaser(control,end,t),t);
                if(Vector2.DistanceSquared(_laserSmooth[^1].Point,knot.Point)<.04f*density*density)_laserSmooth[^1]=knot;
                else _laserSmooth.Add(knot);
            }
            start=end;
        }
    }
    private static LaserKnot MixLaser(LaserKnot a,LaserKnot b,float t)=>new(Vector2.Lerp(a.Point,b.Point,t),a.Timestamp+(b.Timestamp-a.Timestamp)*t);
    private Vector2 LaserTangent(int i)
    {
        var vector=_laserSmooth[Math.Min(i+1,_laserSmooth.Count-1)].Point-_laserSmooth[Math.Max(i-1,0)].Point;
        return vector/Math.Max(.001f,vector.Length());
    }
    private CanvasGeometry LaserRibbon(ICanvasResourceCreator device,float width,double now,double lifetime)
    {
        _laserLeft.Clear();_laserRight.Clear();
        for(var i=0;i<_laserSmooth.Count;i++)
        {
            var knot=_laserSmooth[i];var tangent=LaserTangent(i);
            var radius=width*.5f*MathF.Sqrt(LaserFreshness(now,knot.Timestamp,lifetime));
            var offset=new Vector2(-tangent.Y,tangent.X)*radius;
            _laserLeft.Add(knot.Point+offset);_laserRight.Add(knot.Point-offset);
        }
        using var path=new CanvasPathBuilder(device);path.BeginFigure(_laserLeft[0]);
        for(var i=1;i<_laserLeft.Count;i++)path.AddLine(_laserLeft[i]);
        var head=_laserSmooth[^1];var headRadius=width*.5f*MathF.Sqrt(LaserFreshness(now,head.Timestamp,lifetime));
        path.AddQuadraticBezier(head.Point+LaserTangent(_laserSmooth.Count-1)*headRadius*2,_laserRight[^1]);
        for(var i=_laserRight.Count-2;i>=0;i--)path.AddLine(_laserRight[i]);
        var tail=_laserSmooth[0];var tailRadius=width*.5f*MathF.Sqrt(LaserFreshness(now,tail.Timestamp,lifetime));
        path.AddQuadraticBezier(tail.Point-LaserTangent(0)*tailRadius*2,_laserLeft[0]);path.EndFigure(CanvasFigureLoop.Closed);
        return CanvasGeometry.CreatePath(path);
    }
    private void ClearLaserResources(){_laserTipBrush?.Dispose();_laserTipBrush=null;_laserRaw.Clear();_laserSmooth.Clear();_laserLeft.Clear();_laserRight.Clear();}
}
