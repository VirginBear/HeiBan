# 黑板 · Windows 原生版

**開發預覽 0.1.0-preview.5**。Windows 專用 C#／.NET 10 LTS、WinUI 3、Win2D；不是瀏覽器套殼。

最新開發入口：[2026-10-09 Windows 開發計劃／Antigravity 工作單](docs/WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md)、[目前狀態](docs/CURRENT_STATUS.zh-TW.md)、[問題紀錄](docs/ISSUE_HISTORY.zh-TW.md)、[開發日誌](docs/DEVELOPMENT_LOG.zh-TW.md)。preview.5 整合 Antigravity 第0／1批來源，並修正原生編譯、圓規／圓弧與截圖；後續批次及完整互動仍待開發／驗收。

程式、資源、文件、建置及發行檔均在 `windows/`。不編譯或引用 `macos/`；Windows 與 Mac 只遵循同一黑板 JSON 契約，品牌素材在 Windows 目錄保留獨立副本。

## 公開下載與安裝

公開自包含包等待 Windows SDK 授權例外確認，暫未建立 Release；既有本機封裝保留。[完整安裝／更新指南](../docs/INSTALL.zh-TW.md) · [已知限制](../docs/KNOWN_ISSUES.zh-TW.md)。公開安裝包為 ZIP，完整解壓後執行內含的 Setup EXE；公開包加入 GPL 與第三方原始授權，程式 payload 保持原 preview.5。

## 發行型態

