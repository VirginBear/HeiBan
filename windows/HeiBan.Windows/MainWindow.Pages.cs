using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private void PreparePageChange(){CancelScreenshotCapture("切換頁面");FinishText();CommitPropertyEdit();if(_gesture)CancelGesture();_session.SelectedId=null;}
    private void PagesMenu_Click(object sender,RoutedEventArgs e)
    {
        var menu=new MenuFlyout();var board=_session.Document.Board;var pages=board.Pages??[];
        foreach(var page in pages){var id=page.Id;var item=new MenuFlyoutItem{Text=$"{page.Index+1}. {page.Title}"};item.Click+=(_,_)=>{PreparePageChange();_session.Begin();board.ActivePageId=id;_session.Commit();RefreshEditor();};menu.Items.Add(item);}
        menu.Items.Add(new MenuFlyoutSeparator());
        void Add(string title,Action action,bool enabled=true){var item=new MenuFlyoutItem{Text=title,IsEnabled=enabled};item.Click+=(_,_)=>action();menu.Items.Add(item);}
        Add(T("重新命名目前頁"),RenamePage);Add(T("複製目前頁"),DuplicatePage);Add(T("向前移動"),()=>MovePage(-1));Add(T("向後移動"),()=>MovePage(1));Add(T("刪除目前頁"),DeletePage,pages.Count>1);menu.ShowAt((FrameworkElement)sender);
    }
    private async void RenamePage()
    {
        var page=_session.Document.Board.Pages?.FirstOrDefault(p=>p.Id==_session.Document.Board.ActivePageId);if(page is null)return;PreparePageChange();var board=_session.Document.Board.Id;
        var input=new TextBox{Text=page.Title??"",MaxLength=120};
        if(await new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=T("頁面名稱"),Content=input,PrimaryButtonText=T("儲存"),CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot}.ShowAsync()!=ContentDialogResult.Primary||board!=_session.Document.Board.Id||!(_session.Document.Board.Pages?.Contains(page)??false))return;
        _session.Begin();page.Title=string.IsNullOrWhiteSpace(input.Text)?F($"第 {page.Index+1} 頁"):input.Text.Trim();_session.Commit();RefreshEditor();
    }
    private void DuplicatePage()
    {
        PreparePageChange();var board=_session.Document.Board;var pages=board.Pages??=[];var current=pages.FirstOrDefault(p=>p.Id==board.ActivePageId);if(current is null)return;
        var copies=_session.PageObjects.Select(DocumentCodec.Clone).ToArray();_session.Begin();var next=DocumentCodec.Clone(current);next.Id=Guid.NewGuid().ToString();next.Title=(current.Title??T("頁面"))+T(" 副本");pages.Insert(pages.IndexOf(current)+1,next);
        foreach(var o in copies){o.Id=Guid.NewGuid().ToString();o.PageId=next.Id;_session.Document.Objects.Add(o);}for(var i=0;i<pages.Count;i++)pages[i].Index=i;board.ActivePageId=next.Id;_session.Commit();RefreshEditor();
    }
    private void MovePage(int direction)
    {
        PreparePageChange();var pages=_session.Document.Board.Pages??[];var i=pages.FindIndex(p=>p.Id==_session.Document.Board.ActivePageId);var target=i+direction;if(i<0||target<0||target>=pages.Count)return;
        _session.Begin();(pages[i],pages[target])=(pages[target],pages[i]);for(var j=0;j<pages.Count;j++)pages[j].Index=j;_session.Commit();RefreshEditor();
    }
    private async void DeletePage()
    {
        PreparePageChange();var board=_session.Document.Board;var pages=board.Pages??[];var id=board.ActivePageId;var index=pages.FindIndex(p=>p.Id==id);if(index<0||pages.Count<=1)return;
        var result=await new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=T("刪除目前頁面？"),Content=T("頁面與其中物件會一起刪除，可用復原恢復。"),PrimaryButtonText=T("刪除"),CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot}.ShowAsync();
        if(result!=ContentDialogResult.Primary||board!=_session.Document.Board||id!=board.ActivePageId)return;
        _session.Begin();pages.RemoveAt(index);_session.Document.Objects.RemoveAll(o=>o.PageId==id);for(var i=0;i<pages.Count;i++)pages[i].Index=i;board.ActivePageId=pages[Math.Min(index,pages.Count-1)].Id;_session.Commit();RefreshEditor();
    }
    private void ZoomOut_Click(object sender,RoutedEventArgs e)=>SetZoom(_viewport.Zoom/1.15);
    private void ZoomIn_Click(object sender,RoutedEventArgs e)=>SetZoom(_viewport.Zoom*1.15);
    private void SetZoom(double zoom)
    {if(_viewLocked)return;var x=CanvasSurface.ActualWidth/2;var y=CanvasSurface.ActualHeight/2;var center=_viewport.ScreenToWorld(x,y);_viewport.Zoom=Math.Clamp(zoom,.05,8);_viewport.X=x-center.X*_viewport.Zoom;_viewport.Y=y-center.Y*_viewport.Zoom;ZoomText.Text=$"{_viewport.Zoom:P0}";InvalidateCanvas();}
    private void ZoomMenu_Click(object sender,RoutedEventArgs e)
    {
        var menu=new MenuFlyout();void Add(string title,Action action){var item=new MenuFlyoutItem{Text=title,IsEnabled=!_viewLocked};item.Click+=(_,_)=>action();menu.Items.Add(item);}
        Add(T("適合頁面／內容"),()=>{var area=BoardExporter.Bounds(_session.Document.Board,_session.VisibleObjects);_viewport.Zoom=Math.Clamp(Math.Min(Math.Max(1,CanvasSurface.ActualWidth-80)/area.Width,Math.Max(1,CanvasSurface.ActualHeight-80)/area.Height),.05,8);_viewport.X=(CanvasSurface.ActualWidth-area.Width*_viewport.Zoom)/2-area.X*_viewport.Zoom;_viewport.Y=(CanvasSurface.ActualHeight-area.Height*_viewport.Zoom)/2-area.Y*_viewport.Zoom;ZoomText.Text=$"{_viewport.Zoom:P0}";InvalidateCanvas();});
        Add(T("回到原點與 100%"),()=>{_viewport.Zoom=1;_viewport.X=_viewport.Y=0;ZoomText.Text="100%";InvalidateCanvas();});foreach(var value in new[]{25,50,75,100,150,200}){var percent=value;Add($"{percent}%",()=>SetZoom(percent/100d));}
        var locking=new MenuFlyoutItem{Text=_viewLocked?T("解除視角鎖定"):T("鎖定視角")};locking.Click+=(_,_)=>NavigationLock_Click(this,new RoutedEventArgs());menu.Items.Add(locking);menu.ShowAt((FrameworkElement)sender);
    }
    private void NavigationLock_Click(object sender,RoutedEventArgs e)
    {_viewLocked=!_viewLocked;StatusText.Text=_viewLocked?T("視角已鎖定"):T("視角已解鎖");RefreshNavigationChrome();}
    private bool? _navigationLockState,_navigationReadingState;
    private string? _navigationLanguage;
    private Button? _navigationUpperLock;
    private void RefreshNavigationChrome()
    {
        var language=Localization.Strings.Language;var translated=_navigationLanguage!=language;
        var locking=_navigationLockState!=_viewLocked;
        if(locking||translated)
        {
            NavigationLockButton.Content=Views.ToolIcons.Create(_viewLocked?"lock":"unlock");
            NavigationLockButton.Background=Brush(_viewLocked?"#DCEBDD":"transparent");
            ToolTipService.SetToolTip(NavigationLockButton,_viewLocked?T("解除視角鎖定"):T("鎖定視角：避免平移與縮放"));
        }
        if(_navigationReadingState!=_readingMode||translated)
        {
            NavigationReadingButton.Content=Views.ToolIcons.Create(_readingMode?"pen":"reading");
            ToolTipService.SetToolTip(NavigationReadingButton,_readingMode?T("回到編輯模式"):T("閱讀模式：拖曳移動畫布"));
        }
        _toolButtons.TryGetValue("viewLock",out var upper);
        if(upper is not null&&(locking||translated||!ReferenceEquals(upper,_navigationUpperLock)))
        {
            // Updating an icon must retain its text wrapper in labeled mode.
            Views.ToolbarUi.ReplaceIcon(upper,Views.ToolIcons.Create(_viewLocked?"lock":"unlock"));
            upper.Background=Brush(_viewLocked?"#DCEBDD":"#FCFCFA");
            ToolTipService.SetToolTip(upper,_viewLocked?T("解除視角鎖定"):T("鎖定視角：避免平移與縮放"));
        }
        _navigationLockState=_viewLocked;_navigationReadingState=_readingMode;_navigationLanguage=language;_navigationUpperLock=upper;
    }

}
