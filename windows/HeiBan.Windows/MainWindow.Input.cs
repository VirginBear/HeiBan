using System.IO;
using System.Numerics;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
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
    private bool _lineCompleting,_shapeGesture,_marquee;
    private string[] _marqueeSelection=[];
    private readonly List<InkPoint> _polygon=[];
    private readonly List<InkPoint> _lasso=[];
    private readonly LaserPointerEngine _laser=new();
    private bool _viewLocked;
    private Vector2 _lastScreen;
    private BoardPin? _movingPin;
    private bool _rulerEnabled;
    private Vector2 _rulerCenter=new(450,350);
    private double _rulerAngle;
    private string? _rulerColor;
    private Vector2? _snapEdge;
    private Vector2 _snapDirection;

    private void CanvasSurface_CreateResources(CanvasControl sender,Microsoft.Graphics.Canvas.UI.CanvasCreateResourcesEventArgs e)
    {ClearScene();_renderer.ClearCache();e.TrackAsyncAction(_renderer.LoadImagesAsync(sender,_session.Document.Objects).AsAsyncAction());}
    private void CanvasSurface_Draw(CanvasControl sender,CanvasDrawEventArgs e)
    {
        var ds=e.DrawingSession;var w=(float)sender.ActualWidth;var h=(float)sender.ActualHeight;
        RenderMainScene(sender,ds,w,h);
        var board=_session.Document.Board;
        var clip=board.CanvasMode=="infinite"?new Rect(0,0,w,h):new Rect(_viewport.X,_viewport.Y,(board.CanvasWidth??595)*_viewport.Zoom,(board.CanvasHeight??842)*_viewport.Zoom);
        using(var layer=ds.CreateLayer(1,clip))
        {
            if(_preview is not null)_renderer.RenderPreview(ds,_preview,_viewport,w,h);
            if(_ink.IsDrawing)_renderer.RenderLiveStroke(ds,_ink.ActiveStrokePoints,_viewport,_strokeColor,EffectiveWidth,_opacity,CurrentStyle.Dash);
            if(_polygon.Count>0)
            {
                var preview=CurvePreview.Points(_polygon,_viewport.ScreenToWorld(_mouse.X,_mouse.Y));
                _renderer.RenderLiveStroke(ds,preview,_viewport,_strokeColor,_strokeWidth,_opacity,CurrentStyle.Dash);
            }
            foreach(var selected in _session.SelectedObjects)_renderer.RenderSelection(ds,selected,_viewport,_session.SelectedIds.Count==1);
            if(_lasso.Count>1)_renderer.RenderLiveStroke(ds,_lasso,_viewport,"#39735A",1/_viewport.Zoom,.8);
            _renderer.RenderLaser(ds,_laser,_viewport,LaserNow);
        }
        foreach(var pin in board.Pins??[])
        {
            var p=_viewport.WorldToScreen(pin.X,pin.Y);
            Direct2DCanvasRenderer.DrawPin(ds,new((float)p.X,(float)p.Y),.9f,pin.Color);
            using var format=new Microsoft.Graphics.Canvas.Text.CanvasTextFormat{FontSize=14};
            ds.DrawText(pin.Name,(float)p.X+16,(float)p.Y,Direct2DCanvasRenderer.HexToColor(pin.TextColor??"#397056"),format);
        }
        if(_rulerEnabled)DrawRuler(ds);
        if(_compass.IsEnabled)_renderer.RenderCompass(ds,_compass,_viewport);
        if(_hover&&_editor is null&&_tool is "pen" or "highlighter" or "paint" or "eraser")
            _renderer.RenderHover(ds,_mouse,_tool=="eraser",_tool=="eraser"?EraserSizeSlider.Value:EffectiveWidth,_viewport);
    }
    private double EffectiveWidth=>_strokeWidth;
    private void CanvasSurface_PointerPressed(object sender,PointerRoutedEventArgs e)
    {
        FinishPinRename();
        if(_editor is not null)FinishText();
        var p=e.GetCurrentPoint(CanvasSurface);var screen=new Vector2((float)p.Position.X,(float)p.Position.Y);
        if(p.Properties.IsRightButtonPressed){if(_rulerEnabled&&(RulerHit(screen)||RulerRotationHit(screen)))ShowRulerSettings(CanvasSurface,new Point(screen.X,screen.Y));else ShowContext(screen);e.Handled=true;return;}
        if(p.PointerDeviceType==PointerDeviceType.Touch)return;
        CommitPropertyEdit();
        if(_rulerEnabled&&RulerAngleHit(screen)&&!p.Properties.IsMiddleButtonPressed){ShowRulerSettings(CanvasSurface,new Point(screen.X,screen.Y));e.Handled=true;return;}
        _pointerId=p.PointerId;_lastScreen=_mouse=screen;_start=_lastWorld=_viewport.ScreenToWorld(screen.X,screen.Y);
        _panning=p.Properties.IsMiddleButtonPressed || KeyIsDown(VirtualKey.Space) || _readingMode;
        _gesture=true;CanvasSurface.CapturePointer(e.Pointer);
        if(_tool=="laser"){_panning=false;_laser.Add(_start,LaserNow);InvalidateCanvas();e.Handled=true;return;}
        if(_panning){if(_viewLocked)_panning=false;e.Handled=true;return;}
        if(_tool=="lasso"){_lasso.Clear();_lasso.Add(_start);e.Handled=true;return;}
        if(_rulerEnabled&&RulerPivotHit(screen)){_rulerPivotMoving=true;e.Handled=true;return;}
        if(_rulerEnabled&&RulerRotationHit(screen)){BeginRulerRotation(screen);e.Handled=true;return;}
        if(_rulerEnabled&&RulerHit(screen)){_rulerMoving=true;e.Handled=true;return;}
        if(_compass.IsEnabled)
        {
            var centerScreen=_viewport.WorldToScreen(_compass.Center.X,_compass.Center.Y);
            if(Vector2.Distance(screen,new((float)centerScreen.X,(float)centerScreen.Y))<18)
            {_compassCenterMoving=true;_compassCenterMoved=false;InvalidateCanvas();e.Handled=true;return;}
            var radiusScreenPt=_viewport.WorldToScreen(_compass.Center.X+_compass.Radius*.65,_compass.Center.Y);
            if(!_compass.IsArmed&&Vector2.Distance(screen,new((float)radiusScreenPt.X,(float)radiusScreenPt.Y))<14)
            {_compassRadiusMoving=true;InvalidateCanvas();e.Handled=true;return;}
            var rad=_compass.CurrentPencilAngle*Math.PI/180.0;
            var pencilScreenPt=_viewport.WorldToScreen(_compass.Center.X+_compass.Radius*Math.Cos(rad),_compass.Center.Y+_compass.Radius*Math.Sin(rad));
            if(Vector2.Distance(screen,new((float)pencilScreenPt.X,(float)pencilScreenPt.Y))<20)
            {_compassPencilMoving=true;InvalidateCanvas();e.Handled=true;return;}
        }
        if(_tool=="select")
        {
            _movingPin=PinAt(screen);
            if(_movingPin is not null){_session.Begin();e.Handled=true;return;}
            if(_session.SelectedIds.Count==1&&_session.Selected is { } selected && selected.IsLocked!=true)
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
            var hit=_session.Hit(_start,6/_viewport.Zoom);
            if((KeyIsDown(VirtualKey.Control)||KeyIsDown(VirtualKey.Shift))&&hit is not null)_session.ToggleSelection(hit.Id);
            else if(hit is not null&&!_session.SelectedIds.Contains(hit.Id)||hit is null&&!KeyIsDown(VirtualKey.Control)&&!KeyIsDown(VirtualKey.Shift))Select(hit);
            if(hit is null)BeginWindowSelection(_start,KeyIsDown(VirtualKey.Control)||KeyIsDown(VirtualKey.Shift));
            else if(_session.SelectedObjects.Any(o=>o.IsLocked!=true))_session.Begin();
        }
        else if(_tool is "triangle" or "quadrilateral" or "curve")
        {
            _polygon.Add(_start);
            if(_polygon.Count==(_tool=="quadrilateral"?4:3))
            {
                _session.Begin();var box=VectorMath.ComputeBoundingBox(_tool=="curve"?CurvePreview.Flatten(_polygon):_polygon,_strokeWidth);
                _session.Add(Styled(new BoardObject{Type=_tool,X=box.MinX,Y=box.MinY,Width=box.Width,Height=box.Height,Points=JsonSerializer.Serialize(_polygon,DocumentCodec.Options)}));
                _session.Commit();_polygon.Clear();_tool="select";ResetGesture();CanvasSurface.ReleasePointerCaptures();RefreshEditor();
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
            var o=Styled(new BoardObject{Type=_tool,X=_start.X,Y=_start.Y,Width=240,Height=_tool=="sticky"?200:100,FillColor=_tool=="sticky"?"#fff0ab":"none",Text="",FontSize=18});
            _tool="select";_gesture=false;CanvasSurface.ReleasePointerCaptures();StartText(o,true);
        }
        else
        {
            _shapeGesture=true;
            if(_tool is "line" or "arrow")
            {
                _lineCompleting=_lineAnchor is not null;_lineAnchor??=_start;
                _preview??=Styled(new BoardObject{Type=_tool});
                ObjectHandles.SetEndpoints(_preview,_lineAnchor,ConstrainLine(_lineAnchor,_start));
            }
            else _preview=Styled(new BoardObject{Type=_tool,X=_start.X,Y=_start.Y,Width=1,Height=1});
        }
        InvalidateCanvas();e.Handled=true;
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
        o.LineStyle = CurrentStyle.Dash;o.BrushKind=CurrentStyle.BrushKind;o.Extension=CurrentStyle.Extension;
        if(o.Type=="tape"){o.IsRevealed=false;o.StrokeColor="#F59E0B";o.FillColor="#F59E0B";}
        if (o.Type is "text" or "sticky") o.FontSize = CurrentStyle.FontSize;
        return o;
    }
    private void CanvasSurface_PointerMoved(object sender,PointerRoutedEventArgs e)
    {
        var p=e.GetCurrentPoint(CanvasSurface);_mouse=new((float)p.Position.X,(float)p.Position.Y);_hover=true;
        if(_tool=="laser"){_laser.Add(_viewport.ScreenToWorld(_mouse.X,_mouse.Y),LaserNow);InvalidateCanvas(false);return;}
        if(_tool=="lasso"&&_gesture){var lp=_viewport.ScreenToWorld(_mouse.X,_mouse.Y);if(_lasso.Count==0||Math.Sqrt(Math.Pow(lp.X-_lasso[^1].X,2)+Math.Pow(lp.Y-_lasso[^1].Y,2))>2/_viewport.Zoom)_lasso.Add(lp);InvalidateCanvas(false);return;}
        if(!_gesture||p.PointerId!=_pointerId)
        {
            if(_lineAnchor is not null&&_preview is not null)ObjectHandles.SetEndpoints(_preview,_lineAnchor,ConstrainLine(_lineAnchor,_viewport.ScreenToWorld(_mouse.X,_mouse.Y)));
            if(_polygon.Count>0||_lineAnchor is not null||(_hover&&_editor is null&&_tool is "pen" or "highlighter" or "paint" or "eraser"))InvalidateCanvas(false);return;
        }
        var world=_viewport.ScreenToWorld(_mouse.X,_mouse.Y);var delta=_mouse-_lastScreen;
        if(_panning){if(!_viewLocked){_viewport.X+=delta.X;_viewport.Y+=delta.Y;}}
        else if(_rulerMoving)_rulerCenter+=delta;
        else if(_rulerRotating)RotateRuler(_mouse);
        else if(_rulerPivotMoving)MoveRulerPivot(_mouse);
        else if(_marquee&&_start is not null)
        {
            var end=e.GetCurrentPoint(CanvasSurface).Position;CompleteWindowSelection(_viewport.ScreenToWorld(end.X,end.Y));
        }
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
        else if(_movingPin is not null&&_lastWorld is not null){_movingPin.X+=world.X-_lastWorld.X;_movingPin.Y+=world.Y-_lastWorld.Y;}
        else if(_ink.IsDrawing)_ink.ProcessPointerUpdate(e.GetIntermediatePoints(CanvasSurface),_viewport);
        else if(_tool=="eraser")
        {
            // Sweep with overlapping eraser circles so fast movement cannot leave gaps.
            var length=Vector2.Distance(_mouse,_lastScreen);var steps=Math.Max(1,(int)Math.Ceiling(length/Math.Max(1,EraserSizeSlider.Value*_viewport.Zoom/4)));
            for(var i=1;i<=steps;i++){var s=Vector2.Lerp(_lastScreen,_mouse,(float)i/steps);Erase(_viewport.ScreenToWorld(s.X,s.Y));}
        }
        else if(_marquee&&_preview is not null)UpdateWindowSelection(world);
        else if(_tool=="select" && _session.Selected is { } selected && selected.IsLocked!=true)
        {
            if(_objectHandle is { Kind:"endpoint" } endpoint)ObjectHandles.MoveEndpoint(selected,endpoint.Index,ConstrainLine(ObjectHandles.Endpoint(selected,1-endpoint.Index),world));
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
            else if(_lastWorld is not null)_session.PreviewMoveSelection(world.X-_lastWorld.X,world.Y-_lastWorld.Y);
            UpdateSelectionBarPosition();
        }
        else if(_shapeGesture&&_preview is not null && _start is not null)
        {
            UpdateShapePreview(world);
            ShowHUD(CanvasHUDFormatter.FormatDimensions(_preview.Width,_preview.Height),_mouse.X,_mouse.Y);
        }
        _lastScreen=_mouse;_lastWorld=world;InvalidateCanvas(_tool=="eraser"||(_tool=="select"&&!_marquee&&_session.Selected is not null));e.Handled=true;
    }
    private void Erase(InkPoint p)=>_session.Erase(p,EraserSizeSlider.Value/2,EraserModeBox.SelectedIndex==0);
    private void CanvasSurface_PointerReleased(object sender,PointerRoutedEventArgs e)
    {
        HideHUD();
        if(!_gesture||e.Pointer.PointerId!=_pointerId)return;
        if(_tool=="laser"){_laser.EndTrail();ResetGesture();CanvasSurface.ReleasePointerCaptures();return;}
        if(_tool=="lasso"){
            _session.SetSelection(_session.VisibleObjects.Where(o=>LassoSelection.Intersects(o,_lasso)).Select(o=>o.Id));
            _lasso.Clear();_tool="select";ResetGesture();CanvasSurface.ReleasePointerCaptures();RefreshEditor();return;
        }
        if(_marquee&&_start is not null)
        {
            var end=e.GetCurrentPoint(CanvasSurface).Position;CompleteWindowSelection(_viewport.ScreenToWorld(end.X,end.Y));
        }
        else if(_compassCenterMoving)
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
                if(_tool=="pen"&&_ink.IsStraight&&points.Count==2){o.Type="line";o.Points=null;ObjectHandles.SetEndpoints(o,points[0],points[1]);}
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
        if(_preview.Type is "line" or "arrow")ObjectHandles.SetEndpoints(_preview,_lineAnchor??_start,ConstrainLine(_lineAnchor??_start,world));
        else{_preview.X=Math.Min(_start.X,world.X);_preview.Y=Math.Min(_start.Y,world.Y);_preview.Width=Math.Max(1,Math.Abs(world.X-_start.X));_preview.Height=Math.Max(1,Math.Abs(world.Y-_start.Y));}
    }
    private static InkPoint ConstrainLine(InkPoint anchor,InkPoint point)=>KeyIsDown(VirtualKey.Shift)?ObjectHandles.ConstrainOrthogonal(anchor,point):point;
    private void ResetGesture(){HideHUD();_renderer.ResetLive();_gesture=_panning=_rulerMoving=_rulerRotating=_rulerPivotMoving=_shapeGesture=_lineCompleting=_marquee=false;_compassCenterMoving=_compassCenterMoved=_compassRadiusMoving=_compassPencilMoving=false;_objectHandle=null;_manipulationStart=null;_movingPin=null;_snapEdge=null;_ink.Projection=null;}
    private void CancelGesture(){var changed=_session.HasTransaction;_lasso.Clear();_laser.Clear();HideHUD();_ink.Cancel();_session.Cancel();_preview=null;_lineAnchor=null;_compass.Prepare();ResetGesture();CanvasSurface.ReleasePointerCaptures();if(changed)RefreshProperties();InvalidateCanvas(changed);}
    private void CanvasSurface_PointerCanceled(object sender,PointerRoutedEventArgs e){HideHUD();if(_gesture)CancelGesture();}
    private void CanvasSurface_PointerExited(object sender,PointerRoutedEventArgs e){HideHUD();_hover=false;InvalidateCanvas(false);}
    private void CanvasSurface_PointerWheelChanged(object sender,PointerRoutedEventArgs e)
    {
        if(_editor is not null||_gesture||_viewLocked)return;
        var p=e.GetCurrentPoint(CanvasSurface);
        if(p.Properties.IsHorizontalMouseWheel)_viewport.X+=p.Properties.MouseWheelDelta;
        else _viewport.ZoomAt(p.Position.X,p.Position.Y,p.Properties.MouseWheelDelta);
        ZoomText.Text=$"{_viewport.Zoom:P0}";RefreshProperties();InvalidateCanvas();e.Handled=true;
    }
    private void CanvasSurface_DoubleTapped(object sender,DoubleTappedRoutedEventArgs e)
    {var p=e.GetPosition(CanvasSurface);if(PinAt(new((float)p.X,(float)p.Y)) is { } pin){CancelGesture();StartPinRename(pin);e.Handled=true;return;}var o=_session.Hit(_viewport.ScreenToWorld(p.X,p.Y),6/_viewport.Zoom);if(o?.Type=="tape"&&o.IsLocked!=true){_session.Begin();o.IsRevealed=o.IsRevealed!=true;_session.Commit();RefreshEditor();e.Handled=true;}else if(o?.Type is "text" or "sticky" && o.IsLocked!=true){StartText(o);e.Handled=true;}}
    private bool _editingNew;
    private string? _editingBoard,_editingPage;
    private void StartText(BoardObject o,bool isNew=false)
    {
        FinishText();if(o.IsLocked==true)return;_editingObject=DocumentCodec.Clone(o);_editingNew=isNew;_editingBoard=_session.Document.Board.Id;_editingPage=_session.Document.Board.ActivePageId;var p=_viewport.WorldToScreen(o.X,o.Y);
        _editor=new TextDraftEditor{Text=o.Text??"",TextWrapping=TextWrapping.Wrap,Width=Math.Max(120,o.Width*_viewport.Zoom),Height=Math.Max(80,o.Height*_viewport.Zoom)};
        _editor.SyncStyle(_editingObject,_viewport.Zoom);var input=_editor;var draft=_editingObject;
        Canvas.SetLeft(input,p.X);Canvas.SetTop(input,p.Y);TextOverlay.IsHitTestVisible=true;TextOverlay.Children.Add(input);
        input.KeyDown+=(_,e)=>{var ctrl=Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control).HasFlag(global::Windows.UI.Core.CoreVirtualKeyStates.Down);
            if(e.Key==VirtualKey.Escape){FinishText(false);e.Handled=true;}else if(ctrl&&e.Key==VirtualKey.Enter){FinishText();e.Handled=true;}};
        input.ContextFlyout=null;input.RightTapped+=(_,args)=>{
            var menu=input.CreateTextMenu();bool Current()=>ReferenceEquals(_editingObject,draft)&&_editingBoard==_session.Document.Board.Id&&_editingPage==_session.Document.Board.ActivePageId;
            TextStyleMenu.Append(menu,new[]{draft},change=>{if(Current()){TextStyles.Apply(draft,change);input.SyncStyle(draft,_viewport.Zoom);}},flyout=>{flyout.ShouldConstrainToRootBounds=false;flyout.ShowAt(input);},Current,draft:true);
            menu.ShouldConstrainToRootBounds=false;menu.ShowAt(input,new Microsoft.UI.Xaml.Controls.Primitives.FlyoutShowOptions{Position=args.GetPosition(input)});args.Handled=true;
        };input.Focus(FocusState.Programmatic);
    }
    private void FinishText(bool commit=true)
    {
        FinishPinRename(commit);
        if(_editor is null||_editingObject is null)return;
        var input=_editor;var draft=_editingObject;var isNew=_editingNew;var scope=_editingBoard==_session.Document.Board.Id&&_editingPage==_session.Document.Board.ActivePageId;
        _editor=null;_editingObject=null;TextOverlay.Children.Clear();TextOverlay.IsHitTestVisible=false;
        if(commit&&scope&&(!isNew||!string.IsNullOrWhiteSpace(input.Text)))
        {
            var existing=isNew?null:_session.PageObjects.FirstOrDefault(o=>o.Id==draft.Id&&o.IsLocked!=true);
            if(isNew||existing is not null){if(draft.Text!=input.Text)draft.RichTextSpans=null;draft.Text=input.Text;TextStyles.GrowHeight(draft);_session.Begin();if(isNew)_session.Add(draft);else _session.Document.Objects[_session.Document.Objects.IndexOf(existing!)]=draft;_session.Commit();RefreshEditor();}
        }
        InvalidateCanvas();
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
        var pin=PinAt(screen);
        var hit=_session.Hit(_viewport.ScreenToWorld(screen.X,screen.Y),6/_viewport.Zoom);if(hit is null||!_session.SelectedIds.Contains(hit.Id))Select(hit);
        var menu=new MenuFlyout();void Add(string name,Action action){var item=new MenuFlyoutItem{Text=name};item.Click+=(_,_)=>action();menu.Items.Add(item);}
        if(pin is not null){Add("重新命名圖釘",()=>StartPinRename(pin));Add("圖釘與文字配色…",()=>PinAppearance(pin));Add("刪除圖釘",()=>{_session.Begin();_session.Document.Board.Pins!.Remove(pin);_session.Commit();RefreshEditor();});}
        if(_session.Selected is not null){Add("複製",CopySelected);Add("製作副本",DuplicateSelected);Add("刪除",()=>Delete_Click(this,new RoutedEventArgs()));
            var selection=_session.SelectedIds.ToHashSet();var board=_session.Document.Board.Id;bool Current()=>board==_session.Document.Board.Id&&_session.SelectedIds.SetEquals(selection);
            TextStyleMenu.Append(menu,_session.SelectedObjects.ToArray(),change=>{CommitPropertyEdit();if(Current()){TextStyles.ApplySelection(_session,change);RefreshEditor();}},flyout=>{flyout.ShouldConstrainToRootBounds=false;flyout.ShowAt(CanvasSurface,new Microsoft.UI.Xaml.Controls.Primitives.FlyoutShowOptions{Position=new Point(screen.X,screen.Y)});},Current,()=>{if(_session.SelectedObjects.FirstOrDefault(o=>o.Type is "text" or "sticky"&&o.IsLocked!=true) is { } text)StartText(text);});}
        Add("貼上",PasteObject);menu.OverlayInputPassThroughElement=ToolBorder;menu.ShowAt(CanvasSurface,new Microsoft.UI.Xaml.Controls.Primitives.FlyoutShowOptions{Position=new Point(screen.X,screen.Y)});
    }
    private void CopySelected()
    {if(_session.Selected is not { } o)return;var package=new DataPackage();package.SetText("HEIBAN_OBJECTS:"+JsonSerializer.Serialize(_session.SelectedObjects.ToArray(),DocumentCodec.Options));Clipboard.SetContent(package);}
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
            var objects=text.StartsWith("HEIBAN_OBJECTS:",StringComparison.Ordinal)?JsonSerializer.Deserialize<List<BoardObject>>(text[15..],DocumentCodec.Options):text.StartsWith("HEIBAN_OBJECT:",StringComparison.Ordinal)?new List<BoardObject>{JsonSerializer.Deserialize<BoardObject>(text[14..],DocumentCodec.Options)!}:null;
            if(objects is null||objects.Count==0||objects.Any(o=>o is null))return;
            ActivateTool("select");_session.Begin();var ids=new List<string>();
            foreach(var o in objects){o.Id=Guid.NewGuid().ToString();_session.Move(o,20,20);_session.Add(o);ids.Add(o.Id);}
            _session.SetSelection(ids);_session.Commit();
            await _renderer.LoadImagesAsync(CanvasSurface, _session.Document.Objects);
            RefreshEditor();
        }
        catch (Exception ex) { await Error(ex); }
    }
    private void DuplicateSelected()
    {var originals=_session.SelectedObjects.ToArray();if(originals.Length==0)return;_session.Begin();var ids=new List<string>();foreach(var selected in originals){var o=DocumentCodec.Clone(selected);o.Id=Guid.NewGuid().ToString();_session.Move(o,20,20);_session.Add(o);ids.Add(o.Id);}_session.SetSelection(ids);_session.Commit();RefreshEditor();}
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

                row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                var navContent = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                navContent.Children.Add(new Views.PinIcon(pin.Color));
                navContent.Children.Add(new TextBlock { Text = pin.Name, Foreground=Brush(pin.TextColor??"#397056"), VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis });
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
                renameBtn.Click += (_, _) => { dialog?.Hide(); StartPinRename(pin); };
                Grid.SetColumn(renameBtn, 1);
                row.Children.Add(renameBtn);

                var colorBtn=new Button{Content="配色",Margin=new Thickness(4,0,0,0),Padding=new Thickness(8,4,8,4)};
                colorBtn.Click+=(_,_)=>{dialog?.Hide();DispatcherQueue.TryEnqueue(()=>PinAppearance(pin));};Grid.SetColumn(colorBtn,2);row.Children.Add(colorBtn);
                var deleteBtn = new Button { Content = "刪除", Margin = new Thickness(4, 0, 0, 0), Padding = new Thickness(8, 4, 8, 4) };
                deleteBtn.Click += (_, _) =>
                {
                    _session.Begin();
                    _session.Document.Board.Pins?.Remove(pin);
                    _session.Commit();
                    RefreshEditor();
                    RenderPins();
                };
                Grid.SetColumn(deleteBtn, 3);
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
            Title = "圖釘",
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
}
