using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace HeiBan.Windows.Views;

/// <summary>Native IME editor without a permanent format bar; whole-box styles use the shared context menu.</summary>
internal sealed class TextDraftEditor : RichEditBox
{
    public TextDraftEditor(){AcceptsReturn=true;}
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
        set=>TextDocument.SetText(TextSetOptions.None,value);
    }
    public void SyncStyle(BoardObject draft,double scale=1)
    {
        FontSize=Math.Max(8,(draft.FontSize??24)*scale);FontFamily=new FontFamily(draft.FontFamily??"Microsoft JhengHei");
        TextAlignment=draft.Align=="center"?TextAlignment.Center:draft.Align=="right"?TextAlignment.Right:TextAlignment.Left;
        var all=TextDocument.GetRange(0,Text.Length);var format=all.CharacterFormat;
        format.Size=(float)(FontSize*.75);format.Name=draft.FontFamily?.Split(',')[0]??"Microsoft JhengHei";
        format.Bold=draft.IsBold==true?FormatEffect.On:FormatEffect.Off;format.Italic=draft.IsItalic==true?FormatEffect.On:FormatEffect.Off;
        format.Underline=draft.IsUnderline==true?UnderlineType.Single:UnderlineType.None;format.Strikethrough=draft.IsStrikethrough==true?FormatEffect.On:FormatEffect.Off;
        format.ForegroundColor=Direct2DCanvasRenderer.HexToColor(draft.StrokeColor);
        var offset=0;
        foreach(var span in draft.RichTextSpans??[])
        {
            var length=Math.Min(span.Text.Length,Text.Length-offset);if(length<=0)break;var f=TextDocument.GetRange(offset,offset+length).CharacterFormat;
            f.Bold=span.IsBold==true?FormatEffect.On:FormatEffect.Off;f.Italic=span.IsItalic==true?FormatEffect.On:FormatEffect.Off;f.Underline=span.IsUnderline==true?UnderlineType.Single:UnderlineType.None;f.Strikethrough=span.IsStrikethrough==true?FormatEffect.On:FormatEffect.Off;
            if(span.Color is not null)f.ForegroundColor=Direct2DCanvasRenderer.HexToColor(span.Color);if(span.HighlightColor is not null)f.BackgroundColor=Direct2DCanvasRenderer.HexToColor(span.HighlightColor);offset+=length;
        }
    }
}
