# 2026-10-12 — runFullTrust 送審說明與核對紀錄

## 開工與目的

使用者詢問 Partner Center「為什麼需要 runFullTrust，以及如何在產品中使用」必填欄位。本批提供可貼入的說明，核對目前 Windows manifest 與 Microsoft 官方文件；不修改權限、程式、版本或套件，不代表提交或核准。

公開開工git status只既存.vscode/；私人乾淨且origin／gh isPrivate=true核同。先讀開發索引及Windows目前狀態、架構、問題與平台規則。私人僅保存精簡需求及公開索引，不公開帳戶或新增產品身分。

## 可直接貼入的英文說明

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
