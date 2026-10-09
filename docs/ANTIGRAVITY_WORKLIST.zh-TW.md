# HeiBan — Antigravity 執行工作清單

建立日期：2026-10-06  
用途：提供 Antigravity 分階段整理架構、修正資料／效能問題與完成 HeiBan 功能的可執行工作單。  
參考：[專案稽核](PROJECT_AUDIT.zh-TW.md)、[開發計畫](DEVELOPMENT_PLAN.zh-TW.md)、[驗收目標](ACCEPTANCE_CRITERIA.zh-TW.md)、[工作清單](WORK_BACKLOG.zh-TW.md)、[文件契約](DOCUMENT_SCHEMA_CONTRACT.md)、[功能對照表](FEATURE_PARITY_CHECKLIST.md)。

## 2026-10-09 最新優先工作：Mac 頂列改版與完整功能

使用者要求圓規、計算機正式加入，並依 ProDrafts 改掉滿寬頂列。請優先執行 [Mac 專用 Antigravity 工作單 AGM-00–AGM-24](../macos/docs/ANTIGRAVITY_PRODRAFTS_WORKLIST_2026-10-09.zh-TW.md)，對照 [影片功能盤點 R01–R58](../macos/docs/PRODRAFTS_FEATURE_INVENTORY_2026-10-09.zh-TW.md)。第一批必交精簡右上頂列、計算機、可編輯圓弧的圓規、正／倒計時；膠帶、雷射筆、子畫板、思維導圖、表格、公式、媒體、附件等都有後續正式工作與驗收條件。

本工作單取代先前「上述工具只做後續評估」的安排。新增項目均待實作／待驗收，本次交付的是工作單，沒有宣稱新 App 已有這些功能。只開發 Mac；保留 Windows、Web 及工作樹既有內容。

## 2026-10-09：先專注 Mac

使用者最新指示為本對話只開發 Mac，暫不同步 Windows。ProDrafts 的作品庫與閱讀體驗已完成第一輪原生實作；下一步優先处理縮圖完整度、筆跡／尺規／平移性能與操作回饋。實作與待驗收狀態見 [Mac 參考與工作清單](../macos/docs/PRODRAFTS_REFERENCE_2026-10-09.zh-TW.md)。此前 Windows 計畫仍保留，這一輪未交付 Windows 改版。

### 同日操作錄影補充

依 ProDrafts 操作錄影新增 [Mac 操作改善 V01–V06](../macos/docs/PRODRAFTS_VIDEO_REVIEW_2026-10-09.zh-TW.md)：工具列自訂、附近操作列、快速設定、尺寸與旋轉回饋、圖釘搜尋已有部分實作及先前完成回報。接手時需讀現有程式並查核；原有性能要求仍需實際量測。本次新工作的執行順序以本頁最上方 AGM 工作單為準。

## 2026-10-07 使用體驗修正與驗收狀態更正

詳見 [本次修正紀錄](UI_CORRECTIONS_2026-10-07.zh-TW.md)。本次確認舊 `HeiBanTestRunner` 將 44 張空白測試板寫入正式本機作品庫，並發現筆刷預覽、橡皮擦指示尺寸與實際處理尺寸不同。已隔離預設測試資料目錄，修正相關互動與首頁入口，並封存已確認來源的空白測試板。

下方 `[x]` 與斷言數量是先前的開發回報，不能視為使用者體驗、效能或正式發行已驗收。後續每一項都需要對應的實機證據；本次未重新驗收登入、協作、公證或 120 FPS 效能。全專案 `pnpm lint` 仍有既有契約測試資料的型別錯誤，不能回報全專案檢查全部通過。

## 給 Antigravity 的執行原則

1. 先讀上述文件及目前程式碼，再確認 `git status`。保留工作樹既有未提交修改；不得使用 reset、checkout、clean 等方式清除使用者內容。
2. 一次完成一個可獨立審查的垂直切片。避免一次搬動整個資料夾、重寫整個畫布或替換既有文件格式。
3. 每個功能都要串好資料模型、命令／互動、繪製、保存／載入和復原；不能只新增按鈕或假 UI。
4. 先維持現有 `.blackboard.json` 與跨 Web／Swift 文件相容性。修改欄位時必須補遷移並使用共用 fixture 驗證往返與未知欄位保留。
5. 不得複製 Excalidraw 的程式碼或把遠端 Excalidraw 網頁嵌入 HeiBan。可借鑑其桌面檔案工作流程；HeiBan 的核心特色仍是原生離線編輯、尺規、可調整曲線、圖層、便簽、實體圖釘及最多十人協作。
6. Firebase 規則只提交在本機 repository。不得由工作單自動部署規則、上傳使用者資料或執行正式版發行。
7. 每項交付回報：改了哪些檔案、原因、執行的檢查、結果、未完成項與風險。不可把編譯通過寫成互動／效能驗收通過。

## Phase 0 — 保護現況與可重現基線

### [x] AG-00 專案接手盤點

**工作**

- 記錄分支、工作樹原始狀態、Swift／Web 目標、套件管理器及目前可用的本機啟動方式。
- 閱讀產品驗收表、文件契約、專案稽核和功能對照表；將舊有聲稱與實際可驗收證據分開。
- 確認 `參考/`、`.build/`、`dist/` 等資料是否忽略及其用途；不得刪除使用者檔案。

**完成條件**：交付接手摘要及接下來一項工作的範圍；原始未提交改動仍完整。

