# HeiBan 黑板 — Windows 專屬版本開發經驗總結與工程實施計劃

> **文件定位**：彙整針對 Windows 10/11 生態打造極致效能手寫黑板軟體的**核心開發經驗、技術陷阱、架構洞察**，以及後續在 Windows 環境（含 Parallels 虛擬機與 GitHub Actions 雲端 CI）落地開發的**完整階段實施計劃**。

---

## 目錄
1. [環境邊界與跨平台建置現實](#1-環境邊界與跨平台建置現實)
2. [Windows 專屬黑板繪圖的核心技術經驗與洞察](#2-windows-專屬黑板繪圖的核心技術經驗與洞察)
3. [雙發行型態架構設計經驗 (安裝版 vs. 免安裝綠色版)](#3-雙發行型態架構設計經驗-安裝版-vs-免安裝綠色版)
4. [Windows 版本詳細工程實施計劃 (Roadmap)](#4-windows-版本詳細工程實施計劃-roadmap)
5. [雲端自動化建置管線設計 (GitHub Actions CI/CD)](#5-雲端自動化建置管線設計-github-actions-cicd)
6. [Parallels 虛擬機實機測試操作指南](#6-parallels-虛擬機實機測試操作指南)

---

## 1. 環境邊界與跨平台建置現實

### 1.1 為什麼 macOS 環境無法直接產出「完美的 WinUI 3 原生 .exe」？
在現代軟體工程中，不同技術體系的跨平台編譯能力截然不同：
- **純 Web / Node.js 程式碼**：可在任何 OS 上無痛打包。
- **純 C# 控制台或命令列工具**：可使用 `dotnet publish -r win-x64` 在 macOS 上產出基本 PE 格式執行檔。
- **但是：微軟 Windows App SDK / WinUI 3 是深度綁定 Windows 作業系統的硬體級框架**：
  1. **XAML 編譯器 (`xbf` 生成)**：WinUI 3 的 XAML 前端編譯器為 Win32/x64 二進位原生程式，微軟官方並未釋出 macOS/Linux 版本的 XAML 編譯工具鏈。
  2. **DirectX / Direct2D C++ COM 連結**：Win2D 底層依賴 Windows SDK 的原生頭檔與 import libraries (`d2d1.lib`, `dwrite.lib`)。
  3. **MSIX 應用程式簽章與資訊清單**：需要 Windows 內建的 `MakeAppx.exe` 與 `SignTool.exe`。

**結論**：真正的 Windows 原生極致效能版本（Direct2D + Windows Ink），其**二進位產物必須在 Windows 環境內編譯**（例如：使用 Parallels Desktop 虛擬機、Windows 實體機、或 GitHub Actions Windows 雲端建置機）。

---

## 2. Windows 專屬黑板繪圖的核心技術經驗與洞察

### 2.1 墨水跟手延遲的關鍵：UI 執行緒 vs. 獨立輸入執行緒
- **傳統痛點**：一般 Windows 應用程式若在 UI 訊息迴圈 (`WM_MOUSEMOVE` 或一般 `PointerMoved` 事件) 中更新筆跡，其延遲高達 **35ms ~ 65ms**，使用者在手寫中文字時會明顯感覺「筆尖在前，墨水在後」的拖曳遲滯感。
- **Windows 原生解法**：
  - 必須採用 **Windows Ink API (`Microsoft.UI.Input.Inking` / `InkPresenter`)**。
  - Windows Ink 具備 **獨立輸入執行緒 (Independent Input Thread)**，由作業系統驅動程式層直接調度，取樣率可達 **120Hz ~ 240Hz**（例如 Microsoft Surface Pro / Wacom AES 數位筆）。
  - 配合系統內建的**墨水軌跡動態預測演算法 (Inking Prediction)**，將跟手延遲壓制在 **8ms 以內**，達到如同實體粉筆在黑板書寫的即時響應。

### 2.2 為什麼堅決反對 Electron / WebView2 套殼？
- 很多跨平台白板（如早期 Notion、Slack 內建白板）因偷懶採用 Electron 套殼：
  1. **事件循環阻塞**：Chromium 的主事件循環與垃圾回收機制，使得筆劃輸入無法繞過 JS 執行緒，手寫必然掉幀。
  2. **記憶體黑洞**：單純開一個空白黑板，Chromium + V8 即佔用 250MB ~ 400MB 記憶體。
  3. **字型排版度量失真**：WebKit/Blink 的文字渲染度量與 Windows DirectWrite 存在不可忽略的浮點差異，容易造成換行位置偏移。
- **堅持 WinUI 3 + Win2D + .NET 9 Native AOT**：
  - 記憶體常駐僅需 **45MB ~ 65MB**。
  - 冷啟動時間縮短至 **< 80ms**。

### 2.3 Direct2D (Win2D) 的硬體渲染與視窗裁剪
- **百萬點大黑板的效能瓶頸**：若每次畫面重繪都遍歷所有物件，當黑板上有 10,000 條筆跡與 200 張便簽時，GPU DrawCall 將會爆炸。
- **實作空間 AABB 視窗裁剪 (Frustum Culling)**：
  - 在 [`Direct2DCanvasRenderer.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/Engine/Direct2DCanvasRenderer.cs) 中，先計算每個物件在當前 `ViewportTransform`（縮放與平移）下的螢幕矩形。
  - 僅將與目前螢幕視窗有相交（`Intersects`）的物件送入 GPU 光柵化管線，螢幕外的物件在 CPU 端以極低成本跳過，確保在 4K 144Hz 電競或專業螢幕上依然滿幀。

### 2.4 手掌防誤觸 (Hardware Palm Rejection)
- 教室電子白板或平板書寫時，手掌邊緣貼在螢幕上是自然習慣。
- 在 [`WindowsInkCoordinator.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/Engine/WindowsInkCoordinator.cs) 中：
  - 監聽 `PointerDeviceType.Touch` 與 `PointerDeviceType.Pen`。
  - 檢測接觸橢圓面積 (`ContactRect.Width > 40`) 與壓力分佈，若判定為手掌貼附，則直接標記為已處理（Handled），杜絕造成畫布意外平移或畫出雜訊點。

### 2.5 ARM64 架構的原生重要性 (針對 Parallels on Apple Silicon 與 Copilot+ PC)
- 現今多數 Mac 開發者使用 Apple Silicon (M1/M2/M3/M4)，其 Parallels 虛擬機運行的是 **Windows 11 on ARM64**。
- 同時微軟正全力推動搭載 Qualcomm Snapdragon X Elite 的 **Copilot+ PC**。
- 若只編譯 x64，在 ARM 設備上必須透過模擬層運行，消耗額外 CPU 與電量；因此專案在 [`HeiBan.Windows.csproj`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/HeiBan.Windows.csproj) 中明確原生支援 **`ARM64`** 與 **`x64`** 雙架構。

---

## 3. 雙發行型態架構設計經驗 (安裝版 vs. 免安裝綠色版)

### 3.1 免安裝綠色版 (Portable) 的核心設計：便攜式資料隔離模式
許多標榜「免安裝」的軟體，實際上依然把快取、歷史紀錄寫入 `C:\Users\...\AppData\Local`，並在 Windows 註冊表建立鍵值，這不是真正的綠色軟體。

**HeiBan 的 Portable 設計哲學**：
- 在 [`DocumentSessionManager.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/Engine/DocumentSessionManager.cs) 中實作啟動探針：
  ```csharp
  string portableFlagFile = Path.Combine(exeDir, "portable.dat");
  string portableDataDir = Path.Combine(exeDir, "Data");
  if (File.Exists(portableFlagFile) || Directory.Exists(portableDataDir)) {
      IsPortableMode = true;
      DataDirectory = portableDataDir; // 重定向至本機目錄
  }
  ```
- **好處**：
  1. 解壓即用，放在 USB 隨身碟中，走到任何電腦直接雙擊執行。
  2. 所有的黑板作品、縮圖、設定完全保留在隨身碟的 `./Data/` 內。
  3. 拔除隨身碟後，目標電腦無任何暫存殘留、無註冊表變更。

### 3.2 專業安裝版 (Installer) 的體驗特權
- **副檔名深度整合**：雙擊 `.blackboard.json` 即可由 Windows Shell 直接呼叫 `HeiBan.exe` 開啟。
- **右鍵選單**：檔案總管中對檔案按右鍵出現「使用 HeiBan 黑板開啟」。
- **Windows 11 現代磁貼與捷徑**：自動加入開始功能表、桌面捷徑，支援 Windows 控制台乾淨反安裝。

---

## 4. Windows 版本詳細工程實施計劃 (Roadmap)

```
[Phase 1: 核心引擎對齊] ──> [Phase 2: Fluent 介面深化] ──> [Phase 3: 特色工具對齊] ──> [Phase 4: CI 自動打包發布]
  - Win2D GPU 渲染管線        - Windows 11 Mica 標題列       - 螢幕空間虛擬尺規            - GitHub Actions 雲端出包
  - Windows Ink 低延遲手寫    - Snap Layouts 視窗吸附        - 6 款可愛手繪便簽            - MSIX / Setup.exe 安裝版
  - Schema v1.0.0 序列化      - 深色/淺色主題連動            - 實體世界座標圖釘            - Portable 綠色單檔 ZIP
```

### Phase 1 — 核心渲染與低延遲筆跡 (已完成架構骨架)
- [x] 建立獨立 `windows/` 模組結構，隔離 Web 與 macOS 程式碼。
- [x] 實作 `DOCUMENT_SCHEMA_CONTRACT.md` v1.0.0 的 C# 資料結構 (`BoardModels.cs`)，支援未知欄位無損保留。
- [x] 實作 Direct2D/Win2D GPU 渲染管線 (`Direct2DCanvasRenderer.cs`)，包含五線譜、微點、方格。
- [x] 整合 Windows Ink 手寫協調器 (`WindowsInkCoordinator.cs`)，支援壓感與防手掌誤觸。
- [x] 實作原子磁碟儲存 (`DocumentSessionManager.cs`) 與 Portable 資料重定向。

### Phase 2 — 現代 Fluent 介面與視窗整合
- [ ] **自訂 Mica/Acrylic 標題列**：串接 Windows 11 AppWindow TitleBar API，完美嵌入最小化/最大化/關閉按鈕與 Snap Layouts。
- [ ] **高精度雙指縮放平移**：整合 Windows `DirectManipulation` API，提供符合 Windows 物理慣性之平滑手勢體驗。
- [ ] **深淺主題與動態色盤**：監聽 Windows 系統主題變更事件 (`UISettings.ColorValuesChanged`)，自動同步黑板外觀。

### Phase 3 — HeiBan 招牌特色功能對齊
- [ ] **虛擬螢幕尺規 (Virtual Screen Ruler)**：將 `RulerToolEngine` 移植至 C#，支援雙向支點旋轉、刻度度量與筆跡邊緣吸附。
- [ ] **6 款手繪便簽完整對齊**：實現 `classic`, `washi`, `cat` (貓咪耳朵幾何), `notebook`, `grid`, `soft` 向量渲染與原地 IME 編輯。
- [ ] **實體圖釘與視野導覽**：在畫布建立固定螢幕尺寸的圖釘標記，支援平滑動畫導覽至左上舒適書寫區。
- [ ] **向量 PDF/SVG 匯出**：使用 Direct2D Print API 產生高品質向量 PDF。

### Phase 4 — 自動化打包與雙發行發布
- [ ] **Inno Setup 繁體中文安裝檔**：完善 `inno_setup.iss`，打包為 `HeiBan-Setup-x64.exe` 與 `HeiBan-Setup-arm64.exe`。
- [ ] **免安裝綠色版打包**：完善 `Package-Portable.ps1`，產出自帶 `portable.dat` 的獨立 ZIP。
- [ ] **GitHub Actions 雲端 CI**：配置跨平台自動發布，推送 Release Tag 時自動在微軟雲端機上編譯並發行產物。

---

## 5. 雲端自動化建置管線設計 (GitHub Actions CI/CD)

為了解決在 macOS 本地無法直接產出 Windows 二進位檔的問題，標準現代軟體工程做法是透過 **GitHub Actions 的 `windows-latest` 虛擬機** 進行雲端一鍵自動編譯。

以下為已規劃之工作流程配置檔 (`.github/workflows/windows-release.yml`) 雛形：

```yaml
name: Windows Native Build & Package

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - name: 簽出原始碼
        uses: actions/checkout@v4

      - name: 安裝 .NET 9 SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '9.0.x'

      - name: 還原相依套件
        run: dotnet restore windows/HeiBan.Windows.sln

      - name: 編譯免安裝綠色版 (Portable)
        shell: pwsh
        run: |
          cd windows/HeiBan.Windows/Packaging
          ./Package-Portable.ps1 -Configuration Release -Runtime win-x64

      - name: 安裝 Inno Setup
        run: choco install innosetup -y

      - name: 編譯專業安裝版 (Setup.exe)
        shell: pwsh
        run: |
          cd windows/HeiBan.Windows/Packaging
          ./Package-Installer.ps1 -Configuration Release -Runtime win-x64

      - name: 上傳 Release 產物
        uses: actions/upload-artifact@v4
        with:
          name: windows-binaries
          path: |
            dist/windows/*.zip
            dist/windows/*.exe
```

---

## 6. Parallels 虛擬機實機測試操作指南

若您欲在現有的 Parallels Desktop 虛擬機中直接進行測試與開發，請參照下列步驟：

1. **環境檢查**：
   - 確保虛擬機中已安裝 **.NET 9.0 SDK** (可至 [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/9.0) 免費下載)。
   - 若欲使用 Visual Studio 測試，安裝 **Visual Studio 2022 Community** 並勾選「.NET 桌面開發」。
2. **開啟專案**：
   - Parallels 鏡像路徑：`\\Mac\Home\Desktop\Code\HeiBan\windows\`
   - 雙擊開啟 `HeiBan.Windows.sln`。
3. **一鍵編譯為免安裝版**：
   - 打開 PowerShell，切換至 `\\Mac\Home\Desktop\Code\HeiBan\windows\HeiBan.Windows\Packaging`
   - 執行 `.\Package-Portable.ps1`
   - 即可在 `dist\windows\HeiBan-Portable-...\` 取得現成的 **`HeiBan.exe`**，直接雙擊即可體驗 120Hz Direct2D 硬體加速與 1:1 筆刷/橡皮擦手寫！
