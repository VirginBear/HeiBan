# Windows 1.1.2 筆尖熱點／藤條三擊效果 — 2026-11-05

使用者GO：鋼筆／螢光筆／油漆筆刷及橡皮擦的實際游標點改為筆尖／接觸點，兩套圖示都適用；雷射用較小光點且中心是落點；同區域連敲藤條三下出現裂屏效果與破裂聲；鋼筆拉直等待縮短0.2秒。只Windows，維持1.1.2開發批次，不覆寫既有1.1.2.0 Store提交包。原三份dirty清理文件／三份YouTube未追蹤文件保留，snapshot存`.build/cursor-cane-20261105`。

先讀索引、Windows規則／目前狀態／架構／問題／決策。查到ToolCursor固定十字hotspot=size/8，而圖案另translate8,8；需改原生cursor hotspot，而非改輸入／作品座標。兩host都經ShapeCursor，可共用新hotspot模型。參考Microsoft CreateIconIndirect／ICONINFO／CreateDIBSection文件，32-bit alpha cursor需自己釋放建立用bitmap，系統複製後cursor另管理；不能讓色彩變更無上限累積native handle。

藤條仍以下方握柄跟手（依先前使用者要求），裂紋定位於可見的藤條敲擊尖端。暫定1.2秒內、第一擊附近36DIP三擊觸發一個短暫局部裂紋，約1.2秒淡出；分散、逾時、換工具或模式均重置。裂紋不截取／修改其他軟體畫面，不進永久物件／Undo／匯出；破裂聲用原創合成且沿用藤條靜音。實作與失敗／實際驗證結果逐步追加。

## 實作進行中

已找到兩host原1秒hold，改共用StraightStrokeRecognizer.HoldSeconds=.8，保留原幾何判斷與100ms檢查節奏。游標由26×26原圖座標映射實際DPI熱點；alpha DIB／CreateIconIndirect保留A配色、細描邊與白halo；cache最多64筆，替換前建立handle，釋放bitmap與owned cursor。藤條累計與效果生命週期留Core暫態；固定90段局部裂紋，重用兩host既有互動timer及damage修補，無新增作品物件。破裂音原創合成31752frames，抽出LocalEffectSound共享既有MediaPlayer／memory WAV fallback，保留原藤條sample。

前期查找錯誤：CaneFeedback實際在Windows.Core而非Windows/Engine；PowerShell不能直接把MainWindow*.cs當rg路徑，已改-g過濾；未影響原始碼。

## 驗證進行

Core Release：3689 checks PASS（本批新增244項）；QA build三次皆0 warning／0 error。原生r1失敗：驗證讀cursor bitmap時GetDIBits傳入null HDC，回傳0；正式cursor建立並未失敗。已讓QA helper取得／釋放screen DC，r2 PASS：334 native checks＋5 screen checks，涵蓋兩風格9工具5尺寸、hotspot與非空bitmap、150種顏色cache≤64、音效請求／靜音／文件generation、螢幕局部damage與清除後pixel-byte精確一致。原生PNG atlas／cane-crack已目視，洋紅圈只存在QA atlas，不是正式游標。

以computer-use skill實際操作獨立qa-data-r2：原生視窗選藤條，Sky三次左鍵點擊同座標，實際出現局部白色裂紋與彈性藤條；接續檢查淡出、鋼筆繪製。音效硬體聆聽尚未執行。手冊重新生成10語言，每份26章／80段。

補充：實際三連敲與後續淡出皆已目視確認；後續鋼筆drag被computer-use偵測使用者輸入而拒絕，未執行成功，未當成驗收。Update.Tests為既有獨立專案，執行失敗於GitHubUpdateService缺Localization參照，與本批游標／藤條無關，未擴大修改；OptimizationChecks第一次漏帶輸出參數而拒絕，補正後重跑。另覆查1-bit mask必須WORD對齊，已修正40px時的mask stride並新增native40px驗證。

## 最終封裝前驗證

qa-build-r3：Release win-x64，HEIBAN_RELEASE_VALIDATION，0 warning／0 error。native-r3：370 checks＋5 screen checks PASS，含新增40px、所有native bitmap非空，cache上限64、音效requested／mute、螢幕清除後pixel完全一致。OptimizationChecks補帶獨立輸出參數後68 PASS。Build-LocalizationCatalogs.py十語708 keys／0缺漏；Build-UserGuides.py十語26章80段，去除舊十字熱點敘述；Core3689。尚無硬體聆聽、實際拖筆尖體感、實際0.8秒按住及ARM64硬體驗收。

## 交付產物與命令紀錄

- `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release`：3689 PASS。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/cursor-cane-20261105/qa-build-r3`：0警告／0錯誤；獨立qa-data-r3，`--cursor-cane-validation-output=<native-r3>`：370＋5 PASS。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks -c Release -- windows/.build/cursor-cane-20261105/optimization-r1`：68 PASS。第一次缺輸出參數拒絕已保留optimization.log。
- `dotnet run --project windows/HeiBan.Update.Tests -c Release`：既有CS0234 Localization參照錯誤，未修改／未宣稱通過。
- `python windows/scripts/Build-LocalizationCatalogs.py`：十語708keys，0缺；`python windows/scripts/Build-UserGuides.py`：十語26章80段。
- `python windows/scripts/Generate-CaneCrackSound.py`：31752frames／0.72秒；原創無取樣；Notice含SHA。
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label cursor-cane-2026-11-05-r1`：正常Release完成，來源014d155170ec8ea76ca9d606cb1bc937f55a4c58。
- `.build/cursor-cane-20261105/Verify-Portable-r1.py`：724 payload／401來源／132SVG／10語指南逐SHA、ZIP CRC、獨立空白Data、QA helper不在正常assembly，全部通過。ZIP133452351bytes，SHA685f5009285e367093ed6e9c0fb38d92de7e1d2127dd6a4e3cc6649ce3edc8fc。
- 正式1.1.2.0 x64／arm64／bundle三包SHA與上批封存完全相同。只有Windows改動，原dirty三文件增減行核同、三份YouTube草稿保持未追蹤。

試用：`windows/dist/trials/HeiBan-Windows-Portable-1.1.2-cursor-cane-2026-11-05-r1-win-x64/HeiBan.exe`，同路徑`.zip`。本批未啟動正常trial，原生QA獨立資料庫已實際啟動；無使用者作品搬移／刪除。

## 使用者試用成功標準

1. 原版／A各試鋼筆、螢光筆、油漆筆刷與橡皮擦：筆跡起點／擦除中心跟圖示筆尖／接觸點一致，沒有旁掛十字偏移；切換DPI／跨螢幕再看。選取與物件變形游標仍正常。
2. 雷射游標小光點中心就是落點，實際尾跡仍按左鍵才出現；比較遮擋與辨識度。
3. 藤條1.2秒內同區域連敲三下，45度敲擊尖端出局部裂紋並約1.2秒淡出；分散／逾時不觸發，換工具／模式後重算，作品／Undo無新增。兩畫布都試、靜音時仍動畫但無兩種聲音。
4. 鋼筆近似直線按住不動，原1秒變0.8秒（100ms檢查節奏造成少量量化）；曲線不誤拉直，移動超12DIP恢復預覽。主觀等待感受與硬體音量／音色待使用者。

後續UI關閉測試視窗時遇computer-use偵測使用者輸入，已停止追加操作；未強制終止程序。這不算筆尖拖曳或關閉流程驗收。未做ARM64硬體、WACK、Store安裝／新送審／端到端延遲量測；未覆寫商店包。
