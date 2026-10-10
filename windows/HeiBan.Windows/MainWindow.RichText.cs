using System.Globalization;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task EditRichTextAsync(BoardObject o)
    {
        CommitPropertyEdit();FinishText();o=_session.PageObjects.FirstOrDefault(item=>item.Id==o.Id)??o;var board=_session.Document.Board.Id;
        var editor=new RichEditBox{Width=480,Height=280,AcceptsReturn=true,TextWrapping=TextWrapping.Wrap,FontSize=o.FontSize??18};
        editor.TextDocument.SetText(TextSetOptions.None,o.Text??"");
        var all=editor.TextDocument.GetRange(0,(o.Text??"").Length);all.CharacterFormat.Bold=o.IsBold==true?FormatEffect.On:FormatEffect.Off;all.CharacterFormat.Italic=o.IsItalic==true?FormatEffect.On:FormatEffect.Off;all.CharacterFormat.Underline=o.IsUnderline==true?UnderlineType.Single:UnderlineType.None;all.CharacterFormat.Strikethrough=o.IsStrikethrough==true?FormatEffect.On:FormatEffect.Off;all.CharacterFormat.ForegroundColor=Direct2DCanvasRenderer.HexToColor(o.StrokeColor);
        all.CharacterFormat.BackgroundColor=Direct2DCanvasRenderer.HexToColor("transparent");
        var unhighlighted=all.CharacterFormat.BackgroundColor;
        var offset=0;
        foreach(var span in o.RichTextSpans??[])
        {
            var length=Math.Min(span.Text.Length,(o.Text??"").Length-offset);if(length<=0)break;var f=editor.TextDocument.GetRange(offset,offset+length).CharacterFormat;
            f.Bold=span.IsBold==true?FormatEffect.On:FormatEffect.Off;f.Italic=span.IsItalic==true?FormatEffect.On:FormatEffect.Off;f.Underline=span.IsUnderline==true?UnderlineType.Single:UnderlineType.None;f.Strikethrough=span.IsStrikethrough==true?FormatEffect.On:FormatEffect.Off;if(span.Color is not null)f.ForegroundColor=Direct2DCanvasRenderer.HexToColor(span.Color);f.BackgroundColor=span.HighlightColor is null?unhighlighted:Direct2DCanvasRenderer.HexToColor(span.HighlightColor);offset+=length;
        }
        var panel=new StackPanel{Spacing=8};var bar=new StackPanel{Orientation=Orientation.Horizontal,Spacing=4};
        void Button(string label,Action action){var b=new Button{Content=label};b.Click+=(_,_)=>{action();editor.Focus(FocusState.Programmatic);};bar.Children.Add(b);}
        Button("粗體",()=>editor.TextDocument.Selection.CharacterFormat.Bold=FormatEffect.Toggle);
        Button("斜體",()=>editor.TextDocument.Selection.CharacterFormat.Italic=FormatEffect.Toggle);
        Button("底線",()=>{var f=editor.TextDocument.Selection.CharacterFormat;f.Underline=f.Underline==UnderlineType.None?UnderlineType.Single:UnderlineType.None;});
        Button("刪除線",()=>editor.TextDocument.Selection.CharacterFormat.Strikethrough=FormatEffect.Toggle);
        Button("標記",()=>{var f=editor.TextDocument.Selection.CharacterFormat;f.BackgroundColor=f.BackgroundColor.Equals(unhighlighted)?Direct2DCanvasRenderer.HexToColor("#FDE68A"):unhighlighted;});
        var colors=new ComboBox{ItemsSource=new[]{"黑","紅","綠","藍"},Width=70};colors.SelectionChanged+=(_,_)=>{editor.TextDocument.Selection.CharacterFormat.ForegroundColor=Direct2DCanvasRenderer.HexToColor(new[]{"#111827","#EF4444","#16A34A","#2563EB"}[Math.Max(0,colors.SelectedIndex)]);editor.Focus(FocusState.Programmatic);};bar.Children.Add(colors);panel.Children.Add(new ScrollViewer{Content=bar,HorizontalScrollMode=ScrollMode.Enabled,HorizontalScrollBarVisibility=ScrollBarVisibility.Auto,VerticalScrollMode=ScrollMode.Disabled});panel.Children.Add(editor);
        var result=await new ContentDialog{Title="文字格式：選取文字後套用",Content=panel,PrimaryButtonText="儲存",CloseButtonText="取消",XamlRoot=Root.XamlRoot}.ShowAsync();
        if(result!=ContentDialogResult.Primary||board!=_session.Document.Board.Id||!_session.Document.Objects.Contains(o)||o.IsLocked==true)return;
        editor.TextDocument.GetText(TextGetOptions.None,out var raw);var text=raw.EndsWith("\r",StringComparison.Ordinal)?raw[..^1]:raw;
        var spans=new List<TextSpan>();var enumerator=StringInfo.GetTextElementEnumerator(text);
        while(enumerator.MoveNext())
        {
            var part=enumerator.GetTextElement();var i=enumerator.ElementIndex;var f=editor.TextDocument.GetRange(i,i+part.Length).CharacterFormat;
            var next=new TextSpan{Text=part,IsBold=f.Bold==FormatEffect.On,IsItalic=f.Italic==FormatEffect.On,IsUnderline=f.Underline!=UnderlineType.None,IsStrikethrough=f.Strikethrough==FormatEffect.On,Color=ColorHex(f.ForegroundColor),HighlightColor=f.BackgroundColor.Equals(unhighlighted)?null:ColorHex(f.BackgroundColor)};
            var last=spans.LastOrDefault();if(last is not null&&last.IsBold==next.IsBold&&last.IsItalic==next.IsItalic&&last.IsUnderline==next.IsUnderline&&last.IsStrikethrough==next.IsStrikethrough&&last.Color==next.Color&&last.HighlightColor==next.HighlightColor)last.Text+=part;else spans.Add(next);
        }
        _session.Begin();o.Text=text;o.RichTextSpans=spans;_session.Commit();RefreshEditor();
    }
}