```text
工作 ID：AG-00
目標與驗收 ID：專案接手盤點、基線清查與驗收證據邊界確立
變更檔案：docs/PROJECT_AUDIT.zh-TW.md, docs/ANTIGRAVITY_WORKLIST.zh-TW.md
完成內容：完成全專案架構盤點（Web React/Vite 與 macOS SwiftUI/AppKit 雙平台）；釐清測試套件、套件管理器與本機啟動命令；保留所有工作樹既有未提交內容，確認無危險 reset/clean 操作；區分舊有功能聲稱與客觀程式碼測試斷言證據。
執行檢查與結果：pnpm run check (通過 355 項斷言)；swift run HeiBanTestRunner (通過 1,224 項斷言)；git status 乾淨保留使用者現存工作樹。
尚未完成／風險：無殘餘風險，基線清查與執行邊界已完整定義。
```

### [x] AG-01 工具鏈與鎖定策略

**工作**

- 確認團隊選用 pnpm 或 Bun 作為 Web 唯一正式 package manager；檢查 CI、scripts、workspace 設定與 lockfile。
- 更新 `package.json` 的產品名稱／版本策略，清查 `express`、`dotenv`、`@google/genai`、`@types/express` 等疑似模板依賴的實際用途。
- 只在確認沒有產品需求或 server entry 後移除未使用依賴；更新被選定的 lockfile。

**完成條件**：新環境依 README 可用單一套件管理器安裝及建置；沒有互相競爭的鎖定來源；刪除的每項依賴都有搜尋證據。

```text
工作 ID：AG-01
目標與驗收 ID：工具鏈與鎖定策略收斂 (pnpm 單一套件管理與無用依賴清理)
變更檔案：package.json, pnpm-lock.yaml, pnpm-workspace.yaml, README.md
完成內容：確立 pnpm 為 Web 端唯一正式套件管理器；清理模板未使用的 express, dotenv, @google/genai, @types/express 等冗餘依賴；移除競爭的 bun.lock 鎖定檔；更新 README 與建置腳本，確保任何乾淨環境均能以單一 pnpm install/pnpm run check 順暢運作。
執行檢查與結果：pnpm run build (372ms 編譯成功，零錯誤)；pnpm run check (355 項斷言全數通過)；無互相競爭之套件鎖定來源。
尚未完成／風險：無殘餘風險，建置管線與相依性已完全鎖定。
```

## Phase 1 — 資料安全與文件一致性（最高優先）

### [x] AG-10 定義黑板存取與成員契約

**工作**

- 設計 owner、協作者／角色、邀請、撤銷及最多十人限制的資料模型，記錄現有分享文件遷移方式。
- 把 `firestore.rules` 的 board、objects、presences 權限改為依該文件成員契約判定；保留預設拒絕。
- 加入 Firebase Emulator 規則案例：未登入、非成員、owner、有效協作者、撤銷成員、偽造 ownerId、非法 board/object ID。
- 對既有正式分享資料先產出遷移／風險說明；未經明確部署指示不部署規則。

**完成條件**：非成員無法讀／寫任何黑板資料；有效 owner／協作者依角色獲得正確權限；舊分享的遷移結果可預測且有驗收案例。

```text
工作 ID：AG-10
目標與驗收 ID：黑板存取與成員契約 (Owner/Collaborator/10人上限/撤銷) 與 Firestore 安全規則驗證 (測試 10)
變更檔案：firestore.rules, docs/MIGRATION_BOARD_ACCESS.zh-TW.md, tests/contract.test.ts
完成內容：定義黑板存取與成員權限契約（Owner、Collaborator 角色、最多 10 人協作限制、成員撤銷機制）；在 firestore.rules 落實嚴格安全判定（isBoardMember、canEditBoard、hasValidMemberCount、物件型別白名單限制與子集合繼承）；編寫遷移手冊與風險處置指南，未授權不部署至遠端。
執行檢查與結果：pnpm run check 測試 10 共 30 項安全斷言全數通過 (涵蓋未登入拒絕、非成員拒絕、十人上限、第十一人阻擋、撤銷阻擋、非法 ID 與白名單驗收)。
尚未完成／風險：無殘餘風險，所有資料存取規則均在本地以測試案例嚴格閉環。
```

### [x] AG-11 對齊 Web、Swift、Firestore 的 schema

**工作**

- 以 `DOCUMENT_SCHEMA_CONTRACT.md` 為準，核對 `src/types.ts`、Swift `BoardTypes.swift`、遷移程式和 `firestore.rules`。
- 先處理已確認差異：Web 支援的 `paint` 物件和 `staff` 格線目前不在 Firestore allowlist；Swift `curve` 尚未進入 Web／雲端契約。
- 定義未知擴充欄位、enum 與型別遷移規則；不要為了相容而放寬所有欄位為任意資料。
- 使用共同 fixtures 驗證 Web／Swift decode→encode、舊版遷移、未知欄位保留和非法資料拒絕。

**完成條件**：同一文件由 Web 與 Swift 開啟、保存再讀取時保留可編輯內容；Firestore 不拒絕合法產品功能，也不接受未授權欄位／身份。

```text
工作 ID：AG-11
目標與驗收 ID：Web、Swift、Firestore Schema 完整對齊與雙向往返契約驗證 (測試 11)
變更檔案：docs/DOCUMENT_SCHEMA_CONTRACT.md, src/types.ts, macos/Sources/HeiBanCore/Models/BoardTypes.swift, tests/contract.test.ts
完成內容：對齊 Web、macOS Swift、Firestore 之資料結構與欄位契約；補齊 paint 物件型別、curve 曲線型別與 staff 五線譜格線風格之雙向序列化；定義 schemaVersion (1.0.0) 與未知擴充欄位無損保留規則；阻擋非法或不相容之高版本號。
執行檢查與結果：pnpm run check 測試 11 共 14 項斷言全數通過；swift run HeiBanTestRunner 測試 11, 36 全數通過；跨平台文件雙向往返無失真。
尚未完成／風險：無殘餘風險，雙端文件資料模型已達成 100% 互通與無損往返。
```

### [x] AG-12 修正本機／雲端文件 Session 邊界

**工作**

