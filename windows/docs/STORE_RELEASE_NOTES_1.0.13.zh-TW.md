# Microsoft Store 更新候選 1.0.13.0

> 2026-10-12進版政策更正：此包為未核准正式進版的開發候選，以下文案／步驟僅保留準備歷史。完成整批開發、測試與驗證並由使用者決定正式進版後，再建立正式提交包；目前不建議依本文件立即上傳。詳[進版規則](RELEASE_POLICY_2026-10-12.zh-TW.md)。

日期：2026-10-12。產品版1.0.13；此文件是待提交素材，不是新版認證或發布紀錄。

## 此版本的新增功能（可貼入正體中文清單）

- 新增十種介面語言，可在首頁選擇，預設正體中文，重新開啟後沿用設定。
- 改善作品開啟與多選、畫布背景、形狀控制點、箭頭樣式、圖釘配色、便條紙及屬性面板操作。
- 加入獨立物件圖層面板與拖曳位置預覽；螢幕畫布提供物件圖層、調色盤與橡皮擦範圍提示，工具列依可用空間排列。
- 整理作品與螢幕畫布共用介面，減少繪圖時儲存狀態圖示的重複建立。

## 上傳步驟

1. 在HeiBan產品overview選「開始更新」，建立此次更新提交。
2. 在「套件」上傳本機 `windows/dist/store/HeiBan-Store-1.0.13.0-x64-arm64.msixbundle`。不用重新保留產品名稱，也不是直接更新GitHub Release即可更新Store。
3. 核對套件版本1.0.13.0、x64／ARM64、原產品身分，等套件驗證完成。原1.0.12.0送審／上架包在本機仍保留。
4. 查看目前每個「Store清單」的完成狀態；原正體中文頁加入以上新增功能，描述亦可提十語。至少需要一個完成的清單語言；若新增其他清單語言，完成其內容或移除未準備的清單。套件支援語言與商店介紹語言不同。
5. 核對免費、Availability市場／可發現性、年齡分級、runFullTrust說明與發布時間等既有設定，再由使用者提交認證。是否需要重填，以此次Partner Center驗證提示為準。

商店上傳包尚未自行簽章，供既有Store提交流程使用，不是一般雙擊旁載安裝包。新版仍須經認證／發布；既有使用者是否自動更新，依Store更新設定與裝置狀態。

## 來源與驗收範圍

來源commit與產物SHA記於本批[日誌](STORE_UPDATE_TOOLBAR_2026-10-12.zh-TW.md)及最終產物報告。建置／封裝靜態驗證不是滑鼠、觸控筆、混合DPI、RTL／母語、Store安裝或WACK驗收；本批未執行這些操作。

官方參考：[MSIX套件上傳](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/upload-app-packages)、[套件版本](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/package-version-numbering)、[商店清單語言](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/add-and-edit-store-listing-info)。本批已查閱官方資料，不保證Partner Center個別帳號畫面與必填提示完全相同。