| 版本 | 開啟方式 | 黑板、縮圖、垃圾桶資料 |
| --- | --- | --- |
| 安裝版 | `HeiBan-Setup-0.1.0-preview.5-x64.exe` 或 `...-arm64.exe` | `%LOCALAPPDATA%\HeiBan\Windows\` |
| 免安裝版 | 解壓 `HeiBan-Windows-Portable-0.1.0-preview.5-win-x64.zip` 或 `...-win-arm64.zip`，雙擊 `HeiBan.exe` | 程式旁的 `Data/`；由 `portable.dat` 明確啟用 |

整個 ZIP 解壓後的資料夾必須保留，不能只複製 EXE。自包含 .NET 與 Windows App SDK，不要求使用者額外安裝執行庫。程式放在可寫入的位置，退出後再拔除隨身碟。免安裝模式不自行更改檔案關聯或登錄；Windows 本身仍可能記錄執行歷史，因此不承諾作業系統「零痕跡」。

安裝版是每位使用者安裝，不要求管理員；桌面捷徑及 `.heiban` 開啟方式可選。解除安裝保留使用者作品。`.heiban` 內容與 `.blackboard.json` 一樣是 JSON；也能開啟及匯出 `.json`，不把所有 JSON 檔案改成黑板關聯。

## preview.5 試用版

- 截圖改為黑板自己的區域框選，完成後直接以圖片物件置入目前畫布，可縮放／旋轉；Esc 或右鍵取消。不另存截圖資料夾。
- 修正圓規半徑把手與筆尖重疊、圓弧邊把手縮小及起訖角跨 0° 的連續性。
- 整合計算機、計時器、右上浮動導覽與繁體中文離線手冊。
- 原生 Windows ARM64／x64 封裝；實際驗證範圍見 [建置紀錄](docs/BUILD_STATUS.zh-TW.md)。

## preview.4 操作修正

- 直線／箭頭：先點 A，再點 B 建立；也可直接拖曳建立。完成切回選取，顯示 A／B 圓形把手，各端可獨立拖移；拖線身移動整條線。Esc 取消尚未完成的線。
- 圖片：置入後即選取，八個縮放把手與上方圓形旋轉把手。角落縮放預設保持比例，按 Shift 可自由調整；旋轉時按 Shift 以 15° 吸附。選取框與命中測試隨物件角度旋轉。
- 顏色圓鈕：有選取物件時直接調整該物件的線色、粗細與透明度；未選取時設定目前工具。矩形／圓形等同一面板提供填色與快捷色；右側屬性面板仍可調整。
- 上方作品列：預設收起，不占畫布高度。點擊／滑鼠移到上方中央小頁籤顯示，離開約 0.8 秒收合；編輯名稱或選單開啟時保留，可按「固定」常駐。
- 尺的金色支點：可拖到上方／下方劃線邊，也可到最左端／最右端；拖旋轉把手或輸入角度都固定該支點。右鍵尺規可精確設定邊與 0–100% 位置。

核心回歸檢查：`dotnet run --project HeiBan.Windows.Core.Tests -c Release`。編譯與實機操作驗證範圍見 [本輪紀錄](docs/INTERACTION_FIXES_preview4.zh-TW.md)。

## preview.3 介面與操作修正

以目前 Mac 實作為基準，採用相同的深綠／暖白配色、圖示語意及工具分組。Windows 的線條圖示為原創向量，圖釘仍共用既有斜向造型。

- 點工具列的顏色圓鈕，開啟原生圓形色輪、快捷色、粗細與透明度；各筆刷保留各自設定。六個筆寬預設與預覽採用實際畫布直徑，取消油漆筆／螢光筆隱藏的寬度倍率。
- 屬性面板從右側書籤展開，浮在畫布上；線色、填色、alpha、粗細、線型、旋轉與文字大小立即更新，無須再按「套用」。選取物件不覆寫目前畫筆設定。
- 尺長預設 1200 pt，依小視窗適應；拖尺身移動、拖兩端圓形把手旋轉，點角度或右鍵尺規可輸入 0.1° 角度、尺長、透明度與自適應／自訂文字色。細小旋轉參考點可沿尺移動。尺邊吸附保持至抬筆。
- 工具列握柄自由拖移，放開後在左右改為直排、上下改為橫排。依空間限制長度、超出部分可捲動；拖動途中只改顯示位移，避免方向切換造成抖動。
- preview.3 的截圖按鈕啟動 Windows 剪取工具；preview.5 已改為黑板自己的區域框選。外部剪貼簿圖片仍可用 Ctrl+V 貼上，也可拖入圖片檔。

操作方式與本輪驗收界線見 [介面修正紀錄](docs/UI_PARITY_preview3.zh-TW.md)。這次修正沒有宣稱完成尚未移植的 Google 帳號、PDF／SVG、完整富文本或頁面側欄。

## preview.2 啟動修正與更新

preview.1 發行包漏掉應用程式自身的 `HeiBan.pri`，主視窗會出現 `XAML parsing failed.`；這不是作品資料夾權限錯誤。preview.2 在專案 publish 流程中加入 PRI，兩種封裝均檢查必要檔案，缺檔立即停止。詳細紀錄見 [啟動修復](docs/STARTUP_FIX_preview2.zh-TW.md)。

- 安裝版：執行新版安裝檔更新，不必先移除舊版；作品仍在原來的 Windows 資料目錄。
- 免安裝版：完整解壓新版 ZIP，再開啟其中的 `HeiBan.exe`。如舊版已有作品，關閉黑板後，將舊資料夾的 `Data` 複製到新版資料夾，保留舊副本。
- 啟動錯誤會區分「建立作品資料夾」與「載入 Windows 介面」，完整紀錄寫到 Windows `%TEMP%\HeiBan\StartupLogs`，畫面顯示紀錄位置。

## 已接入的操作

- 品牌首頁、搜尋、小型新增視窗、筆記本／無邊界筆記／有邊界黑板。
- 作品開啟、重新命名、副本、可還原垃圾桶、原子存檔、15 秒自動保存、離開與關閉前保存。
- 畫筆、螢光筆、油漆筆、中間點按時間排序、圓角平滑路徑、已提交幾何與即時筆跡分塊快取。
- 直線、箭頭、矩形、圓、菱形、五角形；三角形／四邊形逐點建立，曲線三點建立；完成切回選取，拖曳頂點或物件。
- 線條粗細、透明度、填色含 alpha、虛線型態、旋轉；屬性面板預設收起。
- 文字／便簽原地 TextBox，支援 IME；Ctrl+Enter／Esc 完成。輸入區滾輪不更動畫布。
- 圖片檔拖入或選檔置入，圖片與文字不被橡皮擦刪除。影像解碼失敗會顯示錯誤；遠端圖片不自動下載。
- 物件橡皮擦、局部筆跡切段、半透明懸停範圍與可調大小。
- 中鍵平移、一般滾輪平移、Ctrl+滾輪縮放；四邊停靠隨方向直排／橫排，工具不足空間可捲動。
- 可移動尺規、0.1° 輸入、對比自適應及自訂刻度色；起筆時鎖定尺邊，越過長度後仍沿同一直線投影。
- 同款斜向圖釘按鈕／列表／畫布標記，拖動、右鍵改名／刪除與視野導航。
- 圖層順序、鎖定、選取、右鍵複製／副本／貼上／刪除、Undo／Redo、筆記本翻頁及加頁。
- JSON／`.heiban` 可編輯文件、目前視野 PNG 匯出、作品真縮圖。

以上是程式實作範圍，**不代表全功能已通過 Windows 實機驗收**。待移植與驗收詳見 [工作清單](docs/WORKLIST.zh-TW.md)。Surface 筆壓已取樣保存，尚未接入可變粗細輪廓；沒有聲稱獨立 InkPresenter 執行緒、硬體防手掌誤觸或固定延遲／幀率。

## 建置

Windows 11 為主要平台，Windows 10 1809 為 API 最低基線，尚需另行驗收。x64、ARM64 分別建置；ARM 機用原生 ARM64 包。

工具：.NET 10 SDK、Windows SDK／WinUI XAML 編譯相依環境；完整 Visual Studio 桌面開發環境亦可。安裝檔需要官方 Inno Setup 6.7+／7。PowerShell 腳本使用 `pwsh` 7，在允許執行本地開發腳本的環境執行。

```powershell
cd windows
# 直接建置
 dotnet build HeiBan.Windows.sln -c Release -p:Platform=x64 -r win-x64
# 或 ARM64
 dotnet build HeiBan.Windows.sln -c Release -p:Platform=ARM64 -r win-arm64

# ZIP 與安裝檔
pwsh -File HeiBan.Windows/Packaging/Package-Portable.ps1 -Runtime win-x64
pwsh -File HeiBan.Windows/Packaging/Package-Installer.ps1 -Runtime win-x64
# 指定其他 Inno 編譯器位置
pwsh -File HeiBan.Windows/Packaging/Package-Installer.ps1 -Runtime win-arm64 -IsccPath 'C:\Tools\InnoSetup\ISCC.exe'
```

輸出僅在 `windows/dist/`，暫存僅在 `windows/.staging/`，每個包附 SHA-256。腳本會在 publish／ISCC 失敗時停止，不將不完整包標為成功。不內建示範作品。MSIX 與程式碼簽章列在後續發行清單；目前沒有正式簽署版本。

開發資料隔離可設定 `HEIBAN_WINDOWS_DATA_DIRECTORY`，例如指向暫存資料夾。這個環境變數只影響 Windows。

## 架構與進度

- [架構決策](docs/ARCHITECTURE.zh-TW.md)
- [移植、開發與驗收清單](docs/WORKLIST.zh-TW.md)
- [建置記錄](docs/BUILD_STATUS.zh-TW.md)
