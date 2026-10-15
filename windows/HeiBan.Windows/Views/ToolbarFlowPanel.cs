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
    internal bool SingleRun { get; set; }
    internal int PageOffset { get; set; }
    internal int PageCapacity { get; private set; } = 1;
    internal Action<bool,bool>? PageAvailabilityChanged { get; set; }
    internal void NextPage(int direction)
    {var count=Children.Count(c=>c.Visibility!=Visibility.Collapsed);PageOffset=Math.Clamp(PageOffset+direction*PageCapacity,0,Math.Max(0,(count-1)/PageCapacity*PageCapacity));InvalidateMeasure();}

    private Size Layout(bool arrange)
    {
        double run=0,cross=0,lineCross=0,maxRun=0;
        if(SingleRun)
        {
            var visible=Children.Where(c=>c.Visibility!=Visibility.Collapsed).ToArray();
            double capacityRun=0;var maximum=0;
            foreach(var child in visible)
            {
                if(!arrange)child.Measure(new Size(double.PositiveInfinity,double.PositiveInfinity));
                var length=Orientation==Orientation.Horizontal?child.DesiredSize.Width:child.DesiredSize.Height;
                if(maximum>0&&capacityRun+Spacing+length>RunLength)break;
                capacityRun+=length+(maximum>0?Spacing:0);maximum++;
            }
            PageCapacity=Math.Max(1,maximum);
            PageOffset=Math.Clamp(PageOffset/PageCapacity*PageCapacity,0,Math.Max(0,(visible.Length-1)/PageCapacity*PageCapacity));
            PageAvailabilityChanged?.Invoke(PageOffset>0,PageOffset+PageCapacity<visible.Length);
            var capacity=0;
            for(var index=0;index<visible.Length;index++)
            {
                var child=visible[index];if(!arrange)child.Measure(new Size(double.PositiveInfinity,double.PositiveInfinity));
                var size=child.DesiredSize;var length=Orientation==Orientation.Horizontal?size.Width:size.Height;
                var breadth=Orientation==Orientation.Horizontal?size.Height:size.Width;
                var show=index>=PageOffset&&index<PageOffset+PageCapacity;
                if(show)
                {
                    if(capacity>0)run+=Spacing;
                    if(arrange)child.Arrange(Orientation==Orientation.Horizontal?new Rect(run,0,size.Width,size.Height):new Rect(0,run,size.Width,size.Height));
                    run+=length;cross=Math.Max(cross,breadth);capacity++;
                }
                else if(arrange)child.Arrange(new Rect(-10000,-10000,0,0));
            }
            return Orientation==Orientation.Horizontal?new Size(run,cross):new Size(cross,run);
        }
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
