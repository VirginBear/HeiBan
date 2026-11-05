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
