using static HeiBan.Windows.Localization.Strings;
using System.Numerics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private readonly CompassToolEngine _compass = new();
    private bool _compassCenterMoving, _compassCenterMoved, _compassRadiusMoving, _compassPencilMoving;
    private global::Windows.Foundation.Rect? _lastCompassDamage;

    private void ToggleScreenCompass()
    {
        _compass.IsEnabled = !_compass.IsEnabled;
        if (_compass.IsEnabled)
        {
            _compass.Prepare();
            _compass.StrokeColor = _color;
            _compass.StrokeWidth = _width * _dpiScale;
            _compass.LineStyle = _dash;
            _compass.Center = new InkPoint(_overlay.Width / 2, _overlay.Height / 2);
        }
        DamageCompass();
        RefreshButtons();
        Changed();
    }

    private void ShowScreenCompassPanel(FrameworkElement anchor)
    {
        _compass.IsEnabled = true;
        _compass.StrokeColor = _color;
        _compass.StrokeWidth = _width * _dpiScale;
        _compass.LineStyle = _dash;

        var panel = new StackPanel { Width = 280, Spacing = 10, Padding = new Thickness(4), RequestedTheme = ElementTheme.Light };
        panel.Children.Add(new TextBlock { Text = T("圓規"), FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });

        var centerCoord = new TextBlock { Text = F($"圓心座標：({_compass.Center.X:0.#}, {_compass.Center.Y:0.#})"), FontSize = 12, Foreground = ChromeBrush(255, 104, 117, 108) };
        panel.Children.Add(centerCoord);

        var centerBtn = new Button { Content = T("置於畫面中央"), HorizontalAlignment = HorizontalAlignment.Stretch };
        centerBtn.Click += (_, _) =>
        {
            DamageCompass();
            _compass.MoveCenter(new InkPoint(_overlay.Width / 2, _overlay.Height / 2));
            centerCoord.Text = F($"圓心座標：({_compass.Center.X:0.#}, {_compass.Center.Y:0.#})");
            DamageCompass();
            _dirty = true;
        };
        panel.Children.Add(centerBtn);

        var rSlider = new Slider { Header = F($"半徑（pt）：{_compass.Radius:0.#}"), Minimum = 10, Maximum = 1000, Value = _compass.Radius, StepFrequency = 5 };
        rSlider.ValueChanged += (_, e) =>
        {
            DamageCompass();
            _compass.AdjustRadius(e.NewValue);
            rSlider.Header = F($"半徑（pt）：{_compass.Radius:0.#}");
            DamageCompass();
            _dirty = true;
        };
        panel.Children.Add(rSlider);

        var startAngleBox = new NumberBox { Header = T("起點角度（0~360°）"), Value = _compass.StartAngle, SmallChange = 1, Minimum = 0, Maximum = 360, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline };
        startAngleBox.ValueChanged += (_, e) =>
        {
            if (double.IsFinite(e.NewValue)) { DamageCompass(); _compass.SetStartAngle(e.NewValue); DamageCompass(); _dirty = true; }
        };
        panel.Children.Add(startAngleBox);

        var sweepAngleBox = new NumberBox { Header = T("掃動角度（-360~360°）"), Value = _compass.SweepAngle, SmallChange = 1, Minimum = -360, Maximum = 360, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline };
        sweepAngleBox.ValueChanged += (_, e) =>
        {
            if (double.IsFinite(e.NewValue)) { DamageCompass(); _compass.SetSweepAngle(e.NewValue); DamageCompass(); _dirty = true; }
        };
        panel.Children.Add(sweepAngleBox);

        var lockToggle = new ToggleButton { Content = _compass.IsArmed ? T("已鎖定圓心作畫") : T("鎖定圓心（作畫階段）"), IsChecked = _compass.IsArmed, HorizontalAlignment = HorizontalAlignment.Stretch };
        lockToggle.Click += (_, _) =>
        {
            _compass.ToggleArmed();
            lockToggle.Content = _compass.IsArmed ? T("已鎖定圓心作畫") : T("鎖定圓心（作畫階段）");
            lockToggle.IsChecked = _compass.IsArmed;
            DamageCompass();
            _dirty = true;
        };
        panel.Children.Add(lockToggle);

        var fullCircleBtn = new Button { Content = T("生成整圓（360°）"), Style = (Style)Application.Current.Resources["AccentButtonStyle"], HorizontalAlignment = HorizontalAlignment.Stretch };
        fullCircleBtn.Click += (_, _) =>
        {
            _compass.StrokeColor = _color;
            _compass.StrokeWidth = _width * _dpiScale;
            _compass.LineStyle = _dash;
            var circleObj = _compass.CreateArcObject("screen", "screen_page", fullCircle: true);
            _session.Begin();
            _session.Add(circleObj);
            _session.SelectedId = circleObj.Id;
            _session.Commit();
            _compass.Prepare();
            _tool = "select";
            _overlay.SetManipulationCursor(null, null, _tool);
            RefreshButtons();
            Changed();
            _status.Text = F($"已生成整圓（半徑 {_compass.Radius:0.#}pt）");
        };
        panel.Children.Add(fullCircleBtn);

        var resetBtn = new Button { Content = T("重設圓規"), HorizontalAlignment = HorizontalAlignment.Stretch };
        resetBtn.Click += (_, _) =>
        {
            DamageCompass();
            _compass.Prepare();
            lockToggle.Content = T("鎖定圓心（作畫階段）");
            lockToggle.IsChecked = false;
            startAngleBox.Value = _compass.StartAngle;
            sweepAngleBox.Value = _compass.SweepAngle;
            DamageCompass();
            _dirty = true;
        };
        panel.Children.Add(resetBtn);

        panel.Children.Add(new TextBlock { Text = T("準備階段：拖曳圓心移動位置，拖曳內側把手調整半徑，拖曳筆尖定位起點。\n作畫階段：拖曳筆尖掃出圓弧，放開即生成精確圓弧物件。"), TextWrapping = TextWrapping.Wrap, FontSize = 12, Foreground = ChromeBrush(255, 104, 117, 108) });

        ShowChromeFlyout(new Flyout { Content = new ScrollViewer { Content = panel, MaxHeight = 440, VerticalScrollBarVisibility = ScrollBarVisibility.Auto } }, anchor);
    }

    private bool CompassCenterHit(Vector2 p) => Vector2.Distance(p, new Vector2((float)_compass.Center.X, (float)_compass.Center.Y)) <= 16;
    private bool CompassRadiusHit(Vector2 p)
    {
        var radH = new Vector2((float)(_compass.Center.X + _compass.Radius * 0.65), (float)_compass.Center.Y);
        return Vector2.Distance(p, radH) <= 14;
    }
    private bool CompassPencilHit(Vector2 p)
    {
        var rad = _compass.CurrentPencilAngle * Math.PI / 180.0;
        var pencilPt = new Vector2((float)(_compass.Center.X + _compass.Radius * Math.Cos(rad)), (float)(_compass.Center.Y + _compass.Radius * Math.Sin(rad)));
        return Vector2.Distance(p, pencilPt) <= 16;
    }

    private global::Windows.Foundation.Rect? GetCompassDamageRect()
    {
        if (!_compass.IsEnabled) return null;
        var cx = _compass.Center.X; var cy = _compass.Center.Y;
        var r = _compass.Radius + 32;
        var left = Math.Max(0, Math.Floor(cx - r));
        var top = Math.Max(0, Math.Floor(cy - r));
        var right = Math.Min(_overlay.Width, Math.Ceiling(cx + r));
        var bottom = Math.Min(_overlay.Height, Math.Ceiling(cy + r));
        if (right > left && bottom > top) return new global::Windows.Foundation.Rect(left, top, right - left, bottom - top);
        return null;
    }

    private void DamageCompass()
    {
        var rect = GetCompassDamageRect();
        if (_lastCompassDamage is { } last) AddScreenDamage(last);
        if (rect is { } current) AddScreenDamage(current);
        _lastCompassDamage = rect;
    }
}
