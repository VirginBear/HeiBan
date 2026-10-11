using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
namespace HeiBan.Windows;
public partial class MainWindow
{
    // Opt-in native validation uses an isolated data root and a synthetic input document.
    // This checks real rendering/printing/storage APIs; it does not claim hardware pointer or cross-app gesture coverage.
    private async Task RunNativeValidationAsync(string outputDirectory)
    {
        if(string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")))throw new InvalidOperationException("原生驗證需要獨立資料根。");
        Directory.CreateDirectory(outputDirectory);
        try
        {
            await Task.Delay(250);
            var doc=DocumentCodec.Clone(_session.Document);var objects=_session.VisibleObjects.ToArray();var area=BoardExporter.Bounds(doc.Board,objects);var vp=new ViewportTransform{X=-area.X,Y=-area.Y,Zoom=1};
            await File.WriteAllTextAsync(Path.Combine(outputDirectory,"document.svg"),BoardExporter.Svg(doc,objects,area));
            await File.WriteAllTextAsync(Path.Combine(outputDirectory,"document.html"),BoardExporter.Html(doc,objects,area));
            using(var target=new CanvasRenderTarget(CanvasSurface,(float)area.Width,(float)area.Height,96))
            {
                await _renderer.LoadImagesAsync(target,objects);
                using(var ds=target.CreateDrawingSession()){_renderer.RenderBackground(ds,doc.Board,vp,(float)area.Width,(float)area.Height);_renderer.RenderObjects(ds,objects,vp,(float)area.Width,(float)area.Height);}
                await target.SaveAsync(Path.Combine(outputDirectory,"document.png"),CanvasBitmapFileFormat.Png);
                if(target.GetPixelBytes().Distinct().Count()<4)throw new InvalidOperationException("實際畫布輸出缺少繪圖內容。");
            }
            await ExportPdfAsync(doc,objects,area,Path.Combine(outputDirectory,"document.pdf"));
            var screenshotMask=RegionScreenshotService.ValidateMask(outputDirectory);var interactions=await ValidateInteractionsAsync(outputDirectory);var mainText=ValidateMainText();var canvasPerformance=ValidateCanvasPerformance();var cpuPerformance=await Task.Run(InteractionBenchmark.Run);
            EnsureScreenAnnotation();await _screenAnnotation!.ValidateNativeSessionAsync(outputDirectory);
            if(_session.Document.Objects.Count!=doc.Objects.Count)throw new InvalidOperationException("螢幕註記污染原作品。");
            Inspector.Visibility=Microsoft.UI.Xaml.Visibility.Visible;LayersPanel.Visibility=Microsoft.UI.Xaml.Visibility.Visible;RefreshEditor();var library=await ValidateLibraryChromeAsync();
            await File.WriteAllTextAsync(Path.Combine(outputDirectory,"result.json"),JsonSerializer.Serialize(new{success=true,architecture=System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture.ToString(),layers=LayerPresentation.Build(_session.PageObjects).Select(row=>new{row.Title,row.Description}).ToArray(),objectCount=doc.Objects.Count,library,screenshotMask,interactions,mainText,canvasPerformance,cpuPerformance,pdfBytes=new FileInfo(Path.Combine(outputDirectory,"document.pdf")).Length},new JsonSerializerOptions{WriteIndented=true}));
            if(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_QA_PREVIEW") is {Length:>0} preview)await _screenAnnotation!.ShowValidationPreviewAsync(preview);
        }
        catch(Exception e){await File.WriteAllTextAsync(Path.Combine(outputDirectory,"result.json"),JsonSerializer.Serialize(new{success=false,error=e.ToString()}));}
    }
    private object ValidateMainText()
    {
        var before=DocumentCodec.Clone(_session.Document);var count=before.Objects.Count;
        try
        {
            StartText(new BoardObject{Type="text",X=200,Y=200,Width=280,Height=100,Text="",FontSize=24},true);
            if(_session.Document.Objects.Count!=count||_editor is null)throw new InvalidOperationException("普通文字草稿提前寫入文件。");
            _editor.Text="中文\n新文字";TextStyles.Apply(_editingObject!,new(Bold:true,Underline:true,Color:"#a855f7"));_editor.SyncStyle(_editingObject!);FinishText();
            var added=_session.Selected;if(added?.Text!="中文\n新文字"||added.IsUnderline!=true||added.IsBold!=true)throw new InvalidOperationException("普通文字草稿樣式未提交。");
            StartText(added);_editor!.Text="取消修改";FinishText(false);if(_session.Document.Objects.First(o=>o.Id==added.Id).Text!="中文\n新文字")throw new InvalidOperationException("Esc取消修改了普通文字。");
            var originalText=_session.PageObjects.First(o=>o.Type=="text"&&o.Id!=added.Id);_session.SetSelection(new[]{originalText.Id,added.Id});
            var screen=_viewport.WorldToScreen(added.X+5,added.Y+5);ShowContext(new((float)screen.X,(float)screen.Y));
            if(_session.SelectedIds.Count!=2)throw new InvalidOperationException("右鍵丟失文字多選。");
            return new{draftSeparate=true,chineseMultiline=true,wholeDraftStyle=true,cancelPreserves=true,rightClickKeepsMultiSelection=true,hardwareIme="未執行"};
        }
        finally{FinishText(false);_session.Open(before);RefreshEditor();}
    }

}
