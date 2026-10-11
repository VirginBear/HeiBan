# Windows 文件增補與相容邊界（2026-10-11）

## 圖釘配色

`board.pins[]` 新增可選 `color` 與 `textColor` 字串，使用既有 `#RRGGBB`／`#RRGGBBAA` 色彩契約；缺值分別使用 `#39B9DC`／`#397056`，不回寫預設。舊作品不用遷移，schemaVersion 維持原值。Windows JSON extension data 仍保留其他未知欄位；typed snapshot 複製兩個不可變字串與獨立 ExtraFields，Undo／Redo／匯出仍保存資料。

Mac 當前 `BoardPin` 的 Codable 尚未宣告這兩欄，也未保留 pin 未知欄位。這次只修改 Windows，因此 Mac 可開啟作品，但以既有 Mac 版本重新儲存可能丟失圖釘配色。需要跨 Mac 往返保色時，先保留 Windows 原作；Mac 配色契約尚未實裝，不能宣稱跨平台無損支援此增補。

## 箭頭

沿用既有 `arrowHeadLength`／`arrowHeadWidth`，不新增物件欄位。缺值現在採 16／10 世界單位，頭部輪廓為連續 2 世界單位，主線粗細／虛線不修改頭部。native renderer、SVG、hit、window selection 的尺寸預設同步。較早 Windows 缺值箭頭曾以 `strokeWidth * 4` 放大，所以舊缺值箭頭的外觀會改變；明確設定的頭部尺寸保留。

## 停筆直線

未完成筆畫／停筆錨點／吸附旗標不序列化。放開才新增既有 `line` 類型與兩端座標；沿用原 stroke color／width／opacity／dash／brush，一次 undo。取消不新增物件。

## 偏好

`Settings/teaching.json` 增加 `rulerLengthPercent`（20–150，預設 90）與 `inspectorDock`（top/left/bottom/right，預設 right），是本機 UI 偏好，不是作品格式。未知作品欄位、文字／圖片／頁面與原 Store 套件不受這些偏好影響。

本批未執行往返／Undo／實機測試；上述為已讀來源與實作契約，驗收狀態見本批日誌。
