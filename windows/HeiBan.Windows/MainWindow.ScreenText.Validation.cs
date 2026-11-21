#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using global::Windows.ApplicationModel.DataTransfer;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private async Task<object> ValidateExternalTextAsync()
    {
        await OpenAsync(new(){Board=new(){Title="Text editing QA",CanvasMode="fixed",CanvasWidth=640,CanvasHeight=480}});
        var package=new DataPackage();
        package.SetText("外部文字\r\nABC 😀");
        var count=_session.Document.Objects.Count;
        await PasteObjectContentAsync(package.GetView());
        await Task.Delay(200);
        if(_editor is null||_editingObject is null||_session.Document.Objects.Count!=count)
            throw new InvalidOperationException("External text must enter an isolated text draft.");
        if(_editor.Text!="外部文字\nABC 😀")throw new InvalidOperationException("Plain text paste lost Unicode or line breaks.");
        var colorButton=FindEditingControl<Button>(TextToolbarPage.Content as DependencyObject,
            button=>AutomationProperties.GetAutomationId(button)=="text-color");
        if(colorButton?.Content is not Ellipse)throw new InvalidOperationException("Text color must use a circle.");
        var format=_editor.TextDocument.GetRange(0,2).CharacterFormat;
        format.ForegroundColor=Microsoft.UI.Colors.Red;
        format.Size=30;
        _editingObject.FillColor="#FFF0AB";
        _editingObject.TextBorderColor="#FF0000";
        _editingObject.TextBorderWidth=3;
        _editingObject.TextBorderStyle="dashed";
        _editingObject.Align="justify";
        FinishText();
        var text=_session.Selected??throw new InvalidOperationException("Pasted text was not committed.");
        if(text.Type!="text"||text.Text!="外部文字\nABC 😀"||text.RichTextSpans?.First().Color!="#FF0000")
            throw new InvalidOperationException("Pasted text formatting did not commit.");
        _session.Undo();
        if(_session.Document.Objects.Count!=count)throw new InvalidOperationException("Paste must create one undo transaction.");
        _session.Redo();
        var reopened=DocumentCodec.Clone(_session.Document);
        await OpenAsync(reopened);
        text=_session.Document.Objects.Single();
        StartText(text);
        await Task.Delay(200);
        if(_editingObject?.TextBorderWidth!=3||_editor!.TextDocument.GetRange(0,2).CharacterFormat.Size!=30)
            throw new InvalidOperationException("Reopening lost text formatting or its border.");
        _editor.TextDocument.Selection.SetRange(0,0);
        _editor.SyncStyle(_editingObject!);
        if(!_editor.TextDocument.Selection.CharacterFormat.ForegroundColor.Equals(Microsoft.UI.Colors.Red))
            throw new InvalidOperationException("Reopened insertion color disagrees with restored text.");
        FinishText(false);
        return new{plainText=true,unicode=true,draftIsolated=true,colorCircle=true,partialFormatting=true,
            appearanceReopens=true,singleUndo=true};
    }

    internal static T? FindEditingControl<T>(DependencyObject? root,Func<T,bool> predicate) where T:DependencyObject
    {
        if(root is null)return null;
        if(root is T match&&predicate(match))return match;
        for(var i=0;i<VisualTreeHelper.GetChildrenCount(root);i++)
            if(FindEditingControl(VisualTreeHelper.GetChild(root,i),predicate) is { } found)return found;
        return null;
    }
}
#endif
