# Mac 困難、錯誤與排解紀錄

更新：2026-10-09。狀態「程式已修正」不代表所有使用場景驗收通過。歷史紀錄依已有文件回溯，不推測不存在的根因。

## M01 — 浮動工具拖曳跳位

狀態：歷史修正，見 [1.0.4 操作紀錄](../TOOL_INTERACTION_FIXES_2026-10-09.zh-TW.md)。

- 症狀：計算機／計時器點按後跳開，難以找回；工具列拖曳不穩。
- 原因：整個面板的拖曳手勢與按鈕競爭；每次加上完整 translation 使位移重複累積。
- 排解：只拖標題／握把，保存起始位置並加本次位移，按面板實際大小限制可見範圍。重新呼叫工具時回到可見位置。
- 防止再犯：內容按鍵、滑桿與捲動區不能兼作拖曳區；拖曳中不反覆切換橫／直排列。

## M02 — 錄製授權開啟但截圖仍失敗

狀態：1.0.5 已修正既有流程；透明螢幕註記的合成截圖仍待驗收。詳見 [截圖修正與證據](../SCREEN_CAPTURE_FIX_2026-10-09.zh-TW.md)。

- 症狀：設定顯示授權，內建截圖仍不能直接使用；系統選取後收到 ScreenCaptureKit -3801。
- 確認原因／邊界：舊 ad-hoc 二進位識別可能與目前 App 不同；廣域權限與一次性 picker 權限不能混用。
- 失敗方案：選取授權後直接呼叫 SCScreenshotManager，仍收到 -3801。
- 排解：完整 App 固定識別簽章；有效廣域授權用單張截圖，picker 授權用 SCStream 取得第一個完整影格後立即停止，再區域裁切；等待 picker 退場避免 UI 進入截圖。
- 注意：開發機沒有正式簽章憑證，不保證每次 ad-hoc 更新後舊 TCC 授權持續有效。不自動清除使用者權限設定。

## M03 — 雷射卡頓與沒有移動尾跡

狀態：1.0.4／1.0.6 程式修正與部分 UI 觀察，尚無延遲／FPS 量測。

- 症狀：高頻取樣刷新整個 UI；後來取樣存在，Canvas 卻沒有持續畫出新尾跡。
- 原因：樣本發布／繪圖回呼清理造成重複更新；取樣改為非發布後，渲染閉包若不讀取 Timeline 的新時間可能被重用；hover 取樣未完整接入。
- 排解：獨立有界緩衝、hover／drag 都取樣；每幀傳入新時間；最多 24 個透明度桶批次畫線，過期定時清理，停用時取消。
- 防止再犯：不能把不發布誤解為不用驅動畫面更新；光點模式本來沒有尾跡，驗收先確認模式。設定入口就近放在工具按鈕。

## M04 — 圓規準備階段誤畫、預覽座標偏移

狀態：1.0.6 已實作兩階段；準備／鎖定／提交曾做原生觀察，最後座標修正仍需完整使用驗收。

- 症狀：調起點時就畫弧；輔助預覽與提交物件位置可能不同。
- 原因：缺少 prepare／armed 狀態；圓規在工作區外層，其他物件在忽略頂部安全區的畫布內層。
- 排解：點中心才 armed，橘色提示；鎖定後拖筆尖，保留準備起點、累計跨零角差；無位移不生成整圓。把圓規 overlay 移到 CanvasView 的同一座標空間。
- 防止再犯：暫態工具和永久 renderer 必須使用同一 canvas 原點，不能只比較數值相同的 viewport。

## M05 — 多選樣式更新重複、退出重複保存

狀態：1.0.7 程式整理；編譯確認，未做互動回歸。

- 發現：多個 setter 複製同樣的鎖定過濾／時間戳／逐物件替換／undo／保存；MainWindow 和 AppDelegate 都在退出寫快照。
- 排解：共用批次樣式命令，一次 objects 發布、一筆交易；退出以 AppDelegate 為唯一入口。保存成功才更新記憶體 revision，失敗可重試。
- 注意：MainWindow 的資料 onChange 仍保留，涵蓋 UI 直接修改；它與命令排程共用 debounce，不是第二條磁碟寫入管線。

