# Mac目前開發進度、排錯與交接總表

更新：2026-10-13。版本維持1.0.13 / 20261011.1。本次為文件整理與Git同步，沒有新增產品功能或重新編譯。

## 1. 接手時先核對哪一份成果

| 項目 | 目前基準 |
| --- | --- |
| Mac程式來源 | 公開來源commit3da9310aec26771456c14a425dad3b6bc50755fa，固定tag macos-v1.0.13；後續main文件提交不移動tag |
| 公開下載 | [Mac1.0.13公開預覽](https://github.com/VirginBear/HeiBan/releases/tag/macos-v1.0.13) |
| 本機最新App | macos/dist/HeiBan.app；Apple Silicon／macOS14以上 |
| 主執行檔SHA-256 | 94b441f4f451bd04e0842f3ba53d35bff7ff90cc4d3d96e56fa0a3190fb2b193 |
| 最近功能封裝 | 10/12日誌09：Release32.93秒、嚴格深層簽章成功；不是全功能操作驗收 |
| 發行包 | ZIP4,148,023bytes／DMG4,717,776bytes；完整SHA見[發行量測](RELEASE_ARTIFACTS_2026-10-13.json) |
| 發行檢查 | 5個遠端assets大小／SHA符合、匿名HEAD皆200；見[遠端核對](RELEASE_REMOTE_AUDIT_2026-10-13.json) |
| 已清理內容 | macos/.build6,899個再生檔，1,596,936,192bytes；[清理明細](CACHE_CLEANUP_2026-10-13.json) |
| 發行限制 | 公開預覽、尚無Developer ID／Apple公證；版本不提高，Windows／Web成品分開 |

不同批次曾在同版號下重建，不能只比較1.0.13字樣判斷是不是同一份。以build、二進位SHA、來源commit和日誌定位；日誌06／08的歷史二進位SHA不代表最終日誌09成品。本批不建立舊App備份或重建快取。

## 2. 最新功能／操作進度表

「已實作」只表示來源有接線；「局部驗證」依各日誌的具體案例；最後共用工具批次尚未完成完整回歸。

| 功能／需求 | 目前實作與解法 | 證據／仍需確認 |
| --- | --- | --- |
| 首頁與品牌 | 原創黑板Logo、精簡新增入口、作品縮圖／種類、可收側欄、螢幕畫布入口 | 既有首頁手冊及M26；縮圖／批次刪除與長列表仍列使用者操作回歸 |
| 一般工具列 | 常用預設／完整catalog／更多／排序隱藏／四邊；偏好正規化保留隱藏選擇 | M23、M34；舊全顯示偏好不擅重置；更多中的每個設定入口需逐項回歸 |
| 右上導覽自動隱藏 | tracking area不擋畫布，700ms延後收起，選單／固定狀態保留 | M26；主工具列依header展開上下避讓，M34局部圖面確認上移52pt |
| 普通／螢幕工具一致 | 共用ToolbarToolsView、ToolbarBrushSettings、ToolbarPreferences；螢幕省導航／圖釘，尾端固定清空退出 | M37、ADR-M23、日誌09；長清單／四邊／短螢幕完整操作待驗收 |
| 筆刷與顏色 | 共用色圈、原生ColorPicker、Hex、最近8色、筆刷類型、實際尺寸預覽、粗細／透明度 | 最終共用面板已實作；不能宣稱自製圓形色輪已完成；縮放下預覽尺寸待實測 |
| 圖形屬性 | 有選取才提供有效線型、填色alpha／漸層、箭頭尺寸／延伸；鎖定與批次交易共用 | M28後續由M37取代舊獨立樣式面板；混合型別／多選／Undo／取消仍待最終操作 |
| 直線／箭頭AB | 單一物件透過Core端點路由，只呈A、B，不提供旋轉屬性 | M31；日誌06fixture視覺確認，真正拖曳與多選流程尚未完整驗收 |
| 圖形控制點／旋轉 | 一般transform；多邊形頂點共用；快速列預留42pt旋轉區，空間不足下移 | M31局部圖面確認；各角度、縮放、多螢幕、四邊面板待驗收 |
| 尺／圓規 | 共用可互動疊層；尺刻度／自適應色及角度設定；圓規先準備、點圓心啟用、再畫弧 | M01／M04及M37；螢幕新命中結構下拖動／啟用階段必須重新驗收 |
| 雷射／橡皮擦 | 按鍵設定、尺寸與暫態尾跡；橡皮擦物件／像素及hover範圍，圖片／文字／便條豁免 | M03及共用工具日誌09；停用／再啟用、兩種橡皮、透明底層及性能待實機 |
| 圖層管理 | 共用LayerPanel；原生拖曳預覽、來源淡化、目標插入線，放下單次交易 | M26／M29；螢幕綁當前engine；取消／拖出／長列捲動及跨session隔離待驗收 |
| 圖片截圖／網頁貼上 | 系統剪貼簿優先，PNG／TIFF／本機URL／網路影像回讀，非同步核作品／頁 | M30；原生NSPasteboard9案例為日誌06證據，瀏覽器受限圖片仍待實測 |
| 文字／便條／右鍵 | 原地NSTextView草稿，完成才提交；文字／便條右鍵批次字號／顏色，其他物件既有選單 | M17／M18；M18使用者確認按完成可顯示；中文組字與最終共用renderer待回歸 |
| 文字滾輪 | 原生文字編輯器優先處理，避免編輯時畫布誤縮放 | 歷史文字輸入修正；巢狀面板與外部鼠標滾輪待使用者實際確認 |
| 畫布格式與文件 | 無邊界、有邊界、筆記本；背景／尺寸可改；可編輯.heiban v1 UTF-8 JSON | ADR-M02；內嵌圖片與未知欄位保留，不能直接改ZIP或丟舊欄位 |
| 圖釘與相容 | 統一原創斜向圖示、名稱／位置；舊坐標與Windows未知欄位相容 | M19／M21；螢幕模式不提供圖釘，普通作品保留；原始資料回歸依原日誌 |
| 屬性面板／浮動教學工具 | 四邊Inspector、calculator／timer等沿用相同元件，暫態位置有邊界 | M01／M37；上下寬型分組與窄屏／popover／再呼喚待操作，不以可編譯當不跳位證據 |
| 螢幕疊層／穿透 | 多顯示器NSPanel、1%透明底層、單一PointerView、原生文字host、dialog遮讓 | M12、M37；常見App、多Spaces及全螢幕待完整回歸，系統安全畫面不保證覆蓋 |
| 螢幕清空／截圖／退出 | 固定操作可達，清空不退出、保留工具／模式／Undo；截圖PNG；先保存後停止 | M14／M32；日誌06只驗上方／左側退出，日誌09更動後全部方向要重新確認 |
| 自動保存／正常退出 | 開關與頻率接入一般作品／螢幕排程；手動／離開保存獨立；terminateLater等待背景成功 | M27；慢寫入／失敗再試／多顯示器／文字草稿／偏好遷移待驗收；截圖中退出須稍後重試 |
| 普通視窗放大 | 選單／快捷鍵與頂端雙擊直接performZoom，保留還原，不改畫布倍率 | M35／M36、日誌07／08局部原生驗收；其他macOS與多螢幕待確認 |
| 更新與多語 | 只查官方Mac Release／相容CPU，不自動降版／安裝；10語詞庫及即時切換 | M33；英文切換曾局部操作；動態字串／手冊／RTL／母語完整性未達全部完成 |
| Google／雲端／多文件／結構筆記 | 有原型／模型基礎；正式GoogleOAuth、雲端協作、多文件owner與導圖等未全接線 | ADR-M06、CURRENT_STATUS既有清單；不能列為已交付登入或完整跨平台功能 |

[使用手冊](../USER_GUIDE.zh-TW.html)講操作；[架構](ARCHITECTURE.zh-TW.md)講狀態與邊界；[問題紀錄](ISSUE_HISTORY.zh-TW.md)保留症狀與排解，三者用途不同。

## 3. 最近排錯因果與失敗方案

| 問題 | 可確認原因／處理 | 曾經不足的方案與注意 |
| --- | --- | --- |
| 螢幕工具缺／尺圓規不可互動 | 11工具硬編碼與獨立switch、renderer全部禁止命中；改共用元件及疊層／一份pointer monitor | 只加入工具圖示不足；父子monitor重複會使事件所有權不清；原生dialog service需強持有 |
| 工具列退出被裁切 | 預估固定尺寸與真實格數／下拉內容不符；改32pt格／4pt間距、動態格數、固定清空退出 | 1,713核心斷言只重述幾何常數，不代表SwiftUI真實可達；最終日誌09取消獨立catalog |
| 顏色設定找不到／改不到已選物件 | 原只改未來預設；改engine-aware選取命令與共用面板 | 混合值／鎖定／文字／圖片不可用同一欄位套用，不能污染別的session |
| 圖片貼不上 | 畫布只解BoardObject JSON／舊內部剪貼簿先用；接系統影像adapter | 網路回讀需核文件／頁，NSTextView貼上優先；不能改文字編輯器的標準Paste |
| AB仍有矩形／旋轉遮擋 | SwiftUI handles與通用transform並存；改Core端點，快捷列避讓 | 單一線和多選共用框不同；未以靜態圖面確認冒充拖曳驗收 |
| 雙擊無法放大 | hiddenTitleBar未接指定操作；只攔本App普通window頂端雙擊 | M35選單入口未滿足雙擊要求；不修改全域系統偏好／不替換SwiftUI delegate |
| 自動存檔設定無效果 | UI寫偏好，timer固定；排程改讀開關／頻率，退出等待背景結果 | 自動存檔off不等於停止手動／退出保存；generation不等於取消磁碟寫入 |
| 發布大小／快取混淆 | .build SDK模組與中間檔非App；確認成品後清精確再生路徑 | 不把作品／全域快取／公開歷史當冗餘；封裝已有App不重建 |
| 文檔漂移 | 維護README停在10/11，M28／M32狀態未指最終共用版；加當前表及歷史失效說明 | 不刪舊失敗／SHA，不能在舊紀錄上改寫當時未發布狀態來掩蓋歷史 |

所有技術原因依既有來源／日誌，未知的系統因素保留未知。本批沒有重新重現上述App缺陷。

## 4. 驗證證據不可跨批套用

- 10/11（7198f11）：1,642核心斷言＋Release probe7/7為當時獨立複核，M23／M25已修；M24完整草稿生命週期仍待確認。
- 10/12日誌06：1,752核心斷言、NSPasteboard9案例；AB／旋轉避讓／英文切換／header移位／上左退出是局部操作，並非所有工具拖曳。
- 10/12日誌08：頂端雙擊首頁／畫布放大還原，畫布100%保持；沒有重跑核心檢查。
- 10/12日誌09：共用工具與命中結構Release成功／簽章成功／正常啟動；**沒有執行測試套件或功能操作**，上批數字不能當本批全面通過。
- 10/13日誌01：既有成品重新封裝與公開檔案完整性，不是新編譯或功能回歸。
- 本次：文件／連結／Git同步核對；沒有重建、App、核心／UI tests、效能量測或Apple公證。

## 5. 下一步工作與驗收清單

先以現有1.0.13完成回歸及資料安全，不因文檔更新進版。

- [ ] **MAC-H01（P0）保存與退出**：on／off／各頻率、舊manual遷移、手動／離開、中文字草稿、慢寫入／失敗再試、恢復檔／多顯示器。確認失敗保留視窗、作品可重開。
- [ ] **MAC-H02（P0）螢幕控制可達**：四邊／收合／短屏／負坐標／混合縮放，清空及退出始終可按，穿透可恢復；不測在安全畫面強行覆蓋。
- [ ] **MAC-H03（P1）共用工具回歸**：可見／更多／自訂／排序隱藏、首頁與螢幕來回同步；尺／圓規準備與啟用、計算機／計時器呼喚、雷射尾跡、兩種橡皮hover。
- [ ] **MAC-H04（P1）選取與樣式**：單線AB／多邊形點位／矩形旋轉、混合值／鎖定、多選一次Undo、填色alpha／漸層／箭頭尺寸、四邊面板不裁切。
- [ ] **MAC-H05（P1）原生輸入**：各瀏覽器／系統截圖貼上、拖圖、編輯文字不誤縮放、中文組字／右鍵格式、圖層拖曳跟隨預覽／取消。
- [ ] **MAC-H06（P1）大型作品量測**：input→preview、序列化／縮圖／磁碟與匯出，固定同資料與環境，先量測再拆publisher或改渲染。包體大小不代表流暢度。
- [ ] **MAC-H07（P2）語言／版本／手冊**：動態字串、十語長字串與RTL、系統色盤／選檔、手冊翻譯；更新錯誤／離線／CPU／Mac平台篩選。
- [ ] **MAC-H08（P2）後續產品能力**：登入OAuth／雲端／多文件／.heiban v2各立方案，不在一般清理中移除原型或偷偷改文件契約。

操作驗收僅在使用者當次要求下執行，使用隔離fixture，不用使用者作品作測試。每批填來源／SHA、環境、步驟、觀察、失敗及未測項；需要修復再以新日誌追加。

## 6. 程式定位與維護不變條件

- 共同工具：HeiBanCore/Models/ToolbarPreferences.swift、ToolbarContentPolicy.swift；HeiBanMac/Views/ToolbarView.swift、ToolbarBrushSettings.swift、ToolbarCustomizeSheet.swift。
- 螢幕：HeiBanMac/ScreenAnnotation下的ScreenAnnotationControls.swift／ScreenAnnotationController.swift／ScreenAnnotationSession.swift／ScreenAnnotationCanvas.swift／AnnotationInputView.swift。舊AnnotationBrushSettings.swift已移出，不再作新功能入口。
- 原生輸入：HeiBanMac/Views/NativePointerSurface.swift內的PointerView類別；透明文字host不另擁有第二份PointerView。
- 保存：HeiBanCore/Engine/BoardEngine+Persistence.swift、BoardPersistenceState.swift；HeiBanMac/HeiBanApp.swift與ScreenAnnotationController的退出等待。
- 圖層／端點：HeiBanCore/Engine/BoardEngine+Layers.swift、BoardEngine.swift、StrokePreviewStore.swift；HeiBanMac/Views/LayerPanelView.swift。
- 平台介接與更新：HeiBanMac/Adapters、Updating/MacUpdateService.swift、Localization/L10n.swift。
- 手冊唯一來源macos/scripts/generate_user_guide.py；版號來源macos/Release.json。沒有UI／版本變更不為文檔整理重生手冊或App。

所有路徑以macos/Sources為根。永久物件世界座標與螢幕指標坐標保持界線；高頻預覽不進保存／Undo，提交才一次交易；每顯示器owner獨立；偏好不寫.heiban。完整取捨依ADR-M19–24，ADR-M08等早期結構不得當現行實作。

## 7. 本批文件同步範圍

補齊此交接總表、維護README、CURRENT_STATUS、ISSUE／DECISIONS歷史失效說明、Antigravity當前表及日誌；既有體積量測一同同步。Windows減重計劃與數據放windows/docs，來源與產品不混平台。提交／push結果記在[日誌03](logs/2026-10-13/03.zh-TW.md)，遠端確認後才稱已同步；不新增發行tag、不改macos-v1.0.13。
