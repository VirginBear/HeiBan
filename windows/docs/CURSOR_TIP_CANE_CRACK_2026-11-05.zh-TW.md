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
