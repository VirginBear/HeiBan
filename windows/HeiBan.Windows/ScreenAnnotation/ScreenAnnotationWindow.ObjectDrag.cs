using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private bool _objectDragArmed;
    private ObjectDragPreview? _objectDrag;
    private ObjectDragRenderer? _objectDragRenderer;
    private ViewportTransform DragViewport(BoardObject item)=>_objectDrag is { } drag&&drag.IsMoving(item)
        ?new(){X=_viewport.X+drag.X*_viewport.Zoom,Y=_viewport.Y+drag.Y*_viewport.Zoom,Zoom=_viewport.Zoom}:_viewport;
    private bool HandleObjectDrag(NativeOverlayWindow.PointerEvent input,InkPoint point)
    {
        if(!_objectDragArmed||_start is null||input.Kind is not("move" or "up"))return false;
        if(_objectDrag is null&&Math.Max(Math.Abs(point.X-_start.X),Math.Abs(point.Y-_start.Y))<3*_dpiScale)
        {if(input.Kind=="move")return true;return false;}
        _selectionClickId=null;_objectDrag??=new(_session,_start);
        if(!_objectDrag.Current(_session)){CancelGesture();return true;}
        DamageSelectedObjects();_objectDrag.Move(point);DamageSelectedObjects();
        _committedDamage=_damage;_dirty=_committedDirty=true;
        if(input.Kind=="up")
        {
            _objectDrag.Commit(_session);ClearObjectDrag();_start=_last=null;_points.Clear();_manipulation=null;
            RefreshScreenStyleButtons();Changed();FocusScreenChrome();
        }
        return true;
    }
    private void ClearObjectDrag(){_objectDragArmed=false;_objectDrag=null;_objectDragRenderer?.Dispose();_objectDragRenderer=null;}
}
