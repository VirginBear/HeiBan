# Windows 操作細節調整（2026-10-11）

## 開工紀錄

- 使用者授權 Windows 20 項操作調整；Mac 原始碼只供對照。
- 起始 HEAD：da5739157a34a01fae233b8fb07dfe53a92fa928；git status 僅有未追蹤 `.vscode/`，保留。
- 已讀開發索引、Windows CURRENT_STATUS、ARCHITECTURE、ISSUE_HISTORY 與根目錄 AGENTS。
- 保留 Store 1.0.12.0 已提交套件及全部既有免安裝產物。本批另建試用包，不發布 Store 或 GitHub Release。
- 本批尚未執行測試、實機操作或建置；不引用以前的測試數字。

## 工作範圍

1. 首頁右鍵開啟作品。
2. 一般點選與批次選取狀態分離。
3. 虛線圓多選入口與圓形勾選。
4. 筆停住一秒的近似直線吸附。
5. 可依畫布寬度設定尺長。
6. 依物件／工具顯示屬性。
7. 箭頭頭部大小獨立於線寬。
8. 個別圖釘本體與文字色。
9. 延伸直線移入屬性。
10. 便條紙視覺。
11. 同步上下視角鎖定圖示。
12. 獨立圖層面板。
13. 圖層拖曳把手與排序。
14. 再次點雷射開啟設定。
15. 儲存勾號／待存虛線圓。
16. 屬性四邊停靠與方向切換。
17. 螢幕畫布橡皮擦範圍。
18. 螢幕工具列依內容及顯示器自適應。
19. 螢幕畫布圖層。
20. 螢幕畫布調色盤。

## 進行中發現

- Home 的 Extended 選取與 SelectionChanged 使單擊也顯示批次操作列；Mac 明確以 selectionMode 決定操作列與卡片勾選。
- Inspector 的 XAML 同時包含筆、填色、文字、橡皮擦、尺及圖層，沒有類型過濾。Mac Inspector 與 LayerPanel 為分開入口。
- 螢幕工具列使用固定 820×60／64×688 DIP，需改以實際控制項尺寸計算並限制在目前顯示器工作區。

## 實際命令與結果

- `git status`、`Get-Content`、`rg`：來源與入口調查。
- 實作、建置、打包與執行驗收：進行中，交付時補上實際結果。

## 實作入口與逐項狀態

以下為已接上的程式入口，實體操作验收尚未執行。

| 項目 | 實作與入口 |
| --- | --- |
| 1 | Home 作品右鍵／⋯的第一個動作為「開啟作品」。 |
| 2 | 一般 Single，只反白；批次列只由 `_libraryMulti` 決定。 |
| 3 | 匯入左邊 24 DIP 虛線圓切換 Multiple；卡片圓圈勾選以通知更新。 |
| 4 | WindowsInkCoordinator 以單調時鐘判斷一秒，至少 5 點、24 DIP 長、近直線及走行長度條件；超過 12 DIP 錨點移動取消吸附，原點保留。放開提交 line，一次 undo。只接主畫布 pen，不把其他筆刷／螢幕註記自動辨形宣稱完成。 |
| 5 | 尺設定 20–150% 當前畫布寬度，90% 預設，保存 teaching 偏好。 |
| 6 | Inspector 區塊依物件分類；選到物件的刷子按鈕共用此面板，鎖定物件控制項唯讀。 |
| 7 | 箭頭屬性長／寬，native／SVG／命中／框選相同尺寸預設，主線粗細／虛線不變動頭部設定。 |
| 8 | 圖釘右鍵「圖釘與文字配色…」及圖釘清單「配色」，兩色單次交易；導覽與畫布套用。 |
| 9 | 直線延伸在屬性；舊偏好 extension 保留但不呈現工具列／更多／自訂工具欄位。 |
| 10 | 共用 native renderer 增加紙張明暗、黏貼帶、折角、投影、筆記／方格紋及貓耳；不移動原本的文字內框。PNG／列印沿用同 renderer；SVG 原有便條裝飾沒有全面重繪成相同陰影。 |
| 11 | RefreshNavigationChrome 同時更新上方 viewLock 與下方 NavigationLock。 |
| 12 | LayersPanel 獨立於 Inspector，更多導覽圖層入口切換顯示。 |
| 13 | 灰色雙槓捕捉指標，以虛擬化列實際座標提示插入位置，放開才 LayerReorder 交易。 |
| 14 | 可見雷射及更多選單雷射第二次點擊開設定；Inspector 也有雷射設定入口。 |
| 15 | 真實 `_saving`／dirty／draft／transaction 決定勾號或虛線圓，其他工具狀態文字不會被誤認成存檔成功。 |
| 16 | 屬性「停靠」選單／標題拖曳至四邊，左右直排／上下橫排；超量欄位可捲動。 |
| 17 | 螢幕 eraser hover 按目前 DPI 顯示同主畫布半透明圓，傷害區涵蓋旧／新位置；操作模式、工具列或 flyout 隱藏。閒置 hover 不重建 committed scene。 |
| 18 | 螢幕工具列量測 start/tools/end，依當前工作區與 DPI 上限調整；僅工具中段捲動，固定清除與關閉。 |
| 19 | 螢幕工具列／更多「物件圖層」，選取、上下移、拖曳、鎖定、顯示、改名；使用共用排序交易。 |
| 20 | 螢幕工具列／更多「調色盤」，8 色票與自訂色輪／alpha／hex；選取時修改線色／文字色，fill 另有入口。 |

