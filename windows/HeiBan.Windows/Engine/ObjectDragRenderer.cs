using System.Numerics;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using global::Windows.UI;
namespace HeiBan.Windows.Engine;

/// <summary>Static paint runs stay at their original Z positions around the translating runs.</summary>
internal sealed class ObjectDragRenderer : IDisposable
{
    private sealed record Cached(ObjectDragPreview.Run Run,ICanvasImage? Image);
    private readonly List<Cached> _runs=[];
    private readonly long _bitmapBudget;
    internal ObjectDragRenderer(long bitmapBudget=64L*1024*1024)=>_bitmapBudget=Math.Clamp(bitmapBudget,0,64L*1024*1024);
    private (CanvasDevice Device,float Width,float Height,float Dpi,double X,double Y,double Zoom)? _key;
    internal int Builds {get;private set;}
    internal long BitmapBytes {get;private set;}
    internal void Draw(CanvasDrawingSession ds,ICanvasResourceCreatorWithDpi surface,Direct2DCanvasRenderer renderer,ObjectDragPreview preview,ViewportTransform viewport,float width,float height,Vector2 origin=default)
    {
        var key=(surface.Device,width,height,surface.Dpi,viewport.X,viewport.Y,viewport.Zoom);
        if(_key!=key)
        {
            Dispose();var pixels=Math.Ceiling(width*surface.Dpi/96)*Math.Ceiling(height*surface.Dpi/96);var bytes=pixels*4;
            try
            {
                foreach(var run in preview.Runs)
                {
                    ICanvasImage? image=null;
                    if(!run.Moving)
                    {
                        // A 4K image is expensive. Retain at most two raster runs and
                        // 64 MiB; fragmented selections use command lists for the rest.
                        if(_runs.Count(r=>r.Image is CanvasRenderTarget)<2&&bytes<=_bitmapBudget-BitmapBytes&&width*surface.Dpi/96<=surface.Device.MaximumBitmapSizeInPixels&&height*surface.Dpi/96<=surface.Device.MaximumBitmapSizeInPixels)
                        {
                            var bitmap=new CanvasRenderTarget(surface,width,height,surface.Dpi);image=bitmap;
                            try{using var drawing=bitmap.CreateDrawingSession();drawing.Clear(Color.FromArgb(0,0,0,0));renderer.RenderOrderedRun(drawing,run.Objects,viewport,width,height);}
                            catch{bitmap.Dispose();throw;}
                            BitmapBytes+=(long)bytes;
                        }
                        else
                        {
                            var commands=new CanvasCommandList(surface.Device);image=commands;
                            try{using var drawing=commands.CreateDrawingSession();renderer.RenderOrderedRun(drawing,run.Objects,viewport,width,height);}
                            catch{commands.Dispose();throw;}
                        }
                    }
                    _runs.Add(new(run,image));
                }
                _key=key;Builds++;
            }
            catch{Dispose();throw;}
        }
        var moved=new ViewportTransform{X=viewport.X+preview.X*viewport.Zoom+origin.X,Y=viewport.Y+preview.Y*viewport.Zoom+origin.Y,Zoom=viewport.Zoom};
        foreach(var run in _runs)
        {
            if(run.Image is { } image)ds.DrawImage(image,origin);
            else renderer.RenderOrderedRun(ds,run.Run.Objects,moved,width-origin.X,height-origin.Y);
        }
    }
    public void Dispose(){foreach(var run in _runs)run.Image?.Dispose();_runs.Clear();_key=null;BitmapBytes=0;}
}
