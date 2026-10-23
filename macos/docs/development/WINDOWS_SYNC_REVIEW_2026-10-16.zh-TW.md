# Windows 1.0.15 → Mac 1.0.15 同步開發對照

日期：2026-10-16；Mac目標1.0.15／20261016.1，Windows產品1.0.15／Store1.0.15.0。基準origin/main=73f17f5；從3f39f1d快轉21筆、132檔。使用者本次明確授權同版號同步，取代先前不進版的限制；不推定授權提交Store或公開Mac Release。

2026-10-17後續：產品仍1.0.15，build20261017.1補保存狀態、真正獨立板擦預覽及分頁設定入口；見[日誌](logs/2026-10-17/01.zh-TW.md)。下列為10/16同步基準與尚待實機清單。

## 來源與界線

- [Windows1.0.15說明](../../../windows/docs/STORE_RELEASE_NOTES_1.0.15.zh-TW.md)、[繪圖流程](../../../windows/docs/DRAWING_WORKFLOW_2026-10-15.zh-TW.md)、[八項修整](../../../windows/docs/CANVAS_UI_REFINEMENT_2026-10-15.zh-TW.md)、[板擦入口與鏡像](../../../windows/docs/BOARD_ERASER_ENTRY_MIRROR_2026-10-15.zh-TW.md)。
- Store來源紀錄是使用者已提交預處理，非本機查證認證已完成；Mac不使用Windows Store updater／COM／WinUI／runtime。
- Mac自有SwiftUI/AppKit、PDFKit／CoreGraphics、原生輸入與生命週期；資源放macos、無執行時Windows目錄依賴。

## 功能與操作對照

「已接線」表示本批來源已實作，不能直接當作實際操作通過。編譯／簽章及最終成品證據另見[當日日誌](logs/2026-10-16/01.zh-TW.md)。

| Windows更新 | Mac同步內容／原生實作 | 限制／待操作 |
| --- | --- | --- |
| 同版本正式metadata | Release.json與About同步1.0.15，build20261016.1 | 公開Mac下載仍先前1.0.13，未自動發布新Release |
| 共用工具catalog與屏幕篩選 | 延續1.0.13共用ToolbarToolsView，磁鐵與分頁同一policy，螢幕排圖釘／視角鎖定及固定清空 | 不移植Windows仍缺的教學工具host；Mac既有尺／圓規／計算機保留 |
| 圖文四分頁／常駐選取 | icons或labels，常用／繪圖／插入／管理；單排／列＋換組箭頭，選取不可隱藏 | 圖示模式保留Mac原可捲動列；四邊／短屏與長譯文待實機 |
| 自訂全選／預設／常用 | 全選、恢復預設、獨立Common勾選、排序及更多；原偏好解碼預設與未知欄位保留 | 首次舊偏好發現磁鐵時補一次，明確隱藏不重置 |
| 磁鐵起點與hover | 空間格索引按物件revision／頁／zoom重建，約10螢幕點，最多查九格；獨立暫態提示 | 頂點／中點／矩形中心／線段端中點／圓弧中心四向與弧端點，鎖定可參照，隱藏排除；大型作品待量測 |
| 連續與中心式建構 | 新完成圖形保留工具；圓／菱形／五角／星形中心拖曳、矩形角拖曳 | 既有圖形資料不遷移；三點三角、四點四邊直線預覽沿用Mac |
| 單擊把手／雙擊詳細 | selection只顯示把手；雙擊開Inspector／quick bar，文字維持原地編輯 | 原Inspector若使用者固定開啟不強制在每次單擊收起；繪圖開始收起 |
| 停筆近直線 | 新增同幾何／screen tolerance的StraightStrokeRecognizer，兩畫布共用Core | Mac原閉合形狀識別保留，不把弧線誤拉直；真實筆壓待驗收 |
| 原創磁吸板擦 | 一般畫布使用同一原創PNG的Mac副本；原生鏡像、12點alpha凸輪廓共同抓取／擦除 | 長1599×984素材不生成新圖；螢幕維持圓形橡皮 |
| 板擦交易／顯隱／右鍵 | 原生拖曳，每事件發一份暫態objects，放開一筆replaceObjects、Esc取消；更多顯示與右鍵隱藏 | 保護圖片／文字／便簽／鎖定／其他頁；局部只切向量筆跡；未提交草稿不入autosave |
| PDF範圍圖片頁匯入 | 原生PDFKit頁碼／密碼入口，最多200頁／100MB，長邊3072px，另建notebook／鎖定image | 來源PDF上限250MB；取消／轉換失敗不安裝半成品；不是外部元素編輯 |
| PPT／PPTX匯入 | Mac以Keynote自動化轉唯一暫存副本PDF，再走相同頁面管線；另支援.key | Windows桌面PowerPoint COM不能搬至Mac。需Keynote及系統Automation；不執行VBA，不關既有簡報。字型／損壞／加密／外連／影片待實測，可先手動PDF |
| 多頁PDF／可編輯原稿 | ImageRenderer共用畫布renderer，選目前／全部頁；Core有效incremental PDF stream保存原稿，Windows同marker可讀 | PDF包含全部原稿／其他頁／隱藏物件；UI提示分享可見內容應PNG。無向量重建外部文件保證 |
| 圖釘一致色／新增優先 | 修正原創圖示固定色：canvas與清單使用effectiveColor；現有新增在搜尋前保留 | 保留圖釘名稱、位置、舊坐標及未知欄位 |
| 紙白綠UI | 普通／螢幕面板強制淺色與綠色accent；不改作品底色 | OS選檔、密碼等系統原生元件由macOS控制 |
| 新設定自動存檔off／退出提示 | 新偏好off，舊manual與明確選擇照原遷移；一般退出已有terminateLater等待，新增native保存spinner | 退出成功才結束，失敗保留；本批未做慢寫入／故障注入 |
| 十語及離線說明 | UI新字串補十語；Mac手冊獨立來源與生成，App依語言開啟，頁內切語／搜尋／ar RTL | 正體中文完整21章圖解，其餘13主題總覽，並非Windows25章逐字移植；母語／全動態提示未全面校閱 |
| Windows體積／Store提交 | 只讀既有資料，不移植Windows runtime、Updater或Store權限 | 不進行WR減重實驗；Mac仍無Developer ID／公證 |

