# HeiBan 專案架構與冗餘稽核

後續：本頁保留 2026-10-06 的歷史發現；2026-10-09 Mac 實際整理與仍待處理項見 [最新程式稽核](../macos/docs/development/CODE_REVIEW_2026-10-09.zh-TW.md)、[開發紀錄入口](DEVELOPMENT_INDEX.zh-TW.md)。

稽核日期：2026-10-06  
範圍：React/Vite 網頁端、Swift/macOS 端、文件／儲存邊界、Firebase 權限、依賴與建置設定。此為靜態原始碼稽核；沒有執行 App、效能測試或雲端規則部署。

## 摘要

專案已有可辨識的分層意圖與版本化文件契約，但實作仍處於「功能快速累積」階段：核心邏輯集中在少數超大型檔案、macOS Core 邊界尚未真正落地、Web 將文件／歷史／雲端同步耦合在根元件，以及另有未接入 UI 的文件 Session 原型。現階段不宜全域搬檔或刪除舊程式；應先處理權限和保存單一事實來源，再用小型可驗收切片拆模組。

## 優先級與證據

### P0 — 雲端權限目前不是黑板成員權限

- `firestore.rules:52-78`：任何登入者都可讀取任意 ID 的黑板；更新黑板只檢查登入與欄位格式，沒有驗證現有擁有者或成員；objects 子集合的讀／新增／修改／刪除亦只要求登入。
- `firestore.rules:83-92` 對 presence 限制使用者只能寫自己的 presence 文件，但所有登入者仍可讀任意黑板的 presence。
- `firestore.rules:33-39` 以固定型別清單驗證物件，但漏掉 `src/types.ts` 已允許的 `paint`；`firestore.rules:26-30` 也漏掉 `src/types.ts` 的 `staff` grid。Swift 另有 `curve` 物件型別，尚未進入 TypeScript/Firestore 契約。新增功能因此可能在離線／本機可用，登入後寫入卻被 rules 拒絕。
- 影響：登入不代表有權存取某份板。若 Firebase 專案正在服務真實使用者，這是發行前的安全阻擋項。不要直接改成 owner-only 再部署，需先定義邀請與成員角色欄位、既有分享板遷移及查詢條件，再同時更新規則與客戶端。

### P1 — 核心模組過大，職責混合

- `src/App.tsx` 約 1,280 行，同時管理登入、Firestore listeners/writes、歷史、圖層、圖片、首頁、定時自動保存、快捷鍵及所有畫面狀態。
- `src/components/Canvas.tsx` 約 2,540 行，把輸入手勢、選取／命中、橡皮擦、幾何預覽、文字編輯、SVG 呈現與多種物件繪製放在同一個元件。
- `macos/Sources/HeiBanCore/Engine/BoardEngine.swift` 約 3,700 行，還匯入 `SwiftUI`、`AppKit`、`UniformTypeIdentifiers`，並直接操作 `UserDefaults`、`NSPasteboard`、`NSImage`、`NSOpenPanel` 和 `NSSavePanel`。
- `macos/Sources/HeiBanMac/Views/CanvasView.swift` 約 1,200 行；模型／命令與平台 UI 的更動容易互相牽動。
- 影響：功能修正不容易隔離；也會提高回歸與畫布互動卡頓的診斷成本。先依「文件/指令、輸入、呈現、儲存/同步、平台適配」分界拆小，保留目前入口和文件格式。

### P1 — 原生文件流程有兩套保存／工作區抽象

- `LocalBoardLibrary`（`macos/Sources/HeiBanCore/Engine/LocalBoardLibrary.swift`）負責原子保存、revision 衝突、備份、縮圖與索引。
- `DocumentSession.swift:69-89` 又提供 `WorkspaceRepository` 目錄掃描；`DocumentSession.swift:93-153` 則透過直接 `Data.write(.atomic)` 管理 Session，沒有呼叫 `LocalBoardLibrary.save`，因此不包含其 revision 保護、備份與縮圖／索引更新。
- 稽核時這套 Session/Workspace 抽象只由 `HeiBanTestRunner` 引用，macOS App UI 尚未使用。這不是可安全刪除的死碼，因為測試覆蓋該原型且 W06 仍待完成；正式接入多文件前，須決定 DocumentSession 是唯一入口，並把儲存委派給 LocalBoardLibrary，或明確保留為外部檔案 session adapter，避免兩種文件生命週期互相競爭。

### P1 — Web 狀態與雲端同步耦合，且大文件寫入成本偏高

