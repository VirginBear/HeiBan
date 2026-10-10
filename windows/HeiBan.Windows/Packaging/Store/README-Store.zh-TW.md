# HeiBan 黑板 — Microsoft Store 封裝

本包為原生 Windows 桌面應用程式；以 Microsoft Store 套件身分安裝。商店版不執行 GitHub 程式更新，由 Microsoft Store 提供更新。

作品保存在使用者資料位置，不能寫入唯讀的 WindowsApps 安裝目錄。第一次從 EXE／Portable 轉用商店版前，請先在舊版匯出並備份作品；不要假設兩種安裝方式自動共用作品庫。移除／重設商店 App 前，請先備份作品，套件管理可能移除其私人資料。

PDF 匯出需要 Microsoft Edge WebView2 Runtime。程式無需管理員權限；螢幕註記、全域快捷鍵與使用者主動區域截圖由桌面程式執行。商店顯示的完整信任桌面權限不等於要求管理員提升權限。

GPL-3.0-only、限定 Windows SDK 例外及第三方授權在 Licenses 目錄。對應原始碼與開發紀錄：https://github.com/VirginBear/HeiBan 。

未簽章的 MSIX／MSIX bundle 是商店送審用產物；不是讓一般使用者直接側載的安裝包。正式版本以 Microsoft Store 簽章及發布結果為準。
