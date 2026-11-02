using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

public static class PointSelection
{
    public static bool Contains(BoardObject item,InkPoint point,double tolerance)
    {
        if(!double.IsFinite(point.X)||!double.IsFinite(point.Y)||!double.IsFinite(tolerance)||tolerance<0)return false;
        // The selectable area follows the object's rotated local bounds rather
        // than its painted pixels. Erasing retains precise geometry separately.
        var local=item.Rotation==0?point:ObjectHandles.ToLocal(item,point);
        var pad=tolerance+Math.Max(0,item.StrokeWidth)/2;
        var left=Math.Min(item.X,item.X+item.Width);var right=Math.Max(item.X,item.X+item.Width);
        var top=Math.Min(item.Y,item.Y+item.Height);var bottom=Math.Max(item.Y,item.Y+item.Height);
        return local.X>=left-pad&&local.X<=right+pad&&local.Y>=top-pad&&local.Y<=bottom+pad
            ||item.Type is "line" or "arrow"&&VectorMath.IsPointInObject(point,item,tolerance);
    }
}
