using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Axis-aligned world footprint. Hosts convert their screen rectangle once per sample.</summary>
public static class RectangularEraser
{
    private static bool Clip(InkPoint a,InkPoint b,double left,double top,double right,double bottom,out double enter,out double exit)
    {
        double low=0,high=1;var dx=b.X-a.X;var dy=b.Y-a.Y;
        bool Edge(double p,double q)
        {
            if(Math.Abs(p)<1e-12)return q>=0;
            var t=q/p;if(p<0){if(t>high)return false;low=Math.Max(low,t);}else{if(t<low)return false;high=Math.Min(high,t);}return true;
        }
        var hit=Edge(-dx,a.X-left)&&Edge(dx,right-a.X)&&Edge(-dy,a.Y-top)&&Edge(dy,bottom-a.Y);
        enter=low;exit=high;return hit;
    }
    private static InkPoint At(InkPoint a,InkPoint b,double t)
    {
        var result=DocumentCodec.Clone(t<.5?a:b);
        result.X=a.X+(b.X-a.X)*t;result.Y=a.Y+(b.Y-a.Y)*t;result.Pressure=a.Pressure+(b.Pressure-a.Pressure)*t;
        if(a.TiltX is { } ax&&b.TiltX is { } bx)result.TiltX=ax+(bx-ax)*t;
        if(a.TiltY is { } ay&&b.TiltY is { } by)result.TiltY=ay+(by-ay)*t;
        return result;
    }
    public static List<List<InkPoint>> Split(IReadOnlyList<InkPoint> points,double left,double top,double right,double bottom)
    {
        List<List<InkPoint>> result=[];List<InkPoint> current=[];
        void End(){if(current.Count>0)result.Add(current);current=[];}
        bool Inside(InkPoint p)=>p.X>=left&&p.X<=right&&p.Y>=top&&p.Y<=bottom;
        if(points.Count==1){if(!Inside(points[0]))result.Add([points[0]]);return result;}
        for(var i=1;i<points.Count;i++)
        {
            var a=points[i-1];var b=points[i];
            if(!Clip(a,b,left,top,right,bottom,out var enter,out var exit))
            {if(current.Count==0)current.Add(a);current.Add(b);continue;}
            if(enter>1e-10){if(current.Count==0)current.Add(a);current.Add(At(a,b,enter));}
            End();
            if(exit<1-1e-10){current.Add(At(a,b,exit));current.Add(b);}
        }
        End();return result;
    }
    public static bool Intersects(BoardObject item,double left,double top,double right,double bottom)
    {
        var pad=item.StrokeWidth/2;left-=pad;right+=pad;top-=pad;bottom+=pad;
        var paths=new List<IReadOnlyList<InkPoint>>();var closed=false;
        if(item.Type is "line" or "arrow")
        {
            var a=ObjectHandles.Endpoint(item,0);var b=ObjectHandles.Endpoint(item,1);paths.Add(new[]{a,b});
            if(item.Type=="arrow")
            {
                var distance=Math.Sqrt(Math.Pow(b.X-a.X,2)+Math.Pow(b.Y-a.Y,2));
                if(distance>1e-9){var dx=(b.X-a.X)/distance;var dy=(b.Y-a.Y)/distance;var length=item.ArrowHeadLength??16;var half=(item.ArrowHeadWidth??10)/2;paths.Add(new[]{new InkPoint(b.X-dx*length-dy*half,b.Y-dy*length+dx*half),b,new InkPoint(b.X-dx*length+dy*half,b.Y-dy*length-dx*half)});}
            }
        }
        else if(item.Type is "circle" or "arc")
        {
            var center=ObjectHandles.Center(item);var rx=item.Type=="arc"?item.ArcRadius??item.Width/2:item.Width/2;var ry=item.Type=="arc"?rx:item.Height/2;
            var start=item.Type=="arc"?item.ArcStartAngle??0:0;var sweep=item.Type=="arc"?item.ArcSweepAngle??360:360;
            paths.Add(Enumerable.Range(0,129).Select(i=>{var angle=(start+sweep*i/128)*Math.PI/180;return ObjectHandles.ToWorld(item,new(center.X+rx*Math.Cos(angle),center.Y+ry*Math.Sin(angle)));}).ToArray());
        }
        else if(item.ParsedPoints.Count>0)
        {paths.Add(CurvePreview.ForObject(item).Points.Select(p=>ObjectHandles.ToWorld(item,p)).ToArray());closed=item.Type is "triangle" or "quadrilateral";}
        else if(item.Type is "diamond" or "pentagon" or "star" or "triangle" or "quadrilateral")
        {
            var count=item.Type=="triangle"?3:item.Type=="pentagon"?5:item.Type=="star"?10:4;
            paths.Add(Enumerable.Range(0,count).Select(i=>{var angle=-Math.PI/2+i*Math.PI*2/count;var radius=item.Type=="star"&&i%2==1?.45:1;return ObjectHandles.ToWorld(item,new(item.X+item.Width/2+Math.Cos(angle)*item.Width/2*radius,item.Y+item.Height/2+Math.Sin(angle)*item.Height/2*radius));}).ToArray());closed=true;
        }
        else{paths.Add(ObjectHandles.Outline(item));closed=true;}
        foreach(var path in paths)
        {
            if(path.Any(p=>p.X>=left&&p.X<=right&&p.Y>=top&&p.Y<=bottom))return true;
            for(var i=1;i<path.Count;i++)if(Clip(path[i-1],path[i],left,top,right,bottom,out _,out _))return true;
            if(closed&&path.Count>1&&Clip(path[^1],path[0],left,top,right,bottom,out _,out _))return true;
        }
        // The footprint may lie fully inside a filled shape, image or text box.
        return new[]{new InkPoint(left,top),new InkPoint(right,top),new InkPoint(right,bottom),new InkPoint(left,bottom),new InkPoint((left+right)/2,(top+bottom)/2)}.Any(p=>VectorMath.IsPointInObject(p,item,0));
    }
}
