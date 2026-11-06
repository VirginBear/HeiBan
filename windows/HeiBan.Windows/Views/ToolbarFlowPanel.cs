using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Foundation;
using HeiBan.Windows.Engine;

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
    private int[] _pageStarts=[0];
    internal void NextPage(int direction)
    {var page=Math.Max(0,Array.FindLastIndex(_pageStarts,start=>start<=PageOffset));PageOffset=_pageStarts[Math.Clamp(page+Math.Sign(direction),0,_pageStarts.Length-1)];InvalidateMeasure();}

    private Size Layout(bool arrange)
    {
        var horizontal = Orientation == Orientation.Horizontal;
        var visible = Children.Where(child => child.Visibility != Visibility.Collapsed).ToArray();
        if (!arrange)
            foreach (var child in visible) child.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));

        var lengths = visible.Select(child => horizontal ? child.DesiredSize.Width : child.DesiredSize.Height).ToArray();
        _pageStarts = ToolbarPaging.Starts(lengths, RunLength, Spacing);
        var firstPage = 0;
        var endPage = _pageStarts.Length;
        int End(int page) => page + 1 < _pageStarts.Length ? _pageStarts[page + 1] : visible.Length;
        if (SingleRun)
        {
            firstPage = Math.Max(0, Array.FindLastIndex(_pageStarts, start => start <= PageOffset));
            endPage = firstPage + 1;
            PageOffset = _pageStarts[firstPage];
            PageCapacity = End(firstPage) - PageOffset;
            PageAvailabilityChanged?.Invoke(PageOffset > 0, PageOffset + PageCapacity < visible.Length);
            if (arrange)
                for (var index = 0; index < visible.Length; index++)
                    if (index < PageOffset || index >= End(firstPage)) visible[index].Arrange(new Rect(-10000, -10000, 0, 0));
        }

        double cross = 0, maxRun = 0;
        for (var page = firstPage; page < endPage; page++)
        {
            var start = _pageStarts[page];
            var end = End(page);
            double lineCross = 0;
            for (var index = start; index < end; index++)
            {
                var size = visible[index].DesiredSize;
                lineCross = Math.Max(lineCross, horizontal ? size.Height : size.Width);
            }

            // Measure the full row/column first so ordinary icons share the
            // midpoint of taller brush/palette units in that run.
            double run = 0;
            for (var index = start; index < end; index++)
            {
                var child = visible[index];
                var size = child.DesiredSize;
                var offset = cross + (lineCross - (horizontal ? size.Height : size.Width)) / 2;
                if (index > start) run += Spacing;
                if (arrange) child.Arrange(horizontal ? new Rect(run, offset, size.Width, size.Height) : new Rect(offset, run, size.Width, size.Height));
                run += lengths[index];
            }
            maxRun = Math.Max(maxRun, run);
            cross += lineCross + (page + 1 < endPage ? Spacing : 0);
        }
        return horizontal ? new Size(maxRun, cross) : new Size(cross, maxRun);
    }

    protected override Size MeasureOverride(Size availableSize)=>Layout(false);
    protected override Size ArrangeOverride(Size finalSize){Layout(true);return finalSize;}
}
