using System.Runtime.InteropServices;
using HeiBan.Windows.Diagnostics;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using global::Windows.Foundation;
using global::Windows.UI;

namespace HeiBan.Windows.Views;

public sealed class ImmediateCanvasResourcesEventArgs : EventArgs
{
    private readonly List<Task> _pending=[];
    public void TrackAsyncAction(IAsyncAction action)=>_pending.Add(action.AsTask());
    internal Task Completion=>Task.WhenAll(_pending);
}

/// <summary>
/// One UI-owned swap chain, with the same renderer and pointer coordinate space
/// as the former CanvasControl. Active ink can submit before returning from its
/// input callback, without waiting for XAML's CanvasImageSource update. This is
/// not an independent input thread and Present completion is not display time.
/// </summary>
public sealed class ImmediateCanvas : Grid, ICanvasResourceCreatorWithDpi
{
    private CanvasDevice? _device;
    private CanvasSwapChainPanel? _panel;
    private CanvasSwapChain? _swapChain;
    private CanvasControl? _fallback;
    private XamlRoot? _root;
    private bool _ready,_pending,_queued,_drawing,_disposed;
    private int _epoch;
    private double _width,_height;
    private float _dpi;
    private bool _useFallback=string.Equals(Environment.GetEnvironmentVariable("HEIBAN_RENDER_PATH"),"xaml",StringComparison.OrdinalIgnoreCase);
    private DispatcherQueueTimer? _frameTimer;
    private long _lastPresent;
    // Bound GPU work for 1000 Hz mice without dropping collected stroke points.
    // This is a maximum submission rate, not a claimed display refresh rate.
    private const double MinimumFrameMilliseconds=1000d/240;
    public event Action<ImmediateCanvas,ImmediateCanvasResourcesEventArgs>? CreateResources;
    public event Action<ImmediateCanvas,CanvasDrawingSession>? Draw;
    public CanvasDevice Device=>_fallback?.Device??(_device??=CanvasDevice.GetSharedDevice());
    public float Dpi=>_fallback?.Dpi??(float)(96*(XamlRoot?.RasterizationScale??1));
    public float ConvertPixelsToDips(int pixels)=>pixels*96f/Dpi;
    public int ConvertDipsToPixels(float dips,CanvasDpiRounding rounding)=>rounding switch
    {
        CanvasDpiRounding.Floor=>(int)Math.Floor(dips*Dpi/96),
        CanvasDpiRounding.Ceiling=>(int)Math.Ceiling(dips*Dpi/96),
        _=>(int)Math.Round(dips*Dpi/96,MidpointRounding.AwayFromZero)
    };

    public ImmediateCanvas()
    {
        Background=new SolidColorBrush(Color.FromArgb(0,0,0,0));
        Loaded+=OnLoaded;
        Unloaded+=(_,_)=>ReleaseSurface();
        SizeChanged+=(_,_)=>Invalidate();
    }

    private void OnLoaded(object sender,RoutedEventArgs e)
    {
        if(_disposed)return;
        _root=XamlRoot;
        if(_root is not null)_root.Changed+=RootChanged;
        if(_useFallback)InstallFallback();
        else _=InitializeSurfaceAsync();
    }
    private void RootChanged(XamlRoot sender,XamlRootChangedEventArgs args)=>Invalidate();

    private async Task InitializeSurfaceAsync()
    {
        var epoch=++_epoch;
        try
        {
            _device=CanvasDevice.GetSharedDevice();
            _panel=new CanvasSwapChainPanel{IsHitTestVisible=false};
            Children.Add(_panel);
            var resources=new ImmediateCanvasResourcesEventArgs();
            CreateResources?.Invoke(this,resources);
            await resources.Completion;
            if(epoch!=_epoch||_disposed||!IsLoaded)return;
            _ready=true;
            InputPresentationTrace.SetPath("swap-chain");
            Invalidate();
        }
        catch(COMException ex) when(epoch==_epoch&&!_disposed)
        {SwitchToFallback(ex.HResult);}
    }

    public void Invalidate()
    {
        _pending=true;
        if(_disposed||!IsLoaded)return;
        if(_fallback is not null){_fallback.Invalidate();return;}
        if(!_ready||_queued)return;
        _queued=true;
        // UI changes coalesce. Active ink uses PresentNow and consumes this
        // request; the queued callback then has no stale frame to replay.
        var epoch=_epoch;
        if(!DispatcherQueue.TryEnqueue(DispatcherQueuePriority.Low,()=>
        {
            if(epoch!=_epoch)return;
            _queued=false;
            if(_pending)PresentNow();
        }))_queued=false;
    }

