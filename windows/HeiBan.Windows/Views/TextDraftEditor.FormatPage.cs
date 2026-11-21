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
    private event Action? FormatReady;

    private void RefreshAppearance()
    {
        if(_draft is not { } draft)return;
        var color=draft.FillColor;
        if(draft.Type=="sticky"&&color is null or "none")color="#FFF0AB";
        var paper=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(color));
        Background=paper;
        Resources["TextControlBackgroundFocused"]=paper;
        Resources["TextControlBackgroundPointerOver"]=paper;
        var border=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(draft.TextBorderColor??"#39735A"));
        BorderBrush=border;
        Resources["TextControlBorderBrushFocused"]=border;
        Resources["TextControlBorderBrushPointerOver"]=border;
        BorderThickness=new Thickness(Math.Min(Math.Min(draft.Width,draft.Height),Math.Max(0,draft.TextBorderWidth??0))*_displayScale);
        Opacity=Math.Clamp(draft.Opacity,.05,1);
    }

    internal FrameworkElement CreateFormatPage(bool vertical,UIElement? clickThrough=null,Action? focusEditor=null,double? formatScale=null)
    {
        _formatUiScale=formatScale??_displayScale;
        var bar=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=4};
        bar.Children.Add(new Border
        {
            Background=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#DCEBDD")),
            CornerRadius=new CornerRadius(8),Padding=new Thickness(8,4,8,4),VerticalAlignment=VerticalAlignment.Center,
            Child=new TextBlock{Text=T("編輯文字"),FontSize=12}
        });
        var colorCircle=new Ellipse{Width=22,Height=22,Fill=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(_draft?.StrokeColor)),
            Stroke=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#889990")),StrokeThickness=1};
        var sizeLabel=new TextBlock{Text="18 pt",VerticalAlignment=VerticalAlignment.Center};
        var fontLabel=new TextBlock{Text=T("字型"),MaxWidth=150,TextTrimming=TextTrimming.CharacterEllipsis,VerticalAlignment=VerticalAlignment.Center};
        var toggles=new List<(Button Button,Func<ITextCharacterFormat,bool> Active)>();
        Button? fontButton=null;
        Button? applyStyle=null;
        fontButton=AddPicker("字型",(flyout,format)=>
        {
            var fonts=InstalledFonts.Value;
            var search=new AutoSuggestBox{Width=260,Text=format.Name??"",PlaceholderText=T("字型")};
            search.TextChanged+=(_,args)=>
            {
                if(args.Reason==AutoSuggestionBoxTextChangeReason.UserInput)
                    search.ItemsSource=fonts.Where(name=>name.Contains(search.Text,StringComparison.OrdinalIgnoreCase)).Take(30).ToArray();
            };
            void Choose(string? name)
            {
                if(name is null)return;
                format.Name=name;
                flyout.Hide();
            }
            search.SuggestionChosen+=(_,args)=>Choose(args.SelectedItem as string);
            search.QuerySubmitted+=(_,args)=>Choose(fonts.FirstOrDefault(name=>name.Equals(args.QueryText.Trim(),StringComparison.OrdinalIgnoreCase)));
            var list=new ListView{ItemsSource=fonts,Height=180,Width=260,IsItemClickEnabled=true,SelectionMode=ListViewSelectionMode.None};
            list.ItemClick+=(_,args)=>Choose(args.ClickedItem as string);
            return new StackPanel{Spacing=4,Children={search,list}};
        },fontLabel);
        AddPicker("文字大小",(_,format)=>
        {
            var current=PointSize(format);
            var size=new NumberBox{Minimum=8,Maximum=144,Value=current,Width=140,
                SpinButtonPlacementMode=NumberBoxSpinButtonPlacementMode.Compact};
            size.ValueChanged+=(_,args)=>
            {
                if(double.IsFinite(args.NewValue))format.Size=(float)(Math.Clamp(args.NewValue,8,144)*_formatUiScale*.75);
            };
            return size;
        },sizeLabel);
        AddAction("放大文字","A+",()=>ResizeSelectedText(2));
        AddAction("縮小文字","A−",()=>ResizeSelectedText(-2));
        AddToggle("粗體","B",format=>format.Bold==FormatEffect.On,format=>format.Bold=format.Bold==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        AddToggle("斜體","I",format=>format.Italic==FormatEffect.On,format=>format.Italic=format.Italic==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        AddToggle("底線","U",format=>format.Underline==UnderlineType.Single,format=>format.Underline=format.Underline==UnderlineType.Single?UnderlineType.None:UnderlineType.Single);
        AddToggle("刪除線","S̶",format=>format.Strikethrough==FormatEffect.On,format=>format.Strikethrough=format.Strikethrough==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        AddToggle("標記","▧",format=>!format.BackgroundColor.Equals(_plainBackground),format=>
            format.BackgroundColor=format.BackgroundColor.Equals(_plainBackground)?Direct2DCanvasRenderer.HexToColor("#FDE68A"):_plainBackground);
        var colorButton=AddPicker("文字顏色",(flyout,format)=>ColorPicker(Hex(format.ForegroundColor),color=>
        {
            format.ForegroundColor=color;
            flyout.Hide();
            UpdateSelection();
        }),colorCircle);
        AutomationProperties.SetAutomationId(colorButton,"text-color");
        AddPicker("文字方塊對齊",(_,_) =>
        {
            var panel=new StackPanel{Spacing=4};
            foreach(var (label,alignment) in new[]{("靠左","left"),("置中","center"),("靠右","right"),("左右對齊","justify")})
            {
                var button=new Button{Content=T(label),HorizontalAlignment=HorizontalAlignment.Stretch,AllowFocusOnInteraction=false};
                button.Click+=(_,_)=>SetAlignment(alignment);
                panel.Children.Add(button);
            }
            return panel;
        },"≡");
        AddAction("清除格式","Tx",()=>
        {
            ApplyStyle(new(_draft?.FontFamily?.Split(',')[0]??"Microsoft JhengHei",(_draft?.FontSize??18)*_displayScale/_formatUiScale,
                false,false,false,false,Direct2DCanvasRenderer.HexToColor(_draft?.StrokeColor),_plainBackground));
        });
        AddAction("複製格式","▤",()=>_copiedCharacterStyle=CaptureStyle());
        applyStyle=AddAction("套用格式","▥",()=>{if(_copiedCharacterStyle is { } style)ApplyStyle(style);});
        AddPicker("文字方塊外觀",(_,_)=>CreateAppearancePanel(),T("外觀"));
        var page=new ScrollViewer
        {
            Content=bar,HorizontalScrollMode=vertical?ScrollMode.Disabled:ScrollMode.Enabled,HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,
            VerticalScrollMode=vertical?ScrollMode.Enabled:ScrollMode.Disabled,VerticalScrollBarVisibility=ScrollBarVisibility.Hidden
        };
        page.Loaded+=(_,_)=>{SelectionChanged+=SelectionUpdated;FormatReady+=UpdateSelection;UpdateSelection();};
        page.Unloaded+=(_,_)=>{SelectionChanged-=SelectionUpdated;FormatReady-=UpdateSelection;};
        return page;

        void SelectionUpdated(object sender,RoutedEventArgs args)=>UpdateSelection();
        void UpdateSelection()
        {
            if(!IsLoaded||_awaitingInitialFormat)return;
            var format=TextDocument.Selection.CharacterFormat;
            colorCircle.Fill=new SolidColorBrush(format.ForegroundColor);
            sizeLabel.Text=$"{PointSize(format):0.#} pt";
            fontLabel.Text=format.Name;
            if(fontButton is not null)ToolTipService.SetToolTip(fontButton,format.Name);
            foreach(var (button,active) in toggles)
                button.Background=active(format)?new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#DCEBDD")):new SolidColorBrush(Microsoft.UI.Colors.Transparent);
            if(applyStyle is not null)applyStyle.IsEnabled=_copiedCharacterStyle is not null;
        }
        void Refocus()
        {
            if(!IsLoaded)return;
            focusEditor?.Invoke();
            Focus(FocusState.Programmatic);
            UpdateSelection();
        }
        Button AddAction(string label,object content,Action action)
        {
            var button=new Button{Content=content,AllowFocusOnInteraction=false,Padding=new Thickness(6,3,6,3)};
            ToolTipService.SetToolTip(button,T(label));
            AutomationProperties.SetName(button,T(label));
            button.Click+=(_,_)=>{action();Refocus();};
            bar.Children.Add(button);
            return button;
        }
        void AddToggle(string label,string glyph,Func<ITextCharacterFormat,bool> active,Action<ITextCharacterFormat> change)
        {
            var button=AddAction(label,glyph,()=>change(TextDocument.Selection.CharacterFormat));
            toggles.Add((button,active));
        }
        Button AddPicker(string label,Func<Flyout,ITextCharacterFormat,FrameworkElement> content,object? display=null)
        {
            var button=new Button{Content=display??T(label),AllowFocusOnInteraction=false,Padding=new Thickness(6,3,6,3)};
            ToolTipService.SetToolTip(button,T(label));
            AutomationProperties.SetName(button,T(label));
            button.Click+=(_,_) =>
            {
                var selection=TextDocument.Selection;
                var start=selection.StartPosition;
                var end=selection.EndPosition;
                var flyout=new Flyout{OverlayInputPassThroughElement=clickThrough};
                flyout.Content=content(flyout,start==end?selection.CharacterFormat:TextDocument.GetRange(start,end).CharacterFormat);
                flyout.Closed+=(_,_) =>
                {
                    if(!IsLoaded)return;
                    TextDocument.Selection.SetRange(start,end);
                    Refocus();
                };
                flyout.ShowAt(button);
            };
            bar.Children.Add(button);
            return button;
        }
    }

    private double PointSize(ITextCharacterFormat format)
    {
        var size=format.Size/.75/_formatUiScale;
        return Math.Clamp(double.IsFinite(size)&&size>0?size:18,8,144);
    }

    private void ResizeSelectedText(double amount)
    {
        var format=TextDocument.Selection.CharacterFormat;
        format.Size=(float)(Math.Clamp(PointSize(format)+amount,8,144)*_formatUiScale*.75);
    }

    private CharacterStyle CaptureStyle()
    {
        var selection=TextDocument.Selection;
        var start=selection.StartPosition;
        var format=start<Text.Length?TextDocument.GetRange(start,start+1).CharacterFormat:selection.CharacterFormat;
        return new(format.Name,PointSize(format),format.Bold==FormatEffect.On,format.Italic==FormatEffect.On,
            format.Underline==UnderlineType.Single,format.Strikethrough==FormatEffect.On,format.ForegroundColor,format.BackgroundColor);
    }

    private void ApplyStyle(CharacterStyle style)
    {
        var format=TextDocument.Selection.CharacterFormat;
        format.Name=style.Family;
        format.Size=(float)(style.Size*_formatUiScale*.75);
        format.Bold=style.Bold?FormatEffect.On:FormatEffect.Off;
        format.Italic=style.Italic?FormatEffect.On:FormatEffect.Off;
        format.Underline=style.Underline?UnderlineType.Single:UnderlineType.None;
        format.Strikethrough=style.Strike?FormatEffect.On:FormatEffect.Off;
        format.ForegroundColor=style.Foreground;
        format.BackgroundColor=style.Background;
    }

    private void SetAlignment(string alignment)
    {
        if(_draft is null)return;
        _draft.Align=alignment;
        TextDocument.GetRange(0,Text.Length).ParagraphFormat.Alignment=alignment switch
        {
            "center"=>ParagraphAlignment.Center,"right"=>ParagraphAlignment.Right,"justify"=>ParagraphAlignment.Justify,_=>ParagraphAlignment.Left
        };
    }

    private FrameworkElement CreateAppearancePanel()
    {
        if(_draft is not { } draft)return new StackPanel();
        var panel=new StackPanel{Width=250,Spacing=8};
        var fillSwatch=new Ellipse{Width=14,Height=14,Stroke=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#889990")),StrokeThickness=1,
            Fill=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(draft.FillColor))};
        var fill=new Button{Content=new StackPanel{Orientation=Orientation.Horizontal,Spacing=6,Children={fillSwatch,new TextBlock{Text=T("填滿顏色"),VerticalAlignment=VerticalAlignment.Center}}},AllowFocusOnInteraction=false};
        fill.Click+=(_,_) =>
        {
            var flyout=new Flyout();
            flyout.Content=ColorPicker(draft.FillColor is null or "none"?"#FFFFFF":draft.FillColor,color=>{draft.FillColor=Hex(color);fillSwatch.Fill=new SolidColorBrush(color);RefreshAppearance();flyout.Hide();});
            flyout.ShowAt(fill);
        };
        var transparent=new Button{Content=T("無填滿"),AllowFocusOnInteraction=false};
        transparent.Click+=(_,_)=>{draft.FillColor="none";fillSwatch.Fill=new SolidColorBrush(Microsoft.UI.Colors.Transparent);RefreshAppearance();};
        panel.Children.Add(new StackPanel{Orientation=Orientation.Horizontal,Spacing=4,Children={fill,transparent}});
        var borderSwatch=new Ellipse{Width=14,Height=14,Stroke=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#889990")),StrokeThickness=1,
            Fill=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(draft.TextBorderColor??"#39735A"))};
        var border=new Button{Content=new StackPanel{Orientation=Orientation.Horizontal,Spacing=6,Children={borderSwatch,new TextBlock{Text=T("邊框顏色"),VerticalAlignment=VerticalAlignment.Center}}},AllowFocusOnInteraction=false};
        border.Click+=(_,_) =>
        {
            var flyout=new Flyout();
            flyout.Content=ColorPicker(draft.TextBorderColor??"#39735A",color=>{draft.TextBorderColor=Hex(color);borderSwatch.Fill=new SolidColorBrush(color);RefreshAppearance();flyout.Hide();});
            flyout.ShowAt(border);
        };
        panel.Children.Add(border);
        var scale=_formatUiScale/_displayScale;
        var thickness=ToolbarUi.BrushSlider(T("邊框粗細"),0,12,Math.Clamp((draft.TextBorderWidth??0)/scale,0,12),.5);
        thickness.ValueChanged+=(_,args)=>{draft.TextBorderWidth=args.NewValue*scale;RefreshAppearance();};
        panel.Children.Add(thickness);
        var style=new ComboBox{Header=T("邊框樣式"),ItemsSource=new[]{T("實線"),T("虛線"),T("點線")},
            SelectedIndex=draft.TextBorderStyle=="dashed"?1:draft.TextBorderStyle=="dotted"?2:0};
        style.SelectionChanged+=(_,_)=>draft.TextBorderStyle=new[]{"solid","dashed","dotted"}[Math.Max(0,style.SelectedIndex)];
        panel.Children.Add(style);
        var opacity=ToolbarUi.BrushSlider(T("透明度"),5,100,Math.Clamp(draft.Opacity*100,5,100),1);
        opacity.ValueChanged+=(_,args)=>{draft.Opacity=args.NewValue/100;RefreshAppearance();};
        panel.Children.Add(opacity);
        return panel;
    }

    private static FrameworkElement ColorPicker(string color,Action<global::Windows.UI.Color> apply)
    {
        var picker=ToolbarUi.CreateColorWheel(color);
        var confirm=new Button{Content=T("套用")};
        confirm.Click+=(_,_)=>apply(picker.Color);
        return new StackPanel{Spacing=4,Children={picker,confirm}};
    }
}
