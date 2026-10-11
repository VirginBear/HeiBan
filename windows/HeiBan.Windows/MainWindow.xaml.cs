using System.Numerics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using global::Windows.Foundation;
using global::Windows.Storage.Pickers;
using global::Windows.System;

namespace HeiBan.Windows;

public sealed record LibraryCard(BoardMetadata Board, string? Thumbnail) : System.ComponentModel.INotifyPropertyChanged
{
    public event System.ComponentModel.PropertyChangedEventHandler? PropertyChanged;
    public bool MultiMode {get;init;}
    public Visibility SelectionVisibility=>MultiMode?Visibility.Visible:Visibility.Collapsed;
    private bool _selected;
    public bool Selected {get=>_selected;set{_selected=value;PropertyChanged?.Invoke(this,new(nameof(SelectionMark)));}}
    public UIElement SelectionMark=>MainWindow.SelectionCircle(Selected);
    public string Title => Board.Title;
    public string Format => Board.CanvasMode switch {"notebook"=>"筆記本","fixed"=>"有邊界黑板",_=>"無邊界筆記"};
    public UIElement FormatIcon => Views.ToolIcons.Create(Board.CanvasMode switch{"notebook"=>"notebook","fixed"=>"rect",_=>"infinite"});
    public double CardWidth {get;init;}=190;
    public double ThumbnailHeight=>CardWidth*.85;
    public string Background=>Board.BackgroundColor;
    public bool IsFavorite {get;init;}
    public string? TrashPath {get;init;}
    public bool CanFavorite=>TrashPath is null;
    public string FavoriteGlyph=>IsFavorite?"★":"☆";
    public string Summary => DateTimeOffset.TryParse(Board.UpdatedAt,out var date)?date.ToLocalTime().ToString("yyyy/M/d HH:mm"):"本機儲存";
}
public sealed record LayerCard(LayerListEntry Entry)
{
    public string ObjectId => Entry.ObjectId;
    public string Title => Entry.Title;
    public string Description => Entry.Description;
    public UIElement Icon => Views.ToolIcons.Create(Entry.IconKey);
}
public partial class MainWindow : Window
{
    private readonly Direct2DCanvasRenderer _renderer=new();
    private readonly WindowsInkCoordinator _ink=new();
    private readonly ViewportTransform _viewport=new();
    private readonly EditorSession _session=new();
    private readonly DocumentSessionManager _storage;
    private readonly SemaphoreSlim _saveGate=new(1,1);
    private readonly DispatcherTimer _autosave=new(){Interval=TimeSpan.FromSeconds(15)};
    private readonly ScreenshotCaptureCoordinator _screenshotCoordinator=new();
    private readonly DispatcherTimer _screenshotWatchTimer=new(){Interval=TimeSpan.FromMilliseconds(250)};
    private List<LibraryCard> _library=[];
    private string _tool="select", _strokeColor="#24533d", _fillColor="#b8d4b2";
    private double _strokeWidth=4,_opacity=1;
    private bool _workspaceOpen,_closing,_preparingClose,_changingLayers,_readingMode;
    private bool _saveFailed,_saving;
    private Views.TextDraftEditor? _editor;
    private BoardObject? _editingObject;
    private Vector2 _mouse;
    private bool _hover;

