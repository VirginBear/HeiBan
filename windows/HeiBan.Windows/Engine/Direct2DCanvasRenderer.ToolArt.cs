using System.Numerics;
using Microsoft.Graphics.Canvas;
using global::Windows.Foundation;

namespace HeiBan.Windows.Engine;

public sealed partial class Direct2DCanvasRenderer
{
    private CanvasBitmap? _boardEraserArt;
    private long _toolArtEpoch;
    internal bool HasBoardEraserArt=>_boardEraserArt is not null;
    internal async Task LoadToolArtAsync(ICanvasResourceCreator device)
    {
        ClearToolArt();var epoch=_toolArtEpoch;
        try
        {
            // Portable apps have no package identity. Resolve the shipped asset
            // beside the executable and decode a stream in both distribution modes.
            using var stream=File.OpenRead(System.IO.Path.Combine(AppContext.BaseDirectory,"Assets","BoardEraser.png"));
            var bitmap=await CanvasBitmap.LoadAsync(device,stream.AsRandomAccessStream());
            if(epoch!=_toolArtEpoch){bitmap.Dispose();return;}
            _boardEraserArt=bitmap;ResourcesChanged?.Invoke();
        }
        catch(Exception e) when(e is not OutOfMemoryException)
        {
            // Optional artwork must never fault an unobserved startup task or
            // prevent the document surface from becoming ready. XAML is retained.
            Diagnostics.CanvasSurfaceDiagnostics.Record("optional-eraser-art",e);
        }
    }
    internal void RenderBoardEraser(CanvasDrawingSession ds,double left,double top,float opacity)
    {
        if(_boardEraserArt is not { } bitmap)return;
        var w=(float)BoardEraserGeometry.DisplayWidth;var h=(float)BoardEraserGeometry.DisplayHeight;
        var t=BoardEraserGeometry.ImageTransform;var old=ds.Transform;
        // Match the centered XAML transform and the physical contact footprint.
        // During dragging, the sprite shares the immediate ink presentation path.
        ds.Transform=Matrix3x2.CreateTranslation(-w/2,-h/2)*new Matrix3x2((float)t.M11,(float)t.M12,(float)t.M21,(float)t.M22,0,0)
            *Matrix3x2.CreateTranslation((float)left+w/2,(float)top+h/2)*old;
        try{ds.DrawImage(bitmap,new Rect(0,0,w,h),bitmap.Bounds,opacity);}
        finally{ds.Transform=old;}
    }
    private void ClearToolArt(){_toolArtEpoch++;_boardEraserArt?.Dispose();_boardEraserArt=null;}
}
