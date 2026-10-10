using System.Text;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Storage.Pickers;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private bool _exporting;
    private async Task ExportDocumentAsync()
    {
        if(_exporting)return;FinishText();CommitPropertyEdit();if(_gesture)CancelGesture();
        var boardId=_session.Document.Board.Id;
        var scope=new ComboBox{Header="匯出範圍",ItemsSource=new[]{"目前頁面／全部內容","選取物件","目前視野"},SelectedIndex=0,MinWidth=250};
        var result=await new ContentDialog{Title="匯出作品",Content=scope,PrimaryButtonText="選擇格式及位置",CloseButtonText="取消",XamlRoot=Root.XamlRoot}.ShowAsync();
        if(result!=ContentDialogResult.Primary||boardId!=_session.Document.Board.Id)return;
        var doc=DocumentCodec.Clone(_session.Document);var selectedIds=_session.SelectedIds.ToHashSet();
        var objects=doc.Objects.Where(o=>o.IsVisible!=false&&(doc.Board.CanvasMode!="notebook"||o.PageId is null||o.PageId==doc.Board.ActivePageId)&&(scope.SelectedIndex!=1||selectedIds.Contains(o.Id))).ToArray();
        if(scope.SelectedIndex==1&&objects.Length==0){StatusText.Text="請先選取物件。";return;}
        var area=scope.SelectedIndex==2?new ExportArea(-_viewport.X/_viewport.Zoom,-_viewport.Y/_viewport.Zoom,Math.Max(1,CanvasSurface.ActualWidth/_viewport.Zoom),Math.Max(1,CanvasSurface.ActualHeight/_viewport.Zoom)):BoardExporter.Bounds(doc.Board,objects,scope.SelectedIndex==1);
        var picker=new FileSavePicker{SuggestedFileName=doc.Board.Title};WinRT.Interop.InitializeWithWindow.Initialize(picker,WinRT.Interop.WindowNative.GetWindowHandle(this));
        picker.FileTypeChoices.Add("可編輯原稿（所有頁面）",new List<string>{".heiban"});picker.FileTypeChoices.Add("跨平台 JSON（所有頁面）",new List<string>{".json"});
        picker.FileTypeChoices.Add("PNG 圖片",new List<string>{".png"});picker.FileTypeChoices.Add("SVG 向量圖",new List<string>{".svg"});picker.FileTypeChoices.Add("PDF 文件",new List<string>{".pdf"});picker.FileTypeChoices.Add("HTML 離線作品",new List<string>{".html"});
        var file=await picker.PickSaveFileAsync();if(file is null)return;_exporting=true;
        try
        {
            switch(file.FileType.ToLowerInvariant())
            {
                case ".png":
                    var scale=Math.Min(2,Math.Min(16384/area.Width,16384/area.Height));
                    scale=Math.Min(scale,Math.Sqrt(40_000_000/(area.Width*area.Height)));if(scale<=0)throw new InvalidOperationException("匯出範圍無效。");
                    var vp=new ViewportTransform{Zoom=scale,X=-area.X*scale,Y=-area.Y*scale};
                    using(var target=new CanvasRenderTarget(CanvasSurface,(float)Math.Max(1,area.Width*scale),(float)Math.Max(1,area.Height*scale),96))
                    {
                        await _renderer.LoadImagesAsync(target,objects);
                        using(var ds=target.CreateDrawingSession()){_renderer.RenderBackground(ds,doc.Board,vp,(float)target.Size.Width,(float)target.Size.Height);_renderer.RenderObjects(ds,objects,vp,(float)target.Size.Width,(float)target.Size.Height);}
                        await target.SaveAsync(file.Path,CanvasBitmapFileFormat.Png);
                    }break;
                case ".svg":await DocumentSessionManager.WriteAtomicAsync(file.Path,BoardExporter.Svg(doc,objects,area));break;
                case ".html":await DocumentSessionManager.WriteAtomicAsync(file.Path,BoardExporter.Html(doc,objects,area));break;
                case ".pdf":await ExportPdfAsync(doc,objects,area,file.Path);break;
                default:await DocumentSessionManager.WriteAtomicAsync(file.Path,DocumentCodec.Encode(doc));break;
            }
            StatusText.Text="已匯出："+file.Name;
        }
        catch(Exception ex){await Error(ex);}
        finally{_exporting=false;}
    }
    private async Task ExportPdfAsync(HeiBanDocument doc,IEnumerable<BoardObject> objects,ExportArea area,string destination)
    {
        var path=Path.Combine(Path.GetTempPath(),"HeiBan-export-"+Guid.NewGuid().ToString("N")+".html");
        var temporaryPdf=Path.Combine(Path.GetTempPath(),"HeiBan-export-"+Guid.NewGuid().ToString("N")+".pdf");
        var view=new WebView2{Width=1,Height=1,Opacity=0,IsHitTestVisible=false};Root.Children.Add(view);
        try
        {
            await File.WriteAllTextAsync(path,BoardExporter.Html(doc,objects,area,true),new UTF8Encoding(false));
            await view.EnsureCoreWebView2Async().AsTask().WaitAsync(TimeSpan.FromSeconds(30));
            view.CoreWebView2.Settings.AreDefaultContextMenusEnabled=false;view.CoreWebView2.Settings.IsScriptEnabled=false;
            var loaded=new TaskCompletionSource<bool>();
            view.CoreWebView2.NavigationCompleted+=(_,e)=>{if(e.IsSuccess)loaded.TrySetResult(true);else loaded.TrySetException(new InvalidOperationException("PDF 排版載入失敗："+e.WebErrorStatus));};
            view.CoreWebView2.Navigate(new Uri(path).AbsoluteUri);await loaded.Task.WaitAsync(TimeSpan.FromSeconds(30));
            var settings=view.CoreWebView2.Environment.CreatePrintSettings();
            var printScale=Math.Min(1,14400/Math.Max(area.Width,area.Height));
            settings.PageWidth=Math.Clamp(area.Width*printScale/72,1,200);settings.PageHeight=Math.Clamp(area.Height*printScale/72,1,200);settings.MarginTop=settings.MarginBottom=settings.MarginLeft=settings.MarginRight=0;settings.ShouldPrintBackgrounds=true;settings.ShouldPrintHeaderAndFooter=false;settings.ScaleFactor=1;
            if(!await view.CoreWebView2.PrintToPdfAsync(temporaryPdf,settings))throw new InvalidOperationException("PDF 匯出失敗，請確認 WebView2 執行環境。");
            var pdf=PdfDocumentAttachment.Append(await File.ReadAllBytesAsync(temporaryPdf),doc);
            await File.WriteAllBytesAsync(temporaryPdf,pdf);
            File.Copy(temporaryPdf,destination,true);
        }
        finally
        {
            view.Close();Root.Children.Remove(view);
            if(File.Exists(path))File.Delete(path);if(File.Exists(temporaryPdf))File.Delete(temporaryPdf);
        }
    }
}
