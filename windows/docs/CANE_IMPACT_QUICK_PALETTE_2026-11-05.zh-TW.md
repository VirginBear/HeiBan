# Windows藤條取樣／碎屑與六色快選 — 2026-11-05

使用者提供rock-smash MP3（四次攻擊），要求省略一次、其餘配藤條並保留最後碎裂聲；裂屏縮小＋細屑掉落。筆刷右方六圓（上三下三）直接選常用色前六項，色彩管理新增排序。只Windows、維持1.1.2開發試用、不覆寫正式Store包，原有三份dirty清理文件與YouTube未追蹤草稿保持。開工狀態／diff存`.build/cane-palette-20261105`。

先讀索引與Windows規則／狀態／架構／問題；現有PalettePreferences Colors已有順序且保存原子化、未知欄位保留，因此直接新增移動API、不另存一份六色。兩host既有ToolbarUi.Arrange共用，會將筆刷＋六色視為一組，避免分頁拆散；快選事件直接套用顏色，不走磁碟保存／重建工具列。PaletteEditor提供排序並共用存檔通知。音訊先解碼辨識四個attack邊界，保存來源SHA與處理決策，不把完整來源MP3放進產品。新增碎屑採固定少量幾何＋時間公式、含damage範圍，不進作品／Undo。

實際實作／失敗／命令與驗證結果進行中追加；不引用上一批測試數字作本批驗收。

## 實作進行

解碼8.976秒，四峰0.44／2.72／4.26／6.74秒；省略較弱且短尾的第二擊，保留1(0.390–1.420)、3(4.100–4.950)、4(6.510–8.976)三個獨立cue，共用gain、2ms入／20ms出、不變調速。來源SHA63ff0653d4c30d4f5e7ba58c694eb582a9bf2eb076370b97cff578a1f4987d80，未附license metadata，Notice據實記使用者提供。聲音由既有timer在impact .075秒有界queue取出，快連點不丟前兩擊，mute仍consume、不重播舊cue；第三擊用最後碎裂cue而非另疊合成音。裂紋縮.62、18碎屑共用一個GPU三角geometry，重力／旋轉／淡出純時間計算，damage擴到完整掉落路徑，device cache清除時釋放。

快色6固定按鈕、3×2，為profile Colors前六項投影，缺色保持disabled空圈、不另新增預設。筆刷＋QuickPalette wrapper不可分頁拆散，Visibility隨brush同步，Loaded／Unloaded訂閱store而非pointer。MoveAsync在原子write gate內依color定位，不用舊index覆蓋並發修改，未知欄位保留。管理模式拖曳或前後箭頭／右鍵選單排序。首輪Core5880 PASS；首QA build因Grid不提供IsEnabled，兩個CS1061引發XAML後續錯誤，改SetEnabled逐button，不誤改XAML字串；修正後重build。

原生r1在反覆停靠後立刻讀取空缺色狀態失敗（正常store寫入未失敗），已補載入時序等待及詳細狀態輸出再跑。另因筆刷組較寬，舊分頁固定用第一頁容量套到其他頁可能溢出；新增實際量測每組長度的ToolbarPaging，前後頁依page starts走，避免拆組或漏工具。Core新跑5883 PASS，加入不同寬分組頁界與空列／超寬組測法；MoveByAsync相對排序在gate內計算，快點兩下不只移一次。

原生r2詳細證據：IsLoaded=true、store已3色但按鈕仍6色／舊tags，等待180ms+80ms仍未修復，因此前一輪「只是等待載入」假設不成立。修正為profile訂閱跟隨host生命週期：QuickPalette建構即訂閱，BuildChrome替換前與兩host Dispose明確退訂，不把分頁／停靠reparent視為控制項終結。補Screen語言刷新、不在pointer做快照；同QA再驗。失敗產物r1/r2皆保留不覆蓋。

