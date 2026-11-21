using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using global::Windows.Graphics;
using global::Windows.System;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private Window? _textWindow;
    private TextDraftEditor? _textInput;
    private BoardObject? _textDraft;
    private string? _textOriginalId;
    private BoardObject[] ScreenTexts=>_session.SelectedObjects.Where(o=>o.Type is "text" or "sticky"&&o.IsLocked!=true).ToArray();
    private void BeginScreenText(InkPoint point,BoardObject? existing=null,string type="text",bool isNew=false)
    {
        FinishScreenText();CancelGesture();if(existing?.IsLocked==true)return;
        _textOriginalId=isNew?null:existing?.Id;_textDraft=existing is null?new BoardObject{Type=type,X=point.X,Y=point.Y,Width=280*_dpiScale,Height=100*_dpiScale,FontSize=24*_dpiScale,StrokeColor=_color,Opacity=_opacity,FillColor=type=="sticky"?"#FFF0AB":"none",Text=""}:DocumentCodec.Clone(existing);
        var window=new Window{Title=T("文字")};_textWindow=window;
        if(window.AppWindow.Presenter is OverlappedPresenter presenter){presenter.PreferredMinimumWidth=1;presenter.PreferredMinimumHeight=1;presenter.IsAlwaysOnTop=true;presenter.IsResizable=false;presenter.SetBorderAndTitleBar(false,false);}
        var x=(int)Math.Round(_overlay.Left+_textDraft.X);var y=(int)Math.Round(_overlay.Top+_textDraft.Y);
        var width=(int)Math.Max(32,Math.Min(_textDraft.Width,_overlay.Left+_overlay.Width-x));
        var height=(int)Math.Max(32,Math.Min(_textDraft.Height,_overlay.Top+_overlay.Height-y));
        window.AppWindow.Move(new PointInt32(x,y));
        window.AppWindow.Resize(new SizeInt32(width,height));
        var dpi=NativeOverlayWindow.DpiScale(WinRT.Interop.WindowNative.GetWindowHandle(window));
        var input=new TextDraftEditor{TextWrapping=TextWrapping.Wrap,RequestedTheme=ElementTheme.Light,
            Padding=new Thickness(_textDraft.Type=="sticky"?12/dpi:0)};
        if(_textDraft.Type=="sticky")input.SetEditorPaper(_textDraft.FillColor);
        _textInput=input;_textInput.LoadDraft(_textDraft,1/dpi);
        // The GPU overlay cannot host XAML or IME controls. This HWND sits exactly over the canvas object and contains only its editor.
        window.Content=input;
        UpdateScreenTextToolbar();
        InvalidateScreenTextScene();
        input.KeyDown+=(_,args)=>{if(args.Key==VirtualKey.Escape){FinishScreenText(false);args.Handled=true;}else if(args.Key==VirtualKey.Enter&&Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control).HasFlag(global::Windows.UI.Core.CoreVirtualKeyStates.Down)){FinishScreenText();args.Handled=true;}};
        input.ContextFlyout=null;input.RightTapped+=(_,args)=>{
            var menu=input.CreateTextMenu();
            menu.ShouldConstrainToRootBounds=false;menu.ShowAt(input,new FlyoutShowOptions{Position=args.GetPosition(input)});args.Handled=true;
        };
        window.AppWindow.Closing+=(_,args)=>{if(!ReferenceEquals(_textWindow,window))return;args.Cancel=true;FinishScreenText();};
        window.Activate();input.Focus(FocusState.Programmatic);
    }
    private void RefreshScreenTextDraft()
    {
        if(_textInput is null||_textDraft is null)return;
        _textInput.SyncStyle(_textDraft,1/NativeOverlayWindow.DpiScale(WinRT.Interop.WindowNative.GetWindowHandle(_textWindow!)));
    }
    private void FinishScreenText(bool commit=true)
    {
        if(_textWindow is null||_textDraft is null||_textInput is null)return;
        var window=_textWindow;var draft=_textDraft;var original=_textOriginalId;
        if(commit)_textInput.ReadDraft(draft);
        _textWindow=null;_textDraft=null;_textInput=null;_textOriginalId=null;window.Close();
        UpdateScreenTextToolbar();
        InvalidateScreenTextScene();
        if(!commit){FocusScreenChrome();return;}
        if(original is null&&string.IsNullOrWhiteSpace(draft.Text))return;
        var existing=original is null?null:_session.PageObjects.FirstOrDefault(o=>o.Id==original&&o.IsLocked!=true);
        if(original is not null&&existing is null)return;
        TextStyles.GrowHeight(draft);
        _session.Begin();if(existing is null)_session.Add(draft);else{var index=_session.Document.Objects.IndexOf(existing);_session.Document.Objects[index]=draft;_session.SelectedId=draft.Id;}_session.Commit();_tool="select";RefreshButtons();Changed();FocusScreenChrome();
    }
    private void UpdateScreenTextToolbar()
    {
        AttachScreenTextToolbar();
        ResizeChrome();PositionChrome();
    }
    private void AttachScreenTextToolbar()
    {
        _chromeStart.Visibility=_chromeEnd.Visibility=Visibility.Visible;
        _mode.Visibility=_textInput is null?Visibility.Visible:Visibility.Collapsed;
        _chromeToolHost.Visibility=_textInput is null&&_collapsed?Visibility.Collapsed:Visibility.Visible;
        _chromeToolHost.Child=_textInput is { } input
            ?input.CreateFormatPage(VerticalChrome,focusEditor:()=>_textWindow?.Activate(),formatScale:1,
                layoutChanged:()=>DispatcherQueue.TryEnqueue(()=>{if(IsActive&&_textInput is not null){ResizeChrome();PositionChrome();}}))
            :_chromeTools;
        if(_textInput is not null&&_chromeToolHost.Child is FrameworkElement page)
            page.SizeChanged+=(_,_)=>DispatcherQueue.TryEnqueue(()=>{if(IsActive&&ReferenceEquals(_chromeToolHost.Child,page)){ResizeChrome();PositionChrome();}});
    }
    private void InvalidateScreenTextScene()
    {
        _dirty=_fullDamage=_committedDirty=true;
        _committedDamage=null;
    }
    private void AppendScreenTextMenu(MenuFlyout menu)
    {
        var selected=_session.SelectedIds.ToHashSet();var board=_session.Document.Board.Id;
        bool Current()=>board==_session.Document.Board.Id&&_session.SelectedIds.SetEquals(selected);
        TextStyleMenu.Append(menu,ScreenTexts,change=>{FinishScreenText();if(Current()){TextStyles.ApplySelection(_session,change,_dpiScale);Changed();}},flyout=>ShowChromeFlyout(flyout,(FrameworkElement)Content),Current,()=>{if(ScreenTexts.FirstOrDefault() is { } text)BeginScreenText(new(text.X,text.Y),text);},_dpiScale);
    }
    internal async Task ShowValidationPreviewAsync(string preview)
    {
        if(string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")))return;
        await StartAsync();DockChrome(preview=="horizontal"?"top":"left");
        if(preview=="brush")ShowBrushSettings();
        if(preview=="text"){BeginScreenText(new(600,440));await Task.Delay(150);_textInput!.Text="我的螢幕就是我的畫布\n中文文字與右鍵設定";TextStyles.Apply(_textDraft!,new(Size:24,Color:"#39735a",Bold:true,Underline:true),_dpiScale);RefreshScreenTextDraft();}
    }
    private async Task<object> ValidateScreenTextAsync()
    {
        var before=DocumentCodec.Clone(_session.Document);var count=before.Objects.Count;
        try
        {
            ChooseScreenTool("text");OnPointer(new("down",420,480));
            if(_textWindow is null||!_overlay.IsBelow(WinRT.Interop.WindowNative.GetWindowHandle(_textWindow)))throw new InvalidOperationException("文字輸入視窗被螢幕層遮住。");if(_textInput is null||_session.Document.Objects.Count!=count)throw new InvalidOperationException("文字草稿提前寫入文件。");
            if(!ReferenceEquals(_textWindow.Content,_textInput)||ReferenceEquals(_chromeToolHost.Child,_chromeTools))throw new InvalidOperationException("螢幕文字沒有借用工具列。");
            for(var wait=0;wait<40&&!_textInput.ReadyForInput;wait++)await Task.Delay(50);
            if(!_textInput.ReadyForInput)throw new InvalidOperationException("Screen text editor did not finish loading.");
            _textInput.Text="中文文字\n第二行";
            var selectedFormat=_textInput.TextDocument.GetRange(0,2).CharacterFormat;
            selectedFormat.Name="Consolas";selectedFormat.Size=30;selectedFormat.ForegroundColor=Microsoft.UI.Colors.DarkBlue;
            OnPointer(new("down",720,480));if(_session.Document.Objects.Count!=count+1||_session.Selected?.Text!="中文文字\n第二行"||!ReferenceEquals(_chromeToolHost.Child,_chromeTools))throw new InvalidOperationException($"點畫布未提交文字或恢復工具列。count={_session.Document.Objects.Count}, expected={count+1}, text={_session.Selected?.Text}, editing={_textInput is not null}");
            var text=_session.Selected!;OnPointer(new("double",text.X+5,text.Y+5));if(_textInput is null)throw new InvalidOperationException("雙擊文字未開始編輯。");_textInput.Text="取消";FinishScreenText(false);if(_session.Selected?.Text!="中文文字\n第二行")throw new InvalidOperationException("取消文字修改了文件。");
            BeginScreenText(new(text.X,text.Y),text);
            for(var wait=0;wait<40&&_textInput is {ReadyForInput:false};wait++)await Task.Delay(50);
            var reopened=_textInput!.TextDocument.GetRange(0,2).CharacterFormat;
            if(reopened.Name!="Consolas"||Math.Abs(reopened.Size-30)>.1||!reopened.ForegroundColor.Equals(Microsoft.UI.Colors.DarkBlue))
                throw new InvalidOperationException($"螢幕文字重新編輯時遺失局部格式。font={reopened.Name}, size={reopened.Size}, color={reopened.ForegroundColor}, ready={_textInput.ReadyForInput}, spans={System.Text.Json.JsonSerializer.Serialize(text.RichTextSpans)}");
            _textInput.Text="修改後";ChooseScreenTool("pen");if(_session.Document.Objects.First(o=>o.Id==text.Id).Text!="修改後")throw new InvalidOperationException("換工具未提交文字。");
            var second=DocumentCodec.Clone(_session.Document.Objects.First(o=>o.Id==text.Id));second.Id=Guid.NewGuid().ToString();second.X=1200;_session.Begin();_session.Add(second);_session.Commit();_session.SelectedId=text.Id;ChooseScreenTool("select");var generation=_session.Generation;
            OnPointer(new("down",second.X+5,second.Y+5,true));OnPointer(new("up",second.X+5,second.Y+5,true));
            if(_session.SelectedIds.Count!=2||_session.Generation!=generation)throw new InvalidOperationException("Shift文字多選未保留或建立了無效Undo。");
            TextStyles.ApplySelection(_session,new(Size:48,Color:"#a855f7",Bold:true,Underline:true),_dpiScale);var edited=_session.Selected!;if(_session.SelectedObjects.Any(o=>o.FontSize!=48*_dpiScale||o.StrokeColor!="#a855f7"||o.IsUnderline!=true))throw new InvalidOperationException("螢幕文字樣式未生效。");
            OnPointer(new("right",edited.X+4,edited.Y+4));if(!_drawing||_session.SelectedIds.Count!=2||_chromeFlyout is not MenuFlyout menu||!menu.Items.OfType<MenuFlyoutSubItem>().Any(item=>item.Text=="文字大小"))throw new InvalidOperationException("螢幕文字物件設定未接線。");
            _session.Undo();if(_session.Document.Objects.First(o=>o.Id==text.Id).IsBold==true)throw new InvalidOperationException("文字樣式未能復原。");
            return new{draftSeparate=true,toolbarPage=true,clickCanvasCommits=true,chineseMultiline=true,doubleClickEdit=true,reopenPreserves=true,cancelPreserves=true,toolSwitchCommits=true,textContextMenu=true,shiftMultiSelection=true,objectMenuKeepsMultiSelection=true,selectionAddsNoUndo=true,styleUndo=true,imeHardware="未執行"};
        }
        finally{FinishScreenText(false);_session.Open(before);Changed();}
    }
}
