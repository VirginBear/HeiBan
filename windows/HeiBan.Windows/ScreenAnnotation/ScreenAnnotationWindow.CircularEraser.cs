using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Diagnostics;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private CircularEraserGesture? _circularEraser;
    private Task? _circularEraserCompletion;
    private bool HandleCircularEraser(NativeOverlayWindow.PointerEvent input,InkPoint point)
    {
        if(_circularEraser is { } active)
        {
            if(!active.IsFinishing&&input.Kind is "move" or "up")
            {using var trace=InputLatencyTrace.Measure(InputStage.EraserMove);active.Queue(point);PumpCircularEraser();if(input.Kind=="up")_ = CompleteCircularEraserAsync();}
            return true;
        }
        if(_tool!="eraser"||input.Kind!="down")return false;
        FinishScreenText();CancelGesture();_session.SelectedId=null;_start=_last=point;
        _circularEraserCompletion=null;
        var gesture=_circularEraser=new(_session,_eraserSize*_dpiScale/2,_eraserWhole);
        gesture.PreviewChanged+=()=>{if(ReferenceEquals(_circularEraser,gesture)){_dirty=_fullDamage=_committedDirty=true;}};
        gesture.Queue(point);PumpCircularEraser();return true;
    }
    private async void PumpCircularEraser()
    {
        var gesture=_circularEraser;if(gesture is null)return;
        try{await gesture.PumpAsync();}
        catch(Exception error){if(ReferenceEquals(_circularEraser,gesture)){CancelCircularEraser();_status.Text=Localization.Strings.T("繪圖未完成：")+error.Message;}}
    }
    private Task CompleteCircularEraserAsync()=>_circularEraserCompletion??=CompleteCircularEraserCoreAsync();
    private async Task CompleteCircularEraserCoreAsync()
    {
        var gesture=_circularEraser;if(gesture is null)return;
        try
        {
            var snapshot=await gesture.CompleteAsync();
            if(ReferenceEquals(_circularEraser,gesture)&&snapshot is not null&&gesture.Matches(_session))
            {using var trace=InputLatencyTrace.Measure(InputStage.EraserCommit);_session.Begin();_session.Document.Objects=snapshot.Objects;_session.Commit();}
        }
        catch(Exception error){gesture.Cancel();_status.Text=Localization.Strings.T("繪圖未完成：")+error.Message;}
        finally{if(ReferenceEquals(_circularEraser,gesture)){_circularEraser=null;_start=_last=null;Changed();}}
    }
    private void CancelCircularEraser()
    {
        var gesture=_circularEraser;if(gesture is null)return;
        _circularEraser=null;gesture.Cancel();_start=_last=null;_dirty=_fullDamage=_committedDirty=true;
    }
}
