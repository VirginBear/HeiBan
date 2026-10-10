using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using global::Windows.Foundation;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private readonly Dictionary<string,Border> _floatingTools=[];
    private void ShowFloatingTool(string key,string title,FrameworkElement content,Action? closed=null)
    {
        if(_floatingTools.Remove(key,out var old))DrawingArea.Children.Remove(old);
        var body=new StackPanel{Spacing=8};
        var scroll=new ScrollViewer{Content=content,MaxHeight=Math.Max(180,DrawingArea.ActualHeight-120),VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
        var header=new Grid{Height=32,Background=Brush("#E8EFE6")};
        header.Children.Add(new TextBlock{Text="⋮⋮  "+title,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(8,0,80,0)});
        var buttons=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Right};
        var collapse=new Button{Content="−",Padding=new Thickness(8,2,8,2)};collapse.Click+=(_,_)=>scroll.Visibility=scroll.Visibility==Visibility.Visible?Visibility.Collapsed:Visibility.Visible;
        var close=new Button{Content="×",Padding=new Thickness(8,2,8,2)};buttons.Children.Add(collapse);buttons.Children.Add(close);header.Children.Add(buttons);body.Children.Add(header);body.Children.Add(scroll);
        var translation=new TranslateTransform{X=key=="timer"?360:32,Y=90};
        var panel=new Border{Child=body,Padding=new Thickness(8),CornerRadius=new CornerRadius(12),Background=Brush("#FCFCFA"),BorderBrush=Brush("#D4DBD1"),BorderThickness=new Thickness(1),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Top,RenderTransform=translation};
        var dragging=false;Point start=default;double sx=0,sy=0;
        header.PointerPressed+=(_,e)=>{if(e.OriginalSource is Button)return;var p=e.GetCurrentPoint(DrawingArea);start=p.Position;sx=translation.X;sy=translation.Y;dragging=true;header.CapturePointer(e.Pointer);e.Handled=true;};
        header.PointerMoved+=(_,e)=>{if(!dragging)return;var p=e.GetCurrentPoint(DrawingArea).Position;translation.X=Math.Clamp(sx+p.X-start.X,0,Math.Max(0,DrawingArea.ActualWidth-panel.ActualWidth));translation.Y=Math.Clamp(sy+p.Y-start.Y,0,Math.Max(0,DrawingArea.ActualHeight-40));e.Handled=true;};
        header.PointerReleased+=(_,e)=>{dragging=false;header.ReleasePointerCaptures();e.Handled=true;};header.PointerCanceled+=(_,_)=>dragging=false;
        close.Click+=(_,_)=>{DrawingArea.Children.Remove(panel);_floatingTools.Remove(key);closed?.Invoke();};
        DrawingArea.Children.Add(panel);_floatingTools[key]=panel;
    }
}
