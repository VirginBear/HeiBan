# 從原始碼建置

這份說明給開發者。一般使用者請直接使用 [Releases](https://github.com/VirginBear/HeiBan/releases)，不用安裝編譯工具。

```bash
git clone https://github.com/VirginBear/HeiBan.git
cd HeiBan
```

## Mac

macOS 14+、Xcode 15+／對應 Command Line Tools、Swift 5.9+、Python 3。目前發行是在 Apple Silicon 使用現有工具鏈完成；較舊 SDK、Intel 及交叉編譯仍未完整驗收。

```bash
# 先產生離線手冊，再建置 Mac 產品
python3 macos/scripts/generate_user_guide.py
cd macos
swift build --product HeiBanMac
bash scripts/build_app.sh
open dist/HeiBan.app
```

App 版本來源為 `macos/Release.json`。預設打包採 ad-hoc 簽章，適合開發／公開預覽；正式 Developer ID 與公證需要維護者自己的 Apple 憑證／帳號，不能以編譯成功代替。

```bash
# 有自己的 Developer ID 時，從外部安全環境提供 identity
HEIBAN_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' bash scripts/build_app.sh
```

發行封裝：`python3 scripts/package_public_release.py --platform macos`，只使用已建置的 `macos/dist/HeiBan.app`，產生 Mac DMG／ZIP／手冊與 SHA-256。不修改作品資料夾。

## Windows

在 Windows 建置，不能在 Mac 直接執行 WinUI XAML 編譯器。需要 .NET 10 SDK、Windows SDK 26100 與 WinUI XAML 編譯相依環境；完整 Visual Studio Windows 桌面開發環境亦可。`windows/global.json` 允許同主版較新 feature band。封裝需要 PowerShell 7 與官方 Inno Setup 6.7+／7（商用建置請確認適用的編譯器條款）。

```powershell
cd windows
dotnet build HeiBan.Windows.sln -c Release -p:Platform=x64 -r win-x64
# ARM64
# dotnet build HeiBan.Windows.sln -c Release -p:Platform=ARM64 -r win-arm64

pwsh -File HeiBan.Windows/Packaging/Package-Portable.ps1 -Runtime win-x64
pwsh -File HeiBan.Windows/Packaging/Package-Installer.ps1 -Runtime win-x64
# 將 Runtime 換成 win-arm64 建置另一架構
# 或提供 -IsccPath 'C:\Tools\InnoSetup\ISCC.exe'
```

產品與暫存只在 `windows/dist/` 與 `windows/.staging/`。公開封裝：回根目錄執行 `python scripts/package_public_release.py --platform windows`；保留原已建置的 EXE／Portable，另在 `windows/dist/public/` 產生含說明與授權的公開 ZIP、手冊及 SHA-256。安裝程式用 ZIP 包裝，不更改原 EXE；Portable 加入 LICENSE／第三方聲明，原程式與資源不變。

## Web 原型

不是本次公開的線上產品。使用 Node.js 22.12+ 或符合 Vite 引擎要求的較新 LTS、`package.json` 指定的 pnpm 11.22.0。

```bash
pnpm install --frozen-lockfile
pnpm run dev
# 本機 http://localhost:3000
pnpm run build
```

`firebase-applet-config.json` 為原型的 Firebase 用戶端設定。部署自己的版本前，替換成自己的 Firebase 專案，設定 Google 登入來源、Security Rules／App Check、適用 API 限制與隱私告知。用戶端識別設定不是 Admin 私鑰；GEMINI_API_KEY 或其他付費 API 金鑰不能放進瀏覽器或 Git。不要宣稱現有資料庫已完成生產安全驗收。

`.env.example` 只放占位值；本次沒有部署 Firebase、開啟正式 Google OAuth 或網頁服務。

## 既有檢查工具

```bash
# 可依修改範圍自行選擇；這不是本次發行的驗收承諾
cd macos
swift run HeiBanTestRunner
# Windows：dotnet run --project HeiBan.Windows.Core.Tests -c Release
# Web：pnpm run check
```

不要讓檢查程式使用正式作品庫。Mac 可設 `HEIBAN_DATA_DIRECTORY`，Windows 可設 `HEIBAN_WINDOWS_DATA_DIRECTORY` 指向獨立開發資料夾。每次執行的結果與未驗收內容寫入平台開發日誌。
