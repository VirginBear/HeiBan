# HeiBan Windows 專屬版本架構設計與發行白皮書 (Windows Architecture Blueprint)

> **設計目標**：打造專屬於 Windows 10/11 生態的極致性能、超低延遲手寫與 Fluent Design 體驗，並支援「標準安裝版 (MSIX / Setup.exe)」與「零殘留免安裝綠色版 (Portable)」雙發行形態。

---

## 1. 架構選型深度評估 (Language & Architecture Evaluation)

為了讓 Windows 版本達到**最佳效能（極致流暢、超低手寫筆延遲）**與**最佳使用體驗（Windows 11 原生視覺與觸控操作）**，我們對 4 種主流 Windows 技術路線進行嚴謹評估：

| 評估維度 | 方案一：WinUI 3 + Win2D + C# (.NET 9 Native AOT) | 方案二：C++20 + DirectX 11/12 + Win32 | 方案三：Rust + Direct2D / WGPU | 方案四：Electron / WebView2 套殼 |
| :--- | :--- | :--- | :--- | :--- |
| **手寫筆跟手延遲** | **極致 (<8ms)**<br>直通 Windows Ink 獨立硬體預測管線 | **極致 (<6ms)**<br>手刻 InkPresenter / D2D | **優異 (<10ms)**<br>透過 windows-rs 綁定 | **差 (30~60ms)**<br>受限於 Chromium 主事件循環 |
| **GPU 渲染性能** | **極致 (120/144Hz)**<br>Win2D (Direct2D 硬體加速光柵化) | **極致 (120/144Hz+)**<br>原生 DirectX SwapChain | **極致 (120/144Hz)**<br>Direct2D / WGPU Pipeline | **普通 (60Hz)**<br>DOM / WebGL 存在合成負載 |
| **啟動速度與記憶體** | **超快 (<80ms)**<br>常駐記憶體約 45~65MB (Native AOT) | **極速 (<50ms)**<br>常駐記憶體約 25~40MB | **極速 (<50ms)**<br>常駐記憶體約 25~45MB | **緩慢 (1~2.5s)**<br>常駐記憶體 200MB~350MB |
| **Windows 11 原生體驗** | **完美支援**<br>Mica 雲母、Snap Layouts、觸控手勢 | **需自行實現**<br>Win32 API 手刻複雜 | **部分支援**<br>UI 生態缺乏成熟 Fluent 組件 | **模擬質感**<br>非原生視窗控制與無障礙 |
| **多態資料契約維護** | **極佳**<br>強型別 C#，與 Swift/TS 語義對稱 | **普通**<br>C++ JSON 序列化與異步維護繁瑣 | **良好**<br>Serde 強大但生態組件少 | **容易**<br>直接共用 Web 程式碼 |
| **結論** | 🌟 **【推薦首選】最佳平衡與極限體驗** | 🛠️ **可作為核心底層加速庫** | 🔬 **具潛力，但 UI 成本高** | ❌ **嚴格否決：無法達成極致手寫** |

### 最終架構決策：WinUI 3 + C# (.NET 9 Native AOT) + Win2D (Direct2D) + Windows Ink

1. **核心渲染管線：Win2D (`Microsoft.Graphics.Canvas`)**
   - Direct2D 是 Windows 官方硬體 2D 繪圖引擎。Win2D 為其提供現代化包裝，直接在 GPU Direct3D 11/12 SwapChain 執行幾何繪製。
   - 支援百萬級筆跡點空間 AABB 視窗裁剪（Frustum Culling），即使大型複雜黑板在 4K 144Hz 螢幕上縮放平移依然保持滿幀。
2. **手寫筆低延遲引擎：Windows Ink API (`Microsoft.UI.Input` + `InkPresenter`)**
   - 啟用 **獨立輸入執行緒 (Independent Input Thread)**：筆跡取樣與預測不等待 UI 執行緒，直接在驅動層渲染浮動筆尖墨水。
   - 支援 Surface Pen / Wacom AES **120Hz~240Hz 筆跡回報率**、壓感（Pressure 0.0~1.0）與傾斜角（Tilt）。
   - 原生硬體防手掌誤觸（Hardware Palm Rejection），手掌貼在螢幕上書寫時絕不造成畫布誤拖曳。
3. **Windows 11 現代視覺：Fluent Design System**
   - 視窗背景套用 **Mica (雲母)** 與 **Acrylic (壓克力)** 毛玻璃半透明材質。
   - 支援 Windows 11 **Snap Layouts** 視窗智慧佈局吸附。
   - 支援深色（Dark）與淺色（Light）主題無縫切換，字型採用 Windows 專屬 **Segoe UI Variable**。
4. **.NET 9 Native AOT 編譯**
   - 直接編譯為純 Windows 原生機器碼（無需 JIT、無 CLR 預熱），冷啟動僅需 60~80ms，記憶體常駐降至 ~50MB。

