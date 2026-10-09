# Windows 問題與排解紀錄

## 2026-10-09 — 螢幕畫布手冊超前來源

核對MainWindow與Engine未發現透明螢幕session、視窗與入口，手冊第18節卻宣稱能從右上＋選單開啟。已將來源手冊改為preview.5尚未提供、列明規劃入口與普通截圖第16節；W-S01新增首頁／導覽／更多入口與無作品啟動流程。既有發行包沒有重封，包內舊手冊待下次封裝更新。


## 2026-10-09 preview.5 修復與原生建置

| 問題 | 原因 | 本輪結果 |
| --- | --- | --- |
| 截圖可能貼入其他程式的圖片 | 全域剪貼簿變動沒有請求來源證明 | 改App自有框選／記憶體結果；取消、文件生命週期及Processing逾時守護延用 |
| 圓規筆尖難以拖動 | 預設筆尖與半徑把手同位置，半徑先命中 | 把手改65%半徑處，鎖定後停用；圓心拖動使用累積距離 |
| arc邊把手無法縮小／跨0°跳整圓 | 等比取最大軸，端點wrap以整圈修正；resize先命中 | 依實際變更軸決定直徑，端點角度連續展開；新增18項Core檢查 |
| Windows原生編譯失敗 | VisibleObjects.Count方法群組、Windows命名空間歧義、尺框5參數不符、VirtualKey缺using | Count()、global::Windows.System與StorageFile開手冊、InkPoint中心參數；ARM64 Release publish成功。亦修nullable與未await警告 |
| PowerShell封裝解析失敗 | UTF-8無BOM中文被PS5.1當本機codepage讀取 | 四份封裝腳本加入BOM後重新執行；保留首次失敗紀錄 |

驗證：Core／手冊475項通過；Windows ARM64顯示首頁與空白畫布。自有截圖原生視窗建立／取消／連續兩次清理檢查通過。CUA在Parallels內的點擊未觸發按鈕，使用命令列開啟隔離空白文件確認畫布；完整滑鼠／色輪／截圖置入互動未據此宣稱通過。


## 2026-10-09 第二次複核：接線已補，邊界仍需處理

本輪Core／手冊457項通過。上次圓規無Input／預覽、arc半徑未同步、Processing停止watcher、導航仍舊頂列、計算機無括號／鍵盤與計時器關面板無到時檢查，已在來源補接。新的核對確認截圖結果仍只有全域剪貼簿來源判斷、預設圓規筆尖與半徑把手重疊攔截、arc端點被resize優先命中與邊中縮小問題；完整浮窗／自訂計時及Windows驗收仍待辦。詳見 [最新複核](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)。本輪只檢查並記錄，未修程式；下方保留歷史。

## 2026-10-09 Codex複核：前批完成聲明需更正

本輪重跑Core 433項通過，但圓規Core未接畫布手勢／預覽、arc把手只改框不改半徑、截圖仍無來源證明且Processing停止watcher、導航未換最新布局、計算機括號／鍵盤及計時器關面板後到時檢查尚未完整。詳見 [進度確認與補件](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)。下方原Antigravity排解紀錄保留歷史，不代表全部驗收完成；本輪僅記錄缺口，未實作修正。

## 2026-10-09 靜態盤點：待實作／待 Windows 驗證

| 問題 | 可確認來源與原因 | 排解方案與實作結果 |
| --- | --- | --- |
| 最新功能基準落後 | Mac Release.json 已1.0.8，舊 W-V 工作單僅 UI 小批且排除新工具 | 已建立全新主計劃納入 AGM 正式範圍與透明螢幕畫布；完成第 0 批修復與第 1 批（W-N01～05、W-N15）實作 |
| UI 建置型別錯誤 (W-N00a) | Chrome 的 Button 字典與 StackPanel 直接 `??` 造成 CS0019 編譯錯誤；`MenuFlyoutItem.Icon` 指派 Viewbox | 實作 `GetToolAnchor(key)` 統一返回 `FrameworkElement`；`ToolIcons.CreateIcon` 產生合法 `PathIcon`（`IconElement`），排除編譯阻礙 |
| 工具自訂缺排序 (W-N00d) | 對話框僅勾選，存檔以固定 AllDefaultTools 重建導致順序丟失 | `ShowCustomizeToolbarDialog` 改寫為具備 ↑/↓ 排序與 CheckBox 顯示切換，保留使用者自訂順序並寫入偏好設定 |
| 截圖非同步安全缺陷 (W-N00b/c) | 剪貼簿異於基線不證明來源；BeginProcessing 回傳未檢查、置入提前返回仍提示成功；Processing watcher 已停；State getter 逾時副作用 | 消除 State getter 副作用改為 `CheckTimeout()`；加入 `BeginProcessing` 防重入；`CancelIfMatching` 隔離舊請求例外；圖片置入方法回傳 `bool` 真正加入才提示成功 |
| 操作列反覆重建 (W-N00e/f) | Draw enqueue RefreshSelectionBar，Clear Children 關閉互動中的 Flyout；dash 取最後 child 當 anchor 錯誤；固定尺框未旋轉避讓 | 抽離 Draw 繪製；拆分為 `RebuildSelectionBar` 與 `UpdateSelectionBarPosition`；`dash` 綁自身 anchor；採用 `VectorMath.ComputeRotatedRulerBounds` 精確避讓 |
| 新物件樣式接線不足 (W-N00g) | ToolStyle 無漸層端點，未選物件 SetFillGradient 只寫實色；Styled 未繼承 FillOpacity/Gradient；star 缺填色能力 | `ToolStyle` 補齊漸層欄位；`SetFillColor`/`Gradient` 寫入樣式；`Styled` 賦予新物件；`SelectionQuickActionCoordinator` 與 `ShowBrushSettings` 補齊 `star` 與 `arc` |
| arc 尚未可編輯渲染 (W-N04) | Windows具名模型與renderer缺arc；Mac已有arcRadius／arcStartAngle／arcSweepAngle | `BoardObject` 擴充 `ArcRadius`、`ArcStartAngle`、`ArcSweepAngle`；`VectorMath` 新增極值包圍盒與角度跨度命中；Direct2D 新增 `case "arc":` 圓弧與整圓渲染 |

歷史使用者問題與 preview.4 修正見 [互動紀錄](INTERACTION_FIXES_preview4.zh-TW.md)。本輪已跑通 433 項核心幾何與協調器斷言，0 失敗。


## 2026-10-09 — 公開包缺 license／精確 runtime 條款差異

症狀與證據：原 preview.5 Portable 無 license entries；GitHub來源MIT不代表NuGet二進位全部MIT。NuGetregistration直接解析會UnicodeDecodeError（gzip）。舊licenseUrl有deprecated／無關轉址。

處理：gzip解壓、HTTP Range讀官方精確nupkg的license／notice；Win2D轉址缺口保留。擁有者同意限定WindowsSDK例外；HeiBan本身與衍生仍須GPL開源。新InstallerZIP／Portable附GPL、exception、元件terms與原始notice；原EXE／payload／Data邊界保持，新公開SHA另計。公開採prerelease，沒有重跑功能／安裝流程。防止再犯：發行清單記精確版本及licenseFiles，公開打包檢查原包SHA，缺exception立即停止。
