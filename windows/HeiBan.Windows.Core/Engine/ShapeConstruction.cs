using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Both hosts use the pointer-down anchor, including a magnet-snapped first point.</summary>
public static class ShapeConstruction
{
    public static void Drag(BoardObject shape,InkPoint start,InkPoint end)
    {
        // Radial shapes start at their center. A bounding-box corner is not on an ellipse
        // and made a correctly snapped pointer-down appear disconnected from the target.
        if(shape.Type is "circle" or "diamond" or "pentagon" or "star")
        {
            var rx=Math.Max(.5,Math.Abs(end.X-start.X));var ry=Math.Max(.5,Math.Abs(end.Y-start.Y));
            shape.X=start.X-rx;shape.Y=start.Y-ry;shape.Width=rx*2;shape.Height=ry*2;
        }
        else
        {shape.X=Math.Min(start.X,end.X);shape.Y=Math.Min(start.Y,end.Y);shape.Width=Math.Max(1,Math.Abs(end.X-start.X));shape.Height=Math.Max(1,Math.Abs(end.Y-start.Y));}
    }
}
