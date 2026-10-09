# Mac 架構決策紀錄

更新：2026-10-09。決策有取捨，後續變更以新編號取代，不刪除原理由。

## ADR-M01 — 平台目錄分離

狀態：採用。原生 UI、腳本、資源與產物在各平台目錄；共用 JSON 語意。原因：發揮各平台原生輸入／渲染能力，避免 Mac 建置帶入 Windows 依賴。代價：需要各平台各自驗收，不能宣稱 Swift 演算法天然可編譯於 Windows。

## ADR-M02 — 作品原稿 `.heiban` v1

狀態：採用。內部 UTF-8 JSON、有 schema version、保留未知欄位；現有作品庫檔名維持相容。大型圖片 ZIP 資產容器列 v2 規劃。原因：單檔可攜、保留現有作品，不依賴 Swift 私有序列化。代價：內嵌圖片體積大。詳見可編輯文件設計。

## ADR-M03 — 暫態預覽和永久資料分開

狀態：採用。筆畫、尺規、雷射各有局部狀態，永久物件完成才提交。原因：避免 UI 在每個取樣重算。代價：兩種生命週期要清楚管理；渲染需主動讀取新樣本，不能因沒有 @Published 而漏畫尾跡。

## ADR-M04 — 先拆責任檔案，保留單一編輯狀態

狀態：本輪採用。BoardEngine 以職責延伸檔拆分；保持公開命令與唯一 board／objects。保存排程另由內部 BoardPersistenceState 持有。沒有替每個延伸檔建立一個轉呼叫的 service。

原因：目前許多工具共用手勢與歷史，強拆第二套可變狀態易導致選取、undo、頁面與存檔不一致。代價：BoardEngine 仍是較大的 ObservableObject；下一階段需按實測熱點分離 publisher／資料 owner，而不是只追求檔案行數。

## ADR-M05 — 批次樣式與共用匯出管線

狀態：本輪採用。樣式更新共用鎖定過濾、時間戳、批次發布、交易；HTML／SVG／PDF／PNG 共用對話框與原子寫入。原因：防止新增屬性或格式漏掉 undo、失敗提示或保存規則。代價：格式生成仍同步，巨大作品的背景匯出留待量測。

## ADR-M06 — 保留未接線基礎，隔離真正檢查替身

狀態：本輪採用。導圖、表格、公式、DocumentSession、登入、雲端、協作與更新原型記錄在狀態清單；MockKeychainStore／MockCloudSyncTransport 僅在既有 runner 編譯。舊品牌腳本封存。

原因：原型與既有檢查有用途，不能用「目前 UI 沒用」作刪除依據；正式產品不應帶檢查替身。代價：需持續維護狀態與產品入口，不把原型誤算成移植完成。

## ADR-M07 — 開發紀錄與手冊有固定來源

狀態：本輪採用。AGENTS 要求開工日誌、進行中追加、交付更新 CURRENT_STATUS／ISSUE／ADR。日誌工具只產生模板；內容由開發者填真實證據。手冊生成源收入版本控制，HTML／Markdown 為衍生輸出。

App 封裝與手冊版本共同讀取 `macos/Release.json`，避免 README、手冊及打包腳本各自硬編碼不同成品版本。

原因：跨人員／工具接手時保留排錯理由，避免暫存程式遺失、文件彼此漂移。代價：每批需投入文件維護；規則不會自動感知外部開發者沒有遵守，也不等同自動提交 Git。

## ADR-M08 — 跨程式螢幕畫布由原生視圖擁有輸入

日期：2026-10-09，1.0.8。採用。NSPanel.contentView 是 AnnotationInputView，繼承既有 PointerView；SwiftUI renderer 為不可命中的子視圖。世界座標等於每顯示器左上本地座標，viewport 鎖定 identity。首點接受輸入；透明空白 backing 使用 1% alpha 以保留 WindowServer 輸入覆蓋。

視窗層級為 statusBar + 1／+ 2，仍在 popup menu 之下，加入 canJoinAllApplications。沒有使用 screenSaver 層級，因為它會蓋住系統選單與工具 popover。自己的保存／確認對話框期間隱藏疊層，之後依生命週期恢復。作畫切換保留工具；文件恢復後才設定初始工具。

原因：一般 floating 無法涵蓋其他 App 浮動／演示工具；空白 transparent SwiftUI 組合不能作為整屏原生輸入覆蓋的契約。代價：約 1% 背景色差；特殊獨佔全螢幕、系統安全畫面仍不保證可覆蓋。原生 UI 診斷受工具視窗綁定與前景變動影響，未將編譯或控制列觀察當作所有 App 成功的證據。

ADR-M08 依據：[Apple 首點輸入契約](https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:))、[Apple 跨 App 視窗集合](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications)。另核對本機 macOS SDK NSWindow.h 層級及互斥 collectionBehavior 定義。Web 工具無法讀取 Apple markdown MIME，改以唯讀 curl 取得首點說明；SDK 明確列 canJoinAllApplications 適用於系統 overlay。

## ADR-M09 — 公開預覽、原始碼與下載包分離

日期：2026-10-09。使用者選擇 GPL-3.0；原創程式採 GPL-3.0-only。平台版本獨立，Mac ARM64 1.0.8、Windows ARM64／x64 preview.5 分別建立 prerelease。Git 儲存原始碼、資源、可重建腳本、手冊及排錯摘要；Release 儲存下載包與 SHA-256，不把 dist 放進 Git。

Windows 原 Setup／Portable 保持不變；公開 Installer ZIP 包裝原 EXE，Portable 追加授權與說明，重新計算公開包雜湊。最新 HTML 手冊另供下載，避免不重編譯卻聲稱換了包內資源。Mac 不加入 Windows 元件／授權副本。作品、憑證、參考專案與原始編譯日誌排除；Firebase 公開用戶端設定不冒稱 Admin secret，雲端實際規則不在本輪驗收。

原因：同時保存既有產物的可追溯性與公開再散布資訊，清楚區分已完成、未驗收與規劃功能；下載不含作品。代價：未正式簽章的預覽有首次開啟提示；Windows 套件使用實際 Microsoft 條款，其 GPL 連結例外待擁有者確認。
