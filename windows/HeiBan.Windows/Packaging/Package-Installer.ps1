# HeiBan Windows 安裝版一鍵自動打包腳本
# 執行環境：Windows PowerShell 5.1+ / PowerShell 7+

param (
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "🚀 開始建置 HeiBan Windows 安裝版 ($Runtime - $Configuration)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Resolve-Path "$ScriptDir\.."
$OutputDir = "$ProjectDir\..\..\dist\windows"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 1. 執行 dotnet publish 發行原生自包含程式庫
Write-Host "📦 正在編譯與發行主程式..." -ForegroundColor Yellow
dotnet publish "$ProjectDir\HeiBan.Windows.csproj" `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:WindowsPackageType=None `
    /p:PublishSingleFile=false

# 2. 呼叫 Inno Setup 編譯安裝檔 (若系統有安裝 ISCC.exe)
$IsccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $IsccPath) {
    Write-Host "🛠️ 正在生成 Inno Setup 安裝程式 (HeiBan-Setup-x64.exe)..." -ForegroundColor Yellow
    & $IsccPath "$ScriptDir\inno_setup.iss"
    Write-Host "✅ 安裝版打包成功！產物位於: $OutputDir\HeiBan-Setup-x64.exe" -ForegroundColor Green
} else {
    Write-Host "ℹ️ 提示：未偵測到 Inno Setup 編譯器，已完成標準 Publish 產物輸出至 bin\Release 目錄。" -ForegroundColor Gray
}

Write-Host "🎉 安裝版建置程序結束！" -ForegroundColor Cyan
