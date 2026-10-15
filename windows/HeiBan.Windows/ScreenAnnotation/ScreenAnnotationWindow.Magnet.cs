using HeiBan.Windows.Engine;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private MagnetSnapIndex? _screenMagnetIndex;
    private static bool IsMagnetDrawingTool(string tool)=>tool is "pen" or "highlighter" or "paint" or "curve" or "line" or "arrow" or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star";
    private async void ToggleScreenMagnet()
    {
        var previous=_toolbarPreferences.MagnetEnabled;_toolbarPreferences.MagnetEnabled=!previous;
        try{await _owner.SaveToolbarPreferencesAsync(_toolbarPreferences);RefreshButtons();}
        catch(Exception ex){_toolbarPreferences.MagnetEnabled=previous;_status.Text=ex.Message;}
    }
}
