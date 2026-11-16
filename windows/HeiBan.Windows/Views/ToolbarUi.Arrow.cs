using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml.Controls;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows.Views;

internal static partial class ToolbarUi
{
    internal static void AddArrowShaftControls(StackPanel panel, BoardObject arrow, double scale, Action<Action<BoardObject>> apply)
    {
        var shaftLength = new NumberBox
        {
            Header = T("箭尾長度"),
            Minimum = 1,
            Value = Math.Max(1, ArrowGeometry.ShaftLength(arrow) / scale),
            SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline
        };
        shaftLength.ValueChanged += (_, e) =>
        {
            if (double.IsFinite(e.NewValue)) apply(item => ArrowGeometry.SetShaftLength(item, e.NewValue * scale));
        };
        panel.Children.Add(shaftLength);
        var shaftWidth = BrushSlider(T("箭尾寬度"), .5, 128, arrow.StrokeWidth / scale, .5);
        shaftWidth.ValueChanged += (_, e) => apply(item => item.StrokeWidth = e.NewValue * scale);
        panel.Children.Add(shaftWidth);
    }
}
