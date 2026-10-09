using System.Diagnostics;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using global::Windows.Graphics;
using global::Windows.UI;

namespace HeiBan.Windows.ScreenAnnotation;

/// <summary>One independent annotation session over the live desktop; the host board is never its storage.</summary>
internal sealed class ScreenAnnotationWindow : Window, IDisposable
{
    private readonly MainWindow _owner;
    private readonly NativeOverlayWindow _overlay=new();
    private readonly EditorSession _session=new();
    private readonly Direct2DCanvasRenderer _renderer=new();
    private readonly ViewportTransform _viewport=new();
    private readonly LaserPointerEngine _laser=new();
    private readonly string _recoveryPath;
    private readonly Func<byte[],Task> _captureResult;
    private readonly Func<Task> _requestStart;
    private readonly DispatcherTimer _renderTimer=new(){Interval=TimeSpan.FromMilliseconds(33)};
    private readonly DispatcherTimer _saveTimer=new(){Interval=TimeSpan.FromSeconds(1)};
    private readonly TextBlock _status=new(){FontSize=12,Text="螢幕畫布",TextWrapping=TextWrapping.Wrap};
    private readonly Button _mode=new(){Content="操作穿透"};
    private readonly Dictionary<string,Button> _buttons=[];
    private CanvasRenderTarget? _target;
    private BoardObject? _preview,_manipulation;
    private ObjectHandles.Handle? _handle;
    private readonly List<InkPoint> _points=[];
    private InkPoint? _start,_last;
    private string _tool="pen",_color="#EF4444";
    private double _width=4,_opacity=1;
    private bool _drawing=true,_dirty,_stopping,_disposed;
    private readonly SemaphoreSlim _saveGate=new(1,1);
    private CancellationTokenSource? _captureCancellation;
    public bool IsActive {get;private set;}
    public ScreenAnnotationWindow(MainWindow owner,string dataDirectory,Func<Task> requestStart,Func<byte[],Task> captureResult)
    {
        _owner=owner;_requestStart=requestStart;_captureResult=captureResult;
        _recoveryPath=Path.Combine(dataDirectory,"ScreenAnnotations","session.heiban");
        Title="我的螢幕就是我的畫布";
        var root=new StackPanel{Spacing=6,Padding=new Thickness(12),Background=new SolidColorBrush(Color.FromArgb(255,248,250,246)),RequestedTheme=ElementTheme.Light};
        var grip=new Grid{Height=20,Children={new TextBlock{Text="⋮⋮  我的螢幕就是我的畫布",FontSize=12,Foreground=new SolidColorBrush(Color.FromArgb(255,57,115,90))}}};
        root.Children.Add(grip);ExtendsContentIntoTitleBar=true;SetTitleBar(grip);
        var tools=new StackPanel{Orientation=Orientation.Horizontal,Spacing=4};
        foreach(var pair in new[]{("select","選取"),("pen","畫筆"),("highlighter","螢光筆"),("paint","油漆筆"),("eraser","橡皮擦"),("line","直線"),("arrow","箭頭"),("rect","矩形"),("circle","圓形"),("laser","雷射")})
        {
            var key=pair.Item1;
            var b=new Button{Content=ToolIcons.Create(key),Padding=new Thickness(7)};
            ToolTipService.SetToolTip(b,pair.Item2);b.Click+=(_,_)=>{CancelGesture();_tool=key;SetDrawing(true);RefreshButtons();};tools.Children.Add(b);_buttons[key]=b;
        }
        _mode.Click+=(_,_)=>SetDrawing(!_drawing);tools.Children.Add(_mode);
        Add(tools,"復原",()=>{CancelGesture();_session.Undo();Changed();});
        Add(tools,"重做",()=>{CancelGesture();_session.Redo();Changed();});
        Add(tools,"截圖",async()=>await CaptureAsync());
        Add(tools,"清除",async()=>await ClearAsync());
        Add(tools,"結束",async()=>await StopAsync());
        root.Children.Add(new ScrollViewer{Content=tools,HorizontalScrollMode=ScrollMode.Enabled,HorizontalScrollBarVisibility=ScrollBarVisibility.Auto,VerticalScrollMode=ScrollMode.Disabled});
        var settings=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8};
        var colors=new ComboBox{Width=120,ItemsSource=new[]{"紅色","綠色","黃色","藍色","白色","黑色"},SelectedIndex=0};
        var hex=new[]{"#EF4444","#16A34A","#FACC15","#2563EB","#FFFFFF","#111827"};
        colors.SelectionChanged+=(_,_)=>{if(colors.SelectedIndex>=0){_color=hex[colors.SelectedIndex];_laser.Color=_color;}};settings.Children.Add(colors);
        var widths=new ComboBox{Width=90,ItemsSource=new[]{"2 pt","4 pt","8 pt","16 pt","32 pt"},SelectedIndex=1};
        widths.SelectionChanged+=(_,_)=>{_width=new[]{2d,4,8,16,32}[Math.Max(0,widths.SelectedIndex)];_laser.Width=_width;};settings.Children.Add(widths);
        var alpha=new Slider{Width=90,Minimum=.1,Maximum=1,Value=1};ToolTipService.SetToolTip(alpha,"透明度");alpha.ValueChanged+=(_,_)=>_opacity=alpha.Value;settings.Children.Add(alpha);
        var laserMode=new ComboBox{Width=110,ItemsSource=new[]{"光點","短尾跡","線條"},SelectedIndex=1};laserMode.SelectionChanged+=(_,_)=>_laser.Mode=new[]{"point","shortTrail","line"}[Math.Max(0,laserMode.SelectedIndex)];settings.Children.Add(laserMode);
        settings.Children.Add(new TextBlock{Text="Ctrl+Alt+A 開始 · D 切模式 · S 截圖 · Q 結束",FontSize=11,VerticalAlignment=VerticalAlignment.Center});
        root.Children.Add(settings);root.Children.Add(_status);Content=root;
        if(AppWindow.Presenter is OverlappedPresenter presenter){presenter.IsAlwaysOnTop=true;presenter.IsResizable=false;presenter.SetBorderAndTitleBar(false,false);}
        AppWindow.Resize(new SizeInt32(1080,190));
        AppWindow.Closing+=async(_,e)=>{e.Cancel=true;await StopAsync();};
        _overlay.Pointer+=OnPointer;_overlay.BoundsChanged+=()=>{CreateTarget();_dirty=true;};
        _overlay.Failed+=e=>{_status.Text="繪圖未完成："+e.Message;SetDrawing(false);};
        _overlay.Hotkey+=async id=>
        {
            if(id==1){await _requestStart();return;}
            if(!IsActive||_captureCancellation is not null)return;
            if(id==2)SetDrawing(!_drawing);else if(id==3)await CaptureAsync();else if(id==4)await StopAsync();
        };
        var failed=0;
        foreach(var key in new[]{(1,0x41u),(2,0x44u),(3,0x53u),(4,0x51u)})if(!_overlay.RegisterShortcut(key.Item1,0x0002|0x0001,key.Item2))failed++;
        if(failed>0)_status.Text="部分快捷鍵被其他程式占用，請使用控制列按鈕。";
        _renderTimer.Tick+=(_,_)=>{if(IsActive&&(_dirty||_laser.Samples.Count>0))Render();};
        _saveTimer.Tick+=async(_,_)=>{_saveTimer.Stop();await SaveAsync();};
        AppWindow.Hide();
    }
    private static void Add(StackPanel panel,string text,Action action)
    {var button=new Button{Content=text,Padding=new Thickness(7)};button.Click+=(_,_)=>action();panel.Children.Add(button);}
    public async Task StartAsync()
    {
        if(IsActive){AppWindow.Show();Activate();return;}
        try
        {
            var doc=File.Exists(_recoveryPath)?DocumentCodec.Decode(await File.ReadAllTextAsync(_recoveryPath)):new HeiBanDocument{Board=new BoardMetadata{Title="螢幕註記",CanvasMode="fixed",BackgroundColor="transparent",GridStyle="blank"}};
            _session.Open(doc);CreateTarget();await _renderer.LoadImagesAsync(_target!,doc.Objects);
            IsActive=true;_owner.AppWindow.Hide();_overlay.Show(true);SetDrawing(true);Render();
            AppWindow.Move(new PointInt32(Math.Max(0,_overlay.Left+40),Math.Max(0,_overlay.Top+40)));AppWindow.Show();Activate();_renderTimer.Start();
        }
        catch(Exception e){IsActive=false;_overlay.Hide();_owner.AppWindow.Show();_owner.Activate();throw new InvalidOperationException("無法開啟螢幕畫布："+e.Message,e);}
    }
    private void CreateTarget()
    {
        _target?.Dispose();_target=new CanvasRenderTarget(CanvasDevice.GetSharedDevice(),_overlay.Width,_overlay.Height,96);
        _session.Document.Board.CanvasWidth=_overlay.Width;_session.Document.Board.CanvasHeight=_overlay.Height;
    }
    private void SetDrawing(bool value)
    {
        CancelGesture();_drawing=value;_overlay.SetDrawing(value);_mode.Content=value?"操作穿透":"回到作畫";
        _status.Text=value?"作畫模式：拖曳註記，右鍵切換穿透":"操作模式：直接點擊下方 App；Ctrl+Alt+D 回到作畫";
        _laser.Clear();_dirty=true;
    }
    private void RefreshButtons()
    {foreach(var pair in _buttons)pair.Value.Background=new SolidColorBrush(pair.Key==_tool?Color.FromArgb(255,219,237,222):Color.FromArgb(255,248,250,246));}
    private void OnPointer(NativeOverlayWindow.PointerEvent input)
    {
        if(!IsActive||_captureCancellation is not null)return;
        var p=new InkPoint(input.X,input.Y,1);
        if(input.Kind=="right"){SetDrawing(false);return;}
        if(_tool=="laser")
        {
            if(input.Kind=="up")_laser.EndTrail();else _laser.Add(p,Now);_dirty=true;return;
        }
        if(input.Kind=="down")
        {
            _start=_last=p;_session.Begin();_points.Clear();_points.Add(p);
            if(_tool=="select")
            {
                _handle=_session.Selected is {IsLocked:not true} selected?ObjectHandles.Get(selected,1).Where(h=>Math.Sqrt(Math.Pow(h.Point.X-p.X,2)+Math.Pow(h.Point.Y-p.Y,2))<14).Select(h=>(ObjectHandles.Handle?)h).FirstOrDefault():null;
                if(_handle is null)_session.SelectedId=_session.Hit(p,6)?.Id;
                _manipulation=_session.Selected is { } o?DocumentCodec.Clone(o):null;
            }
            else if(_tool=="eraser")_session.Erase(p,_width*3,true);
            else if(_tool is "line" or "arrow" or "rect" or "circle")_preview=Styled(new BoardObject{Type=_tool,X=p.X,Y=p.Y,Width=1,Height=1});
        }
        else if(_start is not null&&input.Kind is "move" or "up")
        {
            if(_tool=="select"&&_session.Selected is {IsLocked:not true} selected&&_last is not null)
            {
                if(_handle?.Kind=="resize"&&_manipulation is not null)ObjectHandles.Resize(selected,_manipulation,_handle.Value.Index,p,true);
                else if(_handle?.Kind=="endpoint")ObjectHandles.MoveEndpoint(selected,_handle.Value.Index,p);
                else if(_handle?.Kind=="rotate"&&_manipulation is not null)selected.Rotation=_manipulation.Rotation+(Math.Atan2(p.Y-ObjectHandles.Center(selected).Y,p.X-ObjectHandles.Center(selected).X)-Math.Atan2(_start.Y-ObjectHandles.Center(selected).Y,_start.X-ObjectHandles.Center(selected).X))*180/Math.PI;
                else _session.Move(selected,p.X-_last.X,p.Y-_last.Y);
            }
            else if(_tool=="eraser")_session.Erase(p,_width*3,true);
            else if(_preview is not null)
            {
                if(_tool is "line" or "arrow")ObjectHandles.SetEndpoints(_preview,_start,p);
                else {_preview.X=Math.Min(_start.X,p.X);_preview.Y=Math.Min(_start.Y,p.Y);_preview.Width=Math.Max(1,Math.Abs(p.X-_start.X));_preview.Height=Math.Max(1,Math.Abs(p.Y-_start.Y));}
            }
            else if(_tool is "pen" or "highlighter" or "paint")_points.Add(p);
            _last=p;
        }
        if(input.Kind=="up"&&_start is not null)
        {
            if(_preview is not null)_session.Add(_preview);
            else if(_points.Count>0&&_tool is "pen" or "highlighter" or "paint")
            {
                var bounds=VectorMath.ComputeBoundingBox(_points,_width);
                _session.Add(Styled(new BoardObject{Type=_tool=="pen"?"stroke":_tool,X=bounds.MinX,Y=bounds.MinY,Width=bounds.Width,Height=bounds.Height,Points=JsonSerializer.Serialize(_points,DocumentCodec.Options)}));
            }
            _session.Commit();_points.Clear();_start=_last=null;_preview=null;_handle=null;_renderer.ResetLive();Changed();
        }
        _dirty=true;
    }
    private BoardObject Styled(BoardObject item)
    {item.StrokeColor=_color;item.StrokeWidth=_width;item.Opacity=_tool=="highlighter"?_opacity*.4:_opacity;return item;}
    private static double Now=>Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency;
    private void Render()
    {
        if(_target is null)return;
        _renderer.Prune(_session.Document.Objects);_laser.Prune(Now);
        using(var ds=_target.CreateDrawingSession())
        {
            // Alpha=1 makes blank pixels receive input in draw mode. Desktop content remains live.
            ds.Clear(Color.FromArgb(_drawing?(byte)1:(byte)0,0,0,0));
            _renderer.RenderObjects(ds,_session.VisibleObjects,_viewport,_overlay.Width,_overlay.Height);
            if(_preview is not null)_renderer.RenderObjects(ds,new[]{_preview},_viewport,_overlay.Width,_overlay.Height);
            if(_points.Count>0&&_tool is "pen" or "highlighter" or "paint")_renderer.RenderLiveStroke(ds,_points,_viewport,_color,_width,_tool=="highlighter"?_opacity*.4:_opacity);
            if(_tool=="select")_renderer.RenderSelection(ds,_session.Selected,_viewport);
            _renderer.RenderLaser(ds,_laser,_viewport,Now);
        }
        _overlay.Present(_target.GetPixelBytes());_dirty=false;
    }
    private void Changed(){_dirty=true;_saveTimer.Stop();_saveTimer.Start();}
    private void CancelGesture()
    {_session.Cancel();_points.Clear();_start=_last=null;_preview=null;_handle=null;_renderer.ResetLive();_dirty=true;}
    private async Task<bool> SaveAsync()
    {
        await _saveGate.WaitAsync();
        try{await DocumentSessionManager.WriteAtomicAsync(_recoveryPath,DocumentCodec.Encode(DocumentCodec.Clone(_session.Document)));return true;}
        catch(Exception e){_status.Text="註記保存失敗，內容仍保留："+e.Message;return false;}
        finally{_saveGate.Release();}
    }
    private async Task ClearAsync()
    {
        var dialog=new ContentDialog{Title="清除螢幕註記？",Content="清除後仍可按復原。",PrimaryButtonText="清除",CloseButtonText="取消",XamlRoot=Content.XamlRoot};
        if(await dialog.ShowAsync()!=ContentDialogResult.Primary)return;
        CancelGesture();_session.Begin();_session.Document.Objects.Clear();_session.Commit();_laser.Clear();Changed();
    }
    private async Task CaptureAsync()
    {
        if(!IsActive||_captureCancellation is not null)return;
        CancelGesture();_laser.Clear();Render();AppWindow.Hide();
        using var cancellation=new CancellationTokenSource(TimeSpan.FromSeconds(60));_captureCancellation=cancellation;
        try
        {
            await Task.Delay(150,cancellation.Token);
            var bytes=await RegionScreenshotService.CaptureAsync(cancellation.Token);
            if(bytes is not null){await _captureResult(bytes);_status.Text="截圖已貼回黑板";}else _status.Text="已取消截圖";
        }
        catch(OperationCanceledException){_status.Text="截圖已取消或逾時";}
        catch(Exception e){_status.Text="截圖未完成："+e.Message;}
        finally{_captureCancellation=null;if(IsActive)AppWindow.Show();}
    }
    public async Task<bool> StopAsync()
    {
        if(!IsActive)return true;if(_stopping)return false;_stopping=true;
        try
        {
            _captureCancellation?.Cancel();CancelGesture();
            if(!await SaveAsync())return false;
            IsActive=false;_renderTimer.Stop();_saveTimer.Stop();_overlay.Hide();AppWindow.Hide();_laser.Clear();_target?.Dispose();_target=null;_renderer.ClearCache();
            _owner.AppWindow.Show();_owner.Activate();return true;
        }
        finally{_stopping=false;}
    }
    public void Dispose()
    {
        if(_disposed)return;_disposed=true;_captureCancellation?.Cancel();_renderTimer.Stop();_saveTimer.Stop();_target?.Dispose();_renderer.Dispose();_overlay.Dispose();Close();
    }
}
