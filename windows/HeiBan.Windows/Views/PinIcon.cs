using HeiBan.Windows.Engine;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Numerics;
namespace HeiBan.Windows.Views;
/// <summary>The button, navigation list and canvas all draw the same original pin.</summary>
public sealed class PinIcon : UserControl
{
    public PinIcon(string? color=null)
    {
        Width=32;Height=32;
        var canvas=new CanvasControl();
        canvas.Draw+=(_,e)=>Direct2DCanvasRenderer.DrawPin(e.DrawingSession,new Vector2(16,12),.9f,color);
        Content=canvas;
        Unloaded+=(_,_)=>canvas.RemoveFromVisualTree();
    }
}
