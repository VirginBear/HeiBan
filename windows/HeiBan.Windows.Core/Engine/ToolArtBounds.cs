namespace HeiBan.Windows.Engine;

public readonly record struct ToolArtBounds(double Left,double Top,double Right,double Bottom)
{
    public double Width=>Right-Left;
    public double Height=>Bottom-Top;
    public static ToolArtBounds From(IEnumerable<(double X,double Y)> points)
    {
        var values=points.ToArray();return new(values.Min(p=>p.X),values.Min(p=>p.Y),values.Max(p=>p.X),values.Max(p=>p.Y));
    }
}
