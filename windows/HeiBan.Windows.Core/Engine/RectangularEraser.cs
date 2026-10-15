using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Shared object geometry intersection; the rectangle API delegates to the same convex clipping.</summary>
public static class RectangularEraser
{
    public static List<List<InkPoint>> Split(IReadOnlyList<InkPoint> points,double left,double top,double right,double bottom)
        =>EraserFootprint.Rectangle(left,top,right,bottom).Split(points);
    public static bool Intersects(BoardObject item,double left,double top,double right,double bottom)
        =>Intersects(item,EraserFootprint.Rectangle(left,top,right,bottom));
    public static bool Intersects(BoardObject item,EraserFootprint footprint)
    {
        var pad=item.StrokeWidth/2;
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
            if(path.Any(p=>footprint.Contains(p,pad)))return true;
            for(var i=1;i<path.Count;i++)if(footprint.Clip(path[i-1],path[i],pad,out _,out _))return true;
            if(closed&&path.Count>1&&footprint.Clip(path[^1],path[0],pad,out _,out _))return true;
        }
        // The footprint may lie fully inside a filled shape, image or text box.
        return footprint.Corners.Append(footprint.Center).Any(p=>VectorMath.IsPointInObject(p,item,0));
    }
}
