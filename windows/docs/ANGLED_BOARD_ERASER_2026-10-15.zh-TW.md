# 斜角白色板擦 — 2026-10-15

## 開工
- 基準08fb332，git status --short無輸出，保留前批來源／紀錄。Windows限定，沿用1.0.14開發候選。
- 使用者提供白色塑膠握柄、深色分層擦面的斜視角板擦參考；要求外觀與擦除角度一致。
- 原板擦素材水平木質，擦除及綠框均為132×40軸向矩形。新素材以透明背景生成；依實際擦面投影設定凸四邊形，畫面點轉世界點，不以正矩形或包圍框代替。
- 先讀開發入口、Windows規則／狀態／架構／問題／決策，建立本日誌後實作。測試未執行；本批將建置、封裝供使用者試用，不自行正式進版或提交Store。
## 進行中
- 內建imagegen依參考生成透明白色塑膠／深色分層板擦，替換同一Assets/BoardEraser.png，1254×1254 RGBA、alpha0–255、1,282,591 bytes（較前圖2,532,061 bytes小）。原圖片留Git歷史，不額外綑綁舊板擦。
- 依底層felt長邊約逆時針29度及短邊投影校準四角UV：(0.043,0.665)、(0.742,0.276)、(0.969,0.533)、(0.270,0.922)。後角由可見擦面平行邊延伸；透明留白不當擦除區。
- 新EraserFootprint半平面線段裁切與局部筆跡分段，原矩形API共用此演算法，避免另存一套擦除規則。world遠離原點時，以局部差值計算面積方向，避免大座標相消。
- UI使用144×144完整透明圖，綠色輪廓與實際擦除共用四角。拖曳保留抓取位置，不把握柄／接觸點強行置於滑鼠中心；透明角落不啟動擦除。每8DIP重疊取樣、一筆Undo／取消草稿契約保留。
- 使用者進行中再次明確要求原創生成、符合黑板風格；第一張依照片造型生成的圖不採用。已改用不附任何參考圖片的全新生成，紙白外殼＋霧綠握柄＋深灰felt，依最終圖重新校準接觸輪廓。兩張都經imagegen產生，但不以照片相似版本作最終成品。
## 最終原創素材與校準（覆寫中途方案）
- 最終圖生成時未附參考圖片，從文字描述創作紙白外殼、霧綠膠質握柄／底線、深灰雙層felt，採圓角現代文具造型，避免複製商用板擦的凸點塑膠設計。舊照片及中途相似圖不進專案。
- 圖檔1536×1024 RGBA、1,767,126 bytes，alpha0–254。外圍即使RGB帶灰值，其alpha為0，Runtime透明合成不會畫背景；沒有用腳本改圖。僅從alpha>=128讀出17點抓取輪廓，忽略透明角落。
- 最終顯示160×106.666667 DIP，比例與圖相同。依最終felt長邊約逆時針20度校準圓角斜擦面18點；取代第一張白塑膠圖的29度／四角方案。綠色擦除輪廓、實際裁切及縮放換算共用這18點，不套用舊矩形尺寸。每5DIP重疊取樣。
- 中途build r1成功0warning0error（56.91秒），屬使用者風格覆寫前的來源，不當最終素材驗收。最終build／封裝結果後續追加。
## 最終生成提示（內建 imagegen、未附任何照片）
Use case: product-mockup. Create a BRAND NEW ORIGINAL UI asset for HeiBan, an elegant Windows whiteboard app with a warm paper-white and muted sage-green visual identity. One custom-designed physical blackboard eraser, ivory white rounded molded shell, a large smooth recessed muted sage-green soft-touch grip insert in a long pill shape, a thin sage green seam around the base, and two thick dark charcoal felt layers underneath. This is an original friendly modern stationery design, not a replica of a commercial product. Do not use a field of bumps, ribbed plastic, wood, lettering, labels, or any logo. Restrained semi-realistic 3D product illustration, refined rounded proportions, soft matte surfaces, readable at 144 pixels. Show it obliquely in three-quarter top view, long axis tilted upward to the right by about 25 degrees, with the felt underside's bottom contact footprint clearly following the oblique perspective. Center the complete single object with comfortable balanced transparent padding, no cropped corners. GENUINE TRANSPARENT background with clean alpha, no background color, no checkerboard, no floor, no scene, no cast shadow beyond the object, no other objects. The overall feeling should be calm, cohesive, well-crafted paper-white and botanical sage-green, matching a polished minimal drawing app.

## 命令與驗收邊界
- git status開工乾淨；兩庫fetch後HEAD...origin/main均0/0，私人isPrivate=true。
- rg查RectangularEraser／EraseRectangle／舊尺寸引用後才收整，舊API仍委派共用凸裁切；未刪既有文檔或用戶作品。
- python Build-UserGuides.py：10語25章62段，退出0；git diff --check退出0（僅換行轉換提醒）。讀PNG的Pillow操作只有尺寸／alpha／數值輪廓分析，沒有裁切、去背、轉色或重繪圖檔。
- 半平面邊法向量每個接觸面預算一次，筆跡逐線段命中不重做平方根；實際性能未量測。
- 本批自動化測試／App／實機擦拭／Undo／DPI驗收未執行；後續交由使用者試用。正式版號與Store不動。
- 封裝前發現本批進行期間另有不屬此任務的未追蹤文件產生，被廣域git add誤納；尚未push，已僅移出索引並修正本批自有未推commit，原檔保留為未追蹤、不讀內容、不刪除。後續只stage明確本批路徑。首包記到修正前來源，不當最終交付，改新label重新封裝，保留如實來源證據。
- 成品靜態檢視第一次在封裝ZIP尚未完成、artifact.json未產生時執行，FileNotFoundError即停止，沒有讀取半成品或假定成功；等封裝完成再重跑同一檢視。這是操作時序，不是App執行失敗。

## 最終交付
- 最終來源509c4bbfa2f4cb0e9d4bfadc987676d38074e7b6；Package-PortableTrial.ps1 -Runtime win-x64 -Label eraser-2026-10-15-r2退出0，App及Updater publish完成，無warning／error輸出。原創素材160×106.67DIP、斜圓角18點，原矩形API委派共用半平面裁切。
- ZIP 133752265bytes，SHA256 653c7885d6edf823cb4c528ca048857ac14b7bd8ca89bfa3734787a18d31e5d7。CRC、573payload／162source逐SHA、App／helper x64、十語手冊與透明PNG核同；ZIP無Data檔。靜態檢視在等待artifact產生後重跑成功；清理JSON也曾過早複製、未存在即停止，等清理命令完成後才正式複製，不捏造完成狀態。
- 最新canvas-ui資料27檔／24341106bytes已在未運行、目的空Data、無reparse情況逐SHA接續。使用者在前批交付後的修改保留，不沿用之前24372320bytes當本批數字；不列作品名稱或內容。
- Clear-ObsoleteTrials -KeepTrial HeiBan-Windows-Portable-1.0.14-eraser-2026-10-15-r2-win-x64退出0；先保全Data，再清canvas-ui及未交付eraser-r1。釋放916077320bytes，保留24341106bytes於dist/trial-data-backups/20261015-142945-46188019；Store1.0.12前後SHA相同。舊備份及正式產物保留。
- 本批沒有執行自動化測試、最終App啟動／實機擦拭、Undo或混合DPI驗收。保持1.0.14開發候選，無Store／Release／正式進版。
- 本批進行中產生的其他任務未追蹤文件完整保留，最終只提交本批明確路徑；跨平台程式與資源未改。
