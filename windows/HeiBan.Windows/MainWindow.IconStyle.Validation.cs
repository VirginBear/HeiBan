#if HEIBAN_RELEASE_VALIDATION
using System.Numerics;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Svg;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task RunIconStyleValidationAsync(string output)
    {
        Directory.CreateDirectory(output);
        try
        {
            var screenChecks=await _screenAnnotation!.ValidateIconStyleAsync();
            await OpenAsync(new(){Board=new(){Title="Icon style QA",CanvasMode="infinite",GridStyle="dots"}});await Task.Delay(100);
            using var sheet=new CanvasRenderTarget(CanvasSurface,1100,540,96);var count=0;
            using(var ds=sheet.CreateDrawingSession())
            {
                ds.Clear(Microsoft.UI.ColorHelper.FromArgb(255,250,250,245));
                foreach(var file in Directory.GetFiles(Path.Combine(AppContext.BaseDirectory,"Assets","MenuIcons"),"*.svg",SearchOption.AllDirectories))
                {using var svg=CanvasSvgDocument.LoadFromXml(CanvasSurface,(await File.ReadAllTextAsync(file)).Replace(" width=\"26\" height=\"26\"", ""));ds.DrawSvg(svg,new global::Windows.Foundation.Size(32,32),new Vector2(count%22*50+8,count/22*70+12));count++;}
            }
            await sheet.SaveAsync(Path.Combine(output,"all-icons.png"),CanvasBitmapFileFormat.Png);
            using var preview=new CanvasRenderTarget(CanvasSurface,1000,490,96);
            var keys=new[]{"select","pen","highlighter","eraser","line","arrow","shapes","text","sticky","ruler","compass","laser","cane","palette","layers","mode-operate","mode-draw"};
            ToolIcons.SetStyle("duotone");using(var ds=preview.CreateDrawingSession())
            {
                ds.Clear(Microsoft.UI.ColorHelper.FromArgb(255,250,250,245));ds.DrawText("HeiBan 1.1.2 · A",26,12,Microsoft.UI.Colors.DarkGreen);
                for(var i=0;i<keys.Length;i++)
                {using var svg=CanvasSvgDocument.LoadFromXml(CanvasSurface,ToolIcons.RadialSvg(keys[i],false));var x=i%9*110+28;var y=i/9*130+58;ds.DrawSvg(svg,new global::Windows.Foundation.Size(60,60),new Vector2(x,y));ds.DrawText(keys[i],x-9,y+67,Microsoft.UI.Colors.DarkSlateGray,new Microsoft.Graphics.Canvas.Text.CanvasTextFormat{FontSize=13});}
                _renderer.RenderRadialWheel(ds,RadialTools.Value.Screen,new InkPoint(190,395),1,.63,operateReturnsDrawing:true);
                ToolIcons.SetStyle("classic");_renderer.RenderRadialWheel(ds,RadialTools.Value.Screen,new InkPoint(500,395),1,.63,operateReturnsDrawing:false);
                ToolIcons.SetStyle("duotone");_renderer.RenderRadialWheel(ds,RadialTools.Value.Screen,new InkPoint(810,395),1,.63,operateReturnsDrawing:false);
            }
            await preview.SaveAsync(Path.Combine(output,"style-a-preview.png"),CanvasBitmapFileFormat.Png);
            if(count!=132)throw new Exception("SVG asset count: "+count);
            Title="HeiBan 1.1.2 icon QA";
            await File.WriteAllTextAsync(Path.Combine(output,"result.json"),JsonSerializer.Serialize(new{success=true,screenChecks,svgIconsParsedAndDrawn=count,styleCacheSequence="duotone/classic/duotone",userPhysicalHoldPreviouslyAccepted=true,newStorePackage=false}));
            _ = ShowCustomizeToolbarDialog();
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"error.txt"),error.ToString());}
    }
}
#endif
