using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Diagnostics;
using Microsoft.UI.Xaml;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private CircularEraserGesture? _circularEraser;
    private Task? _circularEraserCompletion;
    private readonly DispatcherTimer _circularEraserTimer=new(){Interval=TimeSpan.FromMilliseconds(16)};
    private void BeginCircularEraser(InkPoint point)
    {
        _session.SelectedId=null;_objectDetailsId=null;SelectionBar.Visibility=Inspector.Visibility=Visibility.Collapsed;
        _circularEraserCompletion=null;
        var gesture=_circularEraser=new(_session,EraserSizeSlider.Value/2,EraserModeBox.SelectedIndex==0);
        gesture.PreviewChanged+=()=>{if(ReferenceEquals(_circularEraser,gesture)){_renderer.Prune(gesture.Preview.Document.Objects);InvalidateCanvas();}};
        gesture.Queue(point);_circularEraserTimer.Tick-=PumpCircularEraser;_circularEraserTimer.Tick+=PumpCircularEraser;_circularEraserTimer.Start();
        InvalidateCanvas(false);
    }
    private async void PumpCircularEraser(object? sender,object e)
    {
        var gesture=_circularEraser;if(gesture is null)return;
        try{await gesture.PumpAsync();}
        catch(Exception error){if(ReferenceEquals(_circularEraser,gesture)){CancelCircularEraser();await Error(error);}}
    }
    private Task CompleteCircularEraserAsync()=>_circularEraserCompletion??=CompleteCircularEraserCoreAsync();
    private async Task CompleteCircularEraserCoreAsync()
    {
        var gesture=_circularEraser;if(gesture is null)return;_circularEraserTimer.Stop();
        try
        {
            var snapshot=await gesture.CompleteAsync();
            if(ReferenceEquals(_circularEraser,gesture)&&snapshot is not null&&gesture.Matches(_session))
            {using var trace=InputLatencyTrace.Measure(InputStage.EraserCommit);_session.Begin();_session.Document.Objects=snapshot.Objects;_session.Commit();}
        }
        catch(Exception error){gesture.Cancel();await Error(error);}
        finally{if(ReferenceEquals(_circularEraser,gesture)){_circularEraser=null;InvalidateCanvas();RefreshEditor();}}
    }
    private void CancelCircularEraser()
    {
        var gesture=_circularEraser;if(gesture is null)return;
        _circularEraser=null;gesture.Cancel();_circularEraserTimer.Stop();InvalidateCanvas();
    }
}