## M06 — 快取資料沒有真正失效，成本上限沒有生效

狀態：1.0.7 程式修正；未做視覺／記憶體量測。

- 發現：key 只含 id、updatedAt、points 字數與寬高。相同字數的點位修改、秒內多次更新、復原可能符合舊 key；NSCache 未傳 cost，totalCostLimit 無法依估算成本驅逐。
- 排解：不可變 key 比較實際 type、位置、尺寸及完整 points；寫入傳入估算成本，保留 countLimit。
- 取捨：完整 String hashing 也有成本，沒有宣稱更快；後續大量長筆畫應量測，再評估解析器／版本 token。128 MB 是快取驅逐參考，不是程序記憶體硬上限。

## M07 — 多文件載入遺失文件 header、保存擁有者混用

狀態：1.0.7 核心基礎修正；多文件 UI 尚未整合，未驗收往返。

- 發現：DocumentSession 開啟／外部 reload 只直接設定 board／objects，忽略 schema version 和 extraFields，也保留舊歷史；自動保存可能寫入全域 library 而非注入的 session library。
- 排解：共用 activate(document)；session engine 關閉普通作品庫自動保存，由 session.library 保存。
- 同批修正：saveAs(repointSession: true) 重建追蹤新 URL 的 coordinator，避免外部變更檢查讀舊檔。
- 仍待處理：外部監視器與正式 UI 的整合、實際多文件往返驗收。不可當成已完成多文件服務。

## M08 — 移出 Mock 後編譯失敗／假登入入口

狀態：1.0.7 排解。

- 實際失敗：第一次全產品編譯報 `cannot find MockCloudSyncTransport in scope`。
- 原因：跨檔引用盤點沒有包含雲端協調器同檔的預設 initializer；檢查替身被隱含指定為預設 transport。
- 排解：constructor 要求明確注入 transport；既有檢查均已提供 transport，替身保留在 runner Fixtures。後續全產品編譯與 Release 封裝成功，沒有執行檢查程式。
- 另一發現：「Google 登入（準備中）」曾以延遲建立示範帳號，並非 OAuth。
- 排解：移除假登入動作並停用尚未接入的按鈕；沒有冒充實際授權、也沒有自動清除使用者既有帳號資料。
- 防止再犯：刪移符號前也查同檔預設參數、工廠與泛型；本機 mock 不能當產品預設。檢查程序能編譯，不等於登入／雲端已交付。

## M09 — 偏好設定尚未真正接入產品行為

狀態：開放，優先級 P1。

AppSettings 的主題／自動保存頻率／部分預設值存得下來，但目前 App 強制 light，普通保存仍固定 0.7 秒。需盤點每項設定的實際 reader，決定接入或暫停入口。這輪沒有默默改成長延遲保存以免降低資料保全；使用手冊與目前狀態不得宣稱這些設定全部生效。

## M10 — 備份與索引失敗缺少可見回饋

狀態：開放，優先級 P1。

LocalBoardLibrary 的主要原稿失敗會 throw，但部分備份、縮圖／索引用 try?。下一步應區分原稿成功與衍生資料警告，並記錄可重試失敗，不要把備份失敗一律當成原稿失敗，亦不可顯示全部成功。CloudSync 佇列也需在正式啟用前處理寫入失敗。

## M11 — 執行緒、長作品與實機驗收

狀態：開放，優先級 P1／P2。

- Core 可變編輯狀態還未完整 MainActor 化；背景工作只能處理值型別快照。
- 全域快捷鍵在其他 App 前景、透明層跨 App 作畫、合成截圖、多螢幕／全螢幕與螢幕分享未完整驗收。
- 圖片解碼、部分匯出與縮圖仍同步；大量內嵌圖片和長筆畫需量測。
- 新 SDK 對 CanvasObjectsView 的 NSParagraphStyle → AttributedString Sendable 提示仍存在；沒有用 unchecked conformance 或全域忽略掩蓋。工具鏈亦有 CommandLineTools library/framework 搜尋路徑警告。
- 既有 runner 的五個未變動變數／未使用結果警告仍保留；本輪沒有改寫既有檢查案例，也沒有引用其歷史執行結果。

