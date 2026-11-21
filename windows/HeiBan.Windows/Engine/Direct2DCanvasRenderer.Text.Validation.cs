#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
namespace HeiBan.Windows.Engine;
public sealed partial class Direct2DCanvasRenderer
{
    internal static void ValidateTextRibbonLayout()
    {
        using var renderer=new Direct2DCanvasRenderer();
        using var target=new CanvasRenderTarget(CanvasDevice.GetSharedDevice(),400,400,96);
        using var ds=target.CreateDrawingSession();
        var item=new BoardObject{Type="text",Width=300,Height=300,Text="中文測試",FontSize=24,TextDirection="vertical-rl"};
        renderer.RenderPreview(ds,item,new(),400,400);
        var layout=renderer._textLayouts[item.Id].Layout;
        var first=layout.GetCharacterRegions(0,1)[0].LayoutBounds;
        var second=layout.GetCharacterRegions(1,1)[0].LayoutBounds;
        if(second.Y<=first.Y||Math.Abs(second.X-first.X)>1)throw new InvalidOperationException("Vertical text must run down a column.");
        item.TextVerticalAlignment="bottom";renderer.RenderPreview(ds,item,new(),400,400);
        var verticalBottom=renderer._textLayouts[item.Id].Layout.GetCharacterRegions(0,1)[0].LayoutBounds;
        if(verticalBottom.Y<=first.Y+100)throw new InvalidOperationException("Vertical writing bottom alignment must move down, not sideways.");
        item.Align="right";renderer.RenderPreview(ds,item,new(),400,400);
        var verticalRight=renderer._textLayouts[item.Id].Layout.GetCharacterRegions(0,1)[0].LayoutBounds;
        if(verticalRight.X<=verticalBottom.X+100)throw new InvalidOperationException("Vertical writing right alignment must move right.");
        item.Align="left";
        item.TextDirection="horizontal-tb";item.TextVerticalAlignment="top";
        renderer.RenderPreview(ds,item,new(),400,400);
        var top=renderer._textLayouts[item.Id].Layout.GetCharacterRegions(0,1)[0].LayoutBounds.Y;
        item.TextVerticalAlignment="bottom";renderer.RenderPreview(ds,item,new(),400,400);
        var bottom=renderer._textLayouts[item.Id].Layout.GetCharacterRegions(0,1)[0].LayoutBounds.Y;
        if(bottom<=top+100)throw new InvalidOperationException("Block alignment was not applied to the text layout.");
        var builds=renderer.TextLayoutBuilds;renderer.RenderPreview(ds,item,new(),400,400);
        if(renderer.TextLayoutBuilds!=builds)throw new InvalidOperationException("Unchanged text must reuse its native layout.");
    }
}
#endif