    public void PresentNow()
    {
        _pending=true;
        if(_disposed||!IsLoaded)return;
        if(_fallback is not null){_fallback.Invalidate();return;}
        if(!_ready||_drawing||ActualWidth<=0||ActualHeight<=0||Visibility!=Visibility.Visible)return;
        var elapsed=System.Diagnostics.Stopwatch.GetElapsedTime(_lastPresent).TotalMilliseconds;
        if(_lastPresent!=0&&elapsed<MinimumFrameMilliseconds)
        {
            if(_frameTimer is null)
            {
                _frameTimer=DispatcherQueue.CreateTimer();_frameTimer.IsRepeating=false;
                _frameTimer.Tick+=(_,_)=>{if(_pending)PresentNow();};
            }
            if(!_frameTimer.IsRunning)
            {
                _frameTimer.Interval=TimeSpan.FromMilliseconds(Math.Max(1,MinimumFrameMilliseconds-elapsed));
                _frameTimer.Start();
            }
            return;
        }
        _frameTimer?.Stop();
        _drawing=true;
        try
        {
            var dpi=Dpi;
            if(_swapChain is null)
            {
                _swapChain=new CanvasSwapChain(Device,(float)ActualWidth,(float)ActualHeight,dpi);
                _panel!.SwapChain=_swapChain;
            }
            else if(_width!=ActualWidth||_height!=ActualHeight||_dpi!=dpi)
                _swapChain.ResizeBuffers((float)ActualWidth,(float)ActualHeight,dpi);
            _width=ActualWidth;_height=ActualHeight;_dpi=dpi;
            _pending=false;
            InputPresentationTrace.BeginDraw();
            using(var session=_swapChain.CreateDrawingSession(Color.FromArgb(0,0,0,0)))
                Draw?.Invoke(this,session);
            // Zero discards superseded queued frames. It does not bypass DWM
            // or promise zero lag. GPU back pressure is included in this scope.
            using(InputLatencyTrace.Measure(InputStage.SwapChainPresent))_swapChain.Present(0);
            _lastPresent=System.Diagnostics.Stopwatch.GetTimestamp();
            InputPresentationTrace.EndPresent();
        }
        catch(COMException ex){SwitchToFallback(ex.HResult);}
        finally{_drawing=false;}
    }

    private void SwitchToFallback(int hresult)
    {
        InputPresentationTrace.SetPath("xaml-fallback",hresult);
        _useFallback=true;
        ReleaseSurface();
        if(IsLoaded&&!_disposed)
        {
            _root=XamlRoot;
            if(_root is not null)_root.Changed+=RootChanged;
            InstallFallback();
        }
    }
    private void InstallFallback()
    {
        if(_fallback is not null)return;
        _fallback=new CanvasControl{IsHitTestVisible=false};
        _fallback.CreateResources+=(sender,args)=>
        {
            var resources=new ImmediateCanvasResourcesEventArgs();
            CreateResources?.Invoke(this,resources);
            args.TrackAsyncAction(resources.Completion.AsAsyncAction());
        };
        _fallback.Draw+=(sender,args)=>
        {
            _pending=false;
            InputPresentationTrace.BeginDraw();
            Draw?.Invoke(this,args.DrawingSession);
            // CanvasControl owns the later presentation. Never label Draw's
            // return as Present or visible latency in the diagnostic report.
            InputPresentationTrace.EndDrawWithoutPresent();
        };
        Children.Add(_fallback);
        InputPresentationTrace.SetPath("xaml");
        _fallback.Invalidate();
    }
    private void ReleaseSurface()
    {
        ++_epoch;_ready=_queued=false;_pending=true;
        _frameTimer?.Stop();_frameTimer=null;_lastPresent=0;
        if(_root is not null)_root.Changed-=RootChanged;
        _root=null;
        if(_panel is not null)_panel.SwapChain=null;
        _swapChain?.Dispose();_swapChain=null;
        _panel=null;
        _fallback?.RemoveFromVisualTree();_fallback=null;
        Children.Clear();
        // Shared device lifetime belongs to Win2D, not this view.
        _device=null;
    }
    public void RemoveFromVisualTree()
    {_disposed=true;ReleaseSurface();CreateResources=null;Draw=null;}
}
