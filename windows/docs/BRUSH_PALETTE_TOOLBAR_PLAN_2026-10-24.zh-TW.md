# 2026-10-24 Windows筆刷／常用色／常駐雷射計畫

狀態：僅分析／規劃，未實作。使用者確認畫布修復OK，要求四項後續調整，晚一點才推動。本輪不修改程式、不編譯、不測試、不封裝、不進版。

開工HEAD 0903b62e705648ef435e80ff42d5454567552084；保留原三份平台文件6／8／4行與三份YouTube新檔。已讀索引、Windows狀態／架構／問題及平台規則。正在核對筆刷選項、色盤保存及共用工具列入口。

## 一、已確認的現況（靜態讀碼）

| 位置 | 證據／影響 |
| --- | --- |
| MainWindow.Teaching.cs / AddExtendedObjectSettings | 八種筆刷下拉只修改BrushKind；Engine搜尋沒有按BrushKind切換材質的實作。不能把名稱當成可用水彩／蠟筆引擎。 |
| Core/Models/BoardModels.cs、SelectionStyle.cs、MainWindow.Input.cs | BrushKind仍是作品序列化、樣式與新物件欄位，移除UI不等於可以刪既有資料。 |
| MainWindow.Chrome.cs / Palette、AddPalette、ShowBrushSettings | 一般畫布固定8色；ColorWheel可調色，沒有使用者色票新增／移除。 |
| ScreenAnnotationWindow.Panels.cs / ShowScreenPalette | 螢幕畫布另有不同固定8色，不能只修改一般畫布。 |
| MainWindow.Chrome.cs / ChangeProperty、ActivateTool | 目前色彩會傳遞到其他工具樣式；不要為了色線擅自改成各工具獨立記色。筆刷圓色塊已有更新，筆工具本身沒有下方色線。 |
| Views/ToolbarUi.Presentation.cs / Arrange、LabelMode、ReplaceIcon | 兩畫布共用排版；圖文模式把select放在分頁外，laser仍由頁面篩選。色線結構須相容圖示替換與標籤包裝。 |
| Core/Engine/ToolbarPreferences.cs | CommonTools預設無laser；select強制可見。Normalize已有版本遷移，須延伸同一政策。 |
| MainWindow.TeachingPreferences.cs | teaching.json已有工具樣式保存，但沒有可編輯色盤；其目前序列化未保留未知欄位，不宜為此批直接擴充後覆寫未知資料。 |

## 二、確定的使用者需求與範圍

1. 移除筆刷設定中的八種材質下拉；保留實際可用的鋼筆、螢光筆等工具，以及顏色／粗細／透明度設定。
2. 色輪先調色，再按「＋」儲存常用色；可移除不需要的色票，重開App仍在。
3. 鋼筆、螢光筆與繪圖工具圖示下方顯示實際筆色線；既有選中背景繼續提供工具選中狀態。
4. 雷射與選取一樣跨全部分頁常駐，預設包含在常用配置。

本批規劃適用Windows一般／螢幕畫布；Mac／Web只留未來比對資訊，不修改。現有1.0.16／1.0.16.0及canvas-recovery試用包維持原狀；使用者回覆OK屬正面回饋，不擴大為所有性能驗收。

## 三、預定操作設計

### A. 移除誤導選項

- 從AddExtendedObjectSettings移除材質ComboBox及其UI事件；同步搜尋其他屬性入口、翻譯與使用說明。
- 保留BrushKind讀寫、既有值及未知欄位，舊作品照常開啟；此批不宣稱新增真正水彩材質。
- 不刪有其他引用的資源／資料模型／歷史文件，移除前用rg查所有引用。

### B. 可管理的常用色盤

- 畫面：標題「常用色」＋色票區＋「＋新增目前顏色」＋「管理」。一般狀態點色票套用；管理狀態各色票有明確移除按鈕，另提供右鍵移除與鍵盤可達入口。
- ＋使用色輪目前已調整顏色；重複色不再新增，聚焦／提示「此顏色已在常用色」。新增後排在最後，不默默排序。
- 移除只影響色票，不改目前筆色、已畫物件或作品；允許全部移除，空白狀態保留＋與色輪。預設色只在第一次缺設定時建立；使用者儲存空列表後不自動補回。
- 提供明確「還原預設色」動作；保留色票順序。初始採一般畫布現有8色，舊版螢幕畫布未保存過使用者色票，首次改用同一組。
- 色票與目前筆色標示要區別；白色／透明色以細邊與棋盤底辨認，tooltip顯示色碼，螢幕閱讀器可辨識選取、色碼、新增與移除。
- 共用一份profile色盤；一般畫布／螢幕畫布同時開啟時立即同步列表。填色若共用色票，只共用色票集合，套用動作仍走原本填色處理，不錯改描邊。文字／圖釘的獨立色盤不擅自整批更換。

### C. 工具下方筆色色線

- 鋼筆、螢光筆、油漆／曲線及圖形集合鍵下方約3 DIP色線，放在圖示與文字之間；圖示模式同樣有線，不增加第二排工具。
- 色線表示該工具下一筆實際使用的描邊色；圖形不是填滿色，選取物件改色不得誤顯示成下一筆工具色。若現有工具共用筆色，色線同步反映，不新增獨立記色規則。
- 保留既有active背景；橡皮擦／選取不掛無意義色線。白色／透明色線有邊框／底紋，不會消失在白底。
- 共用工具圖示包裝helper，LabelMode／ReplaceIcon能找到並替換內層圖示，不能把色線替掉或反覆巢狀包裝。
- 只在顏色／工具／語言／配置變更時更新現有brush，不在PointerMoved或每個Draw重建XAML、保存設定、刷新整個工具列。

