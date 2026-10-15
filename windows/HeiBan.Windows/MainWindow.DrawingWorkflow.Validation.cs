using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using global::Windows.Data.Pdf;
using global::Windows.Storage;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private void ConfigureGuideView(string stage)
    {
        if(string.IsNullOrEmpty(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")))throw new InvalidOperationException("Guide capture requires isolated data.");
        _toolbarPage=stage=="triangle"?"drawing":"common";
        _toolbarPrefs.DisplayMode="labels";foreach(var key in ToolbarPreferences.AllDefaultTools)_toolbarPrefs.ShowTool(key);BuildChrome();
        ShowWorkspaceHeader(true);_headerPinned=true;Inspector.Visibility=Visibility.Collapsed;_objectDetailsId=null;
        if(stage=="properties")
        {_tool="select";_session.SelectedId=_session.Document.Objects.First(o=>o.Type=="rect").Id;_objectDetailsId=_session.SelectedId;Inspector.Visibility=Visibility.Visible;}
        else if(stage=="triangle")
        {_tool="triangle";_polygon.Clear();_polygon.Add(new(760,430));_polygon.Add(new(940,530));var cursor=_viewport.WorldToScreen(700,545);_mouse=new((float)cursor.X,(float)cursor.Y);}
        if(stage=="pdf"){_viewport.X=100;_viewport.Y=180;}
        RefreshEditor();
    }
    private async Task RunDrawingWorkflowChecksAsync(string directory)
    {
        if(string.IsNullOrEmpty(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")))throw new InvalidOperationException("Isolated data directory required.");
        Directory.CreateDirectory(directory);
        try
        {
            var pdf=await PdfDocument.LoadFromFileAsync(await StorageFile.GetFileFromPathAsync(Path.Combine(directory,"fixture.pdf")));
            var imported=await DocumentImportService.RenderPdfAsync(pdf,"PDF import check",0,(int)pdf.PageCount-1,new Progress<(int,int)>(),CancellationToken.None);
            if(imported.Board.Pages?.Count!=2||imported.Objects.Count!=2||imported.Objects.Any(o=>o.IsLocked!=true||!o.ImageUrl!.StartsWith("data:image/png;base64,")))throw new InvalidOperationException("PDF page import failed.");
            await File.WriteAllTextAsync(Path.Combine(directory,"imported.heiban"),DocumentCodec.Encode(imported));
            var copy=DocumentCodec.Decode(DocumentCodec.Encode(imported));if(copy.Board.Pages!.Count!=2||copy.Objects.Select(o=>o.PageId).Distinct().Count()!=2)throw new InvalidOperationException("Imported page persistence failed.");
            await OpenAsync(imported);await ExportPdfAsync(imported,imported.Objects.Where(o=>o.PageId==imported.Board.ActivePageId),BoardExporter.Bounds(imported.Board,imported.Objects),Path.Combine(directory,"roundtrip.pdf"),true);
            var output=await PdfDocument.LoadFromFileAsync(await StorageFile.GetFileFromPathAsync(Path.Combine(directory,"roundtrip.pdf")));if(output.PageCount!=2)throw new InvalidOperationException("Expected two PDF export pages, got "+output.PageCount);
            var converted=false;
            if(DocumentImportService.PowerPointAvailable)
            {
                await DocumentImportService.ConvertPresentationAsync(Path.Combine(directory,"fixture.pptx"),Path.Combine(directory,"presentation.pdf"));
                var slides=await PdfDocument.LoadFromFileAsync(await StorageFile.GetFileFromPathAsync(Path.Combine(directory,"presentation.pdf")));
                var slideWork=await DocumentImportService.RenderPdfAsync(slides,"PPTX import check",0,(int)slides.PageCount-1,new Progress<(int,int)>(),CancellationToken.None);
                if(slideWork.Board.Pages?.Count!=2)throw new InvalidOperationException("Expected two PPTX slides.");converted=true;
            }
            EnsureScreenAnnotation();var screen=await _screenAnnotation!.ValidateDrawingWorkflowAsync();
            await File.WriteAllTextAsync(Path.Combine(directory,"workflow-result.json"),JsonSerializer.Serialize(new{success=true,pdfImportedPages=imported.Board.Pages.Count,pdfExportedPages=output.PageCount,presentationConverted=converted,screen,hardwarePointer="Pending user test"},new JsonSerializerOptions{WriteIndented=true}));
            var demonstration=DocumentCodec.Decode(await File.ReadAllTextAsync(Path.Combine(directory,"demo.heiban")));await OpenAsync(demonstration);
            _toolbarPrefs.DisplayMode="labels";foreach(var key in ToolbarPreferences.AllDefaultTools)_toolbarPrefs.ShowTool(key);BuildChrome();
            if(_toolButtons["select"].Visibility!=Visibility.Visible)throw new InvalidOperationException("Selection tool not visible.");
            Inspector.Visibility=Visibility.Collapsed;_tool="select";_session.SelectedId=null;RefreshEditor();
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(directory,"workflow-error.txt"),error.ToString());throw;}
    }
}
