using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.ScreenAnnotation;
using Microsoft.UI.Xaml;
using global::Windows.Storage.Streams;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private ScreenAnnotationWindow? _screenAnnotation;
    private string? _screenSourceBoard,_screenSourcePage;
    private InkPoint _screenTarget=new(0,0);
    private bool _screenStarting;
    private async void ScreenCanvas_Click(object sender,RoutedEventArgs e)=>await StartScreenAnnotationAsync();
    private async Task StartScreenAnnotationAsync()
    {
        if(_screenStarting)return;_screenStarting=true;
        try
        {
            if(_screenAnnotation?.IsActive==true){await _screenAnnotation.StartAsync();return;}
            FinishText();CommitPropertyEdit();CancelGesture();CancelScreenshotCapture("開始螢幕畫布");
            if(_workspaceOpen&&_session.IsDirty&&!await SaveAsync())return;
            _screenSourceBoard=_workspaceOpen?_session.Document.Board.Id:null;
            _screenSourcePage=_workspaceOpen?_session.Document.Board.ActivePageId:null;
            _screenTarget=_viewport.ScreenToWorld(CanvasSurface.ActualWidth/2,CanvasSurface.ActualHeight/2);
            EnsureScreenAnnotation();await _screenAnnotation!.StartAsync();
        }
        catch(Exception e){await Error(e);}
        finally{_screenStarting=false;}
    }
    private void EnsureScreenAnnotation()
    {
        _screenAnnotation??=new ScreenAnnotationWindow(this,_storage.DataDirectory,StartScreenAnnotationAsync,InsertScreenCaptureAsync);
    }
    private async Task InsertScreenCaptureAsync(byte[] bytes)
    {
        if(_screenSourceBoard is null)
        {
            // A home-launched session has no source document: create an explicit new board for its result.
            var doc=new HeiBanDocument { Board=new BoardMetadata { Title="螢幕註記截圖",CanvasMode="infinite",BackgroundColor="#FFFFFF",BoardTheme="whiteboard",GridStyle="blank" } };
            await _storage.SaveAsync(doc);await OpenAsync(doc);
            _screenSourceBoard=doc.Board.Id;_screenSourcePage=null;
            _screenTarget=_viewport.ScreenToWorld(CanvasSurface.ActualWidth/2,CanvasSurface.ActualHeight/2);
        }
        if(!_workspaceOpen||_session.Document.Board.Id!=_screenSourceBoard||_session.Document.Board.ActivePageId!=_screenSourcePage)
            throw new InvalidOperationException("原作品或頁面已改變，截圖未置入。");
        using var stream=new InMemoryRandomAccessStream();
        using(var writer=new DataWriter(stream.GetOutputStreamAt(0))){writer.WriteBytes(bytes);await writer.StoreAsync();await writer.FlushAsync();writer.DetachStream();}
        stream.Seek(0);
        if(!await InsertImageStreamAsync(stream,_screenTarget,true,expectedBoardId:_screenSourceBoard,expectedPageId:_screenSourcePage))
            throw new InvalidOperationException("圖片未加入原作品。");
        await SaveAsync();
    }
}
