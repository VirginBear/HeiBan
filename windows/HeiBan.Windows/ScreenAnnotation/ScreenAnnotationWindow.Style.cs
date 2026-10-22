using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Ellipse=Microsoft.UI.Xaml.Shapes.Ellipse;

namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private readonly DispatcherTimer _styleCommitTimer=new(){Interval=TimeSpan.FromMilliseconds(300)};
    private bool _styleEditing;
    private BoardObject? StyleSelection=>_tool=="select"?_session.Selected:null;
    private void CommitScreenStyle()
    {
        _styleCommitTimer.Stop();if(!_styleEditing)return;_styleEditing=false;_session.Commit();Changed();
    }
    private void EditScreenStyle(Action<BoardObject> apply,bool fillOnly=false)
    {
        if(StyleSelection is null)return;
        var targets=_session.SelectedObjects.Where(o=>o.IsLocked!=true&&(!fillOnly||o.Type is "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star" or "arc" or "sticky")).ToArray();
        if(targets.Length==0)return;
        if(!_styleEditing){_session.Begin();_styleEditing=true;}
        foreach(var o in targets)apply(o);
        _styleCommitTimer.Stop();_styleCommitTimer.Start();_dirty=_fullDamage=_committedDirty=true;RefreshScreenStyleButtons();
    }
    private void SetScreenColor(string color)
    {
        if(StyleSelection is not null)EditScreenStyle(o=>o.StrokeColor=color);
        else{_color=color;_laser.Color=color;if(_preview is not null)_preview.StrokeColor=color;RefreshScreenStyleButtons();_dirty=true;}
    }
    private void SetScreenDash(string dash)
    {
        if(StyleSelection is not null)EditScreenStyle(o=>o.LineStyle=dash);
        else{_dash=dash;if(_preview is not null)_preview.LineStyle=dash;RefreshScreenStyleButtons();_dirty=true;}
    }
    private void SetScreenFill(string fill)
    {
        if(StyleSelection is not null)EditScreenStyle(o=>{o.FillColor=fill;o.FillGradientStart=null;o.FillGradientEnd=null;},true);
        else{_fill=fill;if(_preview?.Type is "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star")_preview.FillColor=fill;RefreshScreenStyleButtons();_dirty=true;}
    }
    private Button? _lastScreenBrushButton,_lastScreenDashButton;
    private string? _lastScreenBrushColor,_lastScreenDash;
    private void RefreshScreenStyleButtons()
    {
        var selected=StyleSelection;
        _brushButton.IsEnabled=selected?.IsLocked!=true;
        var color=selected?.StrokeColor??_color;var dash=selected?.LineStyle??_dash;
        if(!ReferenceEquals(_lastScreenBrushButton,_brushButton)||_lastScreenBrushColor!=color)
        {
            ToolbarUi.ReplaceIcon(_brushButton,new Ellipse{Width=22,Height=22,Fill=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(color)),Stroke=ChromeBrush(100,85,100,92),StrokeThickness=1});
            _lastScreenBrushButton=_brushButton;_lastScreenBrushColor=color;
        }
        if(!ReferenceEquals(_lastScreenDashButton,_dashButton)||_lastScreenDash!=dash)
        {ToolbarUi.ReplaceIcon(_dashButton,ToolIcons.CreateDash(dash));_lastScreenDashButton=_dashButton;_lastScreenDash=dash;}
        _dashButton.IsEnabled=selected?.IsLocked!=true&&(selected?.Type??_tool) is not("text" or "image" or "sticky" or "eraser" or "laser");
    }
    private void ShowScreenFill()=>ShowScreenFill(_moreButton);
    private void ShowScreenFill(FrameworkElement anchor)
    {
        var menu=new MenuFlyout();
        foreach(var pair in new[]{(T("無填滿"),"none"),(T("紅色"),"#EF4444"),(T("黃色"),"#F59E0B"),(T("綠色"),"#22C55E"),(T("藍色"),"#3B82F6"),(T("白色"),"#FFFFFF"),(T("黑色"),"#111827")})
        {
            var value=pair.Item2;var item=new MenuFlyoutItem{Text=pair.Item1};item.Click+=(_,_)=>{SetScreenFill(value);CommitScreenStyle();};menu.Items.Add(item);
        }
        ShowChromeFlyout(menu,anchor);
    }
    private async Task UndoScreenAsync(bool redo)
    {
        if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
        FinishScreenText();CancelGesture();var ids=_session.SelectedIds.ToArray();if(redo)_session.Redo();else _session.Undo();_session.SetSelection(ids);
        if(_target is not null)await _renderer.LoadImagesAsync(_target,_session.VisibleObjects);RefreshButtons();Changed();
    }
    private async Task InsertScreenCaptureAsync(RegionScreenshotService.CapturedRegion capture,long epoch)
    {
        if(!IsActive||epoch!=_session.DocumentEpoch)throw new InvalidOperationException("螢幕註記工作階段已改變，截圖未置入。");
        var data="data:image/bmp;base64,"+Convert.ToBase64String(capture.Bytes);
        var image=new BoardObject{Type="image",X=capture.Left-_overlay.Left,Y=capture.Top-_overlay.Top,Width=capture.Width,Height=capture.Height,
            ImageUrl=data,OriginalImageUrl=data,OriginalWidth=capture.Width,OriginalHeight=capture.Height,Opacity=1,Name=T("截圖")};
        // Decode before committing so an invalid result cannot leave an unusable object or an open transaction.
        await _renderer.LoadImagesAsync(_target!,new[]{image});
        if(!IsActive||epoch!=_session.DocumentEpoch)return;
        CancelGesture();_session.Begin();_session.Add(image);_session.SelectedId=image.Id;_session.Commit();_tool="select";RefreshButtons();Changed();
    }
}
