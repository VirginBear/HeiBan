# Mac 困難、錯誤與排解紀錄

更新：2026-10-13。狀態「程式已修正」不代表所有使用場景驗收通過。歷史紀錄依已有文件回溯，不推測不存在的根因。

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


## M23 — 工具列隱藏偏好重新載入時被normalize移除

2026-10-11，來源764c8e6。狀態：Release probe已重現，待修。setItemHidden保留active但新增hidden，normalize共用seen將hidden同ID移除，pen／layers重開恢復顯示。測試47的互斥fixture未覆蓋真實hide命令產生的重疊格式。需保留順序＋遮罩契約，補hide→保存→重開／重複normalize測試。見工具列複核報告。

## M24 — 儲存指示只解析舊字串，未讀取真實文字草稿

2026-10-11，來源764c8e6。狀態：Release probe已重現，待修。上次saved→beginInlineTextEntry→非空textDraft仍saved，因回饋只讀autosaveStatus、文字未提交不排程保存；直接測「草稿中」字串不代表實際UI生命週期。需真實草稿／交易與寫入回報，補取消／提交／成功／失敗完整流程。見工具列複核報告。

## M25 — 新toggleViewportLock只改布林，與導航入口行為不同

2026-10-11，來源764c8e6。狀態：Release probe已重現，待修。工具列toggle後文字仍editing，既有setViewportLocked則先提交、清理暫態與縮放。需統一走既有命令，補各入口與文字／手勢中的切換。見工具列複核報告。


### M23–25獨立回歸複核（2026-10-11，7198f11）

上次同一份Release probe7/7與完整runner1642/1642均獨立重跑通過，App／Release碼段一致、簽章有效。M23隱藏保存重開與M25統一導航命令已修復；M24非空新文字草稿不再誤報已存，完整未修改／清空既有文字／富文本／live交易／保存中草稿及取消流程尚未全验收。可以交一般工具列第一批實機試用，不代表TB04–10完成。前文「待修」為當時重現歷史，本節更新目前結果，詳見日誌09。

## M26 — 右上列常駐、圖層拖曳缺回饋與首頁入口不明顯

狀態：1.0.13 已實作，實機互動待驗收；見 [本批日誌10](logs/2026-10-11/10.zh-TW.md)。

- 使用者回報 Windows 已有自動隱藏、Finder 式拖曳回饋及首頁螢幕畫布入口，Mac 未跟上。
- 確認：MainWindowView 直接常駐 TopNav／ReadingNavigation；LayerPanel 只有排序按鈕，沒有拖曳生命週期；首頁入口藏在使用說明選單。
- 排解：新增穿透 tracking area／延遲隱藏／固定偏好；選單與 popup 開啟時保留；圖層左側握把發起原生拖曳、來源淡化／跟隨預覽／上下插入線，放開單次交易，取消不排序；新增帳號與設定上方獨立入口。
- 注意：目前一次拖一個物件，鎖定來源先解鎖。長列表拖曳捲動、Esc／拖出／失焦、閱讀／popover 保留、視窗縮放與實際往返復原尚未操作驗收；不表示 TB04–10 的整份螢幕工具列需求完成。

## M27 — 存檔頻率設定與實際排程未接通

狀態：2026-10-12，設定與一般／螢幕非同步退出保存已實作，編譯成功，尚未執行測試或操作驗收。見[清晨更新比對](WINDOWS_SYNC_REVIEW_2026-10-12.zh-TW.md)／MAC-SYNC-13／[日誌02](logs/2026-10-12/02.zh-TW.md)。

- 發現：Views/SettingsView.swift的「本機自動存檔頻率」Picker更新AppSettings.autoSaveFrequency；全來源rg显示沒有保存排程讀此值，BoardEngine+Persistence.scheduleAutosave固定0.7秒。模型／偏好存取通過舊檢查不表示實際timer接通。
- 對照：Windows c409a6e引入真正autoSaveEnabled、手動與離開保存、退出進度；本批只取回來源，沒有把該政策直接複製到Mac。
- 排解：設定新增獨立開關，保留既有頻率並讓舊 `manual` 偏好遷移為關閉；一般作品與螢幕恢復檔依同一開關／頻率排程。手動保存與正常退出不讀取自動保存開關。偏好先成功編碼／寫入 UserDefaults 再替換記憶體狀態。AppDelegate 使用 `terminateLater` 等待一般作品及各螢幕恢復檔背景保存，成功才退出，失敗留在應用程式；退出期間攔截本 App 編輯事件。
- 尚待驗收：未測試關閉後等待、不同頻率、舊偏好遷移、慢寫入失敗／再試、正在編輯文字退出及多顯示器退出。截圖期間退出目前拒絕該次要求，須待截圖結束後重試。
- 邊界：未關閉 Mac 現有資料保存；這不是繪圖頓感已證實根因。需量測序列化／磁碟／縮圖及 input→preview 後再評估性能收益。Swift build 成功，不代表 UI／資料生命週期驗收。


