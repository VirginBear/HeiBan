using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;

namespace HeiBan.Windows.Views;

/// <summary>Shared palette controls; each host owns the action that applies a chosen color.</summary>
internal sealed class PaletteEditor : StackPanel
{
    private readonly PalettePreferencesStore _store;
    private readonly Func<string> _current;
    private readonly Action<string> _apply;
    private readonly Grid _swatches=new(){ColumnSpacing=4,RowSpacing=4};
    private readonly TextBlock _message=new(){FontSize=11,TextWrapping=TextWrapping.Wrap};
    private bool _managing,_subscribed;
    internal PaletteEditor(PalettePreferencesStore store,Func<string> current,Action<string> apply,ColorPicker? picker=null)
    {
        _store=store;_current=current;_apply=apply;Spacing=8;
        var heading=new Grid();heading.ColumnDefinitions.Add(new(){Width=new GridLength(1,GridUnitType.Star)});heading.ColumnDefinitions.Add(new(){Width=GridLength.Auto});
        heading.Children.Add(new TextBlock{Text=T("常用色"),VerticalAlignment=VerticalAlignment.Center});
        var manage=new Button{Content=T("管理"),Padding=new Thickness(8,3,8,3)};Grid.SetColumn(manage,1);heading.Children.Add(manage);
        manage.Click+=(_,_)=>{_managing=!_managing;manage.Content=T(_managing?"完成":"管理");Rebuild();};Children.Add(heading);Children.Add(_swatches);
        var actions=new StackPanel{Orientation=Orientation.Horizontal,Spacing=6};
        var add=new Button{Content="＋",Width=36,Padding=new Thickness(0)};ToolbarUi.Label(add,T("新增目前顏色"));
        var reset=new Button{Content=T("還原預設色"),FontSize=12,Padding=new Thickness(8,4,8,4)};
        add.IsEnabled=reset.IsEnabled=manage.IsEnabled=!_store.LoadFailed;
        add.Click+=async(_,_)=>await Persist(async()=>{if(!await _store.AddAsync(_current()))_message.Text=T("此顏色已在常用色");});
        reset.Click+=async(_,_)=>await Persist(async()=>{await _store.ResetAsync();});
        actions.Children.Add(add);actions.Children.Add(reset);Children.Add(actions);Children.Add(_message);
        if(_store.LoadFailed)_message.Text=T("常用色未載入，原設定檔已保留。");
        Loaded+=(_,_)=>{if(!_subscribed){_store.Changed+=Rebuild;_subscribed=true;}Rebuild();};
        Unloaded+=(_,_)=>{if(_subscribed){_store.Changed-=Rebuild;_subscribed=false;}};
        // Only picker changes update selection markers. No document/pointer event subscription.
        if(picker is not null)picker.ColorChanged+=(_,_)=>RefreshSelection();
        Rebuild();
    }
    private async Task Persist(Func<Task> change)
    {
        _message.Text="";
        try{await change();}
        catch(Exception){_message.Text=T("常用色保存失敗，請重試。");}
    }
    private void Rebuild()
    {
        _swatches.Children.Clear();_swatches.RowDefinitions.Clear();_swatches.ColumnDefinitions.Clear();
        for(var i=0;i<6;i++)_swatches.ColumnDefinitions.Add(new(){Width=GridLength.Auto});
        var selected=PalettePreferencesStore.Canonical(_current());var index=0;
        foreach(var color in _store.Colors)
        {
            var row=index/6;while(_swatches.RowDefinitions.Count<=row)_swatches.RowDefinitions.Add(new(){Height=GridLength.Auto});
            var cell=new StackPanel{Spacing=2};
            var button=new Button{Tag=color,Content=Chip(color),Width=32,Height=32,MinWidth=0,MinHeight=0,Padding=new Thickness(3),CornerRadius=new CornerRadius(8),BorderBrush=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#39735A")),BorderThickness=new Thickness(color==selected?2:1)};
            ToolbarUi.Label(button,T(color==selected?"目前顏色":"套用顏色")+" "+color);
            button.Click+=(_,_)=>{_apply(color);Rebuild();};
            var menu=new MenuFlyout();var remove=new MenuFlyoutItem{Text=T("移除顏色"),IsEnabled=!_store.LoadFailed};
            remove.Click+=async(_,_)=>await Persist(async()=>{await _store.RemoveAsync(color);});menu.Items.Add(remove);button.ContextFlyout=menu;
            cell.Children.Add(button);
            if(_managing)
            {
                var minus=new Button{Content="−",Width=32,Height=26,MinHeight=0,MinWidth=0,Padding=new Thickness(0)};ToolbarUi.Label(minus,T("移除顏色")+" "+color);
                minus.Click+=async(_,_)=>await Persist(async()=>{await _store.RemoveAsync(color);});cell.Children.Add(minus);
            }
            Grid.SetColumn(cell,index%6);Grid.SetRow(cell,row);_swatches.Children.Add(cell);index++;
        }
        if(index==0){var empty=new TextBlock{Text=T("尚無常用色，調色後按＋新增。"),TextWrapping=TextWrapping.Wrap,FontSize=12};Grid.SetColumnSpan(empty,6);_swatches.Children.Add(empty);}
    }
    private void RefreshSelection()
    {
        var current=PalettePreferencesStore.Canonical(_current());
        foreach(var cell in _swatches.Children.OfType<StackPanel>())
            if(cell.Children[0] is Button{Tag:string color} button)
            {button.BorderThickness=new Thickness(color==current?2:1);ToolbarUi.Label(button,T(color==current?"目前顏色":"套用顏色")+" "+color);}
    }
    internal static Grid Chip(string color)
    {
        var grid=new Grid{Width=22,Height=22};
        grid.RowDefinitions.Add(new());grid.RowDefinitions.Add(new());grid.ColumnDefinitions.Add(new());grid.ColumnDefinitions.Add(new());
        for(var i=0;i<4;i++){var tile=new Rectangle{Fill=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(i is 0 or 3?"#D3DAD5":"#FFFFFF"))};Grid.SetRow(tile,i/2);Grid.SetColumn(tile,i%2);grid.Children.Add(tile);}
        var fill=new Border{Background=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(color)),BorderBrush=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor("#77877B")),BorderThickness=new Thickness(1),CornerRadius=new CornerRadius(4)};
        Grid.SetRowSpan(fill,2);Grid.SetColumnSpan(fill,2);grid.Children.Add(fill);return grid;
    }
}
