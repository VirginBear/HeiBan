using Microsoft.UI.Windowing;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private ScreenCaptureOutputWindow? _captureOutput;
    private void ShowCaptureOutput()
    {
        if(!IsActive||_stopping||_regionDisplayChanged||_target is null)return;
        try
        {
            if(_captureOutput is null)
            {
                var window=new ScreenCaptureOutputWindow();
                _captureOutput=window;
                window.Closed+=(_,_)=>{if(ReferenceEquals(_captureOutput,window))_captureOutput=null;};
                // Prefer another monitor so the preview cannot cover the drawing surface.
                var activeDisplay=DisplayArea.GetFromWindowId(AppWindow.Id,DisplayAreaFallback.Primary);
                var display=DisplayArea.FindAll().FirstOrDefault(candidate=>candidate.DisplayId.Value!=activeDisplay.DisplayId.Value
                    &&!NativeOverlayWindow.Intersects(_overlay.Bounds,candidate.OuterBounds))??activeDisplay;
                window.Place(_overlay.Bounds,display.WorkArea);
            }
            _captureOutput.Present(_target);
            _captureOutput.Activate();
        }
        catch(Exception error)
        {
            CloseCaptureOutput();
            _status.Text=T("OBS 擷取視窗無法開啟。")+" "+error.Message;
            RefreshMode();
        }
    }

    private void CloseCaptureOutput()
    {
        var window=_captureOutput;
        _captureOutput=null;
        window?.Close();
    }
}
