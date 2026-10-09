using System.IO;
using System.Numerics;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using global::Windows.ApplicationModel.DataTransfer;
using PointerDeviceType = Microsoft.UI.Input.PointerDeviceType;
using global::Windows.Foundation;
using global::Windows.Storage;
using global::Windows.Storage.Pickers;
using global::Windows.Storage.Streams;
using global::Windows.System;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private CancellationTokenSource? _regionCaptureCancellation;

    private bool _gesture,_panning,_rulerMoving,_rulerRotating;
    private bool _compassCenterMoving,_compassCenterMoved,_compassRadiusMoving,_compassPencilMoving;
    private uint _pointerId;
    private InkPoint? _start,_lastWorld;
    private BoardObject? _preview;
    private ObjectHandles.Handle? _objectHandle;
    private BoardObject? _manipulationStart;
    private double _objectPointerAngle;
    private InkPoint? _lineAnchor;
    private bool _lineCompleting,_shapeGesture;
    private readonly List<InkPoint> _polygon=[];
    private Vector2 _lastScreen;
    private BoardPin? _movingPin;
    private bool _rulerEnabled;
    private Vector2 _rulerCenter=new(450,350);
    private double _rulerAngle;
    private string? _rulerColor;
    private Vector2? _snapEdge;
    private Vector2 _snapDirection;

    private void CanvasSurface_CreateResources(CanvasControl sender,Microsoft.Graphics.Canvas.UI.CanvasCreateResourcesEventArgs e)
    {_renderer.ClearCache();e.TrackAsyncAction(_renderer.LoadImagesAsync(sender,_session.Document.Objects).AsAsyncAction());}
    private void CanvasSurface_Draw(CanvasControl sender,CanvasDrawEventArgs e)
    {
        var ds=e.DrawingSession;var w=(float)sender.ActualWidth;var h=(float)sender.ActualHeight;
        _renderer.RenderBackground(ds,_session.Document.Board,_viewport,w,h);
        var board=_session.Document.Board;
        var clip=board.CanvasMode=="infinite"?new Rect(0,0,w,h):new Rect(_viewport.X,_viewport.Y,(board.CanvasWidth??595)*_viewport.Zoom,(board.CanvasHeight??842)*_viewport.Zoom);
        using(var layer=ds.CreateLayer(1,clip))
        {
            _renderer.RenderObjects(ds,_session.VisibleObjects,_viewport,w,h);
            if(_preview is not null)_renderer.RenderObjects(ds,[_preview],_viewport,w,h);
            if(_ink.IsDrawing)_renderer.RenderLiveStroke(ds,_ink.ActiveStrokePoints,_viewport,_strokeColor,EffectiveWidth,_opacity);
            if(_polygon.Count>0)
            {
                var preview=_polygon.Concat(new[]{_viewport.ScreenToWorld(_mouse.X,_mouse.Y)}).ToArray();
                _renderer.RenderLiveStroke(ds,preview,_viewport,_strokeColor,_strokeWidth,.8);
            }
            _renderer.RenderSelection(ds,_session.Selected,_viewport);
        }
        foreach(var pin in board.Pins??[])
        {
            var p=_viewport.WorldToScreen(pin.X,pin.Y);
            Direct2DCanvasRenderer.DrawPin(ds,new((float)p.X,(float)p.Y),.9f);
            ds.DrawText(pin.Name,(float)p.X+16,(float)p.Y,Direct2DCanvasRenderer.HexToColor("#397056"));
        }
        if(_rulerEnabled)DrawRuler(ds);
        if(_compass.IsEnabled)_renderer.RenderCompass(ds,_compass,_viewport);
        if(_hover&&_editor is null&&_tool is "pen" or "highlighter" or "paint" or "eraser")
            _renderer.RenderHover(ds,_mouse,_tool=="eraser",_tool=="eraser"?EraserSizeSlider.Value:EffectiveWidth,_viewport);
    }
    private double EffectiveWidth=>_strokeWidth;
    private void CanvasSurface_PointerPressed(object sender,PointerRoutedEventArgs e)
    {
        if(_editor is not null)return;
        var p=e.GetCurrentPoint(CanvasSurface);var screen=new Vector2((float)p.Position.X,(float)p.Position.Y);
        if(p.Properties.IsRightButtonPressed){if(_rulerEnabled&&(RulerHit(screen)||RulerRotationHit(screen)))ShowRulerSettings(CanvasSurface,new Point(screen.X,screen.Y));else ShowContext(screen);e.Handled=true;return;}
        if(p.PointerDeviceType==PointerDeviceType.Touch)return;
        CommitPropertyEdit();
        if(_rulerEnabled&&RulerAngleHit(screen)&&!p.Properties.IsMiddleButtonPressed){ShowRulerSettings(CanvasSurface,new Point(screen.X,screen.Y));e.Handled=true;return;}
        _pointerId=p.PointerId;_lastScreen=_mouse=screen;_start=_lastWorld=_viewport.ScreenToWorld(screen.X,screen.Y);
        _panning=p.Properties.IsMiddleButtonPressed || _readingMode;
        _gesture=true;CanvasSurface.CapturePointer(e.Pointer);
        if(_panning){e.Handled=true;return;}
        if(_rulerEnabled&&RulerPivotHit(screen)){_rulerPivotMoving=true;e.Handled=true;return;}
        if(_rulerEnabled&&RulerRotationHit(screen)){BeginRulerRotation(screen);e.Handled=true;return;}
        if(_rulerEnabled&&RulerHit(screen)){_rulerMoving=true;e.Handled=true;return;}
        if(_compass.IsEnabled)
        {
            var centerScreen=_viewport.WorldToScreen(_compass.Center.X,_compass.Center.Y);
            if(Vector2.Distance(screen,new((float)centerScreen.X,(float)centerScreen.Y))<18)
            {_compassCenterMoving=true;_compassCenterMoved=false;CanvasSurface.Invalidate();e.Handled=true;return;}
            var radiusScreenPt=_viewport.WorldToScreen(_compass.Center.X+_compass.Radius*.65,_compass.Center.Y);
            if(!_compass.IsArmed&&Vector2.Distance(screen,new((float)radiusScreenPt.X,(float)radiusScreenPt.Y))<14)
            {_compassRadiusMoving=true;CanvasSurface.Invalidate();e.Handled=true;return;}
            var rad=_compass.CurrentPencilAngle*Math.PI/180.0;
            var pencilScreenPt=_viewport.WorldToScreen(_compass.Center.X+_compass.Radius*Math.Cos(rad),_compass.Center.Y+_compass.Radius*Math.Sin(rad));
            if(Vector2.Distance(screen,new((float)pencilScreenPt.X,(float)pencilScreenPt.Y))<20)
            {_compassPencilMoving=true;CanvasSurface.Invalidate();e.Handled=true;return;}
        }
        if(_tool=="select")
        {
            _movingPin=_session.Document.Board.Pins?.FirstOrDefault(pin=>{var s=_viewport.WorldToScreen(pin.X,pin.Y);return Vector2.Distance(screen,new((float)s.X,(float)s.Y))<18;});
            if(_movingPin is not null){_session.Begin();return;}
            if(_session.Selected is { } selected && selected.IsLocked!=true)
            {
                foreach(var handle in ObjectHandles.Get(selected,_viewport.Zoom))
                {
                    var s=_viewport.WorldToScreen(handle.Point.X,handle.Point.Y);
                    if(Vector2.Distance(screen,new((float)s.X,(float)s.Y))>10)continue;
                    _objectHandle=handle;_manipulationStart=DocumentCodec.Clone(selected);
                    var center=ObjectHandles.Center(selected);_objectPointerAngle=Math.Atan2(_start.Y-center.Y,_start.X-center.X)*180/Math.PI;
                    _session.Begin();e.Handled=true;return;
                }
            }
            Select(_session.Hit(_start,6/_viewport.Zoom));if(_session.Selected?.IsLocked!=true)_session.Begin();
        }
        else if(_tool is "triangle" or "quadrilateral" or "curve")
        {
            _polygon.Add(_start);
            if(_polygon.Count==(_tool=="quadrilateral"?4:3))
            {
                _session.Begin();var box=VectorMath.ComputeBoundingBox(_polygon,_strokeWidth);
                _session.Add(Styled(new BoardObject{Type=_tool,X=box.MinX,Y=box.MinY,Width=box.Width,Height=box.Height,Points=JsonSerializer.Serialize(_polygon,DocumentCodec.Options)}));
                _session.Commit();_polygon.Clear();_tool="select";RefreshEditor();
            }
        }
        else if(_tool is "pen" or "highlighter" or "paint")
        {
            LatchRuler(screen);_ink.Projection=_snapEdge is null?null:ProjectOnRuler;
            _ink.ProcessPointerDown(p,_viewport);
        }
        else if(_tool=="eraser"){_session.Begin();Erase(_start);}
        else if(_tool is "text" or "sticky")
        {
            _session.Begin();var o=Styled(new BoardObject{Type=_tool,X=_start.X,Y=_start.Y,Width=240,Height=_tool=="sticky"?200:100,FillColor=_tool=="sticky"?"#fff0ab":"none",Text="",FontSize=18});
            _session.Add(o);_session.Commit();_tool="select";_gesture=false;CanvasSurface.ReleasePointerCaptures();StartText(o);
        }
        else
        {
            _shapeGesture=true;
            if(_tool is "line" or "arrow")
            {
                _lineCompleting=_lineAnchor is not null;_lineAnchor??=_start;
                _preview??=Styled(new BoardObject{Type=_tool});
                ObjectHandles.SetEndpoints(_preview,_lineAnchor,_start);
            }
            else _preview=Styled(new BoardObject{Type=_tool,X=_start.X,Y=_start.Y,Width=1,Height=1});
        }
        CanvasSurface.Invalidate();e.Handled=true;
    }
    private BoardObject Styled(BoardObject o)
    {
        o.StrokeColor = _strokeColor;
        o.StrokeWidth = EffectiveWidth;
        o.Opacity = _opacity;
        if (o.Type != "sticky")
        {
            o.FillColor = CurrentStyle.Filled ? _fillColor : "none";
            if (CurrentStyle.Filled)
            {
                o.FillOpacity = CurrentStyle.FillOpacity;
                o.FillGradientStart = CurrentStyle.FillGradientStart;
                o.FillGradientEnd = CurrentStyle.FillGradientEnd;
            }
        }
        o.LineStyle = CurrentStyle.Dash;
        if (o.Type is "text" or "sticky") o.FontSize = CurrentStyle.FontSize;
        return o;
    }
    private void CanvasSurface_PointerMoved(object sender,PointerRoutedEventArgs e)
    {
        var p=e.GetCurrentPoint(CanvasSurface);_mouse=new((float)p.Position.X,(float)p.Position.Y);_hover=true;
        if(!_gesture||p.PointerId!=_pointerId)
        {
            if(_lineAnchor is not null&&_preview is not null)ObjectHandles.SetEndpoints(_preview,_lineAnchor,_viewport.ScreenToWorld(_mouse.X,_mouse.Y));
            CanvasSurface.Invalidate();return;
        }
        var world=_viewport.ScreenToWorld(_mouse.X,_mouse.Y);var delta=_mouse-_lastScreen;
        if(_panning){_viewport.X+=delta.X;_viewport.Y+=delta.Y;}
        else if(_rulerMoving)_rulerCenter+=delta;
        else if(_rulerRotating)RotateRuler(_mouse);
        else if(_rulerPivotMoving)MoveRulerPivot(_mouse);
        else if(_compassCenterMoving)
        {
            if(_start is not null&&Math.Sqrt(Math.Pow(world.X-_start.X,2)+Math.Pow(world.Y-_start.Y,2))*_viewport.Zoom>3)_compassCenterMoved=true;
            _compass.MoveCenter(world);
        }
        else if(_compassRadiusMoving)
        {
            var dist=Math.Sqrt(Math.Pow(world.X-_compass.Center.X,2)+Math.Pow(world.Y-_compass.Center.Y,2));
            _compass.AdjustRadius(dist/.65);
            ShowHUD($"半徑: {(int)Math.Round(_compass.Radius)} pt",_mouse.X,_mouse.Y);
        }
        else if(_compassPencilMoving)
        {
            var angleRad=Math.Atan2(world.Y-_compass.Center.Y,world.X-_compass.Center.X);
            var angleDeg=angleRad*180.0/Math.PI;if(angleDeg<0)angleDeg+=360.0;
            if(!_compass.IsArmed)
            {
                _compass.PositionPencil(angleDeg);
                ShowHUD($"預備角: {angleDeg:0.#}°",_mouse.X,_mouse.Y);
            }
            else
            {
                if(!_compass.IsDrawingArc)_compass.StartArc(angleDeg);
                else _compass.UpdateSweep(angleDeg);
                ShowHUD($"半徑: {(int)Math.Round(_compass.Radius)} pt  掃角: {_compass.SweepAngle:0.#}°",_mouse.X,_mouse.Y);
            }
        }
        else if(_movingPin is not null){_movingPin.X=world.X;_movingPin.Y=world.Y;}
        else if(_ink.IsDrawing)_ink.ProcessPointerUpdate(e.GetIntermediatePoints(CanvasSurface),_viewport);
        else if(_tool=="eraser")
        {
            // Sweep with overlapping eraser circles so fast movement cannot leave gaps.
            var length=Vector2.Distance(_mouse,_lastScreen);var steps=Math.Max(1,(int)Math.Ceiling(length/Math.Max(1,EraserSizeSlider.Value*_viewport.Zoom/4)));
            for(var i=1;i<=steps;i++){var s=Vector2.Lerp(_lastScreen,_mouse,(float)i/steps);Erase(_viewport.ScreenToWorld(s.X,s.Y));}
        }
        else if(_tool=="select" && _session.Selected is { } selected && selected.IsLocked!=true)
        {
            if(_objectHandle is { Kind:"endpoint" } endpoint)ObjectHandles.MoveEndpoint(selected,endpoint.Index,world);
            else if(_objectHandle is { Kind:"arc_start" or "arc_end" } arcHandle)
            {
                ObjectHandles.MoveArcEndpoint(selected,arcHandle.Index,world);
                ShowHUD($"起角: {selected.ArcStartAngle:0.#}°  掃角: {selected.ArcSweepAngle:0.#}°",_mouse.X,_mouse.Y);
            }
            else if(_objectHandle is { Kind:"vertex" } vertex)
            {
                // Bake the existing rotation so untouched vertices stay fixed when the bounds change.
                var pts=selected.ParsedPoints.Select(pt=>ObjectHandles.ToWorld(selected,pt)).ToList();pts[vertex.Index]=world;selected.Rotation=0;selected.Points=JsonSerializer.Serialize(pts,DocumentCodec.Options);
                var box=VectorMath.ComputeBoundingBox(pts,selected.StrokeWidth);selected.X=box.MinX;selected.Y=box.MinY;selected.Width=box.Width;selected.Height=box.Height;
            }
            else if(_objectHandle is { Kind:"resize" } resize&&_manipulationStart is not null)
            {
                ObjectHandles.Resize(selected,_manipulationStart,resize.Index,world,selected.Type=="image"&&!KeyIsDown(VirtualKey.Shift));
                ShowHUD(CanvasHUDFormatter.FormatDimensions(selected.Width,selected.Height),_mouse.X,_mouse.Y);
            }
            else if(_objectHandle is { Kind:"rotate" }&&_manipulationStart is not null)
            {
                var center=ObjectHandles.Center(_manipulationStart);var angle=Math.Atan2(world.Y-center.Y,world.X-center.X)*180/Math.PI;
                var rotation=_manipulationStart.Rotation+Math.IEEERemainder(angle-_objectPointerAngle,360);
                selected.Rotation=KeyIsDown(VirtualKey.Shift)?Math.Round(rotation/15)*15:Math.Round(rotation,1);
                ShowHUD(CanvasHUDFormatter.FormatRotation(selected.Rotation),_mouse.X,_mouse.Y);
            }
            else if(_lastWorld is not null)_session.Move(selected,world.X-_lastWorld.X,world.Y-_lastWorld.Y);
            UpdateSelectionBarPosition();
        }
        else if(_shapeGesture&&_preview is not null && _start is not null)
        {
            UpdateShapePreview(world);
            ShowHUD(CanvasHUDFormatter.FormatDimensions(_preview.Width,_preview.Height),_mouse.X,_mouse.Y);
        }
        _lastScreen=_mouse;_lastWorld=world;CanvasSurface.Invalidate();e.Handled=true;
    }
    private void Erase(InkPoint p)=>_session.Erase(p,EraserSizeSlider.Value/2,EraserModeBox.SelectedIndex==0);
    private void CanvasSurface_PointerReleased(object sender,PointerRoutedEventArgs e)
    {
        HideHUD();
        if(!_gesture||e.Pointer.PointerId!=_pointerId)return;
        if(_compassCenterMoving)
        {
            if(!_compassCenterMoved)
            {
                _compass.ToggleArmed();
                StatusText.Text=_compass.IsArmed?"圓心已鎖定：請拖曳筆尖畫弧":"準備階段：可移動圓心與調整半徑";
            }
        }
        else if(_compassPencilMoving)
        {
            if(_compass.IsDrawingArc)
            {
                _compass.FinishArcDrawing();
                if(Math.Abs(_compass.SweepAngle)>=0.5)
                {
                    _session.Begin();
                    _compass.StrokeColor=_strokeColor;
                    _compass.StrokeWidth=EffectiveWidth;
                    _compass.LineStyle=CurrentStyle.Dash;
                    var board=_session.Document.Board;
                    var arcObj=_compass.CreateArcObject(board.Id,board.ActivePageId,fullCircle:false);
                    arcObj.FillColor=CurrentStyle.Filled?_fillColor:"none";
                    arcObj.FillOpacity=CurrentStyle.FillOpacity;
                    arcObj.FillGradientStart=CurrentStyle.FillGradientStart;
                    arcObj.FillGradientEnd=CurrentStyle.FillGradientEnd;
                    _session.Add(arcObj);
                    _session.SelectedId=arcObj.Id;
                    _session.Commit();
                    _compass.Prepare();
                    _compass.IsEnabled=false;
                    _tool="select";
                    RefreshEditor();
                    StatusText.Text=$"已生成圓弧（半徑 {_compass.Radius:0.#}pt，掃角 {_compass.SweepAngle:0.#}°）";
                }
                else
                {
                    _compass.SweepAngle=0;
                }
            }
        }
        else if(_ink.IsDrawing)
        {
            var points=_ink.Finish(e.GetCurrentPoint(CanvasSurface),_viewport);
            if(points.Count>0)
            {
                _session.Begin();var box=VectorMath.ComputeBoundingBox(points,EffectiveWidth);
                var o=Styled(new BoardObject{Type=_tool=="pen"?"stroke":_tool,X=box.MinX,Y=box.MinY,Width=box.Width,Height=box.Height,Points=JsonSerializer.Serialize(points,DocumentCodec.Options)});
                _session.Add(o);
            }
        }
        else if(_shapeGesture&&_preview is not null)
        {
            var end=e.GetCurrentPoint(CanvasSurface).Position;var world=_viewport.ScreenToWorld(end.X,end.Y);UpdateShapePreview(world);
            var line=_preview.Type is "line" or "arrow";
            var enough=line?Math.Sqrt(_preview.Width*_preview.Width+_preview.Height*_preview.Height)*_viewport.Zoom>3:Math.Max(_preview.Width,_preview.Height)*_viewport.Zoom>3;
            if(enough&&(!line||_lineCompleting||_start is not null&&Math.Sqrt(Math.Pow(world.X-_start.X,2)+Math.Pow(world.Y-_start.Y,2))*_viewport.Zoom>3))
            {_session.Begin();_session.Add(_preview);_preview=null;_lineAnchor=null;_tool="select";}
            else if(!line){_preview=null;}
        }
        _session.Commit();ResetGesture();CanvasSurface.ReleasePointerCaptures();RefreshEditor();e.Handled=true;
    }
    private static bool KeyIsDown(VirtualKey key)=>Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(key).HasFlag(global::Windows.UI.Core.CoreVirtualKeyStates.Down);
    private void UpdateShapePreview(InkPoint world)
    {
        if(_preview is null||_start is null)return;
        if(_preview.Type is "line" or "arrow")ObjectHandles.SetEndpoints(_preview,_lineAnchor??_start,world);
        else{_preview.X=Math.Min(_start.X,world.X);_preview.Y=Math.Min(_start.Y,world.Y);_preview.Width=Math.Max(1,Math.Abs(world.X-_start.X));_preview.Height=Math.Max(1,Math.Abs(world.Y-_start.Y));}
    }
    private void ResetGesture(){HideHUD();_renderer.ResetLive();_gesture=_panning=_rulerMoving=_rulerRotating=_rulerPivotMoving=_shapeGesture=_lineCompleting=false;_compassCenterMoving=_compassCenterMoved=_compassRadiusMoving=_compassPencilMoving=false;_objectHandle=null;_manipulationStart=null;_movingPin=null;_snapEdge=null;_ink.Projection=null;}
    private void CancelGesture(){HideHUD();_ink.Cancel();_session.Cancel();_preview=null;_lineAnchor=null;_compass.Prepare();ResetGesture();CanvasSurface.ReleasePointerCaptures();CanvasSurface.Invalidate();}
    private void CanvasSurface_PointerCanceled(object sender,PointerRoutedEventArgs e){HideHUD();if(_gesture)CancelGesture();}
    private void CanvasSurface_PointerExited(object sender,PointerRoutedEventArgs e){HideHUD();_hover=false;CanvasSurface.Invalidate();}
    private void CanvasSurface_PointerWheelChanged(object sender,PointerRoutedEventArgs e)
    {
        if(_editor is not null||_gesture)return;
        var p=e.GetCurrentPoint(CanvasSurface);var world=_viewport.ScreenToWorld(p.Position.X,p.Position.Y);
        var ctrl=Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control).HasFlag(global::Windows.UI.Core.CoreVirtualKeyStates.Down);
        if(ctrl){_viewport.Zoom=Math.Clamp(_viewport.Zoom*Math.Pow(1.1,p.Properties.MouseWheelDelta/120d),.05,8);_viewport.X=p.Position.X-world.X*_viewport.Zoom;_viewport.Y=p.Position.Y-world.Y*_viewport.Zoom;}
        else if(p.Properties.IsHorizontalMouseWheel)_viewport.X+=p.Properties.MouseWheelDelta;
        else _viewport.Y+=p.Properties.MouseWheelDelta;
        ZoomText.Text=$"{_viewport.Zoom:P0}";RefreshProperties();CanvasSurface.Invalidate();e.Handled=true;
    }
    private void CanvasSurface_DoubleTapped(object sender,DoubleTappedRoutedEventArgs e)
    {var p=e.GetPosition(CanvasSurface);var o=_session.Hit(_viewport.ScreenToWorld(p.X,p.Y),6/_viewport.Zoom);if(o?.Type is "text" or "sticky" && o.IsLocked!=true){StartText(o);e.Handled=true;}}
    private void StartText(BoardObject o)
    {
        FinishText();_editingObject=o;var p=_viewport.WorldToScreen(o.X,o.Y);
        _editor=new TextBox{Text=o.Text??"",AcceptsReturn=true,TextWrapping=TextWrapping.Wrap,
            Width=Math.Max(120,o.Width*_viewport.Zoom),Height=Math.Max(80,o.Height*_viewport.Zoom),FontSize=Math.Max(8,(o.FontSize??18)*_viewport.Zoom)};
        Canvas.SetLeft(_editor,p.X);Canvas.SetTop(_editor,p.Y);TextOverlay.IsHitTestVisible=true;TextOverlay.Children.Add(_editor);
        _editor.KeyDown+=(_,e)=>{var ctrl=Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control).HasFlag(global::Windows.UI.Core.CoreVirtualKeyStates.Down);
            if(e.Key==VirtualKey.Escape||(ctrl&&e.Key==VirtualKey.Enter)){FinishText();e.Handled=true;}};
        _editor.LostFocus+=(_,_)=>FinishText();_editor.Focus(FocusState.Programmatic);
    }
    private void FinishText()
    {
        if(_editor is null||_editingObject is null)return;
        var input=_editor;var o=_editingObject;_editor=null;_editingObject=null;
        if(o.Text!=input.Text){_session.Begin();o.Text=input.Text;_session.Commit();}
        TextOverlay.Children.Clear();TextOverlay.IsHitTestVisible=false;CanvasSurface.Invalidate();
    }
    private void CancelScreenshotCapture(string reason)
    {
        _regionCaptureCancellation?.Cancel();
        _screenshotCoordinator.Cancel(reason);
        _screenshotWatchTimer.Stop();
    }

    private Task OnScreenshotWatchTickAsync()
    {
        if (_screenshotCoordinator.CheckTimeout())
        {
            _regionCaptureCancellation?.Cancel();
            _screenshotWatchTimer.Stop();
            StatusText.Text = "截圖已逾時（超過 60 秒）";
        }
        else if (!_screenshotCoordinator.HasActiveSession)
        {
            _regionCaptureCancellation?.Cancel();
            _screenshotWatchTimer.Stop();
        }
        return Task.CompletedTask;
    }

    private async void Screenshot_Click(object sender, RoutedEventArgs e)
    {
        if (!_workspaceOpen || _screenshotCoordinator.HasActiveSession) return;
        FinishText(); CommitPropertyEdit();
        _activeFlyout?.Hide();
        var board = _session.Document.Board;
        var center = _viewport.ScreenToWorld(CanvasSurface.ActualWidth / 2, CanvasSurface.ActualHeight / 2);
        var request = _screenshotCoordinator.BeginCapture(board.Id, board.ActivePageId, center, 0);
        if (request is null) return;
        var cancellation = new CancellationTokenSource();
        _regionCaptureCancellation = cancellation;
        _screenshotWatchTimer.Start();
        StatusText.Text = "拖曳框選截圖，Esc 或右鍵取消";
        try
        {
            // Let the insertion menu close before taking the desktop snapshot.
            await Task.Delay(150, cancellation.Token);
            var bytes = await RegionScreenshotService.CaptureAsync(cancellation.Token);
            if (bytes is null)
            {
                if (_screenshotCoordinator.CancelIfMatching(request.RequestId))
                    StatusText.Text = "已取消截圖";
                return;
            }
            if (!_screenshotCoordinator.BeginProcessing(request.RequestId)) return;
            using var stream = new InMemoryRandomAccessStream();
            using (var writer = new DataWriter(stream.GetOutputStreamAt(0)))
            {
                writer.WriteBytes(bytes);
                await writer.StoreAsync();
                await writer.FlushAsync();
                writer.DetachStream();
            }
            stream.Seek(0);
            var inserted = await InsertImageStreamAsync(stream, request.TargetCenter, true,
                request.RequestId, request.BoardId, request.PageId);
            if (inserted) StatusText.Text = "截圖已加入畫布";
        }
        catch (OperationCanceledException)
        {
            if (_screenshotCoordinator.CancelIfMatching(request.RequestId)) StatusText.Text = "已取消截圖";
        }
        catch (Exception ex)
        {
            if (_screenshotCoordinator.CancelIfMatching(request.RequestId))
                StatusText.Text = "截圖未完成：" + ex.Message;
        }
        finally
        {
            // An old decode must not stop a newer request's watcher or cancellation source.
            if (ReferenceEquals(_regionCaptureCancellation, cancellation))
            {
                _screenshotWatchTimer.Stop();
                _regionCaptureCancellation = null;
            }
            cancellation.Dispose();
        }
    }

    private async void Image_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var picker = new FileOpenPicker();
            WinRT.Interop.InitializeWithWindow.Initialize(picker, WinRT.Interop.WindowNative.GetWindowHandle(this));
            foreach (var ext in new[] { ".png", ".jpg", ".jpeg", ".bmp", ".gif", ".tif", ".tiff" }) picker.FileTypeFilter.Add(ext);
            var file = await picker.PickSingleFileAsync();
            if (file is not null)
            {
                var centerScreen = new Vector2((float)CanvasSurface.ActualWidth / 2, (float)CanvasSurface.ActualHeight / 2);
                await InsertImageFileAsync(file.Path, _viewport.ScreenToWorld(centerScreen.X, centerScreen.Y), isCenter: true);
            }
        }
        catch (Exception ex) { await Error(ex); }
    }

    private async Task<bool> InsertImageFileAsync(string path, InkPoint location, bool isCenter)
    {
        using var bitmap = await CanvasBitmap.LoadAsync(CanvasSurface, path);
        var bytes = await File.ReadAllBytesAsync(path);
        var ext = Path.GetExtension(path).TrimStart('.').ToLowerInvariant();
        if (ext == "jpg") ext = "jpeg";
        if (string.IsNullOrEmpty(ext)) ext = "png";
        var dataUri = $"data:image/{ext};base64," + Convert.ToBase64String(bytes);
        return await ApplyImageInsertionAsync(bitmap.SizeInPixels.Width, bitmap.SizeInPixels.Height, dataUri, location, isCenter);
    }

    private async Task<bool> InsertImageStreamAsync(IRandomAccessStream stream, InkPoint location, bool isCenter, string? expectedRequestId = null, string? expectedBoardId = null, string? expectedPageId = null)
    {
        using var bitmap = await CanvasBitmap.LoadAsync(CanvasSurface, stream);
        using var memory = new InMemoryRandomAccessStream();
        await bitmap.SaveAsync(memory, CanvasBitmapFileFormat.Png);
        memory.Seek(0);
        using var netStream = memory.AsStreamForRead();
        using var ms = new MemoryStream();
        await netStream.CopyToAsync(ms);
        var dataUri = "data:image/png;base64," + Convert.ToBase64String(ms.ToArray());
        return await ApplyImageInsertionAsync(bitmap.SizeInPixels.Width, bitmap.SizeInPixels.Height, dataUri, location, isCenter, expectedRequestId, expectedBoardId, expectedPageId);
    }

    private async Task<bool> ApplyImageInsertionAsync(double naturalW, double naturalH, string dataUri, InkPoint location, bool isCenter, string? expectedRequestId = null, string? expectedBoardId = null, string? expectedPageId = null)
    {
        if (naturalW <= 0 || naturalH <= 0 || !_workspaceOpen) return false;
        var board = _session.Document.Board;
        if(expectedBoardId is not null && (board.Id!=expectedBoardId||board.ActivePageId!=expectedPageId))return false;

        if (!string.IsNullOrEmpty(expectedRequestId))
        {
            if (!_screenshotCoordinator.ValidateAndComplete(expectedRequestId, board.Id, board.ActivePageId))
            {
                // 情境已改變（使用者在解碼期間切換了作品或頁面、關閉視窗或取消了截圖），放棄置入
                return false;
            }
        }

        var vpW = CanvasSurface.ActualWidth / Math.Max(0.1, _viewport.Zoom);
        var vpH = CanvasSurface.ActualHeight / Math.Max(0.1, _viewport.Zoom);
        var (w, h, posX, posY) = ImagePlacementMath.ComputePlacement(
            naturalW,
            naturalH,
            vpW,
            vpH,
            board.CanvasMode ?? "infinite",
            board.CanvasWidth,
            board.CanvasHeight,
            location,
            isCenter
        );

        ActivateTool("select");
        _session.Begin();
        var o = new BoardObject
        {
            Id = Guid.NewGuid().ToString(),
            BoardId = board.Id,
            PageId = board.ActivePageId,
            Type = "image",
            X = posX,
            Y = posY,
            Width = w,
            Height = h,
            Rotation = 0,
            Opacity = 1,
            StrokeWidth = 1,
            ImageUrl = dataUri,
            OriginalImageUrl = dataUri,
            OriginalWidth = naturalW,
            OriginalHeight = naturalH,
            ZIndex = _session.VisibleObjects.Any() ? _session.VisibleObjects.Max(x => x.ZIndex) + 1 : 1
        };
        _session.Add(o);
        _session.SelectedId = o.Id;
        _session.Commit();

        await _renderer.LoadImagesAsync(CanvasSurface, _session.Document.Objects);
        _tool = "select";
        RefreshEditor();
        return true;
    }

    private void DrawingArea_DragOver(object sender, DragEventArgs e)
    {
        if (e.DataView.Contains(StandardDataFormats.StorageItems))
        {
            e.AcceptedOperation = DataPackageOperation.Copy;
            e.Handled = true;
        }
    }

    private async void DrawingArea_Drop(object sender, DragEventArgs e)
    {
        var deferral = e.GetDeferral();
        try
        {
            var position = e.GetPosition(CanvasSurface);
            var world = _viewport.ScreenToWorld(position.X, position.Y);
            foreach (var file in (await e.DataView.GetStorageItemsAsync()).OfType<StorageFile>())
                await InsertImageFileAsync(file.Path, world, isCenter: true);
        }
        catch (Exception ex) { await Error(ex); }
        finally { deferral.Complete(); }
    }

    private void ShowContext(Vector2 screen)
    {
        var pin=_session.Document.Board.Pins?.FirstOrDefault(p=>{var s=_viewport.WorldToScreen(p.X,p.Y);return Vector2.Distance(screen,new((float)s.X,(float)s.Y))<18;});
        Select(_session.Hit(_viewport.ScreenToWorld(screen.X,screen.Y),6/_viewport.Zoom));
        var menu=new MenuFlyout();void Add(string name,Action action){var item=new MenuFlyoutItem{Text=name};item.Click+=(_,_)=>action();menu.Items.Add(item);}
        if(pin is not null){Add("重新命名圖釘",async()=>await RenamePin(pin));Add("刪除圖釘",()=>{_session.Begin();_session.Document.Board.Pins!.Remove(pin);_session.Commit();RefreshEditor();});}
        if(_session.Selected is not null){Add("複製",CopySelected);Add("製作副本",DuplicateSelected);Add("刪除",()=>Delete_Click(this,new RoutedEventArgs()));
            if(_session.Selected.Type is "text" or "sticky")Add("編輯文字",()=>StartText(_session.Selected!));}
        Add("貼上",PasteObject);menu.ShowAt(CanvasSurface,new Microsoft.UI.Xaml.Controls.Primitives.FlyoutShowOptions{Position=new Point(screen.X,screen.Y)});
    }
    private void CopySelected()
    {if(_session.Selected is not { } o)return;var package=new DataPackage();package.SetText("HEIBAN_OBJECT:"+JsonSerializer.Serialize(o,DocumentCodec.Options));Clipboard.SetContent(package);}
    private async void PasteObject()
    {
        try
        {
            var clipboard = Clipboard.GetContent();
            var centerScreen = new Vector2((float)CanvasSurface.ActualWidth / 2, (float)CanvasSurface.ActualHeight / 2);
            var targetCenter = _viewport.ScreenToWorld(centerScreen.X, centerScreen.Y);
            if (clipboard.Contains(StandardDataFormats.Bitmap))
            {
                using var stream = await (await clipboard.GetBitmapAsync()).OpenReadAsync();
                await InsertImageStreamAsync(stream, targetCenter, isCenter: true);
                return;
            }
            if (clipboard.Contains(StandardDataFormats.StorageItems))
            {
                foreach (var file in (await clipboard.GetStorageItemsAsync()).OfType<StorageFile>())
                    await InsertImageFileAsync(file.Path, targetCenter, isCenter: true);
                return;
            }
            if (!clipboard.Contains(StandardDataFormats.Text)) return;
            var text = await clipboard.GetTextAsync();
            if (!text.StartsWith("HEIBAN_OBJECT:", StringComparison.Ordinal)) return;
            var o = JsonSerializer.Deserialize<BoardObject>(text[14..], DocumentCodec.Options);
            if (o is null) return;
            ActivateTool("select");
            o.Id = Guid.NewGuid().ToString();
            _session.Move(o, 20, 20);
            _session.Begin();
            _session.Add(o);
            _session.SelectedId = o.Id;
            _session.Commit();
            await _renderer.LoadImagesAsync(CanvasSurface, _session.Document.Objects);
            RefreshEditor();
        }
        catch (Exception ex) { await Error(ex); }
    }
    private void DuplicateSelected()
    {if(_session.Selected is not { } selected)return;var o=DocumentCodec.Clone(selected);o.Id=Guid.NewGuid().ToString();_session.Move(o,20,20);_session.Begin();_session.Add(o);_session.Commit();RefreshEditor();}
    private async void Pin_Click(object sender, RoutedEventArgs e)
    {
        var searchBox = new TextBox { PlaceholderText = "搜尋圖釘名稱…", HorizontalAlignment = HorizontalAlignment.Stretch };
        var newPinBox = new TextBox { PlaceholderText = "新圖釘名稱（預設：重要位置）", HorizontalAlignment = HorizontalAlignment.Stretch };
        var listContainer = new StackPanel { Spacing = 8 };
        var scroll = new ScrollViewer { Content = listContainer, MaxHeight = 300, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        ContentDialog? dialog = null;

        void RenderPins()
        {
            listContainer.Children.Clear();
            var pins = _session.Document.Board.Pins ?? [];
            var query = searchBox.Text?.Trim() ?? "";
            var filtered = pins.Where(p => string.IsNullOrEmpty(query) || p.Name.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();

            if (filtered.Count == 0)
            {
                listContainer.Children.Add(new TextBlock
                {
                    Text = string.IsNullOrEmpty(query) ? "尚無圖釘標記" : "無相符的圖釘",
                    Foreground = Brush("#68756C"),
                    Margin = new Thickness(8),
                    HorizontalAlignment = HorizontalAlignment.Center
                });
                return;
            }

            foreach (var pin in filtered)
            {
                var row = new Grid { Margin = new Thickness(0, 2, 0, 2) };
                row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var navContent = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                navContent.Children.Add(new Views.PinIcon());
                navContent.Children.Add(new TextBlock { Text = pin.Name, VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis });
                var navBtn = new Button { Content = navContent, HorizontalAlignment = HorizontalAlignment.Stretch, HorizontalContentAlignment = HorizontalAlignment.Left };
                navBtn.Click += (_, _) =>
                {
                    dialog?.Hide();
                    _viewport.Zoom = Math.Clamp(pin.Zoom, .05, 8);
                    _viewport.X = CanvasSurface.ActualWidth * .2 - pin.X * _viewport.Zoom;
                    _viewport.Y = CanvasSurface.ActualHeight * .2 - pin.Y * _viewport.Zoom;
                    RefreshEditor();
                };
                Grid.SetColumn(navBtn, 0);
                row.Children.Add(navBtn);

                var renameBtn = new Button { Content = "改名", Margin = new Thickness(4, 0, 0, 0), Padding = new Thickness(8, 4, 8, 4) };
                renameBtn.Click += async (_, _) =>
                {
                    await RenamePin(pin);
                    RenderPins();
                };
                Grid.SetColumn(renameBtn, 1);
                row.Children.Add(renameBtn);

                var deleteBtn = new Button { Content = "刪除", Margin = new Thickness(4, 0, 0, 0), Padding = new Thickness(8, 4, 8, 4) };
                deleteBtn.Click += (_, _) =>
                {
                    _session.Begin();
                    _session.Document.Board.Pins?.Remove(pin);
                    _session.Commit();
                    RefreshEditor();
                    RenderPins();
                };
                Grid.SetColumn(deleteBtn, 2);
                row.Children.Add(deleteBtn);

                listContainer.Children.Add(row);
            }
        }

        searchBox.TextChanged += (_, _) => RenderPins();
        RenderPins();

        var contentPanel = new StackPanel { Spacing = 12, Width = 380 };
        contentPanel.Children.Add(new TextBlock { Text = "搜尋或跳轉至圖釘視野", FontSize = 12, Foreground = Brush("#68756C") });
        contentPanel.Children.Add(searchBox);
        contentPanel.Children.Add(scroll);
        contentPanel.Children.Add(new Border { Height = 1, Background = Brush("#D4DBD1"), Margin = new Thickness(0, 4, 0, 4) });
        contentPanel.Children.Add(new TextBlock { Text = "在目前視野新增圖釘：", FontSize = 12, Foreground = Brush("#68756C") });
        contentPanel.Children.Add(newPinBox);

        dialog = new ContentDialog
        {
            Title = "圖釘導航",
            Content = contentPanel,
            PrimaryButtonText = "新增圖釘",
            CloseButtonText = "關閉",
            XamlRoot = Root.XamlRoot
        };

        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;

        var world = _viewport.ScreenToWorld(CanvasSurface.ActualWidth / 2, CanvasSurface.ActualHeight / 2);
        _session.Begin();
        (_session.Document.Board.Pins ??= []).Add(new BoardPin
        {
            Name = string.IsNullOrWhiteSpace(newPinBox.Text) ? "重要位置" : newPinBox.Text.Trim(),
            X = world.X,
            Y = world.Y,
            Zoom = _viewport.Zoom
        });
        _session.Commit();
        RefreshEditor();
    }
    private async Task RenamePin(BoardPin pin)
    {
        var box = new TextBox { Text = pin.Name };
        if (await new ContentDialog { Title = "修改圖釘名稱", Content = box, PrimaryButtonText = "儲存", CloseButtonText = "取消", XamlRoot = Root.XamlRoot }.ShowAsync() != ContentDialogResult.Primary) return;
        if (!string.IsNullOrWhiteSpace(box.Text))
        {
            _session.Begin();
            pin.Name = box.Text.Trim();
            _session.Commit();
            RefreshEditor();
        }
    }
}
