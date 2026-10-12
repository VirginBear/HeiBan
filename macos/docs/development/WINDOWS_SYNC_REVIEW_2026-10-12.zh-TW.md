# 10月12日 Windows 更新同步與 Mac 下一步

日期：2026-10-12（Asia/Taipei）。本批完成來源同步與差異審視；不代表功能已移植、App已更新或操作已驗收。

## 1. 同步結果

- GitHub公開main新增17筆提交，台北時間03:59:32–06:09:04；符合使用者描述的約05:00更新，還包含稍晚文件補充。前一來源7198f11，最新[148d427](https://github.com/VirginBear/HeiBan/commit/148d427a47e03a09bf21431d248fe00e3e9b6d9a)。
- 86個上游變更檔案全位於windows/，與本機Mac修改／新增路徑零重疊。`git fetch origin`後以`git merge --ff-only origin/main`取回；HEAD／origin/main／即時ls-remote一致，ahead／behind為0／0。
- Windows目前347個Git追蹤檔逐一比對Git blob，347相同、0缺失／差異；Windows工作樹無本批未提交修改。包括新手冊資源、腳本、AGENTS、Store說明與共用工具列來源。
- Mac同步前30個修改／新增檔案（含本批開工日誌）逐byte SHA-256比對後全部保留；patch／新增檔ZIP／原SHA清單只存在.git/codex-sync-backups/20261012-windows-sync，不包含App／作品，也不進公開庫。後續修改本批日誌／目前狀態屬本次紀錄更新。
- 相鄰PRIVATE checkout也完成fast-forward，远端與本機一致、工作樹乾淨；connector核對visibility=private。產品管理內容與IARC原件沒有移入公開庫。
- Mac執行檔仍是1.0.13 / 20261011.1；SHA與10/11交付一致。本批沒有重編譯／安裝／啟動App。Windows候選metadata沿用1.0.14，Git未保存原Windows電腦的dist套件、Data作品或SDK；取回來源不等於已安裝其免安裝／Store新包。

逐項提交與核對資料見[本批JSON](SYNC_AUDIT_2026-10-12.json)／[日誌](logs/2026-10-12/01.zh-TW.md)。

## 2. 這批 Windows 新增什麼，Mac 應如何跟進

| 項目 | Windows本批來源證據 | Mac目前狀態／下一步 |
|---|---|---|
| 工具列共用 | [9b6c4e4](https://github.com/VirginBear/HeiBan/commit/9b6c4e48563c6cfc95a4e7d1de3ecd2be8d0b825)，Views/ToolbarUi集中按鈕、提示、無障礙名稱、閱讀方向與4種線型 | Core工具共用，但一般／螢幕UI入口有差距；抽共用工具描述／命令／樣式元件，各自保留座標、停靠、穿透與保存owner。不是共用同一份作品或同一個原生View |
| 存檔指示配置 | MainWindow.Chrome狀態／提示比對後才重建儲存圖示 | Mac狀態槽位已固定，但完整dirty／草稿／交易判斷仍有待辦；先補真實存檔狀態，再量測高頻更新成本，不把SwiftUI宣告式重算等同必然建立原生視圖 |
| 儲存模式 | [c409a6e](https://github.com/VirginBear/HeiBan/commit/c409a6e8e27e4d1ee7e9187e86c8929109187bb6)，autoSaveEnabled預設false、主／螢幕統一開關，手動與離開仍保存 | Mac SettingsView有頻率Picker，實際BoardEngine.scheduleAutosave固定0.7秒，未讀autoSaveFrequency；螢幕保存另有owner。需先修設定真正生效，再設計開關／離開前保存與可見進度。Windows的新預設不自動套進Mac使用者既有偏好 |
| 退出保存進度 | 保存前隔離輸入／提交草稿，動畫先顯示，成功才关闭、失敗留視窗 | Mac已有失敗拒絕退出；AppDelegate仍同步回Bool，saveBeforeLeaving會queue.sync。若加入進度需先設計非同步退出／等待及失敗重試，不能只畫ProgressView或把IO搬到背景但立刻關窗 |
| 十語離線手冊 | [8458363](https://github.com/VirginBear/HeiBan/commit/84583637706e172e0ed64c0e8431122311f17309)，25章55段、章節導覽／搜尋／頁內切語；首頁／作品同入口隨App語言開啟 | Mac目前單份正體中文21章、WKWebView原生獨立視窗。先核對Mac自己的已交付功能，再接Mac語言catalog／偏好及十語手冊；不直接複製Windows快捷鍵、保存規則或未支援功能，不依賴Windows NLS |
| Store／正式進版 | 十語商店文案、runFullTrust說明、候選與來源證據；新windows/AGENTS要求整批驗證後由使用者決定進版 | Store資料僅供理解Windows開發／發行狀態；Mac維持现有開發版，用日期／commit／批次標籤辨識後續修改，不因同步或單批封裝自动升版。不宣稱新候選已提交／上架 |

本表是來源審視；Windows前機的編譯／靜態報告不是本機App／效能驗收。ToolbarUi共用不能直接保證筆畫更快，也不保證包體大幅縮小。

## 3. 下一批工作與驗收目標

沿用[10項工具列工作清單](../ANTIGRAVITY_MAC_TOOLBAR_WORKLIST_2026-10-11.zh-TW.md)與[原12項同步工作](WINDOWS_SYNC_REVIEW_2026-10-11.zh-TW.md)；以下追加新差異，避免重開重複需求。勾選只在有實際證據後更新。

### 第一階段：現有版本與資料安全（優先）

- [ ] **本機1.0.13操作确认**：右上懸停／固定／popover、圖層握把預覽／插入／取消／undo／不同頁、首頁螢幕畫布；一次移一物件，鎖定來源先解鎖。來源M26／MAC-SYNC-05；來源編譯完成不等於手感驗收。
- [~] **MAC-SYNC-13 存檔設定真正生效**：第一輪已接通頻率與獨立開關、舊偏好解碼遷移、普通作品／螢幕恢復排程，以及 AppDelegate 等待一般作品非同步保存。**尚未完成驗收**：螢幕 Session 退出前仍以同步 I/O 寫恢復檔，需改為非同步等待各顯示器；未測試關閉與手動保存、各頻率、偏好遷移、失敗保留與重試、文字草稿及多顯示器結束。手動／離開／正常退出保留；不可把自動保存off映射到`persistence.enabled=false`（它是保存owner邊界）。
  - 驗收目標：一般／螢幕各自開關生效；off不定期寫作品但手動可存；更改頻率符合實際排程；切頁／換作品／匯入／離開／⌘Q／螢幕結束先提交有效文字草稿；失敗留內容可重試。pending写入不能因關開關造成舊快照覆蓋，偏好不進作品undo。
- [ ] **保存中的可見狀態與退出**：涵蓋dirty、文字草稿、live交易及成功／失敗回報。採Mac原生非同步退出協調，保存期間阻擋新編輯／重入，成功才關閉。
  - 驗收目標：慢寫入可見進度、UI仍响应，失敗不關窗；主作品／多螢幕恢復檔与縮圖全部等待，強制結束風險在說明中明列。

### 第二階段：操作完整度與流暢度

- [ ] **TB04–09追齊**：螢幕工具列依內容量測、空間不足換行／換列，保留側邊窄圖示；補收合、完整色輪／透明度／線型、螢幕圖層與曲線、屬性依類型收斂與四邊避讓。保留T／右鍵文字、雷射與橡皮擦再點設定、穿透、四邊色圈、可復原一鍵清空和斜向圖釘一致性。
- [ ] **MAC-SYNC-09基準先行**：普通／透明畫布，0／300／1000／10000物件、稀疏／密集、圖片／文字，記input→preview、提交、pan／zoom、CPU／記憶體／idle及保存成本。记录Mac硬體与縮放，不套Windows成績。
- [ ] **MAC-SYNC-10按證據改善**：尾端預覽／frame合併、當頁穩定排序／保守bounds候選、平移縮放快取、可見圖片與富文本布局、idle事件喚醒。沿用已可編輯向量／同zIndex／取消／undo／未知欄位／匯出契約；Metal或更換renderer先有收益與fallback證據。

### 第三階段：多語與更遠功能

- [ ] **MAC-SYNC-11／14 多語UI與離線手冊**：Mac原生語言資源與显式正體中文預設；入口與手冊隨語言刷新，十語搜尋／章節／RTL，手冊切語不改App偏好。保留Mac功能描述及原生快捷鍵；作品內容／工具碼／座標不翻譯，母語與長字串驗收另列。
- [ ] **原需求後續**：Google登入／同步、外部PDF插入與註記、恢復HeiBan自己匯出文件、SVG向量物件編輯及結構化筆記，沿用既有產品範圍；先做文件與權限／離線衝突契約，再接入口，不能把核心原型或設定頁視為已交付。
- [ ] **整批完成再決定正式版本**：提供來源、完成／剩餘清單、當次授權的操作與回歸證據，再由使用者決定正式進版／發布。Mac只留最新App，歷史來源／文件保留；本批不提前改版號或公開下載。

## 4. 本批沒有執行

App／UI操作、測試套件、效能量測、編譯／封裝、Windows包下載／安裝、作品資料複製、推送、Store後台或Release發布均未執行。完成的是取回Git內容、保全與差異審視；下一批開發依使用者指示進行。