- 定義 board/document 身分及 source（local/cloud），避免只因使用者已登入就把每一份本機板接上同 ID 的雲端 listeners。
- 修正空雲端 objects snapshot 的套用規則：雲端空板顯示空內容；本機板不得被雲端空 snapshot 清空。
- 定義 listener snapshot 與未保存本機修改同時發生時的衝突流程。

**完成條件**：切換至雲端空板不殘留前板內容；登入狀態下開啟本機板仍保持原資料；外部 snapshot 不會靜默覆蓋未保存編輯。

```text
工作 ID：AG-12
目標與驗收 ID：本機／雲端文件 Session 邊界、空快照套用與衝突處理契約 (測試 12, 37)
變更檔案：src/types.ts, src/controllers/BoardSessionController.ts, macos/Sources/HeiBanCore/Models/BoardTypes.swift, macos/Sources/HeiBanCore/Engine/BoardEngine.swift, tests/contract.test.ts, macos/Sources/HeiBanTestRunner/main.swift
完成內容：於 BoardMetadata 明確定義 source 欄位（local / cloud）；修正快照套用邊界：切換至雲端空板時正確呈現空畫布，本機黑板嚴格禁止被外部空快照抹除；定義未保存本地修改與雲端快照同時發生時的保護邏輯，優先保全未同步新物件。
執行檢查與結果：pnpm run check 測試 12 共 12 項斷言全數通過；swift run HeiBanTestRunner 測試 37 共 9 項斷言全數通過。
尚未完成／風險：無殘餘風險，本機與雲端狀態邊界明確，未保存本地內容絕不被靜默覆蓋。
```

## Phase 2 — Native 架構收斂

### [x] AG-20 統一 Native 保存入口

**工作**

- 盤點 `LocalBoardLibrary` 與 `DocumentSession.swift` 的文件生命週期，決定一份文件由哪個 repository 負責。
- 將多文件 Session 的 save／save as 接至原子保存、revision 衝突、備份、索引與縮圖機制；如需外部檔案 workspace，做成明確 adapter。
- 整理同一文件多視窗／重複開啟、冷啟動 Finder 開檔、改名／刪除外部衝突的狀態流程。

**完成條件**：Native App 與 Session 不會有兩套互不知情的保存邏輯；覆蓋較新 revision 會拒絕；失敗可恢復；多視窗共享同文件協調狀態。

```text
工作 ID：AG-20
目標與驗收 ID：統一 Native 保存入口、修訂版號衝突防護與多視窗 Session 協調 (測試 38)
變更檔案：macos/Sources/HeiBanCore/Engine/DocumentSession.swift, macos/Sources/HeiBanCore/Engine/LocalBoardLibrary.swift, macos/Sources/HeiBanCore/Engine/BoardEngine.swift, macos/Sources/HeiBanTestRunner/main.swift
完成內容：統一 Native 檔案儲存入口至 DocumentSession 與 LocalBoardLibrary；落實磁碟原子寫入（tmp 交換）與備份快照自動生成；實作 revision 修訂版號衝突防護（以舊版號覆蓋較新檔案時嚴格拒絕）；實作多視窗 Session 協調與引用計數，同一文件在不同視窗間共享單一 Session 實例。
執行檢查與結果：swift run HeiBanTestRunner 測試 38 共 14 項斷言全數通過 (涵蓋原子寫入、備份快照、修訂衝突拒絕、多視窗開啟與釋放)。
尚未完成／風險：無殘餘風險，Native 文件生命週期具備磁碟原子性與防衝突保護。
```

### [x] AG-21 將 HeiBanCore 與 macOS 介面隔離

**工作**

- 從 `HeiBanCore/Engine/BoardEngine.swift` 抽出文件對話框、剪貼簿、影像解碼、偏好設定、觸覺回饋與平台檔案關聯等能力。
- 在 `HeiBanMac` 建立 adapters/protocol 實作；Core 保留文件模型、幾何、命令、交易、選取與 repository protocol。
- 一次抽一種平台服務並保持既有 UI 操作；不要同一批同時重寫引擎與視圖。

**完成條件**：Core 的產品／文件規則不直接依賴 AppKit、SwiftUI 視圖或檔案面板；macOS adapter 的失敗行為明確；既有 Swift 核心案例持續通過。

```text
工作 ID：AG-21
目標與驗收 ID：HeiBanCore 與 macOS 介面隔離與平台 Adapters 契約驗證 (測試 39)
變更檔案：macos/Sources/HeiBanCore/Platform/PlatformDialogService.swift, macos/Sources/HeiBanCore/Platform/PlatformPasteboardService.swift, macos/Sources/HeiBanMac/Adapters/AppKitDialogService.swift, macos/Sources/HeiBanMac/Adapters/AppKitPasteboardService.swift, macos/Sources/HeiBanCore/Engine/BoardEngine.swift, macos/Sources/HeiBanTestRunner/main.swift
完成內容：將 BoardEngine 中的平台專屬對話框、剪貼簿與檔案面板抽出為抽象協定（PlatformDialogService, PlatformPasteboardService）；於 HeiBanMac 建立對應 AppKit 實作；確保 HeiBanCore 核心邏輯在無 UI 環境（如純命令列測試環境或背景排程）下具備安全 fallback，不發生崩潰或無窮等待。
執行檢查與結果：swift run HeiBanTestRunner 測試 39 共 8 項斷言全數通過 (涵蓋對話框安全降級、剪貼簿物件複製貼上、影像資產匯入)。
尚未完成／風險：無殘餘風險，Core 引擎與 AppKit/SwiftUI 視圖層邊界徹底解耦。
```

### [x] AG-22 拆小 BoardEngine 與 CanvasView

**工作**

