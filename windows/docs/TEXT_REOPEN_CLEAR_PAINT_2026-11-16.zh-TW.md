# Windows 1.1.5 文字格式重開、清除確認與油漆筆刷圖示

依使用者回報處理三項 Windows 問題。開工已核對平台文件，保留三份修改與三份未追蹤文件。先用隔離資料檢查原生 RichEditBox 重開時的格式。

## 問題與修正

基準 WinUI Release 診斷重開已保存的多行文字，待編輯器載入後原本 Consolas、27 pt、黃色標記變成預設字型、18 pt、無標記。原生控制項載入時重新套用外觀，蓋掉過早恢復的局部樣式。改在 Loaded 後排程到 UI 執行緒，等模板與整框外觀完成再還原文件樣式。離開尚未完成載入的編輯器時維持原資料。此輪沿用既有文件格式與編輯分頁。

兩種畫布共用中央 ContentDialog，取消為預設。螢幕畫布暫時把既有壓克力工具列視窗擴至螢幕工作區，關閉後回到原停靠，避開窄視窗裁切。彩色油漆筆刷沿用鋼筆與螢光筆的動態色彩角色，保留原圖示風格設定。

十語手冊重新生成，Core.Tests Release 共 6,903 項通過。首次基準重現及修後結果保留於 windows/.build/text-reopen-20261116。

首輪修後原生測試已通過螢幕文字重開，但取消中央對話框後的工具列尺寸斷言失敗。改為保存並恢復確切的停靠矩形，測試等待對話框完成關閉動畫後再核對。

最終 Release x64 診斷建置 0 警告、0 錯誤。使用新隔離資料根與 --release-validation-output／--release-validation-exit，qa-fixed-r2 回報 success=true。一般與螢幕畫布重開局部文字格式皆通過；螢幕 26 項包含清除確認窗三選項、視窗恢復及取消不改文件。54 項筆刷檢查涵蓋 XAML、SVG 及色彩更新不重建圖形。人工滑鼠、IME、ARM64 與商店安裝未執行。

Windows x64 Release 免安裝封裝成功。執行 Package-PortableTrial.ps1 -Runtime win-x64 -Label text-reopen-2026-11-16-r1，來源 c5a163d。已驗 ZIP CRC 和 724 份程式產物的 SHA-256。試用 ZIP 為 100,548,587 bytes，SHA-256 24fce89815082f324e843f8bc7b7ec3c4d5db10a813bfc28595a5df50f0926d5，位置 `windows/dist/trials/HeiBan-Windows-Portable-1.1.5-text-reopen-2026-11-16-r1-win-x64.zip`。試用資料獨立，原生診斷已另執行，未做人工 GUI／輸入法驗收、商店封裝或上架。
