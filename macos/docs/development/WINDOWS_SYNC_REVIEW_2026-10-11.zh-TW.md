# 兩庫完整性與 Windows → Mac 改善審視

日期：2026-10-11。範圍：檔案、Git、來源與既有開發證據審視；本批沒有修改功能、編譯、啟動 App 或執行測試。

## 1. 結論與同步基準

**Git 管理的原始碼與開發紀錄完整，兩庫 main 都與各自遠端一致。** 不代表原 Windows 電腦的 SDK、試用 ZIP、Store bundle 或使用者作品已移到 Mac。

| 核對項目 | 本次證據 |
|---|---|
| 公開 HeiBan | HEAD／origin/main／遠端 main `99c08c5021d2e76029cea18f9b3bf039b7193170`，ahead／behind 0／0；開工工作樹乾淨 |
| 私人 HeiBan-private | 獨立相鄰 checkout，HEAD／origin/main／遠端 main 一致、ahead／behind 0／0、工作樹乾淨；API visibility PRIVATE |
| 追蹤檔案 | 公開 638／私人 12，缺漏 0；公開 Mac 204／Windows 294／共用 docs 71（不是全部檔案的總和） |
| Git 物件完整性 | 兩庫 `git fsck --full --no-reflogs` 退出 0；主庫兩個 dangling blob 是未引用物件，沒有缺失／損壞證據，未刪除 |
| 相依 Git 內容 | 無 submodule／LFS pointer；未使用 sparse checkout，沒有因 LFS 工具缺席漏取內容 |
| JSON | 公開 113／私人 2 份追蹤 JSON 皆可解析；不以可解析代替語意／UI 驗收 |
| Windows 最新來源清單 | 多語 trial 的 124 項來源全存在：28 項原 byte SHA 相同、96 項只因 LF／CRLF 不同；換行還原後 124／124 符合清單 |
| 合併後 Windows 來源 | `git diff 14bb289..HEAD -- windows` 只有七份後續紀錄；未發現 Windows 程式碼被本地 Mac 合併倒退 |
| 十語资源 | 每份 581 鍵，10 份鍵集合與來源一致、空值 0；沒有驗證翻譯品質／格式呈現 |
| 私人商店素材 | 三張素材檔的大小與 SHA256 3／3 相符；不把素材內容複製到公開審視文件 |
| 未解衝突 | 正式 Swift／C#／XAML 無衝突標記；第三方 NOTICE 的分隔線不是合併衝突 |
| 本地 Mac App | plist 1.0.12 / 20261010.4，與 Release.json 一致；strict／deep codesign 驗證成功，未啟動操作 |

換行差異是跨 OS checkout 的差異，**不是 bit-for-bit 的 Windows build snapshot**。若要重建原包，仍須依來源清單與 Windows 封裝環境核對，不能用 Mac 上的 LF 檔案宣稱原 byte 完全一致。

### 不在 Git 同步範圍內的內容

- 最新 Windows x64 multilingual trial ZIP 與 Store MSIX bundle 在這台 Mac 未找到；最新 source／產物 manifest／封裝腳本已在庫內。這是原設計的 ignored 本機產物，不是 clone 漏檔。
- 此機 windows/dist/public 有歷史 1.0.12-preview.5 安裝／免安裝 ZIP；不能用它們代替 preview.6 新試用。
- 原 Windows Data、trial-data-backups、SDK、原始建置 logs 沒有透過 Git 攜帶；要移作品需另外保全及傳送，不在本輪讀取／複製作品。
- 私人庫是管理與素材交接，不是 App runtime 相依，仍保持與公開庫分開。

## 2. Windows 進度：來源、實測與發行分開

