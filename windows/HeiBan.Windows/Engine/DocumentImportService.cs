using System.Runtime.InteropServices;
using HeiBan.Windows.Models;
using global::Windows.Data.Pdf;
using global::Windows.Storage;
using global::Windows.Storage.Streams;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows.Engine;

internal static class DocumentImportService
{
    internal static bool PowerPointAvailable=>Type.GetTypeFromProgID("PowerPoint.Application") is not null;
    internal static Task ConvertPresentationAsync(string source,string destination)
    {
        // Office COM belongs to one STA. Only the presentation opened here is closed; an
        // already-running PowerPoint session and the user's other presentations stay owned by the user.
        var completion=new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread=new Thread(()=>
        {
            dynamic? app=null,presentations=null,presentation=null;int? security=null,alerts=null;bool startedEmpty=false;
            Exception? failure=null;
            try
            {
                var type=Type.GetTypeFromProgID("PowerPoint.Application")??throw new InvalidOperationException(T("匯入 PPT/PPTX 需要安裝桌面版 PowerPoint。也可以先轉為 PDF 再匯入。"));
                app=Activator.CreateInstance(type)!;presentations=app.Presentations;startedEmpty=presentations.Count==0;
                security=(int)app.AutomationSecurity;alerts=(int)app.DisplayAlerts;app.AutomationSecurity=3;app.DisplayAlerts=1;
                presentation=presentations.Open(Path.GetFullPath(source),-1,0,0);
                presentation.SaveAs(Path.GetFullPath(destination),32,0); // ppSaveAsPDF; original is opened read-only.
                if(!File.Exists(destination))throw new IOException(T("PowerPoint 未產生 PDF。請先開啟簡報確認可正常匯出。"));
            }
            catch(Exception ex){failure=ex;}
            finally
            {
                try{if(presentation is not null)presentation.Close();}catch(Exception ex){failure??=ex;}
                try{if(app is not null){if(security.HasValue)app.AutomationSecurity=security.Value;if(alerts.HasValue)app.DisplayAlerts=alerts.Value;if(startedEmpty&&presentations is not null&&presentations.Count==0)app.Quit();}}catch{ /* Do not kill a user's Office process if COM cleanup fails. */ }
                foreach(object? value in new object?[]{presentation,presentations,app})
                    try{if(value is not null&&Marshal.IsComObject(value))Marshal.FinalReleaseComObject(value);}catch(Exception ex){failure??=ex;}
            }
            if(failure is null)completion.SetResult();else completion.SetException(failure);
        }){IsBackground=true,Name="HeiBan PowerPoint import"};thread.SetApartmentState(ApartmentState.STA);thread.Start();return completion.Task;
    }

    internal static async Task<HeiBanDocument> RenderPdfAsync(PdfDocument pdf,string title,int first,int last,IProgress<(int Done,int Total)> progress,CancellationToken cancellation)
    {
        if(first<0||last<first||last>=pdf.PageCount||last-first>=200)throw new InvalidDataException(T("一次最多匯入 200 頁，請縮小頁面範圍。"));
        var doc=new HeiBanDocument{Board=new BoardMetadata{Title=title,CanvasMode="notebook",CanvasPreset="custom",BackgroundColor="#ffffff",GridStyle="none",Pages=[]}};
        long totalBytes=0;double width=72,height=72;
        for(var index=first;index<=last;index++)
        {
            cancellation.ThrowIfCancellationRequested();using var page=pdf.GetPage((uint)index);
            var w=page.Size.Width*.75;var h=page.Size.Height*.75;
            if(!double.IsFinite(w)||!double.IsFinite(h)||w<=0||h<=0)throw new InvalidDataException(T("PDF 頁面尺寸無效。"));
            var scale=Math.Min(2,Math.Min(3072/w,3072/h));
            using var stream=new InMemoryRandomAccessStream();
            await page.RenderToStreamAsync(stream,new PdfPageRenderOptions{DestinationWidth=(uint)Math.Max(1,Math.Round(w*scale)),DestinationHeight=(uint)Math.Max(1,Math.Round(h*scale))}).AsTask(cancellation);
            totalBytes+=(long)stream.Size;if(totalBytes>100_000_000)throw new InvalidDataException(T("匯入圖片總量超過 100 MB，請縮小頁面範圍。"));
            stream.Seek(0);using var reader=new DataReader(stream);await reader.LoadAsync((uint)stream.Size).AsTask(cancellation);var bytes=new byte[(int)stream.Size];reader.ReadBytes(bytes);
            var sheet=new BoardPage{Index=index-first,Title=$"{index+1}"};doc.Board.Pages!.Add(sheet);
            var data="data:image/png;base64,"+Convert.ToBase64String(bytes);
            doc.Objects.Add(new BoardObject{BoardId=doc.Board.Id,PageId=sheet.Id,Type="image",Name=title+" · "+(index+1),X=0,Y=0,Width=w,Height=h,ImageUrl=data,OriginalImageUrl=data,OriginalWidth=(int)Math.Max(1,Math.Round(w*scale)),OriginalHeight=(int)Math.Max(1,Math.Round(h*scale)),IsLocked=true,ZIndex=-1});
            width=Math.Max(width,w);height=Math.Max(height,h);progress.Report((index-first+1,last-first+1));
        }
        doc.Board.CanvasWidth=width;doc.Board.CanvasHeight=height;doc.Board.ActivePageId=doc.Board.Pages![0].Id;
        foreach(var image in doc.Objects){image.X=(width-image.Width)/2;image.Y=(height-image.Height)/2;}
        return doc;
    }
}
