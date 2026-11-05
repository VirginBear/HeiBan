using System.Runtime.CompilerServices;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace HeiBan.Windows.Views;
internal static partial class ToolbarUi
{
    private static readonly ConditionalWeakTable<Button,Grid> BrushUnits=new();
    internal static void BindQuickPalette(Button brush,QuickPalette palette)
    {
        var unit=new Grid{ColumnSpacing=3,FlowDirection=FlowDirection.LeftToRight};
        unit.ColumnDefinitions.Add(new(){Width=GridLength.Auto});unit.ColumnDefinitions.Add(new(){Width=GridLength.Auto});
        // Called before Arrange reparents the brush. A unit stays indivisible when paging/docking.
        if(brush.Parent is Panel parent)parent.Children.Remove(brush);
        unit.Children.Add(brush);Grid.SetColumn(palette,1);unit.Children.Add(palette);BrushUnits.Add(brush,unit);unit.Visibility=brush.Visibility;
        brush.RegisterPropertyChangedCallback(UIElement.VisibilityProperty,(_,_)=>unit.Visibility=brush.Visibility);
    }
    internal static FrameworkElement ButtonUnit(Button button)=>BrushUnits.TryGetValue(button,out var unit)?unit:button;
}