---

## 2. 雙版本發行策略 (Installer vs. Portable)

### 2.1 安裝版 (Installer Edition)
適合日常主力工作機、教室電子白板設備或企業大量部署：
- **發行產物**：
  - `HeiBan-Setup-x64.exe` (使用 Inno Setup 封裝的經典安裝程式)
  - `HeiBan.Windows.msix` (Windows Store 與企業側載現代套件)
- **核心特性**：
  - 自動關聯 `.blackboard.json` 檔案類型與專屬黑板圖示。
  - 右鍵檔案功能表支援「使用 HeiBan 黑板開啟」。
  - 建立開始功能表捷徑與桌面捷徑。
  - 支援 Windows 11 沙盒化隔離與乾淨解除安裝（不留垃圾檔案）。
  - 自動偵測並安裝 WebView2 Runtime / Windows App SDK 依賴環境。

### 2.2 免安裝版 (Portable / 綠色版)
適合放在 USB 隨身碟帶著走、公用電腦、無管理員權限環境（如學校電腦教室、限制權限的公家機關或公司設備）：
- **發行產物**：
  - `HeiBan-Windows-Portable-v1.0.1.zip`
- **核心特性**：
  - **解壓即用**：內含單一可執行主程式 `HeiBan.exe` 與所需本機原生函式庫，不需要管理員權限，雙擊立即啟動。
  - **便攜式資料隔離模式 (Portable Data Isolation)**：
    - 主程式啟動時會主動偵測同目錄下是否存在 `portable.dat` 旗標或 `Data/` 資料夾。
    - 若命中便攜模式，程式將自動重定向所有本機資料庫、黑板檔案、縮圖快取與設定檔至 `./Data/` 目錄。
    - **零系統殘留**：絕不在目標主機的 `C:\Users\<User>\AppData` 建立殘留目錄，絕不改動目標主機的 Windows 註冊表（Registry）。拔出 USB 隨身碟後主機維持 100% 乾淨。

---

## 3. 專案模組架構圖 (`windows/`)

```
windows/
├── HeiBan.Windows.sln                      # Visual Studio / dotnet 解決方案
├── HeiBan.Windows/
│   ├── HeiBan.Windows.csproj               # WinUI 3 + .NET 9 + Win2D + NativeAOT 專案
│   ├── Package.appxmanifest                # MSIX 打包清單 (安裝版)
│   ├── App.xaml / App.xaml.cs              # 應用程式生命週期、便攜模式偵測、單實例進程協調
│   ├── MainWindow.xaml / MainWindow.xaml.cs # Windows 11 Mica 標題列、Snap Layouts、畫布容器
│   ├── Models/
│   │   └── BoardModels.cs                  # 完全對齊 DOCUMENT_SCHEMA_CONTRACT.md (System.Text.Json)
│   ├── Engine/
│   │   ├── Direct2DCanvasRenderer.cs       # Win2D Direct2D 硬體加速繪圖引擎
│   │   ├── WindowsInkCoordinator.cs        # Windows Ink 獨立執行緒低延遲手寫與壓感
│   │   ├── VectorMath.cs                   # 幾何運算、三次方貝茲平滑、空間 AABB 命中測試
│   │   └── DocumentSessionManager.cs       # 本機檔案原子儲存 (tmp交換)、修訂衝突防護、便攜路由
│   ├── Views/
│   │   ├── CanvasView.xaml                 # 畫布主介面
│   │   ├── TopNavToolbar.xaml              # 頂部 Fluent 工具列與筆刷/色彩選擇器
│   │   └── HomeDashboardView.xaml          # 作品首頁、真縮圖快取、格式選擇視窗
│   └── Packaging/
│       ├── Package-Installer.ps1           # 一鍵建置 MSIX 與 Inno Setup 安裝版
│       ├── Package-Portable.ps1            # 一鍵建置免安裝綠色版 (Portable ZIP)
│       └── inno_setup.iss                  # Inno Setup 腳本設定檔
└── README.md                               # Windows 版本編譯與發布完整操作指南
```

---

## 4. 資料契約與跨平台相容性 (100% 互通)

所有 Windows 產出的 `.blackboard.json` 檔案 100% 符合：
1. **Schema Version**：`1.0.0`，完全相容 macOS (`HeiBanCore`) 與 Web 版。
2. **幾何座標精度**：浮點誤差嚴格控制在 $\le 10^{-6}$。
3. **字型排版度量**：DirectWrite 文字渲染引擎容差 $\le 2.0\text{ pt}$。
4. **全功能物件支援**：鋼筆、螢光筆、油漆筆、貝茲曲線、幾何形狀（含多頂點三角形）、6 款可愛便簽、實體圖釘與多頁筆記本。
