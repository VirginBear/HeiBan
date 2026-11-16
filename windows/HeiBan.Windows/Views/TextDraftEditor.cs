using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using System.Globalization;

namespace HeiBan.Windows.Views;

/// <summary>Native IME editor with a separate page hosted in the canvas toolbar.</summary>
internal sealed class TextDraftEditor : RichEditBox
{
    public TextDraftEditor(){AcceptsReturn=true;}
    internal void SetEditorPaper(string? color)
    {
        var paper=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(color is null or "none"?"#FFF0AB":color));
        Background=paper;
        Resources["TextControlBackgroundFocused"]=paper;
        Resources["TextControlBackgroundPointerOver"]=paper;
    }
    public MenuFlyout CreateTextMenu()
    {
        var menu=new MenuFlyout();
        void Add(string label,Action action){var item=new MenuFlyoutItem{Text=label};item.Click+=(_,_)=>action();menu.Items.Add(item);}
        Add(T("剪下"),()=>TextDocument.Selection.Cut());Add(T("複製"),()=>TextDocument.Selection.Copy());Add(T("貼上"),()=>TextDocument.Selection.Paste(0));Add(T("全選"),()=>TextDocument.Selection.SetRange(0,Text.Length));
        return menu;
    }
    public string Text
    {
        get {TextDocument.GetText(TextGetOptions.None,out var value);return (value.EndsWith('\r')?value[..^1]:value).Replace("\r\n","\n").Replace('\r','\n');}
        set=>TextDocument.SetText(TextSetOptions.None,value.Replace("\r\n","\r").Replace('\n','\r'));
    }
    public void SyncStyle(BoardObject draft,double scale=1)
    {
        FontSize=Math.Max(8,(draft.FontSize??24)*scale);FontFamily=new FontFamily(draft.FontFamily??"Microsoft JhengHei");
        TextAlignment=draft.Align=="center"?TextAlignment.Center:draft.Align=="right"?TextAlignment.Right:TextAlignment.Left;
        var lengthOfText=Text.Length;
        var format=lengthOfText==0?TextDocument.Selection.CharacterFormat:TextDocument.GetRange(0,lengthOfText).CharacterFormat;
        format.Size=(float)(FontSize*.75);format.Name=draft.FontFamily?.Split(',')[0]??"Microsoft JhengHei";
        format.Bold=draft.IsBold==true?FormatEffect.On:FormatEffect.Off;format.Italic=draft.IsItalic==true?FormatEffect.On:FormatEffect.Off;
        format.Underline=draft.IsUnderline==true?UnderlineType.Single:UnderlineType.None;format.Strikethrough=draft.IsStrikethrough==true?FormatEffect.On:FormatEffect.Off;
        format.ForegroundColor=Direct2DCanvasRenderer.HexToColor(draft.StrokeColor);
        format.BackgroundColor=Microsoft.UI.Colors.Transparent;
        _plainBackground=format.BackgroundColor;
        _displayScale=scale;
        var offset=0;
        foreach(var span in draft.RichTextSpans??[])
        {
            var length=Math.Min(span.Text.Length,lengthOfText-offset);if(length<=0)break;var f=TextDocument.GetRange(offset,offset+length).CharacterFormat;
            f.Bold=span.IsBold==true?FormatEffect.On:FormatEffect.Off;f.Italic=span.IsItalic==true?FormatEffect.On:FormatEffect.Off;f.Underline=span.IsUnderline==true?UnderlineType.Single:UnderlineType.None;f.Strikethrough=span.IsStrikethrough==true?FormatEffect.On:FormatEffect.Off;
            if(span.FontFamily is {Length:>0} family)f.Name=family;
            if(span.FontSize is >0 and var size && double.IsFinite(size))f.Size=(float)(size*scale*.75);
            if(span.Color is not null)f.ForegroundColor=Direct2DCanvasRenderer.HexToColor(span.Color);if(span.HighlightColor is not null)f.BackgroundColor=Direct2DCanvasRenderer.HexToColor(span.HighlightColor);offset+=length;
        }
    }

    private double _displayScale=1;
    private global::Windows.UI.Color _plainBackground;
    internal void ReadDraft(BoardObject draft)
    {
        var text=Text;
        var baseColor=Direct2DCanvasRenderer.HexToColor(draft.StrokeColor);
        var baseFamily=draft.FontFamily?.Split(',')[0]??"Microsoft JhengHei";
        var baseSize=Math.Max(8,(draft.FontSize??24)*_displayScale)/_displayScale;
        var oldSpans=draft.RichTextSpans;
        var original=draft.Text??"";
        var prefix=0;var suffix=0;
        if(oldSpans is not null)
        {
            var common=Math.Min(original.Length,text.Length);
            while(prefix<common&&original[prefix]==text[prefix])prefix++;
            while(prefix+suffix<common&&original[^(suffix+1)]==text[^(suffix+1)])suffix++;
        }
        var oldIndex=0;var oldEnd=0;
        var spans=new List<TextSpan>();
        var elements=StringInfo.GetTextElementEnumerator(text);
        System.Text.StringBuilder run=new();
        TextSpan? previous=null;
        while(elements.MoveNext())
        {
            var part=elements.GetTextElement();
            var start=elements.ElementIndex;
            var f=TextDocument.GetRange(start,start+part.Length).CharacterFormat;
            var fontSize=Math.Round(f.Size/.75/_displayScale,3);
            // Keep extension data with surviving text around a replacement.
            var oldStart=start<prefix?start:start>=text.Length-suffix?start+original.Length-text.Length:-1;
            while(oldSpans is not null&&oldIndex<oldSpans.Count&&oldStart>=oldEnd+oldSpans[oldIndex].Text.Length)
                oldEnd+=oldSpans[oldIndex++].Text.Length;
            var next=new TextSpan
            {
                FontFamily=string.IsNullOrWhiteSpace(f.Name)||string.Equals(f.Name,baseFamily,StringComparison.OrdinalIgnoreCase)?null:f.Name,
                FontSize=fontSize>0&&Math.Abs(fontSize-baseSize)>.01?fontSize:null,
                IsBold=f.Bold==FormatEffect.On,IsItalic=f.Italic==FormatEffect.On,
                IsUnderline=f.Underline==UnderlineType.Single,IsStrikethrough=f.Strikethrough==FormatEffect.On,
                Color=f.ForegroundColor.Equals(baseColor)?null:Hex(f.ForegroundColor),
                HighlightColor=f.BackgroundColor.Equals(_plainBackground)?null:Hex(f.BackgroundColor),
                ExtraFields=oldStart>=0&&oldSpans is not null&&oldIndex<oldSpans.Count?oldSpans[oldIndex].ExtraFields:null
            };
            if(previous is null||!SameFormat(previous,next))
            {
                if(previous is not null){previous.Text=run.ToString();spans.Add(previous);run.Clear();}
                previous=next;
            }
            run.Append(part);
        }
        if(previous is not null){previous.Text=run.ToString();spans.Add(previous);}
        draft.Text=text;
        draft.RichTextSpans=spans.Any(span=>span.FontSize is not null||span.FontFamily is not null||span.Color is not null||span.HighlightColor is not null||span.ExtraFields is not null
            ||span.IsBold!=(draft.IsBold==true)||span.IsItalic!=(draft.IsItalic==true)||span.IsUnderline!=(draft.IsUnderline==true)||span.IsStrikethrough!=(draft.IsStrikethrough==true))?spans:null;
    }

    private static string Hex(global::Windows.UI.Color color)=>color.A==255?$"#{color.R:X2}{color.G:X2}{color.B:X2}":$"#{color.R:X2}{color.G:X2}{color.B:X2}{color.A:X2}";
    private static bool SameFormat(TextSpan a,TextSpan b)=>a.IsBold==b.IsBold&&a.IsItalic==b.IsItalic&&a.IsUnderline==b.IsUnderline
        &&a.IsStrikethrough==b.IsStrikethrough&&a.Color==b.Color&&a.HighlightColor==b.HighlightColor
        &&a.FontFamily==b.FontFamily&&a.FontSize==b.FontSize&&ReferenceEquals(a.ExtraFields,b.ExtraFields);

    internal FrameworkElement CreateFormatPage(bool vertical, UIElement? clickThrough = null, Action? focusEditor = null)
    {
        var bar=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=3};
        var tab=new Border
        {
            Background=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#DCEBDD")),
            CornerRadius=new CornerRadius(8),Padding=new Thickness(8,4,8,4),
            VerticalAlignment=VerticalAlignment.Center,
            Child=new TextBlock{Text=T("編輯文字"),FontSize=12,TextWrapping=TextWrapping.Wrap}
        };
        bar.Children.Add(tab);
        void Add(string label,string glyph,Action<ITextCharacterFormat> change)
        {
            var button=new Button{Content=glyph,AllowFocusOnInteraction=false,Padding=new Thickness(6,3,6,3)};
            ToolTipService.SetToolTip(button,T(label));
            Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(button,T(label));
            button.Click+=(_,_)=>{change(TextDocument.Selection.CharacterFormat);Refocus();};
            bar.Children.Add(button);
        }
        Add("粗體","B",f=>f.Bold=f.Bold==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        Add("斜體","I",f=>f.Italic=f.Italic==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        Add("底線","U",f=>f.Underline=f.Underline==UnderlineType.Single?UnderlineType.None:UnderlineType.Single);
        Add("刪除線","S̶",f=>f.Strikethrough=f.Strikethrough==FormatEffect.On?FormatEffect.Off:FormatEffect.On);
        Add("標記","▧",f=>f.BackgroundColor=f.BackgroundColor.Equals(_plainBackground)?Direct2DCanvasRenderer.HexToColor("#FDE68A"):_plainBackground);

        AddPicker("文字大小", (flyout,format) =>
        {
            var current=format.Size/.75/_displayScale;
            var size=ToolbarUi.BrushSlider(T("文字大小"),8,144,Math.Clamp(current>0?current:24,8,144),1);
            size.Width=220;
            size.ValueChanged+=(_,e)=>format.Size=(float)(e.NewValue*_displayScale*.75);
            return size;
        });
        AddPicker("字型", (flyout,format) =>
        {
            var fonts=InstalledFonts.Value;
            var search=new AutoSuggestBox{Width=260,Text=format.Name??"",PlaceholderText=T("字型")};
            search.TextChanged+=(_,e)=>
            {
                if(e.Reason==AutoSuggestionBoxTextChangeReason.UserInput)
                    search.ItemsSource=fonts.Where(name=>name.Contains(search.Text,StringComparison.OrdinalIgnoreCase)).Take(30).ToArray();
            };
            search.SuggestionChosen+=(_,e)=>{if(e.SelectedItem is string name){format.Name=name;flyout.Hide();}};
            search.QuerySubmitted+=(_,e)=>
            {
                var name=fonts.FirstOrDefault(value=>value.Equals(e.QueryText.Trim(),StringComparison.OrdinalIgnoreCase));
                if(name is not null){format.Name=name;flyout.Hide();}
            };
            var list=new ListView{ItemsSource=fonts,Height=180,Width=260,IsItemClickEnabled=true,SelectionMode=ListViewSelectionMode.None};
            list.ItemClick+=(_,e)=>{if(e.ClickedItem is string name){format.Name=name;flyout.Hide();}};
            return new StackPanel{Spacing=4,Children={search,list}};
        });
        AddPicker("文字顏色", (flyout,format) =>
        {
            var picker=ToolbarUi.CreateColorWheel(Hex(format.ForegroundColor));
            var confirm=new Button{Content=T("套用")};
            confirm.Click+=(_,_)=>{format.ForegroundColor=picker.Color;flyout.Hide();};
            return new StackPanel{Spacing=4,Children={picker,confirm}};
        });
        return new ScrollViewer{Content=bar,
            HorizontalScrollMode=vertical?ScrollMode.Disabled:ScrollMode.Enabled,HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,
            VerticalScrollMode=vertical?ScrollMode.Enabled:ScrollMode.Disabled,VerticalScrollBarVisibility=ScrollBarVisibility.Hidden};

        void Refocus(){if(IsLoaded){focusEditor?.Invoke();Focus(FocusState.Programmatic);}}

        void AddPicker(string label,Func<Flyout,ITextCharacterFormat,FrameworkElement> content)
        {
            var button=new Button{Content=T(label),AllowFocusOnInteraction=false,Padding=new Thickness(6,3,6,3)};
            button.Click+=(_,_) =>
            {
                var selection=TextDocument.Selection;
                var start=selection.StartPosition;var end=selection.EndPosition;
                var flyout=new Flyout{OverlayInputPassThroughElement=clickThrough};
                var format=start==end?selection.CharacterFormat:TextDocument.GetRange(start,end).CharacterFormat;
                flyout.Content=content(flyout,format);
                flyout.Closed+=(_,_)=>{if(IsLoaded){Refocus();TextDocument.Selection.SetRange(start,end);}};
                flyout.ShowAt(button);
            };
            bar.Children.Add(button);
        }
    }

    private static readonly Lazy<string[]> InstalledFonts=new(()=>Microsoft.Graphics.Canvas.Text.CanvasTextFormat.GetSystemFontFamilies()
        .Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.CurrentCultureIgnoreCase).ToArray());
}
