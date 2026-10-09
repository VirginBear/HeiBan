# Windows 架構決策（2026-10-08）

## 決策

**C#／.NET 10 LTS + WinUI 3（Windows App SDK 2.5.1）+ Win2D 1.4.0。** 套件以明確版本固定；原生 x64／ARM64 各自建置。UI、輸入、GPU 快取與文件核心各自負責一層。

| 選項 | 適合之處 | 本案的取捨 |
| --- | --- | --- |
| WinUI 3 + C# + Win2D | Windows 原生控制項、IME、可及性、Direct2D；強型別文件核心 | 採用，能沿用既有 Windows 骨架；XAML 需 Windows 建置 |
| C++ + Win32/Direct2D | 精確控制原生輸入、配置與生命週期 | 保留未來輸入／渲染熱區擴充，不先增加 COM 與手刻 UI 維護成本 |
| Rust + Windows API | 幾何與背景工作的記憶體安全 | UI 與 IME 整合需額外橋接；目前不引入第二個原生核心 |
| WebView2 / Electron | 沿用 Web 功能速度較快 | 本案希望獨立 Windows 原生畫布與控制項，因此不採用；不以沒有量測的效能數字排除它 |

.NET 10 為 LTS；原有 .NET 9 計畫接近支援結束，不沿用新專案的基線。[Microsoft .NET 生命週期](https://learn.microsoft.com/en-us/dotnet/core/releases-and-support)。原有 Windows App SDK 1.6 已結束支援，改用查證存在的穩定版本 2.5.1。[SDK 版本](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/release-channels)。

## 模組與檔案隔離

```text
windows/
  HeiBan.Windows.Core/     # net10.0：JSON、幾何、文件交易、磁碟路由，不依賴 UI
  HeiBan.Windows/          # WinUI 3：生命週期、首頁、編輯器、Win2D、指標採樣
    Assets/               # Windows 獨立品牌與 ICO
    Engine/               # GPU 快取與 Windows 輸入收集器
    Views/                # 共用圖釘元件
    Packaging/            # publish、Portable ZIP、Inno Setup
  docs/                   # Windows 決策、工作清單、建置記錄
  dist/                   # 只有 Windows ZIP / Setup.exe / SHA-256
  .staging/               # 每次打包獨立目錄
```

沒有任何 csproj 連結到 `macos/` 或 Swift 檔案；輸出不寫根目錄 `dist/`。平台間共享文件規格，沒有在 Windows 安裝過程讀取／搬動 Mac 作品庫。Windows CI 必須位於 GitHub 指定的 `.github/workflows/windows-build.yml`，但其路徑觸發與產物僅針對 Windows。

## 執行分工與效能設計

1. **UI 執行緒**只維持目前工具、即時手勢、選取與文件交易。每個手勢完成才記錄 Undo，不在 PointerMoved 序列化全文件。Undo 上限 64 個交易及約 32 MB 字串記錄；大型圖片的交易還需要差異式歷史以降記憶體。
2. **指標收集**使用 WinUI 的中間點，依時間戳排序並去重，避免回頭連線產生折痕。滑鼠採固定粗細，Surface 筆壓及傾角保留到資料。觸控暫不畫墨水，以避免手掌把筆劃當成另一條輸入；不宣稱已做系統級 Palm Rejection。
3. **Win2D**保存已提交世界座標幾何，平移／縮放只改矩陣。即時筆跡每 64 個穩定曲線段建立快取，尾段獨立重建。縮圖與 PNG 共用渲染器；GPU 資源在換板／裝置重建／視窗結束釋放。
4. **可見範圍**使用含旋轉與線寬 padding 的保守 AABB 排除畫面外物件。目前仍逐物件遍歷；空間索引、分區快取與延遲量測是後續性能工作，沒有宣稱百萬點滿幀。
5. **保存**在 UI 取得快照後背景寫檔，使用唯一 tmp、Flush(true)、File.Replace 與備份。成功後才更新 UI 保存世代；保存期間新編輯不被標成已保存。使用 semaphore／跨程序 file lock，磁碟 revision 較新時拒絕覆寫。
6. **首頁**正常讀小型 metadata／縮圖，缺少索引時從文件補回。錯誤有明確對話框，不靜默把未來版本或損毀文件變空白。
7. **文字輸入**使用原生 TextBox，避免手刻 IME；只在畫布 PointerWheel 接收縮放，編輯文字期間停止畫布滾輪操作。

Win2D 支援 GPU 加速，但不保證硬體／驅動條件下永遠使用 GPU。[官方 Win2D 指南](https://learn.microsoft.com/en-us/windows/apps/develop/win2d/quick-start)。

## Ink 與 AOT 的界線

原骨架名稱 `WindowsInkCoordinator` 實際是 `PointerPressed/Moved` 收集器，沒有 InkPresenter。穩定 WinUI 的 InkCanvas 仍不受支援，官方提出 Win2D＋pointer input 等替代方案。[官方支援表](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/what-is-supported)。本階段採穩定 API；獨立輸入／預測需另外建 InkDesktopHost／原生橋接原型並量測。

**暫不啟用 Native AOT、trimming 或 single-file 發佈。** JSON extension data、XAML、WinRT 投影與 Win2D 先以穩定自包含部署落地；待功能與映射驗收後再比較 AOT 啟動和大小。AOT 不等於沒有執行期，更不能由編譯選項推導固定 80ms／50 MB。[官方自包含部署](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps)。

## 發行與資料

兩種包使用同一個 self-contained publish，避免功能分岔：安裝版包入 Inno Setup，免安裝版注入 `portable.dat` 和空 `Data/` 後壓縮。免安裝版不因偶然出現 Data 資料夾而切換模式、不在無法寫入時偷用 AppData；失敗會顯示說明。

Windows Shell 依最後副檔名判定；`.blackboard.json` 不能作為複合副檔名關聯而覆蓋全域 `.json`。安裝版另提供可選 `.heiban` OpenWithProgids；內容仍符合同一 JSON 契約。解除安裝只移除程式與自身關聯，保留作品。

Portable 是資料路由策略，並不表示作業系統不留 MRU／執行歷史。正式簽章、MSIX、自動更新與 Store 發行尚未完成，不能把安裝包稱作沙盒。
