using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.Foundation;
using static HeiBan.Windows.Localization.Strings;
namespace HeiBan.Windows.Views;

// Non-modal: a ContentDialog would block the toolbar which supplies the drag source.
internal sealed class RadialWheelSettingsWindow : Window
{
    internal const string DragFormat="HeiBan.RadialToolKey.v1";
    private readonly RadialToolProfile _profile;
    private readonly bool _screen;
    private readonly Func<Task> _save;
    private readonly CanvasControl _canvas=new(){Width=320,Height=320,AllowDrop=true};
    private readonly Direct2DCanvasRenderer _renderer=new();
    private readonly TextBlock _status=new(){TextWrapping=TextWrapping.Wrap,MaxWidth=590};
    private readonly List<ComboBox> _choices=[];
    private bool _refreshing,_closed;private int _hover=-1;
    private readonly string[] _keys;
    internal nint Handle=>WinRT.Interop.WindowNative.GetWindowHandle(this);
    internal RadialWheelSettingsWindow(RadialToolProfile profile,bool screen,Func<Task> save)
    {
        _profile=profile;_screen=screen;_save=save;
        Title=T("右鍵工具輪盤")+" · "+T(screen?"螢幕畫布":"畫布");
        _keys=new[]{""}.Concat(ToolbarPreferences.AllDefaultTools).Concat(new[]{"line","arrow","rect","circle","triangle","quadrilateral","diamond","pentagon","star"}).Where(k=>k==""||RadialToolProfile.Allowed(k,screen)).Distinct().ToArray();
        var root=new StackPanel{FlowDirection=RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Spacing=12,Padding=new Thickness(18),RequestedTheme=ElementTheme.Light,Background=new SolidColorBrush(global::Windows.UI.Color.FromArgb(255,247,250,246))};
        root.Children.Add(new TextBlock{Text=T("右鍵工具輪盤"),FontSize=22});
        root.Children.Add(new TextBlock{Text=T("將上方工具列的圖示拖到輪盤格子；也可使用右側選單。"),TextWrapping=TextWrapping.Wrap,MaxWidth=590});
        var body=new StackPanel{FlowDirection=FlowDirection.LeftToRight,Orientation=Orientation.Horizontal,Spacing=14};body.Children.Add(_canvas);
        var options=new StackPanel{FlowDirection=RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Spacing=4,Width=250};
        for(var i=0;i<RadialToolProfile.Count;i++)
        {
            var slot=i;var row=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8};
            row.Children.Add(new TextBlock{Text=(i+1).ToString(),Width=18,VerticalAlignment=VerticalAlignment.Center});
            var combo=new ComboBox{Width=222,IsEnabled=!(screen&&i==7),ItemsSource=screen&&i==7?new[]{T("操作")}:_keys.Select(Direct2DCanvasRenderer.RadialLabel).ToArray()};
            combo.SelectionChanged+=async(_,_)=>{if(_refreshing||combo.SelectedIndex<0)return;if(_keys[combo.SelectedIndex]=="")_profile.Slots[slot]="";else _profile.Assign(slot,_keys[combo.SelectedIndex],screen);await SaveAsync();};
            row.Children.Add(combo);options.Children.Add(row);_choices.Add(combo);
        }
        body.Children.Add(options);root.Children.Add(body);
        var reset=new Button{Content=T("預設")};reset.Click+=async(_,_)=>{_profile.Reset(screen);await SaveAsync();};root.Children.Add(reset);root.Children.Add(_status);
        Content=new ScrollViewer{Content=root,HorizontalScrollBarVisibility=ScrollBarVisibility.Auto,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
        var scale=ScreenAnnotation.NativeOverlayWindow.DpiScale(Handle);var area=Microsoft.UI.Windowing.DisplayArea.GetFromWindowId(AppWindow.Id,Microsoft.UI.Windowing.DisplayAreaFallback.Nearest).WorkArea;
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(Math.Min(area.Width-24,(int)(650*scale)),Math.Min(area.Height-24,(int)(650*scale))));
        if(AppWindow.Presenter is Microsoft.UI.Windowing.OverlappedPresenter presenter){presenter.IsAlwaysOnTop=true;presenter.IsResizable=false;presenter.IsMaximizable=false;}
        _canvas.Draw+=(_,args)=>_renderer.RenderRadialWheel(args.DrawingSession,_profile,new InkPoint(160,160),_hover);
        _canvas.CreateResources+=(_,_)=>_renderer.ClearCache();
        _canvas.DragOver+=(_,args)=>
        {
            var p=args.GetPosition(_canvas);_hover=HitSlot(p);
            var allowed=args.DataView.Contains(DragFormat)&&_hover>=0&&!(screen&&_hover==7);
            if(!allowed)_hover=-1;args.AcceptedOperation=allowed?DataPackageOperation.Copy:DataPackageOperation.None;_canvas.Invalidate();args.Handled=true;
        };
        _canvas.DragLeave+=(_,_)=>{_hover=-1;_canvas.Invalidate();};
        _canvas.Drop+=async(_,args)=>
        {
            args.Handled=true;var p=args.GetPosition(_canvas);var index=HitSlot(p);var deferral=args.GetDeferral();
            try
            {
                if(!args.DataView.Contains(DragFormat))return;
                if(await args.DataView.GetDataAsync(DragFormat) is string key&&_profile.Assign(index,key,screen))await SaveAsync();
                else _status.Text=T("這一格不能放入此工具。");
            }
            catch(Exception error){if(!_closed)_status.Text=T("輪盤設定尚未保存：")+error.Message;}
            finally{deferral.Complete();_hover=-1;if(!_closed)_canvas.Invalidate();}
        };
        Closed+=(_,_)=>{_closed=true;_canvas.RemoveFromVisualTree();_renderer.Dispose();};RefreshSlots();
    }
    private static int HitSlot(Point point)=>Math.Pow(point.X-160,2)+Math.Pow(point.Y-160,2)>RadialGesture.Radius*RadialGesture.Radius?-1:RadialGesture.Hit(new(point.X,point.Y),new(160,160),1);
    private async Task SaveAsync()
    {
        RefreshSlots();try{await _save();if(!_closed)_status.Text=T("設定已儲存");}
        catch(Exception error){if(!_closed)_status.Text=T("輪盤設定尚未保存：")+error.Message;}
    }
    internal void RefreshSlots()
    {
        if(_closed)return;_refreshing=true;
        for(var i=0;i<_choices.Count;i++)_choices[i].SelectedIndex=_screen&&i==7?0:Array.IndexOf(_keys,_profile.Slots[i]);
        _refreshing=false;_canvas.Invalidate();
    }
}