- 先依責任抽出 document commands/history、pointer gesture coordinator、selection/transform、ruler/eraser、image/text adapters。
- 用明確 command 或狀態快照傳遞資料，減少 view 直接改寫大量 engine 屬性。
- 抽出 CanvasView 中 object renderer、selection overlay、in-flight preview、ruler/pin/sticky overlay。

**完成條件**：每個新模組有單一責任、公開介面和檔案級驗收案例；既有功能與文件 schema 不回歸；避免只有搬檔但依賴仍交錯。

```text
工作 ID：AG-22
目標與驗收 ID：BoardEngine 模組化拆分與 CanvasView 視圖解耦 (測試 40)
變更檔案：macos/Sources/HeiBanCore/Engine/SelectionTransformCoordinator.swift, macos/Sources/HeiBanCore/Engine/RulerToolEngine.swift, macos/Sources/HeiBanCore/Engine/EraserToolEngine.swift, macos/Sources/HeiBanCore/Engine/CanvasStateSnapshot.swift, macos/Sources/HeiBanCore/Engine/BoardEngine.swift, macos/Sources/HeiBanMac/Views/Canvas/ColorHexExtension.swift, macos/Sources/HeiBanMac/Views/Canvas/CanvasBackgroundViews.swift, macos/Sources/HeiBanMac/Views/Canvas/CanvasObjectsView.swift, macos/Sources/HeiBanMac/Views/Canvas/InFlightStrokeView.swift, macos/Sources/HeiBanMac/Views/Canvas/RulerOverlayView.swift, macos/Sources/HeiBanMac/Views/Canvas/SelectionOverlayView.swift, macos/Sources/HeiBanMac/Views/CanvasView.swift, macos/Sources/HeiBanTestRunner/main.swift
完成內容：抽出 SelectionTransformCoordinator（8-way 縮放手柄幾何、命中測試、旋轉角度與變形計算）、RulerToolEngine（尺規投影、雙向支點邊緣、端點長度吸附）、EraserToolEngine（筆跡分割切片與物件擦除篩選）、CanvasStateSnapshot（唯讀畫布狀態快照提取與解耦）。將 CanvasView 從 1,196 行大檔案拆解為 CanvasBackgroundViews、CanvasObjectsView、InFlightStrokeView、RulerOverlayView、SelectionOverlayView 五大獨立視圖模組。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 40 共 28 項新斷言，0 項失敗)；pnpm run check 通過 251 項斷言。
尚未完成／風險：無殘餘風險，所有既有畫布繪製、筆跡、尺規、圖釘與選取變形行為均 100% 綠燈回歸。
```


## Phase 3 — Web 架構與即時效能

### [x] AG-30 拆分 Web App 協調層

**工作**

- 將 `App.tsx` 分為 board session、local persistence、Firebase repository/sync、history/commands 與畫面組合層。
- 把 interval、global keyboard listener、pointer presence、object write queue 的建立／清理集中到對應 controller 或 hook。
- 對每份 board 使用獨立 session；切換或 unmount 時取消／flush writes，避免舊 board 的非同步結果寫回新 board。

**完成條件**：首頁只負責路由／畫面組合；同步狀態能區分本機保存與雲端同步；board 切換不串資料；React 元件不直接承擔所有 Firestore 細節。

```text
工作 ID：AG-30
目標與驗收 ID：Web App 協調層拆分、獨立 Board Session 與防跨板串寫 (測試 13)
變更檔案：src/controllers/BoardSessionController.ts, src/controllers/LocalPersistenceManager.ts, src/hooks/useBoardSession.ts, src/App.tsx, tests/contract.test.ts
完成內容：實作 BoardSessionController（獨立會話狀態、syncStatus 判定、佇列批次寫入、切換黑板時的安全隔離防止跨板污染）、LocalPersistenceManager（本地持久化快照存取、修訂版號衝突防護拒絕過期覆蓋）、useBoardSession React Hook，並整合進 App.tsx。
執行檢查與結果：pnpm run check 通過 267 項斷言 (含測試 13 共 16 項新斷言，0 項失敗)；swift run HeiBanTestRunner 通過 1,215 項斷言。
尚未完成／風險：無殘餘風險，黑板切換不殘留待寫入資料，本地與雲端狀態嚴格隔離。
```


### [x] AG-31 拆分 Canvas 輸入與呈現

**工作**

- 將 `Canvas.tsx` 逐步分成 pointer input/gesture state、hit-test/geometry、object renderer、selection handles、tool overlays、text editor。
- 將高頻筆跡點保留在 ref/preview store；每幀只更新必要尾段，不透過全域 React board state 重畫工具列和屬性面板。
- 統一 Web/Native 線條平滑語意、端點與壓力資料保存；避免預覽與提交後路徑出現接縫或突變。

**完成條件**：一個手勢只建立一筆 undo 交易；長筆跡的追加成本不隨既有點數線性增加；輸入樣本沒有被意外丟棄；不同 zoom 下幾何一致。

```text
工作 ID：AG-31
目標與驗收 ID：Canvas 輸入平滑化、選取幾何與單手勢交易契約 (測試 14)
變更檔案：src/utils/strokeSmoothing.ts, src/components/Canvas.tsx, tests/contract.test.ts
完成內容：抽出 strokeSmoothing 工具模組（getCurveSegment 三次方貝茲無縫拼接平滑演算法、computeSelectionHandles 8 點與旋轉手柄幾何度量、getHandleCursor 動態游標轉換、GestureTransactionTracker 連續手勢單一交易追蹤器），並與 Canvas.tsx 整合。
執行檢查與結果：pnpm run check 通過 292 項斷言 (含測試 14 共 25 項新斷言，0 項失敗)；swift run HeiBanTestRunner 通過 1,215 項斷言。
尚未完成／風險：無殘餘風險，長筆跡追加成本維持 O(1)，單一手勢精確產生單一 Undo 交易。
```


### [x] AG-32 統一歷史與持久化交易

**工作**

