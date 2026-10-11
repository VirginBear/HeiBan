using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using Ellipse=Microsoft.UI.Xaml.Shapes.Ellipse;
using global::Windows.UI;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private FlyoutBase? _chromeFlyout;
    public void RefreshLanguage()
    {
        _chromeFlyout?.Hide();
        Title=T("我的螢幕就是我的畫布");
        if(Content is FrameworkElement root)root.Language=Localization.Strings.Language;
        void Label(Button button,string source)
        {var value=T(source);ToolTipService.SetToolTip(button,value);AutomationProperties.SetName(button,value);}
        foreach(var pair in new[]{("select","選取"),("pen","畫筆"),("highlighter","螢光筆"),("curve","曲線"),("line","直線"),("arrow","箭頭"),("rect","矩形"),("circle","圓形"),("text","文字（T）"),("eraser","橡皮擦：再次點擊開啟設定"),("laser","雷射：再次點擊開啟設定")})
            if(_buttons.TryGetValue(pair.Item1,out var button))Label(button,pair.Item2);
        var actions=new[]{"復原這個螢幕的註記","重做","截圖加入螢幕畫布 · Ctrl+Alt+S","物件圖層：選取、排序與顯示","調色盤：色票與自訂色輪"};
        for(var index=0;index<Math.Min(actions.Length,_chromeActions.Count);index++)Label(_chromeActions[index],actions[index]);
        Label(_clearButton,"一鍵清空所有螢幕註記 · Ctrl+Alt+K · 可復原");
        Label(_closeButton,"結束螢幕畫布 · Ctrl+Alt+Q");
        Label(_brushButton,"顏色、粗細與透明度");Label(_fillButton,"填滿");
        Label(_moreButton,"螢幕畫布更多設定");Label(_dashButton,"線條樣式");
        ToolTipService.SetToolTip(_chromeGrip,T("拖曳到螢幕上下左右；放開後停靠"));
        if(!IsActive)_status.Text=T(_hotkeyRegistrationFailed?"部分快捷鍵被其他程式占用，請使用控制列按鈕。":"螢幕畫布");
        RefreshMode();RefreshButtons();ResizeChrome();PositionChrome();
    }
    private ToolbarFlowPanel _chromeTools=null!;
    private StackPanel _chromeStart=null!,_chromeEnd=null!;
    private Grid _chromeGrip=null!;
    private Border _chromeToolHost=null!;
    private Button _dashButton=null!,_brushButton=null!,_clearButton=null!,_closeButton=null!,_moreButton=null!,_fillButton=null!;
    private readonly List<Button> _chromeActions=[];
    private bool _collapsed;
    private static SolidColorBrush ChromeBrush(byte alpha,byte r,byte g,byte b)=>new(Color.FromArgb(alpha,r,g,b));
    private static Button ChromeButton(string icon,string label)
    {
        var button=new Button{Content=ToolIcons.Create(icon),Width=32,Height=32,MinWidth=0,MinHeight=0,Padding=new Thickness(4),BorderThickness=new Thickness(0),CornerRadius=new CornerRadius(6),Background=ChromeBrush(0,0,0,0)};
        ToolTipService.SetToolTip(button,label);AutomationProperties.SetName(button,label);return button;
    }
    private void InitializeChrome()
    {
        _chromeGrip=new Grid{Width=24,Height=30,Background=ChromeBrush(0,0,0,0)};
        _chromeGrip.Children.Add(new TextBlock{Text="☰",FontSize=18,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Foreground=ChromeBrush(255,62,81,69)});
        ToolTipService.SetToolTip(_chromeGrip,T("拖曳到螢幕上下左右；放開後停靠"));ExtendsContentIntoTitleBar=true;SetTitleBar(_chromeGrip);
        _mode.Height=32;_mode.MinWidth=_mode.MinHeight=0;_mode.Padding=new Thickness(3);_mode.BorderThickness=new Thickness(0);_mode.CornerRadius=new CornerRadius(6);_mode.Background=ChromeBrush(0,0,0,0);_mode.Click+=(_,_)=>SetDrawing(!_drawing);
        foreach(var pair in new[]{("select",T("選取")),("pen",T("畫筆")),("highlighter",T("螢光筆")),("curve",T("曲線")),("line",T("直線")),("arrow",T("箭頭")),("rect",T("矩形")),("circle",T("圓形")),("text",T("文字（T）")),("eraser",T("橡皮擦：再次點擊開啟設定")),("laser",T("雷射：再次點擊開啟設定"))})
        {var key=pair.Item1;var button=ChromeButton(key,pair.Item2);button.Click+=(_,_)=>ChooseScreenTool(key);_buttons[key]=button;}
        _chromeActions.Add(ActionButton("undo",T("復原這個螢幕的註記"),async()=>await UndoScreenAsync(false)));
        _chromeActions.Add(ActionButton("redo",T("重做"),async()=>await UndoScreenAsync(true)));
        _chromeActions.Add(ActionButton("screenshot",T("截圖加入螢幕畫布 · Ctrl+Alt+S"),async()=>await CaptureAsync()));
        _chromeActions.Add(ActionButton("layers",T("物件圖層：選取、排序與顯示"),ShowScreenLayers));
        _paletteButton=ActionButton("palette",T("調色盤：色票與自訂色輪"),ShowScreenPalette);_chromeActions.Add(_paletteButton);
        _dashButton=ChromeButton("dash-solid",T("線條樣式"));_dashButton.Click+=(_,_)=>ShowScreenLineStyles();
        _brushButton=ChromeButton("pen",T("顏色、粗細與透明度"));_brushButton.Click+=(_,_)=>ShowBrushSettings();
        _fillButton=ChromeButton("paint",T("填滿"));_fillButton.Click+=(_,_)=>ShowScreenFill();RefreshScreenStyleButtons();
        _styleCommitTimer.Tick+=(_,_)=>CommitScreenStyle();
        _clearButton=ActionButton("delete",T("一鍵清空所有螢幕註記 · Ctrl+Alt+K · 可復原"),ClearScreenObjects);
        _closeButton=ActionButton("close",T("結束螢幕畫布 · Ctrl+Alt+Q"),async()=>await StopAsync());
        _moreButton=ChromeButton("more",T("螢幕畫布更多設定"));_moreButton.Click+=(_,_)=>ShowScreenMenu(_moreButton);
        Content=new Border{Language=Localization.Strings.Language,RequestedTheme=ElementTheme.Light,CornerRadius=new CornerRadius(16),Background=ChromeBrush(150,247,250,246),BorderBrush=ChromeBrush(55,92,123,108),BorderThickness=new Thickness(1)};
        InitializeChromeDocking();SystemBackdrop=new DesktopAcrylicBackdrop();
    }
    private static Button ActionButton(string icon,string label,Action action){var button=ChromeButton(icon,label);button.Click+=(_,_)=>action();return button;}
    private void RefreshBrushButton()=>RefreshScreenStyleButtons();
    private void ShowScreenLineStyles()
    {
        var menu=new MenuFlyout();var styles=new[]{"solid","dashed","dotted","dashdot"};var names=new[]{T("實線"),T("虛線"),T("點線"),T("點劃線")};
        for(var i=0;i<styles.Length;i++){var value=styles[i];var row=new MenuFlyoutItem{Text=names[i],Icon=ToolIcons.CreateDashIcon(value)};row.Click+=(_,_)=>{SetScreenDash(value);CommitScreenStyle();};menu.Items.Add(row);}
        ShowChromeFlyout(menu,_dashButton);
    }
    private void ShowBrushSettings()
    {
        var selected=StyleSelection;var currentColor=selected?.StrokeColor??_color;var currentWidth=(selected?.StrokeWidth/_dpiScale)??_width;var currentAlpha=selected?.Opacity??_opacity;
        var panel=new StackPanel{Width=248,Spacing=14,RequestedTheme=ElementTheme.Light};panel.Children.Add(new TextBlock{Text=selected is null?T("顏色與筆刷"):T("選取物件樣式"),FontSize=16});
        var palette=new Grid{ColumnSpacing=8,RowSpacing=8};for(var i=0;i<3;i++)palette.ColumnDefinitions.Add(new());palette.RowDefinitions.Add(new());palette.RowDefinitions.Add(new());
        var colors=new[]{"#EF4444","#F59E0B","#22C55E","#3B82F6","#FFFFFF","#111827"};var swatches=new List<(Button Button,string Color)>();
        for(var i=0;i<colors.Length;i++)
        {
            var hex=colors[i];var button=new Button{Content=new Ellipse{Width=24,Height=24,Fill=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(hex)),Stroke=ChromeBrush(100,85,100,92),StrokeThickness=1},Width=36,Height=36,MinWidth=0,MinHeight=0,Padding=new Thickness(3),CornerRadius=new CornerRadius(18),Background=ChromeBrush(0,0,0,0),BorderBrush=ChromeBrush(255,66,117,93),BorderThickness=new Thickness(hex==currentColor?2:0),HorizontalAlignment=HorizontalAlignment.Center};
            AutomationProperties.SetName(button,T("註記顏色 ")+hex);button.Click+=(_,_)=>{SetScreenColor(hex);CommitScreenStyle();foreach(var swatch in swatches)swatch.Button.BorderThickness=new Thickness(swatch.Color==hex?2:0);};Grid.SetColumn(button,i%3);Grid.SetRow(button,i/3);palette.Children.Add(button);swatches.Add((button,hex));
        }
        panel.Children.Add(palette);
        var type=selected?.Type??_tool;
        if(type is not("text" or "sticky" or "image"))
        {
        var widthValue=new TextBlock{Text=$"{currentWidth:0.0} pt",FontSize=12};panel.Children.Add(BrushCaption(T("粗細"),widthValue));var width=ChromeSlider(1,32,currentWidth,"");width.ValueChanged+=(_,_)=>{if(StyleSelection is not null)EditScreenStyle(o=>o.StrokeWidth=width.Value*_dpiScale);else{_width=width.Value;_laser.Width=_width;}widthValue.Text=$"{width.Value:0.0} pt";};panel.Children.Add(width);
        }
        if(selected?.Type=="arrow")
        {
            var headLength=ChromeSlider(4,128,(selected.ArrowHeadLength??16)/_dpiScale,T("箭頭頭部長度（pt）"));headLength.ValueChanged+=(_,_)=>EditScreenStyle(o=>{if(o.Type=="arrow")o.ArrowHeadLength=headLength.Value*_dpiScale;});panel.Children.Add(headLength);
            var headWidth=ChromeSlider(4,96,(selected.ArrowHeadWidth??10)/_dpiScale,T("箭頭頭部寬度（pt）"));headWidth.ValueChanged+=(_,_)=>EditScreenStyle(o=>{if(o.Type=="arrow")o.ArrowHeadWidth=headWidth.Value*_dpiScale;});panel.Children.Add(headWidth);
        }
        if(type is "line" or "arrow")
        {
            var options=new[]{"none","start","end","both"};var extension=new ComboBox{Header=T("直線延伸"),ItemsSource=new[]{T("線段"),T("向 A 延伸"),T("向 B 延伸"),T("雙向延伸")},SelectedIndex=Math.Max(0,Array.IndexOf(options,selected?.Extension??_screenExtension))};
            extension.SelectionChanged+=(_,_)=>{var value=options[Math.Max(0,extension.SelectedIndex)];if(StyleSelection is not null)EditScreenStyle(o=>{if(o.Type is "line" or "arrow")o.Extension=value;});else _screenExtension=value;};panel.Children.Add(extension);
        }
        var alphaValue=new TextBlock{Text=$"{currentAlpha:P0}",FontSize=12};panel.Children.Add(BrushCaption(T("透明度"),alphaValue));var alpha=ChromeSlider(.1,1,currentAlpha,"");alpha.StepFrequency=.05;alpha.ValueChanged+=(_,_)=>{if(StyleSelection is not null)EditScreenStyle(o=>o.Opacity=alpha.Value);else _opacity=alpha.Value;alphaValue.Text=$"{alpha.Value:P0}";};panel.Children.Add(alpha);
        panel.Children.Add(new TextBlock{Text=_status.Text,FontSize=10,TextWrapping=TextWrapping.Wrap});ShowChromeFlyout(new Flyout{Content=panel},_brushButton);
    }
    private static Grid BrushCaption(string text,TextBlock value){var row=new Grid();row.ColumnDefinitions.Add(new(){Width=new GridLength(1,GridUnitType.Star)});row.ColumnDefinitions.Add(new(){Width=GridLength.Auto});row.Children.Add(new TextBlock{Text=text,FontSize=12});Grid.SetColumn(value,1);row.Children.Add(value);return row;}
    private static Slider ChromeSlider(double min,double max,double value,string label)
    {
        var slider=new Slider{Header=label,Minimum=min,Maximum=max,Value=value,StepFrequency=1,HorizontalAlignment=HorizontalAlignment.Stretch};
        foreach(var key in new[]{"SliderThumbBackground","SliderThumbBackgroundPointerOver","SliderThumbBackgroundPressed","SliderTrackValueFill","SliderTrackValueFillPointerOver","SliderTrackValueFillPressed","AccentFillColorDefaultBrush","SystemControlHighlightAccentBrush"})slider.Resources[key]=ChromeBrush(255,85,135,113);
        AutomationProperties.SetName(slider,label);return slider;
    }
    private void ChooseScreenTool(string key)
    {
        _chromeFlyout?.Hide();FinishScreenText();if(key==_tool&&key=="laser"){_ = LaserSettingsAsync();return;}if(key==_tool&&key=="eraser"){ShowEraserSettings();return;}
        var selectionVisuals=(_tool=="select"||key=="select")&&_session.SelectedIds.Count>0;
        if(selectionVisuals)DamageSelectedObjects();CancelGesture();_tool=key;if(!_drawing)SetDrawing(true);else if(selectionVisuals)_dirty=true;RefreshButtons();
    }
    private void RefreshMode()
    {
        _mode.Width=VerticalChrome?32:double.NaN;var color=_drawing?ChromeBrush(255,197,116,40):ChromeBrush(255,32,126,75);
        var icon=ToolIcons.CreateIcon(_drawing?"pen":"select");icon.Width=icon.Height=18;icon.Foreground=color;
        var content=new StackPanel{Orientation=Orientation.Horizontal,Spacing=4,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};content.Children.Add(icon);
        if(!VerticalChrome)content.Children.Add(new TextBlock{Text=_drawing?T("作畫"):T("操作"),FontSize=12,VerticalAlignment=VerticalAlignment.Center,Foreground=color});
        // Measure localized mode labels so the wrapping toolbar reserves their actual width.
        if(!VerticalChrome){content.Measure(new global::Windows.Foundation.Size(double.PositiveInfinity,double.PositiveInfinity));_mode.Width=Math.Max(62,content.DesiredSize.Width+10);}_mode.Content=content;_mode.HorizontalContentAlignment=HorizontalAlignment.Center;_mode.VerticalContentAlignment=VerticalAlignment.Center;
        var hint=(_drawing?T("作畫中；切換穿透操作"):T("操作中；回到作畫"))+" · Ctrl+Alt+D\n"+_status.Text;ToolTipService.SetToolTip(_mode,hint);AutomationProperties.SetName(_mode,hint);
    }
    private void SetChromeCollapsed(bool collapsed){_collapsed=collapsed;RebuildChromeLayout();ResizeChrome();PositionChrome();}
    private void ShowEraserSettings()
    {
        var panel=new StackPanel{Width=228,Spacing=12};panel.Children.Add(new TextBlock{Text=T("橡皮擦"),FontSize=16});
        var mode=new ComboBox{Header=T("模式"),ItemsSource=new[]{T("物件"),T("像素")},SelectedIndex=_eraserWhole?0:1,HorizontalAlignment=HorizontalAlignment.Stretch};mode.SelectionChanged+=(_,_)=>_eraserWhole=mode.SelectedIndex==0;panel.Children.Add(mode);
        var size=ChromeSlider(4,120,_eraserSize,T("範圍（pt）"));size.StepFrequency=2;size.ValueChanged+=(_,_)=>_eraserSize=size.Value;panel.Children.Add(size);ShowChromeFlyout(new Flyout{Content=panel},_buttons["eraser"]);
    }
    private void ShowScreenMenu(FrameworkElement anchor)
    {
        var menu=new MenuFlyout();
        void Item(string icon,string label,Action action){var item=new MenuFlyoutItem{Text=label,Icon=ToolIcons.CreateIcon(icon)};item.Click+=(_,_)=>action();menu.Items.Add(item);}
        if(StyleSelection is not null){Item("select",T("選取物件：樣式、複製、刪除…"),()=>ShowChromeFlyout(CreateObjectMenu(),_moreButton));menu.Items.Add(new MenuFlyoutSeparator());}
        var dockMenu=new MenuFlyoutSubItem{Text=T("工具列位置")};
        foreach(var pair in new[]{("top","上方"),("bottom","下方"),("left","左側"),("right","右側")}){var side=pair.Item1;var item=new MenuFlyoutItem{Text=T(pair.Item2)};item.Click+=(_,_)=>DockChrome(side);dockMenu.Items.Add(item);}menu.Items.Add(dockMenu);menu.Items.Add(new MenuFlyoutSeparator());
        Item("layers",T("物件圖層"),ShowScreenLayers);Item("palette",T("調色盤"),ShowScreenPalette);
        Item("screenshot",T("截圖加入螢幕畫布 · Ctrl+Alt+S"),async()=>await CaptureAsync());Item("export",T("儲存可編輯註記／透明 PNG…"),async()=>await ExportAnnotationsAsync());Item("delete",T("一鍵清空畫布（可復原）"),ClearScreenObjects);Item("reading",T("使用說明（正體中文）"),async()=>await global::Windows.System.Launcher.LaunchUriAsync(new Uri(Path.Combine(AppContext.BaseDirectory,"Assets","HeiBanUserGuide.html"))));
        Item("copy",T("貼上已複製物件"),async()=>await PasteScreenSelectionAsync());Item("paint",T("油漆筆"),()=>ChooseScreenTool("paint"));Item("select",_collapsed?T("展開工具區"):T("收合工具區"),()=>SetChromeCollapsed(!_collapsed));menu.Items.Add(new MenuFlyoutSeparator());menu.Items.Add(new MenuFlyoutItem{Text=_status.Text,IsEnabled=false});ShowChromeFlyout(menu,anchor);
    }
    private void ShowChromeFlyout(FlyoutBase flyout,FrameworkElement anchor,FlyoutShowOptions? options=null)
    {
        if(flyout is Flyout{Content:FrameworkElement body})body.FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight;
        if(flyout is MenuFlyout menu)menu.MenuFlyoutPresenterStyle=new Style{TargetType=typeof(MenuFlyoutPresenter),Setters={new Setter(FrameworkElement.FlowDirectionProperty,Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight)}};
        Activate();_chromeFlyout?.Hide();_chromeFlyout=flyout;flyout.ShouldConstrainToRootBounds=false;flyout.OverlayInputPassThroughElement=(FrameworkElement)Content;
        flyout.Closed+=(_,_)=>{CommitScreenStyle();if(ReferenceEquals(_chromeFlyout,flyout))_chromeFlyout=null;};if(options is null)flyout.ShowAt(anchor);else flyout.ShowAt(anchor,options);
    }
}
