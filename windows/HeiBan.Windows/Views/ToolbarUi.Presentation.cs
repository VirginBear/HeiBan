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
    internal static void LabelMode(Button button,string key,bool labels,double iconSize)
    {
        var wrapped=button.Content as StackPanel;
        if(wrapped?.Tag as string=="toolbar-label")
        {
            if(labels){var text=(TextBlock)wrapped.Children[1];var value=T(key=="brush"?"筆刷":key=="more"?"更多":ToolbarPreferences.ToolNames.GetValueOrDefault(key,key));if(text.Text!=value)text.Text=value;return;}
            var icon=wrapped.Children[0];wrapped.Children.RemoveAt(0);button.Content=icon;
        }
        else if(labels)
        {
            var icon=button.Content as UIElement;button.Content=null;
            var panel=new StackPanel{Tag="toolbar-label",Spacing=5,HorizontalAlignment=HorizontalAlignment.Center};
            if(icon is not null)panel.Children.Add(icon);else panel.Children.Add(new TextBlock());
            panel.Children.Add(new TextBlock{Text=T(key=="brush"?"筆刷":key=="more"?"更多":ToolbarPreferences.ToolNames.GetValueOrDefault(key,key)),FontSize=11,TextWrapping=TextWrapping.Wrap,TextAlignment=TextAlignment.Center,MaxWidth=76});
            button.Content=panel;
        }
        button.Width=labels?84:iconSize;button.Height=labels?72:iconSize;
    }
    internal static void ReplaceIcon(Button button,UIElement icon)
    {
        // Retain the label and its measured panel when just the swatch/style changes.
        if(button.Content is StackPanel{Tag:"toolbar-label"} label)
        {if(label.Children[0] is ColorIcon colored)colored.Icon.Content=icon;else{label.Children.RemoveAt(0);label.Children.Insert(0,icon);}}
        else if(button.Content is ColorIcon colored)colored.Icon.Content=icon;
        else button.Content=icon;
    }
    internal static void DetachButtons(IEnumerable<Button> buttons)
    {
        foreach(var button in buttons)
            if((button.Parent??VisualTreeHelper.GetParent(button)) is Panel parent)parent.Children.Remove(button);
    }
    internal static ToolbarFlowPanel? Arrange(Panel host,IEnumerable<(string Key,Button Button)> source,bool labels,bool vertical,string activePage,Action<string> changePage,double iconSize,IReadOnlyCollection<string>? commonTools=null)
    {
        var buttons=source.ToArray();
        // Detach from their former page before reparenting on dock/language/preference changes.
        DetachButtons(buttons.Select(item=>item.Button));
        host.Children.Clear();
        foreach(var (key,button) in buttons)LabelMode(button,key,labels,iconSize);
        if(!labels){foreach(var (_,button) in buttons.OrderBy(b=>b.Key=="select"?0:b.Key=="laser"?1:b.Key=="cane"?2:3))host.Children.Add(button);return null;}
        var shell=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=6};
        foreach(var key in ToolbarPreferences.FixedTools)if(buttons.FirstOrDefault(b=>b.Key==key).Button is { } pinned)shell.Children.Add(pinned);
        var body=new StackPanel{Spacing=4};
        var tabs=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=3};
        var flow=new ToolbarFlowPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,RunLength=vertical?600:900,Spacing=3,SingleRun=true};
        var tabButtons=new Dictionary<string,Button>();
        void Show(string page)
        {
            flow.Children.Clear();flow.PageOffset=0;
            foreach(var (key,button) in buttons.Where(b=>b.Key!="more"&&!ToolbarPreferences.IsFixedTool(b.Key)&&(page=="common"?(commonTools?.Contains(b.Key)??PageFor(b.Key)=="common"):PageFor(b.Key)==page)))flow.Children.Add(button);
            foreach(var pair in tabButtons)pair.Value.Background=new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(pair.Key==page?(byte)45:(byte)0,57,115,90));
            changePage(page);
        }
        foreach(var (key,label) in Pages)
        {var tab=new Button{Content=T(label),Padding=new Thickness(9,4,9,4),FontSize=12};tab.Click+=(_,_)=>Show(key);tabs.Children.Add(tab);tabButtons[key]=tab;}
        var strip=new StackPanel{Orientation=vertical?Orientation.Vertical:Orientation.Horizontal,Spacing=3};
        var previous=new Button{Content=vertical?"⌃":"‹",Width=24,Height=32,Padding=new Thickness(0),VerticalAlignment=VerticalAlignment.Center};
        var next=new Button{Content=vertical?"⌄":"›",Width=24,Height=32,Padding=new Thickness(0),VerticalAlignment=VerticalAlignment.Center};
        Label(previous,T("上一組工具"));Label(next,T("下一組工具"));previous.Click+=(_,_)=>flow.NextPage(-1);next.Click+=(_,_)=>flow.NextPage(1);
        flow.PageAvailabilityChanged=(canPrevious,canNext)=>{previous.IsEnabled=canPrevious;next.IsEnabled=canNext;};
        strip.Children.Add(previous);strip.Children.Add(flow);strip.Children.Add(next);
        body.Children.Add(tabs);body.Children.Add(strip);shell.Children.Add(body);
        if(buttons.FirstOrDefault(b=>b.Key=="more").Button is { } more)shell.Children.Add(more);
        host.Children.Add(shell);Show(Pages.Any(p=>p.Key==activePage)?activePage:"common");
        return flow;
    }
}
