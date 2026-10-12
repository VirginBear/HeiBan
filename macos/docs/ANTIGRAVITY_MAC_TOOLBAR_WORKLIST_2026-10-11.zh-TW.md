# 給 Antigravity：Mac 工具列追齊 Windows 的開發與驗收清單

## 2026-10-13 現況補齊（優先於下方歷史對照）

版本仍1.0.13 / 20261011.1，已於10/13公開預覽。最終10/12日誌09共用工具與指標命中實作已封裝；本次僅補文件，未新增驗收。下方10/11–12表格／固定尺寸是當時調查或歷史檢查，現行動態尺寸以ToolbarContentPolicy＋itemCount為準。

| 工作 | 目前進度 | 下一步 |
| --- | --- | --- |
| TB01–03 | 已實作；7198f11歷史独立複核1,642斷言／probe7項，後續日誌06另有1,752 | 不以舊數字當最终全部通過；草稿／失敗保存持續回歸 |
| TB04–05 | 動態格數換行／換欄、固定清空退出、收合與偏好已接線 | 四邊／短屏／負坐標／長清單實機 |
| TB06–07 | 共用ToolbarBrushSettings／曲線／圖層，選取樣式與無選取預設分離 | 混合值／锁定／Undo／跨session／曲線與拖曳實機 |
| TB08–09 | 共用圖示／More／文字T、面板與輸入疊層 | 所有popover、尺／圓規命中、四邊避讓／中文組字 |
| TB10 | 最終封裝32.93秒／簽章成功；公開asset核對完成 | 最終功能套件與全操作回歸尚未执行 |

詳[交接總表](development/MAC_DEVELOPMENT_HANDOFF_2026-10-13.zh-TW.md)與[最終共用日誌09](development/logs/2026-10-12/09.zh-TW.md)。以下逐項勾選保留歷史狀態，不代表本日新增测试。

以下為2026-10-12歷史快照；「不發布」指當時決定，後續公開預覽以本頁頂端為準。當時狀態：功能入口與核心檢查已有進度；**不是完整操作驗收完成**。使用者再現螢幕退出按鈕裁切，本批已修幾何並開始 App 操作核對。版本維持 1.0.13，不發布。

2026-10-12 複核：原先 1,713 項斷言只檢查核心狀態／預期常數，不能證明 SwiftUI 真實内容可達。TB04–10 的勾選先撤回完整驗收狀態；既有實作保留，依 [日誌06](development/logs/2026-10-12/06.zh-TW.md) 分項記錄實際操作。横列固定控制總寬212pt、高螢幕直列64×784pt、短螢幕雙欄84×496pt、收合横列284×60pt已修正。

範圍：只改 macOS。一般畫布工具列與「我的螢幕就是我的畫布」工具列分開驗收。

## 1. 為何需要這份清單

使用者實際感受是 Windows 工具列細節比較完整，Mac 應跟上。原 MAC-SYNC-03／04 有方向，但偏重螢幕列，沒有完整記錄主工具列預設配置、圖層入口、偏好遷移、選取後樣式修改、收合與狀態回饋。M21 修復與 1559 核心斷言通過只表示先前相容性缺口修好，不代表工具列追齊。

參考 HEAD `f960c78c6e1979c0d395b09ff8ab6139d9884074`；Windows tree `965e41d77a4528d108af300bc490a038223495bd`。這是本地已同步來源，不宣稱 Windows 所有硬體與 UI 都已驗收。

來源紀錄：

- [Windows 20 項操作調整](../../windows/docs/UX_ALIGNMENT_2026-10-11.zh-TW.md)。
- [Windows 後續工具列補強](../../windows/docs/UX_FEEDBACK_2026-10-11.zh-TW.md)：**覆寫前一份中段捲動方案，改為無捲軸換行／换列**；不能照舊方案開發。
- [原 Mac 同步清單](development/WINDOWS_SYNC_REVIEW_2026-10-11.zh-TW.md)：本清單細化03／04／06，圖層排序依賴05，發行證據依賴12。
- [原 ProDrafts 清單](ANTIGRAVITY_PRODRAFTS_WORKLIST_2026-10-09.zh-TW.md)：既有四邊、瘦側欄、色圈設定、拖曳不抖等要求仍有效。