| 範圍 | 最新已記錄內容 | 尚不能認定完成 |
|---|---|---|
| 原生版本／核心工具 | C#／.NET 10／WinUI 3／Win2D；一般與透明螢幕畫布、文字、圖層、尺規、圓規、雷射、截圖等來源與前批證據 | 全工具在所有硬體／DPI／多螢幕的操作一致性 |
| 第一批效能 | 穩定 Z 順序快取、熱路徑配置減少、螢幕 damage region 的精確像素複製；有原機 Core／native 證據 | 端到端延遲、真筆、device lost、完整硬體矩陣 |
| 第二批效能 | 渲染候選網格、幾何增量更新及安全 fallback；歷史最終 2324 Core／127 幅零容差像素檢查紀錄 | hit／擦除／框選未接 index；GPU 分區快取未實作；密集場景仍慢 |
| 第二批量測界線 | 稀疏 10000 物件候選 CPU p95 0.36124→0.07980ms，是原 Windows 電腦、同 binary 的合成資料 | 完整 scene pan／zoom 有較差跑次，不能宣稱全 App FPS 達標，更不能套用成 Mac 分數 |
| 操作20項＋後續補強 | 內容量測／換行工具列、類型屬性、圖層拖曳預覽／插入線、方向游標、圖釘配色、箭頭頭部、視角鎖定、螢幕橡皮擦／圖層／色輪 | 最新多數批次只編譯／封裝／靜態檢視，未完整實機驗收 |
| 新建／背景 | 無邊界不顯示尺寸；fixed 首次16:9；模式選項記憶；五種背景共用新建／既有入口 | 最新主畫布游標修正及選項生命週期仍待實機確認 |
| 多語 | 10語／581項，首頁切語言、偏好原子保存、展示 RTL／畫布 LTR，最新本機 x64 多語 ZIP | 最新 ARM64 多語包未建，長字串／RTL／原生色盤／母語校閱未完成 |
| Store | 1.0.12.0 首次送審快照與身分／manifest／套件 hash／素材紀錄已備；最後已知「認證中」來自使用者2026-10-10提供 | 本次未登入 Partner Center，不能確認已通過／上架；最新 source 不等於已送審 binary |
| 公開下載 | API 實查 Windows Release 為 1.0.12-preview.5；Mac 為1.0.8 | preview.6 多語等本機新試用尚無公開 Release；不得把 source push 稱為發行 |

歷史 `STORE_ARTIFACTS` 的 storeSubmitted=false 是封裝當時快照；後續送審紀錄已說明使用者上傳，不直接改寫舊 evidence。商店下一包須保留原 snapshot 並另產新版，不能拿目前來源十語 manifest 宣稱原1.0.12.0已含十語。

## 3. Mac 可改善的內容與工作清單

保持 Swift／SwiftUI／AppKit 與 Mac 原生輸入；借鑑行為、資料契約、快取失效規則及驗收方法，不共用 WinUI／C# runtime。跨平台資料保全先於視覺改善。

### 第一批：相容性與版本可信度（P0）

- [ ] **MAC-SYNC-01 圖釘資料往返保全**：BoardPin已擴展color／textColor／boardId／extraFields，新配色與Undo已接上。M21缺失／null座標標記回歸已在f960c78排解；獨立runner1559／Release probe4/4通過，詳見[日誌05](logs/2026-10-11/05.zh-TW.md)。保留未勾選是因實際Windows→Mac→Windows開檔與三处UI操作仍待驗收，不再表示M21待修。
  - 驗收目標：Windows 建 pin／自訂色 → Mac 載入／修改無關物件／另存 → Windows 再開，ID、名稱、座標、兩色及未知欄位都保留；舊無色 pin 使用一致預設；取消不改、一筆配色一次 undo。
- [x] **MAC-SYNC-02 版本、變更紀錄與回報入口統一**：Release.json 是1.0.12，但 Core AboutInfo 固定1.0.5／20261009.4，SettingsView about 顯示它；feedbackUrl 指向舊 heiban/heiban。系統 App plist 正確不代表設定面板正確。最新99c08c5把測試固定成1.0.5，仍未對齊實際Release。（2026-10-11 已完成：AboutInfo 對齊 1.0.12 / 20261010.4、feedbackUrl 指向 VirginBear/HeiBan/issues、補齊 1.0.12 變更紀錄；測試套件已對齊真版本並於 [測試 26] 與 [測試 46] 雙重驗證通過）。
  - 驗收目標：App／設定／手冊／產物使用同版號與 build，最新變更紀錄相符；問題入口為VirginBear/HeiBan/issues；測試 fixture 與 App 版本來源分清，不以改成過期常數取得通過。

