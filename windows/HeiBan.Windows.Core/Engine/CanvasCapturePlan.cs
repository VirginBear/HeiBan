using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

public sealed record CanvasCapturePlan(ExportArea Area,int PixelWidth,int PixelHeight,double Scale)
{
    public static ExportArea? WholePage(BoardMetadata board)=>board.CanvasMode is "fixed" or "notebook"
        ?new(0,0,board.CanvasWidth??595,board.CanvasHeight??842):null;
    public static ExportArea? Drag(InkPoint start,InkPoint end,double zoom)
    {
        if(!double.IsFinite(zoom)||zoom<=0)return null;
        var width=Math.Abs(end.X-start.X);var height=Math.Abs(end.Y-start.Y);
        if(width*zoom<3||height*zoom<3)return null;
        return new(Math.Min(start.X,end.X),Math.Min(start.Y,end.Y),width,height);
    }
    public static CanvasCapturePlan Create(ExportArea area,int maximumDimension,long maximumPixels=40_000_000)
    {
        if(!double.IsFinite(area.X)||!double.IsFinite(area.Y)||!double.IsFinite(area.Width)||!double.IsFinite(area.Height)||area.Width<=0||area.Height<=0||maximumDimension<1||maximumPixels<1)
            throw new ArgumentOutOfRangeException(nameof(area));
        // Render at two pixels per document unit, independent of the current zoom.
        // Limit the actual allocation by both GPU dimensions and total pixel count.
        maximumDimension=(int)Math.Min(maximumDimension,maximumPixels);
        var scale=Math.Min(2,Math.Min(maximumDimension/area.Width,maximumDimension/area.Height));
        scale=Math.Min(scale,Math.Sqrt(maximumPixels/area.Width/area.Height));
        if(!double.IsFinite(scale)||scale<=0)throw new ArgumentOutOfRangeException(nameof(area));
        var width=Math.Clamp((int)Math.Floor(area.Width*scale),1,maximumDimension);
        var height=Math.Clamp((int)Math.Floor(area.Height*scale),1,maximumDimension);
        return new(area,width,height,scale);
    }
}
