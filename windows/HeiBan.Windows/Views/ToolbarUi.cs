using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;

namespace HeiBan.Windows.Views;

/// <summary>Shared chrome construction; each host owns its controls, coordinates and edit transactions.</summary>
internal static class ToolbarUi
{
    internal static readonly (string Key, string Label)[] ShapeTools =
    [
        ("line", "直線"), ("arrow", "箭頭"), ("rect", "矩形"),
        ("circle", "圓形"), ("triangle", "三角形"), ("quadrilateral", "四邊形"),
        ("diamond", "菱形"), ("pentagon", "五角形"), ("star", "星形")
    ];

    // Derive screen button keys from the shared preference catalog. Keep only tools that
    // have a working screen-session handler; the labels are localized from the same keys.
    internal static readonly (string Key, string Label)[] ScreenTools = ToolbarContentPolicy.ScreenCanvasTools
        .Select(key => (key, ToolbarPreferences.ToolNames.GetValueOrDefault(key, key)))
        .ToArray();

    internal static Button CreateButton(string icon, string label, Action? action = null, string? key = null)
    {
        // A XAML element has one parent. Share factories, never controls across windows.
        var button = new Button { Content = ToolIcons.Create(icon), Tag = key };
        Label(button, label);
        if (action is not null) button.Click += (_, _) => action();
        return button;
    }

    internal static void Label(Button button, string translatedLabel)
    {
        ToolTipService.SetToolTip(button, translatedLabel);
        AutomationProperties.SetName(button, translatedLabel);
    }

    internal static void ApplyReadingDirection(FlyoutBase flyout)
    {
        var direction = RightToLeft ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        if (flyout is Flyout { Content: FrameworkElement body }) body.FlowDirection = direction;
        // MenuFlyout has no FlowDirection property; the presenter owns its layout.
        if (flyout is MenuFlyout menu) menu.MenuFlyoutPresenterStyle = new Style
        {
            TargetType = typeof(MenuFlyoutPresenter),
            Setters = { new Setter(FrameworkElement.FlowDirectionProperty, direction) }
        };
    }

    internal static MenuFlyout LineStyles(Action<string> apply)
    {
        var menu = new MenuFlyout();
        foreach (var (value, label) in new[] { ("solid", "實線"), ("dashed", "虛線"), ("dotted", "點線"), ("dashdot", "點劃線") })
        {
            var row = new MenuFlyoutItem { Text = T(label), Icon = ToolIcons.CreateDashIcon(value) };
            // Host callbacks retain their own undo/commit and screen DPI boundaries.
            row.Click += (_, _) => apply(value);
            menu.Items.Add(row);
        }
        return menu;
    }
}
