using static HeiBan.Windows.Localization.Strings;
using System.Numerics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Xaml;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using global::Windows.Foundation;
using global::Windows.Globalization.NumberFormatting;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private bool _rulerEnabled;
    private int _rulerStretchSide;
    private float _rulerGrabOffset;
    private double _rulerOpacity = .38, _rulerPivotRatio = .5, _rulerRotationStart, _rulerPointerStart;
    private Vector2 _rulerFixedPivot;
    private string _rulerPivotEdge = "center";
    private bool _rulerPivotMoving, _rulerMoving, _rulerRotating;
    private Vector2 _rulerCenter = new(600, 450);
    private double _rulerAngle;
    private string? _rulerColor;
    private Vector2? _snapEdge;
    private Vector2 _snapDirection;
    private global::Windows.Foundation.Rect? _lastRulerDamage;

    // The overlay is a 96-DPI target addressed in physical desktop pixels.
    private float RulerScale => (float)_dpiScale;
    private float RulerHeight => RulerGeometry.HeightDip * RulerScale;
    private float RulerLength => _owner.SharedRulerLength * RulerScale;
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
        return Math.Abs(local.X - (-RulerLength / 2)) <= RulerGeometry.EndGripDip * RulerScale && Math.Abs(local.Y) <= RulerHeight / 2;
    }
    private bool RulerRightEdgeHit(Vector2 p)
    {
        var local = RulerLocal(p);
        return Math.Abs(local.X - (RulerLength / 2)) <= RulerGeometry.EndGripDip * RulerScale && Math.Abs(local.Y) <= RulerHeight / 2;
    }
    private bool RulerRotationHit(Vector2 p) =>
        Vector2.Distance(p, RulerPoint(RulerLength / 2 - RulerGeometry.HandleInsetDip * RulerScale)) <= 18 * RulerScale || Vector2.Distance(p, RulerPoint(-RulerLength / 2 + RulerGeometry.HandleInsetDip * RulerScale)) <= 18 * RulerScale;
    private bool RulerPivotHit(Vector2 p) => Vector2.Distance(p, RulerPivot()) < 10 * RulerScale;
    private bool RulerAngleHit(Vector2 p)
    {
        var local = RulerLocal(p);
        return local.X > RulerLength / 2 - 136 * RulerScale && local.X < RulerLength / 2 - 46 * RulerScale && local.Y > -29 * RulerScale && local.Y < -RulerScale;
    }
    private bool RulerHit(Vector2 point)
    {
        var p = RulerLocal(point);
        return Math.Abs(p.X) < RulerLength / 2 - RulerGeometry.EndGripDip * RulerScale && Math.Abs(p.Y) < RulerHeight / 2 - 4 * RulerScale
            && !RulerRotationHit(point) && !RulerPivotHit(point) && !RulerAngleHit(point);
    }
    private void BeginRulerStretch(Vector2 point, int side)
    {
        _rulerStretchSide = side;
        _rulerGrabOffset = (RulerLocal(point).X - side * RulerLength / 2) / RulerScale;
    }

    private void StretchRuler(Vector2 point)
    {
        DamageRuler();
        var previous = _owner.SharedRulerLength;
        var length = RulerGeometry.Stretch(previous, RulerLocal(point).X / RulerScale, _rulerGrabOffset, _rulerStretchSide);
        _rulerCenter += RulerDirection() * (_rulerStretchSide * (length - previous) * RulerScale / 2);
        _owner.SetSharedRulerLength(length);
        DamageRuler();
        _dirty = true;
    }

    private void FinishRulerStretch()
    {
        if (_rulerStretchSide == 0) return;
        _rulerStretchSide = 0;
        _owner.QueueTeachingSettingsSave();
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
        DamageRuler();_rulerEnabled=!_rulerEnabled;
        if(_rulerEnabled)CenterScreenRuler();
        DamageRuler();RefreshButtons();_dirty=true;
    }
    private void CenterScreenRuler()
    {
        var area=DisplayArea.GetFromWindowId(AppWindow.Id,DisplayAreaFallback.Primary).WorkArea;
        _ = _owner.SharedRulerLength;
        // DisplayArea is desktop physical pixels; renderer/input use overlay-local pixels.
        _rulerCenter=new((float)(area.X+area.Width*.5-_overlay.Left),(float)(area.Y+area.Height*.55-_overlay.Top));
    }
    private void RecoverScreenRuler()
    {DamageRuler();_rulerEnabled=true;CenterScreenRuler();DamageRuler();RefreshButtons();_dirty=true;}
    private MenuFlyoutSubItem CreateScreenRulerMenu()
    {
        var menu=new MenuFlyoutSubItem{Text=T("螢幕尺"),Icon=ToolIcons.CreateMenuIcon("ruler")};
        var show=new ToggleMenuFlyoutItem{Text=T("顯示"),IsChecked=_rulerEnabled};show.Click+=(_,_)=>ToggleScreenRuler();menu.Items.Add(show);
        var recover=new MenuFlyoutItem{Text=T("重新顯示螢幕尺")};recover.Click+=(_,_)=>RecoverScreenRuler();menu.Items.Add(recover);
        var settings=new MenuFlyoutItem{Text=T("尺規設定")};settings.Click+=(_,_)=>ShowScreenRulerSettings(_moreButton);menu.Items.Add(settings);
        return menu;
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
        var length = new Slider { Header = T("尺長（DIP）"), Minimum = RulerGeometry.MinimumLengthDip, Maximum = RulerGeometry.MaximumLengthDip, Value = _owner.SharedRulerLength, StepFrequency = 1 };
        length.ValueChanged += (_, e) => { var pivot = RulerPivot(); _owner.SetSharedRulerLength((float)e.NewValue); _owner.QueueTeachingSettingsSave(); SetRulerAngle(_rulerAngle, pivot); DamageRuler(); _dirty = true; };
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
        if (Math.Abs(along) > RulerLength / 2 + 24 * RulerScale || Math.Abs(Math.Abs(perpendicular) - RulerHeight / 2) > 20 * RulerScale) return;
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
        var pad = 16.0 * RulerScale;
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
    private void DrawRuler(CanvasDrawingSession ds) =>
        _renderer.RenderRuler(ds, _rulerCenter, _rulerAngle, _owner.SharedRulerLength, RulerGeometry.HeightDip,
            _rulerOpacity, _rulerPivotRatio, RulerPivotY / RulerScale, _rulerColor, light: true, scale: RulerScale);
}
