using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private readonly CaneFeedback _cane=new();
    private void CaneQuick_Click(object sender,RoutedEventArgs e)=>ActivateTool("cane");
    private void RefreshCaneQuick()
    {
        if(CaneQuickButton is null)return;
        if(CaneQuickButton.Content is null)
        {var icon=(FrameworkElement)Views.ToolIcons.Create("cane");icon.Width=icon.Height=38;CaneQuickButton.Content=icon;}
        // Independent from the eraser's drag surface and visibility.
        var occupied=_toolbarPrefs.BoardEraserVisible?BoardEraserGeometry.DisplayWidth+12:0;
        Canvas.SetLeft(CaneQuickButton,Math.Max(8,DrawingArea.ActualWidth-occupied-74));
        Canvas.SetTop(CaneQuickButton,Math.Max(8,DrawingArea.ActualHeight-98));
        CaneQuickButton.Background=Brush(_tool=="cane"?"#DCEBDD":"#FCFCFA");
        CaneQuickButton.IsEnabled=!_readingMode;
    }
}
