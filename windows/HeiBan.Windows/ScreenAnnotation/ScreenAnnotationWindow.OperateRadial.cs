using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private OperateRadialHook? _operateHook;
    private bool _operateWheel;
    private int _operateEpoch;
    private readonly object _operateQueueGate=new();
    private readonly Queue<(int Epoch,OperateRadialHook.Signal Signal)> _operateQueue=[];
    private (int Epoch,OperateRadialHook.Signal Signal)? _operateMove;
    private bool _operateUiQueued;
#if HEIBAN_RELEASE_VALIDATION
    private int _operateValidationTargetPid;
#endif
    internal void ApplyOperateRadialPreference(bool enabled){_toolbarPreferences.OperateRadialEnabled=enabled;SyncOperateRadial();}
    private void SyncOperateRadial()
    {
        if(!IsActive||_stopping||_regionDisplayChanged||_drawing||_captureCancellation is not null||!_toolbarPreferences.OperateRadialEnabled){StopOperateRadial();return;}
        if(_operateHook is not null)return;
        var epoch=++_operateEpoch;
        var hook=new OperateRadialHook(signal=>QueueOperateSignal(epoch,signal),error=>DispatcherQueue.TryEnqueue(()=>OperateHookFailed(epoch,error)),_region);
#if HEIBAN_RELEASE_VALIDATION
        hook.OnlyTargetProcessId=_operateValidationTargetPid;
#endif
        _operateHook=hook;hook.Enable();_ = ObserveOperateReadyAsync(hook,epoch);
    }
    private async Task ObserveOperateReadyAsync(OperateRadialHook hook,int epoch)
    {try{await hook.Ready;}catch(Exception error){if(ReferenceEquals(_operateHook,hook))OperateHookFailed(epoch,error);}}
    private void OperateHookFailed(int epoch,Exception error)
    {
        if(epoch!=_operateEpoch)return;StopOperateRadial();
        _status.Text=T("右鍵輪盤暫時無法使用：")+$"0x{error.HResult:X8}";
    }
    private void QueueOperateSignal(int epoch,OperateRadialHook.Signal signal)
    {
        lock(_operateQueueGate)
        {
            if(signal.Kind=="move")_operateMove=(epoch,signal);
            else
            {
                if(_operateMove is { } pending){_operateQueue.Enqueue(pending);_operateMove=null;}
                _operateQueue.Enqueue((epoch,signal));
            }
            if(_operateUiQueued)return;_operateUiQueued=true;
            if(!DispatcherQueue.TryEnqueue(DrainOperateSignals)){_operateUiQueued=false;_operateQueue.Clear();_operateMove=null;}
        }
    }
    private void DrainOperateSignals()
    {
        List<(int Epoch,OperateRadialHook.Signal Signal)> items=[];
        lock(_operateQueueGate)
        {
            while(_operateQueue.TryDequeue(out var item))items.Add(item);
            if(_operateMove is { } pending){items.Add(pending);_operateMove=null;}_operateUiQueued=false;
        }
        foreach(var item in items)if(item.Epoch==_operateEpoch&&_operateHook is not null&&IsActive&&!_stopping&&!_drawing&&_captureCancellation is null)HandleOperateSignal(item.Signal);
    }
    private void HandleOperateSignal(OperateRadialHook.Signal signal)
    {
        var point=new InkPoint(signal.X-_overlay.Left,signal.Y-_overlay.Top);
        if(signal.Kind=="start")
        {
            _rightClickTimer.Stop();_pendingRightClick=null;_chromeFlyout?.Hide();_operateWheel=true;_radialScale=ScreenWheelScale(Math.Clamp(signal.Scale,1,8));
            _radialGesture.Press(new(signal.OriginX-_overlay.Left,signal.OriginY-_overlay.Top),Now-RadialGesture.HoldSeconds,_overlay.Width,_overlay.Height,_radialScale);
            _radialGesture.Poll(Now);_radialGesture.Move(point,Now,_radialScale);DamageRadial();
        }
        else if(signal.Kind=="cancel")CancelRadial();
        else if(_operateWheel&&_radialGesture.Holding)
        {
            if(signal.Kind=="move")HandleRadialInput(new("move",point.X,point.Y),point);
            else if(signal.Kind=="finish"){HandleRadialInput(new("rightup",point.X,point.Y),point);if(_drawing)FocusScreenChrome();}
        }
    }
    private void StopOperateRadial()
    {
        ++_operateEpoch;var hook=_operateHook;_operateHook=null;hook?.Dispose();
        lock(_operateQueueGate){_operateQueue.Clear();_operateMove=null;}
        if(_operateWheel){_operateWheel=false;CancelRadial();}
    }
}
