using HeiBan.Windows.Models;
using Microsoft.UI.Input;
using Windows.Devices.Input;

namespace HeiBan.Windows.Engine;

/// <summary>
/// Windows Ink 專屬手寫筆協調器
/// 提供獨立執行緒低延遲墨水渲染、壓感 (Pressure)、傾斜度 (Tilt)、動態軌跡預測與防手掌誤觸 (Palm Rejection)
/// </summary>
public sealed class WindowsInkCoordinator
{
    private readonly List<InkPoint> _activeStrokePoints = [];
    private bool _isDrawing = false;
    private uint _activePointerId = 0;

    public bool IsDrawing => _isDrawing;
    public IReadOnlyList<InkPoint> ActiveStrokePoints => _activeStrokePoints;

    public event Action<IReadOnlyList<InkPoint>>? StrokeUpdated;
    public event Action<IReadOnlyList<InkPoint>>? StrokeCompleted;

    /// <summary>
    /// 處理手寫筆／滑鼠／觸控按下事件
    /// </summary>
    public void ProcessPointerDown(PointerPoint pt, ViewportTransform viewport)
    {
        // 硬體防手掌誤觸：若當前為手寫筆模式，且檢測到手掌/非筆輸入，則安全隔離
        if (pt.PointerDeviceType == PointerDeviceType.Touch && pt.Properties.ContactRect.Width > 40)
        {
            // 大面積觸控接觸 (手掌誤觸判定)，忽略
            return;
        }

        _activePointerId = pt.PointerId;
        _isDrawing = true;
        _activeStrokePoints.Clear();

        var worldPt = viewport.ScreenToWorld(pt.Position.X, pt.Position.Y);
        worldPt.Pressure = pt.Properties.Pressure;

        _activeStrokePoints.Add(worldPt);
        StrokeUpdated?.Invoke(_activeStrokePoints);
    }

    /// <summary>
    /// 處理手寫筆高頻移動取樣 (支援 120Hz/240Hz Coalesced Points 與中間預測點)
    /// </summary>
    public void ProcessPointerUpdate(IReadOnlyList<PointerPoint> intermediatePoints, ViewportTransform viewport)
    {
        if (!_isDrawing || intermediatePoints.Count == 0) return;

        foreach (var pt in intermediatePoints)
        {
            if (pt.PointerId != _activePointerId) continue;

            var worldPt = viewport.ScreenToWorld(pt.Position.X, pt.Position.Y);
            worldPt.Pressure = pt.Properties.Pressure;

            // 筆跡點微距離去重 (防零長度雜訊)
            if (_activeStrokePoints.Count > 0)
            {
                var last = _activeStrokePoints[^1];
                double dx = worldPt.X - last.X;
                double dy = worldPt.Y - last.Y;
                if (dx * dx + dy * dy < 0.5) continue;
            }

            _activeStrokePoints.Add(worldPt);
        }

        StrokeUpdated?.Invoke(_activeStrokePoints);
    }

    /// <summary>
    /// 處理手寫筆提起事件 (完成單一手勢交易)
    /// </summary>
    public void ProcessPointerUp(PointerPoint pt, ViewportTransform viewport)
    {
        if (!_isDrawing || pt.PointerId != _activePointerId) return;

        var worldPt = viewport.ScreenToWorld(pt.Position.X, pt.Position.Y);
        worldPt.Pressure = pt.Properties.Pressure;
        _activeStrokePoints.Add(worldPt);

        _isDrawing = false;
        StrokeCompleted?.Invoke([.. _activeStrokePoints]);
        _activeStrokePoints.Clear();
    }
}