## M28 — 螢幕色彩設定只改未來筆刷且沒有自訂色彩入口

2026-10-13現況補註：以下是10/12日誌04的第一輪狀態；最終M37／日誌09已共用ToolbarBrushSettings，包含Hex／最近色、有效型別的填色alpha／漸層／線型／箭頭尺寸。先前「尚缺」不是目前來源結論；最終混合值／鎖定／Undo／四邊實機仍未驗收。

狀態：2026-10-12 第一輪接線與 Debug 編譯成功，尚待介面／undo 實機驗收，見 TB06／[日誌04](logs/2026-10-12/04.zh-TW.md)。螢幕控制列色圈原本只有六個固定色票，且顏色／粗細／透明度永遠改所有 Session 的未來筆刷，沒有作用於目前已選取物件。

已加入原生 ColorPicker 與六個色票；有選取物件時透過 activeEngine 既有選取樣式交易修改線色／線寬／物件透明度，沒有選取才改畫筆與雷射預設。未碰其他顯示器作品。尚缺填色／填色透明度／漸層／線型／箭頭大小／延伸，亦未操作確認混合色、鎖定選取、Popover及取消／undo。


## M29 — 螢幕畫布缺少圖層與可調曲線工具入口

2026-10-13現況補註：M37最終工具清單及LayerPanelView已與一般畫布共用；本節是較早入口接線紀錄，不再表示工具另外硬編碼。圖層／曲線操作回歸仍待完成。

狀態：2026-10-12，入口已接入／Debug build 通過，未完成操作驗收。螢幕工具列增加既有 Core 曲線工具；更多選單新增 `LayerPanelView`，繫結目前顯示器的 engine。尚未操作確認圖層排序拖曳、Undo／取消、Popover 收回、工具方向、曲線控制點與其他螢幕／普通作品隔離；詳見 TB07／[日誌04](logs/2026-10-12/04.zh-TW.md)。

## M30 — 圖片貼上沒有接到系統剪貼簿

2026-10-12，同版修正。原 pasteClipboard 只解碼 BoardObject JSON，且舊 internalClipboard 優先；Mac adapter 雖有讀影像函式，畫布沒有呼叫。改系統 JSON／影像優先，PNG／TIFF／本機 URL 與網路影像回讀接到 importImage；非同步返回核對作品與頁，文字欄仍走原生貼上。專用 NSPasteboard 9/9 原生案例通過，含實際插入／Undo與像素尺寸；Core 同時檢查旧內部複製資料、空剪貼簿與切頁晚回。瀏覽器登入／受限來源與各瀏覽器實機 Cmd+V 仍待驗收。

## M31 — AB 控制與通用 transform 重疊／旋轉點被快捷列擋住

2026-10-12，同版修正。舊 AB SwiftUI handles 與 Core 矩形 transform 並存，螢幕畫布原生輸入未共享 AB。改 NativePointerSurface → 共用 Core endpoint 手勢，只繪 A、B；單一線／箭頭排除矩形 transform、旋轉屬性與旋轉修改，鎖定線也不出矩形控制。預覽只存在 StrokePreviewStore，放下提交一次歷史。快速列上方距離改42pt，不足則下移；Core 回歸涵蓋原生手勢路由、舊線段缺端點、Undo、避讓。最終隔離fixture的App圖面確認AB且無矩形框、線段屬性無旋轉、矩形旋轉點未被快捷列遮住；實際游標拖曳與顯示器縮放仍未完整驗收。

## M32 — 螢幕工具列估算常數與真實內容不同

2026-10-13現況補註：本節catalog／固定尺寸是日誌06批次；M37／ADR-M23已移除獨立AnnotationToolbarCatalog，正式Controller由ToolbarContentPolicy實際itemCount排布。32pt格／4pt間距與固定退出保留；日誌06局部操作不能替代日誌09最終共用版的全部驗收。

2026-10-12，同版修正。horizontal width−310 與直向688pt沒有核對新增17／16個格及固定按鈕；MenuDisclosureLabel 內含下拉亦超過32pt槽位，导致退出不可達。共享 AnnotationToolbarCatalog＋32pt格／4pt間距／固定212pt；橫排固定清空及退出，側邊依可用高度換欄，更多改單圖示。App 實際上方／左側退出可見可按；其他方向、窄／短螢幕與多顯示器仍待操作。先前1,713斷言只是重述預期常數，已替換為內容加總的回歸，撤回工作清單TB04–10「全數操作完成」。

