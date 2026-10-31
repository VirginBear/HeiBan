# HeiBan 開發紀錄入口

更新：2026-10-31。歷史計畫、實作與驗收是三種不同狀態。

## Mac維護與目前交付

- [2026-10-29 Windows 1.0.18 → Mac 1.0.18 同步開發日誌](../macos/docs/development/logs/2026-10-29/01.zh-TW.md)：build 20261029.1；三固定教學工具（選取／雷射筆／藤條）、藤條 45°/75° 揮擊與拍打音效、板擦 45° 可視輪廓對齊、按住雷射＋共用色盤、右鍵四向圖層移動；1,979 項斷言通過與嚴格簽章封裝完成。

- [2026-10-24 Mac1.0.17來源GitHub同步](../macos/docs/development/logs/2026-10-24/04.zh-TW.md)：build20261024.3、來源64dad31，含常用色／操作同步與螢幕模式修復；推送與遠端SHA核對完成，未新增下載包。

- [2026-10-24 螢幕畫布操作切換修復](../macos/docs/development/logs/2026-10-24/03.zh-TW.md)：1.0.17 build20261024.3；固定模式入口、焦點／穿透、雷射恢復及Finder實機操作證據。

- [2026-10-24 Windows1.0.17→Mac1.0.17功能與操作對照](../macos/docs/development/WINDOWS_SYNC_REVIEW_2026-10-24.zh-TW.md)：常用色／固定雷射／活動色線／平移、資料保護與平台性能邊界；本機build20261024.2，實機細節待使用者回饋。

- [2026-10-23 Mac專案GitHub同步](../macos/docs/development/logs/2026-10-23/04.zh-TW.md)：1.0.16 / 20261023.2來源、手冊及開發紀錄已推送origin/main，未建立新二進位Release。

- [2026-10-23 工具列／雷射／板擦修整](../macos/docs/development/logs/2026-10-23/03.zh-TW.md)：繪圖頁左錨點、雙畫布外觀及尺寸共用、連續雷射、兩畫布板擦；1.0.16同版build20261023.2。Windows雷射只留交接。

- [2026-10-23 Mac操作修整實作](../macos/docs/development/logs/2026-10-23/02.zh-TW.md)：教學練習防覆寫／十語Mac資產可重建、圓擦隔離交易／交點裁剪、單一工具設定host與命令；1.0.16同版build20261023.1，操作驗收另列。

- [2026-10-23 Antigravity進度與Mac操作邏輯核對](../macos/docs/development/ANTIGRAVITY_PROGRESS_REVIEW_2026-10-23.zh-TW.md)：本機與GitHub為1.0.16；指南內容／保護／Git資產、隱藏設定入口及圓擦交易仍有缺口。Mac優先操作一致性，Windows性能留原平台。

- [2026-10-22 Windows 1.0.16 → Mac 1.0.16 同步與專案健康度審視](../macos/docs/development/logs/2026-10-22/01.zh-TW.md)：工具列預設全開與無損遷移、自由筆無磁鐵干擾、板擦 80% 幾何、十語無邊界指南入口；前批日誌記載1,862項斷言通過，本輪未重跑，完整性限制以10/23核對為準。
- [Windows1.0.15 → Mac1.0.15同步開發／功能與限制](../macos/docs/development/WINDOWS_SYNC_REVIEW_2026-10-16.zh-TW.md)。本機版本與編譯／封裝證據依當日日誌，公開舊Release另列。

- [Mac開發進度、排錯與交接總表](../macos/docs/development/MAC_DEVELOPMENT_HANDOFF_2026-10-13.zh-TW.md)
- [Mac 1.0.13公開與快取清理](../macos/docs/development/RELEASE_2026-10-13.zh-TW.md)
- [維護文件總覽](../macos/docs/development/README.zh-TW.md)
- [目前開發狀態與待辦](../macos/docs/development/CURRENT_STATUS.zh-TW.md)
- [實際程式架構與維護邊界](../macos/docs/development/ARCHITECTURE.zh-TW.md)
- [開發日誌](../macos/docs/development/DEVELOPMENT_LOG.zh-TW.md)
- [困難、錯誤與排解紀錄](../macos/docs/development/ISSUE_HISTORY.zh-TW.md)
- [架構決策](../macos/docs/development/DECISIONS.zh-TW.md)
- [10/12清晨Windows更新、本機完整性與Mac下一步](../macos/docs/development/WINDOWS_SYNC_REVIEW_2026-10-12.zh-TW.md)
- [兩庫同步完整性、Windows進度與Mac改善清單](../macos/docs/development/WINDOWS_SYNC_REVIEW_2026-10-11.zh-TW.md)
- [Mac工具列追齊Windows：Antigravity工作與驗收清單](../macos/docs/ANTIGRAVITY_MAC_TOOLBAR_WORKLIST_2026-10-11.zh-TW.md)
- [本次程式整理稽核](../macos/docs/development/CODE_REVIEW_2026-10-09.zh-TW.md)
- [使用手冊](../macos/docs/USER_GUIDE.zh-TW.html)

## Windows端減重評估接手

- [2026-10-31 Ponytail對照與Windows六項優化方案](../windows/docs/PONYTAIL_REVIEW_2026-10-31.zh-TW.md)：擦除候選／快照、共用筆刷設定、增量Undo與Store相依減重；僅靜態分析，未實作／未進版。

- [2026-10-29 Windows 1.0.18.0正式Store提交包](../windows/docs/STORE_RELEASE_1.0.18_2026-10-29.zh-TW.md)：已獲使用者版號核准，x64＋ARM64封裝與靜態核對完成，未上傳／送審；附十語更新文案，保留歷史包。

