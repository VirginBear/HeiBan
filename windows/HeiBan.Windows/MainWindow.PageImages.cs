using HeiBan.Windows.Engine;
using Microsoft.Graphics.Canvas;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private readonly SemaphoreSlim _pageImageGate=new(1,1);
    private (long Epoch,long Generation,string? Page)? _pageImageKey;
    private Task _pageImageLoad=Task.CompletedTask;
    private long _pageImageRequest;

    private Task LoadCurrentPageImagesAsync(ICanvasResourceCreator device,bool resourcesReset=false)
    {
        if(!_workspaceOpen)return Task.CompletedTask;
        var key=(_session.DocumentEpoch,_session.Generation,_session.Document.Board.ActivePageId);
        if(!resourcesReset&&_pageImageKey==key)return _pageImageLoad;
        _pageImageKey=key;
        var request=++_pageImageRequest;
        var sources=Direct2DCanvasRenderer.ImageSources(_session.VisibleObjects).ToHashSet(StringComparer.Ordinal);
        // Retire previous-page GPU bitmaps immediately. Serialized requests bound
        // in-flight decoding to one image during fast page changes.
        _renderer.RetainImages(sources);
        return _pageImageLoad=LoadAsync();

        async Task LoadAsync()
        {
            bool Current()=>request==_pageImageRequest&&_workspaceOpen&&!_closing;
            await _pageImageGate.WaitAsync();
            try
            {
                if(Current())await _renderer.LoadImageSourcesAsync(device,sources,Current);
            }
            catch(Exception error) when(error is not OutOfMemoryException)
            {
                if(!Current())return;
                _pageImageKey=null;
                if(resourcesReset)throw;
                Diagnostics.CanvasSurfaceDiagnostics.Record("load-current-page-images",error);
            }
            finally{_pageImageGate.Release();}
        }
    }
}
