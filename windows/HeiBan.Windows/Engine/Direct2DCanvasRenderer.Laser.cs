using System.Numerics;
using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Brushes;
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

        // Layered vector glow ribbons avoid intermediate GPU blur buffers and CPU stalls on transparent windows
        using var outerGlow=LaserRibbon(ds,width*2.5f,now,lifetime);
        if(outerGlow is not null)ds.FillGeometry(outerGlow,HexToColor(laser.Color,opacity*.22f));

        using var innerGlow=LaserRibbon(ds,width*1.55f,now,lifetime);
        if(innerGlow is not null)ds.FillGeometry(innerGlow,HexToColor(laser.Color,opacity*.48f));

        using var body=LaserRibbon(ds,width,now,lifetime);
        if(body is not null)ds.FillGeometry(body,HexToColor(laser.Color,opacity));

        if(laser.WhiteCore)
        {
            using var core=LaserRibbon(ds,Math.Max(.5f*density,width*.28f),now,lifetime);
            if(core is not null)ds.FillGeometry(core,HexToColor("#FFFFFF",opacity*.88f));
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
    private Vector2 LaserTangent(int i,int startIdx,int count)
    {
        var prev=_laserSmooth[Math.Max(i-1,startIdx)].Point;
        var next=_laserSmooth[Math.Min(i+1,startIdx+count-1)].Point;
        var vector=next-prev;
        var len=vector.Length();
        if(len<0.001f)
        {
            for(var step=2;step<=4;step++)
            {
                prev=_laserSmooth[Math.Max(i-step,startIdx)].Point;
                next=_laserSmooth[Math.Min(i+step,startIdx+count-1)].Point;
                vector=next-prev;
                len=vector.Length();
                if(len>=0.001f)break;
            }
        }
        return len>0.0001f?vector/len:new Vector2(1,0);
    }
    private CanvasGeometry? LaserRibbon(ICanvasResourceCreator device,float width,double now,double lifetime)
    {
        if(_laserSmooth.Count<2)return null;
        var firstActive=0;
        while(firstActive<_laserSmooth.Count-1&&LaserFreshness(now,_laserSmooth[firstActive].Timestamp,lifetime)<=0.005f)firstActive++;
        var activeCount=_laserSmooth.Count-firstActive;
        if(activeCount<2)return null;

        _laserLeft.Clear();_laserRight.Clear();
        for(var i=firstActive;i<_laserSmooth.Count;i++)
        {
            var knot=_laserSmooth[i];var tangent=LaserTangent(i,firstActive,activeCount);
            var radius=Math.Max(0.3f,width*.5f*MathF.Sqrt(LaserFreshness(now,knot.Timestamp,lifetime)));
            var offset=new Vector2(-tangent.Y,tangent.X)*radius;
            _laserLeft.Add(knot.Point+offset);_laserRight.Add(knot.Point-offset);
        }
        if(_laserLeft.Count<2)return null;

        using var path=new CanvasPathBuilder(device);
        path.SetFilledRegionDetermination(CanvasFilledRegionDetermination.Winding);
        path.BeginFigure(_laserLeft[0]);
        for(var i=1;i<_laserLeft.Count;i++)path.AddLine(_laserLeft[i]);
        var lastIdx=_laserSmooth.Count-1;
        var head=_laserSmooth[lastIdx];
        var headRadius=Math.Max(0.5f,width*.5f*MathF.Sqrt(LaserFreshness(now,head.Timestamp,lifetime)));
        path.AddQuadraticBezier(head.Point+LaserTangent(lastIdx,firstActive,activeCount)*headRadius*1.5f,_laserRight[^1]);
        for(var i=_laserRight.Count-2;i>=0;i--)path.AddLine(_laserRight[i]);
        var tail=_laserSmooth[firstActive];
        var tailRadius=Math.Max(0.5f,width*.5f*MathF.Sqrt(LaserFreshness(now,tail.Timestamp,lifetime)));
        path.AddQuadraticBezier(tail.Point-LaserTangent(firstActive,firstActive,activeCount)*tailRadius*1.5f,_laserLeft[0]);
        path.EndFigure(CanvasFigureLoop.Closed);
        return CanvasGeometry.CreatePath(path);
    }
    private void ClearLaserResources(){_laserTipBrush?.Dispose();_laserTipBrush=null;_laserRaw.Clear();_laserSmooth.Clear();_laserLeft.Clear();_laserRight.Clear();}
}
