using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;

namespace HeiBan.Windows.Views;

internal sealed partial class TextDraftEditor
{
    private sealed record CharacterStyle(string Family,double Size,bool Bold,bool Italic,bool Underline,bool Strike,
        global::Windows.UI.Color Foreground,global::Windows.UI.Color Background);
    private static CharacterStyle? _copiedCharacterStyle;
    private double _formatUiScale=1;
    private bool _wholeText,_formatting;
    private int _formatStart,_formatEnd;
    private event Action? FormatReady;
    private static SolidColorBrush Brush(string color)=>new(Direct2DCanvasRenderer.HexToColor(color));
    private static Ellipse Swatch(string color)=>new(){Width=22,Height=22,Fill=Brush(color),Stroke=Brush("#899A90"),StrokeThickness=1};
    private static FrameworkElement Labeled(string title,UIElement content)=>new StackPanel{Spacing=4,Children={new TextBlock{Text=T(title),FontSize=12,Foreground=Brush("#63746A")},content}};
    private static ToolbarFlowPanel Flow(double width=530)=>new(){Orientation=Orientation.Horizontal,RunLength=width,Spacing=6};

    private void RefreshAppearance()
    {
        if(_draft is not { } draft)return;
        var paper=Brush(draft.Type=="sticky"&&draft.FillColor is null or "none"?"#FFF0AB":draft.FillColor??"none");
        Background=paper;Resources["TextControlBackgroundFocused"]=paper;Resources["TextControlBackgroundPointerOver"]=paper;
        var border=Brush(draft.TextBorderColor??"#39735A");BorderBrush=border;
        Resources["TextControlBorderBrushFocused"]=border;Resources["TextControlBorderBrushPointerOver"]=border;
        BorderThickness=new Thickness(Math.Min(Math.Min(draft.Width,draft.Height),Math.Max(0,draft.TextBorderWidth??0))*_displayScale);
        Opacity=Math.Clamp(draft.Opacity,.05,1);QueueLayoutPreview();
    }
    // Preserve the user's character range when focus moves into a toolbar picker.
    private ITextRange FormatTarget()
    {
        var length=Text.Length;
        if(_wholeText&&length>0)return TextDocument.GetRange(0,length);
        var start=Math.Clamp(_formatStart,0,length);var end=Math.Clamp(_formatEnd,start,length);
        return start==end?TextDocument.Selection:TextDocument.GetRange(start,end);
    }
    internal void SetWholeTextScope(bool whole)=>_wholeText=whole;
    internal void ApplyCharacterFormat(Action<ITextCharacterFormat> apply)
    {
        _formatting=true;TextDocument.BatchDisplayUpdates();TextDocument.BeginUndoGroup();
        try{apply(FormatTarget().CharacterFormat);}
        finally{TextDocument.EndUndoGroup();TextDocument.ApplyDisplayUpdates();_formatting=false;}
        FormatReady?.Invoke();QueueLayoutPreview();
    }

