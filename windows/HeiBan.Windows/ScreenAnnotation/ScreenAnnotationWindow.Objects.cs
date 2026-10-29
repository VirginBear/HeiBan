using static HeiBan.Windows.Localization.Strings;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.Foundation;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private void ScreenRightClick(InkPoint point)
    {
        if(!_drawing||_tool is "laser" or "cane")return;
        _chromeFlyout?.Hide();CancelGesture();
        var hit=_session.Hit(point,6);if(hit is null)return;
        // Right-click edits the hit object; preserve a multi-selection when it already contains it.
        DamageSelectedObjects();if(!_session.SelectedIds.Contains(hit.Id))_session.SelectedId=hit.Id;
        _tool="select";RefreshButtons();DamageSelectedObjects();_dirty=true;
        _status.Text=T("作畫中 · 右鍵物件可調整、複製或刪除");
        ShowChromeFlyout(CreateObjectMenu(),(FrameworkElement)Content,new FlyoutShowOptions{Position=new Point(
            (_overlay.Left+point.X-AppWindow.Position.X)/_dpiScale,
            (_overlay.Top+point.Y-AppWindow.Position.Y)/_dpiScale)});
    }
    private MenuFlyout CreateObjectMenu()
    {
        var menu=new MenuFlyout();var selected=_session.Selected;
        void Add(string icon,string label,Action action,bool enabled=true){var item=new MenuFlyoutItem{Text=label,Icon=ToolIcons.CreateIcon(icon),IsEnabled=enabled};item.Click+=(_,_)=>action();menu.Items.Add(item);}
        Add("pen",T("顏色、粗細與透明度"),ShowBrushSettings,selected is {IsLocked:not true});
        Add("dash-solid",T("線條樣式"),ShowScreenLineStyles,selected is {IsLocked:not true});
        Add("paint",T("填滿"),ShowScreenFill,selected is {IsLocked:not true});
        menu.Items.Add(new MenuFlyoutSeparator());
        Add("copy",T("複製"),CopyScreenSelection,selected is not null);
        Add("duplicate",T("製作副本"),DuplicateScreenSelection,selected is not null);
        Add("copy",T("貼上"),async()=>await PasteScreenSelectionAsync());
        menu.Items.Add(new MenuFlyoutSeparator());
        Add("delete",T("刪除物件"),DeleteScreenSelection,selected is {IsLocked:not true});
        Add(selected?.IsLocked==true?"unlock":"lock",selected?.IsLocked==true?T("解除鎖定"):T("鎖定物件"),()=>{if(_session.Selected is not { } o)return;_session.Begin();o.IsLocked=o.IsLocked!=true;_session.Commit();Changed();});
        var epoch=_session.DocumentEpoch;var page=_session.Document.Board.ActivePageId;var ids=_session.SelectedIds.ToHashSet();
        foreach(var (label,move) in new[]{("移至圖層頂端",LayerMove.Front),("上移圖層",LayerMove.Up),("下移圖層",LayerMove.Down),("移至圖層底端",LayerMove.Back)})
            Add("layers",T(label),()=>{if(epoch==_session.DocumentEpoch&&page==_session.Document.Board.ActivePageId&&_session.SelectedIds.SetEquals(ids))ChangeScreenLayer(move);},_session.SelectedObjects.Any(o=>o.IsLocked!=true));
        AppendScreenTextMenu(menu);return menu;
    }
    private string? SerializeScreenSelection()=>_session.Selected is { } selected?"HEIBAN_OBJECTS:"+JsonSerializer.Serialize(_session.SelectedObjects.ToArray(),DocumentCodec.Options):null;
    private void CopyScreenSelection()
    {
        try{var text=SerializeScreenSelection();if(text is null)return;var package=new DataPackage();package.SetText(text);Clipboard.SetContent(package);_status.Text=T("物件已複製，可貼到螢幕或黑板");}
        catch(Exception e){_status.Text=T("複製未完成：")+e.Message;}
    }
    private void DuplicateScreenSelection()
    {
        if(_session.Selected is not { } selected)return;CancelGesture();_session.Begin();
        var originals=_session.SelectedObjects.ToArray();var copies=new List<string>();foreach(var original in originals){var copy=DocumentCodec.Clone(original);copy.Id=Guid.NewGuid().ToString();copy.IsLocked=false;_session.Move(copy,20*_dpiScale,20*_dpiScale);_session.Add(copy);copies.Add(copy.Id);}_session.SetSelection(copies);_session.Commit();_tool="select";RefreshButtons();Changed();
    }
    private async Task PasteScreenSelectionAsync()
    {
        try
        {
            var view=Clipboard.GetContent();if(!view.Contains(StandardDataFormats.Text)){_status.Text=T("先複製黑板物件再貼上");return;}
            var text=await view.GetTextAsync();var objects=text.StartsWith("HEIBAN_OBJECTS:",StringComparison.Ordinal)?JsonSerializer.Deserialize<List<BoardObject>>(text[15..],DocumentCodec.Options):text.StartsWith("HEIBAN_OBJECT:",StringComparison.Ordinal)?new List<BoardObject>{JsonSerializer.Deserialize<BoardObject>(text[14..],DocumentCodec.Options)!}:null;
            if(objects is null||objects.Count==0||objects.Any(o=>o is null)){_status.Text=T("剪貼簿沒有黑板物件");return;}
            CancelGesture();_session.Begin();foreach(var o in objects){o.Id=Guid.NewGuid().ToString();o.BoardId=_session.Document.Board.Id;o.PageId=null;o.IsLocked=false;_session.Move(o,20*_dpiScale,20*_dpiScale);_session.Add(o);}_session.Commit();
            await _renderer.LoadImagesAsync(_target!,objects);_tool="select";RefreshButtons();Changed();
        }
        catch(Exception e){_session.Cancel();_status.Text=T("貼上未完成：")+e.Message;Changed();}
    }
    private void FocusScreenChrome()
    {
        if(!IsActive||_stopping||!_drawing||_textInput is not null)return;
        var handle=WinRT.Interop.WindowNative.GetWindowHandle(this);
        if(NativeOverlayWindow.CurrentForeground!=handle)Activate();
        _mode.Focus(FocusState.Programmatic);
    }
    private void Screen_KeyDown(object sender,Microsoft.UI.Xaml.Input.KeyRoutedEventArgs e)
    {
        if(e.Handled||!IsActive||_stopping||!_drawing||_textInput is not null)return;
        if(e.OriginalSource is TextBox or NumberBox or RichEditBox)return;
        if(e.Key is global::Windows.System.VirtualKey.Delete or global::Windows.System.VirtualKey.Back)
        {
            if(_session.Selected is {IsLocked:not true}){DeleteScreenSelection();e.Handled=true;}
        }
    }
    private void DeleteScreenSelection(){DamageSelectedObjects();CancelGesture();_session.DeleteSelected();RefreshScreenStyleButtons();Changed();}
    private void ChangeScreenLayer(LayerMove move)
    {CancelGesture();if(LayerReorder.MoveSelection(_session,move))Changed();}
    private async void ClearScreenObjects()
    {
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        if(!IsActive)return;FinishScreenText();_chromeFlyout?.Hide();CancelGesture();_session.Begin();_session.Document.Objects.Clear();_session.SelectedId=null;_session.Commit();_laser.Clear();Changed();_status.Text=T("已清除全部註記 · 可按復原恢復");
    }
    private object ValidateObjectCommands()
    {
        _tool="pen";SetDrawing(true);var count=_session.Document.Objects.Count;var original=_session.Document.Objects.Last();
        var point=original.ParsedPoints.Count>0?original.ParsedPoints[0]:ObjectHandles.Center(original);
        var generation=_session.Generation;OnPointer(new("right",point.X,point.Y));
        if(!_drawing||_tool!="select"||_session.SelectedId!=original.Id||_session.Generation!=generation)throw new InvalidOperationException("物件右鍵未選取或意外切換操作／建立Undo。");
        if(_chromeFlyout is not MenuFlyout context||!context.Items.OfType<MenuFlyoutItem>().Any(item=>item.Text=="刪除物件"&&item.IsEnabled)||!context.Items.OfType<MenuFlyoutItem>().Any(item=>item.Text=="複製"&&item.IsEnabled))throw new InvalidOperationException("實際右鍵選單缺少複製／刪除。");
        OnPointer(new("right",-100,-100));if(!_drawing||_session.SelectedId!=original.Id||_session.Generation!=generation)throw new InvalidOperationException("空白右鍵切換模式、清選取或建立Undo。");
        var copy=SerializeScreenSelection();if(copy is null||!copy.StartsWith("HEIBAN_OBJECTS:",StringComparison.Ordinal))throw new InvalidOperationException("複製格式不相容。");
        DuplicateScreenSelection();if(_session.Document.Objects.Count!=count+1)throw new InvalidOperationException("螢幕物件副本未建立。");
        DeleteScreenSelection();if(_session.Document.Objects.Count!=count)throw new InvalidOperationException("螢幕物件刪除未生效。");
        _session.Undo();if(_session.Document.Objects.Count!=count+1)throw new InvalidOperationException("螢幕刪除無法復原。");
        _session.Undo();if(_session.Document.Objects.Count!=count)throw new InvalidOperationException("螢幕副本無法復原。");
        var ids=_session.Document.Objects.Select(o=>o.Id).Order().ToArray();ClearScreenObjects();if(_session.Document.Objects.Count!=0)throw new InvalidOperationException("一鍵清除未清空。");
        _session.Undo();if(!_session.Document.Objects.Select(o=>o.Id).Order().SequenceEqual(ids))throw new InvalidOperationException("一鍵清除無法完整復原。");
        Changed();return new{rightClickObjectMenu=true,blankRightClickKeepsDrawing=true,rightClickAddsNoUndo=true,objectMenu=true,compatibleCopyPayload=true,duplicateDeleteUndo=true,oneClickClearUndo=true,clipboardRoundtrip="未執行，不覆寫使用者剪貼簿"};
    }
}
