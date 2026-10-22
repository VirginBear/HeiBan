using HeiBan.Windows.Engine;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private MagnetSnapIndex? _screenMagnetIndex;
    private double _screenMagnetScale;
    private long _screenMagnetGeneration=-1,_screenMagnetEpoch=-1;
    private HeiBan.Windows.Models.InkPoint? _screenMagnetTarget;
    private global::Windows.Foundation.Rect? _lastMagnetDamage;
    private void AppendScreenInk(HeiBan.Windows.Models.BoardObject item)
    {
        var before=_session.Generation;_session.AppendInk(item);
        if(_screenMagnetIndex is not null&&_toolbarPreferences.MagnetEnabled&&_screenMagnetGeneration==before&&
            _screenMagnetEpoch==_session.DocumentEpoch&&_screenMagnetScale==_dpiScale)
        {_screenMagnetIndex.Add(item);_screenMagnetGeneration=_session.Generation;}
    }
    private void EnsureScreenMagnetIndex()
    {
        if(!_toolbarPreferences.MagnetEnabled){_screenMagnetIndex=null;return;}
        if(_screenMagnetIndex is not null&&_screenMagnetGeneration==_session.Generation&&_screenMagnetEpoch==_session.DocumentEpoch&&_screenMagnetScale==_dpiScale)return;
        _screenMagnetIndex=new MagnetSnapIndex(_session.VisibleObjects,10*_dpiScale);_screenMagnetGeneration=_session.Generation;_screenMagnetEpoch=_session.DocumentEpoch;_screenMagnetScale=_dpiScale;
    }
    private void UpdateScreenMagnetHover()
    {
        HeiBan.Windows.Models.InkPoint? target=null;
        if(_drawing&&_toolbarPreferences.MagnetEnabled&&IsMagnetDrawingTool(_tool)&&_chromeFlyout is null&&_captureCancellation is null)
        {
            var cursor=NativeOverlayWindow.CurrentPointer;var chrome=AppWindow.Position;var size=AppWindow.Size;
            if(!(cursor.X>=chrome.X&&cursor.X<chrome.X+size.Width&&cursor.Y>=chrome.Y&&cursor.Y<chrome.Y+size.Height))
            {
                EnsureScreenMagnetIndex();var point=new HeiBan.Windows.Models.InkPoint(cursor.X-_overlay.Left,cursor.Y-_overlay.Top);
                if(_screenMagnetIndex is not null){var snapped=_screenMagnetIndex.Snap(point,out var found);if(found)target=snapped;}
            }
        }
        if(target?.X==_screenMagnetTarget?.X&&target?.Y==_screenMagnetTarget?.Y)return;
        _screenMagnetTarget=target;_dirty=true;
    }
    private static bool IsMagnetDrawingTool(string tool)=>MagnetSnapIndex.SupportsConstructionTool(tool);
    private async void ToggleScreenMagnet()
    {
        var previous=_toolbarPreferences.MagnetEnabled;_toolbarPreferences.MagnetEnabled=!previous;
        try{await _owner.SaveToolbarPreferencesAsync(_toolbarPreferences);RefreshButtons();}
        catch(Exception ex){_toolbarPreferences.MagnetEnabled=previous;_status.Text=ex.Message;}
    }
}
