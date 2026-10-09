using HeiBan.Windows.Engine;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Numerics;
namespace HeiBan.Windows.Views;
/// <summary>The button, navigation list and canvas all draw the same original pin.</summary>
public sealed class PinIcon : UserControl
{
    public PinIcon()
    {
        Width=24;Height=24;
        var canvas=new CanvasControl();
        canvas.Draw+=(_,e)=>Direct2DCanvasRenderer.DrawPin(e.DrawingSession,new Vector2(12,9),.65f);
        Content=canvas;
        Unloaded+=(_,_)=>canvas.RemoveFromVisualTree();
    }
}