### D. 雷射常駐與排列

圖文模式：`[選取] [雷射] | [常用／繪圖／插入／管理＋當頁工具] | [更多]`。

- 常駐工具不參與分頁溢出，常用頁也只顯示同一個雷射，不複製第二份XAML按鈕。
- CommonTools預設包含laser作配置語意，但Arrange從頁面區排除select／laser；只有圖示模式也將兩者排在前端。
- 雷射與選取依本次明確要求固定顯示，自訂工具列不能把雷射移至更多；舊隱藏laser可於本次一次遷移為常駐，其餘自訂順序／顯隱／常用項維持。
- 四邊停靠、狹小視窗、螢幕畫布ResizeChrome都扣除兩個常駐鍵的尺寸；頁面工具維持單排／單列與既有上一組／下一組。不能擠出畫布、出現工具列scrollbar或丟失雷射。
- 雷射第一次選用、再次點擊開設定的行為保持一致，實際使用各host既有命令。

## 四、資料及程式安排（擬定，尚未落地）

- Core新增PalettePreferences／Store，使用各profile的`Settings/palette.json`，schemaVersion＋有序色碼列表＋JsonExtensionData；不寫入作品、不新增Undo交易。
- 色碼統一為引擎既有的#RRGGBB／#RRGGBBAA契約；精確驗證6／8位，大小寫、6位與FF alpha等價去重，保留alpha與筆畫Opacity各自語意。
- 讀檔區分不存在、使用者空列表、壞JSON／IO錯誤。錯誤保留原檔並提示，不在啟動時以預設覆寫；未知欄位保留。
- App共用palette協調器管理已載入快照、變更通知與單一保存佇列，兩host只接自己的套色委派。僅新增／移除／還原觸發背景原子寫檔，序列化保存避免舊快照蓋新狀態；保存失敗可見，不假稱已保存。關閉等待未完成的偏好保存，與作品自動存檔開關獨立。
- UI共用PaletteEditor／tool-color-indicator helper；主host與screen保留各自session／Undo／座標，不複製另一套色盤邏輯。
- 預期修改：MainWindow.Teaching.cs、MainWindow.Chrome.cs／TeachingPreferences相關接線、ScreenAnnotationWindow.Panels.cs／Style.cs／Chrome.cs／Docking.cs、Views/ToolbarUi.Presentation.cs、Core/Engine/ToolbarPreferences.cs／ToolbarContentPolicy.cs及新增色盤檔。
- 所有手工複製ToolbarPreferences的地方核對revision／ExtraFields；例如SaveToolbarPreferencesAsync目前複製欄位須特別檢查DefaultCommonRevision，避免遷移反覆執行。
- 十語介面／手冊同步更新；指南生成器更新只影響新建預設指南，不能覆寫使用者已編輯的指南作品。跨電腦取回色盤需跟隨Data／Settings搬移，沒有新增雲端同步服務。

## 五、執行次序與未執行驗收

| 階段 | 工作／通過條件 |
| --- | --- |
| 1 | 先實作色盤資料／原子保存與遷移，確認空列表、去重、未知欄位、壞檔保護及保存先後。 |
| 2 | 共用色盤UI接兩host，移除無材質效果下拉；色輪／粗細／alpha、舊作品／Undo保持正確。 |
| 3 | 共用色線結構與狀態更新；測圖示／圖文、換工具、圖形描邊與填色、白色透明色、選取物件。 |
| 4 | 雷射／選取常駐與CommonTools遷移；測四頁／四邊／兩顯示模式，無重複、無scrollbar。 |
| 5 | 十語手冊／指南與紀錄，最後依當次測試授權編譯、獨立資料實機驗證，再提供同正式版號的新標籤免安裝包。 |

待執行測試清單：
- 新增／移除／移除全部／還原預設／重開App；一般畫布新增可在螢幕畫布立即見到，反向亦然。
- 重複色、alpha、空列表、非法色碼、壞JSON、未知欄位、連續快速增刪、寫入失敗與退出等待。
- 新設定、舊自訂設定與曾隱藏雷射；只遷移本次指定項，其他配置不重置，重開不重複追加。
- 舊含BrushKind的作品開啟／保存後值不遺失，未知物件欄位、選取改色、多選Undo及恢復不受影響。
- 完整「開畫布→畫線→首頁→重開」回歸，防止前批空白退化；板擦／橡皮擦／雷射可用。
- 性能只比較實際採樣；色盤管理不加入指標高頻路徑、不新增閒置輪詢。不能把編譯或UI成功當成端到端50ms達標。

## 六、本輪紀錄與接手入口

本輪只執行git status、讀取平台文件、rg靜態搜尋及撰寫計畫。兩次初始搜尋使用不存在的Models／Services目錄，改以Core實際路徑繼續；沒有把搜尋失敗當成不存在功能的證據。Engine搜尋BrushKind等無匹配只表示此欄位未用於該渲染路徑，並未執行材質實測。

未執行：程式修改、編譯、測試、App啟動、資料複製、封裝、清理、正式進版或Store送審。舊測試數字只屬前批，不作本輪成績。等待使用者晚一點GO後，先讀本計畫與最新CURRENT_STATUS、記錄當次git status並建立新的實作日誌；若當次限制不同，以最新指示為準。不建立排程或自行稍後啟動。