### 屬性交叉比對矩陣

| 類型 | 顯示 | 隱藏 |
| --- | --- | --- |
| 筆跡／曲線 | 線色、粗細、樣式、透明度、旋轉；筆跡另有筆刷 | 填色、字型、橡皮擦、尺、圖層 |
| 直線 | 線色、粗細、樣式、透明度、延伸 | 填色、旋轉輸入、字型、工具設定、圖層 |
| 箭頭 | 同直線＋頭部長度／寬度 | 同直線 |
| 封閉圖形 | 線色／粗細／樣式、填色／填色透明／漸層、透明度、旋轉 | 字型、工具設定、圖層 |
| 圓弧 | 線色／粗細／樣式、透明度、旋轉；完整圓才填色 | 局部弧的填色、字型、工具設定、圖層 |
| 文字 | 文字色、透明度、旋轉、字級／字型／段落／局部格式 | 線寬／虛線、填色、工具設定、圖層 |
| 便條紙 | 文字、紙色／透明／漸層、紙張款式、旋轉 | 線寬／虛線、填滿開關、工具設定、圖層 |
| 圖片 | 透明度、旋轉、裁切／恢復 | 線色／寬／填色、文字、工具設定、圖層 |
| 遮題膠帶 | 主色、透明度、旋轉、揭示／遮住 | 線寬／樣式、無效的填色、文字、工具設定、圖層 |

## 困難與處理

- 第一個 Python 編輯腳本對 `   </Grid>` 的搜尋匹配到內層結尾，XAML 寫入前 ValueError。改用完整 WorkspaceHeader 邊界，從未完成的 XAML 段繼續，沒有重覆套用先前成功變更。
- Shell 中 Python 一行指令引號首次 ParserError，改為 `.build` 保存腳本；HTML 檢視首次 stdout cp950 無法輸出省略號，改 UTF-8 環境讀取。兩者不改產品資料。
- 初次 x64 build 的舊私有 `_rulerLength` 未用警告，移除改由百分比取代的欄位。後續 x64 build 0 警告／0 錯誤。
- 靜態檢視捕捉新增 XAML ValueChanged 可能在 InitializeComponent 期間觸發，補 chrome 初始化與 syncing guard。
- 既有可選驗證入口改掉 Extended／64 DIP 固定寬度假設，未新增案例、未執行該入口。

## 變更檔案與理由

- Home／Library／MainWindow.xaml／xaml.cs：分離首頁模式、卡片通知、開啟動作、面板容器與存檔狀態。
- MainWindow.Properties（新增）、Chrome／Teaching／Ruler／TeachingPreferences／Pages／Rendering／Input：依型別設定、停靠、配色、狀態、尺、雷射與工具入口。
- WindowsInkCoordinator：暫態停筆吸附；不寫高頻永久點。
- Direct2DCanvasRenderer.Sticky（新增）與 renderer：便條紙與獨立頭部輪廓。
- Core BoardModels／SelectionStyle／VectorMath／WindowSelection／BoardExporter：可選圖釘欄位、頭部樣式傳遞及幾何預設一致。
- LayerReorder、Views.LayerDragTarget（新增）、PinIcon／ToolIcons：共用排序交易、實際列座標、配色圖示。
- ScreenAnnotation Panels（新增）、Chrome／Docking／Style／Window：圖層、調色盤、類型樣式、尺寸與橡皮擦 overlay。
- Package-PortableTrial：標籤說明不再寫死效能第二批，來源 byte 記錄增加 XAML／HTML／manifest／README。
- Windows README／離線手冊／CURRENT_STATUS／ARCHITECTURE／DECISIONS／ISSUE_HISTORY／DEVELOPMENT_LOG／本紀錄及文件增補：入口、實際證據與相容限制。

## 建置／驗收邊界

- 已執行三輪 `dotnet build ... -c Release -r win-x64 -p:Platform=x64 --artifacts-path ...`：首次成功但舊欄位 2 警告；r2／final 成功 0 警告、0 錯誤。
- 補強來源後最後一輪 x64 build／封裝：進行中，結果續記。
- 本批 Core／native／App 啟動／實體滑鼠／4K／多螢幕／觸控筆：**未執行**。不引用之前的 2324／127 成績作本批結果。
- 圖釘可選欄位與 Mac 保存邊界、缺值箭頭外觀改變見[文件增補](DOCUMENT_ADDITIONS_2026-10-11.zh-TW.md)。

### 最終來源建置

- `dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --artifacts-path windows/.build/ux20-build-final-r2`：退出 0，0 警告、0 錯誤，29.13 秒。原始 log 留 `.build/ux20-build-final-r2.log`。
- 首次／r2／final／final-r2 log 都保留，未删除失敗編輯腳本或歷史產物。
- Store 1.0.12.0 bundle SHA256 重讀為 `d7a49b63d88fa880b1a97b0c307361ad2cfbc9b3d58786048887093d7204ea7b`，與本批前記錄相同。
- `git diff --check`：退出 0；Package-PortableTrial 提示 Git 將 LF 正規化為 CRLF，沒有 whitespace error。
- `git fetch origin main` 成功；提交前比對 HEAD 與 origin/main，僅提交本批 Windows 來源／文件。
