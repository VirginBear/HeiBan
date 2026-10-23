# Antigravity 開發進度與 Mac 操作邏輯核對

日期：2026-10-23（Asia/Taipei）。核對基準：公開main `05ce02d`。本輪是來源與既有成品審視，沒有重新編譯或操作App。

## 後續實作（同日，使用者GO授權）

L01–06已在本機來源實作，仍以實際互動驗收為完成邊界。指南採Mac v3及成功後marker／防覆寫；十語供應來源與資產納入Git範圍；工具設定改單一engine狀態與固定host，圖示／圖文／More共用命令；圓擦改獨立預覽、放開交易及線段圓裁剪；螢幕移除重複展開清空。版本維持1.0.16，build20261023.1。證據、困難及尚待項目見[日誌02](logs/2026-10-23/02.zh-TW.md)。下列保留核對時05ce02d的原始發現，不改寫成實機故障重現。

## 結論

Antigravity確實完成兩筆Mac實作提交：`c1b8745`及`05ce02d`，不是只有報告。Mac目前為 **1.0.16 / 20261022.1**，與Windows產品1.0.16對齊；本機與origin/main在fetch後ahead/behind皆0。**主要操作已移植，但仍不能標為「全部同步完成」或「健康度清零」**，下列缺口由來源及資產追蹤確認，尚未執行UI故障重現。

依使用者最新回饋，Mac流暢度目前不是主要問題。下一步優先維護一致、可發現、可取消及不丟失內容的操作規則。Windows的效能調查留在Windows；相同操作結果可以使用各平台適合的實作。

## 1. 已核到的進展

| 項目 | Mac來源現況 | 證據／界線 |
| --- | --- | --- |
| 版本與來源 | 1.0.16 / 20261022.1；兩筆Mac提交皆已推送origin | 工作區開工乾淨；本輪只新增核對文件 |
| 工具列預設與遷移 | 新設定27項工具、圖示與文字、常用增加筆刷／線型／清空；revision遷移 | ToolbarPreferences；仍需既有自訂設定實機往返 |
| 自由筆與磁鐵 | pen／highlighter／paint不吸附，幾何／曲線及圓規定位保留 | DrawingReferenceGeometry、CompassOverlayView |
| 連續畫圖 | 自由筆與停筆轉形不自動掛選取框；曲線完成保留曲線工具 | BoardEngine+Drawing；不是整體筆尖延遲量測 |
| 橡皮擦與圖形選單 | 板擦長軸80%、貼圖／輪廓共同變換；圓擦5pt補間；兩畫布九宮格 | 資料保護與精確切割仍有下列缺口 |
| 自適應工具列 | 隨分頁工具數調寬、左／頂固定錨點、圖文磚熱區 | 純幾何斷言不能代表所有原生按鈕／popover可操作 |
| 防閃退改動 | More移除重複popover元件、筆刷預覽固定252×84、換頁關閉暫態面板 | 有具體來源；同時產生隱藏設定入口缺口，見L04 |
| 操作指南入口 | 首頁首次建立與手動開啟；既有包含10語、25圖釘、120物件資產 | 資產追蹤、平台文字及開啟安全未完成，見L01–03 |

## 2. 已發現的缺口與接續工作

以下是靜態來源結論／風險，不冒稱已在UI重現。P1優先處理資料保護／核心操作，P2處理可交付與一致性。

### L01 / P1 — 開啟操作指南可能覆寫使用者練習

位置：[HomeView.swift](../../Sources/HeiBanMac/Views/HomeView.swift)，`openQuickStartGuideBoard`（231–238行）。每次先從bundle讀範本、更新時間並以原固定ID `library.save(doc)`，再開作品；沒有先找使用者已修改的同ID指南。當目前工作階段不是該指南時，存在把練習內容改回範本的路徑。既有備份或可恢復，不能因此允許覆寫。

首次建立的`ensureQuickStartOnFirstLaunch`（213–228行）也用`try?`忽略解碼／寫入錯誤，再照寫marker；缺資產或磁碟失敗後可能永遠略過自動建立。

- [ ] 入口先開既有可編輯指南；建立全新範本使用明確入口與新ID，不能偷偷覆蓋。
- [ ] 只在作品已存在或成功落盤後寫marker；失敗回報並允許重試。
- [ ] 保留既有固定ID相容與刪除不重建規則，不直接遷移／刪除使用者指南。

