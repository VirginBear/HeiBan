using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>Shared geometric check for turning a held, nearly straight ink gesture into a line.</summary>
public static class StraightStrokeRecognizer
{
    public static bool IsEligible(IReadOnlyList<InkPoint> points, double zoom)
    {
        if (points.Count < 5 || zoom <= 0) return false;
        var a = points[0];
        var b = points[^1];
        var dx = b.X - a.X;
        var dy = b.Y - a.Y;
        var length = Math.Sqrt(dx * dx + dy * dy);
        if (length * zoom < 24) return false;

        // Tolerance is expressed in screen DIP; reject loops and strokes with a substantial bend.
        var tolerance = Math.Max(5 / zoom, length * .035);
        if (points.Any(point => Math.Abs((point.X - a.X) * dy - (point.Y - a.Y) * dx) / length > tolerance))
            return false;

        var travel = 0d;
        for (var i = 1; i < points.Count; i++)
            travel += Math.Sqrt(Math.Pow(points[i].X - points[i - 1].X, 2) + Math.Pow(points[i].Y - points[i - 1].Y, 2));
        return travel <= length * 1.2;
    }
}
