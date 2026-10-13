using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Foundation;

namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private async Task<object> ValidateInteractionChangesAsync(string outputDirectory)
    {
        var saved=DocumentCodec.Clone(_session.Document);var savedFill=_fill;var tool=_tool;var color=_color;var dash=_dash;var dock=_chromeDock;var collapsed=_collapsed;
        try
        {
            _session.Open(new());_session.Begin();var inside=_session.Add(new BoardObject{Type="rect",X=420,Y=420,Width=20,Height=20,StrokeWidth=1});var partial=_session.Add(new BoardObject{Type="rect",X=460,Y=420,Width=40,Height=20,StrokeWidth=1});_session.Commit();
            ChooseScreenTool("select");OnPointer(new("down",400,400));OnPointer(new("move",475,475));OnPointer(new("up",475,475));
            if(!_session.SelectedIds.SetEquals(new[]{inside.Id}))throw new InvalidOperationException("螢幕包含框選失敗。");
            _session.SelectedId=null;OnPointer(new("down",475,400));OnPointer(new("move",400,475));OnPointer(new("up",400,475));
            if(!_session.SelectedIds.SetEquals(new[]{inside.Id,partial.Id}))throw new InvalidOperationException("螢幕交叉框選失敗。");
            _color="#CC3366";_dash="dotted";ChooseScreenTool("curve");var count=_session.Document.Objects.Count;
            OnPointer(new("down",600,500));OnPointer(new("up",600,500));OnPointer(new("move",700,600));
            if(_preview?.ParsedPoints.Count!=2||_session.Document.Objects.Count!=count)throw new InvalidOperationException("第一點曲線預覽失敗。");
            OnPointer(new("down",700,600));OnPointer(new("up",700,600));OnPointer(new("move",800,500));
            if(_preview?.ParsedPoints.Count!=3||_session.Document.Objects.Count!=count)throw new InvalidOperationException("第二點曲線預覽失敗。");
            OnPointer(new("down",800,500));OnPointer(new("up",800,500));var curve=_session.Document.Objects.Last();
            if(_session.Document.Objects.Count!=count+1||curve.StrokeColor!=_color||curve.LineStyle!=_dash)throw new InvalidOperationException("曲線提交／預選樣式失敗。");
            _session.Undo();if(_session.Document.Objects.Count!=count)throw new InvalidOperationException("三點曲線不只一筆復原。");
            ChooseScreenTool("rect");Render();var cachedBefore=_committedBuilds;
            OnPointer(new("down",850,450));Render();OnPointer(new("move",900,500));Render();OnPointer(new("move",940,560));Render();
            if(_committedBuilds!=cachedBefore)throw new InvalidOperationException("圖形暫態預覽重繪了永久場景。");
            OnPointer(new("up",940,560));Render();if(_committedBuilds!=cachedBefore+1)throw new InvalidOperationException("圖形提交沒有一次更新永久場景。");
            ChooseScreenTool("select");Render();cachedBefore=_committedBuilds;OnPointer(new("down",1000,700));Render();OnPointer(new("move",1050,760));Render();OnPointer(new("move",1100,800));Render();
            if(_committedBuilds!=cachedBefore)throw new InvalidOperationException("框選預覽重繪了永久場景。");OnPointer(new("up",1100,800));Render();
            CancelGesture();ChooseScreenTool("line");OnPointer(new("down",1200,600));OnPointer(new("move",1400,680,true));
            if(_preview?.Y1!=_preview?.Y2)throw new InvalidOperationException("Shift直線預覽未水平。");OnPointer(new("up",1260,850,true));var orthogonal=_session.Document.Objects.Last();
            if(orthogonal.X1!=orthogonal.X2)throw new InvalidOperationException("Shift收筆未改為垂直。");_session.Undo();
            ChooseScreenTool("select");_session.SelectedId=inside.Id;var originalStyle=DocumentCodec.Clone(_session.Selected!);
            SetScreenColor("#3B82F6");CommitScreenStyle();SetScreenDash("dashdot");CommitScreenStyle();SetScreenFill("#F59E0B");CommitScreenStyle();
            var styled=_session.Selected!;if(styled.StrokeColor!="#3B82F6"||styled.LineStyle!="dashdot"||styled.FillColor!="#F59E0B")throw new InvalidOperationException("選取矩形樣式未生效。");
            await UndoScreenAsync(false);if(_session.Selected?.FillColor!=originalStyle.FillColor)throw new InvalidOperationException("填滿復原失敗。");await UndoScreenAsync(false);await UndoScreenAsync(false);
            ShowBrushSettings();await Task.Delay(80);var panel=((Flyout)_chromeFlyout!).Content as StackPanel;var sliders=panel!.Children.OfType<Slider>().ToArray();sliders[0].Value=8;sliders[0].Value=10;CommitScreenStyle();_chromeFlyout.Hide();
            if(_session.Selected?.StrokeWidth!=10*_dpiScale)throw new InvalidOperationException("物件粗細滑桿未接線。");await UndoScreenAsync(false);if(_session.Selected?.StrokeWidth!=originalStyle.StrokeWidth)throw new InvalidOperationException("滑桿多次調整不是一筆Undo。");
            var imageCount=_session.Document.Objects.Count;var bytes=await File.ReadAllBytesAsync(Path.Combine(outputDirectory,"screenshot-mask-synthetic.bmp"));
            await InsertScreenCaptureAsync(new(bytes,_overlay.Left+130,_overlay.Top+240,24,24),_session.DocumentEpoch);var image=_session.Selected!;
            if(image.Type!="image"||image.X!=130||image.Y!=240||image.Width!=24||image.Height!=24||_session.Document.Objects.Count!=imageCount+1)throw new InvalidOperationException("截圖未以選區位置留在螢幕画布。");
            var beforeResize=DocumentCodec.Clone(image);_session.Begin();ObjectHandles.Resize(image,beforeResize,4,new(178,288),true);_session.Commit();if(image.Width!=48||image.Height!=48)throw new InvalidOperationException("截圖物件不能調整尺寸。");
            await UndoScreenAsync(false);await UndoScreenAsync(false);Render();if(_session.Document.Objects.Count!=imageCount)throw new InvalidOperationException("截圖不只一筆Undo。");await UndoScreenAsync(true);Render();
            var restoredPixel=_target!.GetPixelBytes(140,250,1,1);if(restoredPixel[0]!=192||restoredPixel[1]!=80||restoredPixel[2]!=32)throw new InvalidOperationException("截圖重做後圖片解碼快取未恢復。");await UndoScreenAsync(false);
            SetDrawing(false);Render();if(_target!.GetPixelBytes(1,1,1,1)[3]!=0)throw new InvalidOperationException("操作模式未清除輸入背景alpha。");
            SetDrawing(true);Render();if(_target!.GetPixelBytes(1,1,1,1)[3]!=1)throw new InvalidOperationException("作畫模式未恢復可接收輸入的alpha背景。");
            DockChrome("left");SetChromeCollapsed(false);await Task.Delay(120);((Border)Content).UpdateLayout();
            var controls=_buttons.Values.Concat(_chromeActions).Concat(new[]{_mode,_brushButton,_dashButton,_clearButton,_moreButton,_closeButton}).ToArray();
            var sizes=controls.Select(button=>new{width=button.ActualWidth,height=button.ActualHeight,iconWidth=(button.Content as FrameworkElement)?.ActualWidth??0,iconHeight=(button.Content as FrameworkElement)?.ActualHeight??0}).ToArray();
            if(sizes.Any(size=>Math.Abs(size.width-32)>.5||Math.Abs(size.height-32)>.5||size.iconWidth>24||size.iconHeight>24))throw new InvalidOperationException("直排圖示被壓縮或超出按鈕："+System.Text.Json.JsonSerializer.Serialize(sizes));
            if(_chromeToolHost.ActualWidth<32||_chromeTools.ActualHeight<32)throw new InvalidOperationException("直排工具區量測壓縮了項目。");
            ShowBrushSettings();await Task.Delay(80);if(_chromeFlyout?.OverlayInputPassThroughElement!=Content)throw new InvalidOperationException("設定浮窗未允許工具列直接切換。");_chromeFlyout.Hide();
            return new{windowSelection=true,crossingSelection=true,curveFirstPointPreview=true,curveSecondPointPreview=true,curveOneUndo=true,preselectedColorAndDash=true,verticalButtons=sizes,toolsHostWidth=_chromeToolHost.ActualWidth,toolsHostHeight=_chromeToolHost.ActualHeight,toolsHeight=_chromeTools.ActualHeight,toolbarClickThrough=true,shapeAndMarqueePreviewReuseScene=true,shapeCommitRebuildsOnce=true,modeRebuildsInputAlpha=true,selectedShapeStyle=true,styleSliderOneUndo=true,screenshotImageOnScreen=true,screenshotPositionAndResize=true,screenshotUndoRedoPixels=true,shiftOrthogonalPreviewAndCommit=true,hardwarePointer="未執行"};
        }
        finally{_chromeFlyout?.Hide();CancelGesture();_session.Open(saved);_tool=tool;_color=color;_dash=dash;_fill=savedFill;RefreshBrushButton();_dashButton.Content=HeiBan.Windows.Views.ToolIcons.CreateDash(_dash);SetChromeCollapsed(collapsed);DockChrome(dock);Changed();}
    }
}