### L02 / P1 — Mac指南仍是Windows操作說明

位置：`macos/Sources/HeiBanMac/Resources/Guides/QuickStart-*.heiban`。本機正體中文供應資產含`Ctrl+S`、`Win+Shift+S`、`Ctrl+Alt+Q`、`%LOCALAPPDATA%`、Portable資料位置與桌面PowerPoint必要條件。Mac實際使用Command、⌘⌥⇧D／X等螢幕快捷鍵、Application Support及Keynote轉檔。十語HTML另有Mac內容，不代表新可編輯指南已Mac化。

- [ ] 建立Mac自有指南來源／生成流程，保留25章節與可操作練習，把快捷鍵、截圖、退出、儲存、匯入及更新規則逐章換成Mac實際入口。
- [ ] 十語逐一核對平台詞與快捷鍵，不只替換Ctrl字樣；不覆寫已匯入作品庫的使用者指南。
- [ ] 這是說明內容的操作正確性，與使用者文件跨平台相容分開。

### L03 / P1 — 十份指南在本機App，卻沒有進Git

根[.gitignore](../../../.gitignore)第15行忽略所有`*.heiban`；Mac沒有例外。`git ls-files macos/Sources/HeiBanMac/Resources/Guides`只有HTML與manifest；`git check-ignore -v .../QuickStart-zh-TW.heiban`命中該規則，其他九語相同。Mac也沒有在建置時生成它們的腳本。Windows已有自己限定於Assets/Guides的例外。

因此目前這台電腦的舊包包含十份資產，但重新clone及建置時會缺失；指南入口可能靜默無反應。既有runner 51.8又使用`/Users/bear/Desktop/Code/HeiBan/...`絕對路徑及`try!`，且只檢查正體中文，不能證明另一台機器的十語資產齊備。

- [ ] 為Mac供應資產加入精確路徑例外並納入版本控制，或提交完整可重生來源與必經生成步驟；不放寬所有使用者`.heiban`忽略規則。
- [ ] 改可攜的資源定位；後續驗收要確認全10語，不以一份本機資產代表全部。
- [ ] 保持Mac資源在macos目錄，不讓App執行時依賴windows資料夾。

### L04 / P1 — 隱藏／換組工具的設定可能沒有呈現入口

位置：[ToolbarView.swift](../../Sources/HeiBanMac/Views/ToolbarView.swift)，`revealSettings`（220–236行）、`overflowToolRow`（493–544行）、color／eraser／shapes等popover。

More現在是輕量按鈕，避免重複掛載popover，方向合理。但隱藏工具不再在任何地方渲染帶設定popover的`renderToolItem`。More改分頁再設showColorPopover等旗標，不會令hidden工具變可見，結果仍沒有anchor。顯示但位於後組的工具，`revealSettings`也只設pageOffset=0，沒有定位至包含目標的組。雷射隱藏時使用本地showLaserSettings，也沒有其他固定host。

- [ ] 每種設定有單一穩定呈現host；顯隱、分頁和分組不決定設定是否能開啟。
- [ ] 保留防重複popover修正，不退回在所有overflow列重掛相同popover。
- [ ] 後續核對圖示／圖文、四邊、工具隱藏及後組的色圈／圖形／橡皮擦／雷射入口。

### L05 / P1 — 圓形橡皮擦尚未跟上取消／局部裁剪語義

位置：[BoardEngine+Drawing.swift](../../Sources/HeiBanCore/Engine/BoardEngine+Drawing.swift)的beginEraserSwipe／eraseAtWorldSample／endEraserSwipe；[BoardEngine.swift](../../Sources/HeiBanCore/Engine/BoardEngine.swift)的cancelTransientInteraction；[EraserToolEngine.swift](../../Sources/HeiBanCore/Engine/EraserToolEngine.swift)37–53行。

Mac圓擦仍在每個取樣直接改永久objects，待放開才建立Undo；通用取消清理pointerGesture卻沒有回復圓擦物件、清理交易累積或結算。下一筆begin會清空累積，存在取消後留下修改但沒有對應復原交易的路徑。不能把10/17的獨立「板擦」預覽當成圓形橡皮擦也已隔離。

