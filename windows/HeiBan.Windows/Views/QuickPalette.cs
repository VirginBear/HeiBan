using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;

namespace HeiBan.Windows.Views;

/// <summary>Six reusable buttons, projecting the shared ordered palette without another preference file.</summary>
internal sealed class QuickPalette : Grid,IDisposable
{
    private readonly PalettePreferencesStore _store;
    private readonly Func<string> _current;
    private readonly Action<string> _apply;
    private readonly Button[] _buttons=new Button[6];
    private readonly Ellipse[] _rings=new Ellipse[6];
    private readonly Ellipse[] _dots=new Ellipse[6];
    private bool _disposed;
    private double _scale = 1;
    private bool _enabled=true;
    internal void SetEnabled(bool value)
    {if(_enabled==value)return;_enabled=value;foreach(var button in _buttons)button.IsEnabled=value&&button.Tag is string;}
    internal QuickPalette(PalettePreferencesStore store,Func<string> current,Action<string> apply)
    {
        _store=store;_current=current;_apply=apply;
        RowSpacing=4;ColumnSpacing=4;FlowDirection=FlowDirection.LeftToRight;
        VerticalAlignment=VerticalAlignment.Center;Margin=new Thickness(3,0,6,0);
        for(var i=0;i<3;i++)ColumnDefinitions.Add(new(){Width=GridLength.Auto});
        for(var i=0;i<2;i++)RowDefinitions.Add(new(){Height=GridLength.Auto});
        for(var i=0;i<6;i++)
        {
            var button=new Button{Width=22,Height=22,MinWidth=0,MinHeight=0,Padding=new Thickness(0),BorderThickness=new Thickness(0),CornerRadius=new CornerRadius(11),Background=new SolidColorBrush(Microsoft.UI.Colors.Transparent),HorizontalContentAlignment=HorizontalAlignment.Center,VerticalContentAlignment=VerticalAlignment.Center};
            var ring=new Ellipse{Width=20,Height=20,Stroke=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#39735A"))};
            var dot=new Ellipse{Width=14,Height=14,Stroke=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#89988F")),StrokeThickness=.6};
            _rings[i]=ring;_dots[i]=dot;
            // Keep the ring and disk independently centered when the selected stroke changes.
            button.Content=new Grid{Children={ring,dot}};
            button.Click+=(_,_)=>{if(button.Tag is string color){_apply(color);RefreshSelection();}};
            _buttons[i]=button;Grid.SetColumn(button,i%3);Grid.SetRow(button,i/3);Children.Add(button);
        }
        // Page/dock reparenting is not the control's lifetime. Keep the profile
        // subscription until the owning window replaces or disposes this group.
        _store.Changed+=Rebuild;
        Loaded+=(_,_)=>{if(!_disposed)Rebuild();};
        Rebuild();
    }
    internal void SetLayout(bool vertical, double scale)
    {
        _scale = scale;
        RowSpacing = ColumnSpacing = 4 * scale;
        var columns = vertical ? 2 : 3;
        ColumnDefinitions.Clear();
        RowDefinitions.Clear();
        for (var i = 0; i < columns; i++) ColumnDefinitions.Add(new() { Width = GridLength.Auto });
        for (var i = 0; i < 6 / columns; i++) RowDefinitions.Add(new() { Height = GridLength.Auto });
        for (var i = 0; i < _buttons.Length; i++)
        {
            var button = _buttons[i];
            button.Width = button.Height = 22 * scale;
            button.CornerRadius = new CornerRadius(11 * scale);
            _rings[i].Width = _rings[i].Height = 20 * scale;
            _dots[i].Width = _dots[i].Height = 14 * scale;
            Grid.SetColumn(button, i % columns);
            Grid.SetRow(_buttons[i], i / columns);
        }
        RefreshSelection();
        HorizontalAlignment = vertical ? HorizontalAlignment.Center : HorizontalAlignment.Left;
        Margin = vertical ? new Thickness(0) : new Thickness(3, 0, 6, 0);
    }

    public void Dispose(){if(_disposed)return;_disposed=true;_store.Changed-=Rebuild;}
    internal void Refresh()=>Rebuild();
    private void Rebuild()
    {
        var colors=_store.Colors;
        for(var i=0;i<6;i++)
        {
            var button=_buttons[i];var color=i<colors.Count?colors[i]:null;
            button.Tag=color;button.IsEnabled=_enabled&&color is not null;
            _dots[i].Fill=new SolidColorBrush(color is null?Microsoft.UI.Colors.Transparent:Direct2DCanvasRenderer.HexToColor(color));
            ToolbarUi.Label(button,color is null?T("尚無常用色，調色後按＋新增。"):T("套用顏色")+" "+color);
        }
        RefreshSelection();
    }
    internal void RefreshSelection()
    {
        var current=PalettePreferencesStore.Canonical(_current());
        for(var i=0;i<_buttons.Length;i++)
        {
            var selected=_buttons[i].Tag is string color&&color==current;
            _rings[i].StrokeThickness=(selected?2:1)*_scale;
            _rings[i].Opacity=selected?1:.55;
        }
    }
#if HEIBAN_RELEASE_VALIDATION
    internal IReadOnlyList<Button> ValidationButtons=>_buttons;
#endif
}
