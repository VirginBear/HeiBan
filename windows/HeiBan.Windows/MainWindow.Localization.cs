using HeiBan.Windows.Localization;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private bool _changingLanguage;
    private void ApplyLanguageChrome()
    {
        Root.Language = Language;
        // Mirror navigation and text reading only. Drawing hit tests and absolute overlay coordinates remain LTR.
        HomePanel.FlowDirection = RightToLeft ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        Workspace.FlowDirection = FlowDirection.LeftToRight;
        Title = T("HeiBan 黑板 · Windows");
        ToolTipService.SetToolTip(HomeLanguageButton, T("語言") + " · " + NativeName);
        HomeLanguageIcon.Content = new TextBlock { Text = "文/A", FontSize = 12, VerticalAlignment = VerticalAlignment.Center };
    }
    private void HomeLanguage_Click(object sender, RoutedEventArgs args)
    {
        if (_changingLanguage) return;
        var menu = new MenuFlyout();
        foreach (var candidate in Languages)
        {
            var item = new ToggleMenuFlyoutItem { Text = candidate.NativeName, IsChecked = candidate.Code == Language };
            item.Click += async (_, _) =>
            {
                if (_changingLanguage || _workspaceOpen || _screenAnnotation?.IsActive == true) return;
                _changingLanguage = true; HomeLanguageButton.IsEnabled = false;
                try
                {
                    await SelectAsync(candidate.Code);
                    ApplyLanguageChrome(); BuildChrome(); FilterLibrary();
                    _screenAnnotation?.RefreshLanguage();
                    StatusText.Text = T("本機已存");
                }
                catch (Exception error) { await Error(error); }
                finally { _changingLanguage = false; HomeLanguageButton.IsEnabled = true; }
            };
            menu.Items.Add(item);
        }
        ShowExclusiveFlyout(menu, HomeLanguageButton);
    }
}
