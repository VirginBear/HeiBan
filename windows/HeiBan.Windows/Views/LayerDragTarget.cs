using Microsoft.UI.Xaml.Controls;
using global::Windows.Foundation;

namespace HeiBan.Windows.Views;

internal static class LayerDragTarget
{
    // Rows may be virtualized or scrolled. Use their transformed bounds, never a guessed row height.
    internal static (object? Item,bool After) Find(ListView list,Point point)
    {
        (object? Item,bool After) nearest=(null,false);var distance=double.PositiveInfinity;
        foreach(var item in list.Items)
        {
            if(list.ContainerFromItem(item) is not ListViewItem row)continue;
            var top=row.TransformToVisual(list).TransformPoint(new Point()).Y;var middle=top+row.ActualHeight/2;
            if(Math.Abs(point.Y-middle)<distance){distance=Math.Abs(point.Y-middle);nearest=(item,point.Y>middle);}
        }
        return nearest;
    }
}
