# Windows 1.1.0 本機試用交付 — 2026-11-01

使用者要求先實際試用確認，再自行上傳商城。先前提供的是未簽章Store提交包，不能代替免安裝試用程式；本批補打包正常Release x64 Portable，維持1.1.0，不再進版、不上傳商店、不搬動／覆寫原作品及舊包。

開工git status只有既有三份YouTube未追蹤文件，保留。來源75f96f7（相對正式成品來源fa40be9僅增加Windows發行文件），產品程式與商店包保持原樣。新包使用空白獨立Data，可匯入作品副本試用；不交付含驗證hook的.build QA程式。封裝／核對結果待追加。

## 完成交付

命令：PATH前置windows/.build/tools/dotnet後，執行`windows/HeiBan.Windows/Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label review-1.1.0-2026-11-01-r1`。正常Release publish與ZIP封裝成功；證據`.build/portable-trial-5a7058d48b134e3e978397fe1c45b59e`。初次核對誤用Path.with_suffix處理含版本點號的資料夾名，指向不存在的ZIP；改為完整名稱追加.zip後核對通過，非成品毀損。

- 直接啟動：`windows/dist/trials/HeiBan-Windows-Portable-1.1.0-review-1.1.0-2026-11-01-r1-win-x64/HeiBan.exe`。
- ZIP：`windows/dist/trials/HeiBan-Windows-Portable-1.1.0-review-1.1.0-2026-11-01-r1-win-x64.zip`。
- ZIP 133302959bytes，SHA256 `324ceb24ca6f5ae9c08769f1365558438b65050f4ab6cc96cf26c048fd3f3864`。
- ZIP CRC、653 payload SHA及228來源SHA核對通過；含63SVG，未編入原生診斷hook。PE版本1.1.0.0／來源75f96f7。獨立Data為空，未搬移使用者作品；第一次啟動會依正常流程建立操作指南。
- 既有1.1.0.0商店bundle SHA仍為a7799085a7ccb5f7f0a23b37d0b12425a9def99ff366d8fa13686ee01eaade66。未進版／改產品程式／刪舊包／上傳商店。本批未啟動App或重跑上一批Core／Native測試；由使用者實際試用，確認後再自行提交商城。

## 建議試用與成功標準

先正常關閉舊版，開啟上列EXE；作品匯入副本即可。

| 操作 | 成功標準 |
| --- | --- |
| 一般與螢幕畫布開更多 | 圖示輪廓清楚、辨識正確，無缺線／不規則填色 |
| 畫折線、重疊筆畫、兩種擦除 | 筆跡跟手，擦除無明顯停頓；放開再插入不恢復已擦筆跡 |
| 螢幕工具列自訂→套用，再回一般畫布 | 即時刷新；一般圖釘／視角鎖定與常用設定保持 |
| 尺邊起筆與遠處起筆、四邊停靠 | 尺邊整筆不跳脫；遠處自由畫；重掛無錯誤或遺失按鈕 |
| 計算機／計時器插入後Undo | 插入與先前擦除分別撤銷；浮動視窗可收合及關閉 |
| 正常關閉再重開 | 試用作品、色盤及設定保留在此資料夾的Data |
