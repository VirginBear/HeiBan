using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Updating;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private GitHubUpdateService? _updates;
    private async Task ShowUpdatesAsync()
    {
        if (_updates is null) return;
        var status = new TextBlock { Text = _updates.Status, TextWrapping = TextWrapping.Wrap };
        var automatic = new ToggleSwitch { Header = T("背景下載，正常關閉後更新"), IsOn = _updates.Settings.Enabled, IsEnabled = _updates.Available };
        var preview = new ToggleSwitch { Header = T("接收預覽版本"), IsOn = _updates.Settings.IncludePreview, IsEnabled = _updates.Available };
        var check = new Button { Content = T("檢查更新"), IsEnabled = _updates.Available && !_updates.Busy };
        var panel = new StackPanel { Spacing = 14, MaxWidth = 440 };
        panel.Children.Add(new TextBlock { Text = T("目前版本：") + GitHubUpdateService.CurrentVersion, TextWrapping = TextWrapping.Wrap });
        panel.Children.Add(status); panel.Children.Add(automatic); panel.Children.Add(preview); panel.Children.Add(check);
        panel.Children.Add(new TextBlock { Text = T("更新下載期間可繼續使用。作品保存成功、所有黑板視窗關閉後才安裝；下次開啟使用新版。"), TextWrapping = TextWrapping.Wrap });
        panel.Children.Add(new HyperlinkButton { Content = T("GitHub 官方版本與更新說明"), NavigateUri = new Uri("https://github.com/VirginBear/HeiBan/releases") });
        void Refresh() => DispatcherQueue.TryEnqueue(() => { status.Text = _updates.Status; check.IsEnabled = _updates.Available && !_updates.Busy; });
        async void Change(object sender, RoutedEventArgs e)
        {
            try { await _updates.SaveSettingsAsync(automatic.IsOn, preview.IsOn); }
            catch (Exception) { status.Text = T("更新偏好無法保存，請確認資料夾可寫入。"); }
        }
        automatic.Toggled += Change; preview.Toggled += Change;
        check.Click += async (_, _) => { check.IsEnabled = false; await _updates.CheckAsync(); Refresh(); };
        _updates.Changed += Refresh;
        try { await new ContentDialog {FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight, Title = T("黑板更新"), Content = panel, CloseButtonText = T("關閉"), XamlRoot = Root.XamlRoot }.ShowAsync(); }
        finally { _updates.Changed -= Refresh; }
    }
}
