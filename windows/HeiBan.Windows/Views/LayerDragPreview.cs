using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using global::Windows.Foundation;

namespace HeiBan.Windows.Views;

// A separate XAML overlay follows the pointer without changing object Z or rebinding rows.
// A reorder is committed only by the caller on release; cancellation restores row opacity.
internal sealed class LayerDragPreview
{
    private readonly ListView _list;
    private readonly Canvas _overlay;
    private readonly Border _ghost,_line;
    private ListViewItem? _source;
    private double _sourceOpacity;
    internal LayerDragPreview(ListView list,Canvas overlay)
    {
        _list=list;_overlay=overlay;
        var green=new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255,57,115,90));
        _ghost=new Border{Background=new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(245,235,245,237)),BorderBrush=green,BorderThickness=new Thickness(1),CornerRadius=new CornerRadius(8),Padding=new Thickness(8),Opacity=.95};
        _line=new Border{Height=3,Background=green,CornerRadius=new CornerRadius(2)};
    }
    internal void Begin(LayerCard card,Point pointer)
    {
        End();
        _source=_list.ContainerFromItem(card) as ListViewItem;
        if(_source is not null){_sourceOpacity=_source.Opacity;_source.Opacity=.3;}
        _ghost.Child=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8,Children={ToolIcons.Create(card.Entry.IconKey),new TextBlock{Text=card.Title,MaxWidth=Math.Max(20,_list.ActualWidth-70),TextTrimming=TextTrimming.CharacterEllipsis,VerticalAlignment=VerticalAlignment.Center}}};
        _ghost.Width=Math.Max(80,_list.ActualWidth-12);_overlay.Children.Add(_line);_overlay.Children.Add(_ghost);
        Move(pointer);
    }
    internal void Move(Point pointer)
    {
        if(_overlay.Children.Count==0)return;
        var origin=_list.TransformToVisual(_overlay).TransformPoint(new Point());
        Canvas.SetLeft(_ghost,origin.X+6);Canvas.SetTop(_ghost,origin.Y+Math.Clamp(pointer.Y-18,0,Math.Max(0,_list.ActualHeight-40)));
        var target=LayerDragTarget.Find(_list,pointer);
        if(target.Item is null||_list.ContainerFromItem(target.Item) is not ListViewItem row){_line.Visibility=Visibility.Collapsed;return;}
        var bounds=row.TransformToVisual(_overlay).TransformPoint(new Point());
        _line.Visibility=Visibility.Visible;_line.Width=Math.Max(20,_list.ActualWidth-4);
        Canvas.SetLeft(_line,origin.X+2);Canvas.SetTop(_line,bounds.Y+(target.After?row.ActualHeight:0)-1);
    }
    internal void End()
    {
        _overlay.Children.Clear();if(_source is not null)_source.Opacity=_sourceOpacity;_source=null;_ghost.Child=null;
    }
}
