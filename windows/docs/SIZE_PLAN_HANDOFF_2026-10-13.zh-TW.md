# 2026-10-13 Windows減重計劃與Git接手紀錄

狀態：報告與基準完成，已推送公開GitHub並核對遠端；減重開發／測試未執行。

## 目的與範圍

使用者將在Windows電腦評估Store減重，要求完整報告與目前紀錄推送GitHub。本批只改Windows／Mac／共用文件，沒有產品實作／進版／build／App／tests／WACK／Store提交。Mac維持1.0.13／20261011.1；Windows沿用1.0.14候選政策。

## 起點與調查

公開main及origin/main均489ade4，fetch成功0/0。起始只有先前Mac體積分析／JSON／日誌02及其索引狀態修改；全部保留。Store最新版guides候選紀錄、SDK精確NuGet依賴與Portable量測收入減重計劃。重點更正：Store已排Updater，優化它新增收益0MB；42.23MB ML不是已確認Store省量。原調查的反斜線ZIP分類及空通用deps target問題、官方URL猜測失敗等排解見Mac日誌02，沒有刪除失敗過程。

## 新增與更新

WINDOWS_SIZE_REDUCTION_PLAN報告、PACKAGE_SIZE_BASELINE JSON；Windows README／CURRENT_STATUS／DEVELOPMENT_LOG／ISSUE_HISTORY／DECISIONS入口與計劃狀態；Mac總表／維護／問題／ADR／Antigravity現况；共用開發索引。來源／原始量測／相容性及尚未驗收狀態保留。

## Windows電腦接手

1. 專案根先git status，保存／提交既有Windows工作，避免覆蓋本地成果。
2. git fetch origin；確認可fast-forward且工作區乾淨再git pull --ff-only。有分歧先查差異並整合，不用reset／force取代自己的開發。
3. 讀根及windows/AGENTS.md、本報告與CURRENT_STATUS；Windows在windows目錄依WR-01起步，Mac文件供參考。
4. Git只帶來源／文檔及JSON證據，不會帶dist、.build、原機作品Data、SDK工具或簽章憑證。原Windows成品／送審資料請在原機保留，首次測試使用隔離fixture。
5. A／B候選先各自建立與驗收；正式進版及Store提交留給使用者決定。方案配置尚未實作，報告的打包命令不是自動減重腳本。

## 核對與同步結果

358個本地Markdown連結均存在，新增JSON可解析，Portable分組總量與原始audit一致。Mac成品版本／build／SHA符合既有紀錄，沒有重建快取；變更共21份文件，Git提交／push結果下方追加。完整工作日誌亦見[Mac日誌03](../../macos/docs/development/logs/2026-10-13/03.zh-TW.md)。公開origin為VirginBear/HeiBan，本批不推private遠端，不改公開Release或既有tag。

文件提交ecdfb106ccab374fa35ae063801baaba3779bd0f已push到origin/main；ls-remote核對完整SHA一致，範圍只有21份Markdown／JSON，git diff --cached --check退出0，提交後工作區乾淨。本段為遠端確認後的追加紀錄，另提交同步。沒有產品進版、重建或新候選發布。
