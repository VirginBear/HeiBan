using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using global::Windows.Foundation;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private void DamageSelectedObjects()
    {
        foreach(var o in _session.SelectedObjects)
        {
            if(o.Extension is "start" or "end" or "both"){_fullDamage=true;continue;}
            var corners=ObjectHandles.Outline(o);var pad=Math.Max(40*_dpiScale,o.StrokeWidth+(o.ArrowHeadLength??0));
            // Catmull-Rom curves can extend beyond point bounds; include their control hull after rotation.
            if(o.Type is "stroke" or "pen" or "highlighter" or "paint" or "curve")pad+=Math.Sqrt(o.Width*o.Width+o.Height*o.Height)/3;
            var left=Math.Max(0,Math.Floor(corners.Min(p=>p.X)-pad));var top=Math.Max(0,Math.Floor(corners.Min(p=>p.Y)-pad));
            var right=Math.Min(_overlay.Width,Math.Ceiling(corners.Max(p=>p.X)+pad));var bottom=Math.Min(_overlay.Height,Math.Ceiling(corners.Max(p=>p.Y)+pad));
            if(right<=left||bottom<=top)continue;
            AddScreenDamage(new(left,top,right-left,bottom-top));
        }
    }
    private void DamagePreview()
    {
        if(_preview is null)return;var corners=ObjectHandles.Outline(_preview);var pad=_preview.StrokeWidth+40*_dpiScale;
        var left=Math.Max(0,Math.Floor(corners.Min(p=>p.X)-pad));var top=Math.Max(0,Math.Floor(corners.Min(p=>p.Y)-pad));
        var right=Math.Min(_overlay.Width,Math.Ceiling(corners.Max(p=>p.X)+pad));var bottom=Math.Min(_overlay.Height,Math.Ceiling(corners.Max(p=>p.Y)+pad));
        if(right>left&&bottom>top)AddScreenDamage(new(left,top,right-left,bottom-top));
    }
    private Rect? _committedDamage;
    private void AddScreenDamage(Rect rectangle)
    {
        var left=Math.Max(0,Math.Floor(rectangle.Left));var top=Math.Max(0,Math.Floor(rectangle.Top));
        var right=Math.Min(_overlay.Width,Math.Ceiling(rectangle.Right));var bottom=Math.Min(_overlay.Height,Math.Ceiling(rectangle.Bottom));
        if(right<=left||bottom<=top)return;
        if(_damage is { } old){left=Math.Min(left,old.Left);top=Math.Min(top,old.Top);right=Math.Max(right,old.Right);bottom=Math.Max(bottom,old.Bottom);}
        _damage=new(left,top,right-left,bottom-top);
    }
    private void MarkEraserDamage(VectorMath.RectBounds? bounds,bool full)
    {
        if(full||bounds is null){_dirty=_fullDamage=_committedDirty=true;_committedDamage=null;return;}
        // Screen geometry is physical pixels. Include decoration and antialiasing.
        var b=bounds.Value;var pad=32*_dpiScale;
        var left=Math.Max(0,Math.Floor(b.MinX-pad));var top=Math.Max(0,Math.Floor(b.MinY-pad));
        var right=Math.Min(_overlay.Width,Math.Ceiling(b.MaxX+pad));var bottom=Math.Min(_overlay.Height,Math.Ceiling(b.MaxY+pad));
        if(right<=left||bottom<=top)return;var region=new Rect(left,top,right-left,bottom-top);
        if(!_committedDirty)_committedDamage=region;
        else if(_committedDamage is { } old){left=Math.Min(left,old.Left);top=Math.Min(top,old.Top);_committedDamage=new(left,top,Math.Max(right,old.Right)-left,Math.Max(bottom,old.Bottom)-top);}
        _dirty=_committedDirty=true;AddScreenDamage(region);
    }
    private CanvasRenderTarget? _eraserPatch;
    private int _eraserPatchWidth,_eraserPatchHeight;
    private readonly ViewportTransform _eraserPatchView=new();
    private void DisposeEraserPatch(){_eraserPatch?.Dispose();_eraserPatch=null;_eraserPatchWidth=_eraserPatchHeight=0;_committedDamage=null;}
    private void RebuildCommitted(EditorSession sceneSession,global::Windows.UI.Color blank)
    {
        _renderer.Prune(sceneSession.Document.Objects);
        if(!_fullDamage&&_committedDamage is { } region)
        {
            var width=(int)region.Width;var height=(int)region.Height;
            if(_eraserPatch is null||width>_eraserPatchWidth||height>_eraserPatchHeight)
            {
                _eraserPatchWidth=Math.Min(_overlay.Width,Math.Max(width,Math.Max(256,_eraserPatchWidth*2)));
                _eraserPatchHeight=Math.Min(_overlay.Height,Math.Max(height,Math.Max(256,_eraserPatchHeight*2)));
                _eraserPatch?.Dispose();_eraserPatch=new CanvasRenderTarget(_committed!,_eraserPatchWidth,_eraserPatchHeight,96);
            }
            // Clear a separate reusable GPU surface, then copy its exact pixels. A
            // transparent fill inside an opacity layer cannot reliably erase old pixels.
            _eraserPatchView.X=_viewport.X-region.X;_eraserPatchView.Y=_viewport.Y-region.Y;_eraserPatchView.Zoom=_viewport.Zoom;
            using(var ds=_eraserPatch.CreateDrawingSession()){ds.Clear(blank);_renderer.RenderObjects(ds,sceneSession.DrawingObjects,_eraserPatchView,width,height);}
            _committed!.CopyPixelsFromBitmap(_eraserPatch,(int)region.X,(int)region.Y,0,0,width,height);
        }
        else{using var ds=_committed!.CreateDrawingSession();ds.Clear(blank);_renderer.RenderObjects(ds,sceneSession.DrawingObjects,_viewport,_overlay.Width,_overlay.Height);}
        _committedDamage=null;_committedDirty=false;_committedBuilds++;
    }
}