    internal FrameworkElement CreateFormatPage(bool vertical,UIElement? clickThrough=null,Action? focusEditor=null,double? formatScale=null,Action? layoutChanged=null)
    {
        _formatUiScale=formatScale??_displayScale;
        var root=new StackPanel{Spacing=8};
        var toggles=new List<(Button Button,Func<ITextCharacterFormat,bool> Active)>();
        var textSwatch=Swatch("#24533D");var highlightSwatch=Swatch("#FDE68A");
        Button? paste=null;ScrollViewer? scroll=null;var status=Hint("套用至接下來輸入的文字");var queued=false;
        var previewHost=new ContentControl{HorizontalContentAlignment=HorizontalAlignment.Stretch};
        previewHost.SizeChanged+=(_,e)=>{if(_layoutPreview is not null&&e.NewSize.Width>2)_layoutPreview.Width=Math.Max(100,e.NewSize.Width-2);};
        var tabs=new StackPanel{Orientation=Orientation.Horizontal,Spacing=6};
        var scope=new ComboBox{ItemsSource=new[]{T("選取文字"),T("整個文字方塊")},SelectedIndex=_wholeText?1:0,MinWidth=150};
        AutomationProperties.SetName(scope,T("套用範圍"));AutomationProperties.SetAutomationId(scope,"text-scope");
        scope.SelectionChanged+=(_,_)=>{_wholeText=scope.SelectedIndex==1;FormatReady?.Invoke();};
        var header=Flow();header.Children.Add(tabs);header.Children.Add(scope);root.Children.Add(header);
        var pages=new Grid();root.Children.Add(pages);
        var character=new StackPanel{Spacing=8};var layout=new StackPanel{Spacing=8};var appearance=CreateAppearancePanel();
        var bodies=new FrameworkElement[]{character,layout,appearance};foreach(var body in bodies)pages.Children.Add(body);
        var nav=new List<Button>();
        for(var i=0;i<3;i++)
        {
            var index=i;var b=new Button{Content=T(new[]{"文字","排版","外觀"}[i]),Padding=new(10,5,10,5),AllowFocusOnInteraction=false};
            AutomationProperties.SetAutomationId(b,new[]{"text-tab-character","text-tab-layout","text-tab-appearance"}[i]);
            b.Click+=(_,_)=>ShowPage(index);nav.Add(b);tabs.Children.Add(b);
        }
        void ShowPage(int index)
        {
            for(var n=0;n<3;n++){bodies[n].Visibility=n==index?Visibility.Visible:Visibility.Collapsed;nav[n].Background=Brush(n==index?"#DCEBDD":"#F4F6F2");}
            if(scroll is not null){scroll.Height=index==1?430:index==2?300:250;scroll.InvalidateMeasure();}
            layoutChanged?.Invoke();
            _layoutPreviewVisible=index==1;QueueLayoutPreview();
            if(index==1&&previewHost.Content is null){previewHost.Content=CreateLayoutPreview();QueueLayoutPreview();}
        }
        var fontLabel=new TextBlock{MaxWidth=220,TextTrimming=TextTrimming.CharacterEllipsis};
        var size=new NumberBox{Minimum=8,Maximum=144,Value=18,Width=100,SpinButtonPlacementMode=NumberBoxSpinButtonPlacementMode.Compact};
        AutomationProperties.SetName(size,T("文字大小"));AutomationProperties.SetAutomationId(size,"text-size");
        var changingUi=false;
        size.ValueChanged+=(_,e)=>{if(!changingUi&&double.IsFinite(e.NewValue))ApplyCharacterFormat(f=>f.Size=(float)(e.NewValue*_formatUiScale*.75));};
        var fontRow=Flow();character.Children.Add(fontRow);
        var font=Picker("字型",fontLabel,()=>CreateFontPicker(name=>ApplyCharacterFormat(f=>f.Name=name)));font.Width=260;
        fontRow.Children.Add(font);fontRow.Children.Add(size);
        var tools=Flow();character.Children.Add(tools);
        void Toggle(string title,string glyph,Func<ITextCharacterFormat,bool> active,Action<ITextCharacterFormat> apply)
        {var b=ActionButton(title,glyph,()=>ApplyCharacterFormat(apply));tools.Children.Add(b);toggles.Add((b,active));}
        Toggle("粗體","B",f=>f.Bold==FormatEffect.On,f=>f.Bold=f.Bold==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        Toggle("斜體","I",f=>f.Italic==FormatEffect.On,f=>f.Italic=f.Italic==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        Toggle("底線","U",f=>f.Underline==UnderlineType.Single,f=>f.Underline=f.Underline==UnderlineType.Single?UnderlineType.None:UnderlineType.Single);
        Toggle("刪除線","S̶",f=>f.Strikethrough==FormatEffect.On,f=>f.Strikethrough=f.Strikethrough==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        tools.Children.Add(ActionButton("放大文字","A+",()=>ResizeSelectedText(2)));tools.Children.Add(ActionButton("縮小文字","A−",()=>ResizeSelectedText(-2)));
        var colors=Flow();character.Children.Add(colors);
        var textColor=Picker("文字顏色",textSwatch,()=>CreateColorPanel(Hex(FormatTarget().CharacterFormat.ForegroundColor),c=>ApplyCharacterFormat(f=>f.ForegroundColor=c)));
        AutomationProperties.SetAutomationId(textColor,"text-color");colors.Children.Add(Labeled("字體顏色",textColor));
        var highlight=Picker("螢光底色",highlightSwatch,()=>CreateColorPanel(Hex(FormatTarget().CharacterFormat.BackgroundColor),c=>ApplyCharacterFormat(f=>f.BackgroundColor=c),()=>ApplyCharacterFormat(f=>f.BackgroundColor=_plainBackground)));
        AutomationProperties.SetAutomationId(highlight,"text-highlight");colors.Children.Add(Labeled("螢光底色",highlight));
        colors.Children.Add(ActionButton("清除格式","Tx",()=>ApplyStyle(new(_draft?.FontFamily?.Split(',')[0]??"Microsoft JhengHei",(_draft?.FontSize??18)*_displayScale/_formatUiScale,false,false,false,false,Direct2DCanvasRenderer.HexToColor(_draft?.StrokeColor),_plainBackground))));
        colors.Children.Add(ActionButton("複製格式","▤",()=>{_copiedCharacterStyle=CaptureStyle();FormatReady?.Invoke();}));
        paste=ActionButton("套用格式","▥",()=>{if(_copiedCharacterStyle is {} s)ApplyStyle(s);});colors.Children.Add(paste);
        character.Children.Add(Hint("反白文字後調整；未反白時影響接下來輸入的文字。"));
        var aligns=Flow();layout.Children.Add(Labeled("水平對齊",aligns));
        foreach(var (title,value) in new[]{("靠左","left"),("置中","center"),("靠右","right"),("左右對齊","justify")})aligns.Children.Add(ActionButton(title,T(title),()=>SetAlignment(value)));
        var valign=Flow();layout.Children.Add(Labeled("垂直對齊",valign));
        foreach(var (title,value) in new[]{("靠上","top"),("垂直置中","center"),("靠下","bottom")})valign.Children.Add(ActionButton(title,T(title),()=>{if(_draft is not null)_draft.TextVerticalAlignment=value;QueueLayoutPreview();}));
        var direction=Flow();layout.Children.Add(Labeled("書寫方向",direction));
        foreach(var (title,value) in new[]{("橫排","horizontal-tb"),("直排","vertical-rl")})direction.Children.Add(ActionButton(title,T(title),()=>{if(_draft is not null)_draft.TextDirection=value;QueueLayoutPreview();}));
        layout.Children.Add(previewHost);layout.Children.Add(Hint("直排與垂直對齊顯示於預覽；輸入區保留橫排以支援輸入法與反白選字。"));
        root.Children.Add(status);
        scroll=new ScrollViewer{Content=root,HorizontalScrollMode=ScrollMode.Disabled,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled,
            VerticalScrollMode=ScrollMode.Auto,VerticalScrollBarVisibility=ScrollBarVisibility.Auto,Width=560,MaxWidth=560,MaxHeight=430};
        scroll.SizeChanged+=(_,e)=>{foreach(var body in new DependencyObject[]{root,appearance})ResizeFlows(body,Math.Max(220,e.NewSize.Width-12));};
        ShowPage(0);
        void UpdateSelection()
        {
            queued=false;if(!IsLoaded||_awaitingInitialFormat)return;changingUi=true;
            try
            {
                var f=FormatTarget().CharacterFormat;fontLabel.Text=string.IsNullOrWhiteSpace(f.Name)?T("混合格式"):f.Name;
                var point=f.Size/.75/_formatUiScale;size.Value=point>0&&double.IsFinite(point)?Math.Clamp(point,8,144):double.NaN;
                textSwatch.Fill=new SolidColorBrush(f.ForegroundColor);highlightSwatch.Fill=new SolidColorBrush(f.BackgroundColor);
                foreach(var (b,active) in toggles)b.Background=Brush(active(f)?"#DCEBDD":"#F4F6F2");if(paste is not null)paste.IsEnabled=_copiedCharacterStyle is not null;
                status.Text=_wholeText?T("套用至整個文字方塊"):_formatStart!=_formatEnd?T("套用至選取文字"):T("套用至接下來輸入的文字");
            }
            finally{changingUi=false;}
        }
        void QueueUpdate(){if(queued)return;queued=true;DispatcherQueue.TryEnqueue(UpdateSelection);}
        void SelectionUpdated(object sender,RoutedEventArgs args)
        {if(_formatting)return;_formatStart=TextDocument.Selection.StartPosition;_formatEnd=TextDocument.Selection.EndPosition;QueueUpdate();}
        scroll.Loaded+=(_,_)=>{SelectionChanged+=SelectionUpdated;FormatReady+=QueueUpdate;SelectionUpdated(this,new());};
        scroll.Unloaded+=(_,_)=>{SelectionChanged-=SelectionUpdated;FormatReady-=QueueUpdate;StopLayoutPreview();};return scroll;

        void Refocus(){focusEditor?.Invoke();Focus(FocusState.Programmatic);if(!_wholeText)TextDocument.Selection.SetRange(_formatStart,_formatEnd);QueueUpdate();}
        Button ActionButton(string title,object content,Action action)
        {
            var b=new Button{Content=content,Padding=new(10,6,10,6),MinWidth=36,MinHeight=34,AllowFocusOnInteraction=false};
            AutomationProperties.SetName(b,T(title));ToolTipService.SetToolTip(b,T(title));b.Click+=(_,_)=>{action();Refocus();};return b;
        }
        Button Picker(string title,object content,Func<FrameworkElement> build)
        {
            var b=new Button{Content=content,Padding=new(10,6,10,6),MinHeight=34,AllowFocusOnInteraction=false};
            AutomationProperties.SetName(b,T(title));ToolTipService.SetToolTip(b,T(title));
            b.Click+=(_,_)=>{var popup=new Flyout{Content=build(),OverlayInputPassThroughElement=clickThrough,ShouldConstrainToRootBounds=false};popup.Closed+=(_,_)=>{if(IsLoaded)Refocus();};popup.ShowAt(b);};return b;
        }
    }
    private static TextBlock Hint(string text)=>new(){Text=T(text),FontSize=12,Foreground=Brush("#63746A"),TextWrapping=TextWrapping.Wrap};
    private static void ResizeFlows(DependencyObject root,double width)
    {
        if(root is ToolbarFlowPanel flow){flow.RunLength=width;flow.InvalidateMeasure();}
        for(var i=0;i<VisualTreeHelper.GetChildrenCount(root);i++)ResizeFlows(VisualTreeHelper.GetChild(root,i),width);
    }
    private FrameworkElement CreateFontPicker(Action<string> choose)
    {
        var panel=new StackPanel{Width=280,Spacing=6};var search=new AutoSuggestBox{PlaceholderText=T("搜尋字型")};
        var list=new ListView{Height=200,SelectionMode=ListViewSelectionMode.None,IsItemClickEnabled=true,ItemsSource=InstalledFonts.Value};
        search.TextChanged+=(_,_)=>list.ItemsSource=InstalledFonts.Value.Where(n=>n.Contains(search.Text,StringComparison.CurrentCultureIgnoreCase)).Take(100).ToArray();
        list.ItemClick+=(_,e)=>choose((string)e.ClickedItem);panel.Children.Add(search);panel.Children.Add(list);return panel;
    }
    private FrameworkElement CreateColorPanel(string color,Action<global::Windows.UI.Color> apply,Action? clear=null)
    {
        var panel=new StackPanel{Width=280,Spacing=8};var quick=Flow(260);
        foreach(var c in new[]{"#24533D","#000000","#FFFFFF","#EF4444","#FDE68A","#60A5FA","#34D399","#F472B6"})
        {var b=new Button{Content=Swatch(c),Padding=new(4)};b.Click+=(_,_)=>apply(Direct2DCanvasRenderer.HexToColor(c));quick.Children.Add(b);}panel.Children.Add(quick);
        if(clear is not null){var b=new Button{Content=T("無色")};b.Click+=(_,_)=>clear();panel.Children.Add(b);}
        var picker=ToolbarUi.CreateColorWheel(color);panel.Children.Add(picker);var confirm=new Button{Content=T("套用")};confirm.Click+=(_,_)=>apply(picker.Color);panel.Children.Add(confirm);return panel;
    }
    private double PointSize(ITextCharacterFormat f)=>Math.Clamp(f.Size/.75/_formatUiScale,8,144);
    private void ResizeSelectedText(double amount)=>ApplyCharacterFormat(f=>f.Size=(float)(Math.Clamp(PointSize(f)+amount,8,144)*_formatUiScale*.75));
    private CharacterStyle CaptureStyle(){var f=FormatTarget().CharacterFormat;return new(f.Name,PointSize(f),f.Bold==FormatEffect.On,f.Italic==FormatEffect.On,f.Underline==UnderlineType.Single,f.Strikethrough==FormatEffect.On,f.ForegroundColor,f.BackgroundColor);}
    private void ApplyStyle(CharacterStyle s)=>ApplyCharacterFormat(f=>{f.Name=s.Family;f.Size=(float)(s.Size*_formatUiScale*.75);f.Bold=s.Bold?FormatEffect.On:FormatEffect.Off;f.Italic=s.Italic?FormatEffect.On:FormatEffect.Off;f.Underline=s.Underline?UnderlineType.Single:UnderlineType.None;f.Strikethrough=s.Strike?FormatEffect.On:FormatEffect.Off;f.ForegroundColor=s.Foreground;f.BackgroundColor=s.Background;});
    private void SetAlignment(string alignment)
    {if(_draft is null)return;_draft.Align=alignment;TextDocument.GetRange(0,Text.Length).ParagraphFormat.Alignment=alignment switch{"center"=>ParagraphAlignment.Center,"right"=>ParagraphAlignment.Right,"justify"=>ParagraphAlignment.Justify,_=>ParagraphAlignment.Left};QueueLayoutPreview();}
    private FrameworkElement CreateAppearancePanel()
    {
        if(_draft is not {} draft)return new StackPanel();var panel=new StackPanel{Spacing=8};var colors=Flow();panel.Children.Add(colors);
        void ColorControl(string title,string current,Action<string> set,bool clear=false)
        {
            var swatch=Swatch(current);var b=new Button{Content=swatch};AutomationProperties.SetName(b,T(title));
            b.Click+=(_,_)=>{var popup=new Flyout{ShouldConstrainToRootBounds=false};popup.Content=CreateColorPanel(current,c=>{set(Hex(c));swatch.Fill=new SolidColorBrush(c);RefreshAppearance();},clear?()=>{set("none");swatch.Fill=Brush("none");RefreshAppearance();}:null);popup.ShowAt(b);};colors.Children.Add(Labeled(title,b));
        }
        ColorControl("背景顏色",draft.FillColor??"none",c=>draft.FillColor=c,true);ColorControl("邊框顏色",draft.TextBorderColor??"#39735A",c=>draft.TextBorderColor=c);
        var width=new NumberBox{Header=T("邊框粗細"),Minimum=0,Maximum=12,Value=(draft.TextBorderWidth??0)*_displayScale/_formatUiScale,Width=140,SpinButtonPlacementMode=NumberBoxSpinButtonPlacementMode.Compact};
        width.ValueChanged+=(_,e)=>{if(double.IsFinite(e.NewValue)){draft.TextBorderWidth=e.NewValue*_formatUiScale/_displayScale;RefreshAppearance();}};
        var style=new ComboBox{Header=T("邊框樣式"),ItemsSource=new[]{T("實線"),T("虛線"),T("點線")},SelectedIndex=draft.TextBorderStyle=="dashed"?1:draft.TextBorderStyle=="dotted"?2:0,Width=140};
        style.SelectionChanged+=(_,_)=>{draft.TextBorderStyle=new[]{"solid","dashed","dotted"}[Math.Max(0,style.SelectedIndex)];QueueLayoutPreview();};
        var row=Flow();row.Children.Add(width);row.Children.Add(style);panel.Children.Add(row);var opacity=ToolbarUi.BrushSlider(T("透明度"),5,100,draft.Opacity*100,1);
        opacity.ValueChanged+=(_,e)=>{draft.Opacity=e.NewValue/100;RefreshAppearance();};panel.Children.Add(opacity);panel.Children.Add(Hint("背景與邊框套用至整個文字方塊。"));return panel;
    }
}
