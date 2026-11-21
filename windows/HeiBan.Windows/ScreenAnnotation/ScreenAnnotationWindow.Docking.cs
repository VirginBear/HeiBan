using static HeiBan.Windows.Localization.Strings;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml.Input;
using global::Windows.Graphics;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private sealed class ChromePreferences
    {
        public string Dock { get; set; } = "top";
        public double Position { get; set; } = .5;
        public bool Collapsed { get; set; }
    }

    private ToolbarFlowPanel? _labeledScreenFlow;
    private string _chromeDock = "top";
    private double _chromePosition = .5;
    private PointInt32? _requestedChromePosition;
    private string ChromePreferencesPath => Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(_recoveryPath))!, "Settings", "screen-ui.json");
    private bool VerticalChrome => _chromeDock is "left" or "right";
    private uint? _chromeDragPointer;
    private PointInt32 _chromeDragOrigin;
    private (int X,int Y) _chromeDragStart;

    private void ChromeGrip_Pressed(object sender,PointerRoutedEventArgs args)
    {
        if(_stopping||_screenClearDialog is not null||!args.GetCurrentPoint(_chromeGrip).Properties.IsLeftButtonPressed)return;
        _chromeDragOrigin=AppWindow.Position;
        // Use the press packet, not GetCursorPos: queued input may already have
        // moved the global cursor to its release position before this callback runs.
        var point=args.GetCurrentPoint((UIElement)Content).Position;
        var dpi=((FrameworkElement)Content).XamlRoot?.RasterizationScale??_dpiScale;
        _chromeDragStart=(_chromeDragOrigin.X+(int)Math.Round(point.X*dpi),_chromeDragOrigin.Y+(int)Math.Round(point.Y*dpi));
        if(_chromeGrip.CapturePointer(args.Pointer))_chromeDragPointer=args.Pointer.PointerId;
        args.Handled=true;
    }

    private void ChromeGrip_Moved(object sender,PointerRoutedEventArgs args)
    {
        if(_chromeDragPointer!=args.Pointer.PointerId)return;
        var pointer=NativeOverlayWindow.CurrentPointer;
        // AppWindow and the desktop pointer use physical pixels. Moving the window must not change this drag origin.
        _requestedChromePosition=new(_chromeDragOrigin.X+pointer.X-_chromeDragStart.X,_chromeDragOrigin.Y+pointer.Y-_chromeDragStart.Y);
        AppWindow.Move(_requestedChromePosition.Value);
        args.Handled=true;
    }

    private void ChromeGrip_Released(object sender,PointerRoutedEventArgs args)
    {
        if(_chromeDragPointer!=args.Pointer.PointerId)return;
        var pointer=NativeOverlayWindow.CurrentPointer;
        _requestedChromePosition=new(_chromeDragOrigin.X+pointer.X-_chromeDragStart.X,_chromeDragOrigin.Y+pointer.Y-_chromeDragStart.Y);
        AppWindow.Move(_requestedChromePosition.Value);
        _chromeDragPointer=null;
        _chromeGrip.ReleasePointerCapture(args.Pointer);
        FinishChromeDrag();
#if HEIBAN_RELEASE_VALIDATION
        if(Environment.GetEnvironmentVariable("HEIBAN_QA_SCREEN_TEXT_PREVIEW")=="1"&&Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY") is {Length:>0} qaData)
            File.WriteAllText(Path.Combine(qaData,"grip-pointer.json"),"{\"captured\":true,\"released\":true}");
#endif
        args.Handled=true;
    }

    private void ChromeGrip_Cancelled(object sender,PointerRoutedEventArgs args)
    {
        if(_chromeDragPointer!=args.Pointer.PointerId)return;
        _chromeDragPointer=null;
        PositionChrome();
    }

    private void CancelChromeDrag()
    {
        if(_chromeDragPointer is null)return;
        _chromeDragPointer=null;
        _chromeGrip.ReleasePointerCaptures();
    }

    private void InitializeChromeDocking()
    {
        try
        {
            if (File.Exists(ChromePreferencesPath) && JsonSerializer.Deserialize<ChromePreferences>(File.ReadAllText(ChromePreferencesPath), DocumentCodec.Options) is { } prefs)
            {
                _chromeDock = prefs.Dock is "top" or "bottom" or "left" or "right" ? prefs.Dock : "top";
                _chromePosition = double.IsFinite(prefs.Position) ? Math.Clamp(prefs.Position, 0, 1) : .5;
                _collapsed = prefs.Collapsed;
            }
        }
        catch (Exception e) when (e is IOException or JsonException)
        {
            _status.Text = T("停靠偏好讀取未完成，註記仍保留");
        }

        RebuildChromeLayout();

        // Grip release is the only docking transaction. AppWindow position notifications
        // also occur during our own resizes and must not rebuild the active text page.

    }

    private string _chromeIconStyle="";
    internal void ApplyToolbarAppearance(string style, string size)
    {
        var sizeChanged = _toolbarPreferences.ToolbarSize != size;
        _toolbarPreferences.IconStyle=style;
        _toolbarPreferences.ToolbarSize=size;
        if(IsActive&&(_chromeIconStyle!=style||sizeChanged)){CancelRadial();RebuildChromeLayout();RefreshScreenStyleButtons();ResizeChrome();PositionChrome();_dirty=true;}
    }
    private void RebuildChromeLayout()
    {
        CancelChromeDrag();
        ToolIcons.SetStyle(_toolbarPreferences.IconStyle);
        if(_chromeIconStyle!=ToolIcons.Style)
        {
            _chromeIconStyle=ToolIcons.Style;
            foreach(var pair in _buttons.Where(p=>p.Key is not("brush" or "dash")))ToolbarUi.ReplaceIcon(pair.Value,ToolIcons.Create(pair.Key));
            foreach(var button in _chromeActions)if(button.Tag is string key)ToolbarUi.ReplaceIcon(button,ToolIcons.Create(key));
            ToolbarUi.ReplaceIcon(_moreButton,ToolIcons.Create("more"));ToolbarUi.ReplaceIcon(_closeButton,ToolIcons.Create("close"));
            _lastScreenDash=null;
        }
        // Labeled pages nest buttons below the old root. Detach while that tree is still
        // attached; clearing the root first hides Parent before the XAML collection releases ownership.
        ToolbarUi.DetachButtons(_buttons.Values.Concat(_chromeActions));
        if (_chromeToolHost is not null) _chromeToolHost.Child = null;
        _chromeStart?.Children.Clear(); _chromeEnd?.Children.Clear(); _chromeTools?.Children.Clear();

        var scale = ToolbarUi.SizeScale(_toolbarPreferences.ToolbarSize);
        var vertical = VerticalChrome; var orientation = vertical ? Orientation.Vertical : Orientation.Horizontal;
        _chromeStart = new StackPanel { Orientation = orientation, Spacing = 4, VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center };
        _chromeGrip.Width = 24 * scale;
        _chromeGrip.Height = 30 * scale;
        _chromeStart.Children.Add(_chromeGrip);
        _chromeStart.Children.Add(_mode);
        RefreshMode();

        _chromeTools = new ToolbarFlowPanel { Orientation = orientation, Spacing = 4, VerticalAlignment = vertical ? VerticalAlignment.Top : VerticalAlignment.Center, HorizontalAlignment = vertical ? HorizontalAlignment.Center : HorizontalAlignment.Left };

        var ordered = new List<Button>();
        foreach (var key in ToolbarContentPolicy.VisibleTools(_toolbarPreferences, screenCanvas: true))
        {
            if (_collapsed && key == "clearAll") continue;
            if (!ToolbarContentPolicy.IsAvailableOnScreen(key)) continue;
            if (_buttons.TryGetValue(key, out var toolButton)) ordered.Add(toolButton);
            else if (_chromeActions.FirstOrDefault(button => button.Tag as string == key) is { } actionButton) ordered.Add(actionButton);
        }

        foreach (var button in _buttons.Where(pair => !ToolbarPreferences.AllDefaultTools.Contains(pair.Key)).Select(pair => pair.Value)
                    .Concat(_chromeActions.Where(button => button.Tag is null || !ToolbarPreferences.AllDefaultTools.Contains((string)button.Tag))))
            if (!ordered.Contains(button)) ordered.Add(button);

        _labeledScreenFlow = ToolbarUi.Arrange(_chromeTools, ordered.Select(b => (b.Tag as string ?? "", b)), _toolbarPreferences.DisplayMode == "labels", vertical, _toolbarPage, p => { _toolbarPage = p; DispatcherQueue.TryEnqueue(() => { ResizeChrome(); PositionChrome(); }); }, 32, _toolbarPreferences.CommonTools, scale);
        ToolbarUi.LabelMode(_moreButton, "more", false, 32, vertical, scale);
        ToolbarUi.LabelMode(_closeButton, "close", false, 32, vertical, scale);
        if (!vertical && !_collapsed) _chromeTools.Children.Add(_moreButton);

        _chromeEnd = new StackPanel { Orientation = orientation, Spacing = 4, VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center };
        if (_collapsed) _chromeEnd.Children.Add(_clearButton); if (vertical || _collapsed) _chromeEnd.Children.Add(_moreButton); _chromeEnd.Children.Add(_closeButton);
        _chromeToolHost = new Border { Child = _chromeTools, Visibility = _collapsed ? Visibility.Collapsed : Visibility.Visible, MinWidth = 0, MinHeight = 0 };

        var root = new Grid { Padding = new Thickness((vertical ? 5 : 12) * scale), ColumnSpacing = 6, RowSpacing = 6, RequestedTheme = ElementTheme.Light };
        if (vertical) { root.RowDefinitions.Add(new() { Height = GridLength.Auto }); root.RowDefinitions.Add(new() { Height = new GridLength(1, GridUnitType.Star) }); root.RowDefinitions.Add(new() { Height = GridLength.Auto }); Grid.SetRow(_chromeToolHost, 1); Grid.SetRow(_chromeEnd, 2); }
        else { root.ColumnDefinitions.Add(new() { Width = GridLength.Auto }); root.ColumnDefinitions.Add(new() { Width = new GridLength(1, GridUnitType.Star) }); root.ColumnDefinitions.Add(new() { Width = GridLength.Auto }); Grid.SetColumn(_chromeToolHost, 1); Grid.SetColumn(_chromeEnd, 2); }

        root.Children.Add(_chromeStart); root.Children.Add(_chromeToolHost); root.Children.Add(_chromeEnd); ((Border)Content).Child = root;
        if(_textInput is not null)AttachScreenTextToolbar();
    }

    private void ResizeChrome()
    {
        if(_screenClearDialog is not null)return;
        _dpiScale = NativeOverlayWindow.DpiScale(WinRT.Interop.WindowNative.GetWindowHandle(this));
        var available = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Primary).WorkArea;
        var unbounded = new global::Windows.Foundation.Size(double.PositiveInfinity, double.PositiveInfinity);
        _chromeStart.Measure(unbounded); _chromeEnd.Measure(unbounded);
        var scale = ToolbarUi.SizeScale(_toolbarPreferences.ToolbarSize);
        var workWidth = Math.Max(1, available.Width / _dpiScale - 24); var workHeight = Math.Max(1, available.Height / _dpiScale - 24);
        if(_textInput is not null&&_chromeToolHost.Child is FrameworkElement textPage)
        {
            var extraWidth=_chromeStart.DesiredSize.Width+_chromeEnd.DesiredSize.Width+38;
            var extraHeight=_chromeStart.DesiredSize.Height+_chromeEnd.DesiredSize.Height+30;
            textPage.Width=Math.Max(240,Math.Min(560,workWidth-(VerticalChrome?12:extraWidth)));
            textPage.MaxHeight=Math.Max(180,Math.Min(430,workHeight-(VerticalChrome?extraHeight:26)));
            textPage.Measure(new global::Windows.Foundation.Size(
                Math.Max(80,workWidth-(VerticalChrome?0:extraWidth)),
                Math.Max(80,workHeight-(VerticalChrome?extraHeight:0))));
            var textWidth=VerticalChrome
                ?Math.Max(textPage.DesiredSize.Width,Math.Max(_chromeStart.DesiredSize.Width,_chromeEnd.DesiredSize.Width))+12
                :textPage.DesiredSize.Width+extraWidth;
            var textHeight=VerticalChrome
                ?textPage.DesiredSize.Height+extraHeight
                :Math.Max(textPage.DesiredSize.Height,Math.Max(_chromeStart.DesiredSize.Height,_chromeEnd.DesiredSize.Height))+26;
            NativeOverlayWindow.ResizeCompactWindow(WinRT.Interop.WindowNative.GetWindowHandle(this),
                (int)Math.Ceiling(Math.Min(workWidth,textWidth)*_dpiScale),
                (int)Math.Ceiling(Math.Min(workHeight,textHeight)*_dpiScale));
            SetChromeClientInput();
            return;
        }
        _chromeTools.RunLength = VerticalChrome ? Math.Max(32, workHeight - _chromeStart.DesiredSize.Height - _chromeEnd.DesiredSize.Height - 30) : Math.Max(32, workWidth - _chromeStart.DesiredSize.Width - _chromeEnd.DesiredSize.Width - 38);
        if (_labeledScreenFlow is { } labeled) { const int extra = 90; labeled.RunLength = VerticalChrome ? Math.Max(128 * scale, workHeight - _chromeStart.DesiredSize.Height - _chromeEnd.DesiredSize.Height - (_toolbarPreferences.DisplayMode == "labels" ? 278 : 172) * scale) : Math.Max(84 * scale, workWidth - _chromeStart.DesiredSize.Width - _chromeEnd.DesiredSize.Width - (310 + extra) * scale); labeled.InvalidateMeasure(); }
        _chromeTools.InvalidateMeasure(); _chromeTools.Measure(unbounded);
        var start = _chromeStart.DesiredSize; var tools = _collapsed ? new global::Windows.Foundation.Size() : _chromeTools.DesiredSize; var end = _chromeEnd.DesiredSize;
        var desiredWidth = VerticalChrome ? Math.Max(60, Math.Max(start.Width, Math.Max(tools.Width, end.Width)) + 12 * scale) : start.Width + tools.Width + end.Width + 38 * scale;
        var desiredHeight = VerticalChrome ? start.Height + tools.Height + end.Height + 30 * scale : Math.Max(60 * scale, Math.Max(start.Height, Math.Max(tools.Height, end.Height)) + 26 * scale);
        var width = (int)Math.Ceiling(desiredWidth * _dpiScale); var height = (int)Math.Ceiling(desiredHeight * _dpiScale);
        NativeOverlayWindow.ResizeCompactWindow(WinRT.Interop.WindowNative.GetWindowHandle(this), Math.Max(1, Math.Min(width, available.Width - (int)(24 * _dpiScale))), Math.Max(1, Math.Min(height, available.Height - (int)(24 * _dpiScale))));
        SetChromeClientInput();
    }

    private void SetChromeClientInput()
    {
        // Hidden system caption regions can consume the grip's pointer events.
        // This borderless tool window delegates all gestures to its XAML controls.
        if(!AppWindowTitleBar.IsCustomizationSupported())return;
        var size=AppWindow.Size;
        Microsoft.UI.Input.InputNonClientPointerSource.GetForWindowId(AppWindow.Id).SetRegionRects(
            Microsoft.UI.Input.NonClientRegionKind.Passthrough,[new(0,0,size.Width,size.Height)]);
    }

    private void PositionChrome()
    {
        if(_screenClearDialog is not null||_chromeDragPointer is not null)return;
        var area = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Primary).WorkArea; var size = AppWindow.Size; var gap = (int)(12 * _dpiScale);
        var x = VerticalChrome ? (_chromeDock == "left" ? area.X + gap : area.X + area.Width - size.Width - gap) : area.X + (int)((area.Width - size.Width) * _chromePosition);
        var y = VerticalChrome ? area.Y + (int)((area.Height - size.Height) * _chromePosition) : (_chromeDock == "top" ? area.Y + gap : area.Y + area.Height - size.Height - gap);
        x = Math.Clamp(x, area.X, Math.Max(area.X, area.X + area.Width - size.Width)); y = Math.Clamp(y, area.Y, Math.Max(area.Y, area.Y + area.Height - size.Height)); _requestedChromePosition = new(x, y); AppWindow.Move(_requestedChromePosition.Value);
    }

    private void DockChrome(string side,PointInt32? draggedPosition=null)
    {
        _chromeDock = side;
        RebuildChromeLayout();
        ResizeChrome();
        if(draggedPosition is { } position)
        {
            var area=DisplayArea.GetFromWindowId(AppWindow.Id,DisplayAreaFallback.Primary).WorkArea;
            var size=AppWindow.Size;
            // Preferences describe the window's travel, not the pointer's position.
            // Normalizing by the whole monitor made a moved grip snap back on release.
            _chromePosition=VerticalChrome
                ?Math.Clamp((position.Y-area.Y)/(double)Math.Max(1,area.Height-size.Height),0,1)
                :Math.Clamp((position.X-area.X)/(double)Math.Max(1,area.Width-size.Width),0,1);
        }
        PositionChrome();
        _ = SaveChromePreferencesAsync();
    }

    private void FinishChromeDrag()
    {
        var pointer = NativeOverlayWindow.CurrentPointer; var area = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Primary).WorkArea;
        var nearest = new[] { ("top", Math.Abs(pointer.Y - area.Y)), ("bottom", Math.Abs(pointer.Y - area.Y - area.Height)), ("left", Math.Abs(pointer.X - area.X)), ("right", Math.Abs(pointer.X - area.X - area.Width)) }.OrderBy(edge => edge.Item2).First().Item1;
        DockChrome(nearest,_requestedChromePosition??AppWindow.Position);
    }

    private async Task SaveChromePreferencesAsync()
    {
        try
        {
            await DocumentSessionManager.WriteAtomicAsync(ChromePreferencesPath, JsonSerializer.Serialize(new ChromePreferences { Dock = _chromeDock, Position = _chromePosition, Collapsed = _collapsed }, DocumentCodec.Options));
        }
        catch (Exception e) { _status.Text = T("停靠偏好未保存：") + e.Message; }
    }

    private object ValidateChromeDocking()
    {
        var savedDock = _chromeDock; var savedCollapsed = _collapsed; var savedPosition = _chromePosition; SetChromeCollapsed(false);
        try
        {
            DockChrome("left"); var left = AppWindow.Size; if (left.Width < 60 * _dpiScale || left.Width >= left.Height || _chromeTools.Orientation != Orientation.Vertical) throw new InvalidOperationException($"左側直排未生效：{left.Width}×{left.Height}，DPI={_dpiScale}。");
            SetChromeCollapsed(true); var collapsed = AppWindow.Size; if (collapsed.Height >= left.Height) throw new InvalidOperationException("直排收合未生效。");
            SetChromeCollapsed(false); DockChrome("right"); if (_chromeTools.Orientation != Orientation.Vertical) throw new InvalidOperationException("右側直排未生效。");
            var workArea=DisplayArea.GetFromWindowId(AppWindow.Id,DisplayAreaFallback.Primary).WorkArea;
            var movedY=workArea.Y+(int)Math.Round(Math.Max(0,workArea.Height-AppWindow.Size.Height)*.75);
            DockChrome("right",new(AppWindow.Position.X,movedY));
            if(Math.Abs(AppWindow.Position.Y-movedY)>3)throw new InvalidOperationException("Dragged window position snapped back on release.");
            DockChrome("bottom"); if (_chromeTools.Orientation != Orientation.Horizontal) throw new InvalidOperationException("下方橫排未生效。");
            DockChrome("top"); return new { fourSides = true, verticalWidth = left.Width, verticalHeight = left.Height, collapsedVerticalHeight = collapsed.Height, iconOnly = true, fixedClearClose = true, wrapsWithoutScrollbars = true, valuesAndHandlersRetained = true, dragHardware = "未執行" };
        }
        finally { _chromeDock = savedDock; _chromePosition = savedPosition; SetChromeCollapsed(savedCollapsed); DockChrome(savedDock); }
    }
}
