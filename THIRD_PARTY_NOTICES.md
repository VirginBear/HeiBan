# 第三方聲明與授權資料

更新：2026-10-09。GPL-3.0-only 適用於 HeiBan 原創程式；第三方程式、系統框架及建置工具仍依原作者的授權條款。不得把它們的作者標成 HeiBan。

## 原生 Mac

Swift／SwiftUI／AppKit／CoreGraphics／ImageIO／ScreenCaptureKit／WebKit 來自 Apple 工具鏈或系統框架；Mac 套件沒有額外 SwiftPM 外部套件。這些元件不被重新標為 GPL。

## 原生 Windows 公開包

`HeiBan.Windows.csproj` 明列 Windows App SDK 2.5.1、Win2D 1.4.0、Windows SDK BuildTools 10.0.26100.8249。自包含包另含 .NET runtime 與 SDK 的傳遞相依套件。公開包內附 `third-party/` 與 `WINDOWS-DEPENDENCIES.json`，記錄實際 Portable `HeiBan.deps.json` 的版本；原生 DLL 的原有版本／著作權資訊保留。

- [.NET runtime 授權](docs/third-party/DOTNET-LICENSE.txt)及[第三方 notices](docs/third-party/DOTNET-NOTICES.txt)，來源 [dotnet/runtime](https://github.com/dotnet/runtime)。
- Windows App SDK 的 [GitHub 來源授權](docs/third-party/WINDOWS-APP-SDK-LICENSE.txt)與實際 NuGet [發行套件條款](docs/third-party/Microsoft.WindowsAppSDK-2.5.1-license.txt)不同；公開包保留精確套件條款，不能僅憑來源 MIT 宣稱全部 runtime 是 MIT。
- [Win2D 授權](docs/third-party/WIN2D-LICENSE.txt)，來源 [microsoft/Win2D](https://github.com/microsoft/Win2D)。
- Inno Setup 產生安裝程式；[授權原文](docs/third-party/INNO-SETUP-LICENSE.txt)，來源 [jrsoftware.org](https://jrsoftware.org/files/is/license.txt)。商用編譯器使用條款與套件內 license metadata 仍需按實際工具版本確認。
- Inno Setup 繁體中文訊息檔保留原翻譯者 credit；詳見 [Windows notices](windows/docs/THIRD_PARTY_NOTICES.md)，公開安裝 ZIP 亦附相同譯文與聲明。
- WebView2、Windows AI／MachineLearning 等相依套件依其 NuGet 所列授權，公開包附精確版本 nupkg 的 license／third-party notice 原文及 [相依版本清單](docs/third-party/WINDOWS-DEPENDENCIES.json)。沒有將 Microsoft redistributable 元件改授權為 GPL。

Win2D 1.4.0 的舊 NuGet licenseUrl 已轉址到無關教學頁，保留其 metadata 並附官方原始庫授權，不把轉址頁冒稱授權。

上述原文於發行整理時從官方來源取得；不能用此摘要取代原文、正式發行的完整依賴稽核或每個服務的使用條款。

## Web 原型

依賴宣告與精確鎖定見 `package.json`／`pnpm-lock.yaml`；包含 React、Vite、Firebase SDK、Lucide、Motion、jsPDF 等。這次不發佈 Web 二進位／線上服務，若另行部署或分發，應保留其套件授權與 notices。

## 品牌與參考

黑板 Logo 使用本專案選定的生成品牌素材，Mac／Windows 各自保留副本。斜向圖釘以本專案向量幾何繪製。

Excalidraw Desktop 與 ProDrafts 用於互動／設計參考；本專案不隨包分發它們的完整軟體、用戶手冊或第三方截圖。`參考/` 被 Git 排除。名稱與原軟體的權利屬其各自擁有者，沒有聲稱它們參與或認可黑板。