原生r3：371cursor／sound＋20主畫布quickColor＋16screen checks PASS；實際Sky選筆→快捷黃→drag線呈黃色，沒有重開設定。管理拖曳用CanDrag／OS DataPackage沒有改序（store原序已讀確認，程序medium integrity），不能當成功。參考Microsoft UIElement.StartDragAsync與drag-and-drop文件後，此功能僅面板內排序，改自管Button handled pointer事件、6DIP開始、色票ghost與候選邊框、放開才一次MoveAsync；取消／失去capture／Unloaded清理，不需要跨程式資料傳輸。官方API參考https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.uielement.startdragasync?view=windows-app-sdk-2.0 及 https://learn.microsoft.com/en-us/windows/apps/develop/data/drag-and-drop 。硬體音量／聆聽仍未驗收。

最終Core5884 PASS（含MoveByAsync雙快點累積）、Optimization68 PASS；build-r4-final／build-r5皆0警告0錯誤。原生r4 371＋20＋16 PASS。managed drag改色票預覽、source .4透明、目標3px邊框，管理中拖／點色票不套用筆色，完成後恢復點色；原生拖動實機重試遭computer-use user-input rejection，未假記成功；補載入Flyout的實際量測geometry／ghost／sourceopacity／drop持久化／取消不改序整合驗證，不使用系統輸入注入。後續結果追加。十語711UI keys／714作者列、指南26章80段通過。

QA r5的drag第一項（實際target／preview）通過，第二項opacity用精確.4比較失敗，WinUI屬性儲存精度需容差，改1e-5；不因測試改產品透明度，補跑r6。

## 封裝前實際命令／結果

- `python windows/scripts/Extract-CaneRockImpacts.py --input <使用者MP3>`：採1／3／4三個WAV，49440／40800／118368frames，48kHz PCM16 mono；來源SHA及每clip SHA見Assets/CaneRockImpacts.source.json。省略第二擊；未上傳完整來源檔。
- `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release`：最終5884 PASS（core-verified.log）。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks -c Release -- windows/.build/cane-palette-20261105/optimization-r1`：68 PASS。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/cane-palette-20261105/qa-build-r6`：0警告0錯誤。
- QA以不存在的獨立qa-data-r6，`--cursor-cane-validation-output=<native-r6>`：371 cursor／sound＋26 main quick palette／drag＋16 screen PASS。含重開順序、6色、缺色／空色、兩格式四停靠、ghost／source淡化／target／持久化／cancel不改序、3音效request／mute全停與螢幕clear target byte核同。
- `python windows/scripts/Build-LocalizationCatalogs.py`：10語711keys、714作者列、0missing；`python windows/scripts/Build-UserGuides.py`：10語26章80段。
- 真實Sky：點鋼筆、點黃圓、drag線實際黃色；r5管理拖最後深綠到首格，畫面與磁碟palette.json第一項#24533D、其餘順序維持，前六快選同步。原生r3/r4/r6 generated PNG已目視裂紋縮小與細屑下降；主觀音量／音色未實聽。

## 使用者試用成功標準

1. 筆刷右側六圈上3下3，一點就換下一筆顏色、工具保持原選擇；兩畫布都試。
2. 筆刷→常用色→管理，拖色票或前後箭頭排序，放開即保存，工具列前六同步；重開仍同序。少於6色的空位不啟用、不補預設；取消拖曳不改序。管理狀態色票本體只排序，按完成才恢復點色套用。
3. 連敲三次依序是來源第1／3／4擊，最後能聽到碎裂尾音；分散／逾時重算。靜音關三種cue，動畫繼續。
4. 裂紋約原.62倍，周圍少量細屑旋轉下墜淡出；離開／換模式消除，原作品與Undo不多出碎片。

正式Store1.1.2.0保留；ARM64硬體、WACK、Store安裝與新送審、本機喇叭實聽未執行。本批不重跑前批已知Update.Tests缺Localization參照，不引用舊測試數字。試用封裝與SHA結果待下一段追加。