### 第二批：畫布操作與工具列（P1）

使用者本次要求優先追齊工具列，具體細節、主列與螢幕列差異改依 [10項Antigravity工具列工作清單](../ANTIGRAVITY_MAC_TOOLBAR_WORKLIST_2026-10-11.zh-TW.md)。以下保留原工作ID；03／04／06由新清單細化，05為圖層排序依賴，不重複當兩份完成數。

- [ ] **MAC-SYNC-03 螢幕工具列內容量測與換行**：目前 preferred 820×60／64×688，加 ScrollView；Windows 已依工作區量測並換行／換列。改 Mac 原生工作區約束及 SwiftUI 內容量測，拖動只移 NSPanel，放開才重排。正常尺寸維持上下橫排、左右純圖示窄排，不能因新增工具撐成寬側欄。
  - 驗收目標：四邊／短螢幕／不同縮放／跨顯示器完整可達，色圓、作畫模式、清空、結束一直可見；無抖動／面板裁切；空間不足才換行，仍保留鍵盤可達性。
- [ ] **MAC-SYNC-04 螢幕色輪／图層／類型設定**：現有 AnnotationBrushSettings 六色，無自訂色輪；螢幕控制列沒有 LayerPanel 入口。共用普通畫布的色彩與圖層命令，展示要依目前螢幕 engine，不能切回主作品。
  - 驗收目標：右鍵文字設定保留，色輪／透明度／筆粗都更新目前顯示器；圖層可選取／改名／鎖定／隱藏／排序；穿透狀態及作品資料互不污染。
- [ ] **MAC-SYNC-05 圖層拖曳排序與回饋**：2026-10-11 本機1.0.13已實作 LayerPanelView 原生握把拖曳、图示／名稱跟隨、原列淡化与插入線；放開才提交一次排序，取消回收 UI。編譯封裝與實機驗收分開，勾選保留待實機；詳見日誌10。
  - 驗收目標：取消／失焦／換頁／換文件不殘留，混合鎖定／隱藏／同Z排序正確，一次拖曳一次 undo；不為每個 pointer 發布永久 objects。
- [ ] **MAC-SYNC-06 屬性依類型收斂**：已有四邊停靠及部分箭頭／延伸條件，但選取後仍共用 colors／line／object 三欄。按文字／圖片／筆畫／幾何及混合選取展示可用欄位；文字格式繼續集中右鍵。
  - 驗收目標：文字不出現無意義填色／線型，圖片不展示筆刷項，鎖定物件唯讀；橫向面板不遮大片視野，不改掉未選擇欄位。
- [ ] **MAC-SYNC-07 新建設定與尺長**：Mac 已有無邊界隱藏尺寸、五種背景，這些不需要重做；補 fixed 首次16:9、各格式自己的尺寸／背景選擇記憶、尺長依可視畫布寬度20–150%（Windows預設90%）及合法範圍。
  - 驗收目標：取消不污染作品／偏好，已有背景可調整，一次套用一次 undo；尺角度0.1°、拖動／自適應刻度配色與持續尺邊約束保留。
- [ ] **MAC-SYNC-08 箭頭／便簽視覺與命中一致性**：Mac 已有箭頭頭長寬及類型條件，頭部是填滿 Path；Windows 最新規則是頭部輪廓隨線寬、頭長寬獨立。先明訂跨平台視覺及 hit bounds，再補紙張裝飾，不能直接套某平台繪圖 API。
  - 驗收目標：頭長／寬不隨筆粗變動，native／PNG／PDF／SVG與選取範圍相符；便簽新增裝飾不切文字、不改可編輯內容與橡皮擦豁免。

### 第三批：量測後改善效能（P1）

