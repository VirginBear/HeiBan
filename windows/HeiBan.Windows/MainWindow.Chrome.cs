using static HeiBan.Windows.Localization.Strings;
using System.Numerics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using global::Windows.Foundation;
using global::Windows.Globalization.NumberFormatting;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.System;

namespace HeiBan.Windows;

public partial class MainWindow
{
    public sealed class ToolStyle
    {
        public string Color = "#24533D", Fill = "#B8D4B2", Dash = "solid", BrushKind="pen", Extension="none";
        public double Width = 4, Opacity = 1, FontSize = 18;
        public double? FillOpacity;
        public string? FillGradientStart, FillGradientEnd;
        public bool Filled;
    }

    private readonly Dictionary<string, ToolStyle> _toolStyles = new()
    {
        ["pen"] = new(),
        ["curve"] = new(),
        ["highlighter"] = new() { Color = "#FEF08A", Width = 18, Opacity = .45 },
        ["paint"] = new() { Color = "#86EFAC", Width = 32 },
    };

    private readonly Dictionary<string, Button> _toolButtons = [];
    private FrameworkElement GetToolAnchor(string key) => _toolButtons.TryGetValue(key, out var btn) ? btn : (FrameworkElement)Tools;
    private readonly CalculatorModel _calculator = new();
    private readonly TimerCoordinator _timerCoordinator = new();
    private readonly CompassToolEngine _compass = new();
    private DispatcherTimer? _timerTickTimer;
    private Action? _activeTimerDisplayUpdater;
    private string? _selectionBarSignature;
    private BoardObject? _selectionBarObject;
    private readonly List<Action<BoardObject>> _selectionBarUpdates=[];
    private static readonly string[] Palette = ["#86EFAC", "#FEF08A", "#93C5FD", "#FFFFFF", "#F472B6", "#FB923C", "#C084FC", "#24533D"];
    private static readonly string[] DashStyles = ["solid", "dashed", "dotted", "dashdot"];
    private string _styleTool = "pen";
    private bool _syncingProperties = true, _propertyEditing;
    private readonly DispatcherTimer _propertyCommitTimer = new() { Interval = TimeSpan.FromMilliseconds(300) };
    private Button? _brushButton;
    private Ellipse? _brushSwatch;
    private readonly List<FrameworkElement> _toolDividers = [];
    private bool _toolbarDragging;
    private uint _toolbarPointer;
    private Point _toolbarDragStart;
    private Point _toolbarDragOffset;
    private string? _toolbarDrop;
    private readonly TranslateTransform _toolbarTranslation = new();
    private readonly DispatcherTimer _headerHideTimer = new() { Interval = TimeSpan.FromMilliseconds(800) };
    private bool _headerPinned, _headerHovered;
    private bool _chromeEventsBound;
    private FlyoutBase? _activeFlyout;
    private ToolbarPreferences _toolbarPrefs = ToolbarPreferences.CreateDefault();

    private void ShowWorkspaceHeader(bool show)
    {
        WorkspaceHeader.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        HeaderReveal.Visibility = show ? Visibility.Collapsed : Visibility.Visible;
        ToolBorder.Margin = new Thickness(16, _dock == "上方" ? (show ? 68 : 24) : 16, 16, 16);
        if (show) UpdateSaveStatusLight(StatusText.Text);
    }

    private void WorkspaceHeader_Entered(object sender, PointerRoutedEventArgs e)
    {
        _headerHovered = true;
        _headerHideTimer.Stop();
        ShowWorkspaceHeader(true);
    }

    private void WorkspaceHeader_Exited(object sender, PointerRoutedEventArgs e)
    {
        _headerHovered = false;
        _headerHideTimer.Start();
    }

    private void HeaderReveal_Click(object sender, RoutedEventArgs e)
    {
        ShowWorkspaceHeader(true);
        _headerHideTimer.Start();
    }

    private void HeaderPin_Click(object sender, RoutedEventArgs e)
    {
        _headerPinned = !_headerPinned;
        HeaderPinButton.Content=ToolIcons.Create(_headerPinned?"lock":"unlock");
        if (_headerPinned) _headerHideTimer.Stop();
        else _headerHideTimer.Start();
    }

    private void ReadingMode_Click(object sender, RoutedEventArgs e)
    {
        _readingMode = !_readingMode;
        UpdateReadingModeUI();
    }

    private void UpdateReadingModeUI()
    {
        if (_readingMode)
        {
            ReadingModeButton.Content = ToolIcons.Create("pen");
            ToolTipService.SetToolTip(ReadingModeButton, T("回到編輯模式（目前為閱讀模式：拖曳移動畫布，不會畫線）"));
            StatusText.Text = T("閱讀模式：拖曳移動畫布，不會畫線");
        }
        else
        {
            ReadingModeButton.Content = ToolIcons.Create("reading");
            ToolTipService.SetToolTip(ReadingModeButton, T("閱讀模式：拖曳移動畫布，不會畫線"));
            StatusText.Text = T("編輯模式");
        }
        RefreshNavigationChrome();
    }

    private void InsertNav_Click(object sender, RoutedEventArgs e)
    {
        var menu = new MenuFlyout();

        var textItem = new MenuFlyoutItem { Text = T("文字（T）"), Icon = ToolIcons.CreateIcon("text") };
        textItem.Click += (_, _) => ActivateTool("text");
        menu.Items.Add(textItem);

        var stickyItem = new MenuFlyoutItem { Text = T("便條紙"), Icon = ToolIcons.CreateIcon("sticky") };
        stickyItem.Click += (_, _) => ActivateTool("sticky");
        menu.Items.Add(stickyItem);

        var shotItem = new MenuFlyoutItem { Text = T("截圖置入…（Win+Shift+S）"), Icon = ToolIcons.CreateIcon("screenshot") };
        shotItem.Click += (_, _) => Screenshot_Click(this, new RoutedEventArgs());
        menu.Items.Add(shotItem);

        var imgItem = new MenuFlyoutItem { Text = T("圖片匯入…"), Icon = ToolIcons.CreateIcon("image") };
        imgItem.Click += (_, _) => Image_Click(this, new RoutedEventArgs());
        menu.Items.Add(imgItem);

        menu.Items.Add(new MenuFlyoutSeparator());

        var compassItem = new MenuFlyoutItem { Text = T("圓規（兩階段畫弧）"), Icon = ToolIcons.CreateIcon("compass") };
        compassItem.Click += (_, _) => Compass_Click(this, new RoutedEventArgs());
        menu.Items.Add(compassItem);

        var calcItem = new MenuFlyoutItem { Text = T("計算機（科學與括號）"), Icon = ToolIcons.CreateIcon("calculator") };
        calcItem.Click += (_, _) => ShowCalculatorPanel(InsertNavButton);
        menu.Items.Add(calcItem);

        var timerItem = new MenuFlyoutItem { Text = T("計時器（常駐倒數與碼表）"), Icon = ToolIcons.CreateIcon("timer") };
        timerItem.Click += (_, _) => ShowTimerPanel(InsertNavButton);
        menu.Items.Add(timerItem);

        var rulerItem = new MenuFlyoutItem { Text = T("螢幕尺"), Icon = ToolIcons.CreateIcon("ruler") };
        rulerItem.Click += (_, _) => Ruler_Click(this, new RoutedEventArgs());
        menu.Items.Add(rulerItem);

        var screenAnnotateItem = new MenuFlyoutItem { Text = T("我的螢幕就是我的畫布"), Icon = ToolIcons.CreateIcon("infinite") };
        screenAnnotateItem.Click += async (_, _) => await StartScreenAnnotationAsync();
        menu.Items.Add(screenAnnotateItem);

        ShowExclusiveFlyout(menu, InsertNavButton);
    }

    private void MoreNav_Click(object sender, RoutedEventArgs e)
    {
        var menu = new MenuFlyout();

        var noteInfoItem = new MenuFlyoutItem { Text = T("筆記資訊與改名…"), Icon = ToolIcons.CreateIcon("info") };
        noteInfoItem.Click += (_, _) => ShowNoteInfoDialog(MoreNavButton);
        menu.Items.Add(noteInfoItem);

        menu.Items.Add(new MenuFlyoutSeparator());

        var bgItem = new MenuFlyoutItem { Text = T("畫布背景…"), Icon = ToolIcons.CreateIcon("background") };
        bgItem.Click += (_, _) => Background_Click(this, new RoutedEventArgs());
        menu.Items.Add(bgItem);

        var layerItem = new MenuFlyoutItem { Text = T("物件圖層…"), Icon = ToolIcons.CreateIcon("layers") };
        layerItem.Click += (_, _) => Layers_Click(this, new RoutedEventArgs());
        menu.Items.Add(layerItem);

        var propItem = new MenuFlyoutItem { Text = T("屬性檢查器"), Icon = ToolIcons.CreateIcon("settings") };
        propItem.Click += (_, _) => Properties_Click(this, new RoutedEventArgs());
        menu.Items.Add(propItem);

        menu.Items.Add(new MenuFlyoutSeparator());

        var saveItem = new MenuFlyoutItem { Text = T("儲存作品（Ctrl+S）"), Icon = ToolIcons.CreateIcon("save") };
        saveItem.Click += (_, _) => Save_Click(this, new RoutedEventArgs());
        menu.Items.Add(saveItem);

        var exportItem = new MenuFlyoutItem { Text = T("匯出文件或圖片…"), Icon = ToolIcons.CreateIcon("export") };
        exportItem.Click += (_, _) => Export_Click(this, new RoutedEventArgs());
        menu.Items.Add(exportItem);

        menu.Items.Add(new MenuFlyoutSeparator());

        var customizeItem = new MenuFlyoutItem { Text = T("自訂工具列…") };
        customizeItem.Click += async (_, _) => await ShowCustomizeToolbarDialog();
        menu.Items.Add(customizeItem);

        var resetItem = new MenuFlyoutItem { Text = T("恢復預設工具列") };
        resetItem.Click += (_, _) => ResetToolbarToDefault();
        menu.Items.Add(resetItem);

        menu.Items.Add(new MenuFlyoutSeparator());

        var guideItem = new MenuFlyoutItem { Text = T("使用說明") };
        guideItem.Click += async (_, _) => await OpenUserGuideAsync();
        menu.Items.Add(guideItem);

        var aboutItem = new MenuFlyoutItem { Text = T("關於黑板…") };
        aboutItem.Click += (_, _) => About_Click(this, new RoutedEventArgs());
        menu.Items.Add(aboutItem);

        var savingItem = new MenuFlyoutItem { Text = T("設定"), Icon = ToolIcons.CreateIcon("settings") };
        savingItem.Click += async (_, _) => await ShowSavingSettingsAsync();menu.Items.Add(savingItem);

        var updatesItem = new MenuFlyoutItem { Text = T("檢查更新與更新設定…") };
        updatesItem.Click += async (_, _) => await ShowUpdatesAsync();
        menu.Items.Add(updatesItem);

        ShowExclusiveFlyout(menu, MoreNavButton);
    }

