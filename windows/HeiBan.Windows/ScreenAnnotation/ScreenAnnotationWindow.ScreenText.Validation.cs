#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Automation.Peers;
using Microsoft.UI.Xaml.Automation.Provider;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Shapes;
using global::Windows.ApplicationModel.DataTransfer;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    internal async Task<object> ValidateScreenTextControlsAsync(bool preview)
    {
        await StartAsync();
        _session.Open(new(){Objects=[new(){Id="delete-target",Type="rect",X=200,Y=200,Width=160,Height=100,FillColor="#FFF0AB"}]});
        DockChrome("right");
        var package=new DataPackage();
        package.SetText("螢幕文字\r\nPaste 中文 😀");
        await PasteScreenSelectionAsync(package.GetView());
        await Task.Delay(200);
        if(_textInput is null||_textDraft?.Text!="螢幕文字\nPaste 中文 😀")
            throw new InvalidOperationException("Screen paste did not create a text draft.");
        if(_chromeStart.Visibility!=Visibility.Visible||_chromeGrip.XamlRoot is null)
            throw new InvalidOperationException("Editing hid the screen toolbar grip.");
        var colorButton=MainWindow.FindEditingControl<Button>(_chromeToolHost,
            button=>AutomationProperties.GetAutomationId(button)=="text-color");
        if(colorButton?.Content is not Ellipse)throw new InvalidOperationException("Screen editor has no color circle.");
        var layoutButton=MainWindow.FindEditingControl<Button>(_chromeToolHost,
            button=>AutomationProperties.GetAutomationId(button)=="text-tab-layout")!;
        ((IInvokeProvider)new ButtonAutomationPeer(layoutButton).GetPattern(PatternInterface.Invoke)).Invoke();
        await Task.Delay(500);
        var previewCanvas=MainWindow.FindEditingControl<Microsoft.Graphics.Canvas.UI.Xaml.CanvasControl>(_chromeToolHost,_=>true);
        if(previewCanvas is null||previewCanvas.ActualWidth<200||previewCanvas.ActualHeight<100)
            throw new InvalidOperationException($"Layout preview must have a usable visible size. width={previewCanvas?.ActualWidth}, height={previewCanvas?.ActualHeight}, host={_chromeToolHost.ActualWidth}x{_chromeToolHost.ActualHeight}");
        var characterButton=MainWindow.FindEditingControl<Button>(_chromeToolHost,
            button=>AutomationProperties.GetAutomationId(button)=="text-tab-character")!;
        ((IInvokeProvider)new ButtonAutomationPeer(characterButton).GetPattern(PatternInterface.Invoke)).Invoke();
        await Task.Delay(100);
        FinishScreenText();
        if(_session.Document.Objects.Count!=2)throw new InvalidOperationException("Screen text paste did not commit.");
        _session.Undo();
        if(_session.Document.Objects.Count!=1)throw new InvalidOperationException("Screen paste undo changed other objects.");
        _session.Redo();
        foreach(var dock in new[]{"top","right","bottom","left","right"})
        {
            DockChrome(dock);
            if(_chromeGrip.XamlRoot is null)throw new InvalidOperationException("Reparented toolbar lost its drag grip.");
        }
        _tool="select";
        _session.SelectedId="delete-target";
        RefreshButtons();
        Changed();
        FocusScreenChrome();
        if(preview&&Environment.GetEnvironmentVariable("HEIBAN_QA_SCREEN_TEXT_EDIT")=="1")
        {
            var text=_session.Document.Objects.Single(item=>item.Type=="text");
            BeginScreenText(new(text.X,text.Y),text);
            // The diagnostic preview must not capture the user's work in other apps.
            _overlay.SetDrawing(false);
        }
        if(!preview)await StopAsync();
        return new{plainText=true,unicode=true,singleUndo=true,colorCircle=true,editingGripVisible=true,fourSideReparenting=true,layoutPreviewUsable=true,
            desktopWidth=_overlay.Width,desktopHeight=_overlay.Height,dpiScale=_dpiScale,
            keyboardAndPhysicalDrag="Require real input verification"};
    }
}
#endif
