using static HeiBan.Windows.Localization.Strings;
using System.Numerics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using global::Windows.Foundation;
using global::Windows.Globalization.NumberFormatting;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private bool _rulerEnabled;
    private float _rulerPixelLength = 640;
    private double _rulerOpacity = .38, _rulerPivotRatio = .5, _rulerRotationStart, _rulerPointerStart;
    private Vector2 _rulerFixedPivot;
    private string _rulerPivotEdge = "center";
    private bool _rulerPivotMoving, _rulerMoving, _rulerRotating, _rulerResizingLeft, _rulerResizingRight;
    private Vector2 _rulerCenter = new(600, 450);
    private double _rulerAngle;
    private string? _rulerColor;
    private Vector2? _snapEdge;
    private Vector2 _snapDirection;
    private global::Windows.Foundation.Rect? _lastRulerDamage;

    private const float RulerHeight = 64;
    private float RulerLength => (float)Math.Clamp(_rulerPixelLength, 200, _overlay.Width * 1.5f);
    private Vector2 RulerDirection() => new((float)Math.Cos(_rulerAngle * Math.PI / 180), (float)Math.Sin(_rulerAngle * Math.PI / 180));
    private Vector2 RulerLocal(Vector2 point)
    {
        var d = RulerDirection();
        var p = point - _rulerCenter;
        return new(Vector2.Dot(p, d), Vector2.Dot(p, new(-d.Y, d.X)));
    }
    private Vector2 RulerPoint(float x, float y = 0)
    {
        var d = RulerDirection();
        return _rulerCenter + d * x + new Vector2(-d.Y, d.X) * y;
    }
    private float RulerPivotY => _rulerPivotEdge == "top" ? -RulerHeight / 2 : _rulerPivotEdge == "bottom" ? RulerHeight / 2 : 0;
    private Vector2 RulerPivot() => RulerPoint((float)((_rulerPivotRatio - .5) * RulerLength), RulerPivotY);
    private bool RulerLeftEdgeHit(Vector2 p)
    {
        var local = RulerLocal(p);
        return Math.Abs(local.X - (-RulerLength / 2)) <= 16 && Math.Abs(local.Y) <= RulerHeight / 2;
    }
    private bool RulerRightEdgeHit(Vector2 p)
    {
        var local = RulerLocal(p);
        return Math.Abs(local.X - (RulerLength / 2)) <= 16 && Math.Abs(local.Y) <= RulerHeight / 2;
    }
    private bool RulerRotationHit(Vector2 p) =>
        Vector2.Distance(p, RulerPoint(RulerLength / 2 - 28)) <= 18 || Vector2.Distance(p, RulerPoint(-RulerLength / 2 + 28)) <= 18;
    private bool RulerPivotHit(Vector2 p) => Vector2.Distance(p, RulerPivot()) < 10;
    private bool RulerAngleHit(Vector2 p)
    {
        var local = RulerLocal(p);
        return local.X > RulerLength / 2 - 136 && local.X < RulerLength / 2 - 46 && local.Y > -29 && local.Y < -1;
    }
    private bool RulerHit(Vector2 point)
    {
        var p = RulerLocal(point);
        return Math.Abs(p.X) < RulerLength / 2 - 16 && Math.Abs(p.Y) < RulerHeight / 2 - 4
            && !RulerRotationHit(point) && !RulerPivotHit(point) && !RulerAngleHit(point);
    }
    private void BeginRulerRotation(Vector2 p)
    {
        _rulerFixedPivot = RulerPivot();
        _rulerRotationStart = _rulerAngle;
        _rulerPointerStart = Math.Atan2(p.Y - _rulerFixedPivot.Y, p.X - _rulerFixedPivot.X) * 180 / Math.PI;
        _rulerRotating = true;
    }
    private void RotateRuler(Vector2 p)
    {
        var pointer = Math.Atan2(p.Y - _rulerFixedPivot.Y, p.X - _rulerFixedPivot.X) * 180 / Math.PI;
        var delta = Math.IEEERemainder(pointer - _rulerPointerStart, 360);
        SetRulerAngle(_rulerRotationStart + delta, _rulerFixedPivot);
    }
    private void SetRulerAngle(double angle, Vector2? pivot = null)
    {
        if (!double.IsFinite(angle)) return;
        var fixedPoint = pivot ?? RulerPivot();
        _rulerAngle = Math.Round(Math.IEEERemainder(angle, 360), 1);
        var offset = RulerGeometry.PivotOffset(_rulerAngle, RulerLength, RulerHeight, _rulerPivotRatio, _rulerPivotEdge);
        _rulerCenter = fixedPoint - new Vector2((float)offset.X, (float)offset.Y);
        DamageRuler();
        _dirty = true;
    }
    private void MoveRulerPivot(Vector2 p)
    {
        var local = RulerLocal(p);
        (_rulerPivotRatio, _rulerPivotEdge) = RulerGeometry.PickPivot(local.X, local.Y, RulerLength, RulerHeight);
    }
    private void ToggleScreenRuler()
    {
        _rulerEnabled = !_rulerEnabled;
        if (_rulerEnabled && (_rulerCenter.X < 50 || _rulerCenter.X > _overlay.Width - 50 || _rulerCenter.Y < 50 || _rulerCenter.Y > _overlay.Height - 50))
        {
            _rulerCenter = new((float)_overlay.Width / 2, (float)_overlay.Height * .58f);
        }
        DamageRuler();
        RefreshButtons();
        Changed();
    }
    private void ShowScreenRulerSettings(FrameworkElement anchor, Point? position = null)
    {
        var panel = new StackPanel { Width = 292, Spacing = 14, RequestedTheme = ElementTheme.Light };
        panel.Children.Add(new TextBlock { Text = T("尺規設定"), FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        var angle = new NumberBox { Header = T("角度（°）"), Value = _rulerAngle, SmallChange = .1, LargeChange = 15, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline, NumberFormatter = new DecimalFormatter { FractionDigits = 1 } };
        angle.ValueChanged += (_, e) => SetRulerAngle(e.NewValue);
        panel.Children.Add(angle);
        var reset = new Button { Content = T("水平 0.0°") };
        reset.Click += (_, _) => angle.Value = 0;
        panel.Children.Add(reset);
        var length = new Slider { Header = T("尺長（像素 pt）"), Minimum = 200, Maximum = 1600, Value = _rulerPixelLength, StepFrequency = 20 };
        length.ValueChanged += (_, e) => { var pivot = RulerPivot(); _rulerPixelLength = (float)e.NewValue; SetRulerAngle(_rulerAngle, pivot); DamageRuler(); _dirty = true; };
        panel.Children.Add(length);
        var edge = new ComboBox { Header = T("旋轉支點所在邊"), ItemsSource = new[] { T("上方劃線邊"), T("尺身中線"), T("下方劃線邊") }, SelectedIndex = _rulerPivotEdge == "top" ? 0 : _rulerPivotEdge == "bottom" ? 2 : 1, HorizontalAlignment = HorizontalAlignment.Stretch };
        edge.SelectionChanged += (_, _) => { _rulerPivotEdge = edge.SelectedIndex == 0 ? "top" : edge.SelectedIndex == 2 ? "bottom" : "center"; DamageRuler(); _dirty = true; };
        panel.Children.Add(edge);
        var pivotPosition = new Slider { Header = T("支點位置（0% 左端；100% 右端）"), Minimum = 0, Maximum = 100, Value = _rulerPivotRatio * 100, StepFrequency = 1 };
        pivotPosition.ValueChanged += (_, e) => { _rulerPivotRatio = e.NewValue / 100; DamageRuler(); _dirty = true; };
        panel.Children.Add(pivotPosition);
        var opacity = new Slider { Header = T("尺身透明度"), Minimum = .12, Maximum = .75, Value = _rulerOpacity, StepFrequency = .01 };
        opacity.ValueChanged += (_, e) => { _rulerOpacity = e.NewValue; DamageRuler(); _dirty = true; };
        panel.Children.Add(opacity);
        var mode = new ComboBox { Header = T("刻度與文字配色"), ItemsSource = new[] { T("自適應（預設）"), T("自訂顏色") }, SelectedIndex = _rulerColor is null ? 0 : 1, HorizontalAlignment = HorizontalAlignment.Stretch };
        panel.Children.Add(mode);
        var picker = ToolbarUi.CreateColorWheel(_rulerColor ?? "#24533D", 260);
        picker.Visibility = _rulerColor is null ? Visibility.Collapsed : Visibility.Visible;
        panel.Children.Add(picker);
        mode.SelectionChanged += (_, _) =>
        {
            picker.Visibility = mode.SelectedIndex == 0 ? Visibility.Collapsed : Visibility.Visible;
            _rulerColor = mode.SelectedIndex == 0 ? null : $"#{picker.Color.R:X2}{picker.Color.G:X2}{picker.Color.B:X2}";
            DamageRuler();
            _dirty = true;
        };
        picker.ColorChanged += (_, e) =>
        {
            if (mode.SelectedIndex == 1)
            {
                _rulerColor = $"#{e.NewColor.R:X2}{e.NewColor.G:X2}{e.NewColor.B:X2}";
                DamageRuler();
                _dirty = true;
            }
        };
        panel.Children.Add(new TextBlock { Text = T("拖曳尺身移動；拖曳兩端圓形把手旋轉。金色支點可拖到上／下劃線邊及最兩端，旋轉時固定在原位。點尺上的角度可直接輸入，精度 0.1°。"), TextWrapping = TextWrapping.Wrap, FontSize = 12, Foreground = ChromeBrush(255, 104, 117, 108) });
        var flyout = new Flyout { Content = new ScrollViewer { Content = panel, MaxHeight = 420, VerticalScrollBarVisibility = ScrollBarVisibility.Auto } };
        if (position is { } p) ShowChromeFlyout(flyout, anchor, new FlyoutShowOptions { Position = p });
        else ShowChromeFlyout(flyout, anchor);
    }
    private void LatchRuler(Vector2 point)
    {
        _snapEdge = null;
        if (!_rulerEnabled) return;
        _snapDirection = RulerDirection();
        var normal = new Vector2(-_snapDirection.Y, _snapDirection.X);
        var local = point - _rulerCenter;
        var perpendicular = Vector2.Dot(local, normal);
        var along = Vector2.Dot(local, _snapDirection);
        if (Math.Abs(along) > RulerLength / 2 + 24 || Math.Abs(Math.Abs(perpendicular) - RulerHeight / 2) > 20) return;
        _snapEdge = _rulerCenter + normal * (perpendicular < 0 ? -RulerHeight / 2 : RulerHeight / 2);
    }
    private InkPoint ProjectOnRuler(InkPoint screenPoint)
    {
        if (_snapEdge is null) return screenPoint;
        var p = new Vector2((float)screenPoint.X, (float)screenPoint.Y);
        var edge = _snapEdge.Value;
        var projected = edge + _snapDirection * Vector2.Dot(p - edge, _snapDirection);
        return new InkPoint(projected.X, projected.Y, screenPoint.Pressure);
    }
    private global::Windows.Foundation.Rect? GetRulerDamageRect()
    {
        if (!_rulerEnabled) return null;
        var (rx, ry, rw, rh) = VectorMath.ComputeRotatedRulerBounds(new InkPoint(_rulerCenter.X, _rulerCenter.Y), _rulerAngle, RulerLength, RulerHeight);
        var pad = 16.0;
        var left = Math.Max(0, Math.Floor(rx - pad));
        var top = Math.Max(0, Math.Floor(ry - pad));
        var right = Math.Min(_overlay.Width, Math.Ceiling(rx + rw + pad));
        var bottom = Math.Min(_overlay.Height, Math.Ceiling(ry + rh + pad));
        if (right > left && bottom > top) return new global::Windows.Foundation.Rect(left, top, right - left, bottom - top);
        return null;
    }
    private void DamageRuler()
    {
        var rect = GetRulerDamageRect();
        if (_lastRulerDamage is { } last) AddScreenDamage(last);
        if (rect is { } current) AddScreenDamage(current);
        _lastRulerDamage = rect;
    }
    private void DrawRuler(CanvasDrawingSession ds)
    {
        var old = ds.Transform;
        ds.Transform = Matrix3x2.CreateRotation((float)(_rulerAngle * Math.PI / 180)) * Matrix3x2.CreateTranslation(_rulerCenter);
        var light = true;
        var ink = Direct2DCanvasRenderer.HexToColor(_rulerColor ?? (light ? "#244C38" : "#F6F3DF"));
        var length = RulerLength;
        var left = -length / 2;
        var top = -RulerHeight / 2;
        ds.FillRoundedRectangle(left, top, length, RulerHeight, 8, 8, Direct2DCanvasRenderer.HexToColor(light ? "#C9D7C1" : "#6D8B72", (float)_rulerOpacity));
        ds.DrawRoundedRectangle(left, top, length, RulerHeight, 8, 8, ink, 1);
        using var small = new CanvasTextFormat { FontFamily = "Consolas", FontSize = 9 };
        using var badge = new CanvasTextFormat { FontFamily = "Consolas", FontSize = 12, HorizontalAlignment = CanvasHorizontalAlignment.Center, VerticalAlignment = CanvasVerticalAlignment.Center };
        for (var i = 0; i <= length; i += 10)
        {
            var major = i % 50 == 0;
            ds.DrawLine(left + i, top, left + i, top + (major ? 23 : i % 20 == 0 ? 15 : 8), ink, major ? 1.3f : 1);
            if (major) ds.DrawText(i.ToString(), left + i + 4, top + RulerHeight - 15, ink, small);
        }
        foreach (var x in new[] { left + 28, length / 2 - 28 })
        {
            ds.FillCircle(x, 0, 13, Direct2DCanvasRenderer.HexToColor("#39735A"));
            ds.DrawText("↻", new Rect(x - 13, -13, 26, 26), Direct2DCanvasRenderer.HexToColor("#FFFFFF"), badge);
        }
        var moveX = -length * .16f;
        ds.FillRoundedRectangle(moveX - 19, -14, 38, 28, 14, 14, Direct2DCanvasRenderer.HexToColor("#39735A"));
        ds.DrawText("✥", new Rect(moveX - 19, -14, 38, 28), Direct2DCanvasRenderer.HexToColor("#FFFFFF"), badge);

        // Stretch handle grip ticks at left and right edges
        ds.DrawLine(left + 5, -16, left + 5, 16, ink, 2);
        ds.DrawLine(left + 9, -16, left + 9, 16, ink, 2);
        var right = length / 2;
        ds.DrawLine(right - 5, -16, right - 5, 16, ink, 2);
        ds.DrawLine(right - 9, -16, right - 9, 16, ink, 2);
        var pivotX = (float)((_rulerPivotRatio - .5) * length);
        var pivotY = RulerPivotY;
        ds.FillCircle(pivotX, pivotY, 6, Direct2DCanvasRenderer.HexToColor("#DDA548", .95f));
        ds.DrawCircle(pivotX, pivotY, 6, Direct2DCanvasRenderer.HexToColor("#FFFFFF", .9f), 1.5f);
        var badgeX = length / 2 - 136;
        ds.FillRoundedRectangle(badgeX, top + 4, 90, 26, 13, 13, Direct2DCanvasRenderer.HexToColor(light ? "#F8FAF4" : "#203A2C", .95f));
        ds.DrawText($"{_rulerAngle:F1}°", new Rect(badgeX, top + 4, 90, 26), ink, badge);
        ds.Transform = old;
    }
}
