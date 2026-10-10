using Microsoft.UI.Xaml;
namespace HeiBan.Windows;
public partial class App : Application
{
    private MainWindow? _window;
    private Window? _errorWindow;
    private Updating.UpdateInstallation? _installationLease;
    private readonly List<string> _resourceErrors=[];
    internal static string StartupStage { get; set; }="建立主視窗";
    public App()
    {
        DebugSettings.IsXamlResourceReferenceTracingEnabled=true;
        DebugSettings.XamlResourceReferenceFailed+=(_,e)=>_resourceErrors.Add(e.Message);
        InitializeComponent();
    }
    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            if (!Updating.GitHubUpdateService.IsPackaged && string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")))
                _installationLease = new Updating.UpdateInstallation(AppContext.BaseDirectory);
            _window = new MainWindow();
            _window.Closed += (_, _) => _installationLease?.Dispose();
            _window.Activate();
        }
        catch(Exception e)
        {
            string? log=null;
            try
            {
                var folder=Path.Combine(Path.GetTempPath(),"HeiBan","StartupLogs");
                Directory.CreateDirectory(folder);
                log=Path.Combine(folder,$"startup-{DateTime.UtcNow:yyyyMMdd-HHmmss-fff}.log");
                File.WriteAllText(log,$"黑板 {typeof(App).Assembly.GetName().Version}\n階段：{StartupStage}\n架構：{System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}\n{e}\n\n"+string.Join("\n",_resourceErrors));
            }
            catch { /* The error screen must still work if a diagnostic cannot be written. */ }
            var hint=StartupStage=="建立作品資料夾"
                ? "無法建立 Windows 作品資料夾。請確認資料夾可寫入；免安裝版請完整解壓縮到可寫入的資料夾。"
                : "Windows 介面載入失敗。請使用新版黑板，或提供下方診斷紀錄以協助修復。";
            _errorWindow=new Window {Title="黑板：無法啟動",Content=new Microsoft.UI.Xaml.Controls.TextBlock {
                Text=hint+"\n\n階段："+StartupStage+"\n"+e.Message+(log is null?"":"\n\n診斷紀錄："+log),
                TextWrapping=TextWrapping.Wrap,Margin=new Thickness(24) }};
            _errorWindow.Activate();return;
        }
        var file=Environment.GetCommandLineArgs().Skip(1).FirstOrDefault(File.Exists);
        _window.InitializeAsync(file);
    }
}