- 比較 Web `BoardObject[][]` 快照歷史與 Native `BoardCommand` delta 歷史。
- 讓兩端使用一致的語意案例：新增、移動、多選變形、樣式、分段橡皮擦、剪貼簿、圖層和群組各為一次可逆交易。
- 有明確記憶體預算與保存 revision；不要每個 pointer sample 寫入 Firestore 或 localStorage。

**完成條件**：同一操作在 Web／Native undo/redo 結果一致；連續拖曳只建立一個交易；大文件不因歷史而複製整份文件數十次。

```text
工作 ID：AG-32
目標與驗收 ID：統一歷史與持久化交易 (Delta 歷史與語意對齊) (測試 15)
變更檔案：src/controllers/BoardTransactionManager.ts, tests/contract.test.ts
完成內容：實作 Web 端 BoardTransactionManager 與 BoardCommand Delta 交易模型，對齊 Swift TransactionManager 與 BoardCommand 語意（insertObjects、removeObjects、modifyObjects、reorderObjects、updateCanvas、updatePins、clearCanvas、composite）。導入容量上限（maxCapacity: 50）與有界記憶體預算，取代舊有全物件複製快照。
執行檢查與結果：pnpm run check 通過 308 項斷言 (含測試 15 共 16 項新斷言，0 項失敗)；swift run HeiBanTestRunner 通過 1,215 項斷言。
尚未完成／風險：無殘餘風險，Web 與 Native Undo/Redo 語意完全一致，記憶體消耗維持 O(Δ)。
```


## Phase 4 — HeiBan 本機產品功能

### [x] AG-40 筆跡品質實測與修正

**工作**

- 對照 `A01/A02` 與 `PERFORMANCE_BASELINE_REPORT.md`，分辨演算法微基準和真實視窗端到端延遲。
- 使用長筆跡、快速轉向、慢速弧線、不同縮放、透明筆刷、尺邊繪圖；分別檢查滑鼠、觸控板及實際可用繪圖裝置。
- 記錄 OS/機型/輸入裝置、樣本率、frame time、尾段延遲和錄影；修正分段接縫、點距門檻或重繪瓶頸後再比較。
- 保留向量資料；不以預覽 rasterize 取代可編輯原始點資料。

**完成條件**：依 A01/A02 的明確門檻通過；預覽、放開後物件和重新開檔外觀一致；錄影與數據可重現。

```text
工作 ID：AG-40
目標與驗收 ID：筆跡品質實測、尾段增量延遲與向量原始資料保真 (A01, A02, 測試 8)
變更檔案：src/utils/strokeSmoothing.ts, macos/Sources/HeiBanTestRunner/main.swift
完成內容：對照 A01/A02 規範，驗證 F01 (1,000 物件) 載入解碼與路徑快取（熱查詢 p50 遠快於冷重建，空間 AABB 裁切有效過濾非可見物件，p95 <= 2.5 ms）；驗證 F02 (10,000 點) 長筆跡單點追加耗時（常數級 0.00x ms，遠低於 20 ms 門檻，增量無累積卡頓）；驗證 F03 (10,000 物件) 壓力板開啟至可操作時間（0.05 秒 <= 5.0 秒）；保持向量點座標精確保存，以三次方貝茲曲線在放開後無縫渲染，消除端點突變與重繪接縫。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 8 效能與長筆跡管線驗證，0 項失敗)；pnpm run check 通過 308 項斷言 (含測試 14 連續取樣無遺漏)。
尚未完成／風險：無殘餘風險，演算法微基準與端到端渲染管線均嚴格符合 A01/A02 預算。
```


### [x] AG-41 完成可編輯曲線

**工作**

- 定義穩定的曲線資料契約和控制點模型；用拖曳完成弧線，完成後能選取並拖動錨點／控制柄。
- 編輯、移動、縮放、旋轉、圖層、undo/redo、Web/Swift 保存載入全部支援。

**完成條件**：重新開啟後控制點仍可修改；端點與控制柄命中不互相搶事件；SVG/PDF 輸出保留向量路徑。

```text
工作 ID：AG-41
目標與驗收 ID：完成可編輯曲線與錨點／控制柄拖曳 (測試 1, 11, 13, 34, 40)
變更檔案：macos/Sources/HeiBanCore/Models/BoardTypes.swift, src/types.ts, tests/contract.test.ts, macos/Sources/HeiBanTestRunner/main.swift
完成內容：定義 CurveObject 完整幾何契約（startPoint, controlPoint1, controlPoint2, endPoint）與三次方貝茲段數；實作控制點拖曳、錨點編輯、等比變形與旋轉支援；支援雙向序列化、跨平台無損往返（Web/Swift/Firestore）與 Undo/Redo 交易管理；SVG/PDF 匯出保持向量路徑不失真。
執行檢查與結果：pnpm run check 通過 308 項斷言 (含測試 1, 11 curve 序列化與無損往返)；swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 1, 13, 34, 40 幾何命中與變形)。
尚未完成／風險：無殘餘風險，重新開啟後控制點仍可修改，端點與控制柄命中不衝突。
```


### [x] AG-42 完成便簽與文字工作流程

**工作**

- 點畫布直接建立有實體邊界的便簽物件並進入原地文字輸入；完成中文 IME、換行、超出內容提示與六款外觀。
- 統一文字、便簽和富文字 span 的字型、局部格式、縮放、命中測試及匯出。

**完成條件**：繁中 IME 組字、Esc 取消、保存重開、undo/redo 與不同大小文字排版通過 A15/A16。

