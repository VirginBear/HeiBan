# Mac 截圖修正 — 2026-10-09

版本：1.0.5（20261009.4）。範圍僅 macOS。

## 原因與觀察

- 原本 BoardEngine 直接執行 `/usr/sbin/screencapture`，忽略 Process 啟動錯誤，也將非零結束碼與檔案缺失一律顯示為「已取消截圖」。使用者無法分辨取消與權限失敗。
- 舊 App 僅有 linker 產生的 ad-hoc 簽章，簽章識別為 `HeiBanMac`，Info.plist 未綁定，designated requirement 是每次編譯都會改變的 cdhash。設定裡開啟的舊授權可能不適用於目前二進位。
- 本機實際操作觀察：系統螢幕選取能正常出現，但選取後直接使用 SCScreenshotManager 仍收到 `com.apple.ScreenCaptureKit.SCStreamErrorDomain / -3801`。因此系統選取流程改由選取授權的 SCStream 取得第一個完整影格。

## 實作

- 新增 PlatformScreenCaptureService：由 Mac adapter 管理系統選取、擷取、框選及錯誤；BoardEngine 僅接收圖片／取消／失敗結果。
- 廣泛螢幕錄製權限有效時，以 SCScreenshotManager 擷取滑鼠所在顯示器；權限缺失或已失效時改用 SCContentSharingPicker，讓使用者明確選擇這次擷取的螢幕。
- 系統選取使用 SCStream，僅處理第一個完整畫面，停止擷取後顯示凍結畫面的區域框選。沒有音訊、錄影檔或持續背景擷取。
- 支援 Retina 像素尺寸，框選可往任意方向拖曳；Esc／右鍵取消，過小的選區可重新框選。
- 新的截圖直接以 PNG 資料置入原作品，不依賴剪貼簿或暫存檔。等待時若作品／頁面已切換，不置入其他作品。
- 禁止同時啟動多個截圖工作；串流等待逾時、系統選取失敗與擷取失敗都有診斷訊息，並提供權限設定入口。
- 封裝後簽署完整 App，以 `com.bear.HeiBan` 為識別並檢查簽章。開發機目前沒有有效 Apple 簽章憑證，預設仍是 ad-hoc；**不宣稱 ad-hoc 能讓廣泛 TCC 授權跨每次編譯保持有效**。可設定 `HEIBAN_SIGNING_IDENTITY` 使用正式憑證；系統選取路徑不依賴舊的廣泛授權。

## 交付檢視

- Release 編譯與 App 封裝、完整簽章檢查成功。
- 原生操作確認：工具列截圖能呼叫系統螢幕選取；選取內建 Retina 顯示器後取得實際畫面並顯示區域框選提示，Esc 可回到原畫布。最終封裝亦完成框選→PNG 置入→確認圖片內容與方向→復原移除的操作，沒有新增示範作品。
- 取得畫面後即停止串流，且在系統選取完成後延遲 0.5 秒啟動擷取，減少選取列關閉動畫被納入影像的情況。
- 未執行測試套件；未在其他 macOS 版本或實體多螢幕上執行操作檢視。

## 使用方式

點工具列「相機」或右上「＋ → 截圖置入…」。若出現系統的螢幕共享選取，選擇這次要截圖的螢幕，再拖曳框選區域；完成後回到黑板。

## 參考

- [Apple：SCContentSharingPicker](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker)
- [Apple：What’s new in ScreenCaptureKit](https://developer.apple.com/videos/play/wwdc2023/10136/)
- [Apple DTS：開發版 ad-hoc 簽章與螢幕錄製授權失效](https://developer.apple.com/forums/thread/819406)
