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

日期：2026-10-09。狀態：本次公開文件與封裝完成，兩平台公開下載大小／SHA／HEAD已核對；正式簽章／完整互動驗收仍待辦。發佈結果見公開稽核。

原私人 Windows preview.5 ZIP 沒有 license entries，儲存庫沒有 LICENSE／Release。使用者明確授權公開並選 GPL-3.0。補 GNU 官方完整授權；實際 NuGet runtime 條款不同於 GitHub 原始庫 MIT，因此按精確版本取得 nupkg 內文／notice，不能只附一張來源 MIT 檔。

失敗方案：urllib 直接將 gzip registration 視為 UTF-8 JSON，UnicodeDecodeError。修正：辨識 gzip magic 解壓後讀 metadata；舊 licenseUrl 部分 deprecated／轉址，改 HTTP Range 讀 nupkg ZIP 內文。Win2D 舊 license URL 已轉到教學頁，記錄此缺口並附官方來源授權。Windows SDK 相依例外已具體擬稿並向擁有者詢問，使用者已同意限定平台元件例外。

包裝不改 Windows 程式 payload、原 dist 不覆寫；公開 ZIP 明列授權，SHA-256 重新計算。Mac 採 ARM64 DMG／ZIP；hdiutil create 成功但新系統提示命令 deprecated，未影響此次成品，後續改用 diskutil 時需核對較舊 macOS 工具相容性。git diff --check 的既有 Swift 行尾空白只作格式清理；未加／未跑測試。

## M14 — 螢幕工具列固定橫排／清除時露出首頁

日期／版本：2026-10-10，1.0.9 / 20261010.1。狀態：實作／本機編譯／App封裝完成；互動實機待驗收。

症狀：不能左右直排，使用者希望自由停靠；「清除註記」露出黑板首頁。可確認來源：工具列固定740×102，Grip只移動panel；clearAnnotations隱藏全部疊層後NSAlert.runModal，清除不是stop／clearAll返回首頁，但modal／疊層隱藏會露出底層黑板視窗。未實機隔離每個焦點情境，不將來源推論當成量測。

修正：四邊停靠幾何與獨立偏好；native拖動中不轉向，放開一次重排；直向工具／色彩／滑桿、可捲動內容與固定動作區；更多選單直接選邊。清空不走modal／withHiddenOverlays，不切模式、不停止；取消未完成筆畫後恢復工具／樣式，清永久物件及雷射，立即保存screen recovery，仍有每螢幕undo。

證據：Debug product編譯成功；Release product成功29.25秒，App版本與簽章檢查成功，封裝與舊App保留記於日誌。未跑測試／UI驗收。舊1.0.8 App保留dist/archive；普通作品／Windows來源不改。防止再犯：清除與結束分開，清除不啟用主視窗；拖曳只改原生origin、release才更新佈局；位置不保存螢幕絕對座標。下一步：四邊／短螢幕／不同縮放／多顯示器實機拖曳、作畫及穿透模式清空／復原／重開。

## M15 — 側邊工具列文字與常駐屬性占空間

日期／版本：2026-10-10，1.0.10 / 20261010.2。狀態：實作／Release 封裝完成，互動實機待驗收。

使用者提供左側直向工具列截圖，要求不顯示文字且再縮窄。確認原因：1.0.9 側列原生寬度 152 pt、工具按鈕寬 122 pt；工具名、模式與滑桿／狀態文字常駐，底部動作又分兩個橫排。

修正：64 pt 單欄純圖示，模式、工具、底部動作與更多均不顯示文字；移除側邊更多的複合箭頭，色圓開啟共用樣式面板。工具名稱保留 help／accessibilityLabel，狀態訊息收進更多／面板／模式提示。清空／結束不變更生命週期。

證據：build_app.sh Release product 成功 26.64 秒；App 版本、手冊 1.0.10／64 pt 內容與嚴格簽章檢查成功；git diff --check -- macos 成功。沒有本批編譯錯誤／失敗方案；既有 NSParagraphStyle Sendable、未變動 auxInfo 及 CLT 搜尋路徑警告保留。未跑測試套件／實際 UI 操作，不以編譯證明 popover、短螢幕、多顯示器可用。

防止再犯：native 尺寸與 SwiftUI 內距／圖示命中範圍一起修改；不能只隱藏文字卻保留寬面板；不能把失敗提示完全隱藏。下一步：確認左右窄列、彈出設定、四邊切換與短螢幕捲動。