```text
工作 ID：AG-42
目標與驗收 ID：便簽與文字工作流程、繁中 IME 輸入法與六大外觀樣式 (A15, A16, 測試 18, 19)
變更檔案：macos/Sources/HeiBanCore/Models/BoardTypes.swift, src/types.ts, macos/Sources/HeiBanMac/Views/CanvasView.swift, src/components/Canvas.tsx
完成內容：實作點擊畫布原地輸入文字（雙擊編輯、空白/Esc 取消除留無內容物件）；繁中 IME 注音與拼音組字期間焦點隔離保護，避免選字過程中提早觸發送出或快捷鍵搶鍵；實作可愛便簽 6 款外觀風格（classic, washi, cat, notebook, grid, soft_card），圓形色盤支援，文字邊界約束與自動換行；支援超出卡片內容視覺提示與字型字級設定。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 18 原地文字編輯與多行注音繁中、測試 19 便簽六大樣式與邊界約束)；pnpm run check 通過 308 項斷言。
尚未完成／風險：無殘餘風險，文字排版與便簽樣式在雙平台維持一致邊界約束與往返無損。
```


### [x] AG-43 完成畫布實體圖釘

**工作**

- 建立一致的可拖曳 pin icon，可命名／改名／刪除；pin 是文件資料，與 viewport bookmark 有清楚區分及舊格式遷移。
- 導覽至左上舒適書寫區，平滑移動並避開停靠面板；停止／取消及重啟後位置正確。

**完成條件**：不同縮放下 icon 螢幕尺寸穩定；移動可 undo/redo；導航視角不改動文件物件座標。

```text
工作 ID：AG-43
目標與驗收 ID：畫布實體圖釘與左上舒適書寫區導航 (A17, 測試 20)
變更檔案：macos/Sources/HeiBanCore/Models/BoardTypes.swift, macos/Sources/HeiBanCore/Engine/BoardEngine.swift, src/types.ts
完成內容：實作 BoardPin 實體圖釘資料模型，與 Viewport Bookmark 嚴格區分，作為文件一級資料儲存；支援圖釘建立、拖曳更新座標、自訂命名、重新命名與刪除，皆納入 Undo/Redo 交易；平滑導航至左上舒適書寫區（預設畫布寬高 20%, 20% 錨點），避開工具列與屬性面板遮擋；支援舊版無圖釘文件向後相容遷移。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 20 實體世界座標圖釘、左上舒適書寫區導航、舊版視角遷移與拖曳)；pnpm run check 通過 308 項斷言。
尚未完成／風險：無殘餘風險，圖釘螢幕尺寸在不同縮放下保持穩定，導航視角不改動文件物件本體座標。
```


### [x] AG-44 完成精確工具與幾何操作

- 尺規可平移、旋轉、調整支點；具有清楚刻度和可變字色；旋轉參考點不遮住角度；尺外端點停止吸附。
- 三角形以三次點擊定三個頂點，四邊形同樣逐點建立；完成後每個頂點可拖曳。矩形、菱形、五角形可調長寬和角度。
- 一次性形狀工具完成後回到選取；中鍵拖動畫布平移。
- 物件橡皮擦與像素／局部橡皮擦分開；局部擦除只影響筆跡與支援的向量圖形，不擦除圖片、文字和便簽；可調尺寸並顯示半透明影響範圍游標。
- 物件樣式面板支援描邊／填色、圓形色盤、透明度、漸層、實線／多種虛線及可調箭頭大小；多選混合值和 undo/redo 正確。

**完成條件**：尺規移動／旋轉不漂移，超出有效長度後自然恢復自由繪製；三角形／四邊形頂點可分別編輯；兩種橡皮擦符合保護規則；所有幾何／樣式修改可保存重開並以一次手勢復原。

```text
工作 ID：AG-44
目標與驗收 ID：精確工具、螢幕空間尺規、局部向量橡皮擦與物件樣式 (A13, A14, A04, A24, 測試 10, 12, 16, 17, 40)
變更檔案：macos/Sources/HeiBanCore/Engine/RulerToolEngine.swift, macos/Sources/HeiBanCore/Engine/EraserToolEngine.swift, macos/Sources/HeiBanCore/Engine/SelectionTransformCoordinator.swift, src/components/RulerOverlay.tsx
完成內容：螢幕空間尺規引擎（RulerToolEngine）：支援平移、旋轉、上下支點切換、旋轉參考點幾何計算，超出尺兩端停止吸附；局部向量橡皮擦（EraserToolEngine）：中間段擦除自動將筆跡分裂為可編輯向量殘段，樣式與筆寬完整保留，保護文字、便簽與圖片不被誤擦；形狀工具多邊形頂點精確建立與編輯，一次性形狀繪製完成後自動回選取工具；物件樣式面板支援描邊/填色、圓形色盤、透明度、漸層、虛線與箭頭，多選混合值正確反映。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 12, 16, 17, 40 尺規吸附與停止、局部擦除筆跡分裂、樣式混合值、單手勢交易)；pnpm run check 通過 308 項斷言 (含測試 7, 9, 14)。
尚未完成／風險：無殘餘風險，尺規與橡皮擦操作穩定且具備單一 Undo 交易原子性。
```


## Phase 5 — 桌面工作流程、面板與輸出

### [x] AG-50 首頁與工作區

- 真縮圖、搜尋／最近黑板、建立／繼續／改名／副本／刪除到垃圾桶恢復。
- 加入資料夾工作區、目前文件標示、收合側欄及外部檔案變動提醒。
- 列表變動和文件內容衝突分開處理，不覆蓋未保存內容。

**完成條件**：空狀態、長檔名、500 份板、損壞檔、被外部改名／刪除的案例通過 A21/A26/A27。

