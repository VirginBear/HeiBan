using HeiBan.Windows.Models;
using static HeiBan.Windows.Localization.Strings;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private bool IsCurrentScreenSession(long epoch)=>IsActive&&!_stopping&&_session.DocumentEpoch==epoch;
    private bool IsAuxiliaryToolWindow(nint handle)=>handle!=0&&(handle==(_captureOutput is { } output?WinRT.Interop.WindowNative.GetWindowHandle(output):0)||handle==(_screenCalcWindow?.Handle??0)||handle==(_screenTimerWindow?.Handle??0)||handle==(_customizeToolbarWindow?.Handle??0));
    private async Task<bool> PrepareScreenEditAsync(long epoch)
    {
        if(!IsCurrentScreenSession(epoch))return false;
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        if(!IsCurrentScreenSession(epoch))return false;
        FinishScreenText();CommitScreenStyle();
        // A delayed picker must not commit or cancel a newer, still-held drawing gesture.
        if(_start is not null||_circularEraser is not null||_session.HasTransaction){_status.Text=T("請先完成目前操作，再插入物件。");return false;}
        CancelGesture();return true;
    }
    private async Task InsertScreenObjectAsync(BoardObject item,long epoch)
    {
        try
        {
            if(!await PrepareScreenEditAsync(epoch))return;
            _session.Begin();_session.Add(item);_session.SelectedId=item.Id;_session.Commit();
            _tool="select";_overlay.SetManipulationCursor(null,null,_tool);RefreshButtons();Changed();
        }
        catch(Exception error){_status.Text=T("繪圖未完成：")+error.Message;}
    }
}
