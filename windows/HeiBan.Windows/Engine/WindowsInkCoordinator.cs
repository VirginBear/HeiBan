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
    private InkPoint? _holdAnchor;
    private double _holdSince;
    private bool _straight;
    private static double Now=>System.Diagnostics.Stopwatch.GetTimestamp()/(double)System.Diagnostics.Stopwatch.Frequency;
    public Func<InkPoint, InkPoint>? Projection { get; set; }
    public bool IsDrawing { get; private set; }
    public bool IsStraight=>_straight;
    public IReadOnlyList<InkPoint> ActiveStrokePoints => _straight&&_points.Count>1?new[]{_points[0],_points[^1]}:_points;
    public bool TrySnapStraight(double zoom)
    {
        if(!IsDrawing||_straight||Projection is not null||_points.Count<5||Now-_holdSince<1)return false;
        var a=_points[0];var b=_points[^1];var dx=b.X-a.X;var dy=b.Y-a.Y;var length=Math.Sqrt(dx*dx+dy*dy);
        if(length*zoom<24)return false;
        // A loop or a large bend is not a line. The tolerance is in screen DIP, as is hold motion.
        var tolerance=Math.Max(5/zoom,length*.035);
        if(_points.Any(p=>Math.Abs((p.X-a.X)*dy-(p.Y-a.Y)*dx)/length>tolerance))return false;
        var travel=0d;for(var i=1;i<_points.Count;i++)travel+=Math.Sqrt(Math.Pow(_points[i].X-_points[i-1].X,2)+Math.Pow(_points[i].Y-_points[i-1].Y,2));
        if(travel>length*1.2)return false;
        _straight=true;return true;
    }
    public bool ProcessPointerDown(PointerPoint point, ViewportTransform viewport)
    {
        // Touch draws no ink; reserve it for navigation and ignore palm contacts during pen use.
        if (point.PointerDeviceType == PointerDeviceType.Touch || IsDrawing) return false;
        _pointer = point.PointerId; _lastTimestamp = 0; _points.Clear(); IsDrawing = true;_straight=false;_holdAnchor=null;_holdSince=Now;
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
        if(_holdAnchor is null||Math.Sqrt(Math.Pow(world.X-_holdAnchor.X,2)+Math.Pow(world.Y-_holdAnchor.Y,2))*viewport.Zoom>12)
        {_holdAnchor=world;_holdSince=Now;_straight=false;}
        if (_points.Count > 0 && Math.Abs(world.X-_points[^1].X)+Math.Abs(world.Y-_points[^1].Y)<0.001) return;
        if (Projection is not null) world = Projection(world);
        _points.Add(world);
    }
    public IReadOnlyList<InkPoint> Finish(PointerPoint point, ViewportTransform viewport)
    {
        if (!IsDrawing || point.PointerId != _pointer) return [];
        Append(point, viewport); IsDrawing = false;
        var result = ActiveStrokePoints.ToArray(); _points.Clear(); return result;
    }
    public void Cancel() { IsDrawing = false; _points.Clear();_straight=false;_holdAnchor=null; }
}
