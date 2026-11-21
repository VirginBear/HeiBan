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
internal sealed partial class TextDraftEditor : RichEditBox
{
    private BoardObject? _draft;
    public TextDraftEditor(){AcceptsReturn=true;TextChanged+=(_,_)=>QueueLayoutPreview();}
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
    private bool _awaitingInitialFormat;
    internal bool ReadyForInput=>!_awaitingInitialFormat&&IsLoaded;
    internal void LoadDraft(BoardObject draft,double scale=1)
    {
        _draft=draft;
        _displayScale=scale;
        ApplyControlStyle(draft,scale);
        RefreshAppearance();
        Text=draft.Text??"";
        _awaitingInitialFormat=true;
        Loaded+=RestoreAfterTemplate;
        void RestoreAfterTemplate(object sender,RoutedEventArgs args)
        {
            Loaded-=RestoreAfterTemplate;
            // RichEditBox reapplies control font and theme defaults as its native template loads.
            // Restore persisted character runs after those defaults have settled.
            DispatcherQueue.TryEnqueue(()=>
            {
                if(IsLoaded)ApplyDocumentStyle(draft,scale);
                _awaitingInitialFormat=false;
                FormatReady?.Invoke();
            });
        }
    }
    public void SyncStyle(BoardObject draft,double scale=1)
    {
        _draft=draft;
        ApplyControlStyle(draft,scale);
        ApplyDocumentStyle(draft,scale);
        _awaitingInitialFormat=false;
        RefreshAppearance();
        FormatReady?.Invoke();
    }
    private void ApplyControlStyle(BoardObject draft,double scale)
    {
        FontSize=Math.Max(8,(draft.FontSize??24)*scale);FontFamily=new FontFamily(draft.FontFamily??"Microsoft JhengHei");
        TextAlignment=draft.Align switch{"center"=>TextAlignment.Center,"right"=>TextAlignment.Right,"justify"=>TextAlignment.Justify,_=>TextAlignment.Left};
    }
    private void ApplyDocumentStyle(BoardObject draft,double scale)
    {
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
        // Restoring runs does not update RichEdit's collapsed insertion format. Keep the
        // next typed character and the toolbar in agreement with the adjacent text.
        var selection=TextDocument.Selection;
        if(lengthOfText>0&&selection.StartPosition==selection.EndPosition)
        {
            var adjacent=Math.Clamp(selection.StartPosition-1,0,lengthOfText-1);
            selection.CharacterFormat.SetClone(TextDocument.GetRange(adjacent,adjacent+1).CharacterFormat.GetClone());
        }
    }

    private double _displayScale=1;
    private global::Windows.UI.Color _plainBackground;
    internal int LastFormatRunReads {get;private set;}
    internal void ReadDraft(BoardObject draft)
    {
        if(_awaitingInitialFormat)return; // An editor closed before loading has no changes to commit.
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
        if(prefix>0&&prefix<text.Length&&char.IsHighSurrogate(text[prefix-1])&&char.IsLowSurrogate(text[prefix]))prefix--;
        if(suffix>0&&suffix<text.Length&&char.IsLowSurrogate(text[text.Length-suffix])&&char.IsHighSurrogate(text[text.Length-suffix-1]))suffix--;
        var oldIndex=0;var oldEnd=0;
        var spans=new List<TextSpan>();
        LastFormatRunReads=0;
        for(var start=0;start<text.Length;)
        {
            // RichEdit already maintains runs. Read one format per run, not per grapheme.
            var range=TextDocument.GetRange(start,start+1);
            range.Expand(TextRangeUnit.CharacterFormat);
            LastFormatRunReads++;
            var end=Math.Clamp(range.EndPosition,start+1,text.Length);
            var oldStart=start<prefix?start:start>=text.Length-suffix?start+original.Length-text.Length:-1;
            if(start<prefix)end=Math.Min(end,prefix);
            else if(start<text.Length-suffix)end=Math.Min(end,text.Length-suffix);
            while(oldSpans is not null&&oldIndex<oldSpans.Count&&oldStart>=oldEnd+oldSpans[oldIndex].Text.Length)
                oldEnd+=oldSpans[oldIndex++].Text.Length;
            if(oldStart>=0&&oldSpans is not null&&oldIndex<oldSpans.Count)
                end=Math.Min(end,start+oldEnd+oldSpans[oldIndex].Text.Length-oldStart);
            end=Math.Max(start+1,end);
            var f=TextDocument.GetRange(start,end).CharacterFormat;
            var fontSize=Math.Round(f.Size/.75/_displayScale,3);
            var next=new TextSpan
            {
                Text=text[start..end],
                FontFamily=string.IsNullOrWhiteSpace(f.Name)||string.Equals(f.Name,baseFamily,StringComparison.OrdinalIgnoreCase)?null:f.Name,
                FontSize=fontSize>0&&Math.Abs(fontSize-baseSize)>.01?fontSize:null,
                IsBold=f.Bold==FormatEffect.On,IsItalic=f.Italic==FormatEffect.On,
                IsUnderline=f.Underline==UnderlineType.Single,IsStrikethrough=f.Strikethrough==FormatEffect.On,
                Color=f.ForegroundColor.Equals(baseColor)?null:Hex(f.ForegroundColor),
                HighlightColor=f.BackgroundColor.Equals(_plainBackground)?null:Hex(f.BackgroundColor),
                ExtraFields=oldStart>=0&&oldSpans is not null&&oldIndex<oldSpans.Count?oldSpans[oldIndex].ExtraFields:null
            };
            if(spans.Count>0&&SameFormat(spans[^1],next))spans[^1].Text+=next.Text;
            else spans.Add(next);
            start=end;
        }
        draft.Text=text;
        draft.RichTextSpans=spans.Any(span=>span.FontSize is not null||span.FontFamily is not null||span.Color is not null||span.HighlightColor is not null||span.ExtraFields is not null
            ||span.IsBold!=(draft.IsBold==true)||span.IsItalic!=(draft.IsItalic==true)||span.IsUnderline!=(draft.IsUnderline==true)||span.IsStrikethrough!=(draft.IsStrikethrough==true))?spans:null;
    }

    private static string Hex(global::Windows.UI.Color color)=>color.A==255?$"#{color.R:X2}{color.G:X2}{color.B:X2}":$"#{color.R:X2}{color.G:X2}{color.B:X2}{color.A:X2}";
    private static bool SameFormat(TextSpan a,TextSpan b)=>a.IsBold==b.IsBold&&a.IsItalic==b.IsItalic&&a.IsUnderline==b.IsUnderline
        &&a.IsStrikethrough==b.IsStrikethrough&&a.Color==b.Color&&a.HighlightColor==b.HighlightColor
        &&a.FontFamily==b.FontFamily&&a.FontSize==b.FontSize&&ReferenceEquals(a.ExtraFields,b.ExtraFields);

    private static readonly Lazy<string[]> InstalledFonts=new(()=>Microsoft.Graphics.Canvas.Text.CanvasTextFormat.GetSystemFontFamilies()
        .Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.CurrentCultureIgnoreCase).ToArray());
}
