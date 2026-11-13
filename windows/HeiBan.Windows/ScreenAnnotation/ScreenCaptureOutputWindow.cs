using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using global::Windows.Foundation;
using global::Windows.Graphics;

namespace HeiBan.Windows.ScreenAnnotation;

/// <summary>A regular composited HWND for OBS Window Capture. Its source is the annotation render target.</summary>
internal sealed class ScreenCaptureOutputWindow : Window
{
    private readonly CanvasControl _canvas;
    private CanvasRenderTarget? _frame;

    internal ScreenCaptureOutputWindow()
    {
        Title="HeiBan · OBS";
        _canvas=new CanvasControl
        {
            UseSharedDevice=true,
            ClearColor=Microsoft.UI.Colors.White,
            HorizontalAlignment=HorizontalAlignment.Stretch,
            VerticalAlignment=VerticalAlignment.Stretch,
        };
        _canvas.Draw+=Draw;
        Content=_canvas;
        Closed+=(_,_)=>{_frame=null;_canvas.Draw-=Draw;_canvas.RemoveFromVisualTree();Content=null;};
    }

    internal void Place(RectInt32 source,RectInt32 workArea)
    {
        var scale=Math.Min(1,Math.Min(workArea.Width*.72/source.Width,workArea.Height*.72/source.Height));
        var width=Math.Max(1,(int)(source.Width*scale));
        var height=Math.Max(1,(int)(source.Height*scale));
        var x=workArea.X+(workArea.Width-width)/2;
        var y=workArea.Y+(workArea.Height-height)/2;
        // Leave the drawing region unobstructed whenever it has room beside it.
        if(source.X+source.Width+width<=workArea.X+workArea.Width)x=source.X+source.Width;
        else if(source.X-width>=workArea.X)x=source.X-width;
        else if(source.Y+source.Height+height<=workArea.Y+workArea.Height)y=source.Y+source.Height;
        else if(source.Y-height>=workArea.Y)y=source.Y-height;
        AppWindow.MoveAndResize(new RectInt32(x,y,width,height));
    }

    internal void Present(CanvasRenderTarget? frame)
    {
        _frame=frame;
        _canvas.Invalidate();
    }

    private void Draw(CanvasControl canvas,CanvasDrawEventArgs args)
    {
        if(_frame is not { } frame||canvas.ActualWidth<=0||canvas.ActualHeight<=0)return;
        var scale=Math.Min(canvas.ActualWidth/frame.Size.Width,canvas.ActualHeight/frame.Size.Height);
        var width=frame.Size.Width*scale;
        var height=frame.Size.Height*scale;
        // The UI thread owns both render targets. GPU composition reuses the live
        // image without making a second copy of the desktop or a CPU readback.
        args.DrawingSession.DrawImage(frame,new Rect((canvas.ActualWidth-width)/2,(canvas.ActualHeight-height)/2,width,height));
    }
}
