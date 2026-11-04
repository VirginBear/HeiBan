using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using HeiBan.Windows.Engine;
namespace HeiBan.Windows.ScreenAnnotation;

// Only installed for an active screen session in operate mode. This thread never
// touches XAML, waits on the UI, renders, or records unrelated desktop input.
internal sealed class OperateRadialHook : IDisposable
{
    internal readonly record struct Signal(string Kind,double OriginX,double OriginY,double X,double Y,double Scale);
    private const uint StopMessage=0x8001,CancelMessage=0x8002;
    private const nuint ReplayTag=0x48424952;
    private readonly Thread _thread;
    private readonly HookProc _callback;
    private readonly OperateRightGesture _gesture=new();
    private readonly Action<Signal> _publish;
    private readonly Action<Exception> _failed;
    private readonly TaskCompletionSource _ready=new(TaskCreationOptions.RunContinuationsAsynchronously);
    private readonly int _ownPid=Environment.ProcessId;
    private uint _threadId,_ownIntegrity;
    private nuint _timer;
    private volatile bool _enabled;
    private nint _hook,_target;
    private volatile bool _disposed;
    private bool _stop;
    private double _scale=1;
    private double _drainUntil;
    private bool _dropOwnDown;
    private readonly TaskCompletionSource _stopped=new(TaskCreationOptions.RunContinuationsAsynchronously);
    internal Task Stopped=>_stopped.Task;
    internal Task Ready=>_ready.Task;
    internal long InterceptedClicks,ReplayedClicks,StartedWheels;
#if HEIBAN_RELEASE_VALIDATION
    internal int OnlyTargetProcessId;
#endif
    internal OperateRadialHook(Action<Signal> publish,Action<Exception> failed)
    {
        _publish=publish;_failed=failed;_callback=Callback;
        _thread=new Thread(Run){IsBackground=true,Name="HeiBan operate right gesture"};_thread.Start();
    }
    private static double Now=>Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency;
    private void Run()
    {
        try
        {
            _threadId=GetCurrentThreadId();PeekMessage(out _,0,0,0,0);
            if(_disposed){_ready.TrySetCanceled();return;}
            _ownIntegrity=Integrity(GetCurrentProcess());if(_ownIntegrity==0)throw new InvalidOperationException("Cannot verify input integrity boundary");
            _hook=SetWindowsHookEx(14,_callback,GetModuleHandle(null),0);
            if(_hook==0)throw new Win32Exception(Marshal.GetLastWin32Error());
            _ready.TrySetResult();
            while(GetMessage(out var msg,0,0,0)>0)
            {
                if(msg.Id==StopMessage){_stop=true;_gesture.Cancel();}
                else if(msg.Id==CancelMessage)_gesture.Cancel();
                else if(msg.Id==0x0113)
                {
                    if(!_stop&&(GetAsyncKeyState(0x1B)&0x8000)!=0&&_gesture.Phase is OperateRightGesture.State.Pending or OperateRightGesture.State.Wheel){_gesture.Cancel();Emit("cancel");}
                    if(!_stop&&_gesture.Poll(Now)==OperateRightAction.WheelStarted)Emit("start");
                    // Secure-desktop switches can hide a release. Drain ownership,
                    // but never keep the hook installed indefinitely after disabling.
                    if(_gesture.Phase==OperateRightGesture.State.Cancelled&&(GetAsyncKeyState(2)&0x8000)==0)_gesture.Release(_gesture.X,_gesture.Y,Now);
                }
                if(_stop&&!_gesture.OwnsRelease&&Now>=_drainUntil)break;
            }
        }
        catch(Exception error){_ready.TrySetException(error);if(!_disposed)_failed(error);}
        finally{if(_timer!=0)KillTimer(0,_timer);if(_hook!=0)UnhookWindowsHookEx(_hook);_hook=0;_stopped.TrySetResult();}
    }
    private nint Callback(int code,nuint message,nint data)
    {
        if(code<0)return CallNextHookEx(_hook,code,message,data);
        try
        {
            if(message is 0x0201 or 0x0207 or 0x020A&&_gesture.OwnsRelease){_gesture.Cancel();Emit("cancel");}
            if(message is not(0x0200 or 0x0204 or 0x0205))return CallNextHookEx(_hook,code,message,data);
            if(message==0x0200&&_gesture.Phase is OperateRightGesture.State.Idle or OperateRightGesture.State.Dragging or OperateRightGesture.State.Cancelled)return CallNextHookEx(_hook,code,message,data);
            var input=Marshal.PtrToStructure<MouseInput>(data);
            if(input.ExtraInfo==ReplayTag)return _dropOwnDown&&message==0x0204?1:CallNextHookEx(_hook,code,message,data);
            if(message==0x0204)
            {
                if(_gesture.Phase!=OperateRightGesture.State.Idle)return _gesture.OwnsRelease?1:CallNextHookEx(_hook,code,message,data);
                if(!_enabled||_disposed||_stop||!Eligible(input.Point,out _target))return CallNextHookEx(_hook,code,message,data);
                _scale=Math.Max(1,GetDpiForWindow(_target)/96d);_gesture.Press(input.Point.X,input.Point.Y,Now,_scale);Interlocked.Increment(ref InterceptedClicks);
                if(_timer==0)_timer=SetTimer(0,0,12,0);
                if(_timer==0){_gesture.Release(input.Point.X,input.Point.Y,Now);throw new Win32Exception(Marshal.GetLastWin32Error());}
                return 1;
            }
            if(message==0x0200&&_gesture.Phase!=OperateRightGesture.State.Idle)
            {
                var action=_gesture.Move(input.Point.X,input.Point.Y,Now);
                if(action==OperateRightAction.ReplayDown){if(SameTarget(input.Point)){Replay(false);if(_timer!=0){KillTimer(0,_timer);_timer=0;}}else _gesture.Cancel(true);}
                else if(action==OperateRightAction.WheelStarted)Emit("start");
                else if(action==OperateRightAction.WheelMoved)Emit("move");
            }
            else if(message==0x0205&&_gesture.Phase!=OperateRightGesture.State.Idle)
            {
                var owned=_gesture.OwnsRelease;var wasPending=_gesture.Phase==OperateRightGesture.State.Pending;
                var action=_gesture.Release(input.Point.X,input.Point.Y,Now);
                if(action==OperateRightAction.ReplayClick&&SameTarget(input.Point))Replay(true);
                else if(action==OperateRightAction.WheelFinished){if(wasPending)Emit("start");Emit("finish");}
                if(_timer!=0&&Now>=_drainUntil){KillTimer(0,_timer);_timer=0;}
                if(_stop)PostThreadMessage(_threadId,StopMessage,0,0);
                if(owned)return 1;
            }
        }
        catch(Exception error){_gesture.Cancel();if(!_disposed)_failed(error);}
        return CallNextHookEx(_hook,code,message,data);
    }
    private void Emit(string kind)
    {
        if(_disposed)return;if(kind=="start")Interlocked.Increment(ref StartedWheels);
        _publish(new(kind,_gesture.OriginX,_gesture.OriginY,_gesture.X,_gesture.Y,_scale));
    }
    private bool Eligible(Point point,out nint target)
    {
        target=GetAncestor(WindowFromPoint(point),2);if(target==0)return false;
        GetWindowThreadProcessId(target,out var pid);if(pid==0||pid==_ownPid)return false;
#if HEIBAN_RELEASE_VALIDATION
        if(OnlyTargetProcessId!=0&&pid!=OnlyTargetProcessId)return false;
#endif
        foreach(var key in new[]{1,4,0x10,0x11,0x12,0x1B,0x5B,0x5C})if((GetAsyncKeyState(key)&0x8000)!=0)return false;
        var process=OpenProcess(0x1000,false,pid);if(process==0)return false;
        try{var integrity=Integrity(process);return integrity!=0&&integrity<=_ownIntegrity;}
        finally{CloseHandle(process);}
    }
    private bool SameTarget(Point point)=>GetAncestor(WindowFromPoint(point),2)==_target;
    private void Replay(bool complete)
    {
        var inputs=complete?new[]{RightInput(0x0008),RightInput(0x0010)}:new[]{RightInput(0x0008)};
        var sent=SendInput((uint)inputs.Length,inputs,Marshal.SizeOf<Input>());
        var replayError=Marshal.GetLastWin32Error();
        if(sent!=(uint)inputs.Length)
        {
            // A partial pair must not leave an injected down unmatched. Keep the
            // hook briefly to discard a queued unmatched down if repair fails.
            if(complete&&sent==1&&SendInput(1,new[]{RightInput(0x0010)},Marshal.SizeOf<Input>())!=1)_dropOwnDown=true;
            _stop=true;_gesture.Cancel(true);_drainUntil=Now+.1;
            if(_timer==0)_timer=SetTimer(0,0,12,0);
            _failed(new Win32Exception(replayError));PostThreadMessage(_threadId,StopMessage,0,0);
        }
        else if(complete)Interlocked.Increment(ref ReplayedClicks);
    }
    private static Input RightInput(uint flags)=>new(){Type=0,Mouse=new(){Flags=flags,ExtraInfo=ReplayTag}};
    internal void Enable()=>_enabled=true;
    internal void Cancel()=>PostThreadMessage(_threadId,CancelMessage,0,0);
    public void Dispose(){_disposed=true;PostThreadMessage(_threadId,StopMessage,0,0);}
    private static uint Integrity(nint process)
    {
        if(!OpenProcessToken(process,8,out var token))return 0;
        nint buffer=0;
        try
        {
            GetTokenInformation(token,25,0,0,out var size);if(size<16)return 0;
            buffer=Marshal.AllocHGlobal((int)size);if(!GetTokenInformation(token,25,buffer,size,out _))return 0;
            var sid=Marshal.ReadIntPtr(buffer);var offset=sid.ToInt64()-buffer.ToInt64();
            if(offset<0||offset+8>size)return 0;var count=Marshal.ReadByte(sid,1);
            if(count is 0 or >15||offset+8+count*4>size)return 0;
            return unchecked((uint)Marshal.ReadInt32(sid,8+(count-1)*4));
        }
        finally{if(buffer!=0)Marshal.FreeHGlobal(buffer);CloseHandle(token);}
    }
    private delegate nint HookProc(int code,nuint message,nint data);
    [StructLayout(LayoutKind.Sequential)] private struct Point{public int X,Y;}
    [StructLayout(LayoutKind.Sequential)] private struct MouseInput{public Point Point;public uint MouseData,Flags,Time;public nuint ExtraInfo;}
    [StructLayout(LayoutKind.Sequential)] private struct NativeMessage{public nint Hwnd;public uint Id;public nuint WParam;public nint LParam;public uint Time;public Point Point;public uint Private;}
    [StructLayout(LayoutKind.Explicit)] private struct Input{[FieldOffset(0)]public uint Type;[FieldOffset(8)]public MousePayload Mouse;}
    [StructLayout(LayoutKind.Sequential)] private struct MousePayload{public int X,Y;public uint Data,Flags,Time;public nuint ExtraInfo;}
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)]private static extern nint SetWindowsHookEx(int id,HookProc callback,nint module,uint thread);
    [DllImport("user32.dll")]private static extern bool UnhookWindowsHookEx(nint hook);
    [DllImport("user32.dll")]private static extern nint CallNextHookEx(nint hook,int code,nuint message,nint data);
    [DllImport("user32.dll")]private static extern int GetMessage(out NativeMessage msg,nint window,uint min,uint max);
    [DllImport("user32.dll")]private static extern bool PeekMessage(out NativeMessage msg,nint window,uint min,uint max,uint remove);
    [DllImport("user32.dll")]private static extern bool PostThreadMessage(uint thread,uint message,nuint w,nint l);
    [DllImport("user32.dll",SetLastError=true)]private static extern nuint SetTimer(nint window,nuint id,uint interval,nint callback);
    [DllImport("user32.dll")]private static extern bool KillTimer(nint window,nuint id);
    [DllImport("user32.dll")]private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")]private static extern nint WindowFromPoint(Point point);
    [DllImport("user32.dll")]private static extern nint GetAncestor(nint window,uint flags);
    [DllImport("user32.dll")]private static extern uint GetWindowThreadProcessId(nint window,out int process);
    [DllImport("user32.dll")]private static extern uint GetDpiForWindow(nint window);
    [DllImport("user32.dll",SetLastError=true)]private static extern uint SendInput(uint count,Input[] inputs,int size);
    [DllImport("kernel32.dll")]private static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]private static extern nint GetModuleHandle(string? name);
    [DllImport("kernel32.dll")]private static extern nint GetCurrentProcess();
    [DllImport("kernel32.dll")]private static extern nint OpenProcess(uint access,bool inherit,int pid);
    [DllImport("kernel32.dll")]private static extern bool CloseHandle(nint handle);
    [DllImport("advapi32.dll",SetLastError=true)]private static extern bool OpenProcessToken(nint process,uint access,out nint token);
    [DllImport("advapi32.dll",SetLastError=true)]private static extern bool GetTokenInformation(nint token,int type,nint data,uint size,out uint required);
}