## 2. 主工具列歷史對照（10/11來源）

| 細節 | Windows 本地來源 | Mac 本地來源 | 追齊目標 |
|---|---|---|---|
| 預設顯示量 | StreamlinedTools：select、pen、highlighter、eraser、ruler、shapes、layers、undo、redo；其餘進更多 | ToolbarPreferences.defaultActiveItemIds = 全部21項，預設無隱藏項 | 預設常用工具精簡，完整工具仍可達；保留使用者自訂 |
| 圖層工具 | layers 可見／更多／自訂，面板顯示時反白 | 圖層在TopNav更多；ToolbarPreferences無layers | 增加主工具列圖層入口與狀態，三個入口同一命令 |
| 新工具偏好遷移 | Normalize去重，layers兩份清單都缺才加入；已隱藏者不重新顯示 | 直接decode舊active/hidden，無相同Normalize | 新入口出現一次，明確隱藏／排序不被重置 |
| 直線延伸 | 保留extension舊資料，工具列／更多／自訂濾掉，屬性提供 | lineExtension仍定義並渲染Menu | 移入線段／箭頭的屬性，保留舊偏好相容 |
| 可自訂教學／導覽工具 | pins、compass、calculator、timer、viewLock同catalog | 在頂部導覽／更多提供，主catalog沒有這些項目 | 提供同等可發現性及可自訂入口，共用現有浮動面板，不建立第二套功能 |
| 四邊／拖曳 | 停靠／方向與偏好 | 已有局部drag state，放開才placeToolbar，左右直排 | 保留現有防抖設計；量測變更不得拖動中來回轉向 |
| 自適應尺寸 | 主畫布與螢幕列需分別核對；本地新增FlowPanel明確用於螢幕列 | 主列已有GeometryReader內容長度量測，超界ScrollView；並非完全固定長度 | 核對主列短視窗溢出，與精簡配置一起處理，不宣稱主列完全沒有量測 |
| 雷射再點設定 | 可見按鍵／更多同規則 | 可見／更多已實作再點設定 | 保留，驗證兩條路徑與四邊面板不裁切 |
| 色圈与物件設定 | brush選到物件時直接改該物件，依型別提供欄位 | 色圈主要改activeColor／activeStrokeWidth／activeOpacity；物件另走Inspector | 明確區分新筆刷／選取物件；顯示目前值／混合值；文字格式繼續集中右鍵 |
| 圖示／下拉間距 | 共用ToolIcons、狀態反白 | SF Symbols與MenuDisclosureLabel已有8pt間距；文字主按鈕已是T | 保留已完成的間距／T；圖層、圖釘、更多及新項目一致尺寸與命中區 |
| 儲存／視角鎖定 | 真實saving/dirty/draft/transaction決定勾號／虛線圓，上下鎖定同步 | 頂部saveLabel識別尚未儲存，但indicator一般分支仍綠點；下方有視角鎖定 | 固定尺寸、真實狀態、不誤報已存；同一viewportLocked更新所有入口 |

## 3. 螢幕工具列歷史對照（10/11來源）

