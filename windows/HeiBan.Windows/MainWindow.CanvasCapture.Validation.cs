#if HEIBAN_RELEASE_VALIDATION
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Xaml;
using global::Windows.ApplicationModel.DataTransfer;
namespace HeiBan.Windows;
public partial class MainWindow
{
    [System.Runtime.InteropServices.DllImport("user32.dll",EntryPoint="GetClipboardSequenceNumber")]
    private static extern uint GetCanvasClipboardSequence();
    private async Task<(int Width,int Height,byte[] Pixels)> ReadOwnCanvasClipboardAsync(string png)
    {
        if(GetCanvasClipboardSequence()!=_lastCanvasClipboardSequence)throw new InvalidOperationException("Clipboard changed; do not inspect unrelated user data.");
        var view=Clipboard.GetContent();
        if(GetCanvasClipboardSequence()!=_lastCanvasClipboardSequence)
            throw new InvalidOperationException("Clipboard changed; do not inspect unrelated user data.");
        if(!view.Contains(StandardDataFormats.Bitmap))throw new InvalidOperationException("No standard Bitmap clipboard format");
        using var stream=await (await view.GetBitmapAsync()).OpenReadAsync();
        using var bitmap=await CanvasBitmap.LoadAsync(CanvasSurface,stream);
        await bitmap.SaveAsync(png,CanvasBitmapFileFormat.Png);
        return((int)bitmap.SizeInPixels.Width,(int)bitmap.SizeInPixels.Height,bitmap.GetPixelBytes());
    }
    private async Task RunCanvasCaptureValidationAsync(string output)
    {
        Directory.CreateDirectory(output);
        try
        {
            var doc=new HeiBanDocument{Board=new(){CanvasMode="notebook",CanvasWidth=100,CanvasHeight=80,BackgroundColor="#FFFFFF",GridStyle="blank",ActivePageId="a",Pages=[new(){Id="a",Index=0},new(){Id="b",Index=1}]},Objects=[
                new(){Id="red",PageId="a",Type="rect",X=-10,Y=10,Width=50,Height=30,StrokeColor="#FF0000",FillColor="#FF0000"},
                new(){Id="other-page",PageId="b",Type="rect",X=0,Y=0,Width=100,Height=80,FillColor="#0000FF",ZIndex=999},
                new(){Id="hidden",PageId="a",Type="rect",X=0,Y=0,Width=100,Height=80,FillColor="#0000FF",ZIndex=1000,IsVisible=false}
            ]};
            await OpenAsync(doc);await Task.Delay(250);_viewport.Zoom=.2;_viewport.X=-500;_viewport.Y=300;
            var context=new CanvasCaptureContext(_session.DocumentEpoch,"a");
            if(await CopyCanvasAreaAsync(CanvasCapturePlan.WholePage(doc.Board)!,context) is null)throw new Exception("Whole-page capture failed: "+StatusText.Text);
            var page=await ReadOwnCanvasClipboardAsync(Path.Combine(output,"whole-page.png"));
            bool Red(byte[] pixels,int index)=>pixels[index]<5&&pixels[index+1]<5&&pixels[index+2]>250&&pixels[index+3]==255;
            if(page.Width!=200||page.Height!=160||!Red(page.Pixels,(40*page.Width+20)*4))throw new Exception("Page bounds/content/visibility/zoom check failed");
            if(page.Pixels[0]!=255||page.Pixels[1]!=255||page.Pixels[2]!=255||page.Pixels[3]!=255)throw new Exception("Paper background is not captured");
            var old=context;_session.Open(new(){Board=new(){CanvasMode="infinite",BackgroundColor="#FFFFFF",GridStyle="blank"},Objects=[new(){Type="rect",X=-20,Y=0,Width=20,Height=20,FillColor="#FF0000",StrokeColor="#FF0000"}]});
            var token=_lastCanvasCaptureToken;if(await CopyCanvasAreaAsync(new(0,0,10,10),old) is not null||token!=_lastCanvasCaptureToken)throw new Exception("Stale request altered clipboard");
            if(await CopyCanvasAreaAsync(new(-25,-10,80,60),new(_session.DocumentEpoch,null)) is null)throw new Exception("Negative region capture failed");
            var region=await ReadOwnCanvasClipboardAsync(Path.Combine(output,"negative-region.png"));
            if(region.Width!=160||region.Height!=120||!Red(region.Pixels,(40*region.Width+30)*4))throw new Exception("Negative region crop failed");
            await File.WriteAllTextAsync(Path.Combine(output,"result.json"),JsonSerializer.Serialize(new{success=true,wholePage=true,currentPageOnly=true,hiddenExcluded=true,offscreenAndZoomIndependent=true,background=true,negativeCoordinates=true,standardClipboardBitmap=true,disposedPngStreamStillPasteable=true,staleRequestRejected=true}));
            await PrepareMarqueeValidationAsync(Path.Combine(output,"input"),true);Title="HeiBan capture QA";
            var previous=_lastCanvasCaptureToken;var timer=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(200)};
            timer.Tick+=async(_,_)=>
            {
                if(_lastCanvasCaptureToken==previous)return;timer.Stop();
                try{var image=await ReadOwnCanvasClipboardAsync(Path.Combine(output,"mouse-region.png"));await File.WriteAllTextAsync(Path.Combine(output,"mouse-region.json"),JsonSerializer.Serialize(new{success=true,image.Width,image.Height}));}
                catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"mouse-error.txt"),error.ToString());}
            };
            timer.Start();Closed+=(_,_)=>timer.Stop();
            File.WriteAllText(Path.Combine(output,"ready.json"),"ready for selection then canvas capture");
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"error.txt"),error.ToString());}
    }
}
#endif
