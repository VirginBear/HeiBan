using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Windowing;
using global::Windows.Graphics;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private sealed class ChromePreferences
    {public string Dock {get;set;}="top";public double Position {get;set;}=.5;public bool Collapsed {get;set;}}
    private string _chromeDock="top";
    private double _chromePosition=.5;
    private PointInt32? _requestedChromePosition;
    private readonly DispatcherTimer _dockTimer=new(){Interval=TimeSpan.FromMilliseconds(150)};
    private string ChromePreferencesPath=>Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(_recoveryPath))!,"Settings","screen-ui.json");
    private bool VerticalChrome=>_chromeDock is "left" or "right";
    private void InitializeChromeDocking()
    {
        try
        {
            if(File.Exists(ChromePreferencesPath)&&JsonSerializer.Deserialize<ChromePreferences>(File.ReadAllText(ChromePreferencesPath),DocumentCodec.Options) is { } prefs)
            {_chromeDock=prefs.Dock is "top" or "bottom" or "left" or "right"?prefs.Dock:"top";_chromePosition=double.IsFinite(prefs.Position)?Math.Clamp(prefs.Position,0,1):.5;_collapsed=prefs.Collapsed;}
        }catch(Exception e) when(e is IOException or JsonException){_status.Text="停靠偏好讀取未完成，註記仍保留";}
        RebuildChromeLayout();
        AppWindow.Changed+=(_,args)=>{if(!IsActive||!args.DidPositionChange)return;var p=AppWindow.Position;if(_requestedChromePosition is { } expected&&p.X==expected.X&&p.Y==expected.Y)return;_dockTimer.Stop();_dockTimer.Start();};
        _dockTimer.Tick+=(_,_)=>{if(!IsActive){_dockTimer.Stop();return;}if(NativeOverlayWindow.MouseButtonDown)return;_dockTimer.Stop();FinishChromeDrag();};
    }
    private void RebuildChromeLayout()
    {
        // Only the middle scrolls. Color, mode, clear and close remain reachable on short displays.
        if(_chromeToolScroll is not null)_chromeToolScroll.Content=null;
        _chromeStart?.Children.Clear();_chromeEnd?.Children.Clear();_chromeTools?.Children.Clear();
        var vertical=VerticalChrome;var orientation=vertical?Orientation.Vertical:Orientation.Horizontal;
        _chromeStart=new StackPanel{Orientation=orientation,Spacing=4,VerticalAlignment=VerticalAlignment.Center,HorizontalAlignment=HorizontalAlignment.Center};
        _chromeStart.Children.Add(_chromeGrip);_chromeStart.Children.Add(_mode);RefreshMode();
        _chromeTools=new StackPanel{Orientation=orientation,Spacing=4,VerticalAlignment=vertical?VerticalAlignment.Top:VerticalAlignment.Center,HorizontalAlignment=vertical?HorizontalAlignment.Center:HorizontalAlignment.Left};
        foreach(var button in _buttons.Values)_chromeTools.Children.Add(button);
        
        foreach(var button in _chromeActions)_chromeTools.Children.Add(button);
        if(!vertical&&!_collapsed)_chromeTools.Children.Add(_moreButton);
        _chromeEnd=new StackPanel{Orientation=orientation,Spacing=4,VerticalAlignment=VerticalAlignment.Center,HorizontalAlignment=HorizontalAlignment.Center};
        _chromeEnd.Children.Add(_brushButton);_chromeEnd.Children.Add(_dashButton);_chromeEnd.Children.Add(_fillButton);
        _chromeEnd.Children.Add(_clearButton);if(vertical||_collapsed)_chromeEnd.Children.Add(_moreButton);_chromeEnd.Children.Add(_closeButton);
        _chromeToolScroll=new ScrollViewer{Content=_chromeTools,Visibility=_collapsed?Visibility.Collapsed:Visibility.Visible,HorizontalScrollMode=vertical?ScrollMode.Disabled:ScrollMode.Enabled,HorizontalScrollBarVisibility=vertical?ScrollBarVisibility.Disabled:ScrollBarVisibility.Auto,VerticalScrollMode=vertical?ScrollMode.Enabled:ScrollMode.Disabled,VerticalScrollBarVisibility=vertical?ScrollBarVisibility.Auto:ScrollBarVisibility.Disabled,Padding=new Thickness(0),MinWidth=0,MinHeight=0,HorizontalContentAlignment=HorizontalAlignment.Center,VerticalContentAlignment=VerticalAlignment.Top};
        var root=new Grid{Padding=new Thickness(vertical?8:12),ColumnSpacing=6,RowSpacing=6,RequestedTheme=ElementTheme.Light};
        if(vertical){root.RowDefinitions.Add(new(){Height=GridLength.Auto});root.RowDefinitions.Add(new(){Height=new GridLength(1,GridUnitType.Star)});root.RowDefinitions.Add(new(){Height=GridLength.Auto});Grid.SetRow(_chromeToolScroll,1);Grid.SetRow(_chromeEnd,2);}
        else{root.ColumnDefinitions.Add(new(){Width=GridLength.Auto});root.ColumnDefinitions.Add(new(){Width=new GridLength(1,GridUnitType.Star)});root.ColumnDefinitions.Add(new(){Width=GridLength.Auto});Grid.SetColumn(_chromeToolScroll,1);Grid.SetColumn(_chromeEnd,2);}
        root.Children.Add(_chromeStart);root.Children.Add(_chromeToolScroll);root.Children.Add(_chromeEnd);((Border)Content).Child=root;
    }
    private void ResizeChrome()
    {
        _dpiScale=NativeOverlayWindow.DpiScale(WinRT.Interop.WindowNative.GetWindowHandle(this));
        var available=DisplayArea.GetFromWindowId(AppWindow.Id,DisplayAreaFallback.Primary).WorkArea;
        // Measure the controls after orientation changes. DPI converts DIP exactly once into window pixels.
        var unbounded=new global::Windows.Foundation.Size(double.PositiveInfinity,double.PositiveInfinity);
        _chromeStart.Measure(unbounded);_chromeTools.Measure(unbounded);_chromeEnd.Measure(unbounded);
        var start=_chromeStart.DesiredSize;var tools=_collapsed?new global::Windows.Foundation.Size():_chromeTools.DesiredSize;var end=_chromeEnd.DesiredSize;
        var desiredWidth=VerticalChrome?Math.Max(76,Math.Max(start.Width,Math.Max(tools.Width,end.Width))+32):start.Width+tools.Width+end.Width+38;
        var desiredHeight=VerticalChrome?start.Height+tools.Height+end.Height+30:Math.Max(60,Math.Max(start.Height,Math.Max(tools.Height,end.Height))+26);
        var width=(int)Math.Ceiling(desiredWidth*_dpiScale);var height=(int)Math.Ceiling(desiredHeight*_dpiScale);
        NativeOverlayWindow.ResizeCompactWindow(WinRT.Interop.WindowNative.GetWindowHandle(this),Math.Max(1,Math.Min(width,available.Width-(int)(24*_dpiScale))),Math.Max(1,Math.Min(height,available.Height-(int)(24*_dpiScale))));
    }
    private void PositionChrome()
    {
        var area=DisplayArea.GetFromWindowId(AppWindow.Id,DisplayAreaFallback.Primary).WorkArea;var size=AppWindow.Size;var gap=(int)(12*_dpiScale);
        var x=VerticalChrome?(_chromeDock=="left"?area.X+gap:area.X+area.Width-size.Width-gap):area.X+(int)((area.Width-size.Width)*_chromePosition);
        var y=VerticalChrome?area.Y+(int)((area.Height-size.Height)*_chromePosition):(_chromeDock=="top"?area.Y+gap:area.Y+area.Height-size.Height-gap);
        x=Math.Clamp(x,area.X,Math.Max(area.X,area.X+area.Width-size.Width));y=Math.Clamp(y,area.Y,Math.Max(area.Y,area.Y+area.Height-size.Height));_requestedChromePosition=new(x,y);AppWindow.Move(_requestedChromePosition.Value);
    }
    private void DockChrome(string side){_dockTimer.Stop();_chromeDock=side;RebuildChromeLayout();ResizeChrome();PositionChrome();}
    private void FinishChromeDrag()
    {
        var pointer=NativeOverlayWindow.CurrentPointer;var area=DisplayArea.GetFromWindowId(AppWindow.Id,DisplayAreaFallback.Primary).WorkArea;
        var nearest=new[]{("top",Math.Abs(pointer.Y-area.Y)),("bottom",Math.Abs(pointer.Y-area.Y-area.Height)),("left",Math.Abs(pointer.X-area.X)),("right",Math.Abs(pointer.X-area.X-area.Width))}.OrderBy(edge=>edge.Item2).First().Item1;
        _chromeDock=nearest;_chromePosition=VerticalChrome?Math.Clamp((pointer.Y-area.Y)/(double)area.Height,0,1):Math.Clamp((pointer.X-area.X)/(double)area.Width,0,1);DockChrome(nearest);
    }
    private async Task SaveChromePreferencesAsync()
    {try{await DocumentSessionManager.WriteAtomicAsync(ChromePreferencesPath,JsonSerializer.Serialize(new ChromePreferences{Dock=_chromeDock,Position=_chromePosition,Collapsed=_collapsed},DocumentCodec.Options));}catch(Exception e){_status.Text="停靠偏好未保存："+e.Message;}}
    private object ValidateChromeDocking()
    {
        var savedDock=_chromeDock;var savedCollapsed=_collapsed;var savedPosition=_chromePosition;SetChromeCollapsed(false);
        try
        {
            DockChrome("left");var left=AppWindow.Size;if(left.Width<60*_dpiScale||left.Width>=left.Height||_chromeTools.Orientation!=Orientation.Vertical)throw new InvalidOperationException($"左側直排未生效：{left.Width}×{left.Height}，DPI={_dpiScale}。");
            SetChromeCollapsed(true);var collapsed=AppWindow.Size;if(collapsed.Height>=left.Height)throw new InvalidOperationException("直排收合未生效。");
            SetChromeCollapsed(false);DockChrome("right");if(_chromeTools.Orientation!=Orientation.Vertical)throw new InvalidOperationException("右側直排未生效。");
            DockChrome("bottom");if(_chromeTools.Orientation!=Orientation.Horizontal)throw new InvalidOperationException("下方橫排未生效。");
            DockChrome("top");return new{fourSides=true,verticalWidth=left.Width,verticalHeight=left.Height,collapsedVerticalHeight=collapsed.Height,iconOnly=true,fixedClearClose=true,singleHorizontalRow=true,valuesAndHandlersRetained=true,dragHardware="未執行"};
        }
        finally{_chromeDock=savedDock;_chromePosition=savedPosition;SetChromeCollapsed(savedCollapsed);DockChrome(savedDock);}
    }
}