| 細節 | Windows 本地來源 | Mac 本地來源 | 追齊目標 |
|---|---|---|---|
| 實際內容量測 | start/tools/end分段，工作區DIP扣除固定操作後量測；DPI只轉換一次 | AnnotationToolbarLayout優先820×60／64×784，再縮小；不是實際內容尺寸 | NSScreen.visibleFrame＋SwiftUI量測，不照搬DIP或像素數字 |
| 不夠長時 | ToolbarFlowPanel自動橫向換行／直向換列，移除工具ScrollViewer | horizontal／vertical ScrollView，中段工具可能藏起來 | 依可用空間排布全部工具；新增項目不能靠固定常數或隱藏捲軸掩蓋 |
| 側邊簡潔／固定操作 | 圖示、mode/start與brush/clear/close/end分段 | 已64pt窄欄／純圖示；上下60pt，色圈popover；側邊色圈仍在捲動中段 | 保留使用者要求的窄欄／純圖示；模式、色圈、清空、結束保持可達 |
| 曲線 | curve可見按鈕 | annotationTools無curve | 共用現有Core曲線命令與可編輯控制點，不能退化成靜態筆跡 |
| 圖層 | 按鈕／更多，選取／排序／鎖定／隱藏／改名 | 無圖層入口 | 綁當前螢幕engine，共用LayerPanel／交易；拖曳預覽依MAC-SYNC-05 |
| 調色盤 | 額外palette入口：8色、ring、hex、alpha | BrushSettings已有六色、粗細與alpha，沒有色輪／hex | 點色圈取得完整調色設定；更多也可開，不另常駐一整列 |
| 線型／填色 | dash、fill；brush依型別提供箭頭頭長／寬、直線延伸 | 無螢幕線型／填色入口，brush統一粗細／alpha | 線型／填色／填色alpha／漸層與箭頭大小依有效型別呈現 |
| 選取後修改 | StyleSelection修改已選取物件，交易合併 | controller.setColor／setWidth／setOpacity改所有session的未來筆刷樣式 | 已選取物件走當前engine的編輯命令；無選取才更新筆刷預設，不跨螢幕污染已選取物件 |
| 收合 | SetChromeCollapsed、更多收合／展開，偏好有Collapsed | 無收合入口／偏好 | 收合後保留作畫／穿透、清空、更多／展開、結束，不丟失工具與資料 |
| 保留既有功能 | 原生透明畫布、截圖、文字與橡皮擦 | 已有T、右鍵批次文字格式、再點橡皮擦／雷射設定、清空不退出、PNG儲存 | 必須回歸驗收；截圖動作差異另外說明，不默默改成Windows行為 |

## 4. 可交接的工作項目

### 第一批：入口與偏好／狀態（優先）

- [x] **MAC-TB-01 精簡主工具列与偏好遷移**（P1）。對應 ToolbarPreferences.swift、BoardEngine的載入／保存、ToolbarCustomizeSheet。提供常用預設與完整catalog；對新設定用精簡預設，舊設定保留順序／隱藏選擇。去重、合法ID及必需入口可達；用明確遷移規則，不在每次啟動覆寫。
  - 驗收：全新偏好／舊全顯示／自訂順序／明確隱藏圖層／重置預設／損壞資料都可開；重新啟動維持配置。舊21項全顯示不得硬改，使用者可由「恢復預設」取得精簡列。（7198f11當時獨立複核1,642斷言／Release probe7項，後續批次核心數字不代表完整UI；[複核報告](development/MAC_TOOLBAR_REVIEW_2026-10-11.zh-TW.md)）
- [x] **MAC-TB-02 圖層及教學工具catalog與統一命令**（P1）。主列補layers，圖釘／圓規／計算機／計時器／視角鎖定可自訂；線段延伸移出列／更多／自訂，原值仍在屬性使用。主列／更多／頂導覽同一命令；設定toggle同步反白。
  - 驗收：所有新增可見／隱藏路徑都可啟用；面板再次點擊可回收／呼喚；鎖定圖示一致；文字保持T，圖釘共用既有斜向圖示。（7198f11當時獨立複核1,642斷言／Release probe7項，後續批次核心數字不代表完整UI；[複核報告](development/MAC_TOOLBAR_REVIEW_2026-10-11.zh-TW.md)）
- [x] **MAC-TB-03 儲存回饋真實且固定大小**（P0）。對应TopNavView與既有Persistence狀態。消除尚未儲存卻落入綠點的分支；dirty／草稿／交易／寫入中／完成／失敗分別展示，固定槽位避免擠動。
  - 驗收：待存虛線圓、成功勾號、寫入中與錯誤能区分；失敗不報成功，不能以任何非錯誤文字當已存。連續編輯工具位置不變；狀態必須由真實寫入流程提供。（7198f11當時獨立複核1,642斷言／Release probe7項，後續批次核心數字不代表完整UI；[複核報告](development/MAC_TOOLBAR_REVIEW_2026-10-11.zh-TW.md)）

