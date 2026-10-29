# 藤條單次取樣與45°／75°姿態 — 2026-10-29

## 開工

使用者提供本機MP3，指定30～33秒中選一次完整揮擊聲放入程式；常駐角度45°、揮動75°回45°，保留彈性回彈。僅Windows，起點80604f5；已讀索引、平台狀態／架構／問題與規則，git status記錄。保留既有三文件6／8／4行及YouTube三檔；沿用1.0.17，不進Store、不覆寫舊包。音檔分析與剪輯為本批明確需求；不啟動App或未授權自動測試。

## 分析中

先以本機ffprobe／ffmpeg讀取及解碼30～33秒，依波形、能量包絡及頻譜定位單次揮擊，保留起音與自然尾音，避免包含兩次。原MP3不改寫、不上傳整份參考檔。替換音效需同步來源紀錄：此批是使用者提供之取樣，不得沿用「原創合成」描述。持續沿用既有預載播放／備援。

角度以畫面水平線計，素材本身已有傾角，必須補償原始素材方向再設定45°休止；揮動增量+30°到75°，保持右下握點及回彈。一般／螢幕畫布與右下快捷圖應共用姿態定義，不重新生成或修改PNG。

## 波形定位與取樣結果

原檔47.612521秒、MP3 320353bps、48kHz雙聲道，metadata只有encoder，沒有license資訊。原檔不改寫／不納入Git，作者歸屬只依檔名記77音效，不把截取音效誤標成原創合成。

30～33秒的5ms RMS包絡發現完整事件31.070～31.205（峰31.095）、32.035～32.170（峰32.065），32.970後第三事件在33秒邊界不完整。取第二個完整事件，原檔31.990～32.250，共0.260秒。左右聲道相關0.99999905，故混單聲道不改主要聲音；保持48kHz PCM16，12480frames／25004bytes。峰值歸一到0.82（+9.7114dB）、僅頭2ms尾10ms淡化，無變速／變調／EQ；峰位75.729ms、最高5ms RMS在75ms，與動畫75ms接觸點對齊，兩端樣本0，沒有把旁邊第二聲一起帶入。

用ffmpeg showwavespic產生並查看參考波形；最初matplotlib未安裝，改用既有ffmpeg，沒有安裝套件；一次view_image查找未生成的圖失敗，後續已看見ffmpeg波形。頻譜採FFT短時攻擊段能量分析，非人耳試聽。音訊識別／剪輯屬本次明確需求；未播放至裝置、未啟動App，不把聲音分析當成App驗收。

`Extract-CaneSample.py --input <reference>`可重建截取素材及CaneSnap.source.json（原檔SHA／來源秒數／處理），完整MP3留在原位置；CaneSample-NOTICE.txt隨包記來源。原Generate-CaneSound.py保留歷史用途，但預設改寫.build/cane-synth/CaneSnapSynthesized.wav，避免重建歷史合成音覆蓋本次選定樣本。

## 角度與來源實作

CanePose統一45°休止／75°揚起／75ms接觸及8°小幅回彈；原升降時間35ms／75ms／260ms保留。素材本身約30°，先按tip(.05,.07)／grip(.92,.90)及bitmap寬高求補償角度，再加揮動增量；不更動PNG。兩畫布共用同一renderer，右下快捷ImageOpened亦用同一姿態計算、保留素材原比例。缺圖向量回退也休止45°。所有狀態只在暫態工具，不改作品schema或Undo。

初次x64 Release build50.75秒、0warning0error；十語手冊同步45°／75°及單次取樣。後續正式來源freeze後再Portable publish。未執行自動測試／App／WACK／性能；沿用1.0.17，無Store作業、無清理。

本次攻擊段功率頻譜重心約1176Hz；來源語意仍依使用者指定的揮擊取樣，不宣稱已人耳聽辨。

## 封裝與交付

x64 `cane-sample-2026-10-29-r1` 已完成，來源 `1a909a0f212c5f3adbf4c4ee567e749554f6b7ab`；ZIP 133164432bytes／SHA256 `9e71a2487ad98b0e7ae4a1260ff5c4181aee52cb06e47c929ae14d9fff1064fa`。590 payload／207 source SHA及592 archive CRC核同，兩EXE x64；取樣WAV與來源metadata／notice在包內且SHA一致，完整MP3不在包內、原參考檔SHA未變。PNG原圖SHA不變；Data使用者檔=0、獨立作品庫，51份Store檔SHA不變。未執行App／實機播放／自動測試／性能採樣。 [產物紀錄](CANE_SAMPLE_ARTIFACT_2026-10-29.json)。

`Package-PortableTrial.ps1 -Runtime win-x64 -Label cane-sample-2026-10-29-r1` 成功，最終publish紀錄`windows/.build/portable-trial-2702dc3df2e64f00ad062180c99ef19d/publish.log`。`python windows/.build/cane-sample-20261029-r1/inspect_delivery.py` 完成來源／payload／ZIP SHA與CRC、x64PE、PNG alpha／IHDR、WAV PCM header、source metadata／notice及原MP3未變的核對。這些是音訊分析／剪輯與封裝靜態檢查，非App實機驗收。

變更檔案：Core CanePose；MainWindow.Cane／XAML快捷角度、共用Direct2DCanvasRenderer.Cane；CaneSnap.wav及source JSON／notice；Extract-CaneSample.py及歷史Generate-CaneSound.py防覆寫；Portable來源指紋；九語手冊來源與十語輸出、平台紀錄。沒有更動PNG／作品schema／其他平台程式；沒有清理、進版、Store打包／上傳或發布。未執行App、自動測試、ARM64、WACK、性能與裝置試聽；待使用者實機確認音量／延遲與45°／75°視覺感受。

原三文件6／8／4行、YouTube三檔、使用者作品、參考MP3及所有舊試用／Store保持原樣。公開來源／紀錄與私人壓縮交接分開commit／push；PRIVATE及遠端HEAD核對，受保護產品欄位deep-equal，無憑證、整段參考音檔、使用者作品內容或外部排程。
