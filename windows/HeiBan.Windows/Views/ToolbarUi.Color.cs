using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace HeiBan.Windows.Views;

internal static partial class ToolbarUi
{
    internal static bool HasToolColor(string key)=>key is "pen" or "highlighter" or "paint" or "curve" or "shapes";
    private sealed class ColorIcon : Grid
    {
        internal readonly ContentPresenter Icon=new(){HorizontalAlignment=HorizontalAlignment.Center};
        private readonly Border _line = new() { HorizontalAlignment = HorizontalAlignment.Center, CornerRadius = new CornerRadius(1), IsHitTestVisible = false };
        private string? _color;
        internal ColorIcon(UIElement icon)
        {
            RowDefinitions.Add(new(){Height=GridLength.Auto});RowDefinitions.Add(new(){Height=GridLength.Auto});
            Icon.Content=icon;Children.Add(Icon);Grid.SetRow(_line,1);Children.Add(_line);
            SetScale(1);
        }

        internal void SetScale(double scale)
        {
            _line.Width = 22 * scale;
            _line.Height = 3 * scale;
            _line.Margin = new Thickness(0, 2 * scale, 0, 0);
            ScaleIcon(Icon.Content as UIElement, scale);
        }
        internal void SetColor(string color,bool active)
        {
            // Reserve the same icon height, but only the active tool paints a color line.
            _line.Opacity=active?1:0;
            if (!active || _color == color) return;
            _color = color;
            _line.Background = new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(color));
        }
    }
    internal static void SetToolColor(Button button,string key,string color,string activeTool)
    {
        if(!HasToolColor(key))return;
        var label=button.Content as StackPanel;
        if(label?.Tag as string!="toolbar-label")label=null;
        var icon=(label is null?button.Content:label.Children[0]) as UIElement;
        if(icon is null)return;
        if(icon is not ColorIcon indicator)
        {
            if(label is null)button.Content=null;else label.Children.RemoveAt(0);
            indicator=new ColorIcon(icon);
            indicator.SetScale(ButtonParents.GetValue(button, _ => new()).Scale);
            if(label is null)button.Content=indicator;else label.Children.Insert(0,indicator);
        }
        ToolIcons.UpdateBrushArtwork(indicator.Icon.Content as UIElement,color);
        indicator.SetColor(color,key==activeTool||(key=="shapes"&&ShapeTools.Any(shape=>shape.Key==activeTool)));
    }
}
