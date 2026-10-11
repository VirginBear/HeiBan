using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private void Library_ContextRequested(UIElement sender,ContextRequestedEventArgs e)
    {
        var element=e.OriginalSource as FrameworkElement;
        LibraryCard? card=null;
        while(element is not null)
        {
            if(element.DataContext is LibraryCard value){card=value;break;}
            element=Microsoft.UI.Xaml.Media.VisualTreeHelper.GetParent(element) as FrameworkElement;
        }
        if(card is null)return;ShowLibraryCardMenu(card,element??LibraryList);e.Handled=true;
    }
    private void ShowLibraryCardMenu(LibraryCard chosen,FrameworkElement anchor)
    {
        var menu=new MenuFlyout();
        void Add(string title,Func<Task> action)
        {var item=new MenuFlyoutItem{Text=title};item.Click+=async(_,_)=>{try{await action();await RefreshLibrary();}catch(Exception ex){await Error(ex);}};menu.Items.Add(item);}
        if(chosen.TrashPath is { } trash){Add("還原",()=>_storage.RestoreAsync(trash));ShowExclusiveFlyout(menu,anchor);return;}
        Add("開啟作品",async()=>await OpenAsync(await _storage.LoadAsync(chosen.Board.Id)));
        Add(_libraryUi.Favorites.Contains(chosen.Board.Id)?"取消收藏":"加入收藏",()=>ToggleLibraryFavoriteAsync(chosen.Board.Id));
        Add("重新命名",async()=>
        {
            var input=new TextBox{Text=chosen.Title};var dialog=new ContentDialog{Title="作品名稱",Content=input,PrimaryButtonText="儲存",CloseButtonText="取消",XamlRoot=Root.XamlRoot};
            if(await dialog.ShowAsync()!=ContentDialogResult.Primary||string.IsNullOrWhiteSpace(input.Text))return;
            var doc=await _storage.LoadAsync(chosen.Board.Id);doc.Board.Title=input.Text.Trim();await _storage.SaveAsync(doc);
        });
        Add("製作副本",async()=>
        {var doc=await _storage.LoadAsync(chosen.Board.Id);doc.Board.Id=Guid.NewGuid().ToString();doc.Board.Title+=" 副本";doc.Board.Revision=0;
            foreach(var o in doc.Objects)o.BoardId=doc.Board.Id;await _storage.SaveAsync(doc);});
        Add("移到垃圾桶",async()=>{var selected=LibraryList.SelectedItems.OfType<LibraryCard>().ToArray();await TrashLibraryBoardsAsync(selected.Any(c=>c.Board.Id==chosen.Board.Id)?selected.Select(c=>c.Board.Id).ToArray():new[]{chosen.Board.Id});});
        ShowExclusiveFlyout(menu,anchor);
    }
    private async void Trash_Click(object sender,RoutedEventArgs e)
    {
        try
        {
            var entries=await Task.Run(()=>_storage.TrashedBoards().ToList());var list=new ListView{ItemsSource=entries.Select(x=>x.Title).ToList(),SelectionMode=ListViewSelectionMode.Single,MaxHeight=360};
            var dialog=new ContentDialog{Title="垃圾桶",Content=entries.Count==0?new TextBlock{Text="沒有已刪除的作品。"}:list,PrimaryButtonText="還原",CloseButtonText="關閉",XamlRoot=Root.XamlRoot,IsPrimaryButtonEnabled=entries.Count>0};
            if(await dialog.ShowAsync()!=ContentDialogResult.Primary||list.SelectedIndex<0)return;
            await _storage.RestoreAsync(entries[list.SelectedIndex].Path);await RefreshLibrary();
        }catch(Exception ex){await Error(ex);}
    }
}
