using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public static class ArrowGeometry
{
    public static InkPoint[] Outline(BoardObject item)
    {
        var a = new InkPoint(item.X1 ?? item.X, item.Y1 ?? item.Y);
        var b = new InkPoint(item.X2 ?? item.X + item.Width, item.Y2 ?? item.Y + item.Height);
        var dx = b.X - a.X;
        var dy = b.Y - a.Y;
        var length = Math.Sqrt(dx * dx + dy * dy);
        if (length < .001 || !double.IsFinite(length)) return [];

        dx /= length;
        dy /= length;
        var headLength = Math.Clamp(item.ArrowHeadLength ?? 16, 0, length * .9);
        var headHalf = Math.Max(.5, item.ArrowHeadWidth ?? 10) / 2;
        var shaftHalf = Math.Min(headHalf * .95, Math.Max(.1, item.StrokeWidth) / 2);
        InkPoint At(double along, double across) => new(a.X + dx * along - dy * across, a.Y + dy * along + dx * across);
        var joint = length - headLength;
        // One closed outline prevents a visible join even when opacity is below 100%.
        return [At(0,shaftHalf), At(joint,shaftHalf), At(joint,headHalf), b,
            At(joint,-headHalf), At(joint,-shaftHalf), At(0,-shaftHalf)];
    }

    public static double ShaftLength(BoardObject item)
    {
        var a = ObjectHandles.Endpoint(item, 0);
        var b = ObjectHandles.Endpoint(item, 1);
        var length = Math.Sqrt(Math.Pow(b.X-a.X,2)+Math.Pow(b.Y-a.Y,2));
        return length - Math.Clamp(item.ArrowHeadLength ?? 16, 0, length * .9);
    }

    public static void SetShaftLength(BoardObject item, double shaftLength)
    {
        var a = ObjectHandles.Endpoint(item, 0);
        var b = ObjectHandles.Endpoint(item, 1);
        var dx = b.X - a.X;
        var dy = b.Y - a.Y;
        var length = Math.Sqrt(dx*dx+dy*dy);
        if (length < .001 || !double.IsFinite(shaftLength) || shaftLength<=0) return;
        var headLength = Math.Max(0,item.ArrowHeadLength ?? 16);
        var total = Math.Min(shaftLength+headLength,shaftLength*10);
        ObjectHandles.MoveEndpoint(item,0,new(b.X-dx/length*total,b.Y-dy/length*total));
    }
}
