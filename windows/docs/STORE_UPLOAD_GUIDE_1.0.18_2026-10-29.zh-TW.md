# 1.0.18.0 商店提交資料

## 上傳套件

完成封裝後，Partner Center上傳`windows/dist/store/HeiBan-Store-1.0.18.0-x64-arm64.msixbundle`一份，內含x64與ARM64。此為Store提交包，不是本機自行簽章安裝包。實際SHA及完成證據以同日STORE_RELEASE／STORE_INSPECTION為準。

## 此版本的新增功能

依語言貼上[十語文案](STORE_WHATS_NEW_1.0.18_2026-10-29.md)。原應用程式說明、功能清單可沿用；本次未修改現行隱私權原則文字。

## runFullTrust 理由（精簡英文，可貼入受限功能欄）

HeiBan is a WinUI 3 desktop whiteboard packaged as MSIX. runFullTrust is needed to run the desktop app, save works locally, import/export user-selected files, and display a transparent screen-annotation window. The app runs at normal user privileges and does not install services or drivers.

## 提交狀態

助手只準備套件及資料，未上傳／送審／發布；由使用者在Partner Center確認版本1.0.18.0及既有產品資訊後接續提交。不要把封裝完成當成Microsoft通過認證。