- [ ] **MAC-SYNC-09 Mac 基準與快取邊界**：普通／透明畫布各量 input→preview、提交、pan／zoom、場景重建、圖片／富文字和 idle。採0／300／1000／10000、稀疏／密集與前後原始資料，記硬體／縮放，不移用Windows成績。
- [ ] **MAC-SYNC-10 候選索引與提交層**：Mac CanvasObjectsView 每幀遍歷 currentPageObjects，notebook 先 filter，LayerPanel每次排序；BoardPathCache已有128MB／8192項，不是完全無快取。先定位熱點，再選頁面／稳定Z／保守bounds候選、富文本／圖片layout與背景／永久層／暫態層的失效策略。GPU bitmap／Metal是否值得採用，留到基準後決定。
  - 驗收目標：保留同Z、visibility、page、Undo／Redo、取消／live變換與未知型別；有複雜型別／密集 fallback、記憶體預算與清理生命週期；輸出前後比對，收益不穩定則保留舊路徑。

### 第四批：多語與發行（P2）

- [ ] **MAC-SYNC-11 十語入口與資源**：Mac 尚無同等集中語言 catalog／入口。採 Mac 自己的字串資源、顯式正體中文預設與語言偏好，沿用Windows詞意及鍵清單作覆蓋依據，不能直接依賴Windows NLS生成器或Settings/language.json。
  - 驗收目標：10語首頁／工具／Inspector／螢幕列／提示覆蓋，長文自適應；阿拉伯語閱讀RTL、画布座標LTR；作品名稱／文字／文件碼／快捷鍵不重譯；翻譯母語校閱與原生面板語言界線明列。
- [ ] **MAC-SYNC-12 發行來源與產物證據**：借鑑 Windows snapshot／source SHA／獨立trial標籤／資料保全，但Mac保留「只留最新 App」政策。將 source commit、Release、guide、架構、簽章／公證與公開asset狀態分開記；開發版1.0.12不冒稱已在1.0.8公開下載。

目前MAC-SYNC-01／02來源與核心檢查通過，M21已修復；01跨平台與介面實機驗收仍待完成。MAC-SYNC-03–12尚未完成；依使用者本次回饋，下一批優先工具列細節追齊，語言覆蓋與效能工作另按原依賴安排。

## 4. 已有功能與相容性界線

Mac 已有四邊屬性、普通作品庫一般／批次選取、五種背景、鼠標中心縮放、中鍵平移、原生T／右鍵文字、尺角度、自適應配色、圓規兩階段、雷射再次點設定、螢幕橡皮擦预覽與一鍵清空；不應把Windows紀錄中的全部項目重新列成Mac缺失。Mac亦已有 `.heiban` 與 PNG／PDF／SVG／HTML 匯出；Google雲端、完整PDF／SVG編輯及結構化筆記仍是舊待辦。

此批未重跑歷史測試、未量測Mac性能、未在Windows執行新App／MSIX／WACK、未查Partner Center認證結果。所有新驗收目標必須在後續獲授權的實作／驗收批次附真實結果。

## 5. 來源與紀錄入口

- 公開 [main來源](https://github.com/VirginBear/HeiBan/tree/99c08c5021d2e76029cea18f9b3bf039b7193170)、GitHub releases API本次實查。
- Windows [目前狀態](../../../windows/docs/CURRENT_STATUS.zh-TW.md)、[效能第二批](../../../windows/docs/performance/2026-10-11-batch2/README.zh-TW.md)、[20項操作](../../../windows/docs/UX_ALIGNMENT_2026-10-11.zh-TW.md)、[後續補強](../../../windows/docs/UX_FEEDBACK_2026-10-11.zh-TW.md)、[多語](../../../windows/docs/LOCALIZATION_2026-10-11.zh-TW.md)、[送審紀錄](../../../windows/docs/STORE_SUBMISSION_2026-10-10.zh-TW.md)。
- [本日誌](logs/2026-10-11/01.zh-TW.md)、[機器可讀核對](SYNC_AUDIT_2026-10-11.json)。私人原文仍在独立PRIVATE庫，公開文件不複製產品管理JSON／對話／素材。
