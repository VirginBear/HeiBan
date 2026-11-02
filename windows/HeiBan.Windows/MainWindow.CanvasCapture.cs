using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.Foundation;
using global::Windows.Storage.Streams;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private sealed record CanvasCaptureContext(long Epoch,string? Page);
    private CanvasCaptureContext? _canvasCapture;
    private InkPoint? _canvasCaptureStart,_canvasCaptureEnd;
    private bool _canvasCaptureBusy;
#if HEIBAN_RELEASE_VALIDATION
    private string? _lastCanvasCaptureToken;
    private uint _lastCanvasClipboardSequence;
#endif
    private DispatcherTimer? _canvasCaptureToastTimer;
    private void ShowCanvasCapturedNotice()
    {
        if(_canvasCaptureToastTimer is null)
        {
            _canvasCaptureToastTimer=new DispatcherTimer{Interval=TimeSpan.FromSeconds(2)};
            _canvasCaptureToastTimer.Tick+=(_,_)=>{_canvasCaptureToastTimer.Stop();CanvasCaptureToast.Visibility=Visibility.Collapsed;};
        }
        _canvasCaptureToastTimer.Stop();CanvasCaptureToastText.Text=T("畫布已截圖");
        CanvasCaptureToast.Visibility=Visibility.Visible;_canvasCaptureToastTimer.Start();
    }
    private bool CurrentCanvasCapture(CanvasCaptureContext context)=>_workspaceOpen&&_session.DocumentEpoch==context.Epoch&&_session.Document.Board.ActivePageId==context.Page;

    private async void CanvasCapture_Click(object sender,RoutedEventArgs e)
    {
        if(!_workspaceOpen||_canvasCaptureBusy)return;
        if(_canvasCapture is not null){CancelGesture();StatusText.Text=T("已取消截圖");return;}
        var context=new CanvasCaptureContext(_session.DocumentEpoch,_session.Document.Board.ActivePageId);
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        if(_boardEraserFinishing)await CompleteBoardEraserAsync();
        if(!CurrentCanvasCapture(context))return;
        FinishText();FinishPinRename();CommitPropertyEdit();CancelGesture();_activeFlyout?.Hide();
        if(CanvasCapturePlan.WholePage(_session.Document.Board) is { } page){await CopyCanvasAreaAsync(page,context);return;}
        _canvasCapture=context;UpdateShapeCursor();FocusCanvasSurface();
        StatusText.Text=T("拖曳框選畫布範圍，放開後複製圖片；Esc 或右鍵取消");
        InvalidateCanvas(false);
    }

    private bool BeginCanvasCapture(PointerRoutedEventArgs e)
    {
        if(_canvasCapture is not { } context)return false;
        if(!CurrentCanvasCapture(context)){CancelGesture();e.Handled=true;return true;}
        var point=e.GetCurrentPoint(CanvasSurface);
        if(point.Properties.IsRightButtonPressed){CancelGesture();StatusText.Text=T("已取消截圖");e.Handled=true;return true;}
        if(point.Properties.IsLeftButtonPressed)
        {
            _pointerId=point.PointerId;_gesture=true;
            _canvasCaptureStart=_canvasCaptureEnd=_viewport.ScreenToWorld(point.Position.X,point.Position.Y);
            CanvasSurface.CapturePointer(e.Pointer);PresentInteraction();
        }
        e.Handled=true;return true;
    }

    private bool MoveCanvasCapture(PointerRoutedEventArgs e)
    {
        if(_canvasCapture is not { } context)return false;
        if(!CurrentCanvasCapture(context)){CancelGesture();e.Handled=true;return true;}
        var point=e.GetCurrentPoint(CanvasSurface);
        if(_gesture&&point.PointerId==_pointerId&&_canvasCaptureStart is not null)
        {_canvasCaptureEnd=_viewport.ScreenToWorld(point.Position.X,point.Position.Y);PresentInteraction();}
        e.Handled=true;return true;
    }

    private async Task EndCanvasCaptureAsync(PointerRoutedEventArgs e)
    {
        e.Handled=true;
        if(!_gesture||e.Pointer.PointerId!=_pointerId||_canvasCapture is not { } context||_canvasCaptureStart is not { } start)return;
        var point=e.GetCurrentPoint(CanvasSurface);var end=_viewport.ScreenToWorld(point.Position.X,point.Position.Y);
        var area=CanvasCapturePlan.Drag(start,end,_viewport.Zoom);
        if(area is not null)ClearCanvasCapture();
        else _canvasCaptureStart=_canvasCaptureEnd=null;
        ResetGesture();CanvasSurface.ReleasePointerCaptures();InvalidateCanvas(false);
        if(area is null){StatusText.Text=T("截圖範圍太小，請重新框選。");return;}
        await CopyCanvasAreaAsync(area,context);
    }
    private void ClearCanvasCapture(){_canvasCapture=null;_canvasCaptureStart=_canvasCaptureEnd=null;}

    private void DrawCanvasCaptureFrame(CanvasDrawingSession ds,float width,float height)
    {
        if(_canvasCaptureStart is not { } start||_canvasCaptureEnd is not { } end)return;
        var a=_viewport.WorldToScreen(start.X,start.Y);var b=_viewport.WorldToScreen(end.X,end.Y);
        var x=Math.Clamp(Math.Min(a.X,b.X),0,width);var y=Math.Clamp(Math.Min(a.Y,b.Y),0,height);
        var right=Math.Clamp(Math.Max(a.X,b.X),0,width);var bottom=Math.Clamp(Math.Max(a.Y,b.Y),0,height);
        var shade=Microsoft.UI.ColorHelper.FromArgb(80,0,0,0);
        ds.FillRectangle(0,0,width,(float)y,shade);ds.FillRectangle(0,(float)bottom,width,(float)(height-bottom),shade);
        ds.FillRectangle(0,(float)y,(float)x,(float)(bottom-y),shade);ds.FillRectangle((float)right,(float)y,(float)(width-right),(float)(bottom-y),shade);
        ds.DrawRectangle(new Rect(x,y,right-x,bottom-y),Direct2DCanvasRenderer.HexToColor("#4FADDE"),2);
    }

    private async Task<CanvasCapturePlan?> CopyCanvasAreaAsync(ExportArea area,CanvasCaptureContext context)
    {
        if(_canvasCaptureBusy||!CurrentCanvasCapture(context))return null;
        _canvasCaptureBusy=true;
        try
        {
            // Freeze only the active page once, after the gesture. No document work
            // or bitmap readback belongs in PointerMoved.
            var board=DocumentCodec.Clone(_session.Document.Board);
            var objects=_session.VisibleObjects.Select(DocumentCodec.Clone).ToArray();
            var image=await RenderCanvasImageAsync(board,objects,area);var plan=image.Plan;
            using var target=image.Bitmap;
            using var stream=new InMemoryRandomAccessStream();await target.SaveAsync(stream,CanvasBitmapFileFormat.Png);stream.Seek(0);
            if(!CurrentCanvasCapture(context))return null;
            var package=new DataPackage{RequestedOperation=DataPackageOperation.Copy};
            package.SetBitmap(RandomAccessStreamReference.CreateFromStream(stream));
#if HEIBAN_RELEASE_VALIDATION
            var token=Guid.NewGuid().ToString("N");
#endif
            Clipboard.SetContent(package);Clipboard.Flush();ShowCanvasCapturedNotice();
#if HEIBAN_RELEASE_VALIDATION
            _lastCanvasCaptureToken=token;_lastCanvasClipboardSequence=GetCanvasClipboardSequence();
#endif
            StatusText.Text=F($"已複製畫布圖片（{plan.PixelWidth} × {plan.PixelHeight}），可直接貼上。");
            return plan;
        }
        catch(Exception error){StatusText.Text=T("畫布截圖未完成：")+error.Message;return null;}
        finally{_canvasCaptureBusy=false;}
    }
    private async Task<(CanvasRenderTarget Bitmap,CanvasCapturePlan Plan)> RenderCanvasImageAsync(BoardMetadata board,IReadOnlyList<BoardObject> objects,ExportArea area)
    {
        var plan=CanvasCapturePlan.Create(area,Math.Min(16384,CanvasSurface.Device.MaximumBitmapSizeInPixels));
        var vp=new ViewportTransform{X=-area.X*plan.Scale,Y=-area.Y*plan.Scale,Zoom=plan.Scale};
        using var renderer=new Direct2DCanvasRenderer();
        var target=new CanvasRenderTarget(CanvasSurface,plan.PixelWidth,plan.PixelHeight,96);
        try
        {
            await renderer.LoadImagesAsync(target,objects);
            using(var ds=target.CreateDrawingSession())
            {renderer.RenderBackground(ds,board,vp,plan.PixelWidth,plan.PixelHeight);renderer.RenderObjects(ds,objects,vp,plan.PixelWidth,plan.PixelHeight);}
            return(target,plan);
        }
        catch{target.Dispose();throw;}
    }

}
