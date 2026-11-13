using System.Runtime.CompilerServices;
using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace HeiBan.Windows.Views;

internal static partial class ToolbarUi
{
    private static readonly (string Key,string Label)[] Pages=[("common","常用"),("drawing","繪圖"),("insert","插入"),("organize","管理")];
    private static string PageFor(string key)=>key switch
    {
        "select" or "undo" or "redo"=>"organize",
        "cane"=>"common-only",
        "pen" or "highlighter" or "eraser" or "magnet"=>"drawing",
        "brush" or "curve" or "paint" or "ruler" or "shapes" or "compass" or "dash"=>"drawing",
        "sticky" or "text" or "image" or "screenshot" or "tape" or "calculator" or "timer"=>"insert",
        _=>"organize"
    };
    internal const double SideToolbarWidth = 60;

    internal static double SizeScale(string size) => size switch { "small" => .85, "large" => 1.2, _ => 1 };

    internal static ComboBox SizePicker(string size, Action<string> apply)
    {
        string[] values = ["small", "medium", "large"];
        var picker = new ComboBox
        {
            Header = T("工具列大小"),
            ItemsSource = new[] { T("小"), T("中"), T("大") },
            SelectedIndex = Math.Max(0, Array.IndexOf(values, size)),
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        picker.SelectionChanged += (_, _) => { if (picker.SelectedIndex >= 0) apply(values[picker.SelectedIndex]); };
        return picker;
    }

    private sealed record IconDimensions(double Width, double Height);
    private static readonly ConditionalWeakTable<FrameworkElement, IconDimensions> IconSizes = new();

    private static void ScaleIcon(UIElement? icon, double scale)
    {
        if (icon is ColorIcon color) { color.SetScale(scale); return; }
        if (icon is not FrameworkElement element) return;
        var size = IconSizes.GetValue(element, key => new(key.Width, key.Height));
        if (double.IsFinite(size.Width)) element.Width = size.Width * scale;
        if (double.IsFinite(size.Height)) element.Height = size.Height * scale;
    }

    internal static void LabelMode(Button button, string key, bool labels, double iconSize, bool vertical = false, double scale = 1)
    {
        ButtonParents.GetValue(button, _ => new()).Scale = scale;
        button.Width = (labels ? (vertical ? SideToolbarWidth : 84) : iconSize) * scale;
        button.Height = (labels ? (vertical ? 52 : 72) : iconSize) * scale;
        button.MinWidth = button.MinHeight = 0;
        button.Padding = new Thickness(4 * scale);
        button.HorizontalContentAlignment = HorizontalAlignment.Center;
        button.VerticalContentAlignment = VerticalAlignment.Center;

        var panel = button.Content as StackPanel;
        if (panel?.Tag as string != "toolbar-label") panel = null;
        if (!labels)
        {
            if (panel is null) { ScaleIcon(button.Content as UIElement, scale); return; }
            var icon = panel.Children[0];
            panel.Children.RemoveAt(0);
            button.Content = icon;
            ScaleIcon(icon, scale);
            return;
        }

        if (panel is null)
        {
            var icon = button.Content as UIElement;
            button.Content = null;
            panel = new StackPanel { Tag = "toolbar-label", HorizontalAlignment = HorizontalAlignment.Center };
            panel.Children.Add(icon ?? new TextBlock());
            panel.Children.Add(new TextBlock { FontSize = 11, TextAlignment = TextAlignment.Center });
            button.Content = panel;
        }

        panel.Spacing = (vertical ? 2 : 5) * scale;
        ScaleIcon(panel.Children[0], scale);
        var text = (TextBlock)panel.Children[1];
        text.Text = T(key == "brush" ? "筆刷" : key == "more" ? "更多" : ToolbarPreferences.ToolNames.GetValueOrDefault(key, key));
        text.MaxWidth = (vertical ? 50 : 76) * scale;
        text.FontSize = Math.Max(10, 11 * scale);
        text.TextWrapping = vertical ? TextWrapping.NoWrap : TextWrapping.Wrap;
        text.TextTrimming = vertical ? TextTrimming.CharacterEllipsis : TextTrimming.None;
    }

    internal static void ReplaceIcon(Button button,UIElement icon)
    {
        ScaleIcon(icon, ButtonParents.GetValue(button, _ => new()).Scale);
        // Retain the label and its measured panel when just the swatch/style changes.
        if(button.Content is StackPanel{Tag:"toolbar-label"} label)
        {if(label.Children[0] is ColorIcon colored)colored.Icon.Content=icon;else{label.Children.RemoveAt(0);label.Children.Insert(0,icon);}}
        else if(button.Content is ColorIcon colored)colored.Icon.Content=icon;
        else button.Content=icon;
    }
    private sealed class ButtonParent {internal Panel? Owner; internal double Scale = 1;}
    private static readonly ConditionalWeakTable<Button,ButtonParent> ButtonParents=new();
    private static void AttachButton(Panel parent,Button button)
    {
        var unit=ButtonUnit(button);
        unit.HorizontalAlignment = HorizontalAlignment.Center;
        unit.VerticalAlignment = VerticalAlignment.Center;
        var link=ButtonParents.GetValue(button,_=>new());
        if(link.Owner is { } old&&old!=parent)old.Children.Remove(unit);
        parent.Children.Add(unit);link.Owner=parent;
    }
    internal static void DetachButtons(IEnumerable<Button> buttons)
    {
        foreach(var button in buttons.Distinct())
        {
            // Hidden/not-yet-loaded WinUI trees can report Parent=null while their
            // Children collection still owns the control. Remember that collection.
            var unit=ButtonUnit(button);
            if(ButtonParents.TryGetValue(button,out var link)&&link.Owner is { } known){known.Children.Remove(unit);link.Owner=null;}
            else if((unit.Parent??VisualTreeHelper.GetParent(unit)) is Panel parent)parent.Children.Remove(unit);
        }
    }
    internal static ToolbarFlowPanel? Arrange(Panel host,IEnumerable<(string Key,Button Button)> source,bool labels,bool vertical,string activePage,Action<string> changePage,double iconSize,IReadOnlyCollection<string>? commonTools=null,double scale=1,bool compact=false,Action<MenuFlyout,FrameworkElement>? showPageMenu=null)
    {
        var buttons=source.ToArray();
        // Detach from their former page before reparenting on dock/language/preference changes.
        DetachButtons(buttons.Select(item=>item.Button));
        host.Children.Clear();
        foreach(var (key,button) in buttons){LabelMode(button,key,labels,iconSize,vertical,scale);ArrangeQuickPalette(button,vertical,scale);EnableRadialDrag(button,key);}
        if(!labels&&!vertical&&!compact){foreach(var (_,button) in buttons.OrderBy(b=>b.Key=="select"?0:b.Key=="laser"?1:b.Key=="cane"?2:3))AttachButton(host,button);return null;}
        var shell=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=vertical?3:6};
        foreach(var key in compact?Array.Empty<string>():ToolbarPreferences.FixedTools)if(buttons.FirstOrDefault(b=>b.Key==key).Button is { } pinned)AttachButton(shell,pinned);
        var body=new StackPanel{Spacing=vertical?6:4};
        var tabs=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=3};
        var flow=new ToolbarFlowPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,RunLength=vertical?600:900,Spacing=3,SingleRun=true};
        var tabButtons=new Dictionary<string,Button>();
        var pageMenu = new MenuFlyout();
        var pageButton = new Button { Width = SideToolbarWidth * scale, Height = 30 * scale, MinWidth = 0, Padding = new Thickness(2), FontSize = Math.Max(10, 11 * scale), Flyout = showPageMenu is null?pageMenu:null };
        if ((vertical||compact) && labels) ApplyReadingDirection(pageMenu);
        if(showPageMenu is not null)pageButton.Click+=(_,_)=>showPageMenu(pageMenu,pageButton);
        void Show(string page)
        {
            flow.Children.Clear();flow.PageOffset=0;
            foreach(var (key,button) in buttons.Where(b=>b.Key!="more"&&(compact||!ToolbarPreferences.IsFixedTool(b.Key))&&(!labels||ToolbarPreferences.IsFixedTool(b.Key)|| (page=="common"?(commonTools?.Contains(b.Key)??PageFor(b.Key)=="common"):PageFor(b.Key)==page))))AttachButton(flow,button);
            foreach(var pair in tabButtons)pair.Value.Background=new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(pair.Key==page?(byte)45:(byte)0,57,115,90));
            if ((vertical||compact) && labels)
            {
                var name = T(Pages.First(p => p.Key == page).Label);
                pageButton.Content = new TextBlock { Text = name + " ▾", MaxWidth = 50 * scale, TextTrimming = TextTrimming.CharacterEllipsis };
                Label(pageButton, name);
            }
            changePage(page);
        }
        foreach(var (key,label) in Pages)
        {
            if (!labels) break;
            if (vertical||compact)
            {
                var item = new MenuFlyoutItem { Text = T(label) };
                item.Click += (_, _) => Show(key);
                pageMenu.Items.Add(item);
                continue;
            }
            var tab=new Button
            {
                Content=T(label),
                Padding=vertical?new Thickness(6,4,6,4):new Thickness(9,4,9,4),
                FontSize=Math.Max(10,12*scale),
                MinWidth=0
            };
            tab.Click+=(_,_)=>Show(key);tabs.Children.Add(tab);tabButtons[key]=tab;
        }
        var strip=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=3};
        var previous=new Button{Content=vertical?"⌃":"‹",Width=24*scale,Height=32*scale,Padding=new Thickness(0),VerticalAlignment=VerticalAlignment.Center};
        var next=new Button{Content=vertical?"⌄":"›",Width=24*scale,Height=32*scale,Padding=new Thickness(0),VerticalAlignment=VerticalAlignment.Center};
        Label(previous,T("上一組工具"));Label(next,T("下一組工具"));previous.Click+=(_,_)=>flow.NextPage(-1);next.Click+=(_,_)=>flow.NextPage(1);
        flow.PageAvailabilityChanged=(canPrevious,canNext)=>{previous.IsEnabled=canPrevious;next.IsEnabled=canNext;};
        if (vertical)
        {
            if (labels) body.Children.Add(pageButton);
            body.Children.Add(flow);
            var arrows = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 3, HorizontalAlignment = HorizontalAlignment.Center };
            previous.Height = next.Height = 24 * scale;
            arrows.Children.Add(previous);
            arrows.Children.Add(next);
            body.Children.Add(arrows);
        }
        else
        {
            strip.Children.Add(previous);
            strip.Children.Add(flow);
            strip.Children.Add(next);
            if(compact){if(labels)body.Children.Add(pageButton);}
            else body.Children.Add(tabs);
            body.Children.Add(strip);
        }

        shell.Children.Add(body);
        if(buttons.FirstOrDefault(b=>b.Key=="more").Button is { } more)shell.Children.Add(more);
        host.Children.Add(shell);Show(Pages.Any(p=>p.Key==activePage)?activePage:"common");
        return flow;
    }
}