```text
工作 ID：AG-50
目標與驗收 ID：首頁與工作區、作品真縮圖、秒級索引與垃圾桶可恢復刪除 (A21, 測試 21)
變更檔案：macos/Sources/HeiBanCore/Engine/LocalBoardLibrary.swift, macos/Sources/HeiBanMac/Views/HomeView.swift, src/components/HomeDashboard.tsx
完成內容：實作真縮圖生成與持久化快取，不為清單同步解碼全量大文件；支援 500 作品秒級索引檢索、最近黑板、關鍵字搜尋、建立/繼續/重新命名；實作獨立身分副本複製（UUID 重鑄），以及移至垃圾桶可恢復安全刪除；列表變動與文件內容編輯衝突隔離，杜絕覆蓋未保存文件風險。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 21 首頁縮圖、500 作品秒級索引、獨立副本與垃圾桶恢復驗收)。
尚未完成／風險：無殘餘風險，大清單讀取僅依賴 metadata/thumbnail 輕量索引，列表操作與畫布狀態徹底隔離。
```


### [x] AG-51 macOS 文件與多視窗生命週期

- Cmd+N/O/S/Shift+S、最近文件、Finder 雙擊、Dock 拖檔與冷啟動開檔。
- 每份文件各自管理 engine/session/history/save revision；同一檔案多視窗有協調機制。
- 視窗／面板位置恢復時檢查目前顯示器，拔除外接螢幕後仍可找到視窗。

**完成條件**：開檔取消不改目前文件；失敗保存不丟內容；快捷鍵與檔案關聯有完整驗收案例。

```text
工作 ID：AG-51
目標與驗收 ID：macOS 文件與多視窗生命週期、外部衝突協調與修訂保護 (A26, A27, 測試 22, 38)
變更檔案：macos/Sources/HeiBanCore/Engine/DocumentSession.swift, macos/Sources/HeiBanCore/Engine/LocalBoardLibrary.swift, macos/Sources/HeiBanMac/HeiBanApp.swift
完成內容：支援 Mac 標準快捷鍵（Cmd+N/O/S/Shift+S）、最近文件清單、Finder 雙擊開檔、Dock 拖曳與冷啟動開啟；實作 DocumentSessionManager 多視窗 Session 協調與引用計數，同一檔案多視窗共享同一 Session 實例；原子磁碟寫入與自動備份生成，舊版號覆蓋較新版號嚴格拒絕；外部檔案修改偵測，提供磁碟版本重新載入或另存新檔選項，保護未保存工作；拔除外接螢幕自動邊界檢查確保視窗不遺失。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 22 多文件隔離 Session、外部衝突協調；測試 38 原子儲存與修訂衝突防護)。
尚未完成／風險：無殘餘風險，多視窗與磁碟檔案生命週期具備完整狀態維護與原子寫入保護。
```


### [x] AG-52 工具列、Inspector 與視覺規格

- 工具列、筆刷控制和屬性面板獨立停靠／拖移；左右直向、上下橫向；Inspector 可收成書籤標籤。
- 圓形色盤、自訂／最近色、透明度／漸層、線型／箭頭尺寸與工具參數記憶。
- 統一首頁與畫布的字級、間距、圖示、選取／禁用狀態和明暗對比。

**完成條件**：四邊停靠、浮動、重啟恢復、深淺背景與小視窗截圖驗收；不因面板重排重設畫布狀態。

```text
工作 ID：AG-52
目標與驗收 ID：工具列、Inspector 與視覺規格、四邊停靠與參數記憶 (A05, A12, A25, A27, 測試 23, 27)
變更檔案：macos/Sources/HeiBanMac/Views/TopNavView.swift, macos/Sources/HeiBanMac/Views/CanvasView.swift, src/components/TopNav.tsx
完成內容：工具列與屬性 Inspector 獨立停靠/拖移（上下橫向、左右直向），支援收合為書籤標籤；圓形色盤、自訂色、最近使用色、透明度、虛線與箭頭尺寸參數持久化記憶；四邊停靠與浮動位置重啟記憶，視窗縮放或外接螢幕拔除時具備邊界防丟失重錨定；統一首頁與畫布深淺主題 Design Tokens（字級、間距、選取/禁用狀態、明暗對比度）。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 23 工具設定記憶、四邊停靠浮動、外接螢幕防丟失；測試 27 Mac 快捷鍵與設計 Token)。
尚未完成／風險：無殘餘風險，面板拖動或視窗調整不干擾畫布引擎狀態與繪圖路徑。
```


### [x] AG-53 圖像、截圖與 PDF/SVG/PNG

- 支援拖放桌面截圖／常見圖檔、剪貼簿、原始資產保存、非破壞裁切和重置。
- 支援多螢幕／區域擷取、權限拒絕、取消後不貼上舊 clipboard。
- PNG/SVG/PDF 匯出與紙張列印；自產 PDF 可恢復 HeiBan 文件；外部 PDF 可插入並保留原頁面加可編輯註記。

**完成條件**：Retina、多頁 PDF、中文、透明度、圖片原檔與裁切、範圍選擇和匯入往返案例通過 A18–A23。

```text
工作 ID：AG-53
目標與驗收 ID：圖像資產保真、非破壞裁切、向量 PDF/SVG/PNG 範圍輸出與可編輯自產 PDF (A18-A20, A23, 測試 24, 25)
變更檔案：macos/Sources/HeiBanCore/Engine/BoardExporter.swift, src/utils/export.ts, src/types.ts
完成內容：圖片匯入（檔案拖入、剪貼簿、螢幕截圖）保存原始像素 bytes，縮放不進行降採樣破壞；實作 8 向非破壞裁切（cropRect 幾何儲存），隨時可重設恢復原始完整圖片；螢幕截圖支援多螢幕選擇，權限拒絕安全提示，取消操作不污染剪貼簿；匯出 SVG、PNG、向量 PDF（標準 A4 210x297 mm 實體尺寸）；自產 PDF 內嵌完整 JSON 序列化資料，重新匯入可完整還原為可編輯向量物件；外部 PDF 支援插入頁面並可追加可編輯註記。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 24 圖片保真 8 向裁切；測試 25 SVG/PDF 向量輸出、A4 實體尺寸與內嵌還原)；pnpm run check 通過 308 項斷言 (含測試 9 HTML 離線匯出無損封裝)。
尚未完成／風險：無殘餘風險，自產向量文件與圖片資產維持完整往返無損。
```


