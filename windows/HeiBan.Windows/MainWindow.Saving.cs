using System.Text.Json;
using System.Text.Json.Serialization;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private sealed class SavingPreferences
    {
        public bool AutoSaveEnabled { get; set; }
        [JsonExtensionData] public Dictionary<string, JsonElement>? ExtraFields { get; set; }
    }
    private SavingPreferences _savingPreferences = new();
    private bool _saveBoundaryBusy;
    private bool _savingSettingsOpen;
    private readonly SemaphoreSlim _savingPreferencesGate = new(1, 1);
    private string? _savingPreferenceError;
    private string SavingPreferencesPath => Path.Combine(_storage.DataDirectory, "Settings", "saving.json");
    internal bool AutoSaveEnabled => _savingPreferences.AutoSaveEnabled;

    private void LoadSavingPreferences()
    {
        try
        {
            if (File.Exists(SavingPreferencesPath))
                _savingPreferences = JsonSerializer.Deserialize<SavingPreferences>(File.ReadAllText(SavingPreferencesPath), DocumentCodec.Options) ?? new();
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        { _savingPreferenceError = error.Message; }
    }

    private void ApplySavingPreferences()
    {
        _autosave.Stop();
        if (AutoSaveEnabled && !_preparingClose && !_saveBoundaryBusy) _autosave.Start();
        else _thumbnailTimer.Stop();
        _screenAnnotation?.ApplySavingPreferences();
    }

    private async void HomeSettings_Click(object sender, RoutedEventArgs args) => await ShowSavingSettingsAsync();
    private async Task ShowSavingSettingsAsync()
    {
        if (_preparingClose || _saveBoundaryBusy || _savingSettingsOpen) return;
        _savingSettingsOpen = true;
        var automatic = new ToggleSwitch { Header = T("自動存檔"), IsOn = AutoSaveEnabled, OnContent = T("開啟"), OffContent = T("關閉") };
        var message = new TextBlock { Text = _savingPreferenceError is null ? "" : T("儲存設定讀取失敗，暫以自動存檔關閉使用。") + "\n" + _savingPreferenceError, TextWrapping = TextWrapping.Wrap };
        var panel = new StackPanel { Spacing = 16, MaxWidth = 440 };
        var toolbarFormat=new ComboBox{Header=T("工具列格式"),ItemsSource=new[]{T("只有圖示"),T("圖示與文字（分頁）")},SelectedIndex=_toolbarPrefs.DisplayMode=="labels"?1:0,HorizontalAlignment=HorizontalAlignment.Stretch};
        var boardEraser=new ToggleSwitch{Header=T("顯示板擦"),IsOn=_toolbarPrefs.BoardEraserVisible,OnContent=T("開啟"),OffContent=T("關閉")};
        panel.Children.Add(toolbarFormat);panel.Children.Add(boardEraser);panel.Children.Add(automatic);
        panel.Children.Add(new TextBlock { Text = T("預設關閉。關閉時不定期儲存作品；回到首頁、切換作品或正常退出時儲存。Ctrl+S 仍可隨時儲存。"), TextWrapping = TextWrapping.Wrap });
        panel.Children.Add(new TextBlock { Text = T("開啟後沿用定期存檔：一般畫布約每 15 秒，螢幕畫布停止修改約 1 秒後儲存。"), TextWrapping = TextWrapping.Wrap });
        panel.Children.Add(new TextBlock { Text = T("正常退出時顯示儲存動畫，完成後才關閉。未手動儲存的變更，在當機、斷電或強制結束時可能遺失。"), TextWrapping = TextWrapping.Wrap });
        panel.Children.Add(message);
        var dialog = new ContentDialog { Title = T("設定"), Content = panel, PrimaryButtonText = T("套用"), CloseButtonText = T("取消"), DefaultButton = ContentDialogButton.Primary, XamlRoot = Root.XamlRoot, FlowDirection = RightToLeft ? FlowDirection.RightToLeft : FlowDirection.LeftToRight };
        dialog.PrimaryButtonClick += async (_, args) =>
        {
            var deferral = args.GetDeferral(); args.Cancel = true; automatic.IsEnabled = false;
            try
            {
                await SetAutoSaveEnabledAsync(automatic.IsOn);
                var format=toolbarFormat.SelectedIndex==1?"labels":"icons";var previous=_toolbarPrefs.DisplayMode;var previousEraser=_toolbarPrefs.BoardEraserVisible;_toolbarPrefs.DisplayMode=format;_toolbarPrefs.BoardEraserVisible=boardEraser.IsOn;
                try{await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,_toolbarPrefs);}catch{_toolbarPrefs.DisplayMode=previous;_toolbarPrefs.BoardEraserVisible=previousEraser;throw;}
                BuildChrome();args.Cancel = false;
            }
            catch (Exception error) { message.Text = T("儲存設定未保存，請確認資料夾可寫入。") + "\n" + error.Message; }
            finally { automatic.IsEnabled = true; deferral.Complete(); }
        };
        try { await dialog.ShowAsync(); }
        finally { _savingSettingsOpen = false; }
    }

    internal async Task SetAutoSaveEnabledAsync(bool enabled)
    {
        await _savingPreferencesGate.WaitAsync();
        try
        {
            var updated = new SavingPreferences { AutoSaveEnabled = enabled, ExtraFields = _savingPreferences.ExtraFields };
            await DocumentSessionManager.WriteAtomicAsync(SavingPreferencesPath, JsonSerializer.Serialize(updated, DocumentCodec.Options));
            // Never claim a persistent choice until its atomic write has succeeded.
            _savingPreferences = updated; _savingPreferenceError = null; ApplySavingPreferences();
        }
        finally { _savingPreferencesGate.Release(); }
    }

    private void ShowSavingOverlay(bool visible)
    {
        SavingOverlay.FlowDirection = RightToLeft ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        SavingOverlay.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
        SavingRing.IsActive = visible;
        // IsEnabled is a Control property, inherited by its input descendants.
        WorkspaceInputGuard.IsEnabled = HomeInputGuard.IsEnabled = !visible;
    }

    private async Task<bool> SaveBeforeLeavingAsync()
    {
        if (_saveBoundaryBusy || _preparingClose) return false;
        _saveBoundaryBusy = true; _autosave.Stop(); _thumbnailTimer.Stop();
        _activeFlyout?.Hide(); ShowSavingOverlay(true);
        try
        {
            // Allow an animation frame before cloning; IO/encoding already runs off the UI thread.
            await Task.Delay(32);
            FinishText(); CommitPropertyEdit(); if (_gesture) CancelGesture();
            if(_circularEraser?.IsFinishing==true)await CompleteCircularEraserAsync();
            if(_boardEraserFinishing)await CompleteBoardEraserAsync();else CancelBoardEraser();
            if (_workspaceOpen && _session.IsDirty && !await SaveAsync()) return false;
            await FlushPendingThumbnailAsync();
            return !_workspaceOpen || !_session.IsDirty;
        }
        finally { ShowSavingOverlay(false); _saveBoundaryBusy = false; ApplySavingPreferences(); }
    }

    private async Task FlushPendingThumbnailAsync()
    {
        if (_pendingThumbnail is { } pending)
        {
            _pendingThumbnail = null;
            if (pending.Epoch == _session.DocumentEpoch) await SaveThumbnail(pending.Document);
        }
        // Wait for a thumbnail already writing before disposing its drawing resources.
        await _thumbnailGate.WaitAsync(); _thumbnailGate.Release();
    }
}
