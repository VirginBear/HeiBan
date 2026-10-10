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
    $updaterProject = Join-Path $PSScriptRoot '..\..\HeiBan.Updater\HeiBan.Updater.csproj'
    & dotnet publish $updaterProject -c $Configuration -r $Runtime --self-contained true -p:PublishSingleFile=true -o (Join-Path $Destination 'Updater')
    if ($LASTEXITCODE -ne 0) { throw "更新程式 publish 失敗，代碼 $LASTEXITCODE" }
    Copy-Item (Join-Path $PSScriptRoot '..\..\Licenses') (Join-Path $Destination 'Licenses') -Recurse -Force
    # The app PRI holds the compiled XAML; runtime PRIs cannot replace it.
    foreach ($required in @('HeiBan.exe','HeiBan.pri','coreclr.dll','Microsoft.ui.xaml.dll',
        'Microsoft.UI.Xaml.Controls.pri','Microsoft.Graphics.Canvas.dll','Assets\AppIcon.ico','Assets\Wordmark.png','Updater\HeiBan.Updater.exe')) {
        $path = Join-Path $Destination $required
        if (-not (Test-Path $path -PathType Leaf) -or (Get-Item $path).Length -eq 0) {
            throw "發行包缺少必要檔案或檔案為空：$required；停止封裝。"
        }
    }
    Write-HeiBanUpdateInventory $Destination
}
function Write-HeiBanUpdateInventory {
    param([string]$Destination)
    # Only declared application payload is replaced by Portable updates. Data and user-added files stay outside this inventory.
    $files = [ordered]@{}
    Get-ChildItem -LiteralPath $Destination -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring([IO.Path]::GetFullPath($Destination).TrimEnd('\').Length + 1).Replace('\','/')
        if ($relative -ne 'update-files.json' -and $relative -ne 'portable.dat' -and -not $relative.StartsWith('Data/')) {
            $files[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    [ordered]@{ Version=(Get-HeiBanVersion); Files=$files } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $Destination 'update-files.json') -Encoding UTF8
}
function Get-HeiBanVersion {
    [xml]$project = Get-Content (Join-Path $PSScriptRoot '..\HeiBan.Windows.csproj') -Raw -Encoding UTF8
    return [string]($project.Project.PropertyGroup.Version | Select-Object -First 1)
}
