# HeiBan Windows 免安裝綠色版 (Portable) 一鍵自動打包腳本
# 執行環境：Windows PowerShell 5.1+ / PowerShell 7+

param (
    [string]$Configuration = "Release",
    [string]$Runtime = $(if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "win-arm64" } else { "win-x64" }),
    [string]$Version = "1.0.1"
)

$ErrorActionPreference = "Stop"
Write-Host "==================================================" -ForegroundColor Green
Write-Host "🌿 開始建置 HeiBan Windows 免安裝綠色版 ($Runtime)" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Resolve-Path "$ScriptDir\.."
$DistDir = "$ProjectDir\..\..\dist\windows"
$StagingDir = "$DistDir\HeiBan-Portable-$Runtime"

if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# 1. 執行 dotnet publish 發布綠色版 (自包含 Windows App SDK 與 .NET 9 執行期)
Write-Host "📦 正在編譯綠色版獨立執行環境..." -ForegroundColor Yellow
dotnet publish "$ProjectDir\HeiBan.Windows.csproj" `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:WindowsPackageType=None `
    /p:PublishSingleFile=false `
    -o $StagingDir

# 2. 注入「免安裝便攜模式旗標」與獨立資料夾結構
Write-Host "🔒 注入便攜隔離配置 (portable.dat & Data/)..." -ForegroundColor Yellow
New-Item -ItemType File -Path "$StagingDir\portable.dat" -Force | Out-Null
New-Item -ItemType Directory -Path "$StagingDir\Data\Boards" -Force | Out-Null
New-Item -ItemType Directory -Path "$StagingDir\Data\Thumbnails" -Force | Out-Null

# 複製範例黑板資料供開箱即用
$ShowcaseSrc = "$ProjectDir\..\..\public\feature_showcase.blackboard.json"
if (Test-Path $ShowcaseSrc) {
    Copy-Item $ShowcaseSrc "$StagingDir\Data\Boards\feature_showcase.blackboard.json" -Force
}

# 3. 壓縮為 ZIP 綠色免安裝壓縮包
$ZipOutput = "$DistDir\HeiBan-Windows-Portable-v$Version-$Runtime.zip"
if (Test-Path $ZipOutput) { Remove-Item -Force $ZipOutput }

Write-Host "🗜️ 正在封裝為免安裝發行 ZIP: $ZipOutput" -ForegroundColor Yellow
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipOutput -CompressionLevel Optimal

Write-Host "✅ 免安裝綠色版打包成功！" -ForegroundColor Green
Write-Host "產物檔案: $ZipOutput" -ForegroundColor Green
Write-Host "特性：解壓即用、免管理員權限、資料隔離於 Data/ 目錄、零註冊表殘留。" -ForegroundColor Cyan