## M33 — Mac 缺發行檢查及語言接線／翻譯語意錯位

2026-10-12，已實作，語言完整校對待做。新增 Mac 專用官方GitHub版本篩選與設定，十語本機詞庫／即時切換；實際英文設定切換及遠端Mac1.0.8比較通過，本地1.0.13保持。不提供背景自動安裝。UI 操作發現回報→手冊、主題→顏色等初始 alias 非等義，已改手工翻譯；側邊屬性長名稱改純圖示。部分動態字串與手冊仍正體中文，不能把385個固定字串檢查當作十語完整驗收。

## M34 — 隱藏的停靠工具在「更多」點擊沒有作用

2026-10-12，UI 核對發現。hiddenItems 的所有項目原本都呼叫 triggerTool，但 dock 是需要選方向的 Menu，switch default直接略過。更多中的 dock 改真正四方向選單，選定後才收回。一般工具列 topClearance 跟隨 header 可見狀態，12／64pt；核心位置檢查通過，最終App確認Top選單可用、header展開184px／收合80px，對應52pt上移；浮動／拖曳實機待驗收。其他隱藏 popover 型工具仍應繼續逐項檢查，不能只測 catalog 存在。

## M35 — 普通視窗放大入口不明確

狀態：新增入口已完成且首頁／畫布放大還原通過；原回報根因未確認。

- 症狀：使用者無法放大普通視窗，排除全螢幕。
- 調查：沒有禁止 resizable／固定 maxSize；系統綠鈕 secondary「縮放視窗」及「視窗 → 縮放」均可放大還原。上方空白雙擊無反應，未證明是系統雙擊偏好還是 hiddenTitleBar 命中區，不下根因結論。
- 處理：新增明確「放大／還原視窗」／⌘⌥0，直接 keyWindow.performZoom，不換 Space、不碰畫布倍率、不替換 SwiftUI delegate；排除透明 NSPanel／fullScreen。保留原系統入口及偏好。
- 證據：最新 Release 37.12 秒、深層嚴格簽章及十語 catalog 檢查成功；首頁／筆記本畫布放大還原原生確認，倍率保持100%。未驗收邊緣拖曳／多顯示器。詳見[日誌07](logs/2026-10-12/07.zh-TW.md)。

## M36 — 頂端雙擊未接通普通視窗縮放

狀態：已補雙擊，首頁／畫布放大還原原生驗收成功。

- 使用者澄清 M35 其實指頂端雙擊，上一輪只補選單／快捷鍵，沒有完成真正需求。
- 正式舊 App 頂端空白區雙擊可重現無反應；hiddenTitleBar 舊程式沒有補此事件。未確定系統偏好／SwiftUI內部因素的各自影響。
- 新增僅觀察自己普通視窗的 local event monitor，隨 view window 生命週期清理，不替換SwiftUI delegate。只截頂端雙擊並performZoom，回nil避免原生重複處理；其他內容、單擊、系統三鈕和resize邊緣保留。
- 螢幕NSPanel、fullScreen、有attachedSheet時跳過。不修改全域系統偏好；本App頂端雙擊依使用者要求固定zoom。
- 新Release33.98秒，首頁及畫布同位置雙擊放大還原，內容區雙擊保持尺寸，100%畫布倍率不變。詳見[日誌08](logs/2026-10-12/08.zh-TW.md)。


## M37 — 螢幕與一般畫布工具列逐漸分歧

狀態：共用實作及本機封裝完成；互動尚未實機驗收。

- 原因：螢幕模式硬編碼11種工具、獨立圖示／樣式面板／命令，普通畫布擴充後未同步。renderer 禁止全部命中，直接加入尺／圓規無法拖曳。
- 處理：共用 ToolbarToolsView、ToolbarBrushSettings、ToolbarPreferences；螢幕僅過濾導航／圖釘並覆寫必要平台行為。隱藏工具用實際元件開設定；刪掉第二套 trigger switch。尺／圓規／便條／套索／遮題／圖片／計算機／計時器／屬性均接相同工具元件。透明 host 恢復正常命中，父 host 不再重複安裝 pointer monitors。
- 佈局：依當前工具格數計算尺寸與換行；固定清空／退出保留。一般清單設定即時同步到螢幕，不回寫文件。
- 限制：沒有執行測試套件或功能操作驗收；四邊、長清單、原生文字輸入、尺／圓規互動與多螢幕應再由使用者實際確認。版本維持1.0.13，僅Mac。見[日誌09](logs/2026-10-12/09.zh-TW.md)。


## M38 — 編譯SDK快取佔用與公開Mac下載落後