### 第二批：螢幕列排布與完整設定

- [ ] **MAC-TB-04 工作區內容量測与無捲軸換行／列**（P1；細化MAC-SYNC-03）。抽出核心共享佈局 `AnnotationToolbarLayout`，支援橫向寬螢幕（820×60 pt）、窄螢幕自適應雙列（600×96 pt）、極窄螢幕三列（450×132 pt）；直向高螢幕（64×784 pt 單欄）、短螢幕自適應雙欄（84×496 pt，徹底移除直排 `ScrollView`，杜絕任何工具被滾動遮蔽）；支援負座標多螢幕邊界安全防護與自動停靠判定。
  - 驗收：`HeiBanTestRunner` [測試 48] 橫向/直向/短螢幕雙欄/負座標邊界 15 項客觀斷言 100% 通過；全工具隨時可達，作畫模式／色圈／清空／結束始終可見。
- [ ] **MAC-TB-05 螢幕工具列收合／展開**（P1）。已實作 UI 偏好持久化；橫向收合尺寸 284×60 pt，直向收合尺寸 64×252 pt，展開時無損恢復 820×60 pt。收合列完整保留作畫／穿透、清空、更多、展開與結束按鍵。收合不觸發作品編輯交易或 Undo；維持四邊停靠與沿邊位置。
  - 驗收：`HeiBanTestRunner` [測試 48] 收合寬高、恢復全尺寸與持久化斷言全數通過；核心檢查確認保留命令；四邊收合實機可達待驗收。
- [ ] **MAC-TB-06 完整色輪與樣式面板**（P1；細化MAC-SYNC-04／06）。筆刷色圈彈窗提供自訂色彩選擇器、Hex 色碼輸入、最近使用色彩（最多 8 色去重置頂）、線條樣式（實線/虛線）、填色與填色透明度滑桿、漸層填色起訖色、箭頭頭部尺寸與線段延伸模式。嚴格區分「選取物件」與「全域筆刷預設」：有選取物件時僅更新當前 engine 的選取交易並支援單筆 Undo 復原；未選取時僅變更未來預設，絕不污染畫布；文字與圖片物件屬性受到型別安全保護。
  - 驗收：`HeiBanTestRunner` [測試 48] 樣式隔離、Undo/Redo、最近色 8 色佇列、虛實線切換、填色/漸層/箭頭/延伸與文字保護 29 項客觀斷言 100% 通過。
- [ ] **MAC-TB-07 螢幕圖層與曲線入口**（P1；圖層拖曳依MAC-SYNC-05）。螢幕工具列直接提供曲線工具入口，支援 Core 可編輯曲線與控制點陣列儲存；工具列直接新增圖層按鈕（Popover 呼喚共用 `LayerPanelView`，與更多選單入口同步），支援六點握把拖曳排序、單筆 Undo 復原；圖層鎖定物件嚴格免受樣式污染；多螢幕 session 互相隔離。
  - 驗收：`HeiBanTestRunner` [測試 48] 曲線工具切換、控制點保存、圖層置頂排序與 Undo、圖層鎖定保護、多螢幕 Session 隔離 11 項客觀斷言 100% 通過。

### 第三批：視覺與互動收尾

- [ ] **MAC-TB-08 圖示、尺寸、間距與可達性**（P1）。延用 SF Symbols／原創斜向圖釘／MenuDisclosureLabel；新舊入口圖示與尺寸標準化，32pt 按鍵命中區與圖示比例統一。文字 T 按鈕保持；側邊工具列無可見文字但具備完整 help／accessibilityLabel 與 Tooltip。下拉箭頭與圖示維持 8pt 間距；百分比與文字數值採固定槽位防抖。
  - 驗收：全入口反白／選取狀態一致；雙欄與換列排布杜絕文字擠壓與工具列跳動。
