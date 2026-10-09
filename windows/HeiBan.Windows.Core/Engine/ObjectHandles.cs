using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>Shared world-space geometry for drawing, hit testing and pointer manipulation.</summary>
public static class ObjectHandles
{
    public readonly record struct Handle(string Kind, InkPoint Point, int Index = -1);
    private static readonly (double X, double Y)[] Corners = [(0,0),(1,0),(1,1),(0,1)];
    private static readonly (double X, double Y)[] ResizePositions = [(0,0),(.5,0),(1,0),(1,.5),(1,1),(.5,1),(0,1),(0,.5)];
    public static InkPoint Rotate(InkPoint p, InkPoint center, double degrees)
    {
        var radians=degrees*Math.PI/180;var c=Math.Cos(radians);var s=Math.Sin(radians);
        var x=p.X-center.X;var y=p.Y-center.Y;
        return new(center.X+x*c-y*s,center.Y+x*s+y*c);
    }
    public static InkPoint Center(BoardObject o)=>new(o.X+o.Width/2,o.Y+o.Height/2);
    public static InkPoint ToWorld(BoardObject o,InkPoint p)=>Rotate(p,Center(o),o.Rotation);
    public static InkPoint ToLocal(BoardObject o,InkPoint p)=>Rotate(p,Center(o),-o.Rotation);
    public static IReadOnlyList<InkPoint> Outline(BoardObject o)=>Corners.Select(p=>ToWorld(o,new(o.X+p.X*o.Width,o.Y+p.Y*o.Height))).ToArray();
    public static InkPoint Endpoint(BoardObject o,int index)=>ToWorld(o,index==0?new(o.X1??o.X,o.Y1??o.Y):new(o.X2??o.X+o.Width,o.Y2??o.Y+o.Height));
    public static IReadOnlyList<Handle> Get(BoardObject o,double zoom)
    {
        if(o.IsLocked==true)return [];
        if(o.Type is "line" or "arrow")return [new("endpoint",Endpoint(o,0),0),new("endpoint",Endpoint(o,1),1)];
        var handles=new List<Handle>();
        if(o.Type is "triangle" or "quadrilateral" or "curve")
            handles.AddRange(o.ParsedPoints.Select((p,i)=>new Handle("vertex",ToWorld(o,p),i)));
        else if(o.ParsedPoints.Count==0)
            handles.AddRange(ResizePositions.Select((p,i)=>new Handle("resize",ToWorld(o,new(o.X+p.X*o.Width,o.Y+p.Y*o.Height)),i)));
        if(o.Type=="arc")
        {
            var r=o.ArcRadius??(o.Width/2.0);
            var c=Center(o);
            var startDeg=o.ArcStartAngle??0.0;
            var sweepDeg=o.ArcSweepAngle??360.0;
            var endDeg=startDeg+sweepDeg;
            var sRad=startDeg*Math.PI/180.0;
            var eRad=endDeg*Math.PI/180.0;
            var startPt=new InkPoint(c.X+r*Math.Cos(sRad),c.Y+r*Math.Sin(sRad));
            var endPt=new InkPoint(c.X+r*Math.Cos(eRad),c.Y+r*Math.Sin(eRad));
            // Arc endpoints must win hit testing when they coincide with a box handle.
            handles.Insert(0,new Handle("arc_end",ToWorld(o,endPt),1));
            handles.Insert(0,new Handle("arc_start",ToWorld(o,startPt),0));
        }
        handles.Add(new("rotate",ToWorld(o,new(o.X+o.Width/2,o.Y-28/zoom))));
        return handles;
    }
    public static void SetEndpoints(BoardObject o,InkPoint a,InkPoint b)
    {
        o.X1=a.X;o.Y1=a.Y;o.X2=b.X;o.Y2=b.Y;
        o.X=Math.Min(a.X,b.X);o.Y=Math.Min(a.Y,b.Y);o.Width=Math.Abs(b.X-a.X);o.Height=Math.Abs(b.Y-a.Y);o.Rotation=0;
    }
    public static void MoveEndpoint(BoardObject o,int index,InkPoint point)
    {
        // Bake rotation into both endpoints before changing the bounding-box center.
        var a=Endpoint(o,0);var b=Endpoint(o,1);
        SetEndpoints(o,index==0?point:a,index==1?point:b);
    }
    public static void MoveArcEndpoint(BoardObject o,int index,InkPoint point)
    {
        if(o.Type!="arc")return;
        var local=ToLocal(o,point);
        var c=Center(o);
        if(!double.IsFinite(local.X)||!double.IsFinite(local.Y)||Math.Sqrt(Math.Pow(local.X-c.X,2)+Math.Pow(local.Y-c.Y,2))<1e-6)return;
        var angleRad=Math.Atan2(local.Y-c.Y,local.X-c.X);
        var angleDeg=angleRad*180.0/Math.PI;
        if(angleDeg<0)angleDeg+=360.0;

        var start=o.ArcStartAngle??0.0;
        var sweep=o.ArcSweepAngle??360.0;

        // Unwrap about the previous endpoint, so 359° -> 0° remains continuous.
        var reference=index==0?start:start+sweep;
        var unwrapped=angleDeg+360*Math.Round((reference-angleDeg)/360);
        var nextSweep=index==0?start+sweep-unwrapped:unwrapped-start;
        nextSweep=sweep<0?Math.Clamp(nextSweep,-360,-.1):Math.Clamp(nextSweep,.1,360);
        if(index==0)o.ArcStartAngle=Math.Round((unwrapped%360+360)%360,1);
        o.ArcSweepAngle=Math.Round(nextSweep,1);
    }
    public static void Resize(BoardObject target,BoardObject initial,int index,InkPoint pointer,bool keepAspect)
    {
        if(target.Type=="arc"||initial.Type=="arc")keepAspect=true;
        var handle=ResizePositions[index];var opposite=(X:1-handle.X,Y:1-handle.Y);
        var anchor=ToWorld(initial,new(initial.X+opposite.X*initial.Width,initial.Y+opposite.Y*initial.Height));
        var relative=Rotate(pointer,anchor,-initial.Rotation);
        var sx=handle.X==0?-1:1;var sy=handle.Y==0?-1:1;
        var width=handle.X==.5?initial.Width:Math.Max(4,sx*(relative.X-anchor.X));
        var height=handle.Y==.5?initial.Height:Math.Max(4,sy*(relative.Y-anchor.Y));
        if(keepAspect&&handle.X!=.5&&handle.Y!=.5&&initial.Width>0&&initial.Height>0)
        {
            var scale=Math.Max(width/initial.Width,height/initial.Height);
            scale=Math.Max(scale,Math.Max(4/initial.Width,4/initial.Height));
            width=initial.Width*scale;height=initial.Height*scale;
        }
        if(target.Type=="arc")
        {
            // Side handles change one axis; the untouched axis must not prevent shrinking.
            var size=Math.Max(10,handle.X==.5?height:handle.Y==.5?width:Math.Max(width,height));
            width=size;height=size;
            target.ArcRadius=size/2.0;
        }
        var center=Rotate(new(anchor.X+(.5-opposite.X)*width,anchor.Y+(.5-opposite.Y)*height),anchor,initial.Rotation);
        target.X=center.X-width/2;target.Y=center.Y-height/2;target.Width=width;target.Height=height;
    }
}