## 原生架構取捨

1. DrawingAssistState隔離高頻磁鐵目標；BoardEngine僅持gesture index及revision快取，不每次mousemove掃整份文件。
2. DrawingReferenceGeometry共用參考點／板擦幾何及多邊形渲染，避免磁鐵命中的是另一份形狀。
3. BoardEraserOriginal只為單手勢快照；保存document讀原快照至放開，replaceObjects還原精確pageId與未知欄位，不借insert命令重掛舊頁。
4. MacDocumentExchange為平台adapter。只成功後才交既有save-before-leaving／document codec；恢復PDF原稿也建立新作品ID，防止覆蓋庫內同ID作品；PDF與圖像資料在本機處理，簡報轉換只操作自己的暫存副本。
5. Core文件schema保持.heiban v1 UTF-8 JSON；PDF延續Mac/Windows標記但改善容器為有效incremental stream；不把原稿資料默默刪掉來縮小分享檔。

## 後續實際試用順序（本批未執行）

- [ ] 先使用隔離作品開新版本，確認版本／build，再測普通畫布四邊icons／labels、長語言與常用持久化。
- [ ] 磁鐵第一點／終點與所有形狀參考點，中心建構、連續三角／矩形，雙擊細節、AB／旋轉／Undo。
- [ ] 板擦斜角／透明角／物件與局部／取消／Undo／頁切換／變倍率／保護圖片與文字，不用重要作品作實驗。
- [ ] 小PDF兩頁匯入、頁碼／密碼／取消，Keynote／PPTX實際字型轉換，PDF多頁與跨平台原稿恢復；人工檢視頁序／圖像／箭頭／文字方向。
- [ ] 螢幕模式四邊兩種列／固定退出、穿透、文字、尺／圓規／浮動工具／多顯示器。
- [ ] 自動保存新舊設定、正常退出／失敗回復、十語UI與手冊、Finder入口／更新檢查。
