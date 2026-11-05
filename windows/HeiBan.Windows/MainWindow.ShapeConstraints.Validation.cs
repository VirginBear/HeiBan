#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task<int> ValidateMainShapeConstraintsAsync(string output)
    {
        var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        var generation=_session.Generation;_shapeGesture=true;_start=new(170,180);
        using var target=new CanvasRenderTarget(CanvasSurface,1100,480,96);
        using(var ds=target.CreateDrawingSession())
        {
            ds.Clear(Microsoft.UI.Colors.WhiteSmoke);var index=0;
            foreach(var type in new[]{"line","arrow","rect","circle","triangle","quadrilateral","diamond","pentagon","star"})
            {
                _tool=type;_preview=Styled(new(){Type=type});UpdateShapePreview(new(255,228),true);
                Check(type=="triangle"?_preview.ParsedPoints.Count==3:Math.Abs(_preview.Width-_preview.Height)<.001,"Main regular preview: "+type);
                _renderer.RenderObjects(ds,[_preview],new ViewportTransform{X=index%5*210+30-170*.65,Y=index/5*230+85-180*.65,Zoom=.65},1100,480);index++;
            }
        }
        await target.SaveAsync(Path.Combine(output,"shift-shapes.png"),CanvasBitmapFileFormat.Png);
        _tool="rect";_preview=Styled(new(){Type="rect"});UpdateShapePreview(new(255,228),false);
        Check(Math.Abs(_preview.Width-_preview.Height)>1,"Releasing Shift kept square constraint");
        Check(_session.Generation==generation,"Construction preview changed permanent document");_preview=null;ResetGesture();return checks;
    }
}
#endif