## M16 — 顏色與筆刷面板左右裁切／上下工具列多列占位

日期／版本：2026-10-10，1.0.11 / 20261010.3。狀態：排版修正、編譯與封裝完成；實機待驗收。

症狀：使用者提供左／右面板裁切與上下工具列截圖，希望四邊均以色圓開設定、上下縮為單列。確認來源：264 pt popover 內六色橫排、兩個固定寬滑桿橫排；截圖顯示原生灰底色鈕撐寬、標題／滑桿左端與末色右端超出容器。面板未明訂自身 buttonStyle／自然尺寸。未實機隔離每項因素，不把源碼推論當作量測。

修正：獨立 AnnotationBrushSettings，根部 plain 樣式／280 pt 自然寬度／自然高度，色票 3×2 且明訂命中尺寸；滑桿垂直全寬、狀態可換行。四邊使用相同面板／bindings，不複製 engine 樣式。上下 60 pt 單列，移除常駐設定與狀態；色圓與清空／結束固定在捲動區外。

證據：Release 15.15 秒成功、App 封裝／codesign 深層嚴格檢查成功，版本與內建手冊為 1.0.11，手冊包含四邊入口／60 pt；git diff --check -- macos 成功。未新增／執行測試套件、未操作原生 UI；左右／不同縮放下的 popover 與上下列仍待驗收。沒有本批編譯失敗；既有 NSParagraphStyle Sendable、CLT 路徑警告未動。

防止再犯：彈出根視圖明訂尺寸與樣式，色盤／滑桿不以外框強裁切；工具列高度與視圖內距一同改，四邊入口只有一份設定內容。下一步：實機四邊開啟／點色票／滑桿／多螢幕及短螢幕確認。

## M17 — 螢幕畫布缺文字入口／文字設定未集中右鍵

日期／版本：2026-10-10，1.0.12 / 20261010.4。狀態：實作／編譯／封裝完成，實機待驗收。

確認來源：螢幕控制列沒有 .text，renderer 整體 allowsHitTesting(false) 且 host.hitTest 返回 nil；父視圖總是自己接輸入，文字草稿的編輯器沒有渲染／可互動入口。右鍵只有複製／刪除等，文字大小／顏色常駐普通輸入面板，沒有批次文字命令。

修正：T＋原生父視圖內可互動 editor，僅編輯區命中子視圖，其餘全屏原生輸入保留；只觀察 editor 開關／錨點。共用 NSTextView／內容面板及右鍵文字選單，移除常駐格式列／純文字快速改色。新增 batch 文字命令，跳過本頁以外／鎖定／非文字物件，色彩／字形同步 rich spans，字級擴高，整批一筆歷史。自訂欄位只傳修改項、核對對象；草稿格式走 all:、取消不寫文件，新一輪清除舊格式 action。Esc 不被螢幕暫停攔走，暫停／保存／換工具／截圖／停止先提交。

過程問題：手冊文字章節新內容一度誤用 07，來源盤點確認原為 10，重新生成／封裝；hitTest 審視時修正為傳父座標，而非把 local 再轉成子座標。未將這些來源修正當作已發生的實機錯誤。沒有編譯失敗；舊 glob 查詢未匹配改用 rg 正確路徑。

證據：預先 Release product 成功 25.77 秒；最終 build_app.sh Release product 成功 29.64 秒，App 版本／手冊／嚴格深層簽章成功，21 章、文字 10；archive 無 App，git diff --check -- macos 成功。既有 auxInfo／NSParagraphStyle Sendable／CLT 路徑警告保留。未新增／執行測試套件或原生 UI；中文輸入、框選／Shift 多選、混合物件隔離、popover／多顯示器及取消／保存仍待實機確認。

防止再犯：新增工具必須核對 toolbar／輸入／editor 命中／renderer／歷史／恢復／快捷鍵，不只補 icon；修改物件文字顏色須覆寫 spans。下一步依上述實機流程驗收，不把編譯當操作證據。


## M18 — 螢幕文字未顯示：尚未按完成

日期／版本：2026-10-10，1.0.12 / 20261010.4。狀態：使用者確認按完成後顯示，無本批程式修正。