## 記錄格式

新增問題填「日期／版本、症狀、證據、確認原因與推測、失敗方案、實作修正、驗收狀態、防止再犯、下一步」。不能只留一句「已解決」。

## M12 — 螢幕畫布跨 App 無法落筆／切換模式丟失工具

日期／版本：2026-10-09，1.0.8 / 20261009.7。狀態：程式修正完成；完整跨 App 實機驗收待確認。

症狀：其他程式上無法畫筆／圖形，使用者懷疑疊層。確認原因：Session 恢復會經 activate 清理工具；Controller.setDrawing 又呼叫 cancelTransientInteraction，把 currentTool 改成 select；在操作模式點畫筆亦先選工具、再被 setDrawing 清掉。selectDisplay 重複調用 toggle 會把另一螢幕相同工具反向取消。

疊層證據：原設定只有 floating，未 opt in canJoinAllApplications；空白 transparent SwiftUI host 未具明確原生整屏命中所有權。這兩項為覆蓋／輸入的設計缺口，尚未隔離量測每一項對使用者各 App 的實際影響。viewportLocked 只禁止平移／縮放，不是禁止畫筆的原因。

修正：原生 AnnotationInputView 全尺寸接收首點與 drag，不讓背景點擊移動 panel；1% backing 避免透明像素穿透；renderer 不命中。statusBar + 1／+ 2、canJoinAllApplications、Space／啟動重排；modal 暫隱。模式切換保存工具／樣式，恢復後初始化，跨顯示器只在工具不同時同步。

診斷：Debug 編譯成功；獨立資料目錄觀察到操作模式點畫筆後「作畫」與畫筆高亮，結束回 0 作品首頁。第二次觀察到獨立全尺寸螢幕 panel 已取得焦點；原生 drag 工具回報前景／視窗改變，刷新後疊層已關閉，沒有觀察到有效筆畫，所以不宣稱跨 App 筆畫已驗收。未執行測試套件。

防止再犯：UI toggle 不作冪等同步；文件啟用／模式切換的工具清理須明確恢復；層級調高必須一併檢查自己的 modal／menu。下一步：使用者實機確認問題 App、普通全螢幕、Space、多螢幕、合成 PNG 與實體全域鍵。

## M13 — 公開包缺授權及套件 metadata 解碼失敗

日期：2026-10-09。狀態：文件與封裝處理中，發佈結果見公開稽核。

原私人 Windows preview.5 ZIP 沒有 license entries，儲存庫沒有 LICENSE／Release。使用者明確授權公開並選 GPL-3.0。補 GNU 官方完整授權；實際 NuGet runtime 條款不同於 GitHub 原始庫 MIT，因此按精確版本取得 nupkg 內文／notice，不能只附一張來源 MIT 檔。

失敗方案：urllib 直接將 gzip registration 視為 UTF-8 JSON，UnicodeDecodeError。修正：辨識 gzip magic 解壓後讀 metadata；舊 licenseUrl 部分 deprecated／轉址，改 HTTP Range 讀 nupkg ZIP 內文。Win2D 舊 license URL 已轉到教學頁，記錄此缺口並附官方來源授權。Windows SDK 相依例外已具體擬稿並向擁有者詢問，使用者已同意限定平台元件例外。

包裝不改 Windows 程式 payload、原 dist 不覆寫；公開 ZIP 明列授權，SHA-256 重新計算。Mac 採 ARM64 DMG／ZIP；hdiutil create 成功但新系統提示命令 deprecated，未影響此次成品，後續改用 diskutil 時需核對較舊 macOS 工具相容性。git diff --check 的既有 Swift 行尾空白只作格式清理；未加／未跑測試。
