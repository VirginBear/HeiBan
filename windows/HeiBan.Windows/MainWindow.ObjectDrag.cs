using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Xaml.Input;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private bool _objectDragArmed;
    private ObjectDragPreview? _objectDrag;
    private ObjectDragRenderer? _objectDragRenderer;
    private ViewportTransform DragViewport(BoardObject item)=>_objectDrag is { } drag&&drag.IsMoving(item)
        ?new(){X=_viewport.X+drag.X*_viewport.Zoom,Y=_viewport.Y+drag.Y*_viewport.Zoom,Zoom=_viewport.Zoom}:_viewport;
    private bool MoveObjectDrag(PointerRoutedEventArgs e)
    {
        if(!_gesture||!_objectDragArmed||_start is null||e.Pointer.PointerId!=_pointerId)return false;
        var position=e.GetCurrentPoint(CanvasSurface).Position;var point=_viewport.ScreenToWorld(position.X,position.Y);
        if(_objectDrag is null&&Math.Max(Math.Abs(point.X-_start.X),Math.Abs(point.Y-_start.Y))*_viewport.Zoom<3){e.Handled=true;return true;}
        _selectionClickId=null;_objectDrag??=new(_session,_start);
        if(!_objectDrag.Current(_session)){CancelGesture();e.Handled=true;return true;}
        _objectDrag.Move(point);PresentInteraction();e.Handled=true;return true;
    }
    private void ClearObjectDrag(){_objectDragArmed=false;_objectDrag=null;_objectDragRenderer?.Dispose();_objectDragRenderer=null;}
}
