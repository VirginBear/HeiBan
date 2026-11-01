# Windows 最新開發狀態與上架前改善建議 — 2026-11-01

## 開工／範圍

使用者要求確認最新開發狀況，有缺失則撰寫改善建議，無問題再準備Microsoft Store發布。本輪先唯讀審視Windows程式、近期變更、候選包及驗收證據；不調版、不修改產品程式、不送審、不啟動App／實機測試。既有三份YouTube未追蹤文件保留。

審查基準以開工git HEAD及實際候選來源核對；先建立日誌，再記錄發現、命令與限制。過去62項／新紀錄2365及65項不視為本輪已執行結果。

## 進行中

已讀根開發入口、Windows規則、目前狀態／架構／問題／日誌。自上一份交付後又有輪盤、螢幕尺、計算機／計時器、自訂工具列及撤銷釘子／方向控制等改動，應審視9e8babb實際來源，不能只依10/31試用結果判斷可上架。既有graphify關聯圖僅輔助定位，新增功能以現行來源為準。

## 審查進行紀錄（歷史）

- 最新程式基準9e8babb，10/31交付後49個Windows檔案又新增約3348行、移除280行；最新Store候選為store-1.0.18-20261101-r1。fetch後本機較origin/main領先8個提交，尚須同步開發紀錄。
- 已確認：ScreenCustomizeToolbarWindow把allKeys限定螢幕工具後，ApplyChanges整份替換共用VisibleTools／HiddenTools／CommonTools；正常畫布專用pins／viewLock因此失去原可見／常用選擇。主視窗SaveToolbarPreferencesAsync確實把同一組設定寫回全域並重建正常工具列，不是只在螢幕過濾。
- 已確認：螢幕OnPointerCore對畫筆每個輸入樣本都LatchRuler；該函式每次清空_snapEdge再命中；一般畫布則起筆時鎖定投影。螢幕同一筆可能在吸附／自由路徑反覆跳動，待隔離算法探針記錄。
- 待交易探針核對：新螢幕計算機／計時器插入直接Begin/Add/Commit，沒有等待IsFinishing擦除。圓擦完成採Generation/Epoch檢查，合法插入可令先前已放開的擦除失配而被略過。
- 新浮動視窗Handle未納入RememberExternalFocus排除條件；自訂工具列onSaved吞錯後回傳成功，儲存按鈕仍關窗；screenTimerTick未在StopAsync／Dispose停止。以上按現行來源記錄，未聲稱GUI重播。
- 五份新增UI來源掃描發現11處、10個唯一T字串未列Sources.json，含收折、自訂工具列、尺規與圓規；T實作會回退正體中文。宣告表missing0不代表所有新UI都完整本地化。
- 本輪只編寫隔離探針與報告；產品程式未修改，來源／舊套件／作品保留。既有關聯圖不是新增功能完整圖。

## 使用者後續指示

使用者已明確核准1.1.0並要求完整修正、改善更多圖示及封裝。先前本輪只審查的範圍擴展為修正與交付，後續實作／驗證見STORE_RELEASE_1.1.0_2026-11-01.zh-TW.md。

## 結案與改善建議

本次確認的三項P1及輔助缺口已隨1.1.0修復；額外抓到的隱藏工具列重掛亦修正。實際結果與失敗證據見1.1.0發行紀錄。原生17斷言、1次GPU局部／全幅比對及63圖示解析／繪製通過，不等於所有使用者情境無缺陷。

後續改善：①分不同GPU／4K與高DPI量測游標到筆跡延遲及大文件擦除p50/p95；②把兩host剩餘指令對映逐批共用，每批驗證座標／交易邊界，避免一次重寫；③FD候選須在乾淨裝置驗證相依安裝，再決定是否改正式通道；④十語母語校閱、螢幕閱讀器及多DPI視窗移動驗收。這些不宣稱本輪已做。x64展開約251.5MB，主程式約2.50MB，主要體積為SDK／.NET／圖形執行階段，不能把刪C#行數等同下載減重。

MSIX上傳不要求自行付費簽署，Store會重新簽署；參考[官方套件要求](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)。WACK尚未執行；[官方驗證工具說明](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-app-certification-kit)。最終Store認證由Microsoft執行，本輪未代送審。

1.1.0最終成品已完成，390來源與37歷史套件SHA核對通過。新的x64展開251.61MB，六個主程式／資源檔含resources.pri合計4.74MB（約1.9%）；上文2.50MB為舊候選不同檔案集合，不可當作前後程式增長量。正式SHA與限制以發行紀錄為準。