狀態：快取已清理，來源與Mac 1.0.13公開預覽同步完成，5檔匿名下載可讀。

- .build約1.597GB，最大項SDKExplicitPrecompiledModules約1.14GB，其餘中間檔／快取／建置產品；不是使用者App安裝大小。沒有外部Package依賴或正在執行的編譯程序。
- 確認macos/dist/HeiBan.app的簽章、版本與既有SHA後清理精確專案.build，6899個再生檔案。沒有刪除App、來源、作品、參考或全域快取，下次編譯重新生成。
- GitHub Mac舊下載1.0.8，目前本機1.0.13；用獨立Mactag及公開預覽包更新，保留Windows下載與已有遠端歷史。
- 僅沿用既有成功二進位封裝，不在清理後重建／跑測試。發布完整下載不等於新工具列全功能驗收；未公證限制與待操作項目維持公開說明。

## M39 — 維護摘要與最終共用版狀態漂移

2026-10-13，狀態：文件已更正，最終功能回歸仍待完成。維護README仍引10/11並稱螢幕沒有圖層；M28／M32的較早狀態與檔案定位未顯示M37取代。已新增MAC_DEVELOPMENT_HANDOFF現況表、補歷史失效／證據邊界，更新README與Antigravity入口，保留舊症狀及SHA。

防止再犯：現在結論用來源commit／二進位SHA與實際批次定位；來源實作、核心檢查、局部UI與整體回歸分列。舊核心數字不可改寫成最新全部通過，文件整理不重編App或改版號。本批未重現App故障、未執行tests；連結／數據及Git同步另記日誌03。

## M40 — Windows1.0.15新增操作未同步至Mac

2026-10-16，來源移植進行中；完整操作未驗收。Mac原1.0.13缺磁鐵、圖文分頁與Common、板擦、真正外部PDF圖片頁及多頁匯出；圖形預設單次選取、快速列自動出現也與Windows最新需求不同。改由原生共同幾何／policy／文件adapter接線，版本依使用者新授權對齊1.0.15。Windows早期2334等檢查不沿用為Mac本批證據。

排解：首輪Mac文件adapter誤用fitToContent及緊接enum值的==.造成編譯錯誤，改既有fitNavigationView與運算子空白；第二輪Release56.58秒成功。第三輪發現ToolbarPreferences新增未知欄位不是Sendable，確認AnyCodableValue全為遞迴值型別後新增正式Sendable，不用unchecked迴避。板擦最初計畫用remove／insert複合命令，來源複核發現appendInZOrder會改legacy pageId=nil，已改明確replaceObjects交易。未執行故障重現／UI測試；最終編譯結果另記本日01。


## M41 — 關閉自動保存後仍可能顯示已儲存，返回首頁漏交文字草稿

2026-10-17，來源已修正並編譯；未作實機或故障注入驗收。scheduleAutosave原本在開關關閉／manual時提前返回，沒有更新status與generation；之前背景快照的完成回報可覆蓋新修改的狀態。改為先取消排程、推進generation並標記未儲存，再判斷排程；執行時也拒絕過時工作。串行queue仍保證寫入順序，不能宣稱取消已開始寫入。同步saveBeforeLeaving原本沒有commitInlineTextEntry，現在與非同步路徑一致，僅實際編輯中才提交；避免無草稿時重設工具。文字清空及樣式差異也列為草稿。

## M42 — 板擦預覽仍寫入永久物件，取消可能覆蓋其他操作

2026-10-17，修正M40／ADR-M25早期「暫態objects」的實際邊界：當時仍每個native event替換engine.objects，只在document讀原陣列。這會每次推進幾何revision並通知整個engine；取消則回寫原objects。改獨立BoardEraserState.previewObjects及小型render wrapper，放開才一次replaceObjects。新增來源revision／作品／頁核對，永久內容已有其他修改時丟棄預覽；Esc／失焦／拆除取消，不回寫永久資料。Undo／Redo／保存先結算。本批未量測流暢度，不能給改善倍率；精確斜角、長拖曳、局部切段、其他頁／鎖定保護與Undo仍待試用。

## M43 — 圖文分頁外工具缺設定錨點，內容未受中段尺寸約束

2026-10-17，來源已修正，實際窄視窗／長語言待驗收。visibleIDs包含全部分頁工具，用它判斷popover是否有錨點會漏掉其他分頁／下一組；More原本只渲染隱藏工具。改renderedIDs與overflowIDs互補，More用同一renderToolItem保留所有未渲染工具，沒有第二套命令處理。圖文中段給定實際長度並可捲動，固定選取／More不參與捲動，容量明列固定區與間距。初步懷疑舊容量漏計箭頭，複核後發現常數本身偏保守，未確認該推測，不記作確定根因。
