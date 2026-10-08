# HeiBan 黑板 — Windows 專屬原生版本

專為 **Windows 10 / Windows 11** 量身打造的高效能手寫黑板與多頁筆記系統，具備硬體級超低延遲手寫墨水、Direct2D GPU 加速渲染與 Fluent Design 原生體驗。

---

## 🌟 核心特色與技術架構

1. **極致手寫延遲 (<8ms)**：
   - 採用 **Windows Ink API** 獨立執行緒（Independent Input Thread）處理墨水渲染。
   - 支援 Surface Pen、Wacom AES 等設備之 120Hz/240Hz 高頻取樣、中間點預測（Inking Prediction）與硬體防手掌誤觸（Palm Rejection）。
2. **Win2D (Direct2D) 硬體加速**：
   - 直接於 DirectX 11/12 SwapChain 執行百萬級向量點光柵化與三次方貝茲曲線繪製。
   - 內建空間 AABB 視窗裁剪（Frustum Culling），大畫布平移縮放依然滿幀 120/144 FPS。
3. **Windows 11 Fluent Design 原生外觀**：
   - 視窗背景原生套用 Mica (雲母) 材質與 Acrylic 壓克力半透明效果。
   - 完整支援 Windows 11 Snap Layouts 視窗快速排版。
4. **跨平台 100% 資料契約互通**：
   - 遵照 [`docs/DOCUMENT_SCHEMA_CONTRACT.md`](../docs/DOCUMENT_SCHEMA_CONTRACT.md) v1.0.0 規範，產出的 `.blackboard.json` 檔案與 macOS 及 Web 版完全通用、無損雙向往返。

---

## 📦 發行版本說明

我們提供兩種發行型態，滿足不同使用情境：

### 1. 安裝版 (Installer Edition)
- **檔案**：`HeiBan-Setup-x64.exe`
- **特點**：
  - 專為個人主力電腦、智慧黑板與會議室電子白板設計。
  - 自動關聯 `.blackboard.json` 檔案類型與專用圖示，雙擊檔案即可秒開黑板。
  - 整合 Windows 檔案總管右鍵功能表「使用 HeiBan 黑板開啟」。
  - 建立開始功能表與桌面捷徑，支援乾淨卸載。

### 2. 免安裝綠色版 (Portable Edition)
- **檔案**：`HeiBan-Windows-Portable-v1.0.1-win-x64.zip`
- **特點**：
  - **解壓即用**：免管理員權限，不需安裝即可雙擊 `HeiBan.exe` 執行。
  - **資料零殘留與便攜隔離**：
    - 內含 `portable.dat` 旗標與 `./Data/` 目錄。
    - 啟動時自動將黑板資料庫、設定檔與縮圖重定向至 `./Data/`。
    - **完全不寫入目標電腦的 AppData 或 Windows 註冊表 (Registry)**。
    - 非常適合放在 USB 隨身碟帶著走，在任何學校電腦或公用電腦隨插即畫，拔除後乾淨無痕。

---

## 🛠️ 開發與建置指南

### 系統需求
- Windows 10 (組建 17763 以上) 或 Windows 11
- .NET 9.0 SDK
- Visual Studio 2022 (17.10+) 搭配「.NET 桌面開發」與「通用 Windows 平台開發」工作負載

### 建置與除錯
```powershell
# 還原相依套件並編譯
dotnet build windows\HeiBan.Windows.sln -c Debug

# 啟動應用程式
dotnet run --project windows\HeiBan.Windows\HeiBan.Windows.csproj
```

### 一鍵打包發行

#### 建置免安裝綠色版 (Portable ZIP)：
```powershell
powershell -ExecutionPolicy Bypass -File windows\HeiBan.Windows\Packaging\Package-Portable.ps1
```
產物將輸出至：`dist\windows\HeiBan-Windows-Portable-v1.0.1-win-x64.zip`。

#### 建置安裝版 (Installer Setup)：
```powershell
powershell -ExecutionPolicy Bypass -File windows\HeiBan.Windows\Packaging\Package-Installer.ps1
```
產物將輸出至：`dist\windows\HeiBan-Setup-x64.exe`。
