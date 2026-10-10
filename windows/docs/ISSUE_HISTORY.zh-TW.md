# Windows 問題與排解紀錄

## 2026-10-10 — 公開封裝／GitHub發布

首輪新手冊比對KeyError，ZIP使用Windows反斜線而查詢用斜線，已正規化entry索引及安全路徑；重跑保留原entry／EXE逐byte、PE／手冊／無Data檢查通過。draft target使用短SHA回422，改完整commit後成功；draft尚無公開tag endpoint回404，透過release清單／ID核對，publish後tag endpoint正常。新版7assets遠端digest／size及公開HTTP200後才刪舊5下載，源與舊歷史文本保留。


## 2026-10-10 — preview.5：右鍵阻斷物件選單

症狀是螢幕右鍵直接變「操作」，無法就地調整／複製／刪除。確認Objects.ScreenRightClick直接SetDrawing(false)，源於preview.4當時要求，並非命中或剪貼簿失效。依最新指示改命中物件ShowChromeFlyout，空白不切模式；保留工具列與快捷模式入口。原生驗證走實際OnPointer(right)，確認可用複製／刪除、多選文字保持、選取不新增Undo；驗證結果另記本輪報告。


right12p5-native的result／screen-result同輪success，實際路由／可用選單、多選保持與無新增Undo通過，四包安全交付Current1.0.12.5。CUA右鍵／普通工具列點擊均未可靠反映狀態，不當作實體驗收；保留此限制，不推定是新右鍵邏輯錯誤。

## 2026-10-10 — preview.4 螢幕物件與續編輯

色圓／dash只改預設、Capturecallback寫主作品、右鍵先攔成物件選單，已依最新使用要求改為選取物件編輯／截圖留screen／右鍵直接穿透；更多保留物件操作。首頁原None＋ItemClick，缺直覺選取；改Extended／Multiple、DoubleTapped及批次垃圾桶。

r1填滿Undo檢查讀Selected，但Core Restore會清選取，native helper保留仍存在ID後修正。r2大曲線局部畫面失敗，down從舊選取改空白時沒有清舊框的damage，已補；舊大曲線測試座標非實際曲線，改端點並assert不是marquee。r3全套通過，失敗證據保留。CUA click回-10005 noWindowsAvailable，未宣稱硬體點擊通過。

最終36預覽／收筆畫面逐byte相等；圖形／框選傳輸減少99.13%，原生同步中位24.7323→1.824ms；不是硬體端到端延遲，完整實機仍待驗收。

## 2026-10-10 — 1.0.12-preview.3 操作問題

確認的原因：Wheel普通分支平移；普通select缺marquee；螢幕框選固定Intersects；多點曲線hover漏Invalidate；ActivateTool載入工具舊色／dash；樣式圖示固定dash；PathIcon open path樣本不可見；模式圖示沒明確尺寸／中段center量測；截圖只畫白框；換工具重複Cancel／native模式更新；快捷列signature未含model引用且不更新樣式。已按本輪稽核修正。

原生兩次色圓檢查失敗closed，Activate單獨未解決；測試先讓連續關閉窗口的焦點事件完成再開面板後r3／r4success，保留兩個失敗result。CUA同時兩個版本時一次點擊沒有可靠反應，沒有把它算作硬體驗收。最終Core680、ARM64原生與PDF strict通過；首輪包因收尾新增修正不能部署，重封最終76來源。完整硬體／x64實機／Installer升級仍待驗收。

## 2026-10-10 — 整體操作卡頓

- 部署核對首輪未指定--current-user，以SYSTEM執行GetFolderPath(Desktop)為空，Join-Path退出1；已完成的payload核對不可視為捷徑檢查通過。改當前使用者重跑，版本／唯一程序／捷徑與549payload逐SHA全部通過。

- 第一輪封裝開始後才更新README，ARM64 Portable內說明仍p1；增加包內README逐byteassert後失敗，未部署。從同71檔來源以既有Portable腳本重封ARM64，重新核對四包。此檔時序不影響程式／HTML手冊版本；不直接略過驗證。
- Selected getter每個物件predicate又讀SelectedId，反覆搜尋整份文件；改單次PageObjects搜尋，100次／600物件461.2657→0.6635ms。
- 每次hover重繪整scene／文字重新排版；拆GPU committed scene與暫態overlay，文字style／span快取；300物件原生中位24.6737→1.0815ms，9畫面byte一致。
- 長筆跡拖動每事件逐點JSON clone／serialize；改preview位移，收筆一次提交；40事件2,000點92.7712→0.0142ms，commit0.633ms。壓力／傾角／未知欄位／Undo保持。
- autosave可在手勢與切文件間完成，revision也可能造成假Undo；DocumentEpoch／generation守護，transaction跟隨revision；screen timer避開draft／gesture。縮圖writer序列、舊revision跳過避免舊圖覆新。
- 偏好滑桿頻繁落盤、垃圾桶同文件兩次decode；400ms合併／worker落盤、一次讀metadata／舊垃圾桶對話讀取worker。
- 新screen performance helper少Engine using：CS0103 ObjectHandles未找到，衍生WMC1509／9999；補命名空間，最後ARM64 publish成功。驗證強制top／expanded，不依QA持久偏好猜初始尺寸。
- 第一輪快取P95 27.0384ms，最終1.6779ms，VM變異尚存在；完整硬體／IME／多螢幕仍未完成。見本輪性能稽核及原始JSON。


