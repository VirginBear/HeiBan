using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.ScreenAnnotation;
using Microsoft.UI.Xaml;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private ScreenAnnotationWindow? _screenAnnotation;
    private bool _screenStarting;
    private async void ScreenCanvas_Click(object sender,RoutedEventArgs e)=>await StartScreenAnnotationAsync();
    private async Task StartScreenAnnotationAsync()
    {
        if(_screenStarting)return;_screenStarting=true;
        try
        {
            if(_screenAnnotation?.IsActive==true){await _screenAnnotation.StartAsync();return;}
            FinishText();CommitPropertyEdit();CancelGesture();CancelScreenshotCapture("開始螢幕畫布");
            if(_preparingClose||_saveBoundaryBusy)return;
            if(_workspaceOpen&&!await SaveBeforeLeavingAsync())return;
            EnsureScreenAnnotation();await _screenAnnotation!.StartAsync();
        }
        catch(Exception e){await Error(e);}
        finally{_screenStarting=false;}
    }
    private void EnsureScreenAnnotation()
    {
        _screenAnnotation??=new ScreenAnnotationWindow(this,_storage.DataDirectory,StartScreenAnnotationAsync,_laser);
    }
}
