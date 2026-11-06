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
        Check(_session.Generation==generation,"Construction preview changed permanent document");_preview=null;ResetGesture();
        var originalLength = SharedRulerLength;
        SetSharedRulerLength(480);
        _rulerCenter = new(420, 300);
        _rulerAngle = 27;
        foreach (var side in new[] { -1, 1 })
        {
            var fixedEnd = RulerPoint(-side * RulerLength / 2);
            var grip = RulerPoint(side * (RulerLength / 2 - 6));
            Check(RulerStretchSide(grip) == side, "Main ruler grip hit");
            var length = RulerLength;
            BeginRulerStretch(grip, side);
            StretchRuler(grip + RulerDirection() * (side * 72));
            Check(Math.Abs(RulerLength - length - 72) < .01, "Main ruler did not stretch");
            Check(System.Numerics.Vector2.Distance(fixedEnd, RulerPoint(-side * RulerLength / 2)) < .01, "Main opposite ruler end moved");
            ResetGesture();
        }
        Check(_session.Generation == generation, "Ruler resize changed the document");
        _rulerAngle = 0;
        SetSharedRulerLength(originalLength);
        return checks;
    }
}
#endif
