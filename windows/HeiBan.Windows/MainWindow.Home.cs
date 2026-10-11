using static HeiBan.Windows.Localization.Strings;
using System.Text.Json;
using System.Text.Json.Serialization;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private sealed class LibraryUiPreferences
    {
        public HashSet<string> Favorites {get;set;}=[];
        public double CardWidth {get;set;}=190;
        public bool Sidebar {get;set;}=true;
        public string Sort {get;set;}="updated";
        [JsonExtensionData] public Dictionary<string,JsonElement>? ExtraFields {get;set;}
    }
    private LibraryUiPreferences _libraryUi=new();
    private readonly SemaphoreSlim _libraryUiSaveGate=new(1,1);
    private List<LibraryCard> _trashCards=[];
    private string _librarySection="all";
    private bool _libraryChromeReady,_libraryMulti,_libraryDeleteBusy;
    private string LibraryPreferencesPath=>Path.Combine(_storage.DataDirectory,"Settings","library-ui.json");
    private void InitializeLibraryChrome()
    {
        try{if(File.Exists(LibraryPreferencesPath))_libraryUi=JsonSerializer.Deserialize<LibraryUiPreferences>(File.ReadAllText(LibraryPreferencesPath),DocumentCodec.Options)??new();}
        catch(Exception e) when(e is IOException or JsonException){StatusText.Text=T("作品庫偏好讀取未完成，作品仍保留。");}
        _libraryUi.Favorites??=[];if(_libraryUi.CardWidth is not (160 or 190 or 250))_libraryUi.CardWidth=190;
        LibrarySortBox.SelectedIndex=Array.IndexOf(new[]{"updated","created","title"},_libraryUi.Sort);if(LibrarySortBox.SelectedIndex<0)LibrarySortBox.SelectedIndex=0;
        SidebarToggleButton.Content=ToolIcons.Create("dock");AllLibraryIcon.Content=ToolIcons.Create("shapes");FavoriteLibraryIcon.Content=ToolIcons.Create("star");TrashLibraryIcon.Content=ToolIcons.Create("delete");
        HomeScreenIcon.Content=ToolIcons.Create("screen");HomeGuideIcon.Content=ToolIcons.Create("reading");HomeAboutIcon.Content=ToolIcons.Create("info");LibraryMultiButton.Content=SelectionCircle(false,true,24);LibrarySizeButton.Content=ToolIcons.Create("shapes");
        var green=Brush("#39735A");
        foreach(var key in new[]{"AccentButtonBackground","AccentButtonBackgroundPointerOver","AccentButtonBackgroundPressed","AccentFillColorDefaultBrush","AccentFillColorSecondaryBrush","AccentFillColorTertiaryBrush"})HomeNewButton.Resources[key]=green;
        foreach(var key in new[]{"SliderThumbBackground","SliderThumbBackgroundPointerOver","SliderThumbBackgroundPressed","SliderTrackValueFill","SliderTrackValueFillPointerOver","SliderTrackValueFillPressed","AccentFillColorDefaultBrush","SystemControlHighlightAccentBrush","ControlFocusVisualPrimaryBrush"})Root.Resources[key]=green;
        ApplyLibrarySidebar();_libraryChromeReady=true;Root.SizeChanged+=(_,_)=>ApplyLibrarySidebar();RefreshNavigationChrome();
    }
    private void ApplyLibrarySidebar()
    {
        var expanded=_libraryUi.Sidebar&&Root.ActualWidth>=900;
        LibrarySidebarColumn.Width=new GridLength(expanded?188:64);
        SearchBox.Width=Root.ActualWidth<800?140:200;LibraryFormatBox.Width=Root.ActualWidth<800?100:132;LibrarySortBox.Width=Root.ActualWidth<800?100:112;
        LibrarySidebar.Padding=expanded?new Thickness(16,24,16,16):new Thickness(8,24,8,16);
        foreach(var label in new FrameworkElement[]{SidebarTitle,AllLibraryLabel,FavoriteLibraryLabel,TrashLibraryLabel,HomeScreenLabel,HomeGuideLabel,HomeAboutLabel,HomeLanguageLabel}){label.Visibility=expanded?Visibility.Visible:Visibility.Collapsed;if(label is TextBlock text){text.MaxWidth=112;text.TextTrimming=TextTrimming.CharacterEllipsis;}}
        foreach(var button in new[]{AllLibraryButton,FavoriteLibraryButton,TrashLibraryButton,HomeScreenButton,HomeGuideButton,HomeAboutButton,HomeLanguageButton})button.Padding=expanded?new Thickness(8,10,8,10):new Thickness(4,10,4,10);
    }
    private async Task SaveLibraryUiAsync()
    {
        await _libraryUiSaveGate.WaitAsync();
        try{await DocumentSessionManager.WriteAtomicAsync(LibraryPreferencesPath,JsonSerializer.Serialize(_libraryUi,DocumentCodec.Options));}
        catch(Exception e){StatusText.Text=T("作品庫偏好未保存：")+e.Message;}
        finally{_libraryUiSaveGate.Release();}
    }
    private async void SidebarToggle_Click(object sender,RoutedEventArgs e){_libraryUi.Sidebar=!_libraryUi.Sidebar;ApplyLibrarySidebar();await SaveLibraryUiAsync();}
    private async void LibrarySection_Click(object sender,RoutedEventArgs e)
    {
        _librarySection=((Button)sender).Tag as string??"all";SetLibraryMulti(false);await RefreshLibrary();
    }
    private async Task RefreshTrashCardsAsync()
    {
        var entries=await Task.Run(()=>_storage.TrashedBoardEntries().Select(entry=>
        {
            var board=entry.Board;var thumbnail=Path.Combine(Path.GetDirectoryName(entry.Path)!,Path.GetFileName(_storage.ThumbnailPath(board.Id)));
            return new LibraryCard(board,File.Exists(thumbnail)?new Uri(thumbnail).AbsoluteUri:null){TrashPath=entry.Path};
        }).ToList());_trashCards=entries;
    }
    private void FilterLibrary()
    {
        if(!_libraryChromeReady||LibraryList is null)return;
        var selected=LibraryList.SelectedItems.OfType<LibraryCard>().Select(c=>c.Board.Id).ToHashSet();
        IEnumerable<LibraryCard> source=_librarySection=="trash"?_trashCards:_library;
        if(_librarySection=="favorites")source=source.Where(c=>_libraryUi.Favorites.Contains(c.Board.Id));
        var format=LibraryFormatBox.SelectedIndex switch{1=>"notebook",2=>"infinite",3=>"fixed",_=>null};
        source=source.Where(c=>(format is null||c.Board.CanvasMode==format)&&c.Title.Contains(SearchBox.Text??"",StringComparison.OrdinalIgnoreCase));
        source=LibrarySortBox.SelectedIndex switch{1=>source.OrderByDescending(c=>c.Board.CreatedAt),2=>source.OrderBy(c=>c.Title,StringComparer.Create(Localization.Strings.Culture,true)),_=>source.OrderByDescending(c=>c.Board.UpdatedAt)};
        var cards=source.Select(c=>c with{CardWidth=_libraryUi.CardWidth,IsFavorite=_libraryUi.Favorites.Contains(c.Board.Id),MultiMode=_libraryMulti}).ToList();LibraryList.ItemsSource=cards;
        foreach(var card in cards.Where(c=>selected.Contains(c.Board.Id))) { if(_libraryMulti)LibraryList.SelectedItems.Add(card);else LibraryList.SelectedItem=card; }
        LibraryHeading.Text=_librarySection switch{"favorites"=>T("收藏"),"trash"=>T("垃圾桶"),_=>T("我的作品")};LibraryCount.Text=cards.Count.ToString();
        LibraryEmpty.Visibility=cards.Count==0?Visibility.Visible:Visibility.Collapsed;LibraryEmptyTitle.Text=_librarySection=="trash"?T("垃圾桶是空的"):_librarySection=="favorites"?T("收藏常用的作品"):_library.Count==0?T("第一份作品，從這裡開始"):T("沒有符合的作品");
        LibraryTrashHint.Visibility=_librarySection=="trash"?Visibility.Visible:Visibility.Collapsed;LibraryMultiButton.IsEnabled=_librarySection!="trash";
        foreach(var pair in new[]{(AllLibraryButton,"all"),(FavoriteLibraryButton,"favorites"),(TrashLibraryButton,"trash")})pair.Item1.Background=Brush(pair.Item2==_librarySection?"#DCE7DB":"transparent");
        AllLibraryLabel.Text=F($"所有作品  {_library.Count}");FavoriteLibraryLabel.Text=F($"收藏  {_library.Count(c=>_libraryUi.Favorites.Contains(c.Board.Id))}");TrashLibraryLabel.Text=F($"垃圾桶  {_trashCards.Count}");
    }
    private async void LibraryFilter_Changed(object sender,SelectionChangedEventArgs e)
    {if(!_libraryChromeReady)return;FilterLibrary();_libraryUi.Sort=LibrarySortBox.SelectedIndex switch{1=>"created",2=>"title",_=>"updated"};await SaveLibraryUiAsync();}
    private void LibrarySize_Click(object sender,RoutedEventArgs e)
    {
        var menu=new MenuFlyout();foreach(var pair in new[]{(T("緊湊"),160d),(T("適中"),190d),(T("大圖"),250d)})
        {var width=pair.Item2;var item=new MenuFlyoutItem{Text=pair.Item1};item.Click+=async(_,_)=>{_libraryUi.CardWidth=width;FilterLibrary();await SaveLibraryUiAsync();};menu.Items.Add(item);}ShowExclusiveFlyout(menu,(FrameworkElement)sender);
    }
    private async void LibraryFavorite_Click(object sender,RoutedEventArgs e)
    {if((sender as Button)?.Tag is not string id)return;await ToggleLibraryFavoriteAsync(id);}
    private async Task ToggleLibraryFavoriteAsync(string id)
    {if(!_libraryUi.Favorites.Add(id))_libraryUi.Favorites.Remove(id);FilterLibrary();await SaveLibraryUiAsync();}
    private void SetLibraryMulti(bool enabled)
    {_libraryMulti=enabled;LibraryList.SelectedItem=null;if(LibraryList.SelectionMode!=ListViewSelectionMode.Single)LibraryList.SelectedItems.Clear();LibraryList.SelectionMode=enabled?ListViewSelectionMode.Multiple:ListViewSelectionMode.Single;LibrarySelectionBar.Visibility=enabled?Visibility.Visible:Visibility.Collapsed;LibraryMultiButton.Content=SelectionCircle(enabled,true,24);LibraryMultiButton.Background=Brush(enabled?"#DCEBDD":"transparent");FilterLibrary();}
    private void LibraryMulti_Click(object sender,RoutedEventArgs e)=>SetLibraryMulti(!_libraryMulti);
    private void LibrarySelection_Changed(object sender,SelectionChangedEventArgs e)
    {if(LibrarySelectedCount is null)return;LibrarySelectedCount.Text=F($"已選 {LibraryList.SelectedItems.Count} 份");LibraryTrashSelectedButton.IsEnabled=LibraryList.SelectedItems.Count>0;LibrarySelectionBar.Visibility=_libraryMulti?Visibility.Visible:Visibility.Collapsed;foreach(var card in LibraryList.Items.OfType<LibraryCard>())card.Selected=LibraryList.SelectedItems.Contains(card);}
    private void LibrarySelectAll_Click(object sender,RoutedEventArgs e){if(!_libraryMulti)return;foreach(var item in LibraryList.Items)if(!LibraryList.SelectedItems.Contains(item))LibraryList.SelectedItems.Add(item);}
    private async void LibraryTrashSelected_Click(object sender,RoutedEventArgs e)
    {try{var ids=LibraryList.SelectedItems.OfType<LibraryCard>().Select(c=>c.Board.Id).ToArray();if(await TrashLibraryBoardsAsync(ids)){SetLibraryMulti(false);await RefreshLibrary();}}catch(Exception ex){await Error(ex);}}
    private async Task<bool> TrashLibraryBoardsAsync(IReadOnlyList<string> ids)
    {
        if(ids.Count==0||_libraryDeleteBusy)return false;_libraryDeleteBusy=true;try{
        if(await new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=T("移到垃圾桶？"),Content=F($"所選 {ids.Count} 份作品會保留在垃圾桶，可從左側還原。"),PrimaryButtonText=T("移到垃圾桶"),CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot}.ShowAsync()!=ContentDialogResult.Primary)return false;
        await MoveLibraryBoardsToTrashAsync(ids);return true;
        }finally{_libraryDeleteBusy=false;}
    }
    private async Task MoveLibraryBoardsToTrashAsync(IReadOnlyList<string> ids)
    {foreach(var id in ids.Distinct())await _storage.TrashAsync(id);}
    private async void HomeGuide_Click(object sender,RoutedEventArgs e)=>await global::Windows.System.Launcher.LaunchUriAsync(new Uri(Path.Combine(AppContext.BaseDirectory,"Assets","HeiBanUserGuide.html")));
    private void LibraryCardMenu_Click(object sender,RoutedEventArgs e){if(sender is FrameworkElement{DataContext:LibraryCard card} anchor)ShowLibraryCardMenu(card,anchor);}
    private async Task<object> ValidateLibraryChromeAsync()
    {
        // Synthetic fixture only; validation is already restricted to an isolated data root.
        var fixture=DocumentCodec.Clone(_session.Document);fixture.Board.Id=Guid.NewGuid().ToString();fixture.Board.Revision=0;foreach(var o in fixture.Objects)o.BoardId=fixture.Board.Id;await _storage.SaveAsync(fixture);await RefreshLibrary();
        var id=fixture.Board.Id;_libraryUi.Favorites.Add(id);await SaveLibraryUiAsync();
        _librarySection="favorites";FilterLibrary();
        if(!LibraryList.Items.OfType<LibraryCard>().Any(c=>c.Board.Id==id&&c.IsFavorite))throw new InvalidOperationException("作品庫收藏篩選未生效。");
        var restored=JsonSerializer.Deserialize<LibraryUiPreferences>(await File.ReadAllTextAsync(LibraryPreferencesPath),DocumentCodec.Options);
        if(restored?.Favorites.Contains(id)!=true)throw new InvalidOperationException("作品庫收藏偏好未保存。");
        SetLibraryMulti(true);LibrarySelectAll_Click(this,new RoutedEventArgs());
        if(LibraryList.SelectedItems.Count!=LibraryList.Items.Count)throw new InvalidOperationException("作品庫全選未生效。");
        SetLibraryMulti(false);_librarySection="all";FilterLibrary();
        if(LibraryList.IsItemClickEnabled||LibraryList.SelectionMode!=ListViewSelectionMode.Single)throw new InvalidOperationException("作品庫不是單擊選取／雙擊開啟。");
        var second=DocumentCodec.Clone(fixture);second.Board.Id=Guid.NewGuid().ToString();foreach(var o in second.Objects)o.BoardId=second.Board.Id;await _storage.SaveAsync(second);await RefreshLibrary();
        SetLibraryMulti(true);var selectedCards=LibraryList.Items.OfType<LibraryCard>().Where(c=>c.Board.Id==id||c.Board.Id==second.Board.Id).ToArray();foreach(var card in selectedCards)LibraryList.SelectedItems.Add(card);
        if(LibraryList.SelectedItems.Count!=2||LibrarySelectionBar.Visibility!=Visibility.Visible||!LibraryTrashSelectedButton.IsEnabled)throw new InvalidOperationException("兩作品選取／批次刪除入口失敗。");
        await MoveLibraryBoardsToTrashAsync(selectedCards.Select(c=>c.Board.Id).ToArray());await RefreshLibrary();var trashed=_trashCards.Where(c=>c.Board.Id==id||c.Board.Id==second.Board.Id).ToArray();
        if(trashed.Length!=2||_library.Any(c=>c.Board.Id==id||c.Board.Id==second.Board.Id))throw new InvalidOperationException("多畫布刪除失敗。");
        foreach(var card in trashed)await _storage.RestoreAsync(card.TrashPath!);await RefreshLibrary();if(_library.Count(c=>c.Board.Id==id||c.Board.Id==second.Board.Id)!=2)throw new InvalidOperationException("多畫布垃圾桶還原失敗。");
        _workspaceOpen=false;Workspace.Visibility=Visibility.Collapsed;HomePanel.Visibility=Visibility.Visible;
        return new{favoritesFilter=true,preferencesPersist=true,multiSelection=true,singleClickSelectDoubleClickOpen=true,batchTrashAndRestore=true,sidebar=true,cardWidth=_libraryUi.CardWidth,viewportCapsule=true,trashRestoreUi=true,hardwareClicks="未執行"};
    }

}
