#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using Microsoft.Graphics.Canvas;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    internal async Task<int> ValidateCursorCaneAsync(string output)
    {
        var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        await StartAsync();
        try
        {
            checks+=await ValidateScreenConstructionAndRulerAsync(output);
            await Task.Delay(100);
            Check(_quickPalette is not null&&_quickPalette.ValidationButtons.Count==6,"Screen six colors missing");
            await _owner.ProfilePalette.MoveAsync(_owner.ProfilePalette.Colors[^1],0);await Task.Delay(100);
            Check(_quickPalette!.ValidationButtons.Select(b=>b.Tag as string).SequenceEqual(_owner.ProfilePalette.Colors.Take(6)),"Screen quick colors missed shared reorder");
            SetDrawing(true);_tool="pen";var colorGeneration=_session.Generation;SetScreenColor(_owner.ProfilePalette.Colors[0]);CommitScreenStyle();
            Check(_color==_owner.ProfilePalette.Colors[0]&&_session.Generation==colorGeneration,"Screen quick color changed annotations");
            var display=_toolbarPreferences.DisplayMode;var dock=_chromeDock;
            foreach(var mode in new[]{"icons","labels"})foreach(var side in new[]{"top","left","right","bottom"})
            {
                _toolbarPreferences.DisplayMode=mode;_chromeDock=side;RebuildChromeLayout();
                ResizeChrome();
                if (side is "left" or "right")
                    Check(AppWindow.Size.Width / _dpiScale <= 74, $"Screen side toolbar width: {AppWindow.Size.Width / _dpiScale}");
                var unit=HeiBan.Windows.Views.ToolbarUi.ButtonUnit(_brushButton);
                Check(unit is Microsoft.UI.Xaml.Controls.Grid grid&&grid.Children.Contains(_brushButton)&&grid.Children.Contains(_quickPalette)&&Microsoft.UI.Xaml.Controls.Grid.GetRow(_quickPalette)==(side is "left" or "right"?1:0),"Screen brush unit lost during docking");
            }
            _toolbarPreferences.DisplayMode=display;_chromeDock=dock;RebuildChromeLayout();
            SetDrawing(true);_tool="cane";_renderTimer.Stop();_cane.Clear();_dirty=true;Render();
            var generation=_session.Generation;var before=_target!.GetPixelBytes();var now=Now;
            var point=new HeiBan.Windows.Models.InkPoint(700*_dpiScale,500*_dpiScale);
            for(var i=0;i<3;i++)_cane.Strike(point,now-.3+i*.05,new(700,500));
            Render();await _target.SaveAsync(Path.Combine(output,"screen-cane-crack.png"),CanvasBitmapFileFormat.Png);
            Check(!before.SequenceEqual(_target.GetPixelBytes()),"Screen transient was not drawn");
            Check(_lastCaneDamage is {Width:>200,Height:>200},"Screen damage missing crack/cane extent");
            await Task.Delay(1350);Render();Check(!_cane.NeedsAnimation(Now),"Screen animation did not expire");
            _cane.Clear();Render();Check(before.SequenceEqual(_target.GetPixelBytes()),"Screen transient left stale pixels");
            Check(_session.Generation==generation,"Screen transient changed permanent annotations");
            return checks;
        }
        finally{await StopAsync();}
    }
}
#endif
