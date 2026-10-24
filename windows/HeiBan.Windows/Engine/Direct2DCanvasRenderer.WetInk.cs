using System.Numerics;
using HeiBan.Windows.Models;
using HeiBan.Windows.Diagnostics;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Text;
using global::Windows.Foundation;
using global::Windows.UI;

namespace HeiBan.Windows.Engine;

public sealed partial class Direct2DCanvasRenderer
{
    private static readonly int SolidWetBatch=ReadSolidWetBatch();
    private static int ReadSolidWetBatch()=>int.TryParse(Environment.GetEnvironmentVariable("HEIBAN_WET_BATCH"),out var size)&&size>=1&&size<=64?size:16;
    private CanvasRenderTarget? _wetRaster;
    private readonly record struct WetView(double X,double Y,double Zoom,double Width,double Height,float Dpi,string Color,double StrokeWidth,string LineStyle);
    private WetView _wetView;
    private InkPoint? _wetFirst;
    private int _wetStableEnd,_wetCount;
    private CanvasGeometry? _wetTail;
    private int _wetTailCount;
    private BoardObject? _completedWetInk;
    private IReadOnlyList<InkPoint>? _completedWetPoints;
    private void ClearWetTail(){_wetTail?.Dispose();_wetTail=null;_wetTailCount=0;}
    private double _wetMinX,_wetMinY,_wetMaxX,_wetMaxY,_wetMaxStep;
    private readonly Dictionary<string,(string Name,CanvasTextLayout Layout)> _pinLabels=[];

    private void ClearWetResources()
    {
        _wetRaster?.Dispose();_wetRaster=null;_wetFirst=null;_completedWetInk=null;_completedWetPoints=null;
        ClearWetTail();
        foreach(var entry in _pinLabels.Values)entry.Layout.Dispose();_pinLabels.Clear();
    }

    public void RenderPinLabel(CanvasDrawingSession ds,BoardPin pin,Vector2 point)
    {
        if(!_pinLabels.TryGetValue(pin.Id,out var entry)||entry.Name!=pin.Name)
        {
            entry.Layout?.Dispose();
            _pinLabels.Remove(pin.Id);
            // Bounded UI-only labels: offscreen pins are culled by the host.
            if(_pinLabels.Count>=256){foreach(var value in _pinLabels.Values)value.Layout.Dispose();_pinLabels.Clear();}
            using var format=new CanvasTextFormat{FontSize=14};
            entry=(pin.Name,new CanvasTextLayout(ds,pin.Name,format,Math.Max(32,pin.Name.Length*18),40));
            _pinLabels[pin.Id]=entry;
        }
        DrawPin(ds,point,.9f,pin.Color);
        ds.DrawTextLayout(entry.Layout,point+new Vector2(16,0),HexToColor(pin.TextColor??"#397056"));
    }

