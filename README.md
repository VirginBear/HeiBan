# HeiBan (黑板)

高效能向量黑板／白板協作系統，專為流暢書寫、精確幾何工具、無限畫布與多頁筆記本設計。

---

## 平台與架構

* **macOS 原生應用程式 (`macos/`)**：基於 Swift / SwiftUI 與原生 Metal 硬體加速渲染，支援極致低延遲 120 FPS 筆跡、Apple Silicon 原生架構、本機原子保存與資料保全。
* **Web 端應用程式 (`src/`)**：基於 React 19、TypeScript 與 Vite，支援無縫跨平台瀏覽、獨立離線 HTML 匯出檢視與即時協作。
* **文件契約 (`docs/DOCUMENT_SCHEMA_CONTRACT.md`)**：跨平台統一版本化 JSON 檔案格式（`schemaVersion: 1.0.0`），具備幾何容差保證與雙向無損未知欄位保護。

---

## 開發環境與工具鏈需求

### Web 端
* **Node.js**：`>= 20.0.0`
* **套件管理器**：**pnpm**（正式鎖定來源：`pnpm-lock.yaml`，版本 `11.22.0`）

```bash
# 安裝依賴
pnpm install

# 啟動本機開發伺服器 (http://localhost:3000)
pnpm run dev

# 執行跨平台契約檢驗 (TypeScript Contract Test Runner)
pnpm run check

# 產生正式發行打包檔案
pnpm run build
```

### macOS 原生端
* **作業系統**：macOS 14.0 (Sonoma) 或更新版本
* **編譯工具**：Xcode 15+ / Swift 5.9+

```bash
# 切換至 macOS 專案目錄
cd macos

# 編譯原生核心與 App
swift build

# 執行原生核心測試套件 (HeiBanTestRunner)
swift run HeiBanTestRunner

# 執行正式發行打包腳本 (產出 dist/HeiBan.app)
./scripts/build_app.sh
```

---

## 核心功能特色

1. **極致低延遲筆跡**：預覽筆跡點緩存架構、封存路徑批次繪製、120 FPS 原生流暢度。
2. **多頁筆記本與畫布格式**：
   * 無邊界黑板 (Infinite)
   * 固定尺寸 (A4, A3, B5, 16:9, 4:3, 1:1, 9:16)
   * 多頁筆記本 (支援多頁增刪、封面風格、格子／橫線／五線譜／點點內頁、底色與自訂格線深淺顏色)
3. **精確工具與量角尺規**：虛擬直尺、雙向角度旋轉、中點與樞軸拖曳、落筆與橡皮擦半透明範圍預覽。
4. **廣泛匯出與資料保全**：
   * 獨立離線互動網頁檔 (`.html`)：任何瀏覽器免安裝軟體即可離線檢視並內嵌備份資料。
   * 向量 PDF / SVG、高品質 PNG、原生 `.heiban` 備份。
   * 本機冷安裝與 Application Support 隔離儲存，保護使用者資料安全。

---

## 文件導覽

* [Antigravity 工作清單](docs/ANTIGRAVITY_WORKLIST.zh-TW.md)
* [專案架構與冗餘稽核](docs/PROJECT_AUDIT.zh-TW.md)
* [開發目標與階段計畫](docs/DEVELOPMENT_PLAN.zh-TW.md)
* [驗收標準 (A01–A31)](docs/ACCEPTANCE_CRITERIA.zh-TW.md)
* [跨平台架構決策 (ADR)](docs/PLATFORM_DECISIONS.zh-TW.md)
* [文件契約規範](docs/DOCUMENT_SCHEMA_CONTRACT.md)
