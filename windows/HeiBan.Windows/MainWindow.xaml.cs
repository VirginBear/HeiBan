using System.Numerics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;

namespace HeiBan.Windows;

public partial class MainWindow : Window
{
    private readonly Direct2DCanvasRenderer _renderer = new();
    private readonly WindowsInkCoordinator _inkCoordinator = new();
    private readonly ViewportTransform _viewport = new();
    private readonly HeiBanDocument _document = new();

    private string _currentTool = "pen";
    private string _eraserMode = "pixel";
    private double _activeStrokeWidth = 4.0;
    private Vector2 _currentMousePos;

    public MainWindow()
    {
        InitializeComponent();

        // 1. 設定自訂標題列與 Mica 雲母材質背景
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        SystemBackdrop = new MicaBackdrop();

        // 2. 免安裝綠色版提示標籤
        if (DocumentSessionManager.Shared.IsPortableMode)
        {
            PortableBadge.Visibility = Visibility.Visible;
        }

        // 3. 註冊筆跡協調器完成事件
        _inkCoordinator.StrokeUpdated += (pts) => CanvasSurface.Invalidate();
        _inkCoordinator.StrokeCompleted += OnStrokeCompleted;
    }

    private void CanvasSurface_CreateResources(CanvasControl sender, Microsoft.Graphics.Canvas.UI.CanvasCreateResourcesEventArgs args)
    {
        // 預先載入 GPU 紋理或字型資源
    }

    private void CanvasSurface_Draw(CanvasControl sender, CanvasDrawEventArgs args)
    {
        float w = (float)sender.ActualWidth;
        float h = (float)sender.ActualHeight;

        // 1. 繪製背景與網格
        _renderer.RenderBackground(args.DrawingSession, _document.Board, _viewport, w, h);

        // 2. 繪製已提交向量物件
        _renderer.RenderObjects(args.DrawingSession, _document.Objects, _viewport, w, h);

        // 3. 繪製手寫中浮動筆跡 (即時預覽)
        if (_inkCoordinator.IsDrawing && _inkCoordinator.ActiveStrokePoints.Count >= 2)
        {
            var tempObj = new BoardObject
            {
                Type = _currentTool,
                StrokeColor = "#ffffff",
                StrokeWidth = _activeStrokeWidth,
                Points = System.Text.Json.JsonSerializer.Serialize(_inkCoordinator.ActiveStrokePoints)
            };
            _renderer.RenderObjects(args.DrawingSession, [tempObj], _viewport, w, h);
        }

        // 4. 繪製 1:1 橡皮擦與筆刷懸停預覽光圈
        _renderer.RenderHoverIndicator(args.DrawingSession, _currentTool, _eraserMode, _activeStrokeWidth, _viewport, _currentMousePos);
    }

    private void CanvasSurface_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        var pt = e.GetCurrentPoint(CanvasSurface);
        if (_currentTool is "pen" or "highlighter" or "paint")
        {
            _inkCoordinator.ProcessPointerDown(pt, _viewport);
        }
        else if (_currentTool == "eraser")
        {
            var worldPt = _viewport.ScreenToWorld(pt.Position.X, pt.Position.Y);
            EraseAt(worldPt);
        }
        CanvasSurface.Invalidate();
    }

    private void CanvasSurface_PointerMoved(object sender, PointerRoutedEventArgs e)
    {
        var pt = e.GetCurrentPoint(CanvasSurface);
        _currentMousePos = new Vector2((float)pt.Position.X, (float)pt.Position.Y);

        if (_inkCoordinator.IsDrawing)
        {
            var intermediatePts = e.GetIntermediatePoints(CanvasSurface);
            _inkCoordinator.ProcessPointerUpdate(intermediatePts, _viewport);
        }
        else if (_currentTool == "eraser" && pt.Properties.IsLeftButtonPressed)
        {
            var worldPt = _viewport.ScreenToWorld(pt.Position.X, pt.Position.Y);
            EraseAt(worldPt);
        }

        CanvasSurface.Invalidate();
    }

    private void CanvasSurface_PointerReleased(object sender, PointerRoutedEventArgs e)
    {
        var pt = e.GetCurrentPoint(CanvasSurface);
        _inkCoordinator.ProcessPointerUp(pt, _viewport);
        CanvasSurface.Invalidate();
    }

    private void OnStrokeCompleted(IReadOnlyList<InkPoint> points)
    {
        if (points.Count < 2) return;

        var bbox = VectorMath.ComputeBoundingBox(points, _activeStrokeWidth);
        var newObj = new BoardObject
        {
            Id = Guid.NewGuid().ToString(),
            BoardId = _document.Board.Id,
            Type = _currentTool,
            X = bbox.MinX,
            Y = bbox.MinY,
            Width = bbox.Width,
            Height = bbox.Height,
            StrokeWidth = _activeStrokeWidth,
            StrokeColor = "#ffffff",
            Points = System.Text.Json.JsonSerializer.Serialize(points),
            ZIndex = _document.Objects.Count + 1
        };

        _document.Objects.Add(newObj);
        CanvasSurface.Invalidate();
    }

    private void EraseAt(InkPoint worldPt)
    {
        double radius = _eraserMode == "pixel" ? 16.0 : 18.0;
        if (_eraserMode == "object")
        {
            _document.Objects.RemoveAll(o => !o.IsLocked.GetValueOrDefault() && VectorMath.IsPointInObject(worldPt, o, radius));
        }
        CanvasSurface.Invalidate();
    }

    private void Tool_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement fe && fe.Tag is string tool)
        {
            _currentTool = tool;
            CanvasSurface.Invalidate();
        }
    }

    private void ToggleRuler_Click(object sender, RoutedEventArgs e) { /* 尺規開關 */ }
    private void AddSticky_Click(object sender, RoutedEventArgs e) { /* 新增便簽 */ }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        await DocumentSessionManager.Shared.SaveBoardAsync(_document);
    }
}
