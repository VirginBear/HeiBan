using static HeiBan.Windows.Localization.Strings;
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
    public string Format => Board.CanvasMode switch {"notebook"=>T("筆記本"),"fixed"=>T("有邊界黑板"),_=>T("無邊界筆記")};
    public UIElement FormatIcon => Views.ToolIcons.Create(Board.CanvasMode switch{"notebook"=>"notebook","fixed"=>"rect",_=>"infinite"});
    public double CardWidth {get;init;}=190;
    public double ThumbnailHeight=>CardWidth*.85;
    public string Background=>Board.BackgroundColor;
    public bool IsFavorite {get;init;}
    public string? TrashPath {get;init;}
    public bool CanFavorite=>TrashPath is null;
    public string FavoriteGlyph=>IsFavorite?"★":"☆";
    public string Summary => DateTimeOffset.TryParse(Board.UpdatedAt,out var date)?date.ToLocalTime().ToString("yyyy/M/d HH:mm"):T("本機儲存");
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
        Localization.Strings.Initialize(_storage.DataDirectory);
        LoadSavingPreferences();
        ProfilePalette=new PalettePreferencesStore(_storage.DataDirectory);
        _toolbarPrefs=ToolbarPreferencesStore.Load(_storage.DataDirectory);
        _dock=_toolbarPrefs.DockSide;
        App.StartupStage="載入主視窗 XAML";
        InitializeComponent();
        Root.Loaded+=(_,_)=>{if(VisualTreeHelper.GetParent(Root) is UIElement rootHost){rootHost.KeyDown-=Root_KeyDown;rootHost.KeyDown+=Root_KeyDown;}};
        InitializeLibraryChrome();BuildChrome();InitializeTeachingTools();InitializeDeferredWork();InitializeInputLatencyTrace();
        ApplyLanguageChrome();
        App.StartupStage="設定主視窗";
        ExtendsContentIntoTitleBar=true;SetTitleBar(AppTitleBar);SystemBackdrop=null;
        Activated+=(_,e)=>{if(e.WindowActivationState==WindowActivationState.Deactivated&&_tool is "laser" or "cane"&&_gesture)CancelGesture();};
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
        _autosave.Tick+=async(_,_)=>{if(AutoSaveEnabled&&!_preparingClose&&!_saveBoundaryBusy&&_workspaceOpen&&_session.IsDirty&&_editor is null&&!_gesture&&_boardEraserDraft is null&&!_propertyEditing&&_saveGate.CurrentCount>0)await SaveAsync(deferThumbnail:true);};
        ApplySavingPreferences();
        _screenshotWatchTimer.Tick+=async(_,_)=>await OnScreenshotWatchTickAsync();
        AppWindow.Closing+=async(_,e)=>
        {
            if(_closing)return;e.Cancel=true;if(_documentImporting||_preparingClose||_saveBoundaryBusy)return;_preparingClose=true;
            try
            {
                _autosave.Stop();_thumbnailTimer.Stop();_activeFlyout?.Hide();ShowSavingOverlay(true);
                await Task.Delay(32);
                CancelScreenshotCapture("視窗關閉");FinishText();CommitPropertyEdit();if(_gesture)CancelGesture();
                if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
                if(_boardEraserFinishing)await CompleteBoardEraserAsync();else CancelBoardEraser();
                await SaveTeachingSettingsAsync();
                await ProfilePalette.FlushAsync();
                if(_screenAnnotation?.IsActive==true&&!await _screenAnnotation.StopAsync())return;
                if(_workspaceOpen&&_session.IsDirty&&!await SaveAsync())return;
                await FlushPendingThumbnailAsync();
                if(_workspaceOpen&&_session.IsDirty)return;
                if(_updates is not null)await _updates.PrepareExitAsync();
                _inputLatencyHeartbeat?.Stop();
                try{await Diagnostics.InputLatencyTrace.SaveAsync();}
                catch(Exception error){System.Diagnostics.Debug.WriteLine("Input latency report: "+error.Message);}
                _closing=true;Close();
            }
            catch(Exception error){await Error(error);}
            finally{if(!_closing){ShowSavingOverlay(false);_preparingClose=false;ApplySavingPreferences();}}
        };
        Closed+=(_,_)=>{CaneSound.Dispose();_boardEraserWorking?.Cancel();_inputLatencyHeartbeat?.Stop();_layerPreview?.End();CanvasCursorHost.ReleaseCursor();_shapeCursor.Dispose();_updates?.Dispose();_autosave.Stop();_thumbnailTimer.Stop();_inkUiTimer.Stop();_searchTimer.Stop();_teachingSaveTimer.Stop();CancelScreenshotCapture("視窗關閉");_timerTickTimer?.Stop();_laserTimer.Stop();_propertyCommitTimer.Stop();_headerHideTimer.Stop();ClearScene();CanvasSurface.RemoveFromVisualTree();_renderer.Dispose();_screenAnnotation?.Dispose();};
        App.StartupStage="顯示首頁";
        try { EnsureScreenAnnotation(); } catch(Exception e) { StatusText.Text=T("螢幕畫布初始化失敗：")+e.Message; }
    }
    public async void InitializeAsync(string? file)
    {
        try { await EnsureQuickStartAsync();if(file is null)await RefreshLibrary();else await OpenAsync(await _storage.ImportAsync(file));
            var guideView=Environment.GetCommandLineArgs().FirstOrDefault(arg=>arg.StartsWith("--guide-view=",StringComparison.Ordinal));
            var workflow=Environment.GetCommandLineArgs().FirstOrDefault(arg=>arg.StartsWith("--drawing-workflow-output=",StringComparison.Ordinal));
            var validation=Environment.GetCommandLineArgs().FirstOrDefault(arg=>arg.StartsWith("--validation-output=",StringComparison.Ordinal));
            var performance=Environment.GetCommandLineArgs().FirstOrDefault(arg=>arg.StartsWith("--performance-output=",StringComparison.Ordinal));
            if(guideView is not null)ConfigureGuideView(guideView[13..]);
            else if(workflow is not null)await RunDrawingWorkflowChecksAsync(workflow[26..]);
            else if(performance is not null)await RunPerformanceBatchAsync(performance[21..]);
            else if(validation is not null)await RunNativeValidationAsync(validation[20..]);
            else {if(Environment.GetCommandLineArgs().Contains("--screen-canvas"))await StartScreenAnnotationAsync();_updates?.Start();} }
        catch(Exception e){await Error(e);}
    }
    private async Task Error(Exception e)
    {
        StatusText.Text=T("未完成：")+e.Message;
        await new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=T("無法完成操作"),Content=e.Message,CloseButtonText=T("關閉"),XamlRoot=Root.XamlRoot}.ShowAsync();
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
        if(_preparingClose||_saveBoundaryBusy)return;
        CancelScreenshotCapture("切換作品");
        CommitPropertyEdit();FinishText(); _renderer.ClearCache();_session.Open(doc);_workspaceOpen=true;
        _saveFailed=false;HomePanel.Visibility=Visibility.Collapsed;Workspace.Visibility=Visibility.Visible;
        ShowWorkspaceHeader(_headerPinned);
        TitleBox.Text=doc.Board.Title;_viewport.Zoom=1;_viewport.X=doc.Board.CanvasMode=="infinite"?0:80;_viewport.Y=80;
        if(doc.Board.CanvasMode=="notebook" && (doc.Board.Pages?.Count??0)==0)
        {doc.Board.Pages=[new BoardPage()];doc.Board.ActivePageId=doc.Board.Pages[0].Id;}
        _objectDetailsId=null;Inspector.Visibility=Visibility.Collapsed;RefreshEditor();FocusCanvasSurface();DispatcherQueue?.TryEnqueue(FocusCanvasSurface); await _renderer.LoadImagesAsync(CanvasSurface,doc.Objects);
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
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        if(_boardEraserFinishing)await CompleteBoardEraserAsync();
        CommitPropertyEdit();
        await _saveGate.WaitAsync();
        try
        {
            var generation=_session.Generation;var epoch=_session.DocumentEpoch;
            var snapshot=DocumentCodec.Clone(_session.Document);_saving=true;StatusText.Text=T("儲存中…");
            await Task.Run(()=>_storage.SaveAsync(snapshot));
            if(epoch==_session.DocumentEpoch)
            {
                _session.MarkSaved(generation,snapshot.Board.Revision);_saveFailed=false;_saving=false;
                StatusText.Text=_session.IsDirty?T("尚有變更"):T("已儲存");
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
        catch(Exception e){StatusText.Text=T("黑板已儲存，縮圖稍後更新：")+e.Message;}
        finally{_thumbnailGate.Release();}
    }
    private async void New_Click(object sender,RoutedEventArgs e)
    {
        CancelScreenshotCapture("新建作品");
        CommitPropertyEdit();
        try
        {
            var name=new TextBox{PlaceholderText=T("作品名稱")};
            var mode=new ComboBox{Header=T("格式"),ItemsSource=new[]{T("筆記本"),T("無邊界筆記"),T("有邊界黑板")},SelectedIndex=0,HorizontalAlignment=HorizontalAlignment.Stretch};
            var size=new ComboBox{Header=T("尺寸"),ItemsSource=new[]{T("A4 直向"),T("A4 橫向"),T("16:9 簡報"),T("1:1 方形")},SelectedIndex=0,HorizontalAlignment=HorizontalAlignment.Stretch};
            var background=new ComboBox{Header=T("背景"),ItemsSource=new[]{T("純白"),T("暖白"),T("經典黑綠"),T("深灰")},SelectedIndex=0,HorizontalAlignment=HorizontalAlignment.Stretch};
            var pattern=CreateBackgroundStylePicker("lines");
            var sizesByFormat=new[]{0,0,2};var patternsByFormat=new[]{"lines","dots","dots"};var previousFormat=0;
            mode.SelectionChanged+=(_,_)=>
            {
                // Infinite notes have no document dimensions. Remember bounded presets separately,
                // so first entering fixed boards starts at 16:9 without losing later user choices.
                if(previousFormat!=1)sizesByFormat[previousFormat]=Math.Max(0,size.SelectedIndex);
                patternsByFormat[previousFormat]=ReadBackgroundStyle(pattern,patternsByFormat[previousFormat]);
                var selectedFormat=mode.SelectedIndex;
                pattern.SelectedItem=pattern.Items.OfType<ComboBoxItem>().First(item=>Equals(item.Tag,patternsByFormat[selectedFormat]));
                size.Visibility=selectedFormat==1?Visibility.Collapsed:Visibility.Visible;
                size.IsEnabled=selectedFormat!=1;
                if(selectedFormat!=1)size.SelectedIndex=sizesByFormat[selectedFormat];
                previousFormat=selectedFormat;
            };
            var content=new StackPanel{Spacing=14};foreach(var control in new UIElement[]{name,mode,size,background,pattern})content.Children.Add(control);
            var dialog=new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=T("新增筆記或黑板"),Content=new ScrollViewer{Content=content,MaxHeight=Math.Max(160,Root.ActualHeight-180)},PrimaryButtonText=T("建立"),CloseButtonText=T("取消"),DefaultButton=ContentDialogButton.Primary,XamlRoot=Root.XamlRoot};
            if(await dialog.ShowAsync()!=ContentDialogResult.Primary)return;
            if(_workspaceOpen&&!await SaveBeforeLeavingAsync())return;
            var dimensions=new[]{(595d,842d),(842d,595d),(1920d,1080d),(1080d,1080d)}[size.SelectedIndex];
            var board=new BoardMetadata{Title=string.IsNullOrWhiteSpace(name.Text)?T("新筆記"):name.Text.Trim(),CanvasMode=new[]{"notebook","infinite","fixed"}[mode.SelectedIndex],
                CanvasWidth=mode.SelectedIndex==1?null:dimensions.Item1,CanvasHeight=mode.SelectedIndex==1?null:dimensions.Item2,
                CanvasPreset=mode.SelectedIndex==1?"infinite":new[]{"a4_portrait","a4_landscape","16_9","1_1"}[size.SelectedIndex],
                BackgroundColor=new[]{"#ffffff","#faf8f5","#172e25","#18181b"}[background.SelectedIndex],BoardTheme=background.SelectedIndex<2?"whiteboard":"blackboard",GridStyle=ReadBackgroundStyle(pattern,"lines")};
            if(mode.SelectedIndex==0){board.Pages=[new BoardPage()];board.ActivePageId=board.Pages[0].Id;}
            var doc=new HeiBanDocument{Board=board};await _storage.SaveAsync(doc);await OpenAsync(doc);
        }catch(Exception ex){await Error(ex);}
    }
    private async void Home_Click(object sender,RoutedEventArgs e)
    {
        CancelScreenshotCapture("回到首頁");
        if(!await SaveBeforeLeavingAsync())return;
        _workspaceOpen=false;Workspace.Visibility=Visibility.Collapsed;HomePanel.Visibility=Visibility.Visible;
        try{await RefreshLibrary();}catch(Exception ex){await Error(ex);}
    }
    private async void Import_Click(object sender,RoutedEventArgs e)
    {
        if(_documentImporting||_preparingClose||_saveBoundaryBusy)return;
        CancelScreenshotCapture("匯入作品");
        try
        {
            var picker=new FileOpenPicker();WinRT.Interop.InitializeWithWindow.Initialize(picker,WinRT.Interop.WindowNative.GetWindowHandle(this));
            foreach(var extension in new[]{".json",".heiban",".pdf",".pptx",".ppt"})picker.FileTypeFilter.Add(extension);var file=await picker.PickSingleFileAsync();if(file is null)return;
            var imported=file.FileType.ToLowerInvariant() is ".pdf" or ".pptx" or ".ppt"?await ImportExternalDocumentAsync(file.Path):await _storage.ImportAsync(file.Path);
            if(imported is null)return;
            if(_preparingClose||_saveBoundaryBusy)return;
            if(_workspaceOpen&&!await SaveBeforeLeavingAsync())return;
            // Import a new local identity; do not overwrite an existing board with an imported snapshot.
            imported.Board.Id=Guid.NewGuid().ToString();imported.Board.Revision=0;
            foreach(var o in imported.Objects)o.BoardId=imported.Board.Id;
            await _storage.SaveAsync(imported);await OpenAsync(imported);
        }catch(Exception ex){await Error(ex);}
    }
    private async void Save_Click(object sender,RoutedEventArgs e){if(!_workspaceOpen||_preparingClose||_saveBoundaryBusy)return;FinishText();if(_gesture)CancelGesture();await SaveAsync();}
    private void Title_LostFocus(object sender,RoutedEventArgs e)
    {if(!_workspaceOpen||string.IsNullOrWhiteSpace(TitleBox.Text)||TitleBox.Text==_session.Document.Board.Title)return;_session.Begin();_session.Document.Board.Title=TitleBox.Text.Trim();_session.Commit();}
    private async void Export_Click(object sender,RoutedEventArgs e)=>await ExportDocumentAsync();
    private async void About_Click(object sender,RoutedEventArgs e)
    {var result=await new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=T("黑板 · Windows ")+Updating.GitHubUpdateService.CurrentVersion,Content=T("C# / .NET 10 / WinUI 3 / Win2D\n本機作品資料：\n")+_storage.DataDirectory+T("\n\n功能基準：Mac 1.0.12。Windows 預覽版；實體手寫裝置、多螢幕及完整跨 App 操作仍待驗收。"),PrimaryButtonText=T("更新設定"),CloseButtonText=T("關閉"),XamlRoot=Root.XamlRoot}.ShowAsync();if(result==ContentDialogResult.Primary)await ShowUpdatesAsync();}
    private void Tool_Click(object sender,RoutedEventArgs e)=>ActivateTool((string)((FrameworkElement)sender).Tag);
    private void Properties_Click(object sender,RoutedEventArgs e)
    {Inspector.Visibility=Inspector.Visibility==Visibility.Visible?Visibility.Collapsed:Visibility.Visible;if(Inspector.Visibility==Visibility.Visible){_changingLayers=true;try{RefreshLayersIfNeeded();}finally{_changingLayers=false;}}RefreshProperties();RefreshChrome();}
    private void Layers_Click(object sender,RoutedEventArgs e){_layerPreview?.End();_layerDragId=_layerDropId=null;LayersPanel.Visibility=LayersPanel.Visibility==Visibility.Visible?Visibility.Collapsed:Visibility.Visible;RefreshEditor();}
    private async Task<string?> ChooseColor(string title,string current)
    {
        var picker=ColorWheel(current);
        var dialog=new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=title,Content=picker,PrimaryButtonText=T("套用"),CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot};
        if(await dialog.ShowAsync()!=ContentDialogResult.Primary)return null;
        return $"#{picker.Color.R:X2}{picker.Color.G:X2}{picker.Color.B:X2}{picker.Color.A:X2}";
    }
    private void StrokeColor_Click(object sender,RoutedEventArgs e)=>ShowColorWheel((FrameworkElement)sender,_session.Selected?.StrokeColor??CurrentStyle.Color,color=>ChangeProperty(()=>{if(_session.Selected is { } o)o.StrokeColor=color;else{CurrentStyle.Color=color;LoadActiveStyle();}}));
    private void FillColor_Click(object sender,RoutedEventArgs e)=>ShowColorWheel((FrameworkElement)sender,_session.Selected is { FillColor: not "none" } selected?selected.FillColor:CurrentStyle.Fill,color=>ChangeProperty(()=>SetFillColor(color)));
    private static ComboBox CreateBackgroundStylePicker(string current)
    {
        var picker=new ComboBox{Header=T("背景樣式"),HorizontalAlignment=HorizontalAlignment.Stretch};
        foreach(var (key,label) in new[]{("blank",T("空白")),("lines",T("橫線條")),("dots",T("點狀")),("grid",T("方格子")),("staff",T("五線譜"))})
            picker.Items.Add(new ComboBoxItem{Content=label,Tag=key});
        var selected=picker.Items.OfType<ComboBoxItem>().FirstOrDefault(item=>Equals(item.Tag,current));
        // An imported future style is retained unless the user explicitly chooses a known style.
        if(selected is null){selected=new ComboBoxItem{Content=T("目前樣式（保留）"),Tag=current};picker.Items.Add(selected);}
        picker.SelectedItem=selected;return picker;
    }
    private static string ReadBackgroundStyle(ComboBox picker,string fallback)=>(picker.SelectedItem as ComboBoxItem)?.Tag as string??fallback;
    private async void Background_Click(object sender,RoutedEventArgs e)
    {
        CommitPropertyEdit();FinishText();if(_gesture)CancelGesture();
        var board=_session.Document.Board;var epoch=_session.DocumentEpoch;
        var color=ColorWheel(board.BackgroundColor);var originalColor=color.Color;var pattern=CreateBackgroundStylePicker(board.GridStyle);
        var content=new StackPanel{Spacing=14,Children={pattern,new TextBlock{Text=T("背景顏色")},color}};
        var result=await new ContentDialog{FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Title=T("畫布背景"),Content=new ScrollViewer{Content=content,MaxHeight=Math.Max(200,Root.ActualHeight-180)},PrimaryButtonText=T("套用"),CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot}.ShowAsync();
        if(result!=ContentDialogResult.Primary||epoch!=_session.DocumentEpoch||!ReferenceEquals(board,_session.Document.Board))return;
        var nextColor=color.Color.Equals(originalColor)?board.BackgroundColor:ColorHex(color.Color);var nextPattern=ReadBackgroundStyle(pattern,board.GridStyle);
        if(nextColor==board.BackgroundColor&&nextPattern==board.GridStyle)return;
        _session.Begin();board.BackgroundColor=nextColor;board.GridStyle=nextPattern;_session.Commit();InvalidateCanvas();
    }
    private void Layer_Changed(object sender,SelectionChangedEventArgs e)
    {if(_changingLayers)return;if(_tool is "laser" or "cane"){SyncLayerSelection();return;}CommitPropertyEdit();_session.SetSelection(LayerList.SelectedItems.OfType<LayerCard>().Select(row=>row.ObjectId));RefreshProperties();InvalidateCanvas(false);}
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
        var input=new TextBox { Text=selected.Name??"",PlaceholderText=T("例如：重點標記、課程截圖"),MaxLength=120 };
        var panel=new StackPanel { Spacing=8,Children={input,new TextBlock { Text=T("留空可恢復自動名稱。"),FontSize=12 }} };
        var result=await new ContentDialog {FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight, Title=T("重新命名圖層"),Content=panel,PrimaryButtonText=T("儲存"),CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot }.ShowAsync();
        if(result!=ContentDialogResult.Primary||_session.Document.Board.Id!=boardId||!_session.Document.Objects.Contains(selected))return;
        var name=string.IsNullOrWhiteSpace(input.Text)?null:input.Text.Trim();
        if(name==selected.Name)return;
        _session.Begin();selected.Name=name;_session.Commit();RefreshEditor();
    }
    private void Select(BoardObject? o)
    {CommitPropertyEdit();if(_session.SelectedId!=o?.Id){_objectDetailsId=null;Inspector.Visibility=Visibility.Collapsed;}_session.SelectedId=o?.Id;SyncLayerSelection();RefreshProperties();InvalidateCanvas(false);}
    private void Raise_Click(object sender,RoutedEventArgs e)=>OrderSelected(1);
    private void Lower_Click(object sender,RoutedEventArgs e)=>OrderSelected(-1);
    private void OrderSelected(int direction)
    {
        if(_session.Selected is not { } o)return;var order=_session.VisibleObjects.OrderBy(x=>x.ZIndex).ToList();var i=order.IndexOf(o);var next=i+direction;if(next<0||next>=order.Count)return;
        _session.Begin();(order[i],order[next])=(order[next],order[i]);for(var j=0;j<order.Count;j++)order[j].ZIndex=j;_session.Commit();RefreshEditor();
    }
    private void FocusCanvasSurface()
    {
        if(!_workspaceOpen||_editor is not null||_pinNameEditor is not null)return;
        CanvasSurface.Focus(FocusState.Programmatic);
    }
    private void Lock_Click(object sender,RoutedEventArgs e){if(_session.Selected is not { } o)return;var locked=o.IsLocked!=true;_session.Begin();foreach(var item in _session.SelectedObjects)item.IsLocked=locked;_session.Commit();RefreshEditor();FocusCanvasSurface();}
    private void Delete_Click(object sender,RoutedEventArgs e){FinishPinRename();if(_editor is not null)FinishText();CommitPropertyEdit();_session.DeleteSelected();RefreshEditor();FocusCanvasSurface();}
    private async void Undo_Click(object sender,RoutedEventArgs e){if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();CancelGesture();CommitPropertyEdit();FinishText();_session.Undo();RefreshEditor();FocusCanvasSurface();}
    private async void Redo_Click(object sender,RoutedEventArgs e){if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();CancelGesture();CommitPropertyEdit();FinishText();_session.Redo();RefreshEditor();FocusCanvasSurface();}
    private void Dock_Click(object sender,RoutedEventArgs e)
    {
        var menu=new MenuFlyout();foreach(var side in new[]{"上方","左側","下方","右側"})
        {var item=new MenuFlyoutItem{Text=T(side)};item.Click+=(_,_)=>SetDock(side);menu.Items.Add(item);}menu.ShowAt((FrameworkElement)sender);
    }
    private string _dock="上方";
    private void DrawingArea_SizeChanged(object sender,SizeChangedEventArgs e)
    {
        RefreshBoardEraser();
        if(Tools is null)return;
        var floating=_toolbarTranslation.X!=0||_toolbarTranslation.Y!=0;
        var offset=new Point(_toolbarTranslation.X,_toolbarTranslation.Y);
        SetDock(_dock);
        SetInspectorDock(_inspectorDock);
        if(floating){_toolbarTranslation.X=offset.X;_toolbarTranslation.Y=offset.Y;DispatcherQueue.TryEnqueue(ClampToolbar);}
    }
    private void SetDock(string side)
    {
        var changed=_toolbarPrefs.DockSide!=side;_dock=side;_toolbarPrefs.DockSide=side;_toolbarTranslation.X=_toolbarTranslation.Y=0;
        if(changed)_=SaveToolbarDockAsync();
        ShowWorkspaceHeader(WorkspaceHeader.Visibility==Visibility.Visible);
        var vertical=side is "左側" or "右側";Tools.Orientation=ToolShell.Orientation=vertical?Orientation.Vertical:Orientation.Horizontal;
        ToolbarGrip.Width=vertical?40:24;ToolbarGrip.Height=vertical?20:40;
        ToolBorder.HorizontalAlignment=side=="左側"?HorizontalAlignment.Left:side=="右側"?HorizontalAlignment.Right:HorizontalAlignment.Center;
        ToolBorder.VerticalAlignment=side=="下方"?VerticalAlignment.Bottom:side=="上方"?VerticalAlignment.Top:VerticalAlignment.Center;
        ToolScroll.MaxWidth=vertical?44:Math.Max(120,DrawingArea.ActualWidth-80);ToolScroll.MaxHeight=Math.Max(100,DrawingArea.ActualHeight-80);
        ToolScroll.HorizontalScrollBarVisibility=vertical?ScrollBarVisibility.Disabled:ScrollBarVisibility.Auto;
        ToolScroll.VerticalScrollBarVisibility=vertical?ScrollBarVisibility.Auto:ScrollBarVisibility.Disabled;
        ToolScroll.HorizontalScrollMode=vertical?ScrollMode.Disabled:ScrollMode.Enabled;ToolScroll.VerticalScrollMode=vertical?ScrollMode.Enabled:ScrollMode.Disabled;
        ArrangeMainToolbar();
        foreach(var d in _toolDividers){d.Width=vertical?22:1;d.Height=vertical?1:22;}
        SetInspectorDock(_inspectorDock);
    }
    private void AddPage_Click(object sender,RoutedEventArgs e)
    {PreparePageChange();_session.Begin();var pages=_session.Document.Board.Pages??=[];var p=new BoardPage{Index=pages.Count,Title=F($"第 {pages.Count+1} 頁")};pages.Add(p);_session.Document.Board.ActivePageId=p.Id;_session.Commit();RefreshEditor();}
    private void PreviousPage_Click(object sender,RoutedEventArgs e)=>SwitchPage(-1);
    private void NextPage_Click(object sender,RoutedEventArgs e)=>SwitchPage(1);
    private void SwitchPage(int direction)
    {PreparePageChange();var pages=_session.Document.Board.Pages??=[];var i=pages.FindIndex(p=>p.Id==_session.Document.Board.ActivePageId)+direction;if(i<0||i>=pages.Count)return;
        _session.Begin();_session.Document.Board.ActivePageId=pages[i].Id;_session.SelectedId=null;_session.Commit();RefreshEditor();}
    private void Root_KeyDown(object sender,KeyRoutedEventArgs e)
    {
        if(e.Handled)return;
        if(_boardEraserDraft is not null){if(e.Key==VirtualKey.Escape)CancelBoardEraser();e.Handled=true;return;}
        if(_preparingClose||_saveBoundaryBusy){e.Handled=true;return;}
        if(e.OriginalSource is TextBox or NumberBox or RichEditBox || _editor is not null || _pinNameEditor is not null)return;
        var ctrl=Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control).HasFlag(global::Windows.UI.Core.CoreVirtualKeyStates.Down);
        if(!_workspaceOpen)
        {
            if(ctrl&&e.Key==VirtualKey.N){New_Click(sender,e);e.Handled=true;}
            return;
        }
        // Mac keyboards label VirtualKey.Back as Delete; accept both Delete and Backspace when no text editor is active.
        if(_gesture&&(ctrl||e.Key is VirtualKey.Delete or VirtualKey.Back))CancelGesture();
        if(ctrl)
        {
            if(e.Key==VirtualKey.N){New_Click(sender,e);e.Handled=true;}
            if(e.Key==VirtualKey.S){Save_Click(sender,e);e.Handled=true;}
            if(e.Key==VirtualKey.Z){Undo_Click(sender,e);e.Handled=true;}if(e.Key==VirtualKey.Y){Redo_Click(sender,e);e.Handled=true;}
            if(e.Key==VirtualKey.C){CopySelected();e.Handled=true;}if(e.Key==VirtualKey.V){PasteObject();e.Handled=true;}
        }
        else switch(e.Key)
        {case VirtualKey.Delete:
         case VirtualKey.Back:Delete_Click(sender,e);e.Handled=true;break;
         case VirtualKey.Escape:if(_readingMode){_readingMode=false;UpdateReadingModeUI();}if(_screenshotCoordinator.HasActiveSession){CancelScreenshotCapture("使用者按下 Esc");StatusText.Text=T("已取消截圖");}CancelGesture();FinishText();_polygon.Clear();ActivateTool("select");e.Handled=true;break;
         case VirtualKey.V:ActivateTool("select");e.Handled=true;break;case VirtualKey.P:ActivateTool("pen");e.Handled=true;break;case VirtualKey.E:ActivateTool("eraser");e.Handled=true;break;case VirtualKey.T:ActivateTool("text");e.Handled=true;break;}
    }
}
