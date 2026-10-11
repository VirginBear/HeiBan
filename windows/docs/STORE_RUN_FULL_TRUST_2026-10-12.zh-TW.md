# 2026-10-12 — runFullTrust 送審說明與核對紀錄

## 開工與目的

使用者詢問 Partner Center「為什麼需要 runFullTrust，以及如何在產品中使用」必填欄位。本批提供可貼入的說明，核對目前 Windows manifest 與 Microsoft 官方文件；不修改權限、程式、版本或套件，不代表提交或核准。

公開開工git status只既存.vscode/；私人乾淨且origin／gh isPrivate=true核同。先讀開發索引及Windows目前狀態、架構、問題與平台規則。私人僅保存精簡需求及公開索引，不公開帳戶或新增產品身分。

## 短版英文說明（325字元，優先使用）

使用者回報前版文字在欄位中截斷，改提供下列325個ASCII字元的單段版本（含空格與標點、不含外側換行）。這是針對使用者實際回報縮短，未取得後台maxlength，不把500字元當作已查證的官方限制。

HeiBan is a WinUI 3 desktop whiteboard app packaged as MSIX. runFullTrust is required to run HeiBan.exe at mediumIL, manage local work files, and support a transparent desktop annotation overlay, global hotkeys and user-initiated screenshots. It runs with normal user permissions and does not require administrator elevation.

## 原長版說明（保留為背景資料）

HeiBan is a Windows desktop whiteboard and note-taking application built with WinUI 3 / Windows App SDK and packaged as MSIX. The package contains HeiBan.exe, declared as Windows.FullTrustApplication with packagedClassicApp runtime behavior and mediumIL trust level. The runFullTrust capability is required to launch and run this desktop application in its intended execution model.

The application uses desktop APIs to manage its local work library, import and export files selected by the user, and provide a transparent screen annotation window over the desktop and other applications. Desktop window management and global keyboard shortcuts support this annotation feature. Region screenshots are initiated by the user for insertion into a work or export of annotations.

HeiBan runs under the current user's normal permissions and does not require administrator elevation. The annotation window can be closed by the user. The Microsoft Store build disables the GitHub application updater and receives application updates through Microsoft Store. We request runFullTrust for these desktop application features.

## 核對依據

- `HeiBan.Windows/Packaging/Store/Package.appxmanifest`：EntryPoint Windows.FullTrustApplication、RuntimeBehavior packagedClassicApp、TrustLevel mediumIL；Capabilities僅runFullTrust。
- `HeiBan.Windows/app.manifest`：未宣告requestedExecutionLevel；執行模式以Store manifest的mediumIL為依據。螢幕視窗NativeOverlayWindow有SetWindowPos、RegisterHotKey等桌面API，前批MSIX文件已有用途說明。
- [Microsoft官方能力文件](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/app-capability-declarations)：mediumIL桌面應用需宣告runFullTrust；管理員提升使用另外的allowElevation能力。此核對支持保留目前宣告，不保證商店核准。

## 命令、結果與困難

Get-Content／rg檢視manifest、架構與既有MSIX文件；未執行App或測試。rg首次使用包含ScreenAnnotation*的字面路徑，Windows回os error123；改成實際ScreenAnnotation目錄。官方舊UWP文件指向共享Windows文件，另一個desktop-to-uwp-prepare網址回工具Internal Error；改讀共享官方文件的mediumIL與Full Trust條目。

初稿曾把原生manifest描述為asInvoker；讀取實際檔案發現沒有該欄位，在提交前更正為未宣告requestedExecutionLevel，依Store mediumIL說明正常使用者權限，未改manifest。

本批新增本文件，並更新Windows CURRENT_STATUS／DEVELOPMENT_LOG與私人精簡交接。無新架構或程式問題，DECISIONS／ISSUE_HISTORY不變。未執行App、tests、build、封裝、安裝、Partner Center填寫／提交／發布；沒有新核准證據。公開与私人文件各自提交／push，遠端核對結果以當次工具輸出為準。

## 短版補充工作紀錄

開始：公開status只原.vscode/，私人乾淨、visibility=true。使用者回報文字太長並提供IARC通知；本批縮短表單文案，信件原件及分級交接保存在獨立私人庫。已讀開發索引及Windows狀態／架構／問題紀錄。PowerShell字串Length確認短文325字元；舊長文不刪，標為背景資料以保留歷史。不改程式、版本、套件或商店狀態，未執行App／tests／build／後台填寫／提交；私人信件不能當作本次更新的認證證據。實際保存／Git同步結果於本次工具輸出及私人日誌記錄。
