#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using System.Runtime.InteropServices.WindowsRuntime;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task<int> ValidateFlipAndLaserAsync()
    {
        var checks=0;
        void Check(bool condition,string message){if(!condition)throw new InvalidOperationException(message);checks++;}
        using var source=new CanvasRenderTarget(CanvasSurface,60,60,96);
        using(var ds=source.CreateDrawingSession())
        {
            ds.Clear(Microsoft.UI.Colors.Blue);
            ds.FillRectangle(0,0,30,30,Microsoft.UI.Colors.Red);
        }
        using var stream=new MemoryStream();
        await source.SaveAsync(stream.AsRandomAccessStream(),CanvasBitmapFileFormat.Png);
        var image=new BoardObject{Type="image",X=20,Y=20,Width=60,Height=60,ImageUrl="data:image/png;base64,"+Convert.ToBase64String(stream.ToArray())};
        await _renderer.LoadImagesAsync(CanvasSurface,[image]);
        using var output=new CanvasRenderTarget(CanvasSurface,320,240,96);
        bool IsRed(int x,int y)
        {
            var pixel=output.GetPixelBytes(x,y,1,1);
            return pixel[2]>245&&pixel[1]<12&&pixel[0]<12;
        }
        void DrawImage()
        {
            using var ds=output.CreateDrawingSession();
            ds.Clear(Microsoft.UI.Colors.White);
            _renderer.RenderObjects(ds,[image],new ViewportTransform(),320,240);
        }
        DrawImage();Check(IsRed(35,35),"Synthetic image source did not render");
        image.FlipX=true;DrawImage();Check(IsRed(65,35)&&!IsRed(35,35),"Canvas bitmap did not flip horizontally");
        image.FlipY=true;DrawImage();Check(IsRed(65,65)&&!IsRed(65,35),"Canvas bitmap did not flip vertically");

        var laserColor=_laser.Color;var whiteCore=_laser.WhiteCore;
        try
        {
            foreach(var mode in new[]{"fixed","notebook"})
            {
                var board=new BoardMetadata{Title=mode,CanvasMode=mode,CanvasWidth=80,CanvasHeight=80,BackgroundColor="#FFFFFF",GridStyle="blank"};
                await OpenAsync(new(){Board=board});
                _viewport.X=_viewport.Y=10;_viewport.Zoom=1;
                var generation=_session.Generation;
                _laser.Color="#FF0000";_laser.WhiteCore=false;
                _laser.Press(_viewport.ScreenToWorld(180,150),LaserNow);
                using(var ds=output.CreateDrawingSession()){ds.Clear(Microsoft.UI.Colors.Transparent);CanvasSurface_Draw(CanvasSurface,ds);}
                Check(IsRed(180,150),$"{mode}: the laser outside paper was clipped");
                _laser.Release();
                using(var ds=output.CreateDrawingSession()){ds.Clear(Microsoft.UI.Colors.Transparent);CanvasSurface_Draw(CanvasSurface,ds);}
                Check(!IsRed(180,150)&&_session.Generation==generation,$"{mode}: laser survived release or changed the document");
            }
        }
        finally{_laser.Clear();_laser.Color=laserColor;_laser.WhiteCore=whiteCore;}
        return checks;
    }
}
#endif
