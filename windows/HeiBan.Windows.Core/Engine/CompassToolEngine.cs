using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>
/// W-N04: 圓規與高精度圓弧工具引擎 (對齊 CompassToolEngine.swift)
/// 嚴格劃分兩階段：
/// 1. 準備階段 (IsArmed = false)：移動圓心、調整半徑 (5~20,000 pt 範圍限制)、旋轉筆尖預備角，不產生物件。
/// 2. 作畫階段 (IsArmed = true)：圓心鎖定並顯色，沿圓周拖曳累積有向跨零掃角 (-360°~360°)，完成後產生精確 arc 物件。
/// </summary>
public sealed class CompassToolEngine
{
    public bool IsEnabled { get; set; } = false;
    public InkPoint Center { get; set; } = new(400.0, 300.0);
    public double Radius { get; set; } = 120.0;
    public double StartAngle { get; set; } = 0.0;
    public double SweepAngle { get; set; } = 360.0;
    public bool IsDrawingArc { get; set; } = false;
    public bool IsArmed { get; private set; } = false;
    public double CurrentPencilAngle { get; set; } = 0.0;

    public string StrokeColor { get; set; } = "#86efac";
    public double StrokeWidth { get; set; } = 3.5;
    public string LineStyle { get; set; } = "solid";

    public void MoveCenter(InkPoint newCenter)
    {
        if (IsArmed) return;
        if (double.IsNaN(newCenter.X) || double.IsInfinity(newCenter.X) ||
            double.IsNaN(newCenter.Y) || double.IsInfinity(newCenter.Y)) return;
        Center = newCenter;
    }

    public void AdjustRadius(double newRadius)
    {
        if (IsArmed) return;
        if (double.IsNaN(newRadius) || double.IsInfinity(newRadius)) return;
        Radius = Math.Clamp(newRadius, 5.0, 20000.0);
    }

    public void SetStartAngle(double degrees)
    {
        if (double.IsNaN(degrees) || double.IsInfinity(degrees)) return;
        double norm = degrees % 360.0;
        if (norm < 0) norm += 360.0;
        StartAngle = norm;
        CurrentPencilAngle = norm;
    }

    public void Prepare()
    {
        IsArmed = false;
        IsDrawingArc = false;
        SweepAngle = 0;
        CurrentPencilAngle = StartAngle;
    }

    public void ToggleArmed()
    {
        if (IsDrawingArc) return;
        IsArmed = !IsArmed;
        SweepAngle = 0;
    }

    public void PositionPencil(double angle)
    {
        if (IsArmed) return;
        SetStartAngle(angle);
    }

    public void SetSweepAngle(double degrees)
    {
        if (double.IsNaN(degrees) || double.IsInfinity(degrees)) return;
        SweepAngle = Math.Clamp(degrees, -360.0, 360.0);
    }

    public void StartArc(double atAngle)
    {
        if (!IsArmed || double.IsNaN(atAngle) || double.IsInfinity(atAngle)) return;
        double norm = atAngle % 360.0;
        if (norm < 0) norm += 360.0;
        SweepAngle = 0.0;
        CurrentPencilAngle = StartAngle;
        IsDrawingArc = true;
        UpdateSweep(norm);
    }

    public void UpdateSweep(double toAngle)
    {
        if (!IsDrawingArc || double.IsNaN(toAngle) || double.IsInfinity(toAngle)) return;
        double delta = toAngle - CurrentPencilAngle;
        while (delta > 180.0) delta -= 360.0;
        while (delta < -180.0) delta += 360.0;

        SweepAngle = Math.Clamp(SweepAngle + delta, -360.0, 360.0);
        CurrentPencilAngle = toAngle;
    }

    public void FinishArcDrawing()
    {
        IsDrawingArc = false;
    }

    public BoardObject CreateArcObject(string boardId, string? pageId, bool fullCircle = false)
    {
        double effectiveSweep = fullCircle ? 360.0 : SweepAngle;
        double start = fullCircle ? 0.0 : StartAngle;

        return new BoardObject
        {
            Id = Guid.NewGuid().ToString("N"),
            BoardId = boardId,
            PageId = pageId,
            Type = "arc",
            X = Center.X - Radius,
            Y = Center.Y - Radius,
            Width = Radius * 2.0,
            Height = Radius * 2.0,
            StrokeColor = StrokeColor,
            FillColor = "none",
            StrokeWidth = StrokeWidth,
            LineStyle = LineStyle,
            ArcRadius = Radius,
            ArcStartAngle = Math.Round(start, 1),
            ArcSweepAngle = Math.Round(effectiveSweep, 1)
        };
    }
}
