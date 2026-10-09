using HeiBan.Windows.Models;
using Microsoft.UI.Input;
using PointerDeviceType = Microsoft.UI.Input.PointerDeviceType;
namespace HeiBan.Windows.Engine;

/// <summary>Coalesced pointer collector. Uses the UI input thread; this is not InkPresenter.</summary>
public sealed class WindowsInkCoordinator
{
    private readonly List<InkPoint> _points = [];
    private ulong _lastTimestamp;
    private uint _pointer;
    public Func<InkPoint, InkPoint>? Projection { get; set; }
    public bool IsDrawing { get; private set; }
    public IReadOnlyList<InkPoint> ActiveStrokePoints => _points;
    public bool ProcessPointerDown(PointerPoint point, ViewportTransform viewport)
    {
        // Touch draws no ink; reserve it for navigation and ignore palm contacts during pen use.
        if (point.PointerDeviceType == PointerDeviceType.Touch || IsDrawing) return false;
        _pointer = point.PointerId; _lastTimestamp = 0; _points.Clear(); IsDrawing = true;
        Append(point, viewport); return true;
    }
    public void ProcessPointerUpdate(IEnumerable<PointerPoint> points, ViewportTransform viewport)
    {
        if (!IsDrawing) return;
        // WinUI intermediate points are newest first. Sorting by timestamp avoids backwards folds.
        foreach (var p in points.OrderBy(p => p.Timestamp)) if (p.PointerId == _pointer) Append(p, viewport);
    }
    private void Append(PointerPoint p, ViewportTransform viewport)
    {
        if (_points.Count > 0 && p.Timestamp <= _lastTimestamp) return;
        _lastTimestamp = p.Timestamp;
        var world = viewport.ScreenToWorld(p.Position.X, p.Position.Y);
        world.Pressure = p.PointerDeviceType == PointerDeviceType.Pen ? p.Properties.Pressure : 1;
        world.TiltX = p.Properties.XTilt; world.TiltY = p.Properties.YTilt;
        if (_points.Count > 0 && Math.Abs(world.X-_points[^1].X)+Math.Abs(world.Y-_points[^1].Y)<0.001) return;
        if (Projection is not null) world = Projection(world);
        _points.Add(world);
    }
    public IReadOnlyList<InkPoint> Finish(PointerPoint point, ViewportTransform viewport)
    {
        if (!IsDrawing || point.PointerId != _pointer) return [];
        Append(point, viewport); IsDrawing = false;
        var result = _points.ToArray(); _points.Clear(); return result;
    }
    public void Cancel() { IsDrawing = false; _points.Clear(); }
}
