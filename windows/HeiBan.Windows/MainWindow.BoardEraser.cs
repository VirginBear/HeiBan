using HeiBan.Windows.Engine;
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
    private uint _boardEraserPointer;
    private bool _boardEraserWhole;
    private const double BoardEraserWidth=132,BoardEraserHeight=40;
    private void RefreshBoardEraser()
    {
        if(BoardEraserDock is null)return;
        BoardEraserDock.Visibility=_toolbarPrefs.BoardEraserVisible?Visibility.Visible:Visibility.Collapsed;
        if(_boardEraserDraft is null)
        {Canvas.SetLeft(BoardEraserDock,Math.Max(0,DrawingArea.ActualWidth-164));Canvas.SetTop(BoardEraserDock,Math.Max(0,DrawingArea.ActualHeight-110));}
    }
    private void BoardEraser_Pressed(object sender,PointerRoutedEventArgs e)
    {
        var pointer=e.GetCurrentPoint(DrawingArea);if(!pointer.Properties.IsLeftButtonPressed||_readingMode)return;
        FinishText();CommitPropertyEdit();if(_gesture)CancelGesture();_polygon.Clear();_preview=null;_lineAnchor=null;
        _session.SelectedId=null;_objectDetailsId=null;SelectionBar.Visibility=Visibility.Collapsed;Inspector.Visibility=Visibility.Collapsed;
        // The main document and its undo history stay untouched during pointer movement.
        // Only the draft is rendered; release installs its object list in one transaction.
        _boardEraserDraft=new EditorSession();_boardEraserDraft.Open(DocumentCodec.Clone(_session.Document));
        _boardEraserWhole=EraserModeBox.SelectedIndex==0;_boardEraserPointer=pointer.PointerId;_boardEraserLast=pointer.Position;
        BoardEraserDock.CapturePointer(e.Pointer);BoardEraserDock.Opacity=.78;
        MoveBoardEraser(pointer.Position);EraseBoardEraserAt(pointer.Position);e.Handled=true;
    }
    private void MoveBoardEraser(Point point)
    {Canvas.SetLeft(BoardEraserDock,point.X-72);Canvas.SetTop(BoardEraserDock,point.Y-30);}
    private void EraseBoardEraserAt(Point point)
    {
        var world=_viewport.ScreenToWorld(point.X,point.Y);
        _boardEraserDraft?.EraseRectangle(world,BoardEraserWidth/_viewport.Zoom,BoardEraserHeight/_viewport.Zoom,_boardEraserWhole);
        InvalidateCanvas();
    }
    private void BoardEraser_Moved(object sender,PointerRoutedEventArgs e)
    {
        if(_boardEraserDraft is null||e.Pointer.PointerId!=_boardEraserPointer)return;
        var point=e.GetCurrentPoint(DrawingArea).Position;
        var distance=Math.Sqrt(Math.Pow(point.X-_boardEraserLast.X,2)+Math.Pow(point.Y-_boardEraserLast.Y,2));
        var steps=Math.Max(1,(int)Math.Ceiling(distance/(BoardEraserHeight/4)));
        for(var i=1;i<=steps;i++)EraseBoardEraserAt(new(_boardEraserLast.X+(point.X-_boardEraserLast.X)*i/steps,_boardEraserLast.Y+(point.Y-_boardEraserLast.Y)*i/steps));
        MoveBoardEraser(point);_boardEraserLast=point;e.Handled=true;
    }
    private void BoardEraser_Released(object sender,PointerRoutedEventArgs e)
    {
        if(_boardEraserDraft is null||e.Pointer.PointerId!=_boardEraserPointer)return;
        BoardEraser_Moved(sender,e);var draft=_boardEraserDraft;_boardEraserDraft=null;
        _session.Begin();_session.Document.Objects=draft.Document.Objects;_session.Commit();
        BoardEraserDock.ReleasePointerCaptures();BoardEraserDock.Opacity=1;RefreshBoardEraser();RefreshEditor();e.Handled=true;
    }
    private void BoardEraser_Canceled(object sender,PointerRoutedEventArgs e)
    {CancelBoardEraser();}
    private void CancelBoardEraser()
    {if(_boardEraserDraft is null)return;_boardEraserDraft=null;BoardEraserDock.ReleasePointerCaptures();BoardEraserDock.Opacity=1;RefreshBoardEraser();InvalidateCanvas();}
    private void BoardEraser_RightTapped(object sender,RightTappedRoutedEventArgs e)
    {
        var menu=new MenuFlyout();
        foreach(var (label,index) in new[]{("物件擦除（筆畫與圖形）",0),("局部擦除（只擦筆跡）",1)})
        {var item=new ToggleMenuFlyoutItem{Text=T(label),IsChecked=EraserModeBox.SelectedIndex==index};item.Click+=(_,_)=>EraserModeBox.SelectedIndex=index;menu.Items.Add(item);}
        var hide=new MenuFlyoutItem{Text=T("隱藏板擦")};hide.Click+=async(_,_)=>{_toolbarPrefs.BoardEraserVisible=false;try{await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,_toolbarPrefs);RefreshBoardEraser();}catch(Exception ex){_toolbarPrefs.BoardEraserVisible=true;await Error(ex);}};menu.Items.Add(hide);
        ShowExclusiveFlyout(menu,BoardEraserDock);e.Handled=true;
    }
}