    public MainWindow()
    {
        App.StartupStage="建立作品資料夾";
        _storage=new();
        _toolbarPrefs=ToolbarPreferencesStore.Load(_storage.DataDirectory);
        _dock=_toolbarPrefs.DockSide;
        App.StartupStage="載入主視窗 XAML";
        InitializeComponent();
        Root.Loaded+=(_,_)=>_shapeCursor.Attach(WinRT.Interop.WindowNative.GetWindowHandle(this),()=>_hover&&_tool=="select"&&_editor is null&&!_readingMode);
        InitializeLibraryChrome();BuildChrome();InitializeTeachingTools();InitializeDeferredWork();
        App.StartupStage="設定主視窗";
        ExtendsContentIntoTitleBar=true;SetTitleBar(AppTitleBar);SystemBackdrop=new MicaBackdrop();
        AppWindow.TitleBar.ButtonForegroundColor=Direct2DCanvasRenderer.HexToColor("#26372F");
        AppWindow.TitleBar.ButtonBackgroundColor=global::Windows.UI.Color.FromArgb(0,0,0,0);
        AppWindow.TitleBar.ButtonHoverBackgroundColor=Direct2DCanvasRenderer.HexToColor("#DCEBDD");
        AppWindow.TitleBar.ButtonHoverForegroundColor=Direct2DCanvasRenderer.HexToColor("#26372F");
        var display=Microsoft.UI.Windowing.DisplayArea.GetFromWindowId(AppWindow.Id,Microsoft.UI.Windowing.DisplayAreaFallback.Primary).WorkArea;
        var scale=ScreenAnnotation.NativeOverlayWindow.DpiScale(WinRT.Interop.WindowNative.GetWindowHandle(this));
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(Math.Min((int)(1100*scale),display.Width-80),Math.Min((int)(760*scale),display.Height-80)));
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory,"Assets","AppIcon.ico"));
        PortableBadge.Visibility=_storage.IsPortableMode?Visibility.Visible:Visibility.Collapsed;
        _updates=new Updating.GitHubUpdateService(_storage.IsPortableMode);
        _renderer.ResourcesChanged+=()=>InvalidateCanvas();
        _autosave.Tick+=async(_,_)=>{if(_workspaceOpen&&_session.IsDirty&&_editor is null&&!_gesture&&!_propertyEditing&&_saveGate.CurrentCount>0)await SaveAsync(deferThumbnail:true);};
        _autosave.Start();
        _screenshotWatchTimer.Tick+=async(_,_)=>await OnScreenshotWatchTickAsync();
        AppWindow.Closing+=async(_,e)=>
        {
            if(_closing)return;e.Cancel=true;if(_preparingClose)return;_preparingClose=true;
            try
            {
                CancelScreenshotCapture("視窗關閉");FinishText();CommitPropertyEdit();if(_gesture)CancelGesture();
                await SaveTeachingSettingsAsync();
                if(_screenAnnotation?.IsActive==true&&!await _screenAnnotation.StopAsync())return;
                if(_workspaceOpen&&_session.IsDirty&&!await SaveAsync())return;
                if(_updates is not null)await _updates.PrepareExitAsync();
                _closing=true;Close();
            }
            finally{_preparingClose=false;}
        };
        Closed+=(_,_)=>{_layerPreview?.End();_shapeCursor.Dispose();_updates?.Dispose();_autosave.Stop();_thumbnailTimer.Stop();_searchTimer.Stop();_teachingSaveTimer.Stop();CancelScreenshotCapture("視窗關閉");_timerTickTimer?.Stop();_laserTimer.Stop();_propertyCommitTimer.Stop();_headerHideTimer.Stop();ClearScene();CanvasSurface.RemoveFromVisualTree();_renderer.Dispose();_screenAnnotation?.Dispose();};
        App.StartupStage="顯示首頁";
        try { EnsureScreenAnnotation(); } catch(Exception e) { StatusText.Text="螢幕畫布初始化失敗："+e.Message; }
    }
    public async void InitializeAsync(string? file)
    {
        try { if(file is null)await RefreshLibrary();else await OpenAsync(await _storage.ImportAsync(file));
            var validation=Environment.GetCommandLineArgs().FirstOrDefault(arg=>arg.StartsWith("--validation-output=",StringComparison.Ordinal));
            var performance=Environment.GetCommandLineArgs().FirstOrDefault(arg=>arg.StartsWith("--performance-output=",StringComparison.Ordinal));
            if(performance is not null)await RunPerformanceBatchAsync(performance[21..]);
            else if(validation is not null)await RunNativeValidationAsync(validation[20..]);
            else {if(Environment.GetCommandLineArgs().Contains("--screen-canvas"))await StartScreenAnnotationAsync();_updates?.Start();} }
        catch(Exception e){await Error(e);}
    }
    private async Task Error(Exception e)
    {
        StatusText.Text="未完成："+e.Message;
        await new ContentDialog{Title="無法完成操作",Content=e.Message,CloseButtonText="關閉",XamlRoot=Root.XamlRoot}.ShowAsync();
    }
    private async Task RefreshLibrary()
    {
        _library=(await _storage.ListAsync()).Select(b=>new LibraryCard(b,File.Exists(_storage.ThumbnailPath(b.Id))
            ?new Uri(_storage.ThumbnailPath(b.Id)).AbsoluteUri:null)).ToList();await RefreshTrashCardsAsync();FilterLibrary();
    }

    private void Search_Changed(object sender,TextChangedEventArgs e){if(LibraryList is not null){_searchTimer.Stop();_searchTimer.Start();}}
    private async void Library_DoubleTapped(object sender,DoubleTappedRoutedEventArgs e)
    {
        if(_libraryMulti)return;var element=e.OriginalSource as FrameworkElement;
        while(element is not null&&element.DataContext is not LibraryCard)element=VisualTreeHelper.GetParent(element) as FrameworkElement;
        if(element?.DataContext is not LibraryCard card)return;e.Handled=true;
        try{if(card.TrashPath is { } trash){await _storage.RestoreAsync(trash);await RefreshLibrary();}else await OpenAsync(await _storage.LoadAsync(card.Board.Id));}catch(Exception ex){await Error(ex);}
    }

    private async Task OpenAsync(HeiBanDocument doc)
    {
        CancelScreenshotCapture("切換作品");
        CommitPropertyEdit();FinishText(); _renderer.ClearCache();_session.Open(doc);_workspaceOpen=true;
        _saveFailed=false;HomePanel.Visibility=Visibility.Collapsed;Workspace.Visibility=Visibility.Visible;
        ShowWorkspaceHeader(_headerPinned);
        TitleBox.Text=doc.Board.Title;_viewport.Zoom=1;_viewport.X=doc.Board.CanvasMode=="infinite"?0:80;_viewport.Y=80;
        if(doc.Board.CanvasMode=="notebook" && (doc.Board.Pages?.Count??0)==0)
        {doc.Board.Pages=[new BoardPage()];doc.Board.ActivePageId=doc.Board.Pages[0].Id;}
        RefreshEditor(); await _renderer.LoadImagesAsync(CanvasSurface,doc.Objects);
    }
    private void RefreshEditor()
    {
        _renderer.Prune(_session.Document.Objects);
        TitleBox.Text=_session.Document.Board.Title;
        _changingLayers=true;
        try
        {
            RefreshLayersIfNeeded();
        }
        finally { _changingLayers=false; }
        PagesBar.Visibility=_session.Document.Board.CanvasMode=="notebook"?Visibility.Visible:Visibility.Collapsed;
        var pages=_session.Document.Board.Pages??[];var index=pages.FindIndex(p=>p.Id==_session.Document.Board.ActivePageId);
        PageText.Text=$"{index+1} / {pages.Count}";ZoomText.Text=$"{_viewport.Zoom:P0}";
        RefreshProperties();RefreshChrome();RefreshNavigationChrome();InvalidateCanvas();if(_hover)UpdateShapeCursor();
    }
    private async Task<bool> SaveAsync(bool deferThumbnail=false)
    {
        CommitPropertyEdit();
        await _saveGate.WaitAsync();
        try
        {
            var generation=_session.Generation;var epoch=_session.DocumentEpoch;
            var snapshot=DocumentCodec.Clone(_session.Document);_saving=true;StatusText.Text="儲存中…";
            await Task.Run(()=>_storage.SaveAsync(snapshot));
            if(epoch==_session.DocumentEpoch)
            {
                _session.MarkSaved(generation,snapshot.Board.Revision);_saveFailed=false;_saving=false;
                StatusText.Text=_session.IsDirty?"尚有變更":"已儲存";
                if(deferThumbnail||_gesture||_editor is not null||_propertyEditing||generation!=_session.Generation)QueueThumbnail(snapshot,epoch);
                else {_pendingThumbnail=null;_thumbnailTimer.Stop();await SaveThumbnail(snapshot);}
            }
            return true;
        }
        catch(Exception e){_saveFailed=true;await Error(e);return false;}
        finally{_saving=false;_saveGate.Release();UpdateSaveStatusLight(StatusText.Text);}
    }
    private async Task SaveThumbnail(HeiBanDocument snapshot)
    {
        await _thumbnailGate.WaitAsync();
        try
        {
            // A queued autosave thumbnail must never overwrite a later manual save's image.
            if(_thumbnailRevisions.TryGetValue(snapshot.Board.Id,out var revision)&&revision>snapshot.Board.Revision)return;
            using var target=new CanvasRenderTarget(CanvasSurface,480,300,96);
            var vp=new ViewportTransform{X=24,Y=20,Zoom=.3};
            var board=snapshot.Board;var visible=snapshot.Objects.Where(o=>o.IsVisible!=false&&(board.CanvasMode!="notebook"||o.PageId is null||o.PageId==board.ActivePageId)).ToArray();
            if(board.CanvasMode=="infinite" && visible.Length>0)
            {
                var objects=visible;var left=objects.Min(o=>o.X);var top=objects.Min(o=>o.Y);
                var width=Math.Max(1,objects.Max(o=>o.X+o.Width)-left);var height=Math.Max(1,objects.Max(o=>o.Y+o.Height)-top);
                vp.Zoom=Math.Min(432/width,260/height);vp.X=24-left*vp.Zoom;vp.Y=20-top*vp.Zoom;
            }
            using(var ds=target.CreateDrawingSession())
            {_renderer.RenderBackground(ds,board,vp,480,300);_renderer.RenderObjects(ds,visible,vp,480,300);}
            await target.SaveAsync(_storage.ThumbnailPath(board.Id),CanvasBitmapFileFormat.Png);
            _thumbnailRevisions[board.Id]=board.Revision;
        }
        catch(Exception e){StatusText.Text="黑板已儲存，縮圖稍後更新："+e.Message;}
        finally{_thumbnailGate.Release();}
    }
    private async void New_Click(object sender,RoutedEventArgs e)
    {
        CancelScreenshotCapture("新建作品");
        CommitPropertyEdit();
        try
        {
            var name=new TextBox{PlaceholderText="作品名稱"};
            var mode=new ComboBox{Header="格式",ItemsSource=new[]{"筆記本","無邊界筆記","有邊界黑板"},SelectedIndex=0,HorizontalAlignment=HorizontalAlignment.Stretch};
            var size=new ComboBox{Header="尺寸",ItemsSource=new[]{"A4 直向","A4 橫向","16:9 簡報","1:1 方形"},SelectedIndex=0,HorizontalAlignment=HorizontalAlignment.Stretch};
            var background=new ComboBox{Header="背景",ItemsSource=new[]{"純白","暖白","經典黑綠","深灰"},SelectedIndex=0,HorizontalAlignment=HorizontalAlignment.Stretch};
            var content=new StackPanel{Spacing=14};foreach(var control in new UIElement[]{name,mode,size,background})content.Children.Add(control);
            var dialog=new ContentDialog{Title="新增筆記或黑板",Content=content,PrimaryButtonText="建立",CloseButtonText="取消",DefaultButton=ContentDialogButton.Primary,XamlRoot=Root.XamlRoot};
            if(await dialog.ShowAsync()!=ContentDialogResult.Primary)return;
            if(_workspaceOpen&&_session.IsDirty&&!await SaveAsync())return;
            var dimensions=new[]{(595d,842d),(842d,595d),(1920d,1080d),(1080d,1080d)}[size.SelectedIndex];
            var board=new BoardMetadata{Title=string.IsNullOrWhiteSpace(name.Text)?"新筆記":name.Text.Trim(),CanvasMode=new[]{"notebook","infinite","fixed"}[mode.SelectedIndex],
                CanvasWidth=mode.SelectedIndex==1?null:dimensions.Item1,CanvasHeight=mode.SelectedIndex==1?null:dimensions.Item2,
                CanvasPreset=mode.SelectedIndex==1?"infinite":new[]{"a4_portrait","a4_landscape","16_9","1_1"}[size.SelectedIndex],
                BackgroundColor=new[]{"#ffffff","#faf8f5","#172e25","#18181b"}[background.SelectedIndex],BoardTheme=background.SelectedIndex<2?"whiteboard":"blackboard",GridStyle=mode.SelectedIndex==0?"lines":"dots"};
            if(mode.SelectedIndex==0){board.Pages=[new BoardPage()];board.ActivePageId=board.Pages[0].Id;}
            var doc=new HeiBanDocument{Board=board};await _storage.SaveAsync(doc);await OpenAsync(doc);
        }catch(Exception ex){await Error(ex);}
    }
    private async void Home_Click(object sender,RoutedEventArgs e)
    {
        CancelScreenshotCapture("回到首頁");
        CommitPropertyEdit();FinishText();if(_gesture)CancelGesture();if(_session.IsDirty&&!await SaveAsync())return;
        _workspaceOpen=false;Workspace.Visibility=Visibility.Collapsed;HomePanel.Visibility=Visibility.Visible;
        try{await RefreshLibrary();}catch(Exception ex){await Error(ex);}
    }
    private async void Import_Click(object sender,RoutedEventArgs e)
    {
        CancelScreenshotCapture("匯入作品");
        try
        {
            var picker=new FileOpenPicker();WinRT.Interop.InitializeWithWindow.Initialize(picker,WinRT.Interop.WindowNative.GetWindowHandle(this));
            picker.FileTypeFilter.Add(".json");picker.FileTypeFilter.Add(".heiban");var file=await picker.PickSingleFileAsync();if(file is null)return;
            var imported=await _storage.ImportAsync(file.Path);
            // Import a new local identity; do not overwrite an existing board with an imported snapshot.
            imported.Board.Id=Guid.NewGuid().ToString();imported.Board.Revision=0;
            foreach(var o in imported.Objects)o.BoardId=imported.Board.Id;
            await _storage.SaveAsync(imported);await OpenAsync(imported);
        }catch(Exception ex){await Error(ex);}
    }
    private async void Save_Click(object sender,RoutedEventArgs e){FinishText();if(_gesture)CancelGesture();await SaveAsync();}
    private void Title_LostFocus(object sender,RoutedEventArgs e)
    {if(!_workspaceOpen||string.IsNullOrWhiteSpace(TitleBox.Text)||TitleBox.Text==_session.Document.Board.Title)return;_session.Begin();_session.Document.Board.Title=TitleBox.Text.Trim();_session.Commit();}
    private async void Export_Click(object sender,RoutedEventArgs e)=>await ExportDocumentAsync();
    private async void About_Click(object sender,RoutedEventArgs e)
    {var result=await new ContentDialog{Title="黑板 · Windows "+Updating.GitHubUpdateService.CurrentVersion,Content="C# / .NET 10 / WinUI 3 / Win2D\n本機作品資料：\n"+_storage.DataDirectory+"\n\n功能基準：Mac 1.0.12。Windows 預覽版；實體手寫裝置、多螢幕及完整跨 App 操作仍待驗收。",PrimaryButtonText="更新設定",CloseButtonText="關閉",XamlRoot=Root.XamlRoot}.ShowAsync();if(result==ContentDialogResult.Primary)await ShowUpdatesAsync();}
    private void Tool_Click(object sender,RoutedEventArgs e)=>ActivateTool((string)((FrameworkElement)sender).Tag);
    private void Properties_Click(object sender,RoutedEventArgs e)
    {Inspector.Visibility=Inspector.Visibility==Visibility.Visible?Visibility.Collapsed:Visibility.Visible;if(Inspector.Visibility==Visibility.Visible){_changingLayers=true;try{RefreshLayersIfNeeded();}finally{_changingLayers=false;}}RefreshProperties();RefreshChrome();}
    private void Layers_Click(object sender,RoutedEventArgs e){_layerPreview?.End();_layerDragId=_layerDropId=null;LayersPanel.Visibility=LayersPanel.Visibility==Visibility.Visible?Visibility.Collapsed:Visibility.Visible;RefreshEditor();}
    private async Task<string?> ChooseColor(string title,string current)
    {
        var picker=ColorWheel(current);
        var dialog=new ContentDialog{Title=title,Content=picker,PrimaryButtonText="套用",CloseButtonText="取消",XamlRoot=Root.XamlRoot};
        if(await dialog.ShowAsync()!=ContentDialogResult.Primary)return null;
        return $"#{picker.Color.R:X2}{picker.Color.G:X2}{picker.Color.B:X2}{picker.Color.A:X2}";
    }
    private void StrokeColor_Click(object sender,RoutedEventArgs e)=>ShowColorWheel((FrameworkElement)sender,_session.Selected?.StrokeColor??CurrentStyle.Color,color=>ChangeProperty(()=>{if(_session.Selected is { } o)o.StrokeColor=color;else{CurrentStyle.Color=color;LoadActiveStyle();}}));
    private void FillColor_Click(object sender,RoutedEventArgs e)=>ShowColorWheel((FrameworkElement)sender,_session.Selected is { FillColor: not "none" } selected?selected.FillColor:CurrentStyle.Fill,color=>ChangeProperty(()=>SetFillColor(color)));
    private async void Background_Click(object sender,RoutedEventArgs e)
    {var c=await ChooseColor("畫布背景",_session.Document.Board.BackgroundColor);if(c is null)return;_session.Begin();_session.Document.Board.BackgroundColor=c;_session.Commit();InvalidateCanvas();}
    private void Layer_Changed(object sender,SelectionChangedEventArgs e)
    {if(_changingLayers)return;CommitPropertyEdit();_session.SetSelection(LayerList.SelectedItems.OfType<LayerCard>().Select(row=>row.ObjectId));RefreshProperties();InvalidateCanvas(false);}
    private void SyncLayerSelection()
    {
        var changing=_changingLayers;_changingLayers=true;
        try
        {
            LayerList.SelectedItems.Clear();foreach(var row in LayerList.Items.OfType<LayerCard>().Where(row=>_session.SelectedIds.Contains(row.ObjectId)))LayerList.SelectedItems.Add(row);
            RenameLayerButton.IsEnabled=_session.Selected is not null;
        }
        finally { _changingLayers=changing; }
    }
    private async void RenameLayer_Click(object sender,RoutedEventArgs e)
    {
        if(_session.Selected is not { } selected)return;
        var boardId=_session.Document.Board.Id;
        var input=new TextBox { Text=selected.Name??"",PlaceholderText="例如：重點標記、課程截圖",MaxLength=120 };
        var panel=new StackPanel { Spacing=8,Children={input,new TextBlock { Text="留空可恢復自動名稱。",FontSize=12 }} };
        var result=await new ContentDialog { Title="重新命名圖層",Content=panel,PrimaryButtonText="儲存",CloseButtonText="取消",XamlRoot=Root.XamlRoot }.ShowAsync();
        if(result!=ContentDialogResult.Primary||_session.Document.Board.Id!=boardId||!_session.Document.Objects.Contains(selected))return;
        var name=string.IsNullOrWhiteSpace(input.Text)?null:input.Text.Trim();
        if(name==selected.Name)return;
        _session.Begin();selected.Name=name;_session.Commit();RefreshEditor();
    }
    private void Select(BoardObject? o)
    {CommitPropertyEdit();_session.SelectedId=o?.Id;SyncLayerSelection();RefreshProperties();InvalidateCanvas(false);}
    private void Raise_Click(object sender,RoutedEventArgs e)=>OrderSelected(1);
    private void Lower_Click(object sender,RoutedEventArgs e)=>OrderSelected(-1);
    private void OrderSelected(int direction)
    {
        if(_session.Selected is not { } o)return;var order=_session.VisibleObjects.OrderBy(x=>x.ZIndex).ToList();var i=order.IndexOf(o);var next=i+direction;if(next<0||next>=order.Count)return;
        _session.Begin();(order[i],order[next])=(order[next],order[i]);for(var j=0;j<order.Count;j++)order[j].ZIndex=j;_session.Commit();RefreshEditor();
    }
    private void Lock_Click(object sender,RoutedEventArgs e){if(_session.Selected is not { } o)return;var locked=o.IsLocked!=true;_session.Begin();foreach(var item in _session.SelectedObjects)item.IsLocked=locked;_session.Commit();RefreshEditor();}
    private void Delete_Click(object sender,RoutedEventArgs e){CommitPropertyEdit();_session.DeleteSelected();RefreshEditor();}
    private void Undo_Click(object sender,RoutedEventArgs e){CommitPropertyEdit();FinishText();_session.Undo();RefreshEditor();}
    private void Redo_Click(object sender,RoutedEventArgs e){CommitPropertyEdit();FinishText();_session.Redo();RefreshEditor();}
    private void Dock_Click(object sender,RoutedEventArgs e)
    {
        var menu=new MenuFlyout();foreach(var side in new[]{"上方","左側","下方","右側"})
        {var item=new MenuFlyoutItem{Text=side};item.Click+=(_,_)=>SetDock(side);menu.Items.Add(item);}menu.ShowAt((FrameworkElement)sender);
    }
    private string _dock="上方";
    private void DrawingArea_SizeChanged(object sender,SizeChangedEventArgs e)
    {
        if(Tools is null)return;
        var floating=_toolbarTranslation.X!=0||_toolbarTranslation.Y!=0;
        var offset=new Point(_toolbarTranslation.X,_toolbarTranslation.Y);
        SetDock(_dock);
        SetInspectorDock(_inspectorDock);
        if(floating){_toolbarTranslation.X=offset.X;_toolbarTranslation.Y=offset.Y;DispatcherQueue.TryEnqueue(ClampToolbar);}
    }
    private void SetDock(string side)
    {
        _dock=side;_toolbarPrefs.DockSide=side;_toolbarTranslation.X=_toolbarTranslation.Y=0;
        _ = ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,_toolbarPrefs);
        ShowWorkspaceHeader(WorkspaceHeader.Visibility==Visibility.Visible);
        var vertical=side is "左側" or "右側";Tools.Orientation=ToolShell.Orientation=vertical?Orientation.Vertical:Orientation.Horizontal;
        ToolbarGrip.Width=vertical?40:24;ToolbarGrip.Height=vertical?20:40;
        ToolBorder.HorizontalAlignment=side=="左側"?HorizontalAlignment.Left:side=="右側"?HorizontalAlignment.Right:HorizontalAlignment.Center;
        ToolBorder.VerticalAlignment=side=="下方"?VerticalAlignment.Bottom:side=="上方"?VerticalAlignment.Top:VerticalAlignment.Center;
        ToolScroll.MaxWidth=vertical?44:Math.Max(120,DrawingArea.ActualWidth-80);ToolScroll.MaxHeight=Math.Max(100,DrawingArea.ActualHeight-80);
        ToolScroll.HorizontalScrollBarVisibility=vertical?ScrollBarVisibility.Disabled:ScrollBarVisibility.Auto;
        ToolScroll.VerticalScrollBarVisibility=vertical?ScrollBarVisibility.Auto:ScrollBarVisibility.Disabled;
        ToolScroll.HorizontalScrollMode=vertical?ScrollMode.Disabled:ScrollMode.Enabled;ToolScroll.VerticalScrollMode=vertical?ScrollMode.Enabled:ScrollMode.Disabled;
        foreach(var d in _toolDividers){d.Width=vertical?22:1;d.Height=vertical?1:22;}
        SetInspectorDock(_inspectorDock);
    }
    private void AddPage_Click(object sender,RoutedEventArgs e)
    {PreparePageChange();_session.Begin();var pages=_session.Document.Board.Pages??=[];var p=new BoardPage{Index=pages.Count,Title=$"第 {pages.Count+1} 頁"};pages.Add(p);_session.Document.Board.ActivePageId=p.Id;_session.Commit();RefreshEditor();}
    private void PreviousPage_Click(object sender,RoutedEventArgs e)=>SwitchPage(-1);
    private void NextPage_Click(object sender,RoutedEventArgs e)=>SwitchPage(1);
    private void SwitchPage(int direction)
    {PreparePageChange();var pages=_session.Document.Board.Pages??=[];var i=pages.FindIndex(p=>p.Id==_session.Document.Board.ActivePageId)+direction;if(i<0||i>=pages.Count)return;
        _session.Begin();_session.Document.Board.ActivePageId=pages[i].Id;_session.SelectedId=null;_session.Commit();RefreshEditor();}
    private void Root_KeyDown(object sender,KeyRoutedEventArgs e)
    {
        if(e.OriginalSource is TextBox or NumberBox || _editor is not null)return;
        var ctrl=Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control).HasFlag(global::Windows.UI.Core.CoreVirtualKeyStates.Down);
        if(_gesture&&(ctrl||e.Key==VirtualKey.Delete))CancelGesture();
        if(ctrl)
        {
            if(e.Key==VirtualKey.N){New_Click(sender,e);e.Handled=true;}
            if(e.Key==VirtualKey.S){Save_Click(sender,e);e.Handled=true;}
            if(e.Key==VirtualKey.Z){Undo_Click(sender,e);e.Handled=true;}if(e.Key==VirtualKey.Y){Redo_Click(sender,e);e.Handled=true;}
            if(e.Key==VirtualKey.C){CopySelected();e.Handled=true;}if(e.Key==VirtualKey.V){PasteObject();e.Handled=true;}
        }
        else switch(e.Key)
        {case VirtualKey.Delete:Delete_Click(sender,e);e.Handled=true;break;
         case VirtualKey.Escape:if(_readingMode){_readingMode=false;UpdateReadingModeUI();}if(_screenshotCoordinator.HasActiveSession){CancelScreenshotCapture("使用者按下 Esc");StatusText.Text="已取消截圖";}CancelGesture();FinishText();_polygon.Clear();ActivateTool("select");break;
         case VirtualKey.V:ActivateTool("select");break;case VirtualKey.P:ActivateTool("pen");break;case VirtualKey.E:ActivateTool("eraser");break;case VirtualKey.T:ActivateTool("text");break;}
    }
}
