# HeiBan 開發紀錄入口

更新：2026-10-09。歷史計畫、實作與驗收是三種不同狀態。

## 目前工作平台：macOS

- [維護文件總覽](../macos/docs/development/README.zh-TW.md)
- [目前開發狀態與待辦](../macos/docs/development/CURRENT_STATUS.zh-TW.md)
- [實際程式架構與維護邊界](../macos/docs/development/ARCHITECTURE.zh-TW.md)
- [開發日誌](../macos/docs/development/DEVELOPMENT_LOG.zh-TW.md)
- [困難、錯誤與排解紀錄](../macos/docs/development/ISSUE_HISTORY.zh-TW.md)
- [架構決策](../macos/docs/development/DECISIONS.zh-TW.md)
- [本次程式整理稽核](../macos/docs/development/CODE_REVIEW_2026-10-09.zh-TW.md)
- [使用手冊](../macos/docs/USER_GUIDE.zh-TW.html)

## 其他平台與共用文件

- [Windows 文件](../windows/README.md)、[Windows 架構](../windows/docs/ARCHITECTURE.zh-TW.md)：公開整理只補文件與附授權的下載包，不改 Windows 功能；功能狀態仍以平台文件為準。
- [跨平台文件契約](DOCUMENT_SCHEMA_CONTRACT.md)、[平台決策](PLATFORM_DECISIONS.zh-TW.md)。
- [早期整體稽核](PROJECT_AUDIT.zh-TW.md)、[原開發計畫](DEVELOPMENT_PLAN.zh-TW.md)、[原工作清單](WORK_BACKLOG.zh-TW.md)：保留歷史；當前 Mac 狀態以平台 CURRENT_STATUS 為準。

## 固定維護方式

每批工作開始建立日誌，遇到問題即追加調查過程，交付前更新目前狀態與證據。根目錄 `AGENTS.md` 已記錄這些規則。紀錄隨程式保存在 Git 工作區；是否已同步須核對遠端 commit，不能僅憑檔案存在判定。公開整理紀錄見 [發行稽核](PUBLIC_RELEASE_2026-10-09.zh-TW.md)。
