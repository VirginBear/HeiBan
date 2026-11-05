using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private InkPoint? _constructionPointer;
    private bool _constructionShift;
    private void UpdateScreenConstructionPreview(InkPoint point,bool shift)
    {
        if(_preview is null||_start is null)return;
        if(_tool is "line" or "arrow")ObjectHandles.SetEndpoints(_preview,_start,shift?ShapeConstruction.ConstrainLine(_start,point):point);
        else ShapeConstruction.Drag(_preview,_start,point,shift);
    }
    private void RefreshScreenShiftPreview()
    {
        // Overlay keyboard focus can stay in the control window. Poll only an
        // active construction preview, and redraw only on a modifier transition.
        if(!_drawing||_start is null||_preview is null||_constructionPointer is null||!IsMagnetDrawingTool(_tool))return;
        var shift=NativeOverlayWindow.ShiftDown;if(shift==_constructionShift)return;
        _constructionShift=shift;DamagePreview();UpdateScreenConstructionPreview(_constructionPointer,shift);DamagePreview();_dirty=true;
    }
}