    /// <summary>
    /// Rasterize only newly stable cubic segments. Keep the last segment live
    /// because its next control point can still change. One viewport-sized GPU
    /// target is reused between strokes; it never enters document/undo data.
    /// Solid ink appends small batches to avoid an offscreen drawing-session
    /// flush for every mouse sample. Dashed ink retains 64-segment boundaries, but
    /// no longer replays every old block each frame.
    /// </summary>
    public void RenderWetInk(CanvasDrawingSession ds,IReadOnlyList<InkPoint> points,ViewportTransform vp,
        string color,double width,double opacity,string lineStyle,Size surfaceSize)
    {
        using var trace=InputLatencyTrace.Measure(InputStage.WetInkRender);
        InputPresentationTrace.SetWetBatch(SolidWetBatch);
        if(points.Count<3||surfaceSize.Width<=0||surfaceSize.Height<=0)
        {_wetFirst=null;RenderLiveStroke(ds,points,vp,color,width,opacity,lineStyle);return;}
        var key=new WetView(vp.X,vp.Y,vp.Zoom,surfaceSize.Width,surfaceSize.Height,ds.Dpi,color,width,lineStyle);
        var resized=_wetRaster is null||_wetView.Width!=key.Width||_wetView.Height!=key.Height||_wetView.Dpi!=key.Dpi;
        if(resized)
        {
            _wetRaster?.Dispose();_wetRaster=new CanvasRenderTarget(ds,(float)key.Width,(float)key.Height,key.Dpi);
        }
        var reset=resized||_wetView!=key||!ReferenceEquals(_wetFirst,points[0])||points.Count<_wetCount;
        var view=Matrix3x2.CreateScale((float)vp.Zoom)*Matrix3x2.CreateTranslation((float)vp.X,(float)vp.Y);
        var ink=HexToColor(color);var alpha=(float)(Math.Clamp(opacity,0,1)*ink.A/255d);ink.A=255;
        if(reset)
        {
            ClearWetTail();
            _wetFirst=points[0];_wetStableEnd=_wetCount=0;
            _wetMaxStep=0;
            _wetMinX=_wetMaxX=points[0].X;_wetMinY=_wetMaxY=points[0].Y;
        }
        for(var i=_wetCount;i<points.Count;i++)
        {
            var p=points[i];_wetMinX=Math.Min(_wetMinX,p.X);_wetMaxX=Math.Max(_wetMaxX,p.X);
            _wetMinY=Math.Min(_wetMinY,p.Y);_wetMaxY=Math.Max(_wetMaxY,p.Y);
            if(i>0)_wetMaxStep=Math.Max(_wetMaxStep,Math.Max(Math.Abs(p.X-points[i-1].X),Math.Abs(p.Y-points[i-1].Y)));
        }
        _wetCount=points.Count;_wetView=key;
        // Every received sample is visible in the bounded tail immediately;
        // batching only changes when older geometry enters the raster cache.
        // No points are withheld waiting for a batch. Dash phases stay at 64.
        var batchSize=lineStyle=="solid"?SolidWetBatch:64;
        var stableEnd=_wetStableEnd+Math.Max(0,(points.Count-2-_wetStableEnd)/batchSize)*batchSize;
        if(reset||stableEnd>_wetStableEnd)
        {
            using var appendTrace=InputLatencyTrace.Measure(InputStage.WetRasterAppend);
            using var target=_wetRaster!.CreateDrawingSession();
            if(reset)target.Clear(Color.FromArgb(0,0,0,0));
            target.Transform=view;
            if(stableEnd>_wetStableEnd)
            {
                if(lineStyle=="solid")
                {
                    using var segment=SegmentPath(target,points,_wetStableEnd+1,stableEnd);
                    target.DrawGeometry(segment,ink,(float)width,StrokeStyle(lineStyle));
                }
                else for(var start=_wetStableEnd+1;start<=stableEnd;start+=64)
                {
                    using var segment=SegmentPath(target,points,start,start+63);
                    target.DrawGeometry(segment,ink,(float)width,StrokeStyle(lineStyle));
                }
            }
            _wetStableEnd=stableEnd;
        }
        // Padding covers stroke caps plus cubic overshoot. Translucent ink is
        // composed once, so overlapping stable/tail pixels do not darken joins.
        var pad=(width+_wetMaxStep/3)*vp.Zoom+4;
        var left=Math.Max(0,_wetMinX*vp.Zoom+vp.X-pad);var top=Math.Max(0,_wetMinY*vp.Zoom+vp.Y-pad);
        var right=Math.Min(key.Width,_wetMaxX*vp.Zoom+vp.X+pad);var bottom=Math.Min(key.Height,_wetMaxY*vp.Zoom+vp.Y+pad);
        if(right<=left||bottom<=top)return;
        var old=ds.Transform;ds.Transform=Matrix3x2.Identity;
        try
        {
            using var layer=alpha<.99999f?ds.CreateLayer(alpha,new Rect(left,top,right-left,bottom-top)):null;
            var region=new Rect(left,top,right-left,bottom-top);
            ds.DrawImage(_wetRaster,new Vector2((float)left,(float)top),region);
            ds.Transform=view;
            if(_wetTail is null||_wetTailCount!=points.Count)
            {ClearWetTail();_wetTail=SegmentPath(ds,points,_wetStableEnd+1,points.Count-1);_wetTailCount=points.Count;}
            ds.DrawGeometry(_wetTail,ink,(float)width,StrokeStyle(lineStyle));
        }
        finally{ds.Transform=old;}
    }

    public void QueueCompletedWetInk(BoardObject item,IReadOnlyList<InkPoint> points)
    {
        // Keep at most the latest preview. Earlier queued strokes fall back to
        // vector rendering if several pen-ups arrive before the next Draw.
        _completedWetInk=item;_completedWetPoints=points;
    }
    public void RenderAppendedInk(CanvasDrawingSession ds,BoardObject item,ViewportTransform vp,float width,float height)
    {
        if(ReferenceEquals(item,_completedWetInk)&&_completedWetPoints is { } points&&
            item.Type is "stroke" or "pen" or "highlighter" or "paint"&&item.LineStyle=="solid"&&item.Rotation==0&&item.IsVisible!=false)
        {
            RenderWetInk(ds,points,vp,item.StrokeColor,item.StrokeWidth,item.Opacity,item.LineStyle,new Size(width,height));
            DiscardCompletedWetInk();
        }
        else RenderPreview(ds,item,vp,width,height);
    }
    public void DiscardCompletedWetInk(){_completedWetInk=null;_completedWetPoints=null;}
}