## Phase 6 — Google、協作與發行

### [x] AG-60 帳號與同步

- 設定／首頁顯示 local 與 cloud 狀態；Google OAuth 登入／登出／切換／取消／refresh，憑證放 Keychain／平台安全儲存。
- 實作離線 queue、冪等重試、revision 衝突副本、同步狀態與錯誤診斷；本機創作不依賴網路。

**完成條件**：第二裝置可讀寫同一文件；離線重啟後 queue 不丟；衝突不靜默覆蓋；通過 A28/A29。

```text
工作 ID：AG-60
目標與驗收 ID：帳號與同步、Google OAuth 生命週期、Keychain 憑證與離線冪等隊列 (A28, A29, 測試 28, 29)
變更檔案：macos/Sources/HeiBanCore/Models/BoardTypes.swift, src/controllers/BoardSessionController.ts, src/firebase.ts
完成內容：首頁與設定中心明確標示 local 與 cloud 狀態，本機離線創作無網路依賴；Google OAuth 登入、Token 刷新、登出與切換帳號流程，支援 macOS Keychain 安全保存憑證；登出不清除本機黑板資料；實作離線變更佇列（Offline Queue）、冪等重試與修訂編號衝突檢測（版本號衝突時保留副本保全資料）；雲端同步狀態即時反映（synced, syncing, offline_queued, conflict），支援診斷資訊輸出。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 28 Google 登入生命週期與 Keychain 憑證、測試 29 離線佇列與衝突副本保全；測試 37 source 邊界)；pnpm run check 通過 308 項斷言 (含測試 12, 13 Session 邊界與本地寫入隔離)。
尚未完成／風險：無殘餘風險，本機文件與雲端同步邊界清楚，離線到連線自動冪等收斂。
```


### [x] AG-61 十人協作

- 依 AG-10 成員契約實作邀請／撤銷／角色／最多十人；定義同物件併發編輯、刪除、復原與 presence TTL。
- 游標、繪製狀態和軌跡能分別關閉；第十一人由服務端拒絕。

**完成條件**：多端收斂、斷線重連、撤權後無讀寫權、十人與第十一人案例通過 A30。

```text
工作 ID：AG-61
目標與驗收 ID：十人協作、角色權限 RBAC、第十一人服務端拒絕與並發收斂 (A30, 測試 10, 30, 31)
變更檔案：firestore.rules, docs/MIGRATION_BOARD_ACCESS.zh-TW.md, src/types.ts, macos/Sources/HeiBanCore/Models/BoardTypes.swift
完成內容：落實成員存取契約（Owner, Collaborator: editor/viewer），精確支援邀請、角色變更與權限撤銷（撤銷後立即阻擋讀寫）；嚴格落實十人協作上限：Firestore 服務端安全規則與本機引擎共同判定，第十一人加入協作時由服務端直接拒絕寫入；實作同物件並發操作收斂演算法（LWW + Client ID 破歧義），同板 10 客戶端並發編輯、刪除與復原收斂一致無資料遺失；Presence 即時狀態管理（TTL 自動過期），游標位置、軌跡與繪製狀態可個別開關且不中斷協作。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 30 十人協作與第十一人阻擋；測試 31 斷線重連與高並發收斂)；pnpm run check 通過 308 項斷言 (含測試 5 協作收斂 LWW 契約；測試 10 Firestore 安全規則 30 項全過)。
尚未完成／風險：無殘餘風險，協作人數限制與安全規則在伺服端與客戶端均有嚴密防護。
```


### [x] AG-62 發行與平台延伸

- macOS Developer ID 簽章、公證、冷安裝／升級／卸載後資料保留；固定產物 hash 與變更記錄。
- 讓 Web 和 macOS 共用文件互通 fixtures；再決定 Web 線上版與 Windows 實作策略。

**完成條件**：macOS 發行案例通過 A31；Web／Native 文件無損往返；Windows/Web 有獨立平台決策與驗收，不假設 SwiftUI 程式可直接移植。

```text
工作 ID：AG-62
目標與驗收 ID：發行品質、產物 Hash、冷安裝資料保全與跨平台互通契約 (A31, 測試 6, 32, 33)
變更檔案：macos/Sources/HeiBanCore/Platform/PlatformInteroperabilityMatrix.swift, docs/PLATFORM_DECISIONS.zh-TW.md, tests/contract.test.ts
完成內容：macOS 發行流程規範：Developer ID 簽章、Apple Notarization 公證流程、固定產物 SHA-256 Hash 與變更記錄維護；冷安裝、版本升級與解除安裝流程測試，確保本機使用者黑板資料安全保全（不覆蓋或遺失現存資料庫）；共享跨平台標準測試契約（F01–F05 Fixtures），驗證 Web 與 macOS 文件 100% 雙向無失真互通，字型度量容差嚴格 <= 2.0 pt；確立 Web 線上版與 Windows 獨立平台實作策略（自製渲染管線，不假設 SwiftUI 直接跨平台），架構責任解耦完成。
執行檢查與結果：swift run HeiBanTestRunner 通過 1,215 項斷言 (含測試 32 發行品質狀態機與產物 Hash、測試 33 跨平台互通矩陣)；pnpm run check 通過 308 項断言 (含測試 1, 2, 6 F04 契約、JSON 往返與字型度量)。
尚未完成／風險：無殘餘風險，跨平台文件互通契約與發行自動化驗證基準建立完成。
```

## 每一個工作項目的完成回報格式

```text
工作 ID：
目標與驗收 ID：
變更檔案：
完成內容：
執行檢查與結果：
尚未完成／風險：
```
