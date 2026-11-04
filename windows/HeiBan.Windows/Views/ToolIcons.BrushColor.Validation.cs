#if HEIBAN_RELEASE_VALIDATION
using System.Xml.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using HeiBan.Windows.Engine;
using Color=global::Windows.UI.Color;
namespace HeiBan.Windows.Views;
internal static partial class ToolIcons
{
    internal static Color? ValidatePrimaryColor(UIElement? element)
    {
        if(element is not BrushArtwork artwork)return null;
        foreach(var shape in artwork.Artwork.Children.OfType<Microsoft.UI.Xaml.Shapes.Shape>())
            if(shape.Tag as string=="primary"&&shape.Fill is SolidColorBrush fill)return fill.Color;
        return null;
    }
    internal static int ValidateBrushColorArtwork()
    {
        var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        foreach(var key in new[]{"pen","highlighter"})
        {
            var icon=Create(key,"duotone");var original=((BrushArtwork)icon).Artwork;
            foreach(var color in new[]{"#FFD400","#3B82F6",BrushLight,BrushDark,"#00FF0080","#00000000"})
            {
                var expected=Direct2DCanvasRenderer.HexToColor(color);UpdateBrushArtwork(icon,color);
                Check(ValidatePrimaryColor(icon)==expected,"XAML brush fill mismatch for "+key+color);
                Check(ReferenceEquals(original,((BrushArtwork)icon).Artwork),"Color update rebuilt brush geometry");
                var svg=XElement.Parse(BrushSvg(key,color));
                var fill=svg.Elements().First(e=>e.Attribute("fill")?.Value is not(null or "none")).Attribute("fill")!.Value;
                Check(fill==$"#{expected.R:X2}{expected.G:X2}{expected.B:X2}","SVG primary fill changed during role replacement");
            }
        }
        return checks;
    }
}
internal static partial class ToolbarUi
{
    internal static (Color? Primary,double Underline) ValidateToolColor(Button button)
    {
        var icon=button.Content is StackPanel{Tag:"toolbar-label"} panel?panel.Children[0]:button.Content;
        if(icon is not ColorIcon color)return(null,0);
        return(ToolIcons.ValidatePrimaryColor(color.Icon.Content as UIElement),color.Children.OfType<Border>().Single().Opacity);
    }
}
#endif