## 2026-10-10 — 1.0.12 介面與文字修正

- 左右工具列即使要求64 DIP，原生結果仍262px（200%）。只設定PreferredMinimumWidth／Height=1未解決；先收緊檢查以免誤報。SetWindowPos加入SWP_NOSENDCHANGING避免caption追蹤寬度干預，最後實測128×1376px通過；保留失敗JSON文字紀錄。
- 導入Shapes造成Path歧義CS0104，並衍生XAML WMC1509／9999；改Ellipse單一別名後原生編譯成功。
- 草稿右鍵開面板會轉移焦點，LostFocus提交會使面板修改丟失；取消LostFocus自動提交，改由明確完成或硬操作提交。新文字完成前不進文件，Esc取消不增加永久物件。
- 只選取未拖動也呼叫MoveSelection，更新UpdatedAt並建立無效Undo；只在座標改變時移動。原生Shift雙文字選取／右鍵保留兩物件／選取不加Undo／批次樣式Undo通過。

## 2026-10-10 — 本輪原生排解與驗證界線

| 症狀 | 原因／嘗試 | 修正／證據 |
| --- | --- | --- |
| 圖層名稱像亂碼 | 原本直接顯示UUID／英文type並拆展示字串找ID | typed layer row＋中文類型／內容／Name；Core與原生資料結果核對 |
| 原生第一次建置失敗 | LoadCursor缺PInvoke | 補Win32宣告後成功；首次失敗log保留 |
| PDF程式編譯失敗 | WinRT投影屬性為ShouldPrintBackgrounds | 改正複數名後原生編譯成功 |
| RichText／preferences新檔編譯問題 | TextDocument命名空間及多個屬性以逗號宣告不合法；Validation缺Models using | 分別修正，最終ARM64／x64建置通過 |
| PDF能由Poppler開卻strict parser失敗 | 原稿raw尾記在%%EOF之後，末尾不再合法 | incremental stream/xref；pypdf strict解析、中文字／向量及原稿4物件通過 |
| SVG底線未呈現 | text-decoration寫成underline none，CSS不合法 | 只組成有效decoration tokens；原生PDF視覺確認底線 |
| 高DPI螢幕控制列可能裁切 | AppWindow.Resize收實體像素，原數字當DIP | width/height乘DPI，3024×1822桌面控制列已查看 |
| prlctl -File／偶發exec失敗 | 引號或工具Invalid argument；直接傳字串不可靠 | UTF-16LE EncodedCommand及UTF8 BOM腳本；備份exec一次重試成功 |
| 模式切換後控制列可能被透明輸入層覆蓋 | SetWindowPos重新提升TOPMOST | SWP_NOZORDER保持順序，追加原生HWND次序檢查 |
| 螢幕工具列太大、空白太多 | 初版固定1080×210 DIP、標題／大文字按鈕／狀態各佔一列 | 依使用者Mac對照改680×80 DIP兩排，可收成680×48；另存／設定／手冊／清除收更多，原生1360×160px／收合1360×96px確認，淺色半透明外觀已查看 |
| 螢幕作畫不順 | 全桌面22MB讀回／複製，33ms排程，未落筆hover仍重繪 | committed快取、局部讀回／DIB／dirty rect、16ms與訊息座標；80樣本35.62ms→0.83ms；18組像素等價與雷射消退通過 |
| 縮小控制列後設定面板放不下 | ContentDialog限制在80 DIP root | 改不限制root的Flyout；原生IsConstrainedToRootBounds=false通過 |
| 工具列背景灰暗 | Window預設dark，只有內層light | 最外層Border RequestedTheme.Light，淺色Acrylic背景；實際查看文字對比 |
| 右鍵取消作畫後無法操作既有註記 | 舊路徑無條件切穿透 | 命中物件則保留作畫並開相容複製／副本／刪除／鎖定／層級選單；native命中與交易／Undo通過 |
| 全清除需進更多與確認 | 舊Clear ContentDialog | 主列垃圾桶及Ctrl+Alt+K立即清空所有物件／雷射，一筆Undo；native清空與ID完整復原通過 |
| 首頁多選切換COMException 0x8000FFFF | None selection mode的SelectedItems為不可修改collection | 只在Multiple／Extended時Clear，再切mode；原生收藏與全選／退多選通過 |
| 備份雜湊報missing但host檔案存在 | PowerShell5.1的Resolve-Path受MAX_PATH限制，UNC垃圾桶最長>260 | 最短備份名vm/c1；32個檔案逐SHA驗證成功，原Current未替換前不刪除 |
| Parallels點擊沒有觸發按鈕 | CUA只得到外層AX且截圖只看到hover，原因未確認 | 不把CUA嘗試當全互動驗收；隔離合成fixture呼叫真實native APIs，手動硬體試用仍待 |

包裝log由Windows PowerShell5.1 Tee-Object以UTF-16寫出，收尾轉UTF-8便於閱讀。失敗與舊文字紀錄留在build-logs/archive-before-1.0.8；不含使用者作品正文。

## 先前紀錄（歷史）


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
