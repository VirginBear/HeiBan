#if HEIBAN_RELEASE_VALIDATION
using static HeiBan.Windows.Localization.Strings;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private async Task<int> ValidateScreenConstructionAndRulerAsync(string output)
    {
        var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        SetDrawing(true);_renderTimer.Stop();
        foreach(var type in new[]{"line","arrow","rect","circle","triangle","quadrilateral","diamond","pentagon","star"})
        {
            CancelGesture();_tool=type;var count=_session.Document.Objects.Count;
            OnPointerCore(new("down",160,240,Shift:true,LeftDown:true));OnPointerCore(new("move",270,306,Shift:true,LeftDown:true));
            Check(_session.Document.Objects.Count==count,"Preview committed before release: "+type);
            OnPointerCore(new("up",270,306,Shift:true));
            Check(_session.Document.Objects.Count==count+1,"Missing construction: "+type);
            var shape=_session.Document.Objects[^1];
            Check(type=="triangle"?shape.ParsedPoints.Count==3:Math.Abs(shape.Width-shape.Height)<.001,"Screen regular construction: "+type);
        }
        CancelGesture();_tool="triangle";var prior=_session.Document.Objects.Count;
        OnPointerCore(new("down",400,200,LeftDown:true));OnPointerCore(new("move",520,270,Shift:true,LeftDown:true));OnPointerCore(new("up",520,270,Shift:true));
        Check(_session.Document.Objects.Count==prior+1,"Mid-drag Shift triangle failed");
        CancelGesture();_tool="rect";
        OnPointerCore(new("double",500,200,Shift:true,LeftDown:true));OnPointerCore(new("move",570,250,Shift:true,LeftDown:true));OnPointerCore(new("up",570,250,Shift:true));
        Check(_tool=="rect","Double-click switched drawing tool");
        CancelGesture();_tool="pen";_rulerEnabled=false;Changed();Render();var baseline=_target!.GetPixelBytes();var generation=_session.Generation;
        var visible=_toolbarPreferences.VisibleTools.ToList();var hidden=_toolbarPreferences.HiddenTools.ToList();
        try
        {
            _toolbarPreferences.HideTool("ruler");_toolbarPreferences.HideTool("paint");_toolbarPreferences.HideTool("dash");RebuildChromeLayout();
            var menu=CreateScreenMenu();
            Check(menu.Items.OfType<MenuFlyoutSubItem>().Any(i=>i.Text==T("螢幕尺")),"Hidden ruler recovery entry missing");
            Check(menu.Items.OfType<MenuFlyoutSubItem>().Any(i=>i.Text==T("更多工具")&&i.Items.OfType<MenuFlyoutItem>().Any()),"Hidden tools menu missing");
            _screenCommands["dash"]();Check(_chromeFlyout is not null,"Hidden settings did not open from More");_chromeFlyout!.Hide();
            RecoverScreenRuler();Render();
            await File.WriteAllTextAsync(Path.Combine(output,"ruler-coordinates.json"),System.Text.Json.JsonSerializer.Serialize(new{centerX=_rulerCenter.X,centerY=_rulerCenter.Y,length=RulerLength,overlayLeft=_overlay.Left,overlayTop=_overlay.Top,overlayWidth=_overlay.Width,overlayHeight=_overlay.Height,workArea=Microsoft.UI.Windowing.DisplayArea.GetFromWindowId(AppWindow.Id,Microsoft.UI.Windowing.DisplayAreaFallback.Primary).WorkArea}));
            Check(_rulerCenter.X-RulerLength/2>=0&&_rulerCenter.X+RulerLength/2<=_overlay.Width&&_rulerCenter.Y>=RulerHeight/2&&_rulerCenter.Y<=_overlay.Height-RulerHeight/2,"Recovered ruler not fully on desktop");
            Check(_rulerEnabled&&_lastRulerDamage is {Width:>100,Height:>20},"Recovered ruler extent missing");
            Check(!baseline.SequenceEqual(_target.GetPixelBytes()),"Recovered ruler invisible");
            Check(_session.Generation==generation,"Ruler toggling changed document generation");
            await _target.SaveAsync(Path.Combine(output,"screen-ruler.png"),CanvasBitmapFileFormat.Png);
            ToggleScreenRuler();Render();Check(baseline.SequenceEqual(_target.GetPixelBytes()),"Ruler removal left stale pixels");
        }
        finally{_toolbarPreferences.VisibleTools=visible;_toolbarPreferences.HiddenTools=hidden;RebuildChromeLayout();}
        return checks;
    }
}
#endif