    private void ShowNoteInfoDialog(FrameworkElement anchor)
    {
        var board = _session.Document.Board;
        var panel = new StackPanel { Spacing = 10, Width = 280, Padding = new Thickness(14) };

        var header = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        header.Children.Add(ToolIcons.Create("info"));
        header.Children.Add(new TextBlock { Text = T("筆記資訊與改名"), FontWeight = Microsoft.UI.Text.FontWeights.Bold, FontSize = 14, VerticalAlignment = VerticalAlignment.Center });
        panel.Children.Add(header);

        var nameLabel = new TextBlock { Text = T("筆記名稱"), FontSize = 12, Foreground = Brush("#68756C") };
        var editBox = new TextBox { Text = board.Title, HorizontalAlignment = HorizontalAlignment.Stretch };
        panel.Children.Add(nameLabel);
        panel.Children.Add(editBox);

        var sep = new Border { Height = 1, Background = Brush("#E2E7DF"), Margin = new Thickness(0, 4, 0, 4) };
        panel.Children.Add(sep);

        var format = board.CanvasMode switch { "notebook" => T("筆記本（多頁）"), "fixed" => T("有邊界黑板"), _ => T("無邊界筆記") };
        panel.Children.Add(new TextBlock { Text = F($"畫布格式：{format}"), FontSize = 12, Foreground = Brush("#4D5B4F") });
        panel.Children.Add(new TextBlock { Text = F($"物件數量：{_session.VisibleObjects.Count()} 個物件"), FontSize = 12, Foreground = Brush("#4D5B4F") });
        panel.Children.Add(new TextBlock { Text = F($"儲存狀態：{StatusText.Text}"), FontSize = 12, Foreground = Brush("#4D5B4F") });

        var buttonPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8, Margin = new Thickness(0, 8, 0, 0) };
        var okButton = new Button { Content = T("完成"), Style = (Style)Application.Current.Resources["AccentButtonStyle"] };

        Flyout? infoFlyout = null;
        okButton.Click += (_, _) =>
        {
            var newTitle = editBox.Text.Trim();
            if (!string.IsNullOrWhiteSpace(newTitle) && newTitle != board.Title)
            {
                _session.Begin();
                board.Title = newTitle;
                TitleBox.Text = newTitle;
                _session.Commit();
            }
            infoFlyout?.Hide();
        };
        buttonPanel.Children.Add(okButton);
        panel.Children.Add(buttonPanel);

