using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;

namespace HeiBan.Windows;

/// <summary>
/// 應用程式生命週期管理與單一實例重定向協調
/// </summary>
public partial class App : Application
{
    private Window? _window;
    public static Window? MainWindowInstance { get; private set; }

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        // 1. 初始化文件會話管理器 (自動檢測便攜版 Portable 模式)
        _ = DocumentSessionManager.Shared;

        // 2. 建立並啟動主視窗
        _window = new MainWindow();
        MainWindowInstance = _window;
        _window.Activate();

        // 3. 處理開啟檔案命令列引數 (如雙擊 .blackboard.json 開檔)
        var appArgs = AppInstance.GetCurrent().GetActivatedEventArgs();
        if (appArgs.Kind == ExtendedActivationKind.File)
        {
            // 檔案關聯啟動處理
        }
    }
}
