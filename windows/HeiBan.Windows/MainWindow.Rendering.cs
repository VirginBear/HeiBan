using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.UI.Xaml;
using global::Windows.Foundation;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private CanvasRenderTarget? _scene;
    private bool _sceneDirty=true;
    private readonly record struct SceneKey(HeiBanDocument Document,long Generation,string? Page,double X,double Y,double Zoom,float Width,float Height,float Dpi);
    private SceneKey _sceneKey;
    private long _sceneBuilds;
    private void InvalidateCanvas(bool sceneChanged=true)
    {
        if(sceneChanged)_sceneDirty=true;
        UpdateSaveStatusLight(StatusText.Text);
        CanvasSurface.Invalidate();
    }
    private void ClearScene()
    {_scene?.Dispose();_scene=null;_sceneDirty=true;}
    private void RenderMainScene(CanvasControl surface,CanvasDrawingSession ds,float width,float height)
    {
        if(width<=0||height<=0)return;
        var key=new SceneKey(_session.Document,_session.Generation,_session.Document.Board.ActivePageId,_viewport.X,_viewport.Y,_viewport.Zoom,width,height,surface.Dpi);
        if(_scene is null||_sceneKey.Width!=width||_sceneKey.Height!=height||_sceneKey.Dpi!=surface.Dpi)
        {ClearScene();_scene=new CanvasRenderTarget(surface,width,height,surface.Dpi);}
        if(_sceneDirty||key!=_sceneKey)
        {
            using(var drawing=_scene.CreateDrawingSession())
            {
                var board=_session.Document.Board;
                _renderer.RenderBackground(drawing,board,_viewport,width,height);
                var clip=board.CanvasMode=="infinite"?new Rect(0,0,width,height):new Rect(_viewport.X,_viewport.Y,(board.CanvasWidth??595)*_viewport.Zoom,(board.CanvasHeight??842)*_viewport.Zoom);
                using(var layer=drawing.CreateLayer(1,clip))_renderer.RenderObjects(drawing,_session.DrawingObjects,_viewport,width,height);
            }
            _sceneKey=key;_sceneDirty=false;_sceneBuilds++;
        }
        // Hover, live ink, lasso, ruler and laser are drawn above the committed scene, preserving its object order.
        ds.DrawImage(_scene);
    }
    private HeiBanDocument? _layersDocument;
    private long _layersGeneration=-1;
    private string? _layersPage;
    private void RefreshLayersIfNeeded()
    {
        if(LayersPanel.Visibility!=Microsoft.UI.Xaml.Visibility.Visible)return;
        if(!ReferenceEquals(_layersDocument,_session.Document)||_layersGeneration!=_session.Generation||_layersPage!=_session.Document.Board.ActivePageId)
        {
            _layerPreview?.End();_layerDragId=_layerDropId=null;
            LayerList.ItemsSource=LayerPresentation.Build(_session.PageObjects, Localization.Strings.T).Select(entry=>new LayerCard(entry)).ToList();
            _layersDocument=_session.Document;_layersGeneration=_session.Generation;_layersPage=_session.Document.Board.ActivePageId;
        }
        SyncLayerSelection();
    }
    private readonly Microsoft.UI.Xaml.DispatcherTimer _thumbnailTimer=new(){Interval=TimeSpan.FromSeconds(1)};
    private (HeiBanDocument Document,long Epoch)? _pendingThumbnail;
    private readonly Microsoft.UI.Xaml.DispatcherTimer _searchTimer=new(){Interval=TimeSpan.FromMilliseconds(150)};
    private readonly SemaphoreSlim _thumbnailGate=new(1,1);
    private readonly Dictionary<string,long> _thumbnailRevisions=[];
    private void InitializeDeferredWork()
    {
        _thumbnailTimer.Tick+=async(_,_)=>
        {
            _thumbnailTimer.Stop();
            if(_pendingThumbnail is not { } pending)return;
            if(pending.Epoch!=_session.DocumentEpoch){_pendingThumbnail=null;return;}
            if(!AutoSaveEnabled||_preparingClose||_saveBoundaryBusy)return;
            if(_gesture||_editor is not null||_propertyEditing){_thumbnailTimer.Start();return;}
            _pendingThumbnail=null;await SaveThumbnail(pending.Document);
        };
        _searchTimer.Tick+=(_,_)=>{_searchTimer.Stop();if(!_workspaceOpen)FilterLibrary();};
        _teachingSaveTimer.Tick+=async(_,_)=>await SaveTeachingSettingsAsync();
    }
    private void QueueThumbnail(HeiBanDocument snapshot,long epoch)
    {_pendingThumbnail=(snapshot,epoch);_thumbnailTimer.Stop();if(AutoSaveEnabled&&!_preparingClose&&!_saveBoundaryBusy)_thumbnailTimer.Start();}

}
