using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Both hosts use the pointer-down anchor, including a magnet-snapped first point.</summary>
public static class ShapeConstruction
{
    public static InkPoint ConstrainLine(InkPoint start,InkPoint end)
    {
        var dx=end.X-start.X;var dy=end.Y-start.Y;
        var octant=((int)Math.Round(Math.Atan2(dy,dx)/(Math.PI/4))+8)%8;
        var (x,y)=octant switch{0=>(1,0),1=>(1,1),2=>(0,1),3=>(-1,1),4=>(-1,0),5=>(-1,-1),6=>(0,-1),_=>(1,-1)};
        var along=(dx*x+dy*y)/(x*x+y*y);var result=end.Snapshot();
        result.X=start.X+x*along;result.Y=start.Y+y*along;return result;
    }
    public static bool IsVertexPolygon(string tool)=>tool is "triangle" or "quadrilateral";
    public static void Drag(BoardObject shape,InkPoint start,InkPoint end,bool regular=false)
    {
        if(regular&&shape.Type=="triangle")
        {
            // First two vertices define an equilateral triangle. Keep owned
            // preview points; JSON encoding waits until document persistence.
            var b=ConstrainLine(start,end);var dx=b.X-start.X;var dy=b.Y-start.Y;
            var c=new InkPoint((start.X+b.X)/2+dy*Math.Sqrt(3)/2,(start.Y+b.Y)/2-dx*Math.Sqrt(3)/2);
            InkPoint[] vertices=[start,b,c];shape.SetCompletedInkPoints(vertices);
            var bounds=VectorMath.ComputeBoundingBox(vertices,0);
            shape.X=bounds.MinX;shape.Y=bounds.MinY;shape.Width=Math.Max(1,bounds.Width);shape.Height=Math.Max(1,bounds.Height);return;
        }
        if(regular&&shape.Type is "rect" or "circle" or "diamond" or "pentagon" or "star" or "quadrilateral")
        {
            var side=Math.Max(Math.Abs(end.X-start.X),Math.Abs(end.Y-start.Y));
            end=new(start.X+Math.CopySign(side,end.X-start.X),start.Y+Math.CopySign(side,end.Y-start.Y));
        }
        if(IsVertexPolygon(shape.Type))shape.Points=null;
        // Radial shapes start at their center. A bounding-box corner is not on an ellipse
        // and made a correctly snapped pointer-down appear disconnected from the target.
        if(shape.Type is "circle" or "diamond" or "pentagon" or "star")
        {
            var rx=Math.Max(.5,Math.Abs(end.X-start.X));var ry=Math.Max(.5,Math.Abs(end.Y-start.Y));
            shape.X=start.X-rx;shape.Y=start.Y-ry;shape.Width=rx*2;shape.Height=ry*2;
        }
        else
        {shape.X=Math.Min(start.X,end.X);shape.Y=Math.Min(start.Y,end.Y);shape.Width=Math.Max(1,Math.Abs(end.X-start.X));shape.Height=Math.Max(1,Math.Abs(end.Y-start.Y));}
        if(shape.Type=="quadrilateral")shape.SetCompletedInkPoints([new(shape.X,shape.Y),new(shape.X+shape.Width,shape.Y),new(shape.X+shape.Width,shape.Y+shape.Height),new(shape.X,shape.Y+shape.Height)]);
    }
}
