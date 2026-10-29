using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private readonly CaneFeedback _cane=new();
    private void CaneQuickImage_Opened(object sender,RoutedEventArgs e)
    {
        if(sender is Image{Source:BitmapSource bitmap} image&&bitmap.PixelWidth>0&&bitmap.PixelHeight>0)
            image.RenderTransform=new RotateTransform{Angle=CanePose.ArtworkRestRotationDegrees(bitmap.PixelWidth,bitmap.PixelHeight)};
    }
    private void CaneQuick_Tapped(object sender,TappedRoutedEventArgs e){ActivateTool("cane");e.Handled=true;}
    private void CaneQuick_RightTapped(object sender,RightTappedRoutedEventArgs e)
    {
        var menu=new MenuFlyout();var hide=new MenuFlyoutItem{Text=T("隱藏藤條")};
        hide.Click+=async(_,_)=>await SetCaneVisibleAsync(false);menu.Items.Add(hide);
        ShowExclusiveFlyout(menu,CaneQuickButton);e.Handled=true;
    }
    private async Task SetCaneVisibleAsync(bool value)
    {
        var previous=_toolbarPrefs.CaneVisible;_toolbarPrefs.CaneVisible=value;
        try{await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,_toolbarPrefs);}
        catch(Exception e){_toolbarPrefs.CaneVisible=previous;await Error(e);}
        finally{RefreshCaneQuick();}
    }
    private void PlayCaneSound()=>CaneSound.Play(error=>DispatcherQueue.TryEnqueue(()=>StatusText.Text=T("藤條音效無法播放：")+error));
    private void RefreshCaneQuick()
    {
        if(CaneQuickButton is null)return;
        var occupied=_toolbarPrefs.BoardEraserVisible?BoardEraserGeometry.DisplayWidth+12:0;
        Canvas.SetLeft(CaneQuickButton,Math.Max(8,DrawingArea.ActualWidth-occupied-124));
        Canvas.SetTop(CaneQuickButton,Math.Max(8,DrawingArea.ActualHeight-118));
        CaneQuickButton.Visibility=_toolbarPrefs.CaneVisible?Visibility.Visible:Visibility.Collapsed;
        CaneQuickButton.Opacity=_tool=="cane"?1:.9;
        CaneQuickButton.IsHitTestVisible=!_readingMode;
    }
}