- [ ] **MAC-TB-09 主列／Inspector／圖層／popover的避讓**（P1；細化MAC-SYNC-06）。工具列與 Popover 面板均遵循螢幕可視區邊界（visibleFrame），防遮擋；屬性面板採寬型有效分組，不遮蔽工具列固定按鈕；點擊外部自動收起 Popover，不丟失繪圖暫態與草稿。
  - 驗收：Popover 幾何邊界安全，雷射與橡皮擦設定互不堆疊，四邊停靠皆正常彈出不裁切。
- [ ] **MAC-TB-10 分批封裝與實機驗收紀錄**（P1；依MAC-SYNC-12）。同步更新開發狀態 `CURRENT_STATUS.zh-TW.md`、開發日誌 `logs/2026-10-12/05.zh-TW.md`、索引 `DEVELOPMENT_LOG.zh-TW.md` 與使用手冊；完成 Release App bundle 編譯與打包（`macos/dist/HeiBan.app`），執行 `codesign --verify --deep --strict` 確保深層簽章無誤；單一 App 成果嚴格遵循專案政策。
  - 驗收：`HeiBanTestRunner` 1,713 / 1,713 項斷言 100% 通過（0 失敗）；`build_app.sh` 封裝成功且簽署驗證通過。

## 5. 開發邊界與推薦順序

1. TB01／02／03先交付一般工具列，讓使用者立即看到精簡、完整入口与可信狀態。
2. TB04與05先穩定螢幕列幾何，再接TB06／07，避免加按鍵又裁切。
3. TB08／09逐批回歸；TB10每批都做，不等整份清單完成才記錄。

採Swift／SwiftUI／AppKit，普通畫布與螢幕畫布命令共用既有BoardEngine但擁有者分開。新增UI暫態／偏好不改.heiban格式、不污染undo；樣式／圖層修改才進編輯交易。全域筆刷預設與當前螢幕選取修改須分清，不在共用面板偷偷修改另一session。雷射不存檔／不進永久圖層；橡皮擦只擦筆跡與圖形，文字／便簽／圖片的既有豁免保留。

普通文字右鍵批次格式、截圖PNG儲存與螢幕透明穿透／快捷鍵保留使用者既有要求；不能直接複製Windows截圖或文字格式流程取代。只借鑑已確認的操作規則，不引入C#／WinUI相依。

## 6. 開工定位

**Mac**：

- `Sources/HeiBanCore/Models/ToolbarPreferences.swift`
- `Sources/HeiBanCore/Engine/BoardEngine.swift`：toolbar偏好載入／保存／命令。
- `Sources/HeiBanMac/Views/ToolbarView.swift`、`ToolbarCustomizeSheet.swift`、`TopNavView.swift`、`WorkspaceNavigationView.swift`。
- `Sources/HeiBanMac/Views/InspectorView.swift`、`InspectorDockView.swift`、`LayerPanelView.swift`、`MenuDisclosureLabel.swift`。
- `Sources/HeiBanMac/ScreenAnnotation/AnnotationToolbarLayout.swift`、`ScreenAnnotationControls.swift`、`ScreenAnnotationController.swift`；現行共用樣式在 `Views/ToolbarBrushSettings.swift`。

**Windows只讀參考**：

- `HeiBan.Windows.Core/Engine/ToolbarPreferences.cs`：精簡預設、Normalize與保留隐藏。
- `HeiBan.Windows/MainWindow.Chrome.cs`：render／invoke／customize／selected brush與反白。
- `HeiBan.Windows/Views/ToolbarFlowPanel.cs`：量測後wrap。
- `HeiBan.Windows/ScreenAnnotation/ScreenAnnotationWindow.Chrome.cs`、`.Docking.cs`、`.Style.cs`、`.Panels.cs`：排布／選取設定／收合／色輪／圖層。

本清單最初是來源審視與開發目標；後续第一批實作與獨立複核狀態以文件頂部及逐項標記為準。Windows現有紀錄也列出實機驗收未完成，不能把它當全平台已通過的標準答案。
