#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    internal async Task<int> ValidateIconStyleAsync()
    {
        var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        var draft=DocumentCodec.Clone(_toolbarPreferences);draft.OperateRadialEnabled=false;await _owner.SaveToolbarPreferencesAsync(draft);
        await StartAsync();var generation=_session.Generation;
        try
        {
            foreach(var style in new[]{"duotone","classic","duotone"})
            {
                draft=DocumentCodec.Clone(_toolbarPreferences);draft.IconStyle=style;await _owner.SaveToolbarPreferencesAsync(draft);
                Check(_toolbarPreferences.IconStyle==style&&_chromeIconStyle==style&&ToolIcons.Style==style,"Screen/owner did not share icon style");
                Check(ToolbarPreferencesStore.Load(Path.GetDirectoryName(Path.GetDirectoryName(_recoveryPath))!).IconStyle==style,"Style was not persisted");
                SetDrawing(true);Check(ModeUri().EndsWith("/mode-draw.svg"),"Drawing mode lost monitor+pen");
                SetDrawing(false);Check(ModeUri().EndsWith("/mode-operate.svg"),"Operate mode lost monitor+pointer");
            }
            SetScreenColor("#FFD400");
            foreach(var key in new[]{"pen","highlighter"})Check(ToolbarUi.ValidateToolColor(_buttons[key]).Primary==Direct2DCanvasRenderer.HexToColor("#FFD400"),"Screen toolbar brush did not follow yellow");
            Check(_session.Generation==generation,"Style or mode change modified annotations");return checks;
        }
        finally{await StopAsync();}
    }
    private string ModeUri()=>((_mode.Content as StackPanel)?.Children[0] as ImageIcon)?.Source is SvgImageSource svg?svg.UriSource.AbsoluteUri:"";
}
#endif
