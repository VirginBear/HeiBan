using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
namespace HeiBan.Windows.Views;

internal static partial class ToolbarUi
{
    internal sealed record BrushControls(ColorPicker Color,Slider Width,Slider Opacity);
    internal static ColorPicker CreateColorWheel(string color,double width=260)=>new()
    {Color=Direct2DCanvasRenderer.HexToColor(color),Width=width,ColorSpectrumShape=ColorSpectrumShape.Ring,
     IsHexInputVisible=true,IsColorChannelTextInputVisible=false,IsAlphaEnabled=true,IsAlphaSliderVisible=true,IsAlphaTextInputVisible=true};

    // Values are logical canvas units. The screen host alone converts physical
    // overlay pixels at its callbacks; neither host creates a second color state.
    internal static BrushControls AddBrushControls(StackPanel panel,PalettePreferencesStore palette,string color,double width,double opacity,double pickerWidth=260,bool showWidth=true)
    {
        var wheel=CreateColorWheel(color,pickerWidth);
        panel.Children.Add(new PaletteEditor(palette,()=>$"#{wheel.Color.R:X2}{wheel.Color.G:X2}{wheel.Color.B:X2}{wheel.Color.A:X2}",c=>wheel.Color=Direct2DCanvasRenderer.HexToColor(c),wheel));
        panel.Children.Add(wheel);
        var stroke=BrushSlider(T("線條粗細（pt）"),.5,128,width,.5);
        if(showWidth)panel.Children.Add(stroke);
        var alpha=BrushSlider(T("筆畫透明度"),0,1,opacity,.01);panel.Children.Add(alpha);
        return new(wheel,stroke,alpha);
    }
    private static Slider BrushSlider(string label,double min,double max,double value,double step)
    {
        var slider=new Slider{Header=label,Minimum=min,Maximum=max,Value=Math.Clamp(value,min,max),StepFrequency=step,HorizontalAlignment=HorizontalAlignment.Stretch};
        var accent=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#558771"));
        foreach(var key in new[]{"SliderThumbBackground","SliderThumbBackgroundPointerOver","SliderThumbBackgroundPressed","SliderTrackValueFill","SliderTrackValueFillPointerOver","SliderTrackValueFillPressed","AccentFillColorDefaultBrush","SystemControlHighlightAccentBrush"})slider.Resources[key]=accent;
        AutomationProperties.SetName(slider,label);return slider;
    }
}
