#if HEIBAN_RELEASE_VALIDATION
using System.Numerics;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.Graphics.Canvas;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task RunCursorCaneValidationAsync(string output)
    {
        Directory.CreateDirectory(output);
        try
        {
            var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
            using var cursors=new ToolCursor();using var sheet=new CanvasRenderTarget(CanvasSurface,1100,1030,96);
            using(var ds=sheet.CreateDrawingSession())
            {
                ds.Clear(Microsoft.UI.Colors.WhiteSmoke);var i=0;
                foreach(var style in new[]{"classic","duotone"})foreach(var tool in new[]{"pen","highlighter","paint","eraser","laser","curve","line","arrow","rect","circle","triangle","quadrilateral","diamond","pentagon","star"})
                {
                    ToolIcons.SetStyle(style);
                    foreach(var size in new[]{32,40,48,64,96,128})
                    {
                        var data=cursors.ReadValidation(tool,size,"#FFD400");var layout=ToolCursorGeometry.Layout(tool,style=="duotone",size);
                        Check(data.X==layout.X&&data.Y==layout.Y,"Native hotspot mismatch");
                        Check(data.Pixels.Where((_,n)=>n%4==3).Any(a=>a>100),"Empty native cursor bitmap");
                        if(size!=64)continue;
                        var x=20+i%9*120;var y=24+i/9*250;
                        using var bitmap=CanvasBitmap.CreateFromBytes(ds,data.Pixels,size,size,global::Windows.Graphics.DirectX.DirectXPixelFormat.B8G8R8A8UIntNormalized,96);
                        ds.FillRectangle(x,y,100,120,Microsoft.UI.Colors.DarkSlateGray);ds.DrawImage(bitmap,new Vector2(x+16,y+16));
                        ds.DrawCircle(x+16+data.X,y+16+data.Y,3,Microsoft.UI.Colors.Magenta,1);
                        ds.DrawText(style+"\n"+tool,x,y+135,Microsoft.UI.Colors.DarkGreen);
                    }
                    i++;
                }
                for(var c=0;c<150;c++)Check(cursors.ReadValidation("pen",64,$"#{c:X2}C040").Cached<=64,"Unbounded cursor cache");
            }
            await sheet.SaveAsync(Path.Combine(output,"native-cursor-hotspots.png"),CanvasBitmapFileFormat.Png);
            await OpenAsync(new(){Board=new(){Title="Cursor and cane QA",CanvasMode="infinite",GridStyle="dots"}});
            var constructionChecks=await ValidateMainShapeConstraintsAsync(output);
            var quickColorChecks=await ValidateQuickPaletteAsync();
            var generation=_session.Generation;var count=_session.Document.Objects.Count;
            using var crack=new CanvasRenderTarget(CanvasSurface,650,450,96);
            var state=new CaneFeedback();state.Strike(new(480,330),0);state.Strike(new(480,330),.1);state.Strike(new(480,330),.2);
            using(var ds=crack.CreateDrawingSession())
            {ds.Clear(Microsoft.UI.Colors.WhiteSmoke);_renderer.RenderCane(ds,state,new ViewportTransform(),.4);}
            await crack.SaveAsync(Path.Combine(output,"cane-crack.png"),CanvasBitmapFileFormat.Png);
            for(var frame=0;frame<3;frame++)
            {
                using var shards=new CanvasRenderTarget(CanvasSurface,650,450,96);
                using(var ds=shards.CreateDrawingSession()){ds.Clear(Microsoft.UI.Colors.DarkSlateGray);_renderer.RenderCane(ds,state,new ViewportTransform(),.4+frame*.3);}
                await shards.SaveAsync(Path.Combine(output,$"shards-{frame}.png"),CanvasBitmapFileFormat.Png);
            }
            CaneSound.IsMuted=false;CaneSound.Prepare();CaneSound.PlayImpact(1,_=>{});CaneSound.PlayImpact(2,_=>{});
            Check(CaneSound.ValidationRequested&&CaneSound.ValidationSecondRequested,"First and second attack variants missing");CaneSound.PlayCrack(_=>{});await Task.Delay(300);
            Check(CaneSound.ValidationCrackRequested,"Break cue was not requested");CaneSound.IsMuted=true;
            Check(!CaneSound.ValidationRequested&&!CaneSound.ValidationSecondRequested&&!CaneSound.ValidationCrackRequested,"Muting did not stop every cue");CaneSound.PlayCrack(_=>{});
            Check(!CaneSound.ValidationCrackRequested,"Muted break cue played");CaneSound.IsMuted=false;
            var screen=await _screenAnnotation!.ValidateCursorCaneAsync(output);
            Check(_session.Generation==generation&&_session.Document.Objects.Count==count,"Transient effect modified main document");
            ToolIcons.SetStyle("duotone");ActivateTool("cane");Title="HeiBan quick colors and shards QA";
            await File.WriteAllTextAsync(Path.Combine(output,"result.json"),JsonSerializer.Serialize(new{success=true,checks,constructionChecks,quickColorChecks,screen,crackScale=CaneCrackGeometry.DisplayScale,shards=CaneCrackGeometry.ShardCount,holdSeconds=StraightStrokeRecognizer.HoldSeconds,crackSegments=CaneCrackGeometry.Segments.Count,manualSoundListening=false}));
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"error.txt"),error.ToString());}
    }
}
#endif
