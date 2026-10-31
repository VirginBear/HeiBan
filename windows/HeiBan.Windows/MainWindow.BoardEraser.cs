using HeiBan.Windows.Engine;
using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using global::Windows.Foundation;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private EditorSession? _boardEraserDraft;
    private Point _boardEraserLast;
    private Point _boardEraserGripOffset;
    private uint _boardEraserPointer;
    private bool _boardEraserWhole;
    private bool _boardEraserTransformApplied,_boardEraserGpuPreview;
    private readonly List<InkPoint> _boardEraserPending=[];
    private BoardEraserWork? _boardEraserWorking;
    private Task? _boardEraserWorkTask,_boardEraserCompletion;
    private bool _boardEraserFinishing;
    private long _boardEraserEpoch,_boardEraserBaseGeneration,_boardEraserDocumentEpoch;
    private readonly Microsoft.UI.Xaml.Media.TranslateTransform _boardEraserTranslation=new();
    private double _boardEraserDockX,_boardEraserDockY;
    private async Task SetBoardEraserVisibleAsync(bool visible)
    {
        var previous=_toolbarPrefs.BoardEraserVisible;
        if(previous==visible)return;
        _toolbarPrefs.BoardEraserVisible=visible;
        try
        {
            await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,_toolbarPrefs);
            if(!visible)CancelBoardEraser();
        }
        catch(Exception ex){_toolbarPrefs.BoardEraserVisible=previous;await Error(ex);}
        finally{RefreshBoardEraser();}
    }
    private void RefreshBoardEraser()
    {
        if(BoardEraserDock is null)return;
        RefreshCaneQuick();
        if(!_boardEraserTransformApplied)
        {
            var t=BoardEraserGeometry.ImageTransform;
            BoardEraserImage.RenderTransform=new Microsoft.UI.Xaml.Media.MatrixTransform
            {Matrix=new Microsoft.UI.Xaml.Media.Matrix{M11=t.M11,M12=t.M12,M21=t.M21,M22=t.M22,OffsetX=t.M31,OffsetY=t.M32}};
            var contact=BoardEraserGeometry.ContactAt(0,0);
            var figure=new Microsoft.UI.Xaml.Media.PathFigure{StartPoint=new Point(contact[0].X,contact[0].Y),IsClosed=true,IsFilled=true};
            foreach(var point in contact.Skip(1))figure.Segments.Add(new Microsoft.UI.Xaml.Media.LineSegment{Point=new Point(point.X,point.Y)});
            var hit=new Microsoft.UI.Xaml.Media.PathGeometry();hit.Figures.Add(figure);BoardEraserHitSurface.Data=hit;
            _boardEraserTransformApplied=true;
        }
        BoardEraserDock.Width=BoardEraserGeometry.DisplayWidth;BoardEraserDock.Height=BoardEraserGeometry.DisplayHeight;
        BoardEraserDock.Visibility=_toolbarPrefs.BoardEraserVisible?Visibility.Visible:Visibility.Collapsed;
    }
    private void BoardEraser_Pressed(object sender,PointerRoutedEventArgs e)
    {
        if(!CanvasSurface.IsRenderingAvailable){e.Handled=true;return;}
        if(_boardEraserDraft is not null||_circularEraser is not null)return;
        var pointer=e.GetCurrentPoint(DrawingArea);if(!pointer.Properties.IsLeftButtonPressed||_readingMode)return;
        var grip=e.GetCurrentPoint(BoardEraserDock).Position;
        if(!BoardEraserGeometry.CanGrab(grip.X,grip.Y))return;
        _boardEraserGripOffset=grip;
        _boardEraserDockX=Canvas.GetLeft(BoardEraserDock);_boardEraserDockY=Canvas.GetTop(BoardEraserDock);
        BoardEraserDock.RenderTransform=_boardEraserTranslation;
        FinishText();CommitPropertyEdit();if(_gesture)CancelGesture();_polygon.Clear();_preview=null;_lineAnchor=null;
        _session.SelectedId=null;_objectDetailsId=null;SelectionBar.Visibility=Visibility.Collapsed;Inspector.Visibility=Visibility.Collapsed;
        // The main document and its undo history stay untouched during pointer movement.
        // Only the draft is rendered; release installs its object list in one transaction.
        _boardEraserDraft=new EditorSession();_boardEraserDraft.Open(_session.Document); // Read-only until the isolated worker publishes its first result.
        _boardEraserWhole=EraserModeBox.SelectedIndex==0;_boardEraserPointer=pointer.PointerId;_boardEraserLast=pointer.Position;
        _boardEraserEpoch++;_boardEraserBaseGeneration=_session.Generation;_boardEraserDocumentEpoch=_session.DocumentEpoch;
        _boardEraserWorking=new BoardEraserWork(DocumentCodec.Clone(_session.Document),
            new ViewportTransform{X=_viewport.X,Y=_viewport.Y,Zoom=_viewport.Zoom},grip.X,grip.Y,_boardEraserWhole);
        _boardEraserPending.Clear();_boardEraserWorkTask=_boardEraserCompletion=null;_boardEraserFinishing=false;
        BoardEraserDock.CapturePointer(e.Pointer);BoardEraserDock.Opacity=.78;
        _boardEraserGpuPreview=_renderer.HasBoardEraserArt;BoardEraserImage.Opacity=_boardEraserGpuPreview?0:1;
        MoveBoardEraser(pointer.Position);QueueBoardEraserPoint(pointer.Position);e.Handled=true;
    }
    private void MoveBoardEraser(Point point)
    {_boardEraserTranslation.X=point.X-_boardEraserGripOffset.X-_boardEraserDockX;_boardEraserTranslation.Y=point.Y-_boardEraserGripOffset.Y-_boardEraserDockY;}
    private InkPoint[] BoardEraserContact(Point pointer)=>BoardEraserGeometry.ContactAt(pointer.X-_boardEraserGripOffset.X,pointer.Y-_boardEraserGripOffset.Y);
    private void QueueBoardEraserPoint(Point point)
    {
        _boardEraserPending.Add(new(point.X,point.Y));
        PumpBoardEraser();PresentInteraction();
    }
    private void PumpBoardEraser()
    {
        if(_boardEraserWorking is null||_boardEraserFinishing||_boardEraserPending.Count==0||_boardEraserWorkTask?.IsCompleted==false)return;
        _boardEraserWorkTask=DrainBoardEraserAsync();
    }
    private async Task DrainBoardEraserAsync()
    {
        var epoch=_boardEraserEpoch;
        do{await ApplyBoardEraserBatchAsync();}while(epoch==_boardEraserEpoch&&!_boardEraserFinishing&&_boardEraserPending.Count>0);
    }
    private async Task ApplyBoardEraserBatchAsync()
    {
        var working=_boardEraserWorking;if(working is null||_boardEraserPending.Count==0)return;
        var epoch=_boardEraserEpoch;var points=_boardEraserPending.ToArray();_boardEraserPending.Clear();
        try
        {
            var snapshot=await Task.Run(()=>working.Apply(points));
            if(epoch!=_boardEraserEpoch||_boardEraserDraft is null||snapshot is null)return;
            _boardEraserDraft.Open(snapshot);
            _renderer.Prune(snapshot.Objects);PresentInteraction(true);
        }
        catch(Exception error)
        {
            if(epoch==_boardEraserEpoch){CancelBoardEraser();await Error(error);}
        }
    }
    private void BoardEraser_Moved(object sender,PointerRoutedEventArgs e)
    {
        if(!CanvasSurface.IsRenderingAvailable){CancelBoardEraser();e.Handled=true;return;}
        using var trace=InputLatencyTrace.Measure(InputStage.EraserMove);
        if(_boardEraserDraft is null||_boardEraserFinishing||e.Pointer.PointerId!=_boardEraserPointer)return;
        var point=e.GetCurrentPoint(DrawingArea).Position;
        MoveBoardEraser(point);_boardEraserLast=point;
        QueueBoardEraserPoint(point);e.Handled=true;
    }
    private async void BoardEraser_Released(object sender,PointerRoutedEventArgs e)
    {
        if(_boardEraserDraft is null||_boardEraserFinishing||e.Pointer.PointerId!=_boardEraserPointer)return;
        BoardEraser_Moved(sender,e);e.Handled=true;await CompleteBoardEraserAsync();
    }
    private Task CompleteBoardEraserAsync()=>_boardEraserCompletion??=CompleteBoardEraserCoreAsync();
    private async Task CompleteBoardEraserCoreAsync()
    {
        if(_boardEraserDraft is null)return;
        var epoch=_boardEraserEpoch;var working=_boardEraserWorking;
        _boardEraserFinishing=true;
        try
        {
            if(_boardEraserWorkTask is { } running)await running;
            while(epoch==_boardEraserEpoch&&_boardEraserPending.Count>0)await ApplyBoardEraserBatchAsync();
            if(epoch!=_boardEraserEpoch||_boardEraserDraft is null)return;
            if(working?.Changed==true&&_session.Generation==_boardEraserBaseGeneration&&_session.DocumentEpoch==_boardEraserDocumentEpoch)
            {
                using var trace=InputLatencyTrace.Measure(InputStage.EraserCommit);
                _session.Begin();_session.Document.Objects=_boardEraserDraft.Document.Objects;_session.Commit();
            }
        }
        finally
        {
            if(epoch==_boardEraserEpoch)
            {
                _boardEraserDraft=null;_boardEraserWorking=null;_boardEraserPending.Clear();
                _boardEraserTranslation.X=_boardEraserTranslation.Y=0;
                BoardEraserDock.ReleasePointerCaptures();_boardEraserFinishing=false;BoardEraserDock.Opacity=1;BoardEraserImage.Opacity=1;_boardEraserGpuPreview=false;RefreshBoardEraser();RefreshEditor();
            }
        }
    }
    private void BoardEraser_Canceled(object sender,PointerRoutedEventArgs e)
    {if(!_boardEraserFinishing)CancelBoardEraser();}
    private void CancelBoardEraser()
    {if(_boardEraserDraft is null)return;_boardEraserEpoch++;_boardEraserWorking?.Cancel();_boardEraserWorking=null;_boardEraserDraft=null;_boardEraserPending.Clear();_boardEraserFinishing=false;_boardEraserTranslation.X=_boardEraserTranslation.Y=0;BoardEraserDock.ReleasePointerCaptures();BoardEraserDock.Opacity=1;BoardEraserImage.Opacity=1;_boardEraserGpuPreview=false;RefreshBoardEraser();InvalidateCanvas();}
    private void BoardEraser_RightTapped(object sender,RightTappedRoutedEventArgs e)
    {
        var menu=new MenuFlyout();
        foreach(var (label,index) in new[]{("物件擦除（筆畫與圖形）",0),("局部擦除（只擦筆跡）",1)})
        {var item=new ToggleMenuFlyoutItem{Text=T(label),IsChecked=EraserModeBox.SelectedIndex==index};item.Click+=(_,_)=>EraserModeBox.SelectedIndex=index;menu.Items.Add(item);}
        var hide=new MenuFlyoutItem{Text=T("隱藏板擦")};hide.Click+=async(_,_)=>await SetBoardEraserVisibleAsync(false);menu.Items.Add(hide);
        ShowExclusiveFlyout(menu,BoardEraserDock);e.Handled=true;
    }
}
