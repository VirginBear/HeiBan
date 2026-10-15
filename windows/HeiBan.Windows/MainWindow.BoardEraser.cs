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
    private Point _boardEraserGripOffset;
    private uint _boardEraserPointer;
    private bool _boardEraserWhole;
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
        BoardEraserDock.Width=BoardEraserGeometry.DisplayWidth;BoardEraserDock.Height=BoardEraserGeometry.DisplayHeight;
        BoardEraserDock.Visibility=_toolbarPrefs.BoardEraserVisible?Visibility.Visible:Visibility.Collapsed;
        if(_boardEraserDraft is null)
        {Canvas.SetLeft(BoardEraserDock,Math.Max(0,DrawingArea.ActualWidth-BoardEraserGeometry.DisplayWidth-20));Canvas.SetTop(BoardEraserDock,Math.Max(0,DrawingArea.ActualHeight-BoardEraserGeometry.DisplayHeight-40));}
    }
    private void BoardEraser_Pressed(object sender,PointerRoutedEventArgs e)
    {
        var pointer=e.GetCurrentPoint(DrawingArea);if(!pointer.Properties.IsLeftButtonPressed||_readingMode)return;
        var grip=e.GetCurrentPoint(BoardEraserDock).Position;
        if(!BoardEraserGeometry.CanGrab(grip.X,grip.Y))return;
        _boardEraserGripOffset=grip;
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
    {Canvas.SetLeft(BoardEraserDock,point.X-_boardEraserGripOffset.X);Canvas.SetTop(BoardEraserDock,point.Y-_boardEraserGripOffset.Y);}
    private InkPoint[] BoardEraserContact(Point pointer)=>BoardEraserGeometry.ContactAt(pointer.X-_boardEraserGripOffset.X,pointer.Y-_boardEraserGripOffset.Y);
    private void EraseBoardEraserAt(Point point)
    {
        // Image, outline and contact share screen DIP coordinates; only the contact
        // corners cross into the document's world space. There is no bounding-box erase.
        var world=BoardEraserContact(point).Select(p=>_viewport.ScreenToWorld(p.X,p.Y));
        _boardEraserDraft?.EraseFootprint(new EraserFootprint(world),_boardEraserWhole);
        InvalidateCanvas();
    }
    private void BoardEraser_Moved(object sender,PointerRoutedEventArgs e)
    {
        if(_boardEraserDraft is null||e.Pointer.PointerId!=_boardEraserPointer)return;
        var point=e.GetCurrentPoint(DrawingArea).Position;
        var distance=Math.Sqrt(Math.Pow(point.X-_boardEraserLast.X,2)+Math.Pow(point.Y-_boardEraserLast.Y,2));
        var steps=Math.Max(1,(int)Math.Ceiling(distance/BoardEraserGeometry.SweepStep));
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
        var hide=new MenuFlyoutItem{Text=T("隱藏板擦")};hide.Click+=async(_,_)=>await SetBoardEraserVisibleAsync(false);menu.Items.Add(hide);
        ShowExclusiveFlyout(menu,BoardEraserDock);e.Handled=true;
    }
}
