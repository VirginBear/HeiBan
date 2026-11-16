using Microsoft.UI.Xaml.Controls;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows.Views;

internal static partial class ToolbarUi
{
    internal static MenuFlyout ClearPageMenu(Func<bool,Task> clear)
    {
        var menu=new MenuFlyout();
        var all=new MenuFlyoutItem{Text=T("全部清除"),Icon=ToolIcons.CreateMenuIcon("delete")};
        var ink=new MenuFlyoutItem{Text=T("僅清除筆跡"),Icon=ToolIcons.CreateMenuIcon("eraser")};
        all.Click+=async(_,_)=>await clear(false);
        ink.Click+=async(_,_)=>await clear(true);
        menu.Items.Add(all);
        menu.Items.Add(ink);
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(new MenuFlyoutItem{Text=T("取消")});
        return menu;
    }
}