初始回報：試打文字沒有出現在螢幕。先追查 editor／Binding／提交／Canvas 與頁面過濾，並詢問是否按完成。調查時看到原生最後內容同步及邊緣物件布局的來源疑點，但沒有操作重現。使用者後續回覆「我剛剛按完成，可以了」：本次文字仍是草稿，提交後已顯示。

排解：T → 點螢幕 → 輸入 → 完成或 ⌘Enter；Enter 換行，Esc 取消。回覆到達前的未封裝快照 bridge／高度／邊界改動已逐項撤回，不把推論寫成已重現故障，也不把未驗收修正交付。保留既有 1.0.12 內容與開發紀錄，沒有新 build／App／測試；Windows 未動。

證據僅為本次使用者基本操作成功，不代表所有 IME／多螢幕／右鍵批次流程均通過。後續若仍有「完成後不見」，應先確認提交階段、選取框與點位，再定位實際輸入或渲染原因。


## M19 — Windows 新圖釘配色／未知欄位在 Mac 往返缺乏保全

日期：2026-10-11。狀態：已排解（實作、[測試 46] 客觀斷言 100% 通過與發行封裝驗證）。

Windows BoardPin 已有 color／textColor 及 JsonExtensionData。已在 Mac `BoardPin` 增加 `color`、`textColor`、`boardId` 與 `extraFields: [String: AnyCodableValue]?`，實作自訂 Codable 保全未知欄位；提供 `effectiveColor` / `effectiveTextColor`；畫布、左側導覽、頂導覽與右鍵支援色彩設定與單次 Undo。經 [測試 46] 35 項斷言驗證跨平台往返無損。

## M20 — Mac 設定中的版本／回報網址與發行來源不同

日期：2026-10-11。狀態：已排解（實作、[測試 26] & [測試 46] 客觀斷言 100% 通過與發行封裝驗證）。

`AboutInfo` 已對齊 `1.0.12` / `20261010.4`（支援 Bundle 動態識別與預設回退）、`feedbackUrl` 修正為 `https://github.com/VirginBear/HeiBan/issues`、補齊 1.0.12 變更紀錄；測試套件已同步對齊真版本與更新日誌，`build_app.sh` 封裝與深層簽署成功。


## M21 — 自訂 BoardPin decoder 破壞舊座標標記語意

日期：2026-10-11。狀態：已排解（實作修復、相容性探針 4/4 通過、測試套件 1,559 項全數通過與 App 重新封裝簽章）。

來源 31576eb 的 `BoardTypes.swift:406` 對缺失／null `isWorldSpace` 補 `?? true`，導致舊版 viewport offset 標記提前被視為世界座標，跳過座標轉換與遷移。已修正為保留原生 `decodeIfPresent` 之 `nil` 語意。
在 `HeiBanTestRunner` 新增 46.6 與 46.7 斷言，涵蓋 missing／null／false／true 完整解碼、座標計算、單次遷移防呆與往返重開；獨立編譯 probe 達成 4 passed 0 failed；完整 runner 1,559 項斷言 100% 通過；`build_app.sh` 重新編譯封裝成功。


M21 獨立複核補充（2026-10-11）：f960c78 下完整 runner 1559/1559、Release Core 四案例4/4均通過；本機App簽章與Release建置碼段一致，可開始實機試用。未重新操作UI或Windows重開檔；詳見日誌05。


## M22 — 工具列追齊清單範圍不足與儲存回饋誤報風險

日期：2026-10-11。狀態：已完成來源審視與交接清單，實作待做。

使用者實際回報Windows工具列細節較完整。原MAC-SYNC-03／04偏重螢幕列，沒有完整主列預設／catalog／偏好遷移／選取樣式／收合。Windows後續UX_FEEDBACK覆寫原捲動決策，Mac仍固定螢幕尺寸與中段ScrollView；若沿用舊紀錄會做錯方向。已分兩種工具列整理TB01–10及驗收條件，保留Mac窄欄／T／文字右鍵／色圈設定等既有要求。

另靜態確認TopNavView saveLabel有「尚未儲存」值，但statusIndicatorView非失敗／儲存中分支仍畫綠點並提示所有變更已安全寫入；需真實dirty／草稿／交易／寫入狀態，已列TB03。沒有操作UI重現，也尚未修功能。本次未編譯、執行測試或封裝；不得使用上一輪1559數字代表工具列驗收。詳見 [完整工作清單](../ANTIGRAVITY_MAC_TOOLBAR_WORKLIST_2026-10-11.zh-TW.md)。
