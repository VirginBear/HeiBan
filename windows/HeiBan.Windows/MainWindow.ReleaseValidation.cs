#if HEIBAN_RELEASE_VALIDATION
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas.Svg;
using Microsoft.Graphics.Canvas;
using System.Numerics;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task RunRelease110ChecksAsync(string output)
    {
        Directory.CreateDirectory(output);
        try
        {
            var screen=await _screenAnnotation!.ValidateRelease110Async();
            await OpenAsync(new(){Board=new(){Title="HeiBan 1.1.0 QA",CanvasMode="infinite",GridStyle="dots"},Objects=[new(){Type="text",X=160,Y=180,Width=600,Height=100,Text="HeiBan 1.1.0 · More menu",FontSize=28}]});
            await Task.Delay(250);var icons=0;
            using var sheet=new CanvasRenderTarget(CanvasSurface,900,700,96);
            using var drawing=sheet.CreateDrawingSession();drawing.Clear(Microsoft.UI.Colors.White);
            foreach(var file in Directory.GetFiles(Path.Combine(AppContext.BaseDirectory,"Assets","MenuIcons"),"*.svg")){using var svg=CanvasSvgDocument.LoadFromXml(CanvasSurface,await File.ReadAllTextAsync(file));drawing.Transform=Matrix3x2.CreateTranslation(icons%9*100+30,icons/9*100+12);drawing.DrawSvg(svg,new global::Windows.Foundation.Size(40,40));drawing.DrawText(Path.GetFileNameWithoutExtension(file),-22,46,Microsoft.UI.Colors.DarkGreen,new Microsoft.Graphics.Canvas.Text.CanvasTextFormat{FontSize=11});icons++;}
            drawing.Dispose();await sheet.SaveAsync(Path.Combine(output,"menu-icons.png"),CanvasBitmapFileFormat.Png);
            await File.WriteAllTextAsync(Path.Combine(output,"release110-result.json"),JsonSerializer.Serialize(new{success=true,screen,svgIconsParsed=icons,hardwarePointer="Not measured",scope="Native WinUI/Win2D isolated self-checks; no Store installation/WACK"},new JsonSerializerOptions{WriteIndented=true}));
            _toolbarPrefs.HideTool("calculator");_toolbarPrefs.HideTool("timer");_toolbarPrefs.HideTool("ruler");_toolbarPrefs.HideTool("compass");BuildChrome();
            ShowMoreToolsMenu(GetToolAnchor("more"));
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"release110-error.txt"),error.ToString());}
        finally{if(Environment.GetCommandLineArgs().Contains("--release-validation-exit"))Microsoft.UI.Xaml.Application.Current.Exit();}
    }
}
#endif
