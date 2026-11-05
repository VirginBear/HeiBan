#if HEIBAN_RELEASE_VALIDATION
using global::Windows.Foundation;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows.Views;
internal sealed partial class PaletteEditor
{
    internal async Task<int> ValidatePaletteDragAsync()
    {
        var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        _managing=true;Rebuild();await Task.Delay(100);
        var colors=_store.Colors.ToArray();var cells=_swatches.Children.OfType<StackPanel>().ToArray();
        Point At(StackPanel cell)=>cell.TransformToVisual(_swatches).TransformPoint(new Point(16,16));
        BeginPaletteDrag((Button)cells[^1].Children[0],colors[^1],At(cells[^1]));
        Check(MovePaletteDrag(At(cells[0]))&&_dropIndex==0&&_dragPreview is not null&&_dragLayer.Children.Count==1,"Measured drag target or preview missing");
        Check(Math.Abs(((Button)cells[^1].Children[0]).Opacity-.4)<1e-5,"Source does not show being dragged");
        FinishDrag(true);await _store.FlushAsync();await Task.Delay(60);
        Check(_store.Colors.SequenceEqual(new[]{colors[^1]}.Concat(colors[..^1])),"Dropping did not persist ordered palette");
        Check(_dragLayer.Children.Count==0,"Drag preview leaked after drop");
        cells=_swatches.Children.OfType<StackPanel>().ToArray();var before=_store.Colors.ToArray();
        BeginPaletteDrag((Button)cells[0].Children[0],before[0],At(cells[0]));MovePaletteDrag(At(cells[^1]));FinishDrag(false);await _store.FlushAsync();
        Check(_store.Colors.SequenceEqual(before)&&_dragLayer.Children.Count==0,"Cancel changed order or leaked preview");
        return checks;
    }
}
#endif
