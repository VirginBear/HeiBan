function Publish-HeiBan {
    param([string]$Configuration, [ValidateSet('win-x64','win-arm64')][string]$Runtime, [string]$Destination)
    if ($env:OS -ne 'Windows_NT') { throw 'WinUI XAML 必須在 Windows 上編譯。' }
    $project = Join-Path $PSScriptRoot '..\HeiBan.Windows.csproj'
    $platform = if ($Runtime -eq 'win-arm64') { 'ARM64' } else { 'x64' }
    $null = Get-Command dotnet -ErrorAction Stop
    & dotnet publish $project -c $Configuration -r $Runtime --self-contained true `
        -p:Platform=$platform -p:WindowsPackageType=None -p:WindowsAppSDKSelfContained=true `
        -p:PublishAot=false -p:PublishSingleFile=false -o $Destination
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish 失敗，代碼 $LASTEXITCODE" }
    # The app PRI holds the compiled XAML; runtime PRIs cannot replace it.
    foreach ($required in @('HeiBan.exe','HeiBan.pri','coreclr.dll','Microsoft.ui.xaml.dll',
        'Microsoft.UI.Xaml.Controls.pri','Microsoft.Graphics.Canvas.dll','Assets\AppIcon.ico','Assets\Wordmark.png')) {
        $path = Join-Path $Destination $required
        if (-not (Test-Path $path -PathType Leaf) -or (Get-Item $path).Length -eq 0) {
            throw "發行包缺少必要檔案或檔案為空：$required；停止封裝。"
        }
    }
}
function Get-HeiBanVersion {
    [xml]$project = Get-Content (Join-Path $PSScriptRoot '..\HeiBan.Windows.csproj') -Raw -Encoding UTF8
    return [string]($project.Project.PropertyGroup.Version | Select-Object -First 1)
}
