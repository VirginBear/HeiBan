# 公開預覽的已知限制

更新：2026-10-13（Mac）。版本：Mac 1.0.13、Windows 1.0.12-preview.5。以下為現況，不把計畫或核心原型當成正式功能。

| 範圍 | 現況 |
| --- | --- |
| Mac 下載 | ARM64、macOS 14+；未提供 Intel／Universal，未完成 Developer ID／Apple 公證 |
| Windows 下載 | ARM64／x64、安裝／免安裝；未做 Authenticode 簽章；x64 與安裝升級的完整實機流程未驗收 |
| 全功能一致性 | 平台功能仍有差距，跨平台文件中的物件可能尚無對應 UI |
| Google／同步 | 原生登入、雲端與協作未正式啟用；不提供公開 Web 服務 |
| PDF／SVG | Mac／Windows 支援PDF／SVG匯出；外部 PDF 插入註記、自匯 PDF 恢復、完整 SVG 匯入編輯未交付 |
| Mac 螢幕畫布 | 已接一般畫布共用工具列與互動元件；跨 App 真正落筆、PNG 合成、多螢幕、特殊全螢幕仍待驗收；約 1% 透明 backing |
| Windows 螢幕畫布／雷射 | 已提供；右鍵物件調整／複製／刪除，空白右鍵不切模式；Ctrl+Alt+D 明確切穿透。原生ARM64驗證通過，CUA點擊未可靠反映狀態，完整實機仍待驗收 |
| 手寫硬體 | Windows 取樣筆壓，但尚未完整接可變粗細；手掌誤觸與裝置延遲未驗收 |
| 大型作品 | 內嵌圖片 JSON、解析／部分匯出仍可能同步；沒有固定 FPS／延遲保證 |
| 主題與偏好 | Mac 部分偏好／主題仍待完整驗收；自動保存開關與頻率已接排程 |

細節：[Mac 狀態](../macos/docs/development/CURRENT_STATUS.zh-TW.md)、[Mac 排錯紀錄](../macos/docs/development/ISSUE_HISTORY.zh-TW.md)、[Windows 狀態](../windows/docs/CURRENT_STATUS.zh-TW.md)。
