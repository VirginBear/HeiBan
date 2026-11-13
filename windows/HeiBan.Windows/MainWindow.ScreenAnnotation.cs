using HeiBan.Windows.Engine;
using HeiBan.Windows.ScreenAnnotation;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Graphics;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private ScreenAnnotationWindow? _screenAnnotation;
    private bool _screenStarting;
    private Task StartScreenAnnotationAsync()=>StartScreenAnnotationAsync(false);
    private MenuFlyoutItem CreateScreenRegionMenuItem()
    {
        var item=new MenuFlyoutItem{Text=T("螢幕畫布（區域）"),Icon=Views.ToolIcons.CreateMenuIcon("screen")};
        item.Click+=async(_,_)=>await StartScreenAnnotationAsync(true);
        return item;
    }
    private void ScreenCanvasMenu_Click(object sender,RoutedEventArgs e)
    {
        if(sender is not FrameworkElement anchor)return;
        var menu=new MenuFlyout();
        var full=new MenuFlyoutItem{Text=T("螢幕畫布"),Icon=Views.ToolIcons.CreateMenuIcon("screen")};
        full.Click+=async(_,_)=>await StartScreenAnnotationAsync();
        menu.Items.Add(full);
        menu.Items.Add(CreateScreenRegionMenuItem());
        ShowExclusiveFlyout(menu,anchor);
    }
    private CancellationTokenSource? _screenRegionSelection;
    private async Task StartScreenAnnotationAsync(bool selectRegion)
    {
        if(_screenStarting)return;_screenStarting=true;
        try
        {
            if(_screenAnnotation?.IsActive==true){await _screenAnnotation.StartAsync();return;}
            FinishText();CommitPropertyEdit();CancelGesture();CancelScreenshotCapture("開始螢幕畫布");
            if(_preparingClose||_saveBoundaryBusy)return;
            if(_workspaceOpen&&!await SaveBeforeLeavingAsync())return;
            RectInt32? region=null;
            if(selectRegion)
            {
                using var cancellation=new CancellationTokenSource(TimeSpan.FromMinutes(1));
                _screenRegionSelection=cancellation;
                try{region=await RegionScreenshotService.PickBoundsAsync(cancellation.Token);}
                finally{_screenRegionSelection=null;}
                if(region is null||_preparingClose||_closing)return;
            }
            EnsureScreenAnnotation();await _screenAnnotation!.StartAsync(region);
        }
        catch(OperationCanceledException) when(selectRegion){}
        catch(Exception e){await Error(e);}
        finally{_screenStarting=false;}
    }
    private void EnsureScreenAnnotation()
    {
        _screenAnnotation??=new ScreenAnnotationWindow(this,_storage.DataDirectory,StartScreenAnnotationAsync,_laser);
    }
}