- `App.tsx:201-255` 用三個 effect 訂閱板資料、物件與 presence；`App.tsx:301-345` 管理逐物件去抖寫入與 unmount flush；`App.tsx:653-720` 的定時自動保存會同步產生縮圖、寫板 metadata，再逐筆寫入全部 objects，最後另存整份 JSON 到 `localStorage`。
- `App.tsx:183-190` 以最多 35 個 `BoardObject[]` 快照做 undo/redo，編輯時還要處理完整物件陣列。這和原生 `BoardCommand` 增量交易形成兩種歷史策略。
- `App.tsx:224-230` 的空 Firestore snapshot 不會清空目前 objects；若切換至雲端空白板，舊板內容可能留在畫面。不能只改成無條件清空，因為本機文件也可能在登入狀態中開啟；應先在 Repository/DocumentSession 層區分 local 與 cloud board，再定義 snapshot 套用策略。
- 建議：先把 `BoardRepository` / `SyncCoordinator` 從 React View 狀態抽出，採 revision-aware document snapshots 和增量交易；縮圖只在作品修訂改變時產生，Firestore 使用批次／佇列及可追蹤的保存狀態。

### P1 — 文件模型需要單一契約來源與同步規則

- Web `src/types.ts` 與 Native `BoardTypes.swift` 各自持有同一文件 schema，Firestore rules 又有第三份欄位與物件型別規則。
- 已有 `DOCUMENT_SCHEMA_CONTRACT.md`、fixtures 與遷移程式，這是良好基礎；但應把 schema 欄位、enum、可選欄位、擴充欄位和 Firestore 允許型別明確列成版本化契約，並由同一 fixtures 驗證 TS／Swift 讀寫與 rules 邊界。
- 跨平台重複幾何算法、Renderer 與匯出程式是合理的平台實作差異，不應為了消除重複而硬共用 UI／CoreGraphics 程式碼；該共用的是文件語意和案例。

### P2 — 依賴與建置設定有可整理項

- `package.json` 專案仍叫 `react-example`、版本 `0.0.0`；`@google/genai`、`express`、`dotenv`、`@types/express` 在目前 `src/`、Vite 設定與 manifest 外的程式沒有直接 import，疑似起始模板殘留。刪除前仍需確認未來 server/AI 工作是否已排程。
- 專案同時提交 `bun.lock` 與 `pnpm-lock.yaml`，兩份都是有效的獨立解析來源；目前頂層常用套件版本看似相同，但後續安裝與 CI 若選不同 manager，仍可能逐漸漂移。應選一個受支援的 package manager，並只維護一份正式鎖定結果；CI／README 尚需同步。
- `macos/scripts/` 有多個 `generate_*_icons.swift` 品牌探索版本。當前需要確認哪個是正式來源；若僅一版使用，將其他探索稿移到明確 archive，不要與生產資產混放。
- `dist/`、`.build/`、`.DS_Store` 已忽略；不要把它們當作原始程式碼清理，亦不應因整理而刪除使用者產物。

## 好的基礎，應保留

- 文件有 schema version、遷移、未知擴充欄位保留，以及跨 TS/Swift fixtures。
- Native 本機保存已有原子替換、備份和 revision 衝突保護；編輯有 command/transaction 歷史。
- Native 與 Web 的 freehand preview 都已刻意把高頻暫態筆跡與主要 board state 分開；這個輸入邊界應成為後續性能重構的基準。
- 參考專案的借鑑範圍是桌面檔案工作區與原生生命週期，不是照搬其遠端畫布／localStorage 傳輸方式。

## 建議整理順序

1. **先完成資料與安全邊界**：決定 local/cloud board 身分與分享成員契約；修正 Firestore rules 與空 snapshot 語意，確認既有分享不回歸。
2. **統一 Native 儲存入口**：正式把 DocumentSession 接到 LocalBoardLibrary，移除或合併重複的外部工作區掃描和檔案保存實作。
3. **將 Native Core 去平台化**：先抽 `PlatformFileDialogs`、剪貼簿、影像解碼、偏好儲存與觸覺回饋 adapters；Core 保留文件、幾何、命令、歷史和 repository protocol。
4. **拆 Web 大元件**：先將 App 分成 board session / local repository / cloud sync / screen composition；再把 Canvas 分為 pointer controller、hit test/geometry actions、object renderer、overlay layers。每次只搬一個完整垂直流程。
5. **統一交易語意**：讓 Web history 與 Native BoardCommand 使用相同的「一次手勢＝一次可逆交易」文件案例，避免任一端整板快照成為長期路線。
6. **清掉確認的模板與重複設定**：選定 lockfile、更新 package identity、盤點死依賴、統一 icon source；清理要跟版本控制清單和可重現建置一併完成。

## 本輪已完成的安全清理

- `src/firebase.ts` 移除未使用的 `signInWithPopup`、`signOut` imports；登入／登出實際由 `src/App.tsx` 呼叫 Firebase Auth。
- 未自動刪除依賴、另一份 lockfile、Session 原型或品牌圖示腳本，因為它們可能是尚未接線的產品工作；須依上方順序整合或經證實後淘汰。

## 限制

此輪是靜態程式檢視。沒有執行測試、GUI 操作或 Firebase 模擬器，也沒有部署 Firestore rules。文件中的安全／資料流程發現應在正式連線雲端和重構前，加入 rules emulator 案例及雙端文件回歸案例。
