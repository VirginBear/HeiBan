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
    internal sealed record FillControls(CheckBox Toggle, Slider Opacity);

    internal static ColorPicker CreateColorWheel(string color,double width=260)=>new()
    {
        Color=Direct2DCanvasRenderer.HexToColor(color),
        Width=width,
        ColorSpectrumShape=ColorSpectrumShape.Ring,
        IsHexInputVisible=true,
        IsColorChannelTextInputVisible=false,
        IsAlphaEnabled=true,
        IsAlphaSliderVisible=true,
        IsAlphaTextInputVisible=true
    };

    // Values are logical canvas units. The screen host alone converts physical
    // overlay pixels at its callbacks; neither host creates a second color state.
    internal static BrushControls AddBrushControls(StackPanel panel,PalettePreferencesStore palette,string color,double width,double opacity,double pickerWidth=300,bool showWidth=true)
    {
        var wheel=CreateColorWheel(color,pickerWidth);
        panel.Children.Add(new PaletteEditor(palette,()=>$"#{wheel.Color.R:X2}{wheel.Color.G:X2}{wheel.Color.B:X2}{wheel.Color.A:X2}",c=>wheel.Color=Direct2DCanvasRenderer.HexToColor(c),wheel));

        var wheelContainer=new StackPanel{Visibility=Visibility.Collapsed,Spacing=6,HorizontalAlignment=HorizontalAlignment.Center};
        wheelContainer.Children.Add(wheel);

        var toggleBtn=new Button
        {
            Content=T("▶ 進階色輪與色碼"),
            Padding=new Thickness(10,4,10,4),
            Margin=new Thickness(0,2,0,4),
            HorizontalAlignment=HorizontalAlignment.Left,
            FontSize=12
        };
        toggleBtn.Click+=(_,_)=>
        {
            var show=wheelContainer.Visibility!=Visibility.Visible;
            wheelContainer.Visibility=show?Visibility.Visible:Visibility.Collapsed;
            toggleBtn.Content=T(show?"▼ 收合色輪與色碼":"▶ 進階色輪與色碼");
        };
        panel.Children.Add(toggleBtn);
        panel.Children.Add(wheelContainer);

        var stroke=BrushSlider(T("線條粗細（pt）"),.5,128,width,.5);
        if(showWidth)
        {
            var presets=new StackPanel{Orientation=Orientation.Horizontal,Spacing=4,Margin=new Thickness(0,2,0,4)};
            foreach(var n in new[]{2d,3.5,6,10,18,32})
            {
                var b=new Button{Content=$"{n:0.#}",Padding=new Thickness(8,4,8,4),FontSize=12};
                b.Click+=(_,_)=>stroke.Value=n;
                presets.Children.Add(b);
            }
            panel.Children.Add(presets);
            panel.Children.Add(stroke);
        }
        var alpha=BrushSlider(T("筆畫透明度"),0,1,opacity,.01);
        panel.Children.Add(alpha);
        return new(wheel,stroke,alpha);
    }

    internal static Slider BrushSlider(string label,double min,double max,double value,double step)
    {
        var slider=new Slider{Header=label,Minimum=min,Maximum=max,Value=Math.Clamp(value,min,max),StepFrequency=step,HorizontalAlignment=HorizontalAlignment.Stretch};
        var accent=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#558771"));
        foreach(var key in new[]{"SliderThumbBackground","SliderThumbBackgroundPointerOver","SliderThumbBackgroundPressed","SliderTrackValueFill","SliderTrackValueFillPointerOver","SliderTrackValueFillPressed","AccentFillColorDefaultBrush","SystemControlHighlightAccentBrush"})slider.Resources[key]=accent;
        AutomationProperties.SetName(slider,label);return slider;
    }

    internal static ComboBox CreateDashComboBox(string currentDash,Action<string> onDashChanged)
    {
        var options=new[]{("solid","實線"),("dashed","虛線"),("dotted","點線"),("dashdot","點劃線")};
        var box=new ComboBox
        {
            Header=T("線條樣式"),
            ItemsSource=options.Select(p=>T(p.Item2)).ToList(),
            SelectedIndex=Math.Max(0,Array.FindIndex(options,p=>p.Item1==currentDash)),
            HorizontalAlignment=HorizontalAlignment.Stretch,
            Margin=new Thickness(0,2,0,4)
        };
        box.SelectionChanged+=(_,_)=>
        {
            if(box.SelectedIndex>=0&&box.SelectedIndex<options.Length)
                onDashChanged(options[box.SelectedIndex].Item1);
        };
        return box;
    }

    internal static FillControls AddFillControls(
        StackPanel panel,
        PalettePreferencesStore palette,
        bool isFilled,
        string fillColor,
        double fillOpacity,
        Action<bool> onToggleFilled,
        Action<string> onFillColorChanged,
        Action<double> onFillOpacityChanged,
        Action<string,string> onFillGradient,
        Action<FrameworkElement> onCustomColorClick)
    {
        var filled=new CheckBox{Content=T("填滿圖形"),IsChecked=isFilled,Margin=new Thickness(0,4,0,2)};
        panel.Children.Add(filled);

        var fillContainer=new StackPanel{Spacing=6,Margin=new Thickness(0,2,0,4)};
        var fillEditor=new PaletteEditor(palette,()=>fillColor,c=>{onFillColorChanged(c);filled.IsChecked=true;});
        fillContainer.Children.Add(fillEditor);

        var fillAlpha=BrushSlider(T("填色透明度"),0,1,fillOpacity,0.01);
        fillAlpha.ValueChanged+=(_,e)=>onFillOpacityChanged(e.NewValue);
        fillContainer.Children.Add(fillAlpha);

        var customBtn=new Button{Content=T("自訂填色與透明度"),HorizontalAlignment=HorizontalAlignment.Stretch,Margin=new Thickness(0,2,0,2)};
        customBtn.Click+=(_,_)=>onCustomColorClick(customBtn);
        fillContainer.Children.Add(customBtn);

        var gradientRow=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8,Margin=new Thickness(0,2,0,4)};
        var grad1=new Button{Content=T("自然綠漸層"),FontSize=12,Padding=new Thickness(8,4,8,4)};
        grad1.Click+=(_,_)=>{onFillGradient("#86EFAC","#3B82F6");filled.IsChecked=true;};
        var grad2=new Button{Content=T("晨曦橙漸層"),FontSize=12,Padding=new Thickness(8,4,8,4)};
        grad2.Click+=(_,_)=>{onFillGradient("#FED7AA","#F472B6");filled.IsChecked=true;};
        gradientRow.Children.Add(grad1);
        gradientRow.Children.Add(grad2);
        fillContainer.Children.Add(gradientRow);

        panel.Children.Add(fillContainer);

        void SyncFillVisibility()
        {
            fillContainer.Visibility=filled.IsChecked==true?Visibility.Visible:Visibility.Collapsed;
        }
        SyncFillVisibility();

        filled.Checked+=(_,_)=>{onToggleFilled(true);SyncFillVisibility();};
        filled.Unchecked+=(_,_)=>{onToggleFilled(false);SyncFillVisibility();};

        return new(filled,fillAlpha);
    }

    internal static Slider CreateRotationSlider(double rotation,Action<double> onRotationChanged)
    {
        var normalized=((rotation%360)+360)%360;
        var slider=BrushSlider(T("物件旋轉角度"),0,360,Math.Round(normalized,1),1);
        slider.ValueChanged+=(_,e)=>onRotationChanged(e.NewValue);
        return slider;
    }
}