局部擦除只檢查既有取樣點是否落在圓內；例如線段兩端都在圓外、線段中間穿過圓時，hasHit仍false。5pt插補的是擦除游標，不會補齊稀疏筆跡的線段相交判定；旋轉筆跡的世界座標裁剪也需補齊。

Windows已在其來源建立圓擦隔離preview、背景順序佇列與取消／generation拒收；Mac需要同步操作結果，不必因而複製其16ms worker或重寫Mac renderer。

- [ ] 圓擦使用隔離預覽，放開一筆Undo；Esc／capture lost／換作品明確丟棄未提交變更。
- [ ] 用線段／圓相交切割並保留交點、壓力、未知欄位與旋轉後幾何；圖片／文字／便簽／鎖定與其他頁受保護。
- [ ] 明確定義保存、Undo與退出遇到未完成／剛完成擦除的規則；不讓中途修改靜默落盤。

### L06 / P2 — 全磚操作與按鈕命令再次分成兩套

位置：[ToolbarView.swift](../../Sources/HeiBanMac/Views/ToolbarView.swift)的triggerToolTileTap（383–434行）與renderToolItem。新全磚點擊複製switch；dock、undoRedo落到default break，雖其內部Menu／按鈕本身能用，但文字／空白熱區沒有相同動作。後續新增功能需同步兩套，很容易分歧。

- [ ] 共用工具動作／設定策略；Menu及複合Undo／Redo明確定義熱區，避免整磚承諾與實際不同。
- [ ] 與L04一起處理，保持一個命令來源與一個設定host。
- [ ] 螢幕clearAll已開放進catalog，但宿主仍有固定尾端clearButton；另核對預設是否出現兩個清空入口，收合／展開規則需一致。

## 3. Windows順暢度的現況與Mac邊界

Windows10/22紀錄有真實UI心跳採樣P95 113.21ms、max673.92ms；這不是筆尖端到端延遲，也不代表已確定全部成本比例。後續已加入wet raster重用、磁鐵增量索引、圖釘快取、板擦及圓擦背景批次、更多耗時scope。最新候選尚待同條件新採樣，不能僅由build成功宣稱已變順。

Windows Store1.0.16.0的x64＋ARM64 bundle已完成；文件狀態是待使用者上傳，不能當作已通過商店認證或已上架。[Windows目前狀態](../../../windows/docs/CURRENT_STATUS.zh-TW.md)／[圓擦與工具列](../../../windows/docs/ERASER_TOOLBAR_ALIGNMENT_2026-10-22.zh-TW.md)。

Mac依使用者回饋先保留SwiftUI／AppKit原生路徑；只同步一致的顯示、點擊、取消、完成、復原及存檔結果。性能改動須有Mac自己的瓶頸證據。

## 4. 這次核對的證據界線

- 本機和GitHub來源一致，開工乾淨；本輪只改記錄文件。
- 既有Mac App metadata為1.0.16 / 20261022.1，嚴格codesign驗證exit0。
- App及.build產品UUID相同：`64F0F6DD-D571-3953-9EA9-8F9EB2AD1FF0`；不等於本輪重新從乾淨checkout重建。
- App執行檔SHA256：`838bc1d5088fbdb99ac59c952ec050e31fa826f1364dc235a7d51b42efbbb78a`；包內十語QuickStart齊備，與Git漏資產是兩件事。
- Antigravity既有日誌記載1,862斷言、407個UI字串與十語詞庫檢查通過；本輪未重跑。開發入口的1,858為較早數字，已改連結最新核對。
- 未重編／啟動App、未執行測試套件／UI／多螢幕／性能量測／故障注入；來源分析的風險與前批報告分列。

## 5. 接續順序

1. **先保護內容**：L01指南不覆寫、marker成功條件；L05圓擦取消與Undo交易。
2. **補可交付性與說明**：L02十語Mac化、L03供應資產入Git／可重建。
3. **統一使用入口**：L04單一設定host及分組定位、L06共用命令與完整熱區。
4. **再做實際操作確認**：以一般／螢幕畫布、四邊工具列、圖示／圖文、既有自訂／隱藏設定、保存及Undo往返確認結果。未執行的項目不先標完成。

本輪不進版、不改Windows、不發布新包；仍使用現有1.0.16作下一批修整基線。詳細過程見[日誌](logs/2026-10-23/01.zh-TW.md)。
