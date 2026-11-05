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

    internal static void LabelMode(Button button, string key, bool labels, double iconSize, bool vertical = false)
    {
        button.Width = labels ? (vertical ? SideToolbarWidth : 84) : iconSize;
        button.Height = labels ? (vertical ? 52 : 72) : iconSize;

        var panel = button.Content as StackPanel;
        if (panel?.Tag as string != "toolbar-label") panel = null;
        if (!labels)
        {
            if (panel is null) return;
            var icon = panel.Children[0];
            panel.Children.RemoveAt(0);
            button.Content = icon;
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

        panel.Spacing = vertical ? 2 : 5;
        var text = (TextBlock)panel.Children[1];
        text.Text = T(key == "brush" ? "筆刷" : key == "more" ? "更多" : ToolbarPreferences.ToolNames.GetValueOrDefault(key, key));
        text.MaxWidth = vertical ? 50 : 76;
        text.TextWrapping = vertical ? TextWrapping.NoWrap : TextWrapping.Wrap;
        text.TextTrimming = vertical ? TextTrimming.CharacterEllipsis : TextTrimming.None;
    }

    internal static void ReplaceIcon(Button button,UIElement icon)
    {
        // Retain the label and its measured panel when just the swatch/style changes.
        if(button.Content is StackPanel{Tag:"toolbar-label"} label)
        {if(label.Children[0] is ColorIcon colored)colored.Icon.Content=icon;else{label.Children.RemoveAt(0);label.Children.Insert(0,icon);}}
        else if(button.Content is ColorIcon colored)colored.Icon.Content=icon;
        else button.Content=icon;
    }
    private sealed class ButtonParent {internal Panel? Owner;}
    private static readonly ConditionalWeakTable<Button,ButtonParent> ButtonParents=new();
    private static void AttachButton(Panel parent,Button button)
    {
        var unit=ButtonUnit(button);
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
    internal static ToolbarFlowPanel? Arrange(Panel host,IEnumerable<(string Key,Button Button)> source,bool labels,bool vertical,string activePage,Action<string> changePage,double iconSize,IReadOnlyCollection<string>? commonTools=null)
    {
        var buttons=source.ToArray();
        // Detach from their former page before reparenting on dock/language/preference changes.
        DetachButtons(buttons.Select(item=>item.Button));
        host.Children.Clear();
        foreach(var (key,button) in buttons){LabelMode(button,key,labels,iconSize,vertical);ArrangeQuickPalette(button,vertical);EnableRadialDrag(button,key);}
        if(!labels&&!vertical){foreach(var (_,button) in buttons.OrderBy(b=>b.Key=="select"?0:b.Key=="laser"?1:b.Key=="cane"?2:3))AttachButton(host,button);return null;}
        var shell=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=vertical?3:6};
        foreach(var key in ToolbarPreferences.FixedTools)if(buttons.FirstOrDefault(b=>b.Key==key).Button is { } pinned)AttachButton(shell,pinned);
        var body=new StackPanel{Spacing=vertical?6:4};
        var tabs=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=3};
        var flow=new ToolbarFlowPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,RunLength=vertical?600:900,Spacing=3,SingleRun=true};
        var tabButtons=new Dictionary<string,Button>();
        var pageMenu = new MenuFlyout();
        var pageButton = new Button { Width = SideToolbarWidth, Height = 30, MinWidth = 0, Padding = new Thickness(2), FontSize = 11, Flyout = pageMenu };
        if (vertical && labels) ApplyReadingDirection(pageMenu);
        void Show(string page)
        {
            flow.Children.Clear();flow.PageOffset=0;
            foreach(var (key,button) in buttons.Where(b=>b.Key!="more"&&!ToolbarPreferences.IsFixedTool(b.Key)&&(!labels|| (page=="common"?(commonTools?.Contains(b.Key)??PageFor(b.Key)=="common"):PageFor(b.Key)==page))))AttachButton(flow,button);
            foreach(var pair in tabButtons)pair.Value.Background=new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(pair.Key==page?(byte)45:(byte)0,57,115,90));
            if (vertical && labels)
            {
                var name = T(Pages.First(p => p.Key == page).Label);
                pageButton.Content = new TextBlock { Text = name + " ▾", MaxWidth = 50, TextTrimming = TextTrimming.CharacterEllipsis };
                Label(pageButton, name);
            }
            changePage(page);
        }
        foreach(var (key,label) in Pages)
        {
            if (!labels) break;
            if (vertical)
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
                FontSize=vertical?11:12,
                MinWidth=0
            };
            tab.Click+=(_,_)=>Show(key);tabs.Children.Add(tab);tabButtons[key]=tab;
        }
        var strip=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=3};
        var previous=new Button{Content=vertical?"⌃":"‹",Width=24,Height=32,Padding=new Thickness(0),VerticalAlignment=VerticalAlignment.Center};
        var next=new Button{Content=vertical?"⌄":"›",Width=24,Height=32,Padding=new Thickness(0),VerticalAlignment=VerticalAlignment.Center};
        Label(previous,T("上一組工具"));Label(next,T("下一組工具"));previous.Click+=(_,_)=>flow.NextPage(-1);next.Click+=(_,_)=>flow.NextPage(1);
        flow.PageAvailabilityChanged=(canPrevious,canNext)=>{previous.IsEnabled=canPrevious;next.IsEnabled=canNext;};
        if (vertical)
        {
            if (labels) body.Children.Add(pageButton);
            body.Children.Add(flow);
            var arrows = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 3, HorizontalAlignment = HorizontalAlignment.Center };
            previous.Height = next.Height = 24;
            arrows.Children.Add(previous);
            arrows.Children.Add(next);
            body.Children.Add(arrows);
        }
        else
        {
            strip.Children.Add(previous);
            strip.Children.Add(flow);
            strip.Children.Add(next);
            body.Children.Add(tabs);
            body.Children.Add(strip);
        }

        shell.Children.Add(body);
        if(buttons.FirstOrDefault(b=>b.Key=="more").Button is { } more)shell.Children.Add(more);
        host.Children.Add(shell);Show(Pages.Any(p=>p.Key==activePage)?activePage:"common");
        return flow;
    }
}
