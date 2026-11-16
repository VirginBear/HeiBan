# Windows 1.1.5 文字編輯分頁、箭頭粗度與清除選單

依使用者截圖與回饋整理 Windows 畫布的文字編輯介面。開工核對平台文件，保留三份既有修改與三份未追蹤文件。同步調整實心箭頭粗度與清除本頁入口。

## 實作與核對進度

一般畫布用同一文字草稿取代該物件的已提交景象，隱藏選取框及浮動列，暫收起屬性。螢幕畫布的 GPU 疊加無法承載 XAML／IME，只有無框原位文字輸入仍使用原生視窗；格式列放入既有螢幕工具列。畫布點擊先提交文字並返回原工具。保留版號與文件格式。

實心箭頭調整主粗度時同步縮放頭部，進階可獨立指定尾桿長度、頭部寬度及長度，端點維持。舊空心箭頭沿用原屬性。兩畫布的清除選單共用 UI 和清除交易。多頁筆記的「全部」只處理當頁物件，共用物件與其他頁保留。

十語目錄與手冊生成成功。Core.Tests Release 共 6,903 項通過，含新比例、舊箭頭相容與本頁全清 Undo 檢查。工作區 git diff --check 通過。

Windows x64 Release 診斷組態建置 0 警告、0 錯誤。以獨立資料根執行 --release-validation-output 與 --release-validation-exit，qa-result/release110-result.json 回報成功。一般畫布檢查原位輸入、工具列分頁、屬性及浮動列隱藏、格式保存、工具列恢復；螢幕畫布檢查編輯器是原位視窗唯一控制項、暫時工具列及合成點畫布提交。21 項既有螢幕檢查及原生文字驗證通過。人工鼠標、IME、多螢幕、ARM64 與商店認證未執行。

Windows x64 Release 免安裝封裝成功。執行 Package-PortableTrial.ps1 -Runtime win-x64 -Label editing-toolbar-2026-11-16-r1，來源 52d14fe。已驗 ZIP CRC 和 724 份程式產物的 SHA-256。試用 ZIP 為 100,545,765 bytes，SHA-256 31d4a06ec9f1366384b55a294c40debfeb5e0bc76ae66202c1889234118e883b，位置 `windows/dist/trials/HeiBan-Windows-Portable-1.1.5-editing-toolbar-2026-11-16-r1-win-x64.zip`。試用資料獨立，原生診斷已另執行，未做人工 GUI／輸入法驗收、商店封裝或上架。