- [2026-10-29 固定教學工具、右下布局、雷射色盤與右鍵圖層](../windows/docs/TEACHING_TOOLS_2026-10-29.zh-TW.md)：三固定工具／可見輪廓對齊／共用常用色／四圖層命令；1.0.17開發試用，實機待驗收。

- [2026-10-29 Windows藤條取樣與角度](../windows/docs/CANE_SAMPLE_2026-10-29.zh-TW.md)：指定MP3取一次揮擊、45°休止／75°揮動、保留回彈；同1.0.17開發試用，App／實際聲音待驗收。

- [2026-10-29 Windows藤條握持與入口修整](../windows/docs/CANE_REFINEMENT_2026-10-29.zh-TW.md)：右下握點、持續跟隨、原創圖／音訊備援、隱藏恢復與常用對齊，移除管理入口；同1.0.17開發試用，實機待驗收。

- [2026-10-29 Windows藤條提醒工具](../windows/docs/CANE_TOOL_2026-10-29.zh-TW.md)：管理／可選常用鄰雷射、板擦旁快捷、雙畫布單次揮動與原創聲音；同1.0.17開發試用，實機待驗收。

- [2026-10-22 真實採樣、轉角與板擦卡頓](../windows/docs/ERASER_AND_INPUT_QUEUE_2026-10-22.zh-TW.md)：板擦背景批次、數值基準與同樣式合併評估；驗收依後續實機。

- [2026-10-22 畫筆與切換工具卡頓追查](../windows/docs/INK_LATENCY_2026-10-22.zh-TW.md)：真實使用回報、渲染／索引／資源改善及手動本機採樣；性能驗收依證據。

- [2026-10-22 常用工具與完整無邊界操作指南](../windows/docs/TOOLBAR_GUIDE_2026-10-22.zh-TW.md)：預設圖示與文字、全工具可操作指南；試用與驗收依日誌。

- [2026-10-22 工具預設、操作範例與繪圖流暢度](../windows/docs/DRAWING_FLOW_2026-10-22.zh-TW.md)：新系列開發，未進版；試用與未驗收事項依日誌。

- [2026-10-15 Microsoft Store更新](../windows/docs/STORE_RELEASE_2026-10-15.zh-TW.md)：使用者核准本系列更新，套件1.0.15.0；實際封裝／提交結果依日誌。

- [2026-10-15 板擦更多入口與鏡像](../windows/docs/BOARD_ERASER_ENTRY_MIRROR_2026-10-15.zh-TW.md)：保留原圖、左高右低顯示與共用接觸面，最新試用依Windows狀態。

- [2026-10-15 原創斜角板擦](../windows/docs/ANGLED_BOARD_ERASER_2026-10-15.zh-TW.md)：紙白／霧綠生成素材、隨斜擦面的輪廓擦除與抓取位置，覆寫前批木質正矩形板擦。

- [2026-10-15 八項畫布操作與一致外觀](../windows/docs/CANVAS_UI_REFINEMENT_2026-10-15.zh-TW.md)：單排分組、常用自訂、起點／幾何磁鐵、生成板擦、匯入告知、圖釘與固定主題；驗收與試用檔依日誌。

- [2026-10-15 繪圖／文件交換批次](../windows/docs/DRAWING_WORKFLOW_2026-10-15.zh-TW.md)：PDF／PowerPoint頁面匯入、多頁PDF匯出、磁鐵、連續繪圖、雙擊詳細屬性、圖文分頁工具列與實機圖手冊；驗證與試用包以該日誌為準。

- [Windows操作／精簡優化本機批次（待實機）](../windows/docs/WINDOWS_OPTIMIZATION_BATCH_2026-10-13.zh-TW.md)：screen catalog去重、填色入口收整、焦點輪詢降頻；未build／測試，包體減重尚未驗證。
- [工具列一致性第一批實作日誌（未驗收）](../windows/docs/TOOLBAR_ALIGNMENT_2026-10-13.zh-TW.md)：共用偏好政策、形狀選單及十語手冊已落源碼；其他工具及面板仍待接線。
- [Windows版本減重分析計劃報告書](../windows/docs/WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)。
- [Store／Portable基準數據](../windows/docs/PACKAGE_SIZE_BASELINE_2026-10-13.json)與[文件同步交接](../windows/docs/SIZE_PLAN_HANDOFF_2026-10-13.zh-TW.md)。
- 方案尚未實作，版本政策不變；Windows原機成品／作品／工具不隨Git同步。

## 其他平台與共用文件

- [Windows 文件](../windows/README.md)、[Windows 架構](../windows/docs/ARCHITECTURE.zh-TW.md)：Windows獨立功能與封裝進度以[目前狀態](../windows/docs/CURRENT_STATUS.zh-TW.md)為準；GitHub下載與相應來源依平台版本更新。
- [跨平台文件契約](DOCUMENT_SCHEMA_CONTRACT.md)、[平台決策](PLATFORM_DECISIONS.zh-TW.md)。
- [早期整體稽核](PROJECT_AUDIT.zh-TW.md)、[原開發計畫](DEVELOPMENT_PLAN.zh-TW.md)、[原工作清單](WORK_BACKLOG.zh-TW.md)：保留歷史；當前 Mac 狀態以平台 CURRENT_STATUS 為準。

## 固定維護方式

每批工作開始建立日誌，遇到問題即追加調查過程，交付前更新目前狀態與證據。根目錄 `AGENTS.md` 已記錄這些規則。紀錄隨程式保存在 Git 工作區；是否已同步須核對遠端 commit，不能僅憑檔案存在判定。公開整理紀錄見 [發行稽核](PUBLIC_RELEASE_2026-10-09.zh-TW.md)。
