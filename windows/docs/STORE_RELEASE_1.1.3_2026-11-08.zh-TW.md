# Windows 1.1.3 Microsoft Store 封裝 — 2026-11-08

使用者明確要求預設圖示為彩色，並打包 1.1.3 上傳微軟商城。本批准予產品 1.1.3／套件 1.1.3.0 與必要檢查、x64＋ARM64 正式合併套件。沿用正式 SelfContained 封裝路徑。框架相依候選的安裝與升級尚未驗收。

已讀開發索引及 Windows 狀態／架構／決策／問題紀錄。開工既有三份未提交清理文件及三份 YouTube 草稿已記錄。預設改為 duotone，還原預設與缺少或未知風格的偏好也使用彩色。使用者已保存的 classic 選擇仍視為明確偏好。正式包與版本資料將逐步核對。
## 封裝前實際檢查

- 使用工作區 SDK 執行 Core.Tests Release，獨立 core-build 產物目錄，6,850 項通過。
- OptimizationChecks Release 使用獨立 optimization-build 及 optimization-output，68 項通過。
- Build-LocalizationCatalogs.py 十語 716 鍵、缺漏 0。Build-UserGuides.py 十語各 26 章 80 段。
- QA Release x64 獨立 qa-build 建置成功，0 警告、0 錯誤，39.25 秒。使用不存在的 qa-data，執行 --cursor-cane-validation-output。原生游標與藤條 516、主幾何／尺 18、主色盤／尺寸 42、螢幕 69，合計 645 項。新增斷言確認新設定與 ToolIcons 都以 duotone 啟動，0.5 秒門檻也核對成功。
- msbuild 的 PreventValidationStoreBuild 在 HeiBanStoreBuild=true 與 HeiBanValidationBuild=true 時回傳明確拒絕訊息。封裝保護守衛通過。
- 初始擷取 70 份既有正式 Store 檔案 SHA，排除會更新的最新指標 STORE_ARTIFACTS.json。版本報告與已交付包另存保留。
- 產品、FileVersion、AssemblyVersion、StoreIdentity、AppxManifest 已一致更新。原生驗證採隔離資料，正常關閉 QA。
- 十語「此版本的新增功能」和既有 runFullTrust 說明已整理於 STORE_LISTING_UPDATE_1.1.3_2026-11-08.zh-TW.md。說明涵蓋正式 1.1.2 之後的工具列、畫筆、尺規與筆色管理調整。
