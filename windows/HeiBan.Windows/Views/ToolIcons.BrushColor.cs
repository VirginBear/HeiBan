using System.Globalization;
using System.Xml.Linq;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Markup;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Color=global::Windows.UI.Color;
namespace HeiBan.Windows.Views;

internal static partial class ToolIcons
{
    // The SVG generator reads these role colors. They are replaced only in the
    // two brush artworks, never in other icons or user drawings.
    internal const string BrushPrimary="#4D8B75",BrushLight="#C6E1D2",BrushDark="#335B4C";
    internal static bool IsBrushArtwork(string key)=>key is "pen" or "highlighter";
    private static Color Tone(string role,Color c)
    {
        byte Mix(byte v)=>role==BrushLight?(byte)Math.Round(v+(255-v)*.55):role==BrushDark?(byte)Math.Round(v*.72):v;
        return Color.FromArgb(c.A,Mix(c.R),Mix(c.G),Mix(c.B));
    }
    private static string ToneHex(string role,string color)
    {var c=Tone(role,Direct2DCanvasRenderer.HexToColor(color));return $"#{c.R:X2}{c.G:X2}{c.B:X2}";}
    internal static string BrushSvg(string key,string? color=null)
    {
        EnsureDuotone();var xml=DuotoneXml[ResolvedKey(key)];
        if(!IsBrushArtwork(key)||color is null)return xml;
        var root=XElement.Parse(xml);var alpha=Direct2DCanvasRenderer.HexToColor(color).A;
        foreach(var node in root.Elements())foreach(var paint in new[]{"fill","stroke"})
        {
            var attr=node.Attribute(paint);
            if(attr?.Value is not(BrushPrimary or BrushLight or BrushDark))continue;
            attr.Value=ToneHex(attr.Value,color);
            if(alpha<255)node.SetAttributeValue(paint+"-opacity",(alpha/255d).ToString(CultureInfo.InvariantCulture));
        }
        return root.ToString(SaveOptions.DisableFormatting);
    }
    internal static void UpdateBrushArtwork(UIElement? icon,string color)
    {if(icon is BrushArtwork artwork)artwork.SetColor(color);}
    private static async Task ColorMenuIconAsync(ImageIcon icon,string xml)
    {
        // Menu rows are created on demand, outside pointer drawing. Keep a usable
        // packaged fallback while their one-shot SVG source is decoded.
        try
        {
            using var stream=new global::Windows.Storage.Streams.InMemoryRandomAccessStream();
            using(var writer=new global::Windows.Storage.Streams.DataWriter(stream))
            {writer.WriteBytes(System.Text.Encoding.UTF8.GetBytes(xml));await writer.StoreAsync();writer.DetachStream();}
            stream.Seek(0);var source=new Microsoft.UI.Xaml.Media.Imaging.SvgImageSource();await source.SetSourceAsync(stream);icon.Source=source;
        }
        catch{ /* The packaged neutral artwork already remains on the row. */ }
    }

    // Both SVG and XAML use the same generated paths. Create geometry once;
    // color-picker changes update existing brushes, without rasterization,
    // asynchronous image loads, or a cache entry for every possible RGB value.
    private sealed class BrushArtwork : Grid
    {
        private readonly List<(SolidColorBrush Brush,string Role)> _tones=[];
        private string? _color;
        internal readonly Canvas Artwork=new(){Width=26,Height=26};
        internal BrushArtwork(string key,string color)
        {
            Width=Height=18;var canvas=Artwork;Children.Add(new Viewbox{Child=canvas});
            foreach(var node in XElement.Parse(BrushSvg(key)).Elements())
            {
                double Number(string name)=>double.Parse(node.Attribute(name)!.Value,CultureInfo.InvariantCulture);
                Shape shape;
                if(node.Name.LocalName=="path")shape=new Microsoft.UI.Xaml.Shapes.Path{Data=(Geometry)XamlReader.Load($"<Geometry xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>{node.Attribute("d")!.Value}</Geometry>"),StrokeStartLineCap=PenLineCap.Round,StrokeEndLineCap=PenLineCap.Round,StrokeLineJoin=PenLineJoin.Round};
                else if(node.Name.LocalName=="circle")
                {var radius=Number("r");shape=new Ellipse{Width=radius*2,Height=radius*2};Canvas.SetLeft(shape,Number("cx")-radius);Canvas.SetTop(shape,Number("cy")-radius);}
                else throw new InvalidOperationException("Unsupported brush SVG element: "+node.Name);
                Brush? Paint(string name)
                {
                    var value=node.Attribute(name)?.Value;if(value is null or "none")return null;
                    var brush=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(value));
                    if(value is BrushPrimary or BrushLight or BrushDark)_tones.Add((brush,value));return brush;
                }
                shape.Fill=Paint("fill");shape.Stroke=Paint("stroke");shape.StrokeThickness=Number("stroke-width");canvas.Children.Add(shape);
#if HEIBAN_RELEASE_VALIDATION
                if(node.Attribute("fill")?.Value==BrushPrimary)shape.Tag="primary";
#endif
            }
            SetColor(color);
        }
        internal void SetColor(string color)
        {if(color==_color)return;_color=color;var c=Direct2DCanvasRenderer.HexToColor(color);foreach(var (brush,role) in _tones)brush.Color=Tone(role,c);}
    }
}
