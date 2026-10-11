using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;

namespace HeiBan.Windows.Views;

/// <summary>One context menu for committed text and drafts. Delayed panels retain the selection/draft guard.</summary>
internal static class TextStyleMenu
{
    private static readonly (string Hex,string Name)[] Colors=[("#111827","墨黑"),("#ffffff","白色"),("#ef4444","紅色"),("#f59e0b","橘色"),("#22c55e","綠色"),("#3b82f6","藍色"),("#a855f7","紫色"),("#ec4899","粉色")];
    internal static void Append(MenuFlyout menu,BoardObject[] targets,Action<TextStyleChange> apply,
        Action<FlyoutBase> show,Func<bool> isCurrent,Action? edit=null,double scale=1,bool draft=false)
    {
        var text=targets.Where(o=>o.Type is "text" or "sticky"&&o.IsLocked!=true).ToArray();if(text.Length==0)return;
        void Change(TextStyleChange value){if(isCurrent())apply(value);}
        menu.Items.Add(new MenuFlyoutSeparator());menu.Items.Add(new MenuFlyoutItem{Text=draft?T("文字設定（目前草稿）"):F($"文字設定（{text.Length} 個文字框）"),IsEnabled=false});
        var sizes=new MenuFlyoutSubItem{Text=T("文字大小")};foreach(var size in new[]{8,12,16,18,24,32,48,64,96,144}){var value=size;var item=new MenuFlyoutItem{Text=$"{size} pt"};item.Click+=(_,_)=>Change(new(Size:value));sizes.Items.Add(item);}menu.Items.Add(sizes);
        var colors=new MenuFlyoutSubItem{Text=T("文字顏色")};foreach(var (hex,name) in Colors){var item=new MenuFlyoutItem{Text=T(name)};item.Click+=(_,_)=>Change(new(Color:hex));colors.Items.Add(item);}menu.Items.Add(colors);
        foreach(var kind in new[]{"粗體","斜體","底線"})
        {
            var enabled=text.All(o=>kind=="粗體"?o.IsBold==true:kind=="斜體"?o.IsItalic==true:o.IsUnderline==true);
            var item=new ToggleMenuFlyoutItem{Text=T(kind),IsChecked=enabled};item.Click+=(_,_)=>Change(kind=="粗體"?new(Bold:!enabled):kind=="斜體"?new(Italic:!enabled):new(Underline:!enabled));menu.Items.Add(item);
        }
        var more=new MenuFlyoutItem{Text=T("更多文字設定…")};more.Click+=(_,_)=>{if(isCurrent())show(Settings(text[0],text.Length,Change,isCurrent,scale));};menu.Items.Add(more);
        if(edit is not null&&text.Length==1){var item=new MenuFlyoutItem{Text=T("編輯文字內容")};item.Click+=(_,_)=>{if(isCurrent())edit();};menu.Items.Add(item);}
    }
    private static Flyout Settings(BoardObject sample,int count,Action<TextStyleChange> apply,Func<bool> isCurrent,double scale)
    {
        var changed=new HashSet<string>();var panel=new StackPanel{Width=248,Spacing=10,RequestedTheme=ElementTheme.Light};
        panel.Children.Add(new TextBlock{Text=T("文字設定"),FontSize=16});
        if(count>1)panel.Children.Add(new TextBlock{Text=T("只套用你修改的欄位至所選文字框"),FontSize=12,TextWrapping=TextWrapping.Wrap});
        var size=new NumberBox{Header=T("文字大小（pt）"),Minimum=8,Maximum=144,Value=(sample.FontSize??24)/scale,SpinButtonPlacementMode=NumberBoxSpinButtonPlacementMode.Compact};
        var color=new TextBox{Header=T("文字顏色"),Text=sample.StrokeColor,PlaceholderText="#RRGGBB"};
        var palette=new Grid{ColumnSpacing=8,RowSpacing=6};for(var i=0;i<4;i++)palette.ColumnDefinitions.Add(new());palette.RowDefinitions.Add(new());palette.RowDefinitions.Add(new());
        for(var i=0;i<Colors.Length;i++){var (hex,name)=Colors[i];var button=new Button{Width=32,Height=32,MinWidth=0,MinHeight=0,Padding=new Thickness(0),CornerRadius=new CornerRadius(16),Content=new Microsoft.UI.Xaml.Shapes.Ellipse{Width=24,Height=24,Fill=new SolidColorBrush(Direct2DCanvasRenderer.HexToColor(hex))},Background=new SolidColorBrush(global::Windows.UI.Color.FromArgb(0,0,0,0))};ToolTipService.SetToolTip(button,T(name));button.Click+=(_,_)=>color.Text=hex;Grid.SetColumn(button,i%4);Grid.SetRow(button,i/4);palette.Children.Add(button);}
        var family=new TextBox{Header=T("字體名稱"),Text=sample.FontFamily??"Microsoft JhengHei"};
        var alignment=new ComboBox{Header=T("對齊"),ItemsSource=new[]{T("靠左"),T("置中"),T("靠右")},SelectedIndex=sample.Align=="center"?1:sample.Align=="right"?2:0,HorizontalAlignment=HorizontalAlignment.Stretch};
        var opacity=new Slider{Header=T("不透明度"),Minimum=.05,Maximum=1,StepFrequency=.05,Value=sample.Opacity};
        foreach(var control in new UIElement[]{size,color,palette,family,alignment,opacity})panel.Children.Add(control);
        size.ValueChanged+=(_,_)=>changed.Add("size");color.TextChanged+=(_,_)=>changed.Add("color");family.TextChanged+=(_,_)=>changed.Add("family");alignment.SelectionChanged+=(_,_)=>changed.Add("align");opacity.ValueChanged+=(_,_)=>changed.Add("opacity");
        var error=new TextBlock{FontSize=12,TextWrapping=TextWrapping.Wrap};panel.Children.Add(error);
        var flyout=new Flyout{Content=panel,ShouldConstrainToRootBounds=false};var buttons=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8};var save=new Button{Content=T("套用")};var cancel=new Button{Content=T("取消")};buttons.Children.Add(save);buttons.Children.Add(cancel);panel.Children.Add(buttons);
        cancel.Click+=(_,_)=>flyout.Hide();save.Click+=(_,_)=>{
            if(!isCurrent()){flyout.Hide();return;}
            if(changed.Contains("size")&&!double.IsFinite(size.Value)||changed.Contains("color")&&!TextStyles.ValidColor(color.Text)||changed.Contains("family")&&string.IsNullOrWhiteSpace(family.Text)){error.Text=T("請輸入有效大小、#RRGGBB 與字體名稱。");return;}
            apply(new(changed.Contains("size")?size.Value:null,changed.Contains("color")?color.Text:null,changed.Contains("family")?family.Text:null,changed.Contains("align")?new[]{"left","center","right"}[Math.Max(0,alignment.SelectedIndex)]:null,changed.Contains("opacity")?opacity.Value:null));flyout.Hide();
        };return flyout;
    }
}
