using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task<object> ValidateInteractionsAsync(string outputDirectory)
    {
        var saved=DocumentCodec.Clone(_session.Document);var tool=_tool;var styleTool=_styleTool;
        var styles=_toolStyles.ToDictionary(p=>p.Key,p=>JsonSerializer.Deserialize<ToolStyle>(JsonSerializer.Serialize(p.Value,new JsonSerializerOptions{IncludeFields=true}),new JsonSerializerOptions{IncludeFields=true})!);
        try
        {
            _session.Open(new());ActivateTool("select");
            ChangeProperty(()=>{CurrentStyle.Color="#CC3366";CurrentStyle.Dash="dashdot";});ActivateTool("pen");
            var pen=Styled(new BoardObject{Type="stroke"});if(pen.StrokeColor!="#CC3366"||pen.LineStyle!="dashdot")throw new InvalidOperationException("預先選色與線條未套用到画筆。");
            ActivateTool("rect");var rectangle=Styled(new BoardObject{Type="rect"});if(rectangle.StrokeColor!=pen.StrokeColor||rectangle.LineStyle!=pen.LineStyle)throw new InvalidOperationException("圖形切換遺失預選樣式。");
            _session.Begin();var inside=_session.Add(new BoardObject{Type="rect",X=20,Y=20,Width=20,Height=20,StrokeWidth=1});var partial=_session.Add(new BoardObject{Type="rect",X=60,Y=20,Width=40,Height=20,StrokeWidth=1});_session.Commit();
            ActivateTool("select");_start=new(0,0);BeginWindowSelection(_start,false);UpdateWindowSelection(new(75,75));CompleteWindowSelection(new(75,75));
            if(!_session.SelectedIds.SetEquals(new[]{inside.Id}))throw new InvalidOperationException("普通畫布包含框選未生效。");
            _start=new(75,0);BeginWindowSelection(_start,false);UpdateWindowSelection(new(0,75));CompleteWindowSelection(new(0,75));
            if(!_session.SelectedIds.SetEquals(new[]{inside.Id,partial.Id}))throw new InvalidOperationException("普通畫布交叉框選未生效。");
            _session.SelectedId=inside.Id;RefreshProperties();
            var quickDash=SelectionBarTools.Children.OfType<Microsoft.UI.Xaml.Controls.Button>().First(button=>Equals(Microsoft.UI.Xaml.Controls.ToolTipService.GetToolTip(button),"線條樣式"));var sample=quickDash.Content;
            ChangeProperty(()=>_session.Selected!.LineStyle="dotted");
            if(ReferenceEquals(sample,quickDash.Content)||!SelectionBarTools.Children.Contains(quickDash))throw new InvalidOperationException("選取快捷列沒有直接同步目前線條樣式。");CommitPropertyEdit();
            _session.Begin();_session.Selected!.X+=15;CancelGesture();
            var reboundDash=SelectionBarTools.Children.OfType<Microsoft.UI.Xaml.Controls.Button>().First(button=>Equals(Microsoft.UI.Xaml.Controls.ToolTipService.GetToolTip(button),"線條樣式"));
            if(ReferenceEquals(quickDash,reboundDash)||ReferenceEquals(_selectionBarObject,inside))throw new InvalidOperationException("取消手勢後快捷列仍綁定舊物件。");
            _session.Begin();var pin=new BoardPin{Name="原圖釘",X=140,Y=100,Zoom=1};(_session.Document.Board.Pins??=[]).Add(pin);_session.Commit();
            StartPinRename(pin);if(_pinNameEditor is null||!TextOverlay.Children.Contains(_pinNameEditor))throw new InvalidOperationException("圖釘畫布編輯器未顯示。");
            _pinNameEditor.Text="取消";FinishPinRename(false);if(pin.Name!="原圖釘")throw new InvalidOperationException("取消圖釘名稱改變了資料。");
            StartPinRename(pin);_pinNameEditor!.Text="新名稱";FinishPinRename();if(_session.Document.Board.Pins![0].Name!="新名稱")throw new InvalidOperationException("圖釘名稱未提交。");
            _session.Undo();if(_session.Document.Board.Pins![0].Name!="原圖釘")throw new InvalidOperationException("圖釘改名无法復原。");
            using var target=new CanvasRenderTarget(CanvasSurface,256,180,96);var vp=new ViewportTransform();
            byte[] Draw(IReadOnlyList<InkPoint> points)
            {using(var ds=target.CreateDrawingSession()){ds.Clear(Microsoft.UI.Colors.Transparent);_renderer.RenderLiveStroke(ds,points,vp,"#CC3366",4,1,"dashdot");}return target.GetPixelBytes();}
            var one=Draw(CurvePreview.Points(new[]{new InkPoint(20,20)},new(100,130)));var two=Draw(CurvePreview.Points(new[]{new InkPoint(20,20),new InkPoint(100,130)},new(220,20)));
            if(!one.Any(b=>b!=0)||!two.Any(b=>b!=0)||one.SequenceEqual(two))throw new InvalidOperationException("曲線兩階段預覽未產生不同的可見畫面。");
            await target.SaveAsync(Path.Combine(outputDirectory,"curve-preview.png"),CanvasBitmapFileFormat.Png);
            var patternPixels=new Dictionary<string,int>();
            foreach(var pattern in new[]{"solid","dashed","dotted","dashdot"})
            {
                using(var ds=target.CreateDrawingSession()){ds.Clear(Microsoft.UI.Colors.Transparent);_renderer.RenderLiveStroke(ds,new[]{new InkPoint(20,90),new InkPoint(220,90)},vp,"#CC3366",4,1,pattern);}
                var bytes=target.GetPixelBytes();var visible=0;for(var offset=3;offset<bytes.Length;offset+=4)if(bytes[offset]>0)visible++;
                if(visible<50)throw new InvalidOperationException("線條樣式沒有可見筆畫："+pattern);patternPixels[pattern]=visible;
                await target.SaveAsync(Path.Combine(outputDirectory,"line-pattern-"+pattern+".png"),CanvasBitmapFileFormat.Png);
            }
            ShowLineStyles(GetToolAnchor("dash"));var menu=_activeFlyout as Microsoft.UI.Xaml.Controls.MenuFlyout;
            if(menu?.Items.OfType<Microsoft.UI.Xaml.Controls.MenuFlyoutItem>().Count(row=>row.Icon is not null)!=4||_activeFlyout?.OverlayInputPassThroughElement!=ToolBorder)throw new InvalidOperationException("樣式預覽／工具列點擊穿透未接線。");_activeFlyout?.Hide();
            return new{preselectedColorAndDash=true,toolChangeRetainsStyle=true,windowSelection=true,crossingSelection=true,pinInlineRename=true,pinCancelAndUndo=true,curvePreviewAfterFirstAndSecond=true,lineStyleSamples=4,patternPixels,selectionQuickStyleUpdates=true,selectionRebindAfterCancel=true,toolbarClickThrough=true,hardwarePointer="未執行"};
        }
        finally
        {
            _activeFlyout?.Hide();FinishPinRename(false);_session.Open(saved);_toolStyles.Clear();foreach(var pair in styles)_toolStyles[pair.Key]=pair.Value;_tool=tool;_styleTool=styleTool;LoadActiveStyle();RefreshEditor();
        }
    }
}
