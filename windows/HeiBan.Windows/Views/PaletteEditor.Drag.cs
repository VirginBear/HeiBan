using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using global::Windows.Foundation;

namespace HeiBan.Windows.Views;
internal sealed partial class PaletteEditor
{
    private readonly Canvas _dragLayer=new(){IsHitTestVisible=false};
    private readonly List<(Rect Bounds,int Index,Button Button)> _dropTargets=[];
    private Button? _pressedColor;
    private string? _dragColor;
    private Point _pressedAt;
    private Border? _dragPreview;
    private int _dropIndex=-1;
    private bool _dragging,_suppressClick;

    private void EnablePaletteDrag(Button button,string color)
    {
        // This is an in-panel reorder, not an OS data transfer. Handle already-
        // consumed Button pointer events so a short mouse drag starts immediately.
        button.AddHandler(PointerPressedEvent,new PointerEventHandler((_,e)=>
        {
            if(!_managing||_store.LoadFailed||!e.GetCurrentPoint(button).Properties.IsLeftButtonPressed)return;
            BeginPaletteDrag(button,color,e.GetCurrentPoint(_swatches).Position);
            button.CapturePointer(e.Pointer);
        }),true);
        button.AddHandler(PointerMovedEvent,new PointerEventHandler((_,e)=>
        {
            if(_pressedColor!=button||!e.GetCurrentPoint(button).Properties.IsLeftButtonPressed)return;
            if(MovePaletteDrag(e.GetCurrentPoint(_swatches).Position))e.Handled=true;
        }),true);
        button.AddHandler(PointerReleasedEvent,new PointerEventHandler((_,e)=>{if(_pressedColor==button){var dragged=_dragging;FinishDrag(true);if(dragged)e.Handled=true;}}),true);
        button.AddHandler(PointerCaptureLostEvent,new PointerEventHandler((_,e)=>
        {if(_pressedColor==button)FinishDrag(!e.GetCurrentPoint(button).Properties.IsLeftButtonPressed);}),true);
        button.AddHandler(PointerCanceledEvent,new PointerEventHandler((_,_)=>{if(_pressedColor==button)FinishDrag(false);}),true);
        button.KeyDown+=(_,e)=>{if(e.Key==global::Windows.System.VirtualKey.Escape){FinishDrag(false);e.Handled=true;}};
    }
    private void BeginPaletteDrag(Button button,string color,Point point)
    {_pressedColor=button;_dragColor=color;_pressedAt=point;}
    private bool MovePaletteDrag(Point p)
    {
        if(_pressedColor is not { } button)return false;
            if(!_dragging)
            {
                if(Math.Abs(p.X-_pressedAt.X)+Math.Abs(p.Y-_pressedAt.Y)<6)return false;
                _dragging=_suppressClick=true;_dropTargets.Clear();
                var index=0;
                foreach(var cell in _swatches.Children.OfType<StackPanel>())
                {
                    var at=cell.TransformToVisual(_swatches).TransformPoint(new Point());
                    if(cell.Children[0] is Button target)_dropTargets.Add((new Rect(at.X,at.Y,cell.ActualWidth,cell.ActualHeight),index++,target));
                }
                _dragPreview=new Border{Width=32,Height=32,CornerRadius=new CornerRadius(16),Opacity=.9,Background=new SolidColorBrush(Microsoft.UI.Colors.White),BorderBrush=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#39735A")),BorderThickness=new Thickness(2),Child=Chip(_dragColor!)};
                _dragLayer.Children.Add(_dragPreview);button.Opacity=.4;
            }
            Canvas.SetLeft(_dragPreview!,p.X-16);Canvas.SetTop(_dragPreview!,p.Y-16);
            _dropIndex=-1;RefreshSelection();
            foreach(var target in _dropTargets)
                if(target.Bounds.Contains(p)){_dropIndex=target.Index;target.Button.BorderThickness=new Thickness(3);break;}
            return true;
    }
    private async void FinishDrag(bool commit)
    {
        if(_pressedColor is not { } button)return;
        var color=_dragColor;var destination=_dropIndex;var apply=commit&&_dragging&&color is not null&&destination>=0;
        _pressedColor=null;_dragColor=null;_dragging=false;_dropIndex=-1;
        _dragLayer.Children.Clear();_dragPreview=null;button.Opacity=1;button.ReleasePointerCaptures();RefreshSelection();
        DispatcherQueue.TryEnqueue(()=>_suppressClick=false);
        if(apply)await Persist(async()=>{await _store.MoveAsync(color!,destination);});
    }
}
