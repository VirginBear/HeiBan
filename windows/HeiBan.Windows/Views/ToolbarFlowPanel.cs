using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Foundation;

namespace HeiBan.Windows.Views;

// Tool windows use DIP here; the native window size converts to physical pixels once.
// Overflow creates another row/column, so no control is hidden behind a scrollbar.
internal sealed class ToolbarFlowPanel : Panel
{
    internal Orientation Orientation { get; set; }
    internal double RunLength { get; set; } = double.PositiveInfinity;
    internal double Spacing { get; set; } = 4;

    private Size Layout(bool arrange)
    {
        double run=0,cross=0,lineCross=0,maxRun=0;
        foreach(var child in Children)
        {
            if(child.Visibility==Visibility.Collapsed)continue;
            if(!arrange)child.Measure(new Size(double.PositiveInfinity,double.PositiveInfinity));
            var size=child.DesiredSize;var length=Orientation==Orientation.Horizontal?size.Width:size.Height;
            var breadth=Orientation==Orientation.Horizontal?size.Height:size.Width;
            if(run>0&&run+Spacing+length>RunLength){maxRun=Math.Max(maxRun,run);cross+=lineCross+Spacing;run=0;lineCross=0;}
            if(run>0)run+=Spacing;
            if(arrange)child.Arrange(Orientation==Orientation.Horizontal?new Rect(run,cross,size.Width,size.Height):new Rect(cross,run,size.Width,size.Height));
            run+=length;lineCross=Math.Max(lineCross,breadth);
        }
        maxRun=Math.Max(maxRun,run);cross+=lineCross;
        return Orientation==Orientation.Horizontal?new Size(maxRun,cross):new Size(cross,maxRun);
    }
    protected override Size MeasureOverride(Size availableSize)=>Layout(false);
    protected override Size ArrangeOverride(Size finalSize){Layout(true);return finalSize;}
}
