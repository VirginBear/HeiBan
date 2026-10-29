using static HeiBan.Windows.Localization.Strings;
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
internal sealed partial class ScreenAnnotationWindow : Window, IDisposable
{
    private static readonly HashSet<string> ScreenShapeTools=ToolbarUi.ShapeTools.Select(shape=>shape.Key).ToHashSet(StringComparer.Ordinal);
    private readonly MainWindow _owner;
    private readonly NativeOverlayWindow _overlay=new();
    private readonly EditorSession _session=new();
    private readonly Direct2DCanvasRenderer _renderer=new();
    private readonly ViewportTransform _viewport=new();
    private readonly LaserPointerEngine _laser;
    // The screen host reads the same user toolbar file as the board, then applies host filtering without rewriting that preference.
    private ToolbarPreferences _toolbarPreferences;
    private nint _lastExternal;
    private double _dpiScale=1;
    private FileStream? _sessionLease;
    private readonly string _recoveryPath;
    private readonly Func<Task> _requestStart;
    private readonly DispatcherTimer _renderTimer=new(){Interval=TimeSpan.FromMilliseconds(16)};
    // Focus restoration does not need frame-rate polling; keep this outside the drawing tick.
    private readonly DispatcherTimer _focusRememberTimer=new(){Interval=TimeSpan.FromMilliseconds(250)};
    // Poll only during an active pen gesture; idle rendering never pays for straight-line recognition.
    private readonly DispatcherTimer _straightenTimer=new(){Interval=TimeSpan.FromMilliseconds(100)};
    private readonly DispatcherTimer _saveTimer=new(){Interval=TimeSpan.FromSeconds(1)};
    private readonly TextBlock _status=new(){FontSize=11,Text=T("螢幕畫布"),TextTrimming=TextTrimming.CharacterEllipsis,VerticalAlignment=VerticalAlignment.Center};
    private readonly Button _mode=new(){Content=T("操作穿透")};
    private readonly Dictionary<string,Button> _buttons=[];
    private CanvasRenderTarget? _target,_committed;
    private bool _committedDirty=true,_fullDamage=true,_benchmarkFullFrames;
    private global::Windows.Foundation.Rect? _damage,_lastLaserDamage;
    private long _presentedBytes,_renderedFrames,_committedBuilds;
    private BoardObject? _preview,_manipulation;
    private ObjectHandles.Handle? _handle;
    private readonly List<InkPoint> _points=[];
    private InkPoint? _start,_last;
    private InkPoint? _penHoldAnchor;
    private double _penHoldSince;
    private bool _screenPenStraight;
    private string _screenExtension="none";
    private string _tool="pen",_color="#EF4444",_dash="solid",_fill="none";
    private readonly List<InkPoint> _curveAnchors=[];
    private double _width=4,_opacity=1,_eraserSize=24;
    private bool _eraserWhole=true,_marquee;
    private string[] _marqueeSelection=[];
    private bool _drawing=true,_dirty,_stopping,_disposed;
    private readonly SemaphoreSlim _saveGate=new(1,1);
    private CancellationTokenSource? _captureCancellation;
    public bool IsActive {get;private set;}
    public ScreenAnnotationWindow(MainWindow owner,string dataDirectory,Func<Task> requestStart,LaserPointerEngine laser)
    {
        _owner=owner;_requestStart=requestStart;_laser=laser;_toolbarPreferences=ToolbarPreferencesStore.Load(dataDirectory);
        _recoveryPath=Path.Combine(dataDirectory,"ScreenAnnotations","session.heiban");
        Title=T("我的螢幕就是我的畫布");
        InitializeChrome();
        if(AppWindow.Presenter is OverlappedPresenter presenter){presenter.PreferredMinimumWidth=1;presenter.PreferredMinimumHeight=1;presenter.IsAlwaysOnTop=true;presenter.IsResizable=false;presenter.SetBorderAndTitleBar(false,false);}
        _dpiScale=NativeOverlayWindow.DpiScale(WinRT.Interop.WindowNative.GetWindowHandle(this));ResizeChrome();
        AppWindow.Closing+=async(_,e)=>{if(_disposed)return;e.Cancel=true;await StopAsync();};
        _overlay.Pointer+=OnPointer;_overlay.BoundsChanged+=async()=>{if(IsActive&&!_stopping){if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();if(!IsActive||_stopping)return;CancelGesture();CreateTarget();Changed();ResizeChrome();PositionChrome();}};
        _overlay.Failed+=e=>{SetDrawing(false);_status.Text=T("繪圖未完成：")+e.Message;};
        _overlay.Hotkey+=async id=>
        {
            if(_stopping)return;
            if(id==1){await _requestStart();return;}
            if(!IsActive||_captureCancellation is not null)return;
            if(id==2)SetDrawing(!_drawing);else if(id==3)await CaptureAsync();else if(id==4)await StopAsync();else if(id==5)ClearScreenObjects();
        };
        var failed=0;
        foreach(var key in new[]{(1,0x41u),(2,0x44u),(3,0x53u),(4,0x51u),(5,0x4Bu)})if(!_overlay.RegisterShortcut(key.Item1,0x0002|0x0001,key.Item2))failed++;
        _hotkeyRegistrationFailed=failed>0;if(failed>0)_status.Text=T("部分快捷鍵被其他程式占用，請使用控制列按鈕。");
        _renderTimer.Tick+=(_,_)=>{if(!IsActive)return;try{UpdateScreenEraser();UpdateScreenMagnetHover();if(_dirty||_laser.Samples.Count>0)Render();}catch(Exception e){_renderTimer.Stop();_overlay.Hide();_status.Text=T("螢幕繪圖已停止：")+e.Message;}};
        _focusRememberTimer.Tick+=(_,_)=>{if(IsActive)RememberExternalFocus();};
        _straightenTimer.Tick+=(_,_)=>
        {
            if(IsActive&&_drawing&&_tool=="pen"&&_start is not null&&Now-_penHoldSince>=1&&StraightStrokeRecognizer.IsEligible(_points,1/_dpiScale))
            {_screenPenStraight=true;_straightenTimer.Stop();_dirty=true;}
        };
        _saveTimer.Tick+=async(_,_)=>{_saveTimer.Stop();if(!_owner.AutoSaveEnabled||_stopping||!IsActive)return;if(_start is not null||_textDraft is not null||_session.HasTransaction){_saveTimer.Start();return;}await SaveAsync();};
        AppWindow.Hide();
    }
    public async Task StartAsync()
    {
        if(IsActive){AppWindow.Show();Activate();return;}
        _toolbarPreferences=ToolbarPreferencesStore.Load(Path.GetDirectoryName(Path.GetDirectoryName(_recoveryPath))!);RebuildChromeLayout();
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_recoveryPath)!);_sessionLease=new FileStream(_recoveryPath+".lock",FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);
            var doc=File.Exists(_recoveryPath)?DocumentCodec.Decode(await File.ReadAllTextAsync(_recoveryPath)):new HeiBanDocument{Board=new BoardMetadata{Title=T("螢幕註記"),CanvasMode="fixed",BackgroundColor="transparent",GridStyle="blank"}};
            _session.Open(doc);CreateTarget();await _renderer.LoadImagesAsync(_target!,doc.Objects);
            IsActive=true;_laser.Clear();_owner.AppWindow.Hide();RememberExternalFocus();_overlay.Show(true);SetDrawing(true);Render();
            ResizeChrome();RefreshButtons();
            PositionChrome();AppWindow.Show();Activate();_renderTimer.Start();_focusRememberTimer.Start();
        }
        catch(Exception e){_sessionLease?.Dispose();_sessionLease=null;IsActive=false;_overlay.Hide();_owner.AppWindow.Show();_owner.Activate();throw new InvalidOperationException("無法開啟螢幕畫布："+e.Message,e);}
    }
    private void CreateTarget()
    {
        _target?.Dispose();_committed?.Dispose();_target=new CanvasRenderTarget(CanvasDevice.GetSharedDevice(),_overlay.Width,_overlay.Height,96);
        _committed=new CanvasRenderTarget(CanvasDevice.GetSharedDevice(),_overlay.Width,_overlay.Height,96);_committedDirty=_fullDamage=true;_damage=null;
        var board=_session.Document.Board;board.ExtraFields??=[];
        var oldX=board.ExtraFields.TryGetValue("windowsScreenOriginX",out var x)&&x.TryGetInt32(out var xx)?xx:_overlay.Left;
        var oldY=board.ExtraFields.TryGetValue("windowsScreenOriginY",out var y)&&y.TryGetInt32(out var yy)?yy:_overlay.Top;
        if(oldX!=_overlay.Left||oldY!=_overlay.Top)foreach(var o in _session.Document.Objects)_session.Move(o,oldX-_overlay.Left,oldY-_overlay.Top);
        board.ExtraFields["windowsScreenOriginX"]=JsonSerializer.SerializeToElement(_overlay.Left);board.ExtraFields["windowsScreenOriginY"]=JsonSerializer.SerializeToElement(_overlay.Top);
        _session.Document.Board.CanvasWidth=_overlay.Width;_session.Document.Board.CanvasHeight=_overlay.Height;
    }
    private bool _hotkeyRegistrationFailed;
    private async void SetDrawing(bool value)
    {
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        if(!value)RememberExternalFocus();
        FinishScreenText();CancelGesture();_drawing=value;_overlay.SetDrawing(value);_overlay.SetManipulationCursor(null,null,_tool);UpdateScreenEraser();RefreshMode();
        _status.Text=value?T("作畫中 · 右鍵物件可編輯"):T("操作中 · Ctrl+Alt+D 繼續作畫");
        RefreshMode();ResizeChrome();PositionChrome();
        _laser.Clear();_dirty=_fullDamage=_committedDirty=true;if(!value)NativeOverlayWindow.RestoreFocus(_lastExternal);
    }
    private void RememberExternalFocus()
    {var current=NativeOverlayWindow.CurrentForeground;if(current!=0&&current!=_overlay.Handle&&current!=WinRT.Interop.WindowNative.GetWindowHandle(this)&&current!=WinRT.Interop.WindowNative.GetWindowHandle(_owner))_lastExternal=current;}
    private void RefreshButtons()
    {foreach(var pair in _buttons)pair.Value.Background=new SolidColorBrush(pair.Key==_tool?Color.FromArgb(70,116,156,141):Color.FromArgb(0,0,0,0));RefreshScreenStyleButtons();foreach(var pair in _buttons){ToolbarUi.LabelMode(pair.Value,pair.Key,_toolbarPreferences.DisplayMode=="labels",32);if(pair.Key=="magnet")pair.Value.Background=ChromeBrush(_toolbarPreferences.MagnetEnabled?(byte)70:(byte)0,116,156,141);}}
    private void OnPointer(NativeOverlayWindow.PointerEvent input)
    {
        if(!IsActive||_stopping||_captureCancellation is not null)return;
        if(input.Kind=="cancel"){CancelGesture();return;}
        if(!_drawing)return;
        var p=new InkPoint(input.X,input.Y,1);
        // Laser owns this whole input route: hover/right/double never reach object hit tests.
        if(_tool=="laser")
        {
            UpdateScreenShapeCursor(p);
            if(input.Kind is "down" or "double"&&input.LeftDown){_laser.Press(p,Now);_dirty=true;}
            else if(input.Kind=="move"&&input.LeftDown){_laser.MovePressed(p,Now);if(_laser.IsPressed)_dirty=true;}
            else if(_laser.IsPressed){_laser.Release();_dirty=true;}
            return;
        }
        if(HandleCircularEraser(input,p))return;
        if(input.Kind=="down"&&_tool is "pen" or "highlighter" or "paint")
        {_screenMagnetIndex=null;_screenMagnetTarget=null;} // No snap lookup or stale reference index during freehand ink.
        if(IsMagnetDrawingTool(_tool))
        {
            EnsureScreenMagnetIndex();
            if(_toolbarPreferences.MagnetEnabled&&_screenMagnetIndex is not null)p=_screenMagnetIndex.Snap(p,out _);
        }
        UpdateScreenShapeCursor(p);
        if(input.Kind=="move"&&_start is null&&_tool=="eraser"){UpdateScreenEraser();return;}
        if(input.Kind=="right"){FinishScreenText();ScreenRightClick(p);return;}
        if(input.Kind=="double")
        {
            FinishScreenText();var hit=_session.Hit(p,6);
            if(hit is {IsLocked:not true,Type:"tape"}){_session.Begin();hit.IsRevealed=hit.IsRevealed!=true;_session.Commit();Changed();}
            else if(hit is {IsLocked:not true,Type:"text" or "sticky"})BeginScreenText(p,hit);
            else if(hit is {IsLocked:not true}){CancelGesture();_tool="select";_session.SelectedId=hit.Id;RefreshButtons();Changed();ShowBrushSettings();}
            return;
        }
        if(input.Kind=="down"){FinishScreenText();if(_tool is "text" or "sticky"){BeginScreenText(p,type:_tool);return;}}
        if(_preview is not null)DamagePreview();
        if(_tool is "curve" or "triangle" or "quadrilateral")
        {
            if(input.Kind=="down")_curveAnchors.Add(p);
            if(_curveAnchors.Count==0)return;
            _preview??=new BoardObject{Type=_tool};Styled(_preview);
            var needed=_tool=="quadrilateral"?4:3;
            var points=_curveAnchors.Count==needed?_curveAnchors.ToArray():_tool=="curve"?CurvePreview.Points(_curveAnchors,p):_curveAnchors.Concat(new[]{p}).ToArray();
            var bounds=VectorMath.ComputeBoundingBox(_tool=="curve"?CurvePreview.Flatten(points):points,_width*_dpiScale);
            _preview.X=bounds.MinX;_preview.Y=bounds.MinY;_preview.Width=bounds.Width;_preview.Height=bounds.Height;_preview.Points=JsonSerializer.Serialize(points,DocumentCodec.Options);
            if(_curveAnchors.Count==needed){_session.Begin();_session.Add(_preview);_session.Commit();_preview=null;_curveAnchors.Clear();Changed();}
            DamagePreview();_dirty=true;return;
        }
        if(_tool=="lasso")
        {
            if(input.Kind=="down")
            {
                DamageSelectedObjects();_start=_last=p;_points.Clear();_points.Add(p);
                _marqueeSelection=input.Shift?_session.SelectedIds.ToArray():[];
                if(!input.Shift)_session.SelectedId=null;
                _dirty=_fullDamage=true;return;
            }
            if(_start is null||input.Kind is not("move" or "up"))return;
            if(_last is not null&&Math.Pow(p.X-_last.X,2)+Math.Pow(p.Y-_last.Y,2)>=4)_points.Add(p);
            _last=p;
            if(input.Kind=="up")
            {
                DamageSelectedObjects();
                if(_points.Count>=3)_session.SetSelection(_session.VisibleObjects.Where(o=>LassoSelection.Intersects(o,_points)).Select(o=>o.Id).Concat(_marqueeSelection));
                _points.Clear();_start=_last=null;_marqueeSelection=[];RefreshScreenStyleButtons();Changed();
                if(_session.Selected is not null)FocusScreenChrome();
            }
            else _dirty=true;
            return;
        }
        if(input.Kind=="move"&&_last is not null&&p.X==_last.X&&p.Y==_last.Y)return;
        var regionalSelection=input.Kind is "move" or "up"&&_start is not null&&_tool=="select"&&!_marquee;
        if(regionalSelection)DamageSelectedObjects();
        if(input.Kind is "move" or "up"&&_start is null)return; // Hovering with a normal tool changes no pixels.
        if(input.Kind=="down")
        {
            if(_tool=="select")DamageSelectedObjects(); // Remove the previous selection adorners even when the new gesture starts on blank space.
            _start=_last=p;if(_tool is not("select" or "pen" or "highlighter" or "paint"))_session.Begin();_points.Clear();_points.Add(p);
            _screenPenStraight=false;_penHoldAnchor=_tool=="pen"?p:null;_penHoldSince=Now;_straightenTimer.Stop();if(_penHoldAnchor is not null)_straightenTimer.Start();
            if(_tool=="select")
            {
                _handle=_session.SelectedIds.Count==1&&_session.Selected is {IsLocked:not true} selected?ObjectHandles.Get(selected,1).Where(h=>Math.Sqrt(Math.Pow(h.Point.X-p.X,2)+Math.Pow(h.Point.Y-p.Y,2))<14).Select(h=>(ObjectHandles.Handle?)h).FirstOrDefault():null;
                if(_handle is null)
                {
                    var hit=_session.Hit(p,6);if(hit is not null){if(input.Shift)_session.ToggleSelection(hit.Id);else if(!_session.SelectedIds.Contains(hit.Id))_session.SelectedId=hit.Id;}
                    else{_marquee=true;_marqueeSelection=input.Shift?_session.SelectedIds.ToArray():[];if(!input.Shift)_session.SelectedId=null;_preview=new BoardObject{Type="rect",X=p.X,Y=p.Y,Width=1,Height=1,StrokeColor="#39735a",StrokeWidth=1,LineStyle="dashed",FillColor="none"};}
                }
                if(!_marquee&&_session.SelectedObjects.Any(o=>o.IsLocked!=true))_session.Begin();
                RefreshScreenStyleButtons();_manipulation=_session.SelectedIds.Count==1&&_session.Selected is { } o?DocumentCodec.Clone(o):null;
            }
            else if(ScreenShapeTools.Contains(_tool)||_tool=="tape")_preview=Styled(new BoardObject{Type=_tool,X=p.X,Y=p.Y,Width=1,Height=1});
        }
        else if(_start is not null&&input.Kind is "move" or "up")
        {
            if(_tool=="select"&&!_marquee&&_session.Selected is { } selected&&_last is not null)
            {
                if(_handle?.Kind=="resize"&&_manipulation is not null)ObjectHandles.Resize(selected,_manipulation,_handle.Value.Index,p,true);
                else if(_handle?.Kind=="endpoint")ObjectHandles.MoveEndpoint(selected,_handle.Value.Index,input.Shift?ObjectHandles.ConstrainOrthogonal(ObjectHandles.Endpoint(selected,1-_handle.Value.Index),p):p);
                else if(_handle?.Kind=="rotate"&&_manipulation is not null)selected.Rotation=_manipulation.Rotation+(Math.Atan2(p.Y-ObjectHandles.Center(selected).Y,p.X-ObjectHandles.Center(selected).X)-Math.Atan2(_start.Y-ObjectHandles.Center(selected).Y,_start.X-ObjectHandles.Center(selected).X))*180/Math.PI;
                else if(p.X!=_last.X||p.Y!=_last.Y)_session.PreviewMoveSelection(p.X-_last.X,p.Y-_last.Y);
            }
            else if(_preview is not null)
            {
                if(_tool is "line" or "arrow")ObjectHandles.SetEndpoints(_preview,_start,input.Shift?ObjectHandles.ConstrainOrthogonal(_start,p):p);
                else {ShapeConstruction.Drag(_preview,_start,p);if(_marquee){_preview.LineStyle=p.X<_start.X?"dashed":"solid";_preview.StrokeColor=p.X<_start.X?"#39735A":"#3976C4";}}
            }
            else if(_tool is "pen" or "highlighter" or "paint")
            {
                _points.Add(p);
                // The screen host stores physical overlay pixels, so compare movement in screen DIP.
                if(_tool=="pen"&&_penHoldAnchor is { } anchor&&Math.Sqrt(Math.Pow(p.X-anchor.X,2)+Math.Pow(p.Y-anchor.Y,2))>12*_dpiScale)
                {_penHoldAnchor=p;_penHoldSince=Now;_screenPenStraight=false;_straightenTimer.Stop();_straightenTimer.Start();}
            }
            if(regionalSelection)DamageSelectedObjects();
            _last=p;
        }
        if(input.Kind=="up"&&_start is not null)
        {
            DamagePreview();var previewCommit=_preview is not null;
            var partialCommit=(_tool is "pen" or "highlighter" or "paint"||previewCommit)&&!_fullDamage;
            if(partialCommit&&!previewCommit)DamageStrokeTail(true);
            if(_marquee)DamageSelectedObjects();var strokeDamage=_damage;
            if(_marquee&&_preview is not null)_session.SetSelection(_session.VisibleObjects.Where(o=>WindowSelection.Matches(o,_start,p)).Select(o=>o.Id).Concat(_marqueeSelection));
            else if(_preview is not null)_session.Add(_preview);
            else if(_points.Count>0&&_tool is "pen" or "highlighter" or "paint")
            {
                var bounds=VectorMath.ComputeBoundingBox(_points,_width*_dpiScale);
                if(_tool=="pen"&&_screenPenStraight)
                {
                    var line=Styled(new BoardObject{Type="line",X=bounds.MinX,Y=bounds.MinY,Width=bounds.Width,Height=bounds.Height});
                    ObjectHandles.SetEndpoints(line,_points[0],_points[^1]);AppendScreenInk(line);
                }
                else
                {
                    var item=Styled(new BoardObject{Type=_tool=="pen"?"stroke":_tool,X=bounds.MinX,Y=bounds.MinY,Width=bounds.Width,Height=bounds.Height});
                    item.SetCompletedInkPoints(_points);AppendScreenInk(item);
                }
            }
            _straightenTimer.Stop();_penHoldAnchor=null;_screenPenStraight=false;_session.Commit();if(_marquee)DamageSelectedObjects();var committedDamage=_damage;RefreshScreenStyleButtons();_marquee=false;_points.Clear();_start=_last=null;_preview=null;_handle=null;_renderer.ResetLive();Changed();
            if(_tool=="select"&&_session.Selected is not null)FocusScreenChrome();
            if(partialCommit){_fullDamage=false;_damage=previewCommit?committedDamage:strokeDamage;}
        }
        if(_tool is "pen" or "highlighter" or "paint"){if(input.Kind!="up")DamageStrokeTail();}
        else {DamagePreview();if(!regionalSelection&&_preview is null&&input.Kind!="up")_fullDamage=true;if(regionalSelection||_tool=="eraser")_committedDirty=true;}
        _dirty=true;
    }
    private void UpdateScreenShapeCursor(InkPoint pointer)
    {
        BoardObject? selected=null;ObjectHandles.Handle? handle=null;
        if(_drawing&&_tool=="select"&&_session.SelectedIds.Count==1&&_session.Selected is {IsLocked:not true} o)
        {
            selected=_start is not null?_manipulation??o:o;
            handle=_start is not null?_handle:ObjectHandles.Get(o,1).Where(h=>Math.Sqrt(Math.Pow(h.Point.X-pointer.X,2)+Math.Pow(h.Point.Y-pointer.Y,2))<14).Select(h=>(ObjectHandles.Handle?)h).FirstOrDefault();
        }
        _overlay.SetManipulationCursor(selected,handle,_tool);
    }
    private BoardObject Styled(BoardObject item)
    {item.StrokeColor=_color;if(item.Type is "line" or "arrow")item.Extension=_screenExtension;item.StrokeWidth=_width*_dpiScale;item.Opacity=_tool=="highlighter"?_opacity*.4:_opacity;item.LineStyle=_dash;if(item.Type is "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star")item.FillColor=_fill;if(item.Type=="tape"){item.StrokeColor=item.FillColor="#F59E0B";item.IsRevealed=false;}return item;}
    private static double Now=>Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency;
    private void DamageStrokeTail(bool entire=false)
    {
        // The newest sample changes only the last two Catmull-Rom segments. Include
        // their control hull so fast movement and curve overshoot cannot leave stale pixels.
        if(_points.Count==0)return;
        var start=entire?0:Math.Max(0,_points.Count-4);
        var left=_points[start].X;var top=_points[start].Y;var right=left;var bottom=top;
        for(var i=start+1;i<_points.Count;i++)
        {var point=_points[i];left=Math.Min(left,point.X);top=Math.Min(top,point.Y);right=Math.Max(right,point.X);bottom=Math.Max(bottom,point.Y);}
        var pad=Math.Max(right-left,bottom-top)/3+_width*_dpiScale+4;
        left=Math.Max(0,Math.Floor(left-pad));top=Math.Max(0,Math.Floor(top-pad));right=Math.Min(_overlay.Width,Math.Ceiling(right+pad));bottom=Math.Min(_overlay.Height,Math.Ceiling(bottom+pad));
        if(_damage is { } old){left=Math.Min(left,old.Left);top=Math.Min(top,old.Top);right=Math.Max(right,old.Right);bottom=Math.Max(bottom,old.Bottom);}
        if(right>left&&bottom>top)_damage=new(left,top,right-left,bottom-top);
    }
    private void Render()
    {
        using var trace=global::HeiBan.Windows.Diagnostics.InputLatencyTrace.Measure(global::HeiBan.Windows.Diagnostics.InputStage.ScreenRender);
        if(_target is null||_committed is null)return;
        var sceneSession=_circularEraser?.Preview??_session;
        _laser.Prune(Now);
        global::Windows.Foundation.Rect? laserDamage=null;
        if(_laser.Samples.Count>0)
        {
            var points=_laser.Samples.Select(s=>s.Point).ToArray();var pad=Math.Max(_laser.PointDiameter*1.2,_laser.Width*4)*_dpiScale+4;
            var left=Math.Max(0,Math.Floor(points.Min(p=>p.X)-pad));var top=Math.Max(0,Math.Floor(points.Min(p=>p.Y)-pad));
            var right=Math.Min(_overlay.Width,Math.Ceiling(points.Max(p=>p.X)+pad));var bottom=Math.Min(_overlay.Height,Math.Ceiling(points.Max(p=>p.Y)+pad));
            if(right>left&&bottom>top)laserDamage=new(left,top,right-left,bottom-top);
        }
        global::Windows.Foundation.Rect? eraserDamage=null;
        if(_screenEraserPointer is { } cursor)
        {
            var radius=_eraserSize*_dpiScale/2+4;
            var left=Math.Max(0,Math.Floor(cursor.X-radius));var top=Math.Max(0,Math.Floor(cursor.Y-radius));
            var right=Math.Min(_overlay.Width,Math.Ceiling(cursor.X+radius));var bottom=Math.Min(_overlay.Height,Math.Ceiling(cursor.Y+radius));
            if(right>left&&bottom>top)eraserDamage=new(left,top,right-left,bottom-top);
        }
        global::Windows.Foundation.Rect? magnetDamage=null;
        if(_screenMagnetTarget is { } snap)
        {var left=Math.Max(0,Math.Floor(snap.X-10*_dpiScale));var top=Math.Max(0,Math.Floor(snap.Y-10*_dpiScale));var right=Math.Min(_overlay.Width,Math.Ceiling(snap.X+10*_dpiScale));var bottom=Math.Min(_overlay.Height,Math.Ceiling(snap.Y+10*_dpiScale));if(right>left&&bottom>top)magnetDamage=new(left,top,right-left,bottom-top);}
        foreach(var bounds in new[]{_lastLaserDamage,laserDamage,_lastEraserDamage,eraserDamage,_lastMagnetDamage,magnetDamage})if(bounds is { } rect)
        {
            if(_damage is { } old){var left=Math.Min(old.Left,rect.Left);var top=Math.Min(old.Top,rect.Top);_damage=new(left,top,Math.Max(old.Right,rect.Right)-left,Math.Max(old.Bottom,rect.Bottom)-top);}
            else _damage=rect;
        }
        var full=_fullDamage||_benchmarkFullFrames||_damage is null;
        var region=full?new global::Windows.Foundation.Rect(0,0,_overlay.Width,_overlay.Height):_damage!.Value;
        var blank=Color.FromArgb(_drawing?(byte)1:(byte)0,0,0,0);
        if(_committedDirty&&!_benchmarkFullFrames)
        {
            _renderer.Prune(sceneSession.Document.Objects);
            using var ds=_committed.CreateDrawingSession();ds.Clear(blank);
            _renderer.RenderObjects(ds,sceneSession.DrawingObjects,_viewport,_overlay.Width,_overlay.Height);_committedDirty=false;_committedBuilds++;
        }
        // Both targets use the same device, BGRA format and 96 DPI; damage bounds are integral pixels.
        // Copy bitmap pixels without a sampling/compositing pass that can round translucent edge colors.
        if(!_benchmarkFullFrames)_target.CopyPixelsFromBitmap(_committed,(int)region.X,(int)region.Y,(int)region.X,(int)region.Y,(int)region.Width,(int)region.Height);
        using(var ds=_target.CreateDrawingSession())
        {
            if(_benchmarkFullFrames){ds.Clear(blank);_renderer.Prune(sceneSession.Document.Objects);_renderer.RenderObjects(ds,sceneSession.VisibleObjects,_viewport,_overlay.Width,_overlay.Height);}
            using var clip=ds.CreateLayer(1,region);
            if(_preview is not null)_renderer.RenderPreview(ds,_preview,_viewport,_overlay.Width,_overlay.Height);
            if(_points.Count>0&&_tool is "pen" or "highlighter" or "paint" or "lasso")
            {
                IReadOnlyList<InkPoint> livePoints=_screenPenStraight&&_points.Count>1?new[]{_points[0],_points[^1]}:_points;
                _renderer.RenderWetInk(ds,livePoints,_viewport,_tool=="lasso"?"#39735A":_color,_tool=="lasso"?1:_width*_dpiScale,_tool=="highlighter"?_opacity*.4:_opacity,_tool=="lasso"?"dashed":_dash,new global::Windows.Foundation.Size(_overlay.Width,_overlay.Height));
            }
            if(_tool=="select")foreach(var selected in _session.SelectedObjects)_renderer.RenderSelection(ds,selected,_viewport,_session.SelectedIds.Count==1);
            _renderer.RenderLaser(ds,_laser,_viewport,Now,_dpiScale);
            if(_screenMagnetTarget is { } target)ds.DrawCircle((float)target.X,(float)target.Y,(float)(7*_dpiScale),Direct2DCanvasRenderer.HexToColor("#10B981"),2);
            if(_screenEraserPointer is { } eraser)_renderer.RenderHover(ds,eraser,true,_eraserSize*_dpiScale,_viewport);
        }
        var x=(int)region.X;var y=(int)region.Y;var width=(int)region.Width;var height=(int)region.Height;
        _overlay.PresentBitmap(_target,x,y,width,height);_presentedBytes+=(long)width*height*4;_renderedFrames++;
        _dirty=false;_fullDamage=false;_damage=null;_lastLaserDamage=laserDamage;_lastEraserDamage=eraserDamage;_lastMagnetDamage=magnetDamage;
    }
    public void ApplySavingPreferences(){_saveTimer.Stop();if(_owner.AutoSaveEnabled&&IsActive&&!_stopping&&_session.IsDirty)_saveTimer.Start();}
    private void Changed(){_dirty=_fullDamage=_committedDirty=true;RefreshScreenLayers();ApplySavingPreferences();}
    private void CancelGesture()
    {
        if(_laser.Samples.Count>0){_laser.Release();_dirty=true;}
        CancelCircularEraser();
        CommitScreenStyle();var committedChanged=_session.HasTransaction;var previewVisible=_preview is not null||_points.Count>0;
        _straightenTimer.Stop();_penHoldAnchor=null;_screenPenStraight=false;DamagePreview();_session.Cancel();_curveAnchors.Clear();_marquee=false;_points.Clear();_start=_last=null;_preview=null;_handle=null;_renderer.ResetLive();
        if(committedChanged){_dirty=_fullDamage=_committedDirty=true;_damage=null;}else if(previewVisible)_dirty=true;
    }
    private async Task<bool> SaveAsync()
    {
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        await _saveGate.WaitAsync();
        try{var snapshot=DocumentCodec.Clone(_session.Document);var generation=_session.Generation;var epoch=_session.DocumentEpoch;await Task.Run(()=>DocumentSessionManager.WriteAtomicAsync(_recoveryPath,DocumentCodec.Encode(snapshot)));if(epoch==_session.DocumentEpoch)_session.MarkSaved(generation,snapshot.Board.Revision);return true;}
        catch(Exception e){_status.Text=T("註記保存失敗，內容仍保留：")+e.Message;return false;}
        finally{_saveGate.Release();}
    }
    private async Task CaptureAsync()
    {
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        if(!IsActive||_captureCancellation is not null)return;
        FinishScreenText();CancelGesture();_laser.Clear();Render();AppWindow.Hide();
        using var cancellation=new CancellationTokenSource(TimeSpan.FromSeconds(60));_captureCancellation=cancellation;
        try
        {
            await Task.Delay(150,cancellation.Token);
            var epoch=_session.DocumentEpoch;var capture=await RegionScreenshotService.CaptureRegionAsync(cancellation.Token);
            if(capture is not null){await InsertScreenCaptureAsync(capture,epoch);_status.Text=T("截圖已加入螢幕畫布，可選取調整");}else _status.Text=T("已取消截圖");
        }
        catch(OperationCanceledException){_status.Text=T("截圖已取消或逾時");}
        catch(Exception e){_status.Text=T("截圖未完成：")+e.Message;}
        finally{_captureCancellation=null;if(IsActive)AppWindow.Show();}
    }
    private Task LaserSettingsAsync()
    {
        var panel=new StackPanel{Spacing=8,Width=260};panel.Children.Add(new TextBlock{Text=T("雷射設定"),FontSize=16});
        var modes=new[]{"point","shortTrail","line"};var mode=new ComboBox{Header=T("模式"),ItemsSource=new[]{T("光點"),T("短尾跡"),T("線條")},SelectedIndex=Math.Max(0,Array.IndexOf(modes,_laser.Mode))};panel.Children.Add(mode);
        var diameter=new Slider{Header=T("光點直徑"),Minimum=4,Maximum=64,Value=_laser.PointDiameter};
        var width=new Slider{Header=T("尾跡粗細"),Minimum=1,Maximum=32,Value=_laser.Width};var fade=new Slider{Header=T("消退時間（秒）"),Minimum=.1,Maximum=5,StepFrequency=.1,Value=_laser.FadeDuration};var white=new CheckBox{Content=T("白色光芯"),IsChecked=_laser.WhiteCore};
        panel.Children.Add(diameter);panel.Children.Add(width);panel.Children.Add(fade);panel.Children.Add(white);
        var flyout=new Flyout{Content=panel};var apply=new Button{Content=T("套用")};apply.Click+=(_,_)=>{_laser.Mode=modes[Math.Max(0,mode.SelectedIndex)];_laser.PointDiameter=diameter.Value;_laser.Width=width.Value;_laser.FadeDuration=fade.Value;_laser.WhiteCore=white.IsChecked==true;_laser.Clear();_dirty=true;flyout.Hide();};panel.Children.Add(apply);
        ShowChromeFlyout(flyout,_mode);return Task.CompletedTask;
    }
    internal async Task ValidateNativeSessionAsync(string outputDirectory)
    {
        await StartAsync();DockChrome("top");SetChromeCollapsed(false);var before=_session.Document.Objects.Count;
        try
        {
            _tool="pen";SetDrawing(true);OnPointer(new("down",120,300));OnPointer(new("move",200,330));OnPointer(new("up",300,300));Render();
            if(_session.Document.Objects.Count!=before+1)throw new InvalidOperationException("螢幕筆畫未提交。");
            using(var target=new CanvasRenderTarget(CanvasDevice.GetSharedDevice(),_overlay.Width,_overlay.Height,96))
            {using(var ds=target.CreateDrawingSession()){ds.Clear(Color.FromArgb(0,0,0,0));_renderer.RenderObjects(ds,_session.DrawingObjects,_viewport,_overlay.Width,_overlay.Height);}await target.SaveAsync(Path.Combine(outputDirectory,"screen-annotations.png"),CanvasBitmapFileFormat.Png);}
            SetDrawing(false);Render();SetDrawing(true);Render();
            if(!_overlay.IsBelow(WinRT.Interop.WindowNative.GetWindowHandle(this)))throw new InvalidOperationException("模式切換後透明輸入層遮住控制列。");
            var interactions=await ValidateInteractionChangesAsync(outputDirectory);var previewPerformance=ValidatePreviewPerformance();var performance=ValidateStrokePerformance();var objectCommands=ValidateObjectCommands();var docking=ValidateChromeDocking();var text=ValidateScreenText();
            var expanded=AppWindow.Size;SetChromeCollapsed(false);
            if(expanded.Height>62*_dpiScale)throw new InvalidOperationException("螢幕工具列不是60pt單排。");
            await Task.Delay(160);Activate();await Task.Delay(80);ShowBrushSettings();await Task.Delay(100);var brushPanel=_chromeFlyout is Microsoft.UI.Xaml.Controls.Flyout brushFlyout&&brushFlyout.Content is StackPanel brush&&brush.Width==248&&brush.Children.OfType<Microsoft.UI.Xaml.Controls.Slider>().Count()==2;
            if(!brushPanel)throw new InvalidOperationException("共用色圓設定面板未接線："+(_chromeFlyout?.GetType().Name??"closed")+" / "+((_chromeFlyout as Flyout)?.Content is StackPanel actual?actual.Width.ToString():"no panel"));_chromeFlyout?.Hide();
            await LaserSettingsAsync();await Task.Delay(100);
            var settingsOutsideRoot=_chromeFlyout?.IsConstrainedToRootBounds==false;
            if(!settingsOutsideRoot)throw new InvalidOperationException("雷射設定被限制在工具列高度內。");
            _chromeFlyout?.Hide();
            if(!await SaveAsync())throw new InvalidOperationException("螢幕恢復檔保存失敗。");
            var restored=DocumentCodec.Decode(await File.ReadAllTextAsync(_recoveryPath));if(restored.Objects.Count!=before+1)throw new InvalidOperationException("螢幕恢復檔不一致。");
            await File.WriteAllTextAsync(Path.Combine(outputDirectory,"screen-result.json"),JsonSerializer.Serialize(new{success=true,width=_overlay.Width,height=_overlay.Height,addedObjects=restored.Objects.Count-before,controlsAboveOverlay=true,expandedWidth=expanded.Width,expandedHeight=expanded.Height,singleRow=true,brushPanel,dpiScale=_dpiScale,settingsOutsideRoot,interactions,previewPerformance,performance,objectCommands,docking,text}));
        }
        finally{await StopAsync();}
    }
    private async Task ExportAnnotationsAsync()
    {
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        if(!IsActive)return;FinishScreenText();CancelGesture();
        try
        {
            var picker=new global::Windows.Storage.Pickers.FileSavePicker{SuggestedFileName=T("螢幕註記")};
            WinRT.Interop.InitializeWithWindow.Initialize(picker,WinRT.Interop.WindowNative.GetWindowHandle(this));
            picker.FileTypeChoices.Add(T("可編輯註記"),new List<string>{".heiban"});picker.FileTypeChoices.Add(T("透明 PNG"),new List<string>{".png"});
            var file=await picker.PickSaveFileAsync();if(file is null)return;
            if(file.FileType==".png"){
                using var target=new CanvasRenderTarget(CanvasDevice.GetSharedDevice(),_overlay.Width,_overlay.Height,96);
                using(var ds=target.CreateDrawingSession()){ds.Clear(Color.FromArgb(0,0,0,0));_renderer.RenderObjects(ds,_session.DrawingObjects,_viewport,_overlay.Width,_overlay.Height);}
                await target.SaveAsync(file.Path,CanvasBitmapFileFormat.Png);
            }else await DocumentSessionManager.WriteAtomicAsync(file.Path,DocumentCodec.Encode(_session.Document));
            _status.Text=T("註記已另存");
        }catch(Exception e){_status.Text=T("註記另存失敗：")+e.Message;}
    }
    public async Task<bool> StopAsync()
    {
        if(!IsActive)return true;if(_stopping)return false;RememberExternalFocus();_stopping=true;
        var originalContent=Content;var originalSize=AppWindow.Size;
        var ring=new ProgressRing{IsActive=true,Width=30,Height=30};
        try
        {
            _saveTimer.Stop();_renderTimer.Stop();_focusRememberTimer.Stop();_dockTimer.Stop();_chromeFlyout?.Hide();
            _captureCancellation?.Cancel();if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();FinishScreenText();CancelGesture();
            // Replace only the chrome while the native annotation session is frozen.
            Content=new Border{Background=ChromeBrush(255,247,250,246),Padding=new Thickness(12),CornerRadius=new CornerRadius(16),Child=new StackPanel{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Orientation=Orientation.Horizontal,Spacing=12,Children={ring,new TextBlock{Text=T("正在儲存…"),VerticalAlignment=VerticalAlignment.Center}}}};
            AppWindow.Resize(new SizeInt32((int)(320*_dpiScale),(int)(72*_dpiScale)));AppWindow.Show();Activate();await Task.Delay(32);
            if(!await SaveAsync())return false;
            if(_session.IsDirty){_status.Text=T("尚有變更");return false;}
            IsActive=false;_renderTimer.Stop();_focusRememberTimer.Stop();_saveTimer.Stop();_dockTimer.Stop();await SaveChromePreferencesAsync();_overlay.Hide();AppWindow.Hide();_laser.Clear();_target?.Dispose();_target=null;_committed?.Dispose();_committed=null;_renderer.ClearCache();_sessionLease?.Dispose();_sessionLease=null;
            _owner.AppWindow.Show();_owner.Activate();return true;
        }
        catch(Exception error){_status.Text=T("註記保存失敗，內容仍保留：")+error.Message;return false;}
        finally{ring.IsActive=false;Content=originalContent;AppWindow.Resize(originalSize);_stopping=false;if(IsActive){_renderTimer.Start();_focusRememberTimer.Start();ApplySavingPreferences();RefreshMode();ShowChromeFlyout(new Flyout{Content=new TextBlock{Text=_status.Text,TextWrapping=TextWrapping.Wrap,MaxWidth=300}},_closeButton);}}
    }
    public void Dispose()
    {
        if(_disposed)return;CancelCircularEraser();FinishScreenText();_disposed=true;_captureCancellation?.Cancel();_renderTimer.Stop();_focusRememberTimer.Stop();_straightenTimer.Stop();_saveTimer.Stop();_styleCommitTimer.Stop();_dockTimer.Stop();_target?.Dispose();_committed?.Dispose();_renderer.Dispose();_sessionLease?.Dispose();_sessionLease=null;_overlay.Dispose();Close();
    }
}
