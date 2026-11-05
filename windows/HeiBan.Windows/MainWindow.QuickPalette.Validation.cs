#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task<int> ValidateQuickPaletteAsync()
    {
        var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        await Task.Delay(150);
        Check(_quickPalette is not null&&_quickPalette.ValidationButtons.Count==6,"Six quick color circles missing");
        var colors=ProfilePalette.Colors.ToArray();await ProfilePalette.MoveAsync(colors[^1],0);await Task.Delay(100);
        Check(_quickPalette!.ValidationButtons.Select(b=>b.Tag as string).SequenceEqual(ProfilePalette.Colors.Take(6)),"Quick palette did not follow reordered first six");
        Check(new PalettePreferencesStore(_storage.DataDirectory).Colors.SequenceEqual(ProfilePalette.Colors),"Order not persisted");
        ActivateTool("pen");var generation=_session.Generation;
        foreach(var color in ProfilePalette.Colors.Take(6))
        {ApplyQuickBrushColor(color);Check(CurrentStyle.Color==color&&_session.Generation==generation,"Fast color selection altered document or missed brush");}
        ActivateTool("laser");ApplyQuickBrushColor(ProfilePalette.Colors[0]);Check(_laser.Color==ProfilePalette.Colors[0],"Quick colors missed laser");
        ActivateTool("pen");
        var display=_toolbarPrefs.DisplayMode;var dock=_dock;
        foreach(var mode in new[]{"icons","labels"})foreach(var side in new[]{"上方","左側","右側","下方"})
        {
            _toolbarPrefs.DisplayMode=mode;_dock=side;ArrangeMainToolbar();
            var unit=ToolbarUi.ButtonUnit(_brushButton!);
            Check(unit is Grid grid&&grid.Children.Contains(_brushButton)&&grid.Children.Contains(_quickPalette)&&Grid.GetColumn(_quickPalette)==1,"Brush/six-color unit split during mode/dock change");
        }
        _toolbarPrefs.DisplayMode=display;_dock=dock;ArrangeMainToolbar();await Task.Delay(180);
        await ProfilePalette.ResetAsync();
        foreach(var color in ProfilePalette.Colors.Skip(3).ToArray())await ProfilePalette.RemoveAsync(color);
        await Task.Delay(80);
        Check(_quickPalette.ValidationButtons.Count(b=>b.IsEnabled)==3,$"Missing colors placeholders: enabled={_quickPalette.ValidationButtons.Count(b=>b.IsEnabled)},loaded={_quickPalette.IsLoaded},store={ProfilePalette.Colors.Count},tags={string.Join(",",_quickPalette.ValidationButtons.Select(b=>b.Tag))}");
        foreach(var color in ProfilePalette.Colors.ToArray())await ProfilePalette.RemoveAsync(color);
        await Task.Delay(80);
        Check(_quickPalette.ValidationButtons.All(b=>!b.IsEnabled)&&ProfilePalette.Colors.Count==0,"Empty palette must not manufacture defaults");
        await ProfilePalette.ResetAsync();
        var applied=0;
        var editor=new PaletteEditor(ProfilePalette,()=>CurrentStyle.Color,_=>applied++);
        var flyout=new Microsoft.UI.Xaml.Controls.Flyout{Content=editor};
        ShowExclusiveFlyout(flyout,_brushButton!,DrawingArea);await Task.Delay(200);
        try{checks+=await editor.ValidatePaletteDragAsync();Check(applied==0,"Managing reorder applied a brush color");}
        finally{flyout.Hide();}
        await ProfilePalette.ResetAsync();
        return checks;
    }
}
#endif
