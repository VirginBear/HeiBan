using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Data.Pdf;
using global::Windows.Storage;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private bool _documentImporting;
    private async Task<HeiBanDocument?> ImportExternalDocumentAsync(string path)
    {
        if(_documentImporting)return null;_documentImporting=true;
        var extension=Path.GetExtension(path).ToLowerInvariant();var presentation=extension is ".pptx" or ".ppt";
        var temporary=Path.Combine(Path.GetTempPath(),"HeiBan-presentation-"+Guid.NewGuid().ToString("N")+".pdf");
        ContentDialog? busy=null;
        try
        {
            if(presentation)
            {
                if(!DocumentImportService.PowerPointAvailable)throw new InvalidOperationException(T("匯入 PPT/PPTX 需要安裝桌面版 PowerPoint。也可以先轉為 PDF 再匯入。"));
                busy=new ContentDialog{Title=T("轉換簡報"),Content=new StackPanel{Spacing=12,Children={new ProgressRing{IsActive=true},new TextBlock{Text=T("正在透過 PowerPoint 轉成靜態頁面。動畫、影片與可編輯投影片元素不會保留。"),TextWrapping=TextWrapping.Wrap}}},XamlRoot=Root.XamlRoot};
                var shown=busy.ShowAsync();await DocumentImportService.ConvertPresentationAsync(path,temporary);busy.Hide();await shown;busy=null;
            }
            var file=await StorageFile.GetFileFromPathAsync(presentation?temporary:path);var pdf=await PdfDocument.LoadFromFileAsync(file);
            if(pdf.PageCount==0)throw new InvalidDataException(T("PDF 沒有可匯入的頁面。"));
            var first=new NumberBox{Header=T("起始頁"),Minimum=1,Maximum=pdf.PageCount,Value=1,SpinButtonPlacementMode=NumberBoxSpinButtonPlacementMode.Inline};
            var last=new NumberBox{Header=T("結束頁"),Minimum=1,Maximum=pdf.PageCount,Value=Math.Min(200,pdf.PageCount),SpinButtonPlacementMode=NumberBoxSpinButtonPlacementMode.Inline};
            var panel=new StackPanel{Spacing=10,MaxWidth=420};panel.Children.Add(new TextBlock{Text=T("每頁匯入為鎖定背景圖片，可在上方繪圖。原文件文字與圖形不會轉成可編輯物件。"),TextWrapping=TextWrapping.Wrap});panel.Children.Add(first);panel.Children.Add(last);
            if(await new ContentDialog{Title=T("匯入文件頁面"),Content=panel,PrimaryButtonText=T("匯入"),CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot}.ShowAsync()!=ContentDialogResult.Primary)return null;
            if(!double.IsFinite(first.Value)||!double.IsFinite(last.Value)||first.Value!=Math.Truncate(first.Value)||last.Value!=Math.Truncate(last.Value)||first.Value<1||last.Value>pdf.PageCount||last.Value<first.Value||last.Value-first.Value>=200)throw new InvalidDataException(T("一次最多匯入 200 頁，請縮小頁面範圍。"));
            using var cancellation=new CancellationTokenSource();var status=new TextBlock{Text=T("正在匯入…")};
            busy=new ContentDialog{Title=T("匯入文件頁面"),Content=new StackPanel{Spacing=12,Children={new ProgressRing{IsActive=true},status}},CloseButtonText=T("取消"),XamlRoot=Root.XamlRoot};
            busy.CloseButtonClick+=(_,args)=>{args.Cancel=true;cancellation.Cancel();status.Text=T("正在取消…");};
            var showing=busy.ShowAsync();
            try{return await DocumentImportService.RenderPdfAsync(pdf,Path.GetFileNameWithoutExtension(path),(int)first.Value-1,(int)last.Value-1,new Progress<(int Done,int Total)>(p=>status.Text=$"{p.Done} / {p.Total}"),cancellation.Token);}
            catch(OperationCanceledException){return null;}
            finally{busy.Hide();await showing;busy=null;}
        }
        finally{busy?.Hide();_documentImporting=false;if(File.Exists(temporary))File.Delete(temporary);}
    }
}
