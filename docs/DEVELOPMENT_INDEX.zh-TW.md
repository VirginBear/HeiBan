# HeiBan 開發紀錄入口

更新：2026-10-13。歷史計畫、實作與驗收是三種不同狀態。

## Mac維護與目前交付

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

- [Windows版本減重分析計劃報告書](../windows/docs/WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)。
- [Store／Portable基準數據](../windows/docs/PACKAGE_SIZE_BASELINE_2026-10-13.json)與[文件同步交接](../windows/docs/SIZE_PLAN_HANDOFF_2026-10-13.zh-TW.md)。
- 方案尚未實作，版本政策不變；Windows原機成品／作品／工具不隨Git同步。

## 其他平台與共用文件

- [Windows 文件](../windows/README.md)、[Windows 架構](../windows/docs/ARCHITECTURE.zh-TW.md)：Windows獨立功能與封裝進度以[目前狀態](../windows/docs/CURRENT_STATUS.zh-TW.md)為準；GitHub下載與相應來源依平台版本更新。
- [跨平台文件契約](DOCUMENT_SCHEMA_CONTRACT.md)、[平台決策](PLATFORM_DECISIONS.zh-TW.md)。
- [早期整體稽核](PROJECT_AUDIT.zh-TW.md)、[原開發計畫](DEVELOPMENT_PLAN.zh-TW.md)、[原工作清單](WORK_BACKLOG.zh-TW.md)：保留歷史；當前 Mac 狀態以平台 CURRENT_STATUS 為準。

## 固定維護方式

每批工作開始建立日誌，遇到問題即追加調查過程，交付前更新目前狀態與證據。根目錄 `AGENTS.md` 已記錄這些規則。紀錄隨程式保存在 Git 工作區；是否已同步須核對遠端 commit，不能僅憑檔案存在判定。公開整理紀錄見 [發行稽核](PUBLIC_RELEASE_2026-10-09.zh-TW.md)。
