#if HEIBAN_RELEASE_VALIDATION
using System.Text.Json;
using HeiBan.Windows.Engine;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    internal async Task ValidateOperateRadialAsync(string output,int targetPid)
    {
        Directory.CreateDirectory(output);_operateValidationTargetPid=targetPid;await StartAsync();var checks=0;
        void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        try
        {
            var draft=DocumentCodec.Clone(_toolbarPreferences);draft.OperateRadialEnabled=true;await _owner.SaveToolbarPreferencesAsync(draft);
            SetDrawing(false);var first=_operateHook??throw new Exception("No operate hook");await first.Ready.WaitAsync(TimeSpan.FromSeconds(5));
            Check(!_drawing&&_operateHook is not null,"Operate mode did not install native bridge");
            var generation=_session.Generation;
            var x=_overlay.Left+Math.Min(800,_overlay.Width/2);var y=_overlay.Top+Math.Min(500,_overlay.Height/2);
            HandleOperateSignal(new("start",x,y,x,y,1));Check(_radialGesture.Visible&&_operateWheel&&!_drawing,"Hook signal did not open wheel in operate mode");
            var slot=RadialProfile.Slots.FindIndex(k=>k=="operate");var point=RadialGesture.SlotCenter(slot,_radialGesture.Center,_radialScale);
            HandleOperateSignal(new("move",x,y,point.X+_overlay.Left,point.Y+_overlay.Top,1));
            Check(_radialGesture.Hover==slot,"Operate wheel hover mapped to wrong coordinates");
            HandleOperateSignal(new("finish",x,y,point.X+_overlay.Left,point.Y+_overlay.Top,1));
            Check(_drawing&&!_radialGesture.Holding&&_operateHook is null,"Return-to-draw slot did not switch modes/release hook");await first.Stopped.WaitAsync(TimeSpan.FromSeconds(5));
            SetDrawing(false);await _operateHook!.Ready.WaitAsync(TimeSpan.FromSeconds(5));
            HandleOperateSignal(new("start",x,y,x,y,1));
            for(var i=0;i<500;i++)QueueOperateSignal(_operateEpoch,new("move",x,y,x+100,y+20,1));
            lock(_operateQueueGate)Check(_operateQueue.Count==0&&_operateMove is not null&&_operateUiQueued,"Move samples were queued individually instead of coalesced");
            await Task.Delay(50);Check(_radialGesture.Hover>=0,"Coalesced latest move was not delivered");
            HandleOperateSignal(new("cancel",x,y,x,y,1));Check(!_operateWheel&&!_radialGesture.Holding&&!_drawing,"Cancel changed mode or left wheel visible");
            draft=DocumentCodec.Clone(_toolbarPreferences);draft.OperateRadialEnabled=false;await _owner.SaveToolbarPreferencesAsync(draft);Check(_operateHook is null,"Opt-out kept hook alive");
            Check(!ToolbarPreferencesStore.Load(Path.GetDirectoryName(Path.GetDirectoryName(_recoveryPath))!).OperateRadialEnabled,"Opt-out not persisted");
            draft.OperateRadialEnabled=true;await _owner.SaveToolbarPreferencesAsync(draft);await _operateHook!.Ready.WaitAsync(TimeSpan.FromSeconds(5));
            HandleOperateSignal(new("start",x,y,x,y,1));
            var toolSlot=RadialProfile.Slots.FindIndex(k=>RadialToolProfile.IsTool(k)&&k!="cane");var tool=RadialProfile.Slots[toolSlot];point=RadialGesture.SlotCenter(toolSlot,_radialGesture.Center,_radialScale);
            HandleOperateSignal(new("move",x,y,point.X+_overlay.Left,point.Y+_overlay.Top,1));HandleOperateSignal(new("finish",x,y,point.X+_overlay.Left,point.Y+_overlay.Top,1));
            Check(_drawing&&_tool==tool,"Selecting tool from operate wheel failed to enter drawing");
            Check(_session.Generation==generation,"Mode/wheel changes edited annotations");
            SetDrawing(false);await _operateHook!.Ready.WaitAsync(TimeSpan.FromSeconds(5));Title="HeiBan operate radial QA";
            await File.WriteAllTextAsync(Path.Combine(output,"result.json"),JsonSerializer.Serialize(new{success=true,checks,signalsAreSynthetic=true,physicalLongPressNotTested=true,coalescedMoveSamples=500,nativeHookReady=true,targetProcess=targetPid}));
            var previous="";var timer=new Microsoft.UI.Xaml.DispatcherTimer{Interval=TimeSpan.FromMilliseconds(100)};
            timer.Tick+=(_,_)=>{var h=_operateHook;var state=JsonSerializer.Serialize(new{drawing=_drawing,wheel=_radialGesture.Visible,hover=_radialGesture.Hover,intercepted=h is null?0:Interlocked.Read(ref h.InterceptedClicks),replayed=h is null?0:Interlocked.Read(ref h.ReplayedClicks),started=h is null?0:Interlocked.Read(ref h.StartedWheels)});if(state!=previous){previous=state;File.WriteAllText(Path.Combine(output,"live.json"),state);}};timer.Start();Closed+=(_,_)=>timer.Stop();
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"error.txt"),error.ToString());await StopAsync();}
    }
}
#endif
