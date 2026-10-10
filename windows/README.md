# 黑板 · Windows 原生版

**最新本機試用版：1.0.12-preview.6（2026-10-10）**。本批加入 GitHub 背景更新；公開 GitHub 下載仍為 1.0.12-preview.5。以 Mac 1.0.12／20261010.4 的現行可操作功能為基準，Windows 使用 C#／.NET 10、WinUI 3 與 Win2D。主畫布為原生 Direct2D；PDF 匯出單獨使用 WebView2 列印。

[目前狀態](docs/CURRENT_STATUS.zh-TW.md) · [功能對照與驗證](docs/MAC_1_0_12_PARITY_2026-10-10.zh-TW.md) · [建置紀錄](docs/BUILD_STATUS.zh-TW.md) · [離線手冊](HeiBan.Windows/Assets/HeiBanUserGuide.html) · [開發日誌](docs/DEVELOPMENT_LOG.zh-TW.md)

## 開啟與更新

| 類型 | 最新檔案 | 資料位置 |
| --- | --- | --- |
| ARM64 免安裝版 | `dist/HeiBan-Windows-Portable-1.0.12-preview.6-win-arm64.zip` | 解壓後程式旁的 `Data/` |
| x64 免安裝版 | `dist/HeiBan-Windows-Portable-1.0.12-preview.6-win-x64.zip` | 解壓後程式旁的 `Data/` |
| ARM64／x64 安裝版 | `dist/HeiBan-Setup-1.0.12-preview.6-arm64.exe`／`...-x64.exe` | `%LOCALAPPDATA%\HeiBan\Windows\` |

Parallels 的 Windows 11 ARM64 使用 ARM64 包。Portable 必須完整解壓到可寫入的位置，雙擊 HeiBan.exe，不要只複製 EXE。退出程式後才拔除隨身碟。升級前關閉舊程式，備份整個 Data，再複製到新版資料夾；作品、垃圾桶、縮圖與設定一起保留。

.NET 與 Windows App SDK 自包含，普通畫布無需另裝 SDK。PDF 匯出需要 Edge WebView2 runtime；未安裝時會顯示錯誤，不影響其他匯出。安裝版每使用者安裝，不需管理員；可選桌面捷徑及 .heiban 開啟方式，解除安裝保留作品。

本版僅在本機封裝，尚未發布至 GitHub。現行 [1.0.12-preview.5 公開下載](https://github.com/VirginBear/HeiBan/releases/tag/windows-v1.0.12-preview.5) 保持原發行狀態。

## 自動更新（preview.6 起）

首頁「關於黑板 → 更新設定」或畫布「更多 → 檢查更新與更新設定」。GitHub 版預設在啟動約十秒後背景檢查，使用期間每六小時再檢查；可關閉背景更新／預覽版本，手動檢查。依 Windows tag、版本、x64／ARM64、Installer／Portable 篩選，下載後核對 GitHub asset digest 的 SHA-256 與大小。舊版需先手動安裝一次 preview.6 或更新的帶更新功能版本。

正常關閉時先保存作品與螢幕註記，獨立 helper 等待程序退出；同一安裝尚有視窗時延後，不強制關閉、不自動重開。安裝版使用 Inno 靜默升級，Portable 只更新 `update-files.json` 宣告的程式檔，保留 Data／portable.dat／未知檔，普通失敗會還原已移動程式檔。關閉自動更新後不自動套用暫存包。下載中断／離線不阻止使用；更新結果與暫存在 `%LOCALAPPDATA%\HeiBan\Updates\` 的個別安裝目錄。更新期間請勿拔除儲存裝置；中斷電源或安裝失敗需使用官方包修復，備份暫存不自行刪除。

MSIX 有 package identity 時交由 Microsoft Store 更新，不執行 GitHub 替換。商店 MSIX 免費簽章／託管；GitHub SHA 驗證不是 Authenticode，獨立 EXE 首次執行仍可能有系統提示。此批不產生 MSI 或 MSIX、不操作 Store 帳號或發布；商店準備需實際 Identity Name／Publisher 與封裝驗收。[本批紀錄](docs/AUTO_UPDATE_2026-10-10.zh-TW.md)。

## 更新發行契約

發布 tag `windows-v<版本>`，版本為 `major.minor.patch` 或 `major.minor.patch-preview.N`；Release 附正確架構的 `HeiBan-Setup-<版本>-<arch>.exe`（建議直接上傳）及／或原 Installer ZIP、Portable ZIP。GitHub 必須提供有效 `sha256:` asset digest；只 push 原始碼不會發送更新。Portable 保留完整 `update-files.json`，不要手動改動程式包內容後沿用舊清單。未經發布的 preview.6 不會讓既有用戶自動更新。

## 本次操作修正

- 滾輪以鼠標位置縮放；中鍵／空白鍵拖曳平移。
- 選取工具由空白處拖框：左往右只選完整包含的物件，右往左選碰到的物件；Ctrl／Shift 可追加。
- 圖釘使用圖釘圖示；雙擊圖釘或名稱，在畫布直接改名，Enter 保存、Esc 取消，可復原。
- 曲線第一點後隨滑鼠預覽，第二點後預覽完整彎曲；第三點提交一次復原。
- 顏色與線條可先選再切畫筆／圖形；線條按鈕與各選項顯示實際樣式。
- 螢幕直列圖示固定尺寸，中段只捲動；色圓、線條、清空與結束固定可用。浮窗允許直接點擊工具列切換。
- 截圖框外灰霧、框內原始清晰，完成直接成為圖片物件。

[本次修正與驗證](docs/WINDOWS_INTERACTION_REVIEW_2026-10-10.zh-TW.md)

## 本次流暢度改善

減少普通畫布重複重繪與中文字排版、修正選取物件的重複掃描；長筆跡拖動先預覽，收筆才寫回。保存／匯入移到背景，縮圖延後到操作空檔；偏好滑桿合併寫入。原生隔離300物件量測已減少重繪耗時；詳見性能稽核，這是同VM渲染量測，並非硬體輸入延遲。

[性能稽核與驗證](docs/WINDOWS_PERFORMANCE_REVIEW_2026-10-10.zh-TW.md)

## 本次功能

- Mac配置的作品庫側欄、收藏、格式／排序、三種卡片尺寸、單擊選取／雙擊開啟、Ctrl／Shift多選及批次垃圾桶／還原；左下浮動視角／頁面控制。
- 圖層顯示中文類型、文字摘要或自訂名稱；支援改名、排序、鎖定、隱藏與多選，物件 UUID 只作內部身份。
- 畫筆／螢光筆／油漆筆、八種筆刷選擇、色輪與填色；幾何、曲線、A/B 端點、射線；圖片縮放、旋轉與非破壞裁切。
- 框選／Ctrl 或 Shift 多選／套索，批次移動、複製、貼上、樣式及刪除；遮題膠帶與揭示；雷射三模式及暫態消退。
- T 螢幕文字、Enter 換行、Ctrl+Enter 完成、Esc 取消、雙擊編輯；畫布／螢幕共用文字右鍵設定，字級8～144、顏色、字型、對齊、透明度及粗斜體／底線，只修改有調整的欄位，支援多選一筆復原。繁體中文文字、局部富文字、標記色、六種便條紙；浮動計算機、碼表、自訂倒數。
- 尺規支點可到劃線兩端、圓規及圓弧端點、圖釘；工具列自訂與停靠、頂部自動隱藏、視角鎖定及多頁管理。
- 截圖由 App 自有區域框選，直接置入畫布成為可編輯圖片，不另存截圖資料夾。Win+Shift+S 的外部截圖仍需 Ctrl+V。
- 「我的螢幕就是我的畫布」由首頁、右上螢幕圖示、更多工具或 Ctrl+Alt+A 啟動；820×60 DIP 單排半透明工具列、64×688 DIP 直式圖示列、四邊停靠與中段捲動、獨立280 DIP色彩／粗細／透明度面板、透明作畫／穿透操作、獨立保存恢復、透明 PNG／原稿及截圖圖片直接留在螢幕畫布。右鍵物件開啟調整／複製／個別刪除選單，空白右鍵不切換操作；穿透由模式按鈕或 Ctrl+Alt+D 切換；選取後色圓／線條／填滿直接修改已完成物件；工具列垃圾桶或 Ctrl+Alt+K 一鍵清空，可復原。Ctrl+Alt+D 切模式，Ctrl+Alt+S 截圖，Ctrl+Alt+Q 結束。
- 三種畫布、作品庫、副本／垃圾桶、原子保存、JSON／.heiban；PNG／SVG／PDF／HTML 匯出，提供頁面全部、選取與視野範圍。

Mac 基準尚未交付的雲端／Google、協作、心智圖／表格／公式／畫框、外部 PDF／SVG 原稿編輯及文件多視窗仍未提供。八種筆刷使用與該 Mac 基準相同的平滑向量渲染，未提供材質物理模擬。Surface 壓力／傾角可保存，尚未接可變粗細輪廓。

## 驗證範圍

本輪核心與手冊 **700 項**檢查通過；原生 ARM64 Win2D／PDF／透明螢幕層與註記保存檢查通過。兩架構建置及包內檔案／版本／SHA-256 檢查見建置紀錄。這些不是完整滑鼠／觸控筆／混合 DPI／多螢幕操作驗收；x64 實機及安裝升級仍待試用。

Windows 11 為主要平台，Windows 10 1809 為 API 最低基線，尚需驗收。沒有正式簽章、自動更新或 Store 發行。

## 建置

在 Windows 使用 .NET 10 SDK；安裝包需 Inno Setup 6.7+／7。平台來源及產物在 windows/，不編譯 Mac。

```powershell
cd windows
dotnet run --project HeiBan.Windows.Core.Tests -c Release
powershell -ExecutionPolicy Bypass -File HeiBan.Windows/Packaging/Package-Portable.ps1 -Runtime win-arm64
powershell -ExecutionPolicy Bypass -File HeiBan.Windows/Packaging/Package-Installer.ps1 -Runtime win-arm64 -IsccPath 'C:\Tools\InnoSetup\ISCC.exe'
# x64 使用 -Runtime win-x64
```

發行輸出 dist/，封裝暫存 .staging/，每包附 SHA-256。腳本檢查 HeiBan.pri、runtime、品牌資源與授權；不包含使用者作品。開發可設定 HEIBAN_WINDOWS_DATA_DIRECTORY 隔離資料。

## 授權與歷史

HeiBan 為 GPL-3.0-only，附 [限定 Windows SDK 例外](LICENSE-WINDOWS-EXCEPTION.txt)；衍生程式仍需提供對應原始碼。包內 Licenses/ 含完整 GPL、例外與第三方原始條款。

[preview.5 README 封存](docs/README_preview5_ARCHIVE.zh-TW.md) · [原開發工作單](docs/WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md) · [架構](docs/ARCHITECTURE.zh-TW.md) · [問題紀錄](docs/ISSUE_HISTORY.zh-TW.md)

本輪追加：螢幕物件樣式、原位置截圖物件、Shift水平／垂直直線、首頁多選刪除；本版依最新要求恢復右鍵物件選單，取消右鍵自動穿透；圖形／框選局部讀回與無手勢工具切換避免整屏傳輸。實際原生驗證與封裝以本輪BUILD_STATUS為準。
