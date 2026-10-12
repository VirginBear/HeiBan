# Mac 介面語言

Mac runtime 只讀 `Sources/HeiBanMac/Resources/Localization/<code>.json`，由 Package.swift 獨立封裝，不讀 Windows 目錄、DLL 或網路翻譯服務。十種語言與本機偏好在 `Localization/L10n.swift`；缺字串回退來源正體中文。

初始詞庫沿用同一 HeiBan 專案 Windows 來源，Mac 特有詞句另外維護：

- `Aliases.json`：明確等義的 Mac 名稱到既有名稱對照。不可為了檢查通過，把不同功能當同義詞。
- `MacTranslations.json`：Mac 特有翻譯及語意修正，優先於 alias。變更需同步各 bundled JSON。
- `scripts/check_localization.py`：核對已接線的固定 `L10n.t("...")` 是否在十個詞庫內；不等於語意或全部動態字串的驗收。

視圖訂閱低頻 L10n 變更，不使用 `.id(language)` 重建引擎／文字編輯器。作品文字、名稱、文件值、工具 ID 與座標不翻譯。Arabic 只在作品庫及設定採右至左排版，畫布世界座標和工具方向保持一致。

目前已接首頁、設定、主工具列、螢幕工具列、屬性、文字右鍵與輔助工具的主要固定控制。部分動態計數／狀態／錯誤、樣式預設名稱、完整工具說明與離線手冊仍為正體中文；十語母語校對、長字串、RTL 與輸入法仍待驗收，不把詞庫項數視為已全部翻譯。

新增詞句流程：確認來源語意 → 接 L10n → 補十語 JSON／必要的手工對照 → 檢查資源 → 實际操作切換與窄版排版。不能以英文 fallback 取代其餘語言，再宣稱完整支援。