        infoFlyout = new Flyout { Content = panel };
        ShowExclusiveFlyout(infoFlyout, anchor);
    }

    private async Task OpenUserGuideAsync()
    {
        try
        {
            // Resolve at opening time so a language change also applies to the next guide.
            // Files are bundled offline; older/incomplete deployments retain the zh-TW fallback.
            var guidePath = System.IO.Path.Combine(AppContext.BaseDirectory, "Assets", "Guides", Localization.Strings.Language + ".html");
            if (!System.IO.File.Exists(guidePath))
                guidePath = System.IO.Path.Combine(AppContext.BaseDirectory, "Assets", "HeiBanUserGuide.html");
            if (System.IO.File.Exists(guidePath))
            {
                var guide = await global::Windows.Storage.StorageFile.GetFileFromPathAsync(guidePath);
                await Launcher.LaunchFileAsync(guide);
            }
            else
            {
                StatusText.Text = T("手冊路徑未找到");
            }
        }
        catch (Exception ex)
        {
            await Error(ex);
        }
    }

    private int _saveIndicatorState = -1;
    private string? _saveIndicatorTooltip;
    private void UpdateSaveStatusLight(string status)
    {
        if (SaveStatusDot == null) return;
        var failed=_saveFailed;
        var pending=_session.IsDirty||_propertyEditing||_editor is not null||_pinNameEditor is not null||_ink.IsDrawing||_preview is not null||_session.HasTransaction||_saving;
        var state=failed?2:pending?1:0;
        // Pointer preview invalidations also reach here. Rebuild XAML only on a state transition.
        if(state!=_saveIndicatorState)
        {
            SaveStatusDot.Content=pending||failed?SelectionCircle(false,true):new TextBlock{Text="✓",FontSize=18,Foreground=Brush("#39735A"),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
            SaveStatusDot.Foreground=Brush(failed?"#CF4860":pending?"#A87929":"#39735A");
            _saveIndicatorState=state;
        }
        var tooltip=failed?F($"儲存未完成：{status}"):pending?T("尚未儲存完成"):T("本機已存");
        if(tooltip!=_saveIndicatorTooltip){ToolTipService.SetToolTip(SaveStatusDot,tooltip);_saveIndicatorTooltip=tooltip;}
    }

    private SolidColorBrush Brush(string hex) => new(Direct2DCanvasRenderer.HexToColor(hex));
    private ToolStyle CurrentStyle => _toolStyles.TryGetValue(_styleTool, out var style) ? style : (_toolStyles[_styleTool] = new());

    private Button IconButton(string icon, string tooltip, Action action, string? key = null)
    {
        var button = ToolbarUi.CreateButton(icon, tooltip, action, key);
        button.Style = (Style)Application.Current.Resources["ToolButtonStyle"];
        return button;
    }

    private void ShowExclusiveFlyout(FlyoutBase flyout, FrameworkElement anchor)
    {
        ToolbarUi.ApplyReadingDirection(flyout);
        if (_activeFlyout != null && _activeFlyout != flyout)
        {
            _activeFlyout.Hide();
        }
        _activeFlyout = flyout;
        flyout.Closed += (_, _) => { if (_activeFlyout == flyout) _activeFlyout = null; };
        flyout.OverlayInputPassThroughElement=ToolBorder;
        flyout.ShowAt(anchor);
    }

    private void BuildChrome()
    {
        HomeButton.Content = ToolIcons.Create("chevron-left");
        HeaderPinButton.Content=ToolIcons.Create(_headerPinned?"lock":"unlock");
        ScreenCanvasButton.Content=ToolIcons.Create("screen");
        ReadingModeButton.Content = ToolIcons.Create("reading");
        PinNavButton.Content = ToolIcons.Create("pins");
        InsertNavButton.Content = ToolIcons.Create("plus");
        MoreNavButton.Content = ToolIcons.Create("more");
        BackgroundButton.Content = ToolIcons.Create("background");
        ExportButton.Content = ToolIcons.Create("export");
        SaveButton.Content = ToolIcons.Create("save");
        LayersButton.Content = ToolIcons.Create("layers");
        InspectorBookmark.Content = ToolIcons.Create("settings");
        CloseInspectorButton.Content = ToolIcons.Create("close");

        foreach (var b in new[] { HomeButton, ScreenCanvasButton, ReadingModeButton, PinNavButton, InsertNavButton, MoreNavButton, HeaderPinButton, BackgroundButton, ExportButton, SaveButton, LayersButton, CloseInspectorButton })
            b.Style = (Style)Application.Current.Resources["ToolButtonStyle"];

        Tools.Children.Clear();
        _toolButtons.Clear();
        _toolDividers.Clear();

        void Tool(string icon, string tip, string key)
        {
            var b = IconButton(icon, tip, () => {if(key=="laser"&&_tool=="laser")ShowLaserSettings(GetToolAnchor(key));else ActivateTool(key);}, key);
            _toolButtons[key] = b;
            Tools.Children.Add(b);
        }

        void Divider()
        {
            var d = new Border { Width = 1, Height = 22, Margin = new Thickness(5), Background = Brush("#D4DBD1") };
            _toolDividers.Add(d);
            Tools.Children.Add(d);
        }

        // 依據 _toolbarPrefs.VisibleTools 動態建構工具列
        var visible = _toolbarPrefs.VisibleTools;
        var needsDividerBefore = new HashSet<string> { "pen", "shapes", "brush", "pins" };

        foreach (var key in visible)
        {
            if (needsDividerBefore.Contains(key) && Tools.Children.Count > 0 && Tools.Children[^1] is not Border)
            {
                Divider();
            }

            switch (key)
            {
                case "laser" or "tape" or "lasso":
                    Tool(key,key=="laser"?T("雷射：再次點擊開啟設定"):T(ToolbarPreferences.ToolNames[key]),key);break;
                case "extension": break; // 延伸屬性改由線段設定提供；保留舊偏好欄位。
                case "magnet":
                    var magnet=IconButton("magnet",T("磁鐵"),ToggleMagnet,"magnet");_toolButtons[key]=magnet;Tools.Children.Add(magnet);break;
                case "layers":
                    var layers=IconButton("layers",T("物件圖層"),()=>Layers_Click(this,new RoutedEventArgs()),"layers");
                    _toolButtons[key]=layers;Tools.Children.Add(layers);break;
                case "clearAll" or "viewLock":
                    var extraKey=key;var extra=IconButton(key=="clearAll"?"delete":key=="viewLock"?"lock":"line",T(ToolbarPreferences.ToolNames[key]),()=>InvokeToolByKey(extraKey),key);
                    _toolButtons[key]=extra;Tools.Children.Add(extra);break;
                case "select": Tool("select", T("選取（V）"), "select"); break;
                case "pen": Tool("pen", T("鋼筆／向量筆（P）"), "pen"); break;
                case "curve": Tool("curve", T("可編輯曲線"), "curve"); break;
                case "highlighter": Tool("highlighter", T("螢光筆"), "highlighter"); break;
                case "paint": Tool("paint", T("油漆筆刷"), "paint"); break;
                case "eraser":
                    var eraser = IconButton("eraser", T("橡皮擦：模式與大小（E）"), () => { ActivateTool("eraser"); ShowEraserSettings(_toolButtons["eraser"]); }, "eraser");
                    _toolButtons["eraser"] = eraser;
                    Tools.Children.Add(eraser);
                    break;
                case "ruler":
                    var ruler = IconButton("ruler", T("螢幕尺；右鍵設定角度與配色"), () => Ruler_Click(this, new()), "ruler");
                    ruler.RightTapped += (_, e) => { ShowRulerSettings(ruler); e.Handled = true; };
                    _toolButtons["ruler"] = ruler;
                    Tools.Children.Add(ruler);
                    break;
                case "shapes":
                    var shapes = IconButton("shapes", T("圖形：直線、箭頭、矩形、圓與多邊形"), () => ShowShapes(_toolButtons["shapes"]), "shapes");
                    _toolButtons["shapes"] = shapes;
                    Tools.Children.Add(shapes);
                    break;
                case "sticky": Tool("sticky", T("便條紙"), "sticky"); break;
                case "text": Tool("text", T("文字（T）"), "text"); break;
                case "screenshot":
                    Tools.Children.Add(IconButton("screenshot", T("截圖：拖曳框選後直接置入畫布"), () => Screenshot_Click(this, new()), "screenshot"));
                    _toolButtons["screenshot"] = (Button)Tools.Children[^1];
                    break;
                case "image":
                    Tools.Children.Add(IconButton("image", T("匯入圖片；也可拖入桌面截圖"), () => Image_Click(this, new()), "image"));
                    _toolButtons["image"] = (Button)Tools.Children[^1];
                    break;
                case "brush":
                    _brushSwatch = new Ellipse { Width = 24, Height = 24, Fill = Brush(_strokeColor), Stroke = Brush("#879487"), StrokeThickness = 1 };
                    _brushButton = new Button { Style = (Style)Application.Current.Resources["ToolButtonStyle"], Content = _brushSwatch, Tag = "brush" };
                    ToolTipService.SetToolTip(_brushButton, T("顏色、粗細與透明度；選取物件時直接修改物件"));
                    Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(_brushButton, T("繪圖與物件設定"));
                    _brushButton.Click += (_, _) => ShowBrushSettings(_brushButton);
                    _toolButtons["brush"] = _brushButton;
                    Tools.Children.Add(_brushButton);
                    break;
                case "dash":
                    Tools.Children.Add(IconButton("dash", T("線條樣式"), () => ShowLineStyles(_toolButtons["dash"]), "dash"));
                    _toolButtons["dash"] = (Button)Tools.Children[^1];
                    break;
                case "pins":
                    var pin = IconButton("pins", T("圖釘"), () => Pin_Click(this, new()), "pins");
                    _toolButtons["pins"] = pin;
                    Tools.Children.Add(pin);
                    break;
                case "undo":
                    Tools.Children.Add(IconButton("undo", T("復原（Ctrl+Z）"), () => Undo_Click(this, new()), "undo"));
                    _toolButtons["undo"] = (Button)Tools.Children[^1];
                    break;
                case "redo":
                    Tools.Children.Add(IconButton("redo", T("重做（Ctrl+Y）"), () => Redo_Click(this, new()), "redo"));
                    _toolButtons["redo"] = (Button)Tools.Children[^1];
                    break;
                case "calculator":
                    Tools.Children.Add(IconButton("calculator", T("計算機：基本與科學計算、插入算式"), () => ShowCalculatorPanel(GetToolAnchor("calculator")), "calculator"));
                    _toolButtons["calculator"] = (Button)Tools.Children[^1];
                    break;
                case "timer":
                    Tools.Children.Add(IconButton("timer", T("計時器：碼表與倒數計時"), () => ShowTimerPanel(GetToolAnchor("timer")), "timer"));
                    _toolButtons["timer"] = (Button)Tools.Children[^1];
                    break;
                case "compass":
                    var compassBtn = IconButton("compass", T("圓規：畫布兩階段繪製精確圓弧；右鍵開啟參數面板"), () => Compass_Click(this, new()), "compass");
                    compassBtn.RightTapped += (_, e) => { ShowCompassPanel(compassBtn); e.Handled = true; };
                    _toolButtons["compass"] = compassBtn;
                    Tools.Children.Add(compassBtn);
                    break;
                case "dock":
                    Tools.Children.Add(IconButton("dock", T("工具列停靠位置"), () => Dock_Click(Tools.Children[^1], new()), "dock"));
                    _toolButtons["dock"] = (Button)Tools.Children[^1];
                    break;
            }
        }

        // 加入「更多」按鈕：到達所有隱藏工具、自訂工具列與恢復預設
        var moreButton = IconButton("more", T("更多工具與設定"), () => ShowMoreToolsMenu(GetToolAnchor("more")), "more");
        _toolButtons["more"] = moreButton;
        Tools.Children.Add(moreButton);

        ToolBorder.RenderTransform = _toolbarTranslation;

        if (!_chromeEventsBound)
        {
            AddPalette(StrokePalette, color => ChangeProperty(() => { if (_session.Selected is { } o) o.StrokeColor = color; else { CurrentStyle.Color = color; LoadActiveStyle(); } }));
            AddPalette(FillPalette, color => ChangeProperty(() => SetFillColor(color)));
            WidthSlider.ValueChanged += (_, e) => ChangeProperty(() => { if (_session.Selected is { } o) o.StrokeWidth = e.NewValue; else { CurrentStyle.Width = e.NewValue; LoadActiveStyle(); } });
            OpacitySlider.ValueChanged += (_, e) => ChangeProperty(() => { if (_session.Selected is { } o) o.Opacity = e.NewValue; else { CurrentStyle.Opacity = e.NewValue; LoadActiveStyle(); } });
            FillToggle.Checked += FillChanged;
            FillToggle.Unchecked += FillChanged;
            DashBox.SelectionChanged += (_, _) => ChangeProperty(() => { var dash = DashStyles[Math.Clamp(DashBox.SelectedIndex, 0, 3)]; if (_session.Selected is { } o) o.LineStyle = dash; else CurrentStyle.Dash = dash; });
            RotationBox.ValueChanged += (_, e) => { if (double.IsFinite(e.NewValue)) ChangeProperty(() => { if (_session.Selected is { } o) o.Rotation = Math.Round(e.NewValue, 1); }); };
            FontSizeBox.ValueChanged += (_, e) => { if (double.IsFinite(e.NewValue)) ChangeProperty(() => { if (_session.Selected is { } o) o.FontSize = e.NewValue; else CurrentStyle.FontSize = e.NewValue; }); };
            EraserSizeSlider.ValueChanged += (_, _) => InvalidateCanvas();
            RotationBox.NumberFormatter = RulerAngleBox.NumberFormatter = new DecimalFormatter { FractionDigits = 1 };
            _propertyCommitTimer.Tick += (_, _) => CommitPropertyEdit();
            _headerHideTimer.Tick += (_, _) =>
            {
                if (_headerPinned || _headerHovered || TitleBox.FocusState != FocusState.Unfocused || VisualTreeHelper.GetOpenPopupsForXamlRoot(Root.XamlRoot).Count > 0) return;
                _headerHideTimer.Stop();
                ShowWorkspaceHeader(false);
            };
            _chromeEventsBound = true;
        }

        foreach(var (dash,index) in DashStyles.Select((value,index)=>(value,index)))
        {var sample=new StackPanel{Orientation=Orientation.Horizontal,Spacing=12};sample.Children.Add(ToolIcons.CreateDash(dash));sample.Children.Add(new TextBlock{Text=new[]{T("實線"),T("虛線"),T("點線"),T("點劃線")}[index]});((ComboBoxItem)DashBox.Items[index]).Content=sample;}
        _syncingProperties = false;
        LoadActiveStyle();
        RefreshChrome();
        SetDock(_toolbarPrefs.DockSide);
        EnsureTimerDaemon();
    }

    private void EnsureTimerDaemon()
    {
        if (_timerTickTimer == null)
        {
            _timerTickTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(100) };
            _timerTickTimer.Tick += (_, _) =>
            {
                if (_timerCoordinator.Status == TimerStatus.Running)
                {
                    _timerCoordinator.UpdateDisplayTimes();
                    _activeTimerDisplayUpdater?.Invoke();
                    if (_timerCoordinator.DidAlertTimesUp)
                    {
                        StatusText.Text = T("倒數計時時間到！");
                    }
                }
            };
            _timerTickTimer.Start();
        }
    }

    private void Compass_Click(object sender, RoutedEventArgs e)
    {
        _compass.IsEnabled = !_compass.IsEnabled;
        if (_compass.IsEnabled)
        {
            _compass.Prepare();
            _compass.StrokeColor = _strokeColor;
            _compass.StrokeWidth = EffectiveWidth;
            _compass.LineStyle = CurrentStyle.Dash;
            var centerScreen = new InkPoint(CanvasSurface.ActualWidth / 2, CanvasSurface.ActualHeight / 2);
            _compass.Center = _viewport.ScreenToWorld(centerScreen.X, centerScreen.Y);
            StatusText.Text = T("圓規已啟用：拖曳圓心或半徑把手，點擊圓心鎖定後拖曳筆尖畫弧");
        }
        else
        {
            StatusText.Text = T("圓規已關閉");
        }
        RefreshChrome();
        InvalidateCanvas();
    }

    private void ShowMoreToolsMenu(FrameworkElement anchor)
    {
        var menu = new MenuFlyout();
        var screenItem=new MenuFlyoutItem { Text=T("我的螢幕就是我的畫布"),Icon=ToolIcons.CreateIcon("screen") };
        screenItem.Click+=(_,_)=>ScreenCanvas_Click(this,new());menu.Items.Add(screenItem);menu.Items.Add(new MenuFlyoutSeparator());

        var boardEraserItem=new ToggleMenuFlyoutItem { Text=T("顯示板擦"),IsChecked=_toolbarPrefs.BoardEraserVisible };
        boardEraserItem.Click+=async(_,_)=>
        {
            boardEraserItem.IsEnabled=false;
            try{await SetBoardEraserVisibleAsync(boardEraserItem.IsChecked);}
            finally{boardEraserItem.IsChecked=_toolbarPrefs.BoardEraserVisible;boardEraserItem.IsEnabled=true;}
        };
        menu.Items.Add(boardEraserItem);
        menu.Items.Add(new MenuFlyoutSeparator());

        // 隱藏工具清單
        if (_toolbarPrefs.HiddenTools.Count > 0)
        {
            foreach (var key in _toolbarPrefs.HiddenTools.Where(key=>key!="extension"))
            {
                var toolKey = key;
                var item = new MenuFlyoutItem
                {
                    Text = T(ToolbarPreferences.ToolNames.GetValueOrDefault(toolKey, toolKey)),
                    Icon = ToolIcons.CreateIcon(toolKey)
                };
                item.Click += (_, _) => InvokeToolByKey(toolKey);
                menu.Items.Add(item);
            }
            menu.Items.Add(new MenuFlyoutSeparator());
        }

        var customizeItem = new MenuFlyoutItem { Text = T("自訂工具列…") };
        customizeItem.Click += async (_, _) => await ShowCustomizeToolbarDialog();
        menu.Items.Add(customizeItem);

        var resetItem = new MenuFlyoutItem { Text = T("恢復預設工具列") };
        resetItem.Click += (_, _) => ResetToolbarToDefault();
        menu.Items.Add(resetItem);

        ShowExclusiveFlyout(menu, anchor);
    }

    private void InvokeToolByKey(string key)
    {
        switch (key)
        {
            case "magnet": ToggleMagnet();break;
            case "laser": if(_tool=="laser")ShowLaserSettings(GetToolAnchor(key));else ActivateTool(key);break;
            case "tape" or "lasso" or "select" or "pen" or "curve" or "highlighter" or "paint" or "sticky" or "text" or "star":
                ActivateTool(key);
                break;
            case "extension": Inspector.Visibility=Visibility.Visible;RefreshProperties();RefreshChrome();break;
            case "layers": Layers_Click(this,new RoutedEventArgs());break;
            case "viewLock": NavigationLock_Click(this,new RoutedEventArgs());break;
            case "clearAll": ClearPage();break;
            case "calculator":
                ShowCalculatorPanel(GetToolAnchor("calculator"));
                break;
            case "timer":
                ShowTimerPanel(GetToolAnchor("timer"));
                break;
            case "compass":
                Compass_Click(this, new());
                break;
            case "eraser":
                ActivateTool("eraser");
                ShowEraserSettings(GetToolAnchor("eraser"));
                break;
            case "ruler":
                Ruler_Click(this, new());
                break;
            case "shapes":
                ShowShapes(GetToolAnchor("shapes"));
                break;
            case "screenshot":
                Screenshot_Click(this, new());
                break;
            case "image":
                Image_Click(this, new());
                break;
            case "brush":
                ShowBrushSettings(GetToolAnchor("brush"));
                break;
            case "dash":
                ShowLineStyles(GetToolAnchor("dash"));
                break;
            case "pins":
                Pin_Click(this, new());
                break;
            case "undo":
                Undo_Click(this, new());
                break;
            case "redo":
                Redo_Click(this, new());
                break;
            case "dock":
                Dock_Click(GetToolAnchor("dock"), new());
                break;
        }
    }

    private async Task ShowCustomizeToolbarDialog()
    {
        var allKeys = _toolbarPrefs.VisibleTools
            .Concat(_toolbarPrefs.HiddenTools)
            .Concat(ToolbarPreferences.AllDefaultTools)
            .Distinct().Where(key=>key!="extension")
            .ToList();

        var visibleSet = new HashSet<string>(_toolbarPrefs.VisibleTools);
        var commonSet = new HashSet<string>(_toolbarPrefs.CommonTools);
        var displayMode=_toolbarPrefs.DisplayMode;
        var panel = new StackPanel { Spacing = 6 };

        void RebuildList()
        {
            panel.Children.Clear();
            for (var i = 0; i < allKeys.Count; i++)
            {
                var idx = i;
                var key = allKeys[i];
                var grid = new Grid { ColumnSpacing = 8 };
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var cb = new CheckBox
                {
                    Content = new StackPanel{Orientation=Orientation.Horizontal,Spacing=10,Children={ToolIcons.Create(key),new TextBlock{Text=T(ToolbarPreferences.ToolNames.GetValueOrDefault(key,key)),MaxWidth=160,TextWrapping=TextWrapping.Wrap,VerticalAlignment=VerticalAlignment.Center}}},
                    IsEnabled=key!="select",IsChecked = key=="select"||visibleSet.Contains(key)
                };
                cb.Checked += (_, _) => visibleSet.Add(key);
                cb.Unchecked += (_, _) => visibleSet.Remove(key);
                Grid.SetColumn(cb, 0);
                grid.Children.Add(cb);

                var upBtn = new Button { Content = "↑", Padding = new Thickness(6, 2, 6, 2), IsEnabled = idx > 0 };
                upBtn.Click += (_, _) =>
                {
                    (allKeys[idx - 1], allKeys[idx]) = (allKeys[idx], allKeys[idx - 1]);
                    RebuildList();
                };
                var common=new CheckBox{Content=T("常用"),IsChecked=commonSet.Contains(key),IsEnabled=key!="select",MinWidth=72};
                common.Checked+=(_,_)=>{commonSet.Add(key);visibleSet.Add(key);cb.IsChecked=true;};
                common.Unchecked+=(_,_)=>commonSet.Remove(key);
                Grid.SetColumn(common,1);grid.Children.Add(common);
                Grid.SetColumn(upBtn, 2);
                grid.Children.Add(upBtn);

                var downBtn = new Button { Content = "↓", Padding = new Thickness(6, 2, 6, 2), IsEnabled = idx < allKeys.Count - 1 };
                downBtn.Click += (_, _) =>
                {
                    (allKeys[idx + 1], allKeys[idx]) = (allKeys[idx], allKeys[idx + 1]);
                    RebuildList();
                };
                Grid.SetColumn(downBtn, 3);
                grid.Children.Add(downBtn);

                panel.Children.Add(new Border{Background=Brush("#F0F4EC"),BorderBrush=Brush("#DFE6D9"),BorderThickness=new Thickness(1),CornerRadius=new CornerRadius(12),Padding=new Thickness(10,4,10,4),Child=grid});
            }
        }

        RebuildList();

        var scroll = new ScrollViewer { Content = panel, MaxHeight = 360, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        var dialog = new ContentDialog
        {FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,
            Title = T("自訂工具列"),
            Content = new StackPanel{Spacing=10,Children={CustomizeToolbarHeader(visibleSet,allKeys,RebuildList,displayMode,value=>displayMode=value,()=>{commonSet.Clear();commonSet.UnionWith(new ToolbarPreferences().CommonTools);}),new TextBlock{Text=T("左側勾選顯示工具，勾選「常用」加入常用分頁；選取工具會持續顯示。"),TextWrapping=TextWrapping.Wrap,FontSize=12,Foreground=Brush("#65746A")},scroll}},
            PrimaryButtonText = T("儲存"),
            CloseButtonText = T("取消"),
            XamlRoot = Root.XamlRoot
        };

        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;

        var newVisible = new List<string>();
        var newHidden = new List<string>();

        foreach (var key in allKeys)
        {
            if (visibleSet.Contains(key)) newVisible.Add(key);
            else newHidden.Add(key);
        }

        if (newVisible.Count == 0) newVisible.Add("select");

        _toolbarPrefs.DisplayMode=displayMode;
        _toolbarPrefs.CommonTools=allKeys.Where(commonSet.Contains).ToList();
        _toolbarPrefs.VisibleTools = newVisible;
        _toolbarPrefs.HiddenTools = newHidden;
        await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory, _toolbarPrefs);
        BuildChrome();
    }

    private void ResetToolbarToDefault()
    {
        _toolbarPrefs.ResetToDefault();
        _ = ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory, _toolbarPrefs);
        BuildChrome();
    }

    internal async Task SaveToolbarPreferencesAsync(ToolbarPreferences preferences)
    {
        // Screen canvas shares the settings file. Update the hidden owner in-memory too, or its
        // next toolbar rebuild could overwrite a choice just made in the screen session.
        var updated=new ToolbarPreferences{DockSide=preferences.DockSide,DisplayMode=preferences.DisplayMode,MagnetEnabled=preferences.MagnetEnabled,BoardEraserVisible=preferences.BoardEraserVisible,DefaultToolsRevision=preferences.DefaultToolsRevision,DefaultPresentationRevision=preferences.DefaultPresentationRevision,CommonTools=[..preferences.CommonTools],ExtraFields=preferences.ExtraFields,VisibleTools=[..preferences.VisibleTools],HiddenTools=[..preferences.HiddenTools]};
        updated.Normalize();
        await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,updated);
        _toolbarPrefs=updated;
        BuildChrome();
    }

    private void AddPalette(StackPanel panel, Action<string> set)
    {
        foreach (var color in Palette)
        {
            var b = new Button
            {
                Width = 24, Height = 24, Padding = new Thickness(2),
                BorderThickness = new Thickness(0), Background = Brush("#FCFCFA"),
                CornerRadius = new CornerRadius(12),
                Content = new Ellipse { Width = 18, Height = 18, Fill = Brush(color), Stroke = Brush("#A7B2A3"), StrokeThickness = 1 }
            };
            ToolTipService.SetToolTip(b, color);
            b.Click += (_, _) => set(color);
            panel.Children.Add(b);
        }
    }

    private async void ActivateTool(string tool)
    {
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        using var trace=InputLatencyTrace.Measure(InputStage.ToolSwitch);
        _activeFlyout?.Hide();
        if(tool==_tool&&!_gesture&&_editor is null&&_polygon.Count==0&&_session.SelectedIds.Count==0)
        {FocusCanvasSurface();return;}
        CommitPropertyEdit();
        FinishText();
        var color=CurrentStyle.Color;var dash=CurrentStyle.Dash;
        CancelGesture();
        _polygon.Clear();
        _session.SelectedId = null;_objectDetailsId=null;
        _tool = tool;
        if (tool is not ("select" or "eraser"))
        {
            _styleTool = tool;
            CurrentStyle.Color=color;CurrentStyle.Dash=dash;
            LoadActiveStyle();
        }
        RefreshProperties();
        RefreshChrome();
        RefreshSelectionBar();
        FocusCanvasSurface();
        InvalidateCanvas(false);
    }

    private void LoadActiveStyle()
    {
        _strokeColor = CurrentStyle.Color;
        _strokeWidth = CurrentStyle.Width;
        _opacity = CurrentStyle.Opacity;
        _fillColor = CurrentStyle.Fill;
        if (_brushSwatch is not null) _brushSwatch.Fill = Brush(_strokeColor);
    }

    private void RefreshChrome()
    {
        RefreshBoardEraser();
        foreach (var (key, b) in _toolButtons)
        {
            ToolbarUi.LabelMode(b,key,_toolbarPrefs.DisplayMode=="labels",40);
            var active = (key=="magnet"&&_toolbarPrefs.MagnetEnabled) || (key=="layers"&&LayersPanel.Visibility==Visibility.Visible) || key == _tool || (key == "ruler" && _rulerEnabled) || (key == "compass" && _compass.IsEnabled) || (key == "shapes" && _tool is "line" or "arrow" or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star");
            var color=Direct2DCanvasRenderer.HexToColor(active?"#DCEBDD":"#FCFCFA");
            if(b.Background is not SolidColorBrush current||current.Color!=color)b.Background=new SolidColorBrush(color);
        }
        CanvasFormatText.Text = _session.Document.Board.CanvasMode switch { "notebook" => T("筆記本"), "fixed" => T("有邊界黑板"), _ => T("無邊界筆記") };
        RefreshNavigationChrome();UpdateSaveStatusLight(StatusText.Text);
        InspectorBookmark.Visibility = Inspector.Visibility == Visibility.Visible ? Visibility.Collapsed : Visibility.Visible;
    }

    private Button? _dashIconButton;
    private string? _dashIconStyle;
    private void RefreshProperties()
    {
        if (StrokeColorButton is null) return;
        var o = _session.Selected;
        var style = CurrentStyle;
        var dash=o?.LineStyle??style.Dash;
        if(_toolButtons.TryGetValue("dash",out var dashButton)&&(!ReferenceEquals(_dashIconButton,dashButton)||_dashIconStyle!=dash))
        {
            var icon=ToolIcons.CreateDash(dash);
            ToolbarUi.ReplaceIcon(dashButton,icon);
            _dashIconButton=dashButton;_dashIconStyle=dash;
        }
        if(_brushSwatch is not null)_brushSwatch.Fill=Brush(o?.StrokeColor??style.Color);
        // Hidden properties are synchronized when opened; tool switches need only
        // their swatches, not every slider, number box and inspector section.
        if(o is null&&Inspector.Visibility!=Visibility.Visible){RefreshSelectionBar();return;}
        _syncingProperties = true;
        WidthSlider.Value = o?.StrokeWidth ?? style.Width;
        OpacitySlider.Value = o?.Opacity ?? style.Opacity;
        RotationBox.Value = o?.Rotation ?? 0;
        FontSizeBox.Value = o?.FontSize ?? style.FontSize;
        FillToggle.IsChecked = o is null ? style.Filled : o.FillColor != "none";
        FillOpacitySlider.Value=o?.FillOpacity??style.FillOpacity??1;
        DashBox.SelectedIndex = Math.Max(0, Array.IndexOf(DashStyles, o?.LineStyle ?? style.Dash));
        StrokeColorButton.Content = T("自訂色輪 · ") + (o?.StrokeColor ?? style.Color);
        if (_brushSwatch is not null) _brushSwatch.Fill = Brush(o?.StrokeColor ?? style.Color);
        FillColorButton.Content = T("自訂填色與透明度");
        WidthValueText.Text = F($"{WidthSlider.Value:0.#} pt · 畫布直徑 {WidthSlider.Value * _viewport.Zoom:0.#} pt");
        SelectionSummary.Text = o is null ? T("目前畫筆 · 設定即時生效") : o.IsLocked == true ? T("物件已鎖定") : T("已選取物件 · 設定即時生效");
        ApplyInspectorContext(o);
        _syncingProperties = false;
        RefreshSelectionBar();
    }

    private void ChangeProperty(Action change)
    {
        if (_syncingProperties || _gesture || _session.Selected?.IsLocked == true) return;
        if (_session.Selected is not null)
        {
            _session.Begin();
            _propertyEditing = true;
            _propertyCommitTimer.Stop();
            _propertyCommitTimer.Start();
        }
        var oldColor=_session.Selected?.StrokeColor??CurrentStyle.Color;var oldDash=_session.Selected?.LineStyle??CurrentStyle.Dash;
        var before=_session.Selected is { } primary && _session.SelectedIds.Count>1 ? DocumentCodec.Clone(primary):null;
        change();
        var color=_session.Selected?.StrokeColor??CurrentStyle.Color;var dash=_session.Selected?.LineStyle??CurrentStyle.Dash;
        if(color!=oldColor||dash!=oldDash)
        {
            foreach(var setting in _toolStyles.Values){if(color!=oldColor)setting.Color=color;if(dash!=oldDash)setting.Dash=dash;}
            LoadActiveStyle();QueueTeachingSettingsSave();
        }
        else if(_session.Selected is null)QueueTeachingSettingsSave();
        if(before is not null&&_session.Selected is { } changed)SelectionStyle.ApplyChanged(before,changed,_session.SelectedObjects);
        if (_preview is not null) Styled(_preview);
        RefreshProperties();
        InvalidateCanvas(_session.Selected is not null);
    }

    private readonly Dictionary<string, string> _objectFillColors = [];

    private void SetFillColor(string color)
    {
        if (_session.Selected is { } o)
        {
            o.FillColor = color;
            o.FillGradientStart = o.FillGradientEnd = null;
            _objectFillColors[o.Id] = color;
        }
        else
        {
            CurrentStyle.Fill = color;
            CurrentStyle.Filled = true;
            CurrentStyle.FillGradientStart = CurrentStyle.FillGradientEnd = null;
            LoadActiveStyle();
        }
    }

    private void SetFillGradient(string startColor, string endColor)
    {
        if (_session.Selected is { } o)
        {
            o.FillColor = startColor;
            o.FillGradientStart = startColor;
            o.FillGradientEnd = endColor;
        }
        else
        {
            CurrentStyle.Fill = startColor;
            CurrentStyle.FillGradientStart = startColor;
            CurrentStyle.FillGradientEnd = endColor;
            CurrentStyle.Filled = true;
            LoadActiveStyle();
        }
    }

    private void SetFilled(bool filled)
    {
        if (_session.Selected is { } o)
        {
            if (!filled && o.FillColor != "none") _objectFillColors[o.Id] = o.FillColor;
            o.FillColor = filled ? (_objectFillColors.GetValueOrDefault(o.Id) ?? CurrentStyle.Fill) : "none";
            if (!filled) o.FillGradientStart = o.FillGradientEnd = null;
        }
        else CurrentStyle.Filled = filled;
    }

    private void FillChanged(object sender, RoutedEventArgs e) => ChangeProperty(() => SetFilled(FillToggle.IsChecked == true));
    private void CommitPropertyEdit() { _propertyCommitTimer.Stop(); if (_propertyEditing) { _session.Commit(); _propertyEditing = false; } }

    private void ShowShapes(FrameworkElement anchor)
        =>ShowExclusiveFlyout(ToolbarUi.Shapes(ActivateTool),anchor);

    private void ShowLineStyles(FrameworkElement anchor)
    {
        var menu = ToolbarUi.LineStyles(value => ChangeProperty(() => { if (_session.Selected is { } o) o.LineStyle = value; else CurrentStyle.Dash = value; }));
        ShowExclusiveFlyout(menu, anchor);
    }

    private ColorPicker ColorWheel(string current) => new() { Color = Direct2DCanvasRenderer.HexToColor(current), ColorSpectrumShape = ColorSpectrumShape.Ring, IsAlphaEnabled = true, IsAlphaSliderVisible = true, IsAlphaTextInputVisible = true, IsColorChannelTextInputVisible = false, IsHexInputVisible = true, Width = 260 };
    private static string ColorHex(global::Windows.UI.Color c) => $"#{c.R:X2}{c.G:X2}{c.B:X2}{c.A:X2}";

    private void ShowColorWheel(FrameworkElement anchor, string current, Action<string> update)
    {
        var picker = ColorWheel(current);
        picker.ColorChanged += (_, e) => update(ColorHex(e.NewColor));
        var f = new Flyout { Content = picker };
        f.Closed += (_, _) => CommitPropertyEdit();
        ShowExclusiveFlyout(f, anchor);
    }

    private void ShowBrushSettings(FrameworkElement anchor)
    {
        using var trace=InputLatencyTrace.Measure(InputStage.BrushPanel);
        var selected = _session.Selected;
        if(selected is not null){Inspector.Visibility=Visibility.Visible;RefreshProperties();RefreshChrome();return;}
        if(_tool=="laser"){ShowLaserSettings(anchor);return;}
        var panel = new StackPanel { Width = 286, Spacing = 12 };
        panel.Children.Add(new TextBlock { Text = selected is null ? F($"繪圖設定（{T(ToolbarPreferences.ToolNames.GetValueOrDefault(_styleTool,_styleTool))}）") : T("已選取物件設定"), FontSize = 16, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        AddExtendedObjectSettings(panel,selected);
        var palette = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 5 };
        AddPalette(palette, c => ChangeProperty(() => { if (_session.Selected is { } o) o.StrokeColor = c; else { CurrentStyle.Color = c; LoadActiveStyle(); } }));
        panel.Children.Add(palette);
        var wheel = ColorWheel(selected?.StrokeColor ?? CurrentStyle.Color);
        panel.Children.Add(wheel);
        var width = new Slider { Header = T("線條粗細（pt）"), Minimum = .5, Maximum = 128, Value = selected?.StrokeWidth ?? CurrentStyle.Width, StepFrequency = .5 };
        panel.Children.Add(width);
        var presets = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
        foreach (var n in new[] { 2d, 3.5, 6, 10, 18, 32 })
        {
            var b = new Button { Content = $"{n:0.#}", Padding = new Thickness(7, 4, 7, 4) };
            b.Click += (_, _) => width.Value = n;
            presets.Children.Add(b);
        }
        panel.Children.Add(presets);
        var alpha = new Slider { Header = T("筆畫透明度"), Minimum = 0, Maximum = 1, StepFrequency = .01, Value = selected?.Opacity ?? CurrentStyle.Opacity };
        panel.Children.Add(alpha);

        CheckBox? filled = null;
        if ((selected?.Type ?? _styleTool) is "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star" or "arc" or "sticky")
        {
            filled = new CheckBox { Content = T("填滿圖形"), IsChecked = selected is null ? CurrentStyle.Filled : selected.FillColor != "none" };
            panel.Children.Add(filled);
            var fillPalette = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 5 };
            AddPalette(fillPalette, c => { ChangeProperty(() => SetFillColor(c)); filled.IsChecked = true; });
            panel.Children.Add(fillPalette);

            var fillAlpha = new Slider { Header = T("填色透明度"), Minimum = 0, Maximum = 1, StepFrequency = .01, Value = selected?.FillOpacity ?? CurrentStyle.FillOpacity ?? 1.0 };
            fillAlpha.ValueChanged += (_, e) => ChangeProperty(() => { if (_session.Selected is { } o) o.FillOpacity = e.NewValue; else CurrentStyle.FillOpacity = e.NewValue; });
            panel.Children.Add(fillAlpha);

            var fillButton = new Button { Content = T("自訂填色與透明度"), HorizontalAlignment = HorizontalAlignment.Stretch };
            fillButton.Click += (_, _) => ShowColorWheel(fillButton, _session.Selected is { FillColor: not "none" } o ? o.FillColor : CurrentStyle.Fill, c => { ChangeProperty(() => SetFillColor(c)); filled.IsChecked = true; });
            panel.Children.Add(fillButton);

            var gradientRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            var grad1 = new Button { Content = T("自然綠漸層"), FontSize = 12 };
            grad1.Click += (_, _) => { ChangeProperty(() => SetFillGradient("#86EFAC", "#3B82F6")); filled.IsChecked = true; };
            var grad2 = new Button { Content = T("晨曦橙漸層"), FontSize = 12 };
            grad2.Click += (_, _) => { ChangeProperty(() => SetFillGradient("#FED7AA", "#F472B6")); filled.IsChecked = true; };
            gradientRow.Children.Add(grad1);
            gradientRow.Children.Add(grad2);
            panel.Children.Add(gradientRow);

            filled.Checked += (_, _) => ChangeProperty(() => SetFilled(true));
            filled.Unchecked += (_, _) => ChangeProperty(() => SetFilled(false));
        }

        var label = new TextBlock { FontSize = 12, Foreground = Brush("#68756C") };
        panel.Children.Add(label);
        var dot = new Ellipse { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        var preview = new Grid { MinWidth = 260, MinHeight = 80, Background = Brush("#E9EEE6") };
        preview.Children.Add(dot);
        panel.Children.Add(new ScrollViewer { Content = preview, Height = 100, HorizontalScrollBarVisibility = ScrollBarVisibility.Auto, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });

        void Sync()
        {
            RefreshProperties();
            var o = _session.Selected;
            dot.Width = dot.Height = (o?.StrokeWidth ?? CurrentStyle.Width) * _viewport.Zoom;
            dot.Fill = Brush(o?.StrokeColor ?? CurrentStyle.Color);
            dot.Opacity = o?.Opacity ?? CurrentStyle.Opacity;
            preview.MinWidth = Math.Max(260, dot.Width + 24);
            preview.MinHeight = Math.Max(80, dot.Height + 24);
            label.Text = F($"畫布直徑 {dot.Width:0.#} pt · 縮放 {_viewport.Zoom:P0} · 透明度 {dot.Opacity:P0}");
            InvalidateCanvas();
        }

        wheel.ColorChanged += (_, e) => { ChangeProperty(() => { if (_session.Selected is { } o) o.StrokeColor = ColorHex(e.NewColor); else { CurrentStyle.Color = ColorHex(e.NewColor); LoadActiveStyle(); } }); Sync(); };
        width.ValueChanged += (_, e) => { ChangeProperty(() => { if (_session.Selected is { } o) o.StrokeWidth = e.NewValue; else { CurrentStyle.Width = e.NewValue; LoadActiveStyle(); } }); Sync(); };
        alpha.ValueChanged += (_, e) => { ChangeProperty(() => { if (_session.Selected is { } o) o.Opacity = e.NewValue; else { CurrentStyle.Opacity = e.NewValue; LoadActiveStyle(); } }); Sync(); };
        foreach (var child in palette.Children.OfType<Button>()) child.Click += (_, _) => { wheel.Color = Direct2DCanvasRenderer.HexToColor(_session.Selected?.StrokeColor ?? CurrentStyle.Color); Sync(); };
        if (_rulerEnabled) { var b = new Button { Content = T("尺規角度與配色…") }; b.Click += (_, _) => ShowRulerSettings(anchor); panel.Children.Add(b); }
        Sync();
        var flyout = new Flyout { Content = new ScrollViewer { Content = panel, MaxHeight = Math.Max(300, Root.ActualHeight - 100), VerticalScrollBarVisibility = ScrollBarVisibility.Auto } };
        flyout.Closed += (_, _) => CommitPropertyEdit();
        ShowExclusiveFlyout(flyout, anchor);
    }

    private void ShowEraserSettings(FrameworkElement anchor)
    {
        var panel = new StackPanel { Width = 260, Spacing = 12 };
        panel.Children.Add(new TextBlock { Text = T("橡皮擦"), FontSize = 16 });
        var mode = new ComboBox { ItemsSource = new[] { T("物件擦除（筆畫與圖形）"), T("局部擦除（只擦筆跡）") }, SelectedIndex = EraserModeBox.SelectedIndex, HorizontalAlignment = HorizontalAlignment.Stretch };
        mode.SelectionChanged += (_, _) => EraserModeBox.SelectedIndex = mode.SelectedIndex;
        panel.Children.Add(mode);
        var size = new Slider { Header = T("直徑（pt）"), Minimum = 4, Maximum = 160, Value = EraserSizeSlider.Value };
        size.ValueChanged += (_, e) => EraserSizeSlider.Value = e.NewValue;
        panel.Children.Add(size);
        ShowExclusiveFlyout(new Flyout { Content = panel }, anchor);
    }

    /// <summary>
    /// W-V02: 更新選取物件附近快速操作列
    /// </summary>
    private void RefreshSelectionBar()
    {
        if (SelectionBar is null || SelectionBarTools is null) return;
        var selected = _session.Selected;
        if (selected is null || !_workspaceOpen || _objectDetailsId!=selected.Id)
        {
            _selectionBarSignature = null;_selectionBarObject=null;_selectionBarUpdates.Clear();
            SelectionBar.Visibility = Visibility.Collapsed;
            return;
        }

        var signature = $"{selected.Id}:{selected.IsLocked}:{selected.Type}";
        if (_selectionBarSignature != signature||!ReferenceEquals(_selectionBarObject,selected))
        {
            RebuildSelectionBar(selected);
            _selectionBarSignature = signature;_selectionBarObject=selected;
        }

        foreach(var update in _selectionBarUpdates)update(selected);
        UpdateSelectionBarPosition();
    }

    private void RebuildSelectionBar(BoardObject selected)
    {
        SelectionBar.Visibility = Visibility.Visible;
        SelectionBarTools.Children.Clear();_selectionBarUpdates.Clear();

        Button QuickButton(string icon, string tip, Action<Button> action)
        {
            var btn = new Button
            {
                Style = (Style)Application.Current.Resources["ToolButtonStyle"],
                Content = ToolIcons.Create(icon),
                Width = 32, Height = 32, Padding = new Thickness(4)
            };
            ToolTipService.SetToolTip(btn, tip);
            btn.Click += (_, _) => action(btn);
            return btn;
        }

        var actions = SelectionQuickActionCoordinator.GetAvailableActions(selected);

        foreach (var action in actions)
        {
            switch (action)
            {
                case QuickActionItem.StrokeColor:
                    var colorDot = new Ellipse { Width = 16, Height = 16, Fill = Brush(selected.StrokeColor), Stroke = Brush("#879487"), StrokeThickness = 1 };
                    var colorBtn = new Button { Style = (Style)Application.Current.Resources["ToolButtonStyle"], Content = colorDot, Width = 32, Height = 32, Padding = new Thickness(4) };
                    ToolTipService.SetToolTip(colorBtn, T("線條色彩"));
                    colorBtn.Click += (_, _) => ShowColorWheel(colorBtn, selected.StrokeColor, c => ChangeProperty(() => selected.StrokeColor = c));
                    var shownColor=selected.StrokeColor;_selectionBarUpdates.Add(o=>{if(o.StrokeColor!=shownColor){shownColor=o.StrokeColor;colorDot.Fill=Brush(shownColor);}});
                    SelectionBarTools.Children.Add(colorBtn);
                    break;

                case QuickActionItem.StrokeWidth:
                    var wBtn = new Button { Style = (Style)Application.Current.Resources["ToolButtonStyle"], Content = new TextBlock { Text = $"{selected.StrokeWidth:0.#}", FontSize = 11, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold }, Width = 36, Height = 32, Padding = new Thickness(2) };
                    ToolTipService.SetToolTip(wBtn, T("線條粗細"));
                    wBtn.Click += (_, _) =>
                    {
                        var s = new Slider { Minimum = .5, Maximum = 128, Value = selected.StrokeWidth, StepFrequency = .5, Width = 180 };
                        s.ValueChanged += (_, e) => ChangeProperty(() => selected.StrokeWidth = e.NewValue);
                        ShowExclusiveFlyout(new Flyout { Content = new StackPanel { Spacing = 8, Children = { new TextBlock { Text = T("粗細（pt）"), FontSize = 12 }, s } } }, wBtn);
                    };
                    _selectionBarUpdates.Add(o=>((TextBlock)wBtn.Content).Text=$"{o.StrokeWidth:0.#}");
                    SelectionBarTools.Children.Add(wBtn);
                    break;

                case QuickActionItem.FillColor:
                    var fillDot = new Ellipse { Width = 16, Height = 16, Fill = Brush(selected.FillColor == "none" ? "#FCFCFA" : selected.FillColor), Stroke = Brush("#879487"), StrokeThickness = 1 };
                    var fillBtn = new Button { Style = (Style)Application.Current.Resources["ToolButtonStyle"], Content = fillDot, Width = 32, Height = 32, Padding = new Thickness(4) };
                    ToolTipService.SetToolTip(fillBtn, T("填色與透明度"));
                    fillBtn.Click += (_, _) =>
                    {
                        var p = new StackPanel { Width = 200, Spacing = 8 };
                        p.Children.Add(new TextBlock { Text = T("填色"), FontSize = 12, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
                        var noFill = new Button { Content = T("無填色"), HorizontalAlignment = HorizontalAlignment.Stretch };
                        noFill.Click += (_, _) => ChangeProperty(() => SetFilled(false));
                        p.Children.Add(noFill);
                        var pal = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
                        AddPalette(pal, c => ChangeProperty(() => SetFillColor(c)));
                        p.Children.Add(pal);
                        var alphaSlider = new Slider { Header = T("填色透明度"), Minimum = 0, Maximum = 1, StepFrequency = .01, Value = selected.FillOpacity ?? selected.Opacity };
                        alphaSlider.ValueChanged += (_, e) => ChangeProperty(() => selected.FillOpacity = e.NewValue);
                        p.Children.Add(alphaSlider);
                        ShowExclusiveFlyout(new Flyout { Content = p }, fillBtn);
                    };
                    var shownFill=selected.FillColor;_selectionBarUpdates.Add(o=>{if(o.FillColor!=shownFill){shownFill=o.FillColor;fillDot.Fill=Brush(shownFill=="none"?"#FCFCFA":shownFill);}});
                    SelectionBarTools.Children.Add(fillBtn);
                    break;

                case QuickActionItem.DashStyle:
                    var dashButton=QuickButton("dash", T("線條樣式"), b => ShowLineStyles(b));dashButton.Content=ToolIcons.CreateDash(selected.LineStyle);var shownDash=selected.LineStyle;_selectionBarUpdates.Add(o=>{if(o.LineStyle!=shownDash){shownDash=o.LineStyle;dashButton.Content=ToolIcons.CreateDash(shownDash);}});SelectionBarTools.Children.Add(dashButton);
                    break;

                case QuickActionItem.FontSize:
                    var fBtn = new Button { Style = (Style)Application.Current.Resources["ToolButtonStyle"], Content = new TextBlock { Text = $"{selected.FontSize ?? 18:0}pt", FontSize = 11 }, Width = 40, Height = 32, Padding = new Thickness(2) };
                    ToolTipService.SetToolTip(fBtn, T("字體大小"));
                    fBtn.Click += (_, _) =>
                    {
                        var nb = new NumberBox { Value = selected.FontSize ?? 18, Minimum = 8, Maximum = 200, Width = 120, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline };
                        nb.ValueChanged += (_, e) => { if (double.IsFinite(e.NewValue)) ChangeProperty(() => selected.FontSize = e.NewValue); };
                        ShowExclusiveFlyout(new Flyout { Content = nb }, fBtn);
                    };
                    _selectionBarUpdates.Add(o=>((TextBlock)fBtn.Content).Text=$"{o.FontSize??18:0}pt");
                    SelectionBarTools.Children.Add(fBtn);
                    break;

                case QuickActionItem.Opacity:
                    var oBtn = new Button { Style = (Style)Application.Current.Resources["ToolButtonStyle"], Content = new TextBlock { Text = $"{selected.Opacity * 100:0}%", FontSize = 11 }, Width = 40, Height = 32, Padding = new Thickness(2) };
                    ToolTipService.SetToolTip(oBtn, T("物件透明度"));
                    oBtn.Click += (_, _) =>
                    {
                        var s = new Slider { Minimum = 0, Maximum = 1, StepFrequency = .01, Value = selected.Opacity, Width = 180 };
                        s.ValueChanged += (_, e) => ChangeProperty(() => selected.Opacity = e.NewValue);
                        ShowExclusiveFlyout(new Flyout { Content = new StackPanel { Spacing = 8, Children = { new TextBlock { Text = T("透明度"), FontSize = 12 }, s } } }, oBtn);
                    };
                    _selectionBarUpdates.Add(o=>((TextBlock)oBtn.Content).Text=$"{o.Opacity*100:0}%");
                    SelectionBarTools.Children.Add(oBtn);
                    break;

                case QuickActionItem.EditText:
                    SelectionBarTools.Children.Add(QuickButton("text-edit", T("編輯文字"), _ => StartText(selected)));
                    break;

                case QuickActionItem.Copy:
                    SelectionBarTools.Children.Add(QuickButton("copy", T("複製（Ctrl+C）"), _ => CopySelected()));
                    break;

                case QuickActionItem.Duplicate:
                    SelectionBarTools.Children.Add(QuickButton("duplicate", T("製作副本"), _ => DuplicateSelected()));
                    break;

                case QuickActionItem.Delete:
                    SelectionBarTools.Children.Add(QuickButton("delete", T("刪除（Delete）"), _ => Delete_Click(this, new RoutedEventArgs())));
                    break;

                case QuickActionItem.Unlock:
                    SelectionBarTools.Children.Add(QuickButton("unlock", T("解除鎖定"), _ => Lock_Click(this, new RoutedEventArgs())));
                    break;

                case QuickActionItem.Lock:
                    SelectionBarTools.Children.Add(QuickButton("lock", T("鎖定物件"), _ => Lock_Click(this, new RoutedEventArgs())));
                    break;
            }
        }
    }

    private void UpdateSelectionBarPosition()
    {
        if (SelectionBar is null || SelectionBarTools is null) return;
        var selected = _session.Selected;
        if (selected is null || !_workspaceOpen || SelectionBar.Visibility != Visibility.Visible) return;

        var sPos = _viewport.WorldToScreen(selected.X, selected.Y);
        var sW = Math.Max(20, selected.Width * _viewport.Zoom);
        var sH = Math.Max(20, selected.Height * _viewport.Zoom);
        var handles = ObjectHandles.Get(selected, _viewport.Zoom)
            .Select(h => { var hp = _viewport.WorldToScreen(h.Point.X, h.Point.Y); return new InkPoint(hp.X, hp.Y); })
            .ToList();
        var barW = Math.Max(180, Math.Min(600, SelectionBarTools.Children.Count * 36 + 16));
        var barH = 40;
        (double X, double Y, double W, double H)? rulerBox = _rulerEnabled
            ? VectorMath.ComputeRotatedRulerBounds(new InkPoint(_rulerCenter.X, _rulerCenter.Y), _rulerAngle, RulerLength, RulerHeight)
            : null;
        (double X, double Y, double W, double H)? editorBox = _editor != null ? (Canvas.GetLeft(_editor), Canvas.GetTop(_editor), _editor.ActualWidth, _editor.ActualHeight) : null;

        var targetPos = SelectionQuickActionCoordinator.ComputeBarPosition(
            sPos.X, sPos.Y, sW, sH, handles,
            DrawingArea.ActualWidth, DrawingArea.ActualHeight,
            barW, barH, rulerBox, editorBox
        );

        SelectionBarTransform.X = targetPos.X;
        SelectionBarTransform.Y = targetPos.Y;
    }

    private void ShowCalculatorPanel(FrameworkElement anchor)
    {
        var panel = new StackPanel { Width = 310, Spacing = 8, Padding = new Thickness(4) };
        var titleRow = new Grid();
        titleRow.Children.Add(new TextBlock { Text = T("計算機"), FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        var modeBtn = new Button { Content = _calculator.IsDegreeMode ? "DEG" : "RAD", FontSize = 11, Padding = new Thickness(6, 2, 6, 2), HorizontalAlignment = HorizontalAlignment.Right };
        titleRow.Children.Add(modeBtn);
        panel.Children.Add(titleRow);

        var exprText = new TextBlock { Text = _calculator.Expression, FontSize = 12, Foreground = Brush("#68756C"), TextAlignment = TextAlignment.Right, Height = 18 };
        panel.Children.Add(exprText);

        var displayBox = new TextBox { Text = _calculator.Display, FontSize = 22, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextAlignment = TextAlignment.Right, Margin = new Thickness(0, 0, 0, 4) };
        displayBox.KeyDown += (_, e) =>
        {
            if (e.Key == VirtualKey.Enter)
            {
                _calculator.EvaluateCurrentExpression(displayBox.Text);
                RefreshCalcDisplay();
                e.Handled = true;
            }
            else if (e.Key == VirtualKey.Escape)
            {
                _calculator.Clear();
                RefreshCalcDisplay();
                e.Handled = true;
            }
        };
        panel.Children.Add(displayBox);

        void RefreshCalcDisplay()
        {
            exprText.Text = _calculator.Expression;
            displayBox.Text = _calculator.Display;
            modeBtn.Content = _calculator.IsDegreeMode ? "DEG" : "RAD";
        }

        modeBtn.Click += (_, _) => { _calculator.ToggleDegreeMode(); RefreshCalcDisplay(); };

        var grid = new Grid { ColumnSpacing = 4, RowSpacing = 4 };
        for (var c = 0; c < 5; c++) grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        for (var r = 0; r < 7; r++) grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var btnDefs = new (string text, int col, int row, Action action)[]
        {
            ("(", 0, 0, () => _calculator.InputParenthesis("(")),
            (")", 1, 0, () => _calculator.InputParenthesis(")")),
            ("CE", 2, 0, () => _calculator.ClearEntry()),
            ("C", 3, 0, () => _calculator.Clear()),
            ("⌫", 4, 0, () => _calculator.Backspace()),

            ("sin", 0, 1, () => _calculator.SinFunction()),
            ("cos", 1, 1, () => _calculator.CosFunction()),
            ("tan", 2, 1, () => _calculator.TanFunction()),
            ("^", 3, 1, () => _calculator.InputOperator("^")),
            ("÷", 4, 1, () => _calculator.InputOperator("/")),

            ("ln", 0, 2, () => _calculator.LnFunction()),
            ("7", 1, 2, () => _calculator.InputDigit("7")),
            ("8", 2, 2, () => _calculator.InputDigit("8")),
            ("9", 3, 2, () => _calculator.InputDigit("9")),
            ("×", 4, 2, () => _calculator.InputOperator("*")),

            ("log", 0, 3, () => _calculator.Log10Function()),
            ("4", 1, 3, () => _calculator.InputDigit("4")),
            ("5", 2, 3, () => _calculator.InputDigit("5")),
            ("6", 3, 3, () => _calculator.InputDigit("6")),
            ("−", 4, 3, () => _calculator.InputOperator("-")),

            ("√", 0, 4, () => _calculator.SquareRoot()),
            ("1", 1, 4, () => _calculator.InputDigit("1")),
            ("2", 2, 4, () => _calculator.InputDigit("2")),
            ("3", 3, 4, () => _calculator.InputDigit("3")),
            ("＋", 4, 4, () => _calculator.InputOperator("+")),

            ("1/x", 0, 5, () => _calculator.Reciprocal()),
            ("x²", 1, 5, () => _calculator.Square()),
            ("0", 2, 5, () => _calculator.InputDigit("0")),
            (".", 3, 5, () => _calculator.InputDecimal()),
            ("＝", 4, 5, () => _calculator.CalculateResult()),

            ("±", 0, 6, () => _calculator.ToggleSign()),
            ("%", 1, 6, () => _calculator.InputPercentage()),
            ("π", 2, 6, () => _calculator.InputDigit("3.14159265")),
            ("e", 3, 6, () => _calculator.InputDigit("2.71828183")),
            ("Ans", 4, 6, () => { if (_calculator.History.Count > 0) _calculator.SetResult(_calculator.History[0].Result); }),
        };

        foreach (var (txt, col, row, act) in btnDefs)
        {
            var b = new Button
            {
                Content = txt,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                VerticalAlignment = VerticalAlignment.Stretch,
                Padding = new Thickness(2, 6, 2, 6),
                FontSize = txt.Length > 2 ? 11 : 14,
                FontWeight = (txt is "=" or "＝") ? Microsoft.UI.Text.FontWeights.Bold : Microsoft.UI.Text.FontWeights.Normal,
                Background = (txt is "=" or "＝") ? Brush("#DCEBDD") : Brush("#FCFCFA")
            };
            b.Click += (_, _) => { act(); RefreshCalcDisplay(); };
            Grid.SetColumn(b, col);
            Grid.SetRow(b, row);
            grid.Children.Add(b);
        }
        panel.Children.Add(grid);

        var actionsRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, Margin = new Thickness(0, 6, 0, 0) };
        var insertBtn = new Button { Content = T("插入畫布"), Style = (Style)Application.Current.Resources["AccentButtonStyle"], FontSize = 12 };
        insertBtn.Click += (_, _) =>
        {
            var board = _session.Document.Board;
            var center = _viewport.ScreenToWorld(CanvasSurface.ActualWidth / 2, CanvasSurface.ActualHeight / 2);
            var textObj = _calculator.CreateBoardObject(center.X, center.Y, board.Id, board.ActivePageId, asExpression: true);
            _session.Begin();
            _session.Add(textObj);
            _session.SelectedId = textObj.Id;
            _session.Commit();
            RefreshEditor();
            StatusText.Text = T("計算結果已插入畫布");
        };
        actionsRow.Children.Add(insertBtn);

        var copyBtn = new Button { Content = T("複製結果"), FontSize = 12 };
        copyBtn.Click += (_, _) =>
        {
            var dp = new DataPackage();
            dp.SetText(_calculator.Display);
            Clipboard.SetContent(dp);
            StatusText.Text = T("已複製計算結果至剪貼簿");
        };
        actionsRow.Children.Add(copyBtn);

        var historyBtn = new Button { Content = T("歷史"), FontSize = 12 };
        historyBtn.Click += (_, _) =>
        {
            var histMenu = new MenuFlyout();
            if (_calculator.History.Count == 0)
            {
                histMenu.Items.Add(new MenuFlyoutItem { Text = T("尚無歷史紀錄"), IsEnabled = false });
            }
            else
            {
                foreach (var item in _calculator.History.Take(10))
                {
                    var mi = new MenuFlyoutItem { Text = $"{item.Expression} {item.Result}" };
                    mi.Click += (_, _) =>
                    {
                        _calculator.SetResult(item.Result);
                        RefreshCalcDisplay();
                    };
                    histMenu.Items.Add(mi);
                }
                histMenu.Items.Add(new MenuFlyoutSeparator());
                var clearHist = new MenuFlyoutItem { Text = T("清除歷史紀錄") };
                clearHist.Click += (_, _) => { _calculator.History.Clear(); };
                histMenu.Items.Add(clearHist);
            }
            histMenu.ShowAt(historyBtn);
        };
        actionsRow.Children.Add(historyBtn);
        panel.Children.Add(actionsRow);

        ShowFloatingTool("calculator",T("計算機"),panel);
    }

    private void ShowTimerPanel(FrameworkElement anchor)
    {
        var panel = new StackPanel { Width = 280, Spacing = 10, Padding = new Thickness(4) };
        panel.Children.Add(new TextBlock { Text = T("計時器與碼表"), FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });

        var modeStack = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var swBtn = new Button { Content = T("碼表正計時"), FontSize = 12, Background = _timerCoordinator.Mode == TimerMode.Stopwatch ? Brush("#DCEBDD") : Brush("#FCFCFA") };
        var cdBtn = new Button { Content = T("倒數計時"), FontSize = 12, Background = _timerCoordinator.Mode == TimerMode.Countdown ? Brush("#DCEBDD") : Brush("#FCFCFA") };
        modeStack.Children.Add(swBtn);
        modeStack.Children.Add(cdBtn);
        panel.Children.Add(modeStack);

        var timeDisplay = new TextBlock
        {
            Text = _timerCoordinator.FormattedTimeString(),
            FontSize = 32,
            FontWeight = Microsoft.UI.Text.FontWeights.Bold,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 4, 0, 4)
        };
        panel.Children.Add(timeDisplay);

        var countdownPresets = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, Visibility = _timerCoordinator.Mode == TimerMode.Countdown ? Visibility.Visible : Visibility.Collapsed };
        foreach (var m in new[] { 5, 15, 25 })
        {
            var pBtn = new Button { Content = F($"{m} 分鐘"), FontSize = 11, Padding = new Thickness(6, 4, 6, 4) };
            pBtn.Click += (_, _) =>
            {
                _timerCoordinator.SelectPresetMinutes(m);
                timeDisplay.Text = _timerCoordinator.FormattedTimeString();
            };
            countdownPresets.Children.Add(pBtn);
        }
        panel.Children.Add(countdownPresets);
        var customDuration=new NumberBox{Header=T("自訂倒數（秒）"),Minimum=1,Maximum=86400,Value=_timerCoordinator.CountdownDuration};
        var applyDuration=new Button{Content=T("套用自訂倒數")};applyDuration.Click+=(_,_)=>{if(!double.IsFinite(customDuration.Value))return;_timerCoordinator.Mode=TimerMode.Countdown;_timerCoordinator.Reset();_timerCoordinator.SetCountdownDuration(customDuration.Value);timeDisplay.Text=_timerCoordinator.FormattedTimeString();};
        panel.Children.Add(customDuration);panel.Children.Add(applyDuration);

        var controlsRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, HorizontalAlignment = HorizontalAlignment.Center };
        var playBtn = new Button
        {
            Content = _timerCoordinator.Status == TimerStatus.Running ? T("暫停") : T("開始"),
            Style = (Style)Application.Current.Resources["AccentButtonStyle"],
            Width = 80
        };
        var resetBtn = new Button { Content = T("重設"), Width = 80 };
        controlsRow.Children.Add(playBtn);
        controlsRow.Children.Add(resetBtn);
        panel.Children.Add(controlsRow);

        playBtn.Click += (_, _) =>
        {
            _timerCoordinator.TogglePlayPause();
            playBtn.Content = _timerCoordinator.Status == TimerStatus.Running ? T("暫停") : T("開始");
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
        };

        resetBtn.Click += (_, _) =>
        {
            _timerCoordinator.Reset();
            playBtn.Content = T("開始");
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
        };

        swBtn.Click += (_, _) =>
        {
            _timerCoordinator.Mode = TimerMode.Stopwatch;
            _timerCoordinator.Reset();
            swBtn.Background = Brush("#DCEBDD");
            cdBtn.Background = Brush("#FCFCFA");
            countdownPresets.Visibility = Visibility.Collapsed;
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
            playBtn.Content = T("開始");
        };

        cdBtn.Click += (_, _) =>
        {
            _timerCoordinator.Mode = TimerMode.Countdown;
            _timerCoordinator.Reset();
            swBtn.Background = Brush("#FCFCFA");
            cdBtn.Background = Brush("#DCEBDD");
            countdownPresets.Visibility = Visibility.Visible;
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
            playBtn.Content = T("開始");
        };

        EnsureTimerDaemon();
        _activeTimerDisplayUpdater = () =>
        {
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
            if (_timerCoordinator.DidAlertTimesUp)
            {
                playBtn.Content = T("開始");
            }
        };

        var insertRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Thickness(0, 4, 0, 0) };
        var insertBtn = new Button { Content = T("插入用時至畫布"), FontSize = 12 };
        insertBtn.Click += (_, _) =>
        {
            var board = _session.Document.Board;
            var center = _viewport.ScreenToWorld(CanvasSurface.ActualWidth / 2, CanvasSurface.ActualHeight / 2);
            var textObj = _timerCoordinator.CreateBoardObject(center.X, center.Y, board.Id, board.ActivePageId);
            _session.Begin();
            _session.Add(textObj);
            _session.SelectedId = textObj.Id;
            _session.Commit();
            RefreshEditor();
            StatusText.Text = T("用時已插入畫布");
        };
        insertRow.Children.Add(insertBtn);
        panel.Children.Add(insertRow);

        ShowFloatingTool("timer",T("計時器"),panel,()=>_activeTimerDisplayUpdater=null);
    }

    private void ShowCompassPanel(FrameworkElement anchor)
    {
        _compass.IsEnabled = true;
        RefreshChrome();
        InvalidateCanvas();

        var panel = new StackPanel { Width = 280, Spacing = 10, Padding = new Thickness(4) };
        panel.Children.Add(new TextBlock { Text = T("圓規與圓弧"), FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });

        var centerCoord = new TextBlock { Text = F($"圓心座標：({_compass.Center.X:0.#}, {_compass.Center.Y:0.#})"), FontSize = 12, Foreground = Brush("#68756C") };
        panel.Children.Add(centerCoord);

        var centerBtn = new Button { Content = T("將圓心設為目前視野中心"), FontSize = 12, HorizontalAlignment = HorizontalAlignment.Stretch };
        centerBtn.Click += (_, _) =>
        {
            var center = _viewport.ScreenToWorld(CanvasSurface.ActualWidth / 2, CanvasSurface.ActualHeight / 2);
            _compass.MoveCenter(center);
            centerCoord.Text = F($"圓心座標：({_compass.Center.X:0.#}, {_compass.Center.Y:0.#})");
            InvalidateCanvas();
        };
        panel.Children.Add(centerBtn);

        var rSlider = new Slider { Header = F($"半徑（pt）：{_compass.Radius:0.#}"), Minimum = 10, Maximum = 1000, Value = _compass.Radius, StepFrequency = 5 };
        rSlider.ValueChanged += (_, e) =>
        {
            _compass.AdjustRadius(e.NewValue);
            rSlider.Header = F($"半徑（pt）：{_compass.Radius:0.#}");
            InvalidateCanvas();
        };
        panel.Children.Add(rSlider);

        var startAngleBox = new NumberBox { Header = T("起點角度（0~360°）"), Value = _compass.StartAngle, SmallChange = 1, Minimum = 0, Maximum = 360, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline };
        startAngleBox.ValueChanged += (_, e) =>
        {
            if (double.IsFinite(e.NewValue)) _compass.SetStartAngle(e.NewValue);
        };
        panel.Children.Add(startAngleBox);

        var sweepAngleBox = new NumberBox { Header = T("掃動角度（-360~360°）"), Value = _compass.SweepAngle, SmallChange = 1, Minimum = -360, Maximum = 360, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline };
        sweepAngleBox.ValueChanged += (_, e) =>
        {
            if (double.IsFinite(e.NewValue)) _compass.SetSweepAngle(e.NewValue);
        };
        panel.Children.Add(sweepAngleBox);

        var lockToggle = new ToggleButton { Content = _compass.IsArmed ? T("已鎖定圓心作畫") : T("鎖定圓心（作畫階段）"), IsChecked = _compass.IsArmed, HorizontalAlignment = HorizontalAlignment.Stretch };
        lockToggle.Click += (_, _) =>
        {
            _compass.ToggleArmed();
            lockToggle.Content = _compass.IsArmed ? T("已鎖定圓心作畫") : T("鎖定圓心（作畫階段）");
            lockToggle.IsChecked = _compass.IsArmed;
        };
        panel.Children.Add(lockToggle);

        var circleBtn = new Button { Content = T("一鍵繪製整圓 (360°)"), Style = (Style)Application.Current.Resources["AccentButtonStyle"], HorizontalAlignment = HorizontalAlignment.Stretch };
        circleBtn.Click += (_, _) =>
        {
            var board = _session.Document.Board;
            _compass.StrokeColor = _strokeColor;
            _compass.StrokeWidth = EffectiveWidth;
            _compass.LineStyle = CurrentStyle.Dash;
            var obj = _compass.CreateArcObject(board.Id, board.ActivePageId, fullCircle: true);
            obj.FillColor = CurrentStyle.Filled ? _fillColor : "none";
            obj.FillOpacity = CurrentStyle.FillOpacity;
            obj.FillGradientStart = CurrentStyle.FillGradientStart;
            obj.FillGradientEnd = CurrentStyle.FillGradientEnd;
            _session.Begin();
            _session.Add(obj);
            _session.SelectedId = obj.Id;
            _session.Commit();
            RefreshEditor();
            StatusText.Text = T("已生成整圓物件");
        };
        panel.Children.Add(circleBtn);

        var arcBtn = new Button { Content = T("繪製設定圓弧"), HorizontalAlignment = HorizontalAlignment.Stretch };
        arcBtn.Click += (_, _) =>
        {
            var board = _session.Document.Board;
            _compass.StrokeColor = _strokeColor;
            _compass.StrokeWidth = EffectiveWidth;
            _compass.LineStyle = CurrentStyle.Dash;
            var obj = _compass.CreateArcObject(board.Id, board.ActivePageId, fullCircle: false);
            obj.FillColor = CurrentStyle.Filled ? _fillColor : "none";
            obj.FillOpacity = CurrentStyle.FillOpacity;
            obj.FillGradientStart = CurrentStyle.FillGradientStart;
            obj.FillGradientEnd = CurrentStyle.FillGradientEnd;
            _session.Begin();
            _session.Add(obj);
            _session.SelectedId = obj.Id;
            _session.Commit();
            RefreshEditor();
            StatusText.Text = F($"已生成圓弧（半徑 {_compass.Radius:0.#}pt，掃角 {_compass.SweepAngle:0.#}°）");
        };
        panel.Children.Add(arcBtn);

        ShowExclusiveFlyout(new Flyout { Content = panel }, anchor);
    }

    /// <summary>
    /// W-V04: 即時 HUD 標籤顯示尺寸與 0.1° 旋轉角度
    /// </summary>
    private void ShowHUD(string text, double screenX, double screenY)
    {
        if (HUDOverlay is null || HUDText is null) return;
        HUDText.Text = text;
        var badgePos = CanvasHUDFormatter.ComputeBadgePosition(
            screenX, screenY,
            Math.Max(80, HUDOverlay.ActualWidth), Math.Max(28, HUDOverlay.ActualHeight),
            DrawingArea.ActualWidth, DrawingArea.ActualHeight
        );
        HUDTransform.X = badgePos.X;
        HUDTransform.Y = badgePos.Y;
        HUDOverlay.Visibility = Visibility.Visible;
    }

    private void HideHUD()
    {
        if (HUDOverlay is not null) HUDOverlay.Visibility = Visibility.Collapsed;
    }

    private void ToolbarGrip_Pressed(object sender, PointerRoutedEventArgs e)
    {
        _toolbarDragging = true;
        _toolbarPointer = e.Pointer.PointerId;
        _toolbarDrop = null;
        _toolbarDragStart = e.GetCurrentPoint(DrawingArea).Position;
        _toolbarDragOffset = new(_toolbarTranslation.X, _toolbarTranslation.Y);
        ToolbarGrip.CapturePointer(e.Pointer);
        e.Handled = true;
    }

    private string? ToolbarTarget(Point p)
    {
        if (p.X < 96) return "左側";
        if (p.X > DrawingArea.ActualWidth - 96) return "右側";
        if (p.Y < 96) return "上方";
        if (p.Y > DrawingArea.ActualHeight - 96) return "下方";
        return null;
    }

    private void ToolbarGrip_Moved(object sender, PointerRoutedEventArgs e)
    {
        if (!_toolbarDragging || e.Pointer.PointerId != _toolbarPointer) return;
        var p = e.GetCurrentPoint(DrawingArea).Position;
        _toolbarTranslation.X = _toolbarDragOffset.X + p.X - _toolbarDragStart.X;
        _toolbarTranslation.Y = _toolbarDragOffset.Y + p.Y - _toolbarDragStart.Y;
        _toolbarDrop = ToolbarTarget(p);
        DockHint.Visibility = _toolbarDrop is null ? Visibility.Collapsed : Visibility.Visible;
        if (_toolbarDrop is not null)
        {
            var side = _toolbarDrop is "左側" or "右側";
            DockHint.Width = side ? 76 : Math.Min(480, DrawingArea.ActualWidth - 32);
            DockHint.Height = side ? Math.Min(360, DrawingArea.ActualHeight - 32) : 64;
            DockHint.HorizontalAlignment = _toolbarDrop == "左側" ? HorizontalAlignment.Left : _toolbarDrop == "右側" ? HorizontalAlignment.Right : HorizontalAlignment.Center;
            DockHint.VerticalAlignment = _toolbarDrop == "上方" ? VerticalAlignment.Top : _toolbarDrop == "下方" ? VerticalAlignment.Bottom : VerticalAlignment.Center;
            DockHintText.Text = side ? T("直排") : T("橫排");
        }
        e.Handled = true;
    }

    private void ToolbarGrip_Released(object sender, PointerRoutedEventArgs e)
    {
        if (!_toolbarDragging) return;
        _toolbarDragging = false;
        var drop = _toolbarDrop;
        DockHint.Visibility = Visibility.Collapsed;
        ToolbarGrip.ReleasePointerCaptures();
        if (drop is not null) SetDock(drop);
        else ClampToolbar();
        e.Handled = true;
    }

    private void ToolbarGrip_Canceled(object sender, PointerRoutedEventArgs e)
    {
        if (!_toolbarDragging) return;
        _toolbarDragging = false;
        DockHint.Visibility = Visibility.Collapsed;
        _toolbarTranslation.X = _toolbarDragOffset.X;
        _toolbarTranslation.Y = _toolbarDragOffset.Y;
    }

    private void ClampToolbar()
    {
        if (DrawingArea.ActualWidth <= 0 || ToolBorder.ActualWidth <= 0) return;
        var point = ToolBorder.TransformToVisual(DrawingArea).TransformPoint(new Point());
        _toolbarTranslation.X += Math.Clamp(point.X, 8, Math.Max(8, DrawingArea.ActualWidth - ToolBorder.ActualWidth - 8)) - point.X;
        _toolbarTranslation.Y += Math.Clamp(point.Y, 8, Math.Max(8, DrawingArea.ActualHeight - ToolBorder.ActualHeight - 8)) - point.Y;
    }
}
