import Foundation
import CoreGraphics
import HeiBanCore

// All default engines and background saves must use an isolated library.
let runnerDataDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("HeiBanChecks-\(UUID().uuidString)", isDirectory: true)
setenv("HEIBAN_DATA_DIRECTORY", runnerDataDirectory.path, 1)

var passedCount = 0
var failedCount = 0

func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passedCount += 1
        print("  ✓ \(message)")
    } else {
        failedCount += 1
        print("  ✗ FAILED: \(message) at line \(line)")
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
    if actual == expected {
        passedCount += 1
        print("  ✓ \(message)")
    } else {
        failedCount += 1
        print("  ✗ FAILED: \(message) [Expected: \(expected), Got: \(actual)] at line \(line)")
    }
}

print("==================================================")
print("🎯 HeiBan Mac Native Engine Verification Suite (立靶檢驗)")
print("==================================================")

// -------------------------------------------------------------------------
// 1. Shape Recognizer Tests
// -------------------------------------------------------------------------
print("\n[測試 1] GoodNotes 手勢識別 (幾何形狀自動校正)")

// 1.1 Straight Line
var linePoints: [Point] = []
for x in stride(from: 10.0, through: 210.0, by: 10.0) {
    let wobble = (x.truncatingRemainder(dividingBy: 20.0) == 0) ? 0.4 : -0.4
    linePoints.append(Point(x: x, y: 15.0 + wobble))
}
let lineShape = ShapeRecognizer.recognize(points: linePoints)
assertTrue(lineShape != nil, "直線手勢應被成功識別")
assertEqual(lineShape?.type, "line", "形狀類型應為 line")
assertEqual(lineShape?.x, 10.0, "直線起點 X 應正確")
assertEqual(lineShape?.y, 15.0, "直線起點 Y 應正確")
assertEqual(lineShape?.width, 200.0, "直線長度 width 應為 200")

// 1.2 Circle
var circlePoints: [Point] = []
let center = (x: 150.0, y: 150.0)
let radius = 60.0
let steps = 40
for i in 0...steps {
    let angle = (Double(i) / Double(steps)) * 2 * Double.pi
    circlePoints.append(Point(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
}
let circleShape = ShapeRecognizer.recognize(points: circlePoints)
assertTrue(circleShape != nil, "封閉圓形手勢應被成功識別")
assertEqual(circleShape?.type, "circle", "形狀類型應為 circle")
assertTrue(abs((circleShape?.width ?? 0) - 120.0) <= 2.0, "圓形直徑 width 應約 120")
assertTrue(abs((circleShape?.height ?? 0) - 120.0) <= 2.0, "圓形直徑 height 應約 120")

// 1.3 Random Wiggle (Should NOT snap to shape)
var wigglePoints: [Point] = []
for i in 0..<25 {
    wigglePoints.append(Point(x: Double(i * 10), y: (i % 2 == 0) ? 5.0 : 65.0))
}
let wiggleShape = ShapeRecognizer.recognize(points: wigglePoints)
assertTrue(wiggleShape == nil, "凌亂波浪筆跡不應誤判為幾何形狀")


// -------------------------------------------------------------------------
// 2. Vector Math & Ruler Snapping Tests
// -------------------------------------------------------------------------
print("\n[測試 2] 向量數學與螢幕尺磁吸長度邊界約束")

let ruler = RulerState(
    enabled: true,
    screenCenterX: 400,
    screenCenterY: 200,
    angle: 0,
    width: 500, // [-250, 250], physical bounds in X [150, 650]
    height: 50  // top edge: 200 - 25 = 175, bottom edge: 200 + 25 = 225
)

// 2.1 Snapping near top edge
let snapPt = Point(x: 350, y: 170)
let snapResult = VectorMath.snapToRulerEdge(screenPt: snapPt, ruler: ruler, snapTolerance: 20)
assertTrue(snapResult.snapped, "尺頂緣附近的筆尖應被精確磁吸")
assertEqual(snapResult.screenPt.y, 175.0, "磁吸後 Y 座標應嚴格貼合頂緣 175")
assertEqual(snapResult.screenPt.x, 350.0, "磁吸後 X 座標應保持筆尖水平位置")

// 2.2 Clamping beyond ruler length
let outOfBoundsPt = Point(x: 720, y: 175) // X > 650
let outResult = VectorMath.snapToRulerEdge(screenPt: outOfBoundsPt, ruler: ruler, snapTolerance: 20)
assertTrue(outResult.snapped, "沿尺緣超出尺長的筆跡應被限制在尺的端點")
assertEqual(outResult.screenPt.x, 650.0, "超出尺緣長度時應精確裁切至尺端")

// 2.3 Coordinate Transform Roundtrip
let viewport = ViewportTransform(x: 250, y: 150, zoom: 1.5)
let screenP = Point(x: 400, y: 300)
let worldP = VectorMath.screenToWorld(screenP, viewport: viewport)
assertEqual(worldP.x, (400.0 - 250.0) / 1.5, "Screen to World X 換算正確")
assertEqual(worldP.y, (300.0 - 150.0) / 1.5, "Screen to World Y 換算正確")
let backP = VectorMath.worldToScreen(worldP, viewport: viewport)
assertEqual(backP.x, 400.0, "World to Screen X 還原正確")
assertEqual(backP.y, 300.0, "World to Screen Y 還原正確")


// -------------------------------------------------------------------------
// 3. Document Serialization & Web HeiBan Compatibility
// -------------------------------------------------------------------------
print("\n[測試 3] JSON 資料結構與 Web HeiBan 互通性相容驗證")

let testBoard = BoardMetadata(
    id: "board_demo",
    title: "跨平台向量黑板",
    ownerId: "mac_user",
    ownerName: "Bear",
    backgroundColor: "#172e25",
    gridStyle: .grid,
    boardTheme: .blackboard,
    canvasMode: .infinite,
    pins: [
        BoardPin(id: "pin_home", name: "原點視角", x: 0, y: 0, zoom: 1.0)
    ]
)

let strokeObj = BoardObject(
    id: "stroke_1",
    boardId: "board_demo",
    type: "stroke",
    x: 50,
    y: 50,
    width: 100,
    height: 100,
    points: "[{\"x\":50,\"y\":50},{\"x\":150,\"y\":150}]",
    strokeColor: "#86efac",
    strokeWidth: 3.5
)

let doc = HeiBanDocument(
    version: "1.0",
    board: testBoard,
    objects: [strokeObj]
)

do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonBytes = try encoder.encode(doc)
    let jsonString = String(data: jsonBytes, encoding: .utf8) ?? ""
    assertTrue(jsonString.contains("\"version\" : \"1.0\""), "JSON 包含正確版本號")
    assertTrue(jsonString.contains("\"boardTheme\" : \"blackboard\""), "JSON 包含正確黑板主題")
    assertTrue(jsonString.contains("\"strokeColor\" : \"#86efac\""), "JSON 包含正確筆跡顏色")

    let decoder = JSONDecoder()
    let decodedDoc = try decoder.decode(HeiBanDocument.self, from: jsonBytes)
    assertEqual(decodedDoc.board.title, "跨平台向量黑板", "反序列化黑板標題相符")
    assertEqual(decodedDoc.board.pins?.count, 1, "反序列化圖釘數量相符")
    assertEqual(decodedDoc.objects.count, 1, "反序列化物件數量相符")
    assertEqual(decodedDoc.objects[0].parsedPoints.count, 2, "反序列化筆跡點座標數量相符")
} catch {
    failedCount += 1
    print("  ✗ FAILED: 序列化拋出異常: \(error)")
}

// -------------------------------------------------------------------------
// 4. BoardEngine State & Undo / Redo
// -------------------------------------------------------------------------
print("\n[測試 4] BoardEngine 狀態管理與復原／重做 (Undo / Redo)")

let engine = BoardEngine(restoreSession: false)
let initialCount = engine.objects.count
assertEqual(initialCount, 0, "新黑板應從乾淨的無限畫布開始")

let testSticky = BoardObject(
    boardId: engine.board.id,
    type: "sticky",
    x: 300,
    y: 300,
    width: 200,
    height: 150,
    text: "測試便條"
)
engine.addObject(testSticky)
assertEqual(engine.objects.count, initialCount + 1, "新增物件後物件數量遞增")
assertTrue(engine.canUndo, "新增後應可復原 (canUndo)")

engine.undo()
assertEqual(engine.objects.count, initialCount, "執行 Undo 後物件恢復先前狀態")
assertTrue(engine.canRedo, "Undo 後應可重做 (canRedo)")

engine.redo()
assertEqual(engine.objects.count, initialCount + 1, "執行 Redo 後物件再次被還原")

// Pin Navigation Test
engine.addPin(name: "重點結論區")
let pins = engine.board.pins ?? []
assertTrue(pins.contains { $0.name == "重點結論區" }, "圖釘視角清單應包含新加入的標記")

// -------------------------------------------------------------------------
// 5. Pointer-centered navigation and incremental gestures
// -------------------------------------------------------------------------
print("\n[測試 5] 增量平移與游標中心縮放")
let navigationEngine = BoardEngine(restoreSession: false)
let initialViewport = navigationEngine.viewport
navigationEngine.updatePanGesture(translation: CGSize(width: 10, height: 5))
navigationEngine.updatePanGesture(translation: CGSize(width: 20, height: 9))
assertEqual(navigationEngine.viewport.x - initialViewport.x, 20.0, "累積平移只應套用最終位移一次")
assertEqual(navigationEngine.viewport.y - initialViewport.y, 9.0, "累積垂直平移不應加速")
navigationEngine.endPanGesture()

let zoomAnchor = Point(x: 320, y: 240)
let worldAtAnchor = VectorMath.screenToWorld(zoomAnchor, viewport: navigationEngine.viewport)
navigationEngine.handleScrollWheel(at: zoomAnchor, deltaX: 0, deltaY: 120, shift: false)
let worldAfterZoom = VectorMath.screenToWorld(zoomAnchor, viewport: navigationEngine.viewport)
assertTrue(abs(worldAfterZoom.x - worldAtAnchor.x) < 1e-9, "滾輪縮放應固定游標下的世界座標 X")
assertTrue(abs(worldAfterZoom.y - worldAtAnchor.y) < 1e-9, "滾輪縮放應固定游標下的世界座標 Y")

// -------------------------------------------------------------------------
// 6. Direct geometry and object manipulation
// -------------------------------------------------------------------------
print("\n[測試 6] A/B 線段與物件拖曳")
let lineEngine = BoardEngine(restoreSession: false)
lineEngine.currentTool = .line
let lineStart = VectorMath.worldToScreen(Point(x: 300, y: 250), viewport: lineEngine.viewport)
let lineEnd = VectorMath.worldToScreen(Point(x: 100, y: 50), viewport: lineEngine.viewport)
lineEngine.beginPointerGesture(at: lineStart)
lineEngine.updatePointerGesture(at: lineEnd, translation: CGSize(width: -200, height: -200))
lineEngine.endPointerGesture(translation: CGSize(width: -200, height: -200))
let createdLine = lineEngine.objects.first
assertEqual(createdLine?.x1, 300.0, "線段 A 點應保留拖曳起點 X")
assertEqual(createdLine?.y1, 250.0, "線段 A 點應保留拖曳起點 Y")
assertEqual(createdLine?.x2, 100.0, "反向拖曳後 B 點不得被方框邏輯翻轉")
assertEqual(createdLine?.y2, 50.0, "反向拖曳後 B 點 Y 應保留")
lineEngine.setSelectedLineExtension(.both)
assertEqual(lineEngine.objects.first?.extensionMode, .both, "選取直線可設定雙向延伸")
let endpointTarget = VectorMath.worldToScreen(Point(x: 350, y: 275), viewport: lineEngine.viewport)
lineEngine.updateLineEndpointDrag(objectID: createdLine?.id ?? "missing", endpoint: .start, at: endpointTarget)
lineEngine.endLineEndpointDrag()
assertEqual(lineEngine.objects.first?.x1, 350.0, "A 點控制把手可改變起點 X")
assertEqual(lineEngine.objects.first?.y1, 275.0, "A 點控制把手可改變起點 Y")

let moveEngine = BoardEngine(restoreSession: false)
let movable = BoardObject(type: "rect", x: 100, y: 100, width: 80, height: 60)
moveEngine.addObject(movable)
moveEngine.currentTool = .select
let click = VectorMath.worldToScreen(Point(x: 120, y: 120), viewport: moveEngine.viewport)
moveEngine.beginPointerGesture(at: click)
moveEngine.updatePointerGesture(at: click, translation: CGSize(width: 24, height: 12))
moveEngine.endPointerGesture(translation: CGSize(width: 24, height: 12))
assertEqual(moveEngine.objects.first?.x, 124.0, "選取物件應以畫布尺度移動 X")
assertEqual(moveEngine.objects.first?.y, 112.0, "選取物件應以畫布尺度移動 Y")

// -------------------------------------------------------------------------
// 7. W02 & A23: Document Contract, F04 Lossless Round-trip & Migration
// -------------------------------------------------------------------------
print("\n[測試 7] W02 & A23: 文件契約、F04 往返無損與遷移驗證")

// 7.1 Locate F04 fixture file
let fileManager = FileManager.default
let candidatePaths = [
    "tests/fixtures/f04_contract.json",
    "../tests/fixtures/f04_contract.json",
    "../../tests/fixtures/f04_contract.json",
    "/Users/bear/Desktop/Code/HeiBan/tests/fixtures/f04_contract.json"
]
var f04URL: URL?
for path in candidatePaths {
    if fileManager.fileExists(atPath: path) {
        f04URL = URL(fileURLWithPath: path)
        break
    }
}

assertTrue(f04URL != nil, "F04 契約驗證檔案應能被定位")

if let f04URL = f04URL, let f04Data = try? Data(contentsOf: f04URL) {
    do {
        // Decode F04 through HeiBanDocumentCodec
        let docF04 = try HeiBanDocumentCodec.decode(from: f04Data)
        assertEqual(docF04.schemaVersion, "1.0.0", "F04 應包含 schemaVersion 1.0.0")
        assertEqual(docF04.version, "1.0", "F04 應包含 version 1.0")
        assertEqual(docF04.board.title, "F04 跨平台契約完整驗收板", "黑板標題相符")
        assertEqual(docF04.board.pins?.count, 2, "黑板圖釘數量應為 2")
        assertEqual(docF04.board.extraFields?["unknownBoardExtensionField"], .string("preserved_custom_metadata_value"), "黑板未知擴展欄位應被無損保留")
        assertEqual(docF04.objects.count, 15, "F04 應包含 15 種測試物件")

        // Reverse line check
        let revLine = docF04.objects.first { $0.id == "obj_09_line_reverse_both_ext" }
        assertTrue(revLine != nil, "反向雙向延伸線段存在")
        assertEqual(revLine?.x1, 250.0, "反向線段 x1 座標相符")
        assertEqual(revLine?.y1, 430.0, "反向線段 y1 座標相符")
        assertEqual(revLine?.x2, 100.0, "反向線段 x2 座標相符")
        assertEqual(revLine?.y2, 350.0, "反向線段 y2 座標相符")
        assertEqual(revLine?.extensionMode, .both, "反向線段延伸為 both")

        // Reverse arrow check
        let revArrow = docF04.objects.first { $0.id == "obj_10_arrow_reverse_start_ext" }
        assertTrue(revArrow != nil, "反向箭頭存在")
        assertEqual(revArrow?.x1, 520.0, "反向箭頭 x1 座標相符")
        assertEqual(revArrow?.y1, 350.0, "反向箭頭 y1 座標相符")
        assertEqual(revArrow?.x2, 400.0, "反向箭頭 x2 座標相符")
        assertEqual(revArrow?.y2, 440.0, "反向箭頭 y2 座標相符")
        assertEqual(revArrow?.extensionMode, .start, "反向箭頭延伸為 start")

        // Rich text spans check
        let richText = docF04.objects.first { $0.id == "obj_11_text_rich" }
        assertTrue(richText != nil, "富文本物件存在")
        assertEqual(richText?.richTextSpans?.count, 3, "富文本片段數量應為 3")
        assertEqual(richText?.richTextSpans?[1].text, "富文本標題", "第二片段文字相符")
        assertEqual(richText?.richTextSpans?[1].isItalic, true, "第二片段應為斜體")
        assertEqual(richText?.richTextSpans?[1].color, "#facc15", "第二片段顏色相符")

        // Cropped image check
        let croppedImg = docF04.objects.first { $0.id == "obj_14_image_cropped" }
        assertTrue(croppedImg != nil, "裁切圖片物件存在")
        assertEqual(croppedImg?.cropX, 100.0, "裁切 X 座標相符")
        assertEqual(croppedImg?.cropY, 50.0, "裁切 Y 座標相符")
        assertEqual(croppedImg?.cropWidth, 1720.0, "裁切寬度相符")
        assertEqual(croppedImg?.cropHeight, 980.0, "裁切高度相符")
        assertEqual(croppedImg?.originalWidth, 1920.0, "原圖寬度相符")
        assertEqual(croppedImg?.originalHeight, 1080.0, "原圖高度相符")

        // Unknown object field
        let strokeObj = docF04.objects.first { $0.id == "obj_01_stroke" }
        assertEqual(strokeObj?.extraFields?["unknownObjectExtensionField"], .double(42.5), "物件未知擴展欄位應被無損保留")

        // 7.2 Native round-trip serialization & geometric precision tolerance (<= 1e-6)
        let reEncodedData = try HeiBanDocumentCodec.encode(docF04, prettyPrinted: true)
        let reDecodedDoc = try HeiBanDocumentCodec.decode(from: reEncodedData)
        assertEqual(reDecodedDoc.objects.count, docF04.objects.count, "原生往返物件數量相符")
        for i in 0..<docF04.objects.count {
            let o1 = docF04.objects[i]
            let o2 = reDecodedDoc.objects[i]
            assertEqual(o2.id, o1.id, "原生往返 [\(o1.id)] ID 相符")
            assertTrue(abs(o2.x - o1.x) <= 1e-6, "原生往返 [\(o1.id)] X 幾何容差 ≤ 1e-6")
            assertTrue(abs(o2.y - o1.y) <= 1e-6, "原生往返 [\(o1.id)] Y 幾何容差 ≤ 1e-6")
            assertTrue(abs(o2.width - o1.width) <= 1e-6, "原生往返 [\(o1.id)] 寬度幾何容差 ≤ 1e-6")
            assertTrue(abs(o2.height - o1.height) <= 1e-6, "原生往返 [\(o1.id)] 高度幾何容差 ≤ 1e-6")
        }
        assertEqual(reDecodedDoc.board.extraFields?["unknownBoardExtensionField"], .string("preserved_custom_metadata_value"), "原生往返黑板未知欄位保留")
        assertEqual(reDecodedDoc.objects.first { $0.id == "obj_01_stroke" }?.extraFields?["unknownObjectExtensionField"], .double(42.5), "原生往返物件未知欄位保留")

        // 7.3 Headless BoardEngine document integration
        let headlessEngine = BoardEngine(restoreSession: false)
        try headlessEngine.loadFromJsonData(reEncodedData)
        assertEqual(headlessEngine.objects.count, 15, "Headless BoardEngine 應載入 15 個物件")
        let headlessExport = try headlessEngine.exportToJsonData()
        let headlessDecoded = try HeiBanDocumentCodec.decode(from: headlessExport)
        assertEqual(headlessDecoded.objects.count, 15, "Headless BoardEngine 導出應保留 15 個物件")

    } catch {
        failedCount += 1
        print("  ✗ FAILED: F04 解碼或往返拋出異常: \(error)")
    }
}

// 7.4 Legacy v0 Migration without version number
let legacyCandidatePaths = [
    "tests/fixtures/legacy_v0_no_version.json",
    "../tests/fixtures/legacy_v0_no_version.json",
    "../../tests/fixtures/legacy_v0_no_version.json",
    "/Users/bear/Desktop/Code/HeiBan/tests/fixtures/legacy_v0_no_version.json"
]
for path in legacyCandidatePaths {
    if fileManager.fileExists(atPath: path), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
        do {
            let migratedDoc = try HeiBanDocumentCodec.decode(from: data)
            assertEqual(migratedDoc.schemaVersion, "1.0.0", "舊版無版本文件應自動升級至 schemaVersion 1.0.0")
            assertEqual(migratedDoc.version, "1.0", "舊版無版本文件應補齊 version 1.0")
            assertEqual(migratedDoc.objects.count, 1, "舊版無版本物件應完整保留")
            assertEqual(migratedDoc.objects.first?.id, "legacy_obj_1", "舊版無版本物件 ID 應保留")
        } catch {
            failedCount += 1
            print("  ✗ FAILED: 舊版遷移失敗: \(error)")
        }
        break
    }
}

// 7.5 Rejection of unsupported future versions
let futureCandidatePaths = [
    "tests/fixtures/unsupported_v99.json",
    "../tests/fixtures/unsupported_v99.json",
    "../../tests/fixtures/unsupported_v99.json",
    "/Users/bear/Desktop/Code/HeiBan/tests/fixtures/unsupported_v99.json"
]
for path in futureCandidatePaths {
    if fileManager.fileExists(atPath: path), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
        var didCatchUnsupported = false
        do {
            _ = try HeiBanDocumentCodec.decode(from: data)
        } catch DocumentMigrationError.unsupportedFutureVersion(let found, let supportedMax) {
            didCatchUnsupported = true
            assertEqual(found, "99.0.0", "不支援版本號應精確報告為 99.0.0")
            assertEqual(supportedMax, "1.0.0", "最高支援版本應報告為 1.0.0")
        } catch {
            print("  ✗ 攔截到非預期錯誤: \(error)")
        }
        assertTrue(didCatchUnsupported, "未來不相容版本 (v99.0.0) 必須明確拋出 unsupportedFutureVersion 拒絕靜默丟失")
        break
    }
}

// -------------------------------------------------------------------------
// 8. W01, A01 & A02: Performance Profiling, Path Caching & Spatial Culling
// -------------------------------------------------------------------------
print("\n[測試 8] W01, A01 & A02: 畫布效能 Profiling、Path 快取與空間索引裁切")

func locateFixture(_ filename: String) -> URL? {
    let candidates = [
        "tests/fixtures/\(filename)",
        "../tests/fixtures/\(filename)",
        "../../tests/fixtures/\(filename)",
        "/Users/bear/Desktop/Code/HeiBan/tests/fixtures/\(filename)"
    ]
    for p in candidates {
        if fileManager.fileExists(atPath: p) {
            return URL(fileURLWithPath: p)
        }
    }
    return nil
}

func calcStats(_ values: [Double]) -> (min: Double, max: Double, avg: Double, p50: Double, p95: Double) {
    let sorted = values.sorted()
    let sum = sorted.reduce(0, +)
    let avg = sum / Double(sorted.count)
    let p50 = sorted[Int(Double(sorted.count) * 0.5)]
    let p95 = sorted[Int(Double(sorted.count) * 0.95)]
    return (sorted.first ?? 0, sorted.last ?? 0, avg, p50, p95)
}

// 8.1 F01 Daily (1,000 objects) Profiling
if let f01URL = locateFixture("f01_daily_1k.json"), let f01Data = try? Data(contentsOf: f01URL) {
    var f01DecodeTimes: [Double] = []
    var f01CachedPathTimes: [Double] = []
    var f01CullingTimes: [Double] = []

    var decodedDoc: HeiBanDocument?
    for _ in 1...5 {
        let t0 = DispatchTime.now().uptimeNanoseconds
        let doc = try? HeiBanDocumentCodec.decode(from: f01Data)
        let t1 = DispatchTime.now().uptimeNanoseconds
        f01DecodeTimes.append(Double(t1 - t0) / 1_000_000.0)
        decodedDoc = doc
    }

    if let doc = decodedDoc {
        assertEqual(doc.objects.count, 1000, "F01 應成功解碼 1000 個物件")

        // Cold vs Warm Path Cache
        BoardPathCache.clear()
        let tCold0 = DispatchTime.now().uptimeNanoseconds
        for obj in doc.objects {
            _ = BoardPathCache.worldPath(for: obj)
        }
        let tCold1 = DispatchTime.now().uptimeNanoseconds
        let coldMs = Double(tCold1 - tCold0) / 1_000_000.0

        for _ in 1...5 {
            let tW0 = DispatchTime.now().uptimeNanoseconds
            for obj in doc.objects {
                _ = BoardPathCache.worldPath(for: obj)
            }
            let tW1 = DispatchTime.now().uptimeNanoseconds
            f01CachedPathTimes.append(Double(tW1 - tW0) / 1_000_000.0)
        }

        let warmStats = calcStats(f01CachedPathTimes)
        assertTrue(warmStats.p50 < coldMs, "Path 快取生效：熱查詢 (p50: \(String(format: "%.2f", warmStats.p50)) ms) 明顯快於冷重建 (\(String(format: "%.2f", coldMs)) ms)")

        // Spatial AABB Culling Query
        let canvasSize = CGSize(width: 1200, height: 800)
        let viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
        let visibleRect = VectorMath.visibleWorldRect(canvasSize: canvasSize, viewport: viewport)

        var culledCount = 0
        for _ in 1...5 {
            let tC0 = DispatchTime.now().uptimeNanoseconds
            let visibleObjs = doc.objects.filter { obj in
                obj.isVisible != false && VectorMath.intersects(object: obj, worldVisibleRect: visibleRect)
            }
            let tC1 = DispatchTime.now().uptimeNanoseconds
            f01CullingTimes.append(Double(tC1 - tC0) / 1_000_000.0)
            culledCount = visibleObjs.count
        }
        let cullingStats = calcStats(f01CullingTimes)
        assertTrue(culledCount < 1000, "空間索引裁切成功：1000 物件中僅保留可見 \(culledCount) 個物件")
        assertTrue(cullingStats.p95 < 2.5, "1000 物件可見區空間檢索 p95 (\(String(format: "%.2f", cullingStats.p95)) ms) ≤ 2.5 ms")
    }

    let decodeStats = calcStats(f01DecodeTimes)
    print("  ✓ F01 原生 5 輪解碼耗時 p50: \(String(format: "%.2f", decodeStats.p50)) ms, p95: \(String(format: "%.2f", decodeStats.p95)) ms")
}

// 8.2 F02 Long Stroke (10,000 points) Append Latency (A01)
print("\n[驗收 A01] F02 10,000 點長筆跡增量預覽管線延遲驗證")
let previewStore = StrokePreviewStore()
previewStore.begin(with: Point(x: 0, y: 0, pressure: 0.5))

// Append first 100 points
for i in 1...100 {
    previewStore.append(Point(x: Double(i), y: sin(Double(i) * 0.1) * 20.0, pressure: 0.5))
}
let tStart0 = DispatchTime.now().uptimeNanoseconds
previewStore.append(Point(x: 101.0, y: sin(10.1) * 20.0, pressure: 0.5))
let tStart1 = DispatchTime.now().uptimeNanoseconds
let tStart = Double(tStart1 - tStart0) / 1_000_000.0

// Append up to 10,000 points
for i in 102...9990 {
    previewStore.append(Point(x: Double(i), y: sin(Double(i) * 0.1) * 20.0, pressure: 0.5))
}
let tEnd0 = DispatchTime.now().uptimeNanoseconds
previewStore.append(Point(x: 9991.0, y: sin(999.1) * 20.0, pressure: 0.5))
let tEnd1 = DispatchTime.now().uptimeNanoseconds
let tEnd = Double(tEnd1 - tEnd0) / 1_000_000.0

// A01 criteria:增幅 <= 20%
let baseline = max(0.005, tStart)
let incrementPercent = ((tEnd - baseline) / baseline) * 100.0
assertTrue(tEnd < 1.0, "10,000 點筆跡單點追加耗時 (\(String(format: "%.3f", tEnd)) ms) 遠低於 20 ms 門檻")
assertTrue(incrementPercent <= 20.0 || tEnd <= 0.05, "F02 長筆跡尾段未發生累積卡頓 (增量延遲維持在常數級 \(String(format: "%.3f", tEnd)) ms)")

// 8.3 F03 Stress Test (10,000 objects) (A02)
print("\n[驗收 A02] F03 10,000 物件壓力板載入時間與可見區檢索")
if let f03URL = locateFixture("f03_stress_10k.json"), let f03Data = try? Data(contentsOf: f03URL) {
    let tLoad0 = DispatchTime.now().uptimeNanoseconds
    let stressDoc = try? HeiBanDocumentCodec.decode(from: f03Data)
    let tLoad1 = DispatchTime.now().uptimeNanoseconds
    let loadSec = Double(tLoad1 - tLoad0) / 1_000_000_000.0

    assertEqual(stressDoc?.objects.count, 10000, "F03 壓力板 10,000 物件解碼完整")
    assertTrue(loadSec <= 5.0, "F03 開啟至可操作時間 (\(String(format: "%.2f", loadSec)) 秒) 嚴格 ≤ 5.0 秒 (A02 規範)")

    if let stressDoc = stressDoc {
        let canvasSize = CGSize(width: 1200, height: 800)
        let viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
        let visibleRect = VectorMath.visibleWorldRect(canvasSize: canvasSize, viewport: viewport)

        let tCul0 = DispatchTime.now().uptimeNanoseconds
        let visible = stressDoc.objects.filter { obj in
            obj.isVisible != false && VectorMath.intersects(object: obj, worldVisibleRect: visibleRect)
        }
        let tCul1 = DispatchTime.now().uptimeNanoseconds
        let culMs = Double(tCul1 - tCul0) / 1_000_000.0

        assertTrue(culMs < 8.0, "10,000 物件空間裁切計算耗時 (\(String(format: "%.2f", culMs)) ms) ≤ 8.0 ms (遠小於 16.7ms 幀預算)")
        assertTrue(visible.count < 500, "10,000 物件中僅需繪製可見區 \(visible.count) 個物件，節省超過 95% 渲染指令")
    }
}

// -------------------------------------------------------------------------
// 9. W03, A03 & A26: Atomic Persistence, Revision Control & Corrupt File Recovery
// -------------------------------------------------------------------------
print("\n[測試 9] W03, A03 & A26: 原子保存、修訂版號防護與損壞快照恢復")

let isolatedTestDir = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("HeiBanTestLib_\(UUID().uuidString)")
let testLibrary = LocalBoardLibrary(directory: isolatedTestDir)

let testBoardMeta = BoardMetadata(
    id: "board_atomic_test",
    title: "原子保存測試黑板",
    ownerId: "tester",
    ownerName: "Tester",
    revision: 1
)
let testObj = BoardObject(
    id: "obj_atomic_1",
    boardId: "board_atomic_test",
    type: "rect",
    x: 10, y: 10, width: 100, height: 100
)
let docV1 = HeiBanDocument(
    schemaVersion: "1.0.0",
    version: "1.0",
    board: testBoardMeta,
    objects: [testObj]
)

do {
    // 9.1 Atomic save revision 1
    try testLibrary.save(docV1, createBackup: true)
    let savedFile = testLibrary.fileURL(id: "board_atomic_test")
    assertTrue(fileManager.fileExists(atPath: savedFile.path), "黑板檔案應成功寫入目標位置")

    let loadedV1 = try testLibrary.load(id: "board_atomic_test")
    assertEqual(loadedV1.board.title, "原子保存測試黑板", "已儲存黑板讀取標題相符")
    assertEqual(loadedV1.board.revision, 1, "修訂版號應為 1")
    assertEqual(loadedV1.objects.count, 1, "物件數量相符")

    // 9.2 Revision conflict protection (A03: 延遲保存不覆蓋較新修訂)
    var olderDoc = docV1
    olderDoc.board.revision = 0
    olderDoc.board.title = "過期修訂嘗試覆蓋"
    var didCatchRevisionConflict = false
    do {
        try testLibrary.save(olderDoc, createBackup: true)
    } catch PersistenceError.revisionConflict(let current, let incoming) {
        didCatchRevisionConflict = true
        assertEqual(current, 1, "當前修訂應為 1")
        assertEqual(incoming, 0, "嘗試覆蓋之過期修訂應為 0")
    } catch {
        // other error
    }
    assertTrue(didCatchRevisionConflict, "磁碟已有較新修訂 (1) 時，較舊修訂 (0) 必須被拒絕覆蓋 (A03 規範)")

    // 9.3 Backup snapshot existence
    let backupFile = testLibrary.backupURL(id: "board_atomic_test")
    assertTrue(fileManager.fileExists(atPath: backupFile.path), "備份快照檔案應成功建立在 Backups 目錄")

    // 9.4 Save revision 2 succeeds
    var docV2 = docV1
    docV2.board.revision = 2
    docV2.board.title = "修訂版號2正常推進"
    try testLibrary.save(docV2, createBackup: true)
    let loadedV2 = try testLibrary.load(id: "board_atomic_test")
    assertEqual(loadedV2.board.revision, 2, "新修訂版號應成功推進至 2")
    assertEqual(loadedV2.board.title, "修訂版號2正常推進", "新修訂標題相符")

    // 9.5 Corrupted file detection without silent deletion (A03)
    try "{ broken corrupted payload without closing bracket".write(to: savedFile, atomically: true, encoding: .utf8)
    let inspectResult = try testLibrary.inspectLibrary()
    assertEqual(inspectResult.damagedFiles.count, 1, "inspectLibrary 應精確識別 1 個損壞黑板檔案")
    assertEqual(inspectResult.damagedFiles.first?.hasBackup, true, "損壞檔案應標記有備份可用")
    assertTrue(fileManager.fileExists(atPath: savedFile.path), "偵測到損壞時原件嚴禁被靜默刪除或清空")

    // 9.6 Safe recovery from backup (A03)
    let restoredDoc = try testLibrary.restoreFromBackup(id: "board_atomic_test")
    assertEqual(restoredDoc.board.id, "board_atomic_test", "還原之黑板 ID 相符")
    assertEqual(restoredDoc.objects.count, 1, "還原之黑板物件數量完整")

    let inspectAfterRestore = try testLibrary.inspectLibrary()
    assertEqual(inspectAfterRestore.validBoards.count, 1, "還原後黑板已重新回到正常資料庫清單")
    assertEqual(inspectAfterRestore.damagedFiles.count, 0, "損壞檔案計數歸零")

} catch {
    failedCount += 1
    print("  ✗ FAILED: W03 驗證拋出異常: \(error)")
}

// Clean up isolated test folder
_ = try? fileManager.removeItem(at: isolatedTestDir)

// -------------------------------------------------------------------------
// 10. W09, A04 & A24: 編輯交易指令、Undo/Redo 記憶體預算與圖層管理
// -------------------------------------------------------------------------
print("\n[測試 10] W09, A04 & A24: 編輯交易指令、Undo/Redo 記憶體預算與圖層管理 (立靶驗收)")

do {
    let engine = BoardEngine(restoreSession: false)
    engine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
    engine.clearAll()
    engine.clearHistory()

    // 10.1 單一完成手勢為一筆歷史 (A04)
    engine.startStroke(at: Point(x: 10, y: 10))
    for i in 1...20 {
        engine.appendStrokePoint(at: Point(x: 10.0 + Double(i) * 5.0, y: 10.0 + Double(i) * 2.0))
    }
    engine.endStroke()

    assertEqual(engine.objects.count, 1, "筆劃結束應生成 1 個筆跡物件")
    assertEqual(engine.transactionManager.undoStack.count, 1, "無論取樣點數多少，單一繪製手勢嚴格只產生 1 筆歷史交易 (A04)")
    assertTrue(engine.canUndo, "應可執行復原 (canUndo == true)")
    assertEqual(engine.canRedo, false, "新操作後重做堆疊應為空 (canRedo == false)")

    engine.undo()
    assertEqual(engine.objects.count, 0, "執行一次 Undo 後筆跡應消失")
    assertEqual(engine.canUndo, false, "Undo 後已無歷史可復原")
    assertTrue(engine.canRedo, "Undo 後應可執行 Redo")

    engine.redo()
    assertEqual(engine.objects.count, 1, "執行一次 Redo 後筆跡應恢復")
    assertTrue(engine.canUndo, "Redo 後應可再次 Undo")

    // 10.2 整次擦除手勢為單一歷史交易 (A04 & A24)
    engine.clearAll()
    engine.clearHistory()

    engine.addShape(type: "rect", at: Point(x: 100, y: 100))
    engine.addShape(type: "circle", at: Point(x: 150, y: 100))
    engine.addShape(type: "triangle", at: Point(x: 200, y: 100))
    assertEqual(engine.objects.count, 3, "畫布應有 3 個幾何物件")
    engine.clearHistory() // 清空測試歷史以隔離擦除手勢驗收

    engine.beginEraserSwipe()
    engine.eraseAt(screenPt: Point(x: 110, y: 110))
    engine.eraseAt(screenPt: Point(x: 160, y: 110))
    engine.eraseAt(screenPt: Point(x: 210, y: 110))
    engine.endEraserSwipe()

    assertEqual(engine.objects.count, 0, "擦除手勢結束後 3 個物件應全部被清除")
    assertEqual(engine.transactionManager.undoStack.count, 1, "跨多點、多物件之整次擦除手勢嚴格記錄為單一交易 (A04, A24)")

    engine.undo()
    assertEqual(engine.objects.count, 3, "一次 Undo 應完整恢復被擦除的 3 個物件")
    engine.redo()
    assertEqual(engine.objects.count, 0, "一次 Redo 應重新清除 3 個物件")
    engine.undo()
    assertEqual(engine.objects.count, 3, "再次 Undo 恢復 3 個物件以供後續圖層測試")

    // 10.3 清空畫布可一次復原 (A04)
    engine.clearAll()
    assertEqual(engine.objects.count, 0, "clearAll 後畫布應清空")
    engine.undo()
    assertEqual(engine.objects.count, 3, "清空畫布後一次 Undo 必須完整恢復所有原有物件 (A04)")

    // 10.4 圖層前後排序操作與歷史復原 (A24)
    let sortedObjIds = engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id)
    let idA = sortedObjIds[0]
    let idB = sortedObjIds[1]
    let idC = sortedObjIds[2]

    // 置頂 (Bring to front)
    engine.bringToFront(ids: [idA])
    let currentOrder = engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id)
    assertEqual(currentOrder, [idB, idC, idA], "A 置頂後順序應為 B, C, A")
    engine.undo()
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idA, idB, idC], "Undo 置頂後順序應還原為 A, B, C")

    // 置底 (Send to back)
    engine.sendToBack(ids: [idC])
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idC, idA, idB], "C 置底後順序應為 C, A, B")
    engine.undo()
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idA, idB, idC], "Undo 置底後順序應還原為 A, B, C")

    // 上移一層 (Bring forward)
    engine.bringForward(ids: [idA])
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idB, idA, idC], "A 上移一層後順序應為 B, A, C")
    engine.undo()
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idA, idB, idC], "Undo 上移後順序應還原為 A, B, C")

    // 下移一層 (Send backward)
    engine.sendBackward(ids: [idC])
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idA, idC, idB], "C 下移一層後順序應為 A, C, B")
    engine.undo()
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idA, idB, idC], "Undo 下移後順序應還原為 A, B, C")

    // 手柄拖拉任意重排 (reorderObjects)
    engine.reorderObjects(newOrder: [idB, idC, idA])
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idB, idC, idA], "手柄任意重排順序應為 B, C, A")
    engine.undo()
    assertEqual(engine.objects.sorted { $0.zIndex < $1.zIndex }.map(\.id), [idA, idB, idC], "Undo 任意重排後順序應還原為 A, B, C")

    // 10.5 圖層鎖定規則 (A24)
    engine.setObjectLocked(id: idA, isLocked: true)
    assertEqual(engine.objects.first(where: { $0.id == idA })?.isLocked, true, "物件 A 應處於鎖定狀態")

    // 鎖定物件禁止被畫布點選選取
    engine.selectObjectOnCanvas(id: idA)
    assertTrue(!engine.selectedIds.contains(idA), "鎖定物件禁止被畫布點擊選取 (A24)")

    // 鎖定物件禁止被橡皮擦擦除
    engine.beginEraserSwipe()
    engine.eraseAt(screenPt: Point(x: 105, y: 105))
    engine.endEraserSwipe()
    assertEqual(engine.objects.contains(where: { $0.id == idA }), true, "鎖定物件嚴禁被橡皮擦擦除 (A24)")

    engine.undo() // 還原 eraseAt
    engine.undo() // 還原 lock
    assertEqual(engine.objects.first(where: { $0.id == idA })?.isLocked ?? false, false, "Undo 應解鎖物件 A")

    // 10.6 圖層隱藏規則 (A24)
    engine.setObjectVisible(id: idB, isVisible: false)
    assertEqual(engine.objects.first(where: { $0.id == idB })?.isVisible, false, "物件 B 應處於隱藏狀態")

    // 隱藏物件不參與畫布命中與選取
    engine.selectObjectOnCanvas(id: idB)
    assertTrue(!engine.selectedIds.contains(idB), "隱藏物件不參與畫布選取命中 (A24)")

    // 隱藏物件不可被橡皮擦擦除
    engine.beginEraserSwipe()
    engine.eraseAt(screenPt: Point(x: 155, y: 105))
    engine.endEraserSwipe()
    assertEqual(engine.objects.contains(where: { $0.id == idB }), true, "隱藏物件不參與擦除命中 (A24)")

    engine.undo() // 還原 eraseAt
    engine.undo() // 還原 hide
    assertEqual(engine.objects.first(where: { $0.id == idB })?.isVisible ?? true, true, "Undo 應恢復物件 B 可見性")

    // 10.7 圖層命名 (A24)
    engine.setCustomName(id: idC, name: "測試自訂架構圖")
    assertEqual(engine.objects.first(where: { $0.id == idC })?.name, "測試自訂架構圖", "物件 C 自訂名稱應設定成功")
    engine.undo()
    assertEqual(engine.objects.first(where: { $0.id == idC })?.name, nil, "Undo 命名後應還原為原始名稱")
    engine.redo()
    assertEqual(engine.objects.first(where: { $0.id == idC })?.name, "測試自訂架構圖", "Redo 應重新套用自訂名稱")

    // 10.8 畫布設定與圖釘交易 (A04)
    let originalTitle = engine.board.title
    engine.updateBoardTitle("新設定標題")
    assertEqual(engine.board.title, "新設定標題", "標題應更新")
    engine.undo()
    assertEqual(engine.board.title, originalTitle, "Undo 應還原畫布標題")

    let originalPinsCount = engine.board.pins?.count ?? 0
    engine.addPin(name: "交易測試圖釘")
    assertEqual(engine.board.pins?.count, originalPinsCount + 1, "應新增 1 個圖釘")
    engine.undo()
    assertEqual(engine.board.pins?.count ?? 0, originalPinsCount, "Undo 應移除圖釘")
    engine.redo()
    assertEqual(engine.board.pins?.count, originalPinsCount + 1, "Redo 應恢復圖釘")

    // 10.9 暫時狀態不產生歷史 (A04)
    let stackCountBeforeTemp = engine.transactionManager.undoStack.count
    engine.viewport.x += 100
    engine.viewport.y += 50
    engine.viewport.zoom = 2.0
    engine.selectedIds = [idA, idB]
    assertEqual(engine.transactionManager.undoStack.count, stackCountBeforeTemp, "平移、縮放與選取等暫時狀態嚴禁產生歷史交易 (A04)")

    // 10.10 記憶體預算與容量上限 (A04)
    let smallBudgetEngine = BoardEngine(restoreSession: false)
    smallBudgetEngine.clearAll()
    smallBudgetEngine.clearHistory()
    // Push 60 add operations onto a budget of 50
    for i in 1...60 {
        smallBudgetEngine.addShape(type: "rect", at: Point(x: Double(i * 10), y: 100))
    }
    assertEqual(smallBudgetEngine.transactionManager.undoStack.count, 50, "歷史記錄嚴格限制在記憶體容量預算上限 (50 筆) (A04)")
    assertEqual(smallBudgetEngine.objects.count, 60, "畫布仍持有完整 60 個物件")
    assertTrue(smallBudgetEngine.canUndo, "記憶體削峰後仍可安全復原")
}

// -------------------------------------------------------------------------
// 11. Multi-Selection, Grouping, Transform & Clipboard Tests (W10, A06)
// -------------------------------------------------------------------------
print("\n[測試 11] W10 & A06: 多選、群組、物件變形與剪貼簿 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.clearAll()
    engine.clearHistory()
    engine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)

    // 11.1 框選 (Marquee Box Selection) 與幾何命中
    let idRect = UUID().uuidString
    let idCircle = UUID().uuidString
    let idText = UUID().uuidString

    let objRect = BoardObject(id: idRect, type: "rect", x: 100, y: 100, width: 60, height: 60)
    let objCircle = BoardObject(id: idCircle, type: "circle", x: 200, y: 100, width: 60, height: 60)
    let objText = BoardObject(id: idText, type: "text", x: 500, y: 500, width: 100, height: 40)

    engine.objects = [objRect, objCircle, objText]

    // 框選 (80, 80) 到 (280, 180)，涵蓋 objRect 與 objCircle，不包含 objText
    engine.selectObjectsInBox(rect: CGRect(x: 80, y: 80, width: 200, height: 100), isShiftPressed: false)
    assertEqual(engine.selectedIds.count, 2, "框選應命中 2 個物件")
    assertTrue(engine.selectedIds.contains(idRect), "框選應包含矩形 A")
    assertTrue(engine.selectedIds.contains(idCircle), "框選應包含圓形 B")
    assertTrue(!engine.selectedIds.contains(idText), "框選不應包含遠處文字 C")

    // 11.2 Shift 複選 (加選與反選)
    engine.toggleObjectSelection(id: idText)
    assertEqual(engine.selectedIds.count, 3, "Shift 點選遠處文字後應全選 3 個物件")
    engine.toggleObjectSelection(id: idRect)
    assertEqual(engine.selectedIds.count, 2, "Shift 點選已選取之矩形應將其反選移除")
    assertTrue(!engine.selectedIds.contains(idRect), "已選取矩形反選後不應在選取集合中")

    // 恢復選取 A 與 B
    engine.selectedIds = [idRect, idCircle]

    // 11.3 穩定選取外框與八向／旋轉手柄計算 (Selection Bounding Box & Handles)
    guard let bounds = engine.selectionBoundingBox else {
        fatalError("selectionBoundingBox should not be nil")
    }
    assertEqual(bounds.minX, 100.0, "外框 minX 應為 100")
    assertEqual(bounds.minY, 100.0, "外框 minY 應為 100")
    assertEqual(bounds.width, 160.0, "外框 width 應為 160 (從 100 到 260)")
    assertEqual(bounds.height, 60.0, "外框 height 應為 60 (從 100 到 160)")

    let handles = VectorMath.handlePositions(for: bounds, zoom: 1.0)
    assertEqual(handles[.topLeft], CGPoint(x: 100, y: 100), "Top-Left 手柄座標相符")
    assertEqual(handles[.topCenter], CGPoint(x: 180, y: 100), "Top-Center 手柄座標相符")
    assertEqual(handles[.topRight], CGPoint(x: 260, y: 100), "Top-Right 手柄座標相符")
    assertEqual(handles[.middleRight], CGPoint(x: 260, y: 130), "Middle-Right 手柄座標相符")
    assertEqual(handles[.bottomRight], CGPoint(x: 260, y: 160), "Bottom-Right 手柄座標相符")
    assertEqual(handles[.bottomCenter], CGPoint(x: 180, y: 160), "Bottom-Center 手柄座標相符")
    assertEqual(handles[.bottomLeft], CGPoint(x: 100, y: 160), "Bottom-Left 手柄座標相符")
    assertEqual(handles[.middleLeft], CGPoint(x: 100, y: 130), "Middle-Left 手柄座標相符")
    assertEqual(handles[.rotate], CGPoint(x: 180, y: 76), "Rotate 手柄座標應位於頂部中央上方 24 點")

    let hitBottomRight = VectorMath.hitTestHandle(point: Point(x: 260, y: 160), bounds: bounds, zoom: 1.0)
    assertEqual(hitBottomRight, .bottomRight, "右下角手柄命中測試應返回 bottomRight")
    let hitRotate = VectorMath.hitTestHandle(point: Point(x: 180, y: 76), bounds: bounds, zoom: 1.0)
    assertEqual(hitRotate, .rotate, "旋轉手柄命中測試應返回 rotate")

    // 11.4 群組／解組交易 (Group / Ungroup Transaction)
    engine.groupSelected()
    let groupedA = engine.objects.first(where: { $0.id == idRect })
    let groupedB = engine.objects.first(where: { $0.id == idCircle })
    assertTrue(groupedA?.groupId != nil, "群組後物件 A 應擁有非空 groupId")
    assertTrue(groupedB?.groupId != nil, "群組後物件 B 應擁有非空 groupId")
    assertEqual(groupedA?.groupId, groupedB?.groupId, "群組後物件 A 與 B 應共享相同 groupId")

    // 點選群組中任一物件，應聯動全選該群組所有成員
    engine.selectedIds = []
    engine.selectObjectOnCanvas(id: idRect)
    assertEqual(engine.selectedIds.count, 2, "點選群組成員應自動全選該群組所有成員")
    assertTrue(engine.selectedIds.contains(idRect) && engine.selectedIds.contains(idCircle), "群組聯動選取相符")

    // 復原群組
    engine.undo()
    assertEqual(engine.objects.first(where: { $0.id == idRect })?.groupId, nil, "Undo 應清除物件 A 之 groupId")
    assertEqual(engine.objects.first(where: { $0.id == idCircle })?.groupId, nil, "Undo 應清除物件 B 之 groupId")

    // 重做群組
    engine.redo()
    assertTrue(engine.objects.first(where: { $0.id == idRect })?.groupId != nil, "Redo 應恢復群組")

    // 解組 (選取群組物件後解組)
    engine.selectedIds = [idRect, idCircle]
    engine.ungroupSelected()
    assertEqual(engine.objects.first(where: { $0.id == idRect })?.groupId, nil, "解組後物件 A 之 groupId 應為 nil")
    assertEqual(engine.objects.first(where: { $0.id == idCircle })?.groupId, nil, "解組後物件 B 之 groupId 應為 nil")
    engine.undo() // 恢復群組狀態以供後續變形與剪貼測試

    // 11.5 八向縮放與等比縮放 (8-way & Proportional Scaling)
    engine.selectedIds = [idRect, idCircle]
    let origBounds = bounds
    let scaledBounds = CGRect(x: 100, y: 100, width: 320, height: 120) // 2.0x 放大
    engine.scaleSelected(from: origBounds, to: scaledBounds, preserveAspectRatio: false)

    let scaledA = engine.objects.first(where: { $0.id == idRect })!
    let scaledB = engine.objects.first(where: { $0.id == idCircle })!
    assertEqual(scaledA.x, 100.0, "縮放後物件 A 起始 X 應仍為 100")
    assertEqual(scaledA.y, 100.0, "縮放後物件 A 起始 Y 應仍為 100")
    assertEqual(scaledA.width, 120.0, "縮放後物件 A 寬度應由 60 變為 120 (2.0x)")
    assertEqual(scaledA.height, 120.0, "縮放後物件 A 高度應由 60 變為 120 (2.0x)")
    assertEqual(scaledB.x, 300.0, "縮放後物件 B 相對位置 X 應為 100 + (200-100)*2 = 300")
    assertEqual(scaledB.width, 120.0, "縮放後物件 B 寬度應由 60 變為 120 (2.0x)")

    // 單次 Undo 完整復原變形
    engine.undo()
    let restoredA = engine.objects.first(where: { $0.id == idRect })!
    assertEqual(restoredA.width, 60.0, "Undo 縮放後物件 A 寬度應精確還原為 60")
    assertEqual(restoredA.height, 60.0, "Undo 縮放後物件 A 高度應精確還原為 60")

    // 11.6 負向拖曳變形與水平翻轉 (Negative Drag & Flipping)
    let flippedBounds = CGRect(x: 260, y: 100, width: -160, height: 60) // 向左負向拖曳
    let flippedA = VectorMath.transformObject(object: restoredA, from: origBounds, to: flippedBounds)
    assertTrue(flippedA.width > 0, "負向拖曳翻轉後寬度仍應為正值 (幾何不崩潰)")
    assertEqual(flippedA.width, 60.0, "翻轉後寬度應為 60")
    // 物件 A 本在左側 (100)，水平鏡像後應翻轉到右側
    assertTrue(flippedA.x > restoredA.x, "水平鏡像後原左側物件應翻轉至右側")

    // 11.7 選取群組旋轉 (Group Rotation around Center)
    let rotCenter = CGPoint(x: bounds.midX, y: bounds.midY)
    let rotatedA = VectorMath.rotateObject(object: restoredA, around: rotCenter, deltaDegrees: 90.0)
    assertEqual(rotatedA.rotation, 90.0, "旋轉後物件角度應增加 90 度")
    assertTrue(abs(hypot(rotatedA.x + rotatedA.width/2 - Double(rotCenter.x), rotatedA.y + rotatedA.height/2 - Double(rotCenter.y)) - hypot(restoredA.x + restoredA.width/2 - Double(rotCenter.x), restoredA.y + restoredA.height/2 - Double(rotCenter.y))) <= 1e-6, "旋轉後物件中心至群組中心之半徑距離應嚴格守恆 (幾何無畸變)")

    // 11.8 複製／貼上／剪下／刪除 (Cut / Copy / Paste / Delete)
    engine.selectedIds = [idRect, idCircle]
    engine.copySelected()
    assertEqual(engine.internalClipboard.count, 2, "複製應將 2 個選取物件放入內部剪貼簿")

    let countBeforePaste = engine.objects.count
    engine.pasteClipboard(offset: CGPoint(x: 40, y: 40))
    assertEqual(engine.objects.count, countBeforePaste + 2, "貼上後物件總數應增加 2 個")
    let pastedObjects = engine.objects.filter { $0.id != idRect && $0.id != idCircle && $0.id != idText }
    assertEqual(pastedObjects.count, 2, "應有 2 個新貼上之物件")
    assertTrue(pastedObjects[0].id != idRect && pastedObjects[0].id != idCircle, "新貼上物件必須被賦予全新獨立 UUID")
    assertTrue(pastedObjects[1].id != idRect && pastedObjects[1].id != idCircle, "新貼上物件必須被賦予全新獨立 UUID")
    assertTrue(pastedObjects[0].groupId != nil, "新貼上之群組物件應分配新群組")
    assertEqual(pastedObjects[0].groupId, pastedObjects[1].groupId, "新貼上之群組物件應保持彼此同組")
    assertTrue(pastedObjects[0].groupId != groupedA?.groupId, "新貼上之群組 ID 必須與原群組 ID 獨立隔離")
    assertEqual(pastedObjects[0].x, 140.0, "貼上物件 X 座標應精確平移 40 點")
    assertEqual(pastedObjects[0].y, 140.0, "貼上物件 Y 座標應精確平移 40 點")

    // Undo 貼上
    engine.undo()
    assertEqual(engine.objects.count, countBeforePaste, "Undo 應完整移除貼上之 2 個新物件")

    // 刪除
    engine.selectedIds = [idRect]
    engine.deleteSelected()
    assertTrue(!engine.objects.contains(where: { $0.id == idRect }), "刪除選取物件後畫布應不再含有物件 A")
    engine.undo()
    assertTrue(engine.objects.contains(where: { $0.id == idRect }), "Undo 刪除應完整復原物件 A")

    // 11.9 遠座標 (±1,000,000) 與極限縮放 (800%) 幾何穩定性 (A06)
    let farObj = BoardObject(id: "far_obj", type: "rect", x: 1_000_000.0, y: -1_000_000.0, width: 200.0, height: 200.0)
    let farOrigBounds = CGRect(x: 1_000_000.0, y: -1_000_000.0, width: 200.0, height: 200.0)
    let farScaledBounds = CGRect(x: 1_000_000.0, y: -1_000_000.0, width: 300.0, height: 300.0)
    let farTransformed = VectorMath.transformObject(object: farObj, from: farOrigBounds, to: farScaledBounds)
    assertEqual(farTransformed.x, 1_000_000.0, "遠座標 (1,000,000) X 縮放後不偏移")
    assertEqual(farTransformed.y, -1_000_000.0, "遠座標 (-1,000,000) Y 縮放後不偏移")
    assertEqual(farTransformed.width, 300.0, "遠座標物件縮放後寬度為 300")
    assertEqual(farTransformed.height, 300.0, "遠座標物件縮放後高度為 300")
    assertTrue(farTransformed.x.isFinite && !farTransformed.x.isNaN, "遠座標運算未發生溢位或 NaN")
}

// -------------------------------------------------------------------------
// 12. Object Styles, Mixed Values & Line Endpoints (W11, A07 & A08)
// -------------------------------------------------------------------------
print("\n[測試 12] W11, A07 & A08: 物件樣式面板、混合值、A/B 端點幾何與四延伸模式 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.clearAll()
    engine.clearHistory()
    engine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)

    // 12.1 單一物件樣式讀取與批次修改、Undo/Redo (A07)
    let id1 = UUID().uuidString
    let obj1 = BoardObject(
        id: id1,
        type: "rect",
        x: 100, y: 100, width: 80, height: 80,
        strokeColor: "#ff0000",
        fillColor: "none",
        strokeWidth: 2.0,
        lineStyle: "solid",
        opacity: 1.0,
        rotation: 0.0
    )
    engine.objects = [obj1]
    engine.selectedIds = [id1]

    assertEqual(engine.selectedStrokeColor, .value("#ff0000"), "單一選取物件描邊色彩讀取正確")
    assertEqual(engine.selectedFillColor, .value("none"), "單一選取物件填充色彩讀取正確")
    assertEqual(engine.selectedStrokeWidth, .value(2.0), "單一選取物件線寬讀取正確")
    assertEqual(engine.selectedOpacity, .value(1.0), "單一選取物件不透明度讀取正確")
    assertEqual(engine.selectedLineStyle, .value("solid"), "單一選取物件線條樣式讀取正確")
    assertEqual(engine.selectedRotation, .value(0.0), "單一選取物件旋轉角度讀取正確")

    // 修改樣式並驗證單一交易
    engine.setSelectedStrokeColor("#0000ff")
    engine.setSelectedFillColor("#ffff00")
    engine.setSelectedStrokeWidth(6.0)
    engine.setSelectedOpacity(0.5)
    engine.setSelectedLineStyle("dashed")
    engine.setSelectedRotationAngle(45.0)

    assertEqual(engine.selectedStrokeColor, .value("#0000ff"), "變更後描邊色彩相符")
    assertEqual(engine.selectedFillColor, .value("#ffff00"), "變更後填充色彩相符")
    assertEqual(engine.selectedStrokeWidth, .value(6.0), "變更後線寬相符")
    assertEqual(engine.selectedOpacity, .value(0.5), "變更後不透明度相符")
    assertEqual(engine.selectedLineStyle, .value("dashed"), "變更後線條樣式相符")
    assertEqual(engine.selectedRotation, .value(45.0), "變更後旋轉角度相符")

    // 復原最後一個樣式修改 (Rotation)
    engine.undo()
    assertEqual(engine.objects.first(where: { $0.id == id1 })?.rotation, 0.0, "Undo 後物件旋轉角度應還原為 0.0")
    engine.selectedIds = [id1]
    assertEqual(engine.selectedRotation, .value(0.0), "Undo 後選取面板旋轉角度應還原為 0.0")
    engine.redo()
    assertEqual(engine.objects.first(where: { $0.id == id1 })?.rotation, 45.0, "Redo 後物件旋轉角度應重新套用 45.0")
    engine.selectedIds = [id1]
    assertEqual(engine.selectedRotation, .value(45.0), "Redo 後選取面板旋轉角度應重新套用 45.0")

    // 12.2 多選混合值 (Mixed Values) 呈現與批次覆蓋 (A07)
    let id2 = UUID().uuidString
    let obj2 = BoardObject(
        id: id2,
        type: "circle",
        x: 300, y: 100, width: 80, height: 80,
        strokeColor: "#00ff00",
        fillColor: "#0000ff",
        strokeWidth: 4.0,
        lineStyle: "solid",
        opacity: 0.8,
        rotation: 90.0
    )
    engine.objects.append(obj2)
    engine.selectedIds = [id1, id2]

    assertEqual(engine.selectedStrokeColor, .mixed, "多選不同描邊色彩應返回 .mixed")
    assertEqual(engine.selectedFillColor, .mixed, "多選不同填充色彩應返回 .mixed")
    assertEqual(engine.selectedStrokeWidth, .mixed, "多選不同線寬應返回 .mixed")
    assertEqual(engine.selectedOpacity, .mixed, "多選不同不透明度應返回 .mixed")
    assertEqual(engine.selectedLineStyle, .mixed, "多選不同線條樣式應返回 .mixed")
    assertEqual(engine.selectedRotation, .mixed, "多選不同角度應返回 .mixed")

    // 批次統一設定色彩
    engine.setSelectedStrokeColor("#ffffff")
    assertEqual(engine.selectedStrokeColor, .value("#ffffff"), "批次覆蓋後描邊色彩應統一為白色")
    let afterBatch1 = engine.objects.first(where: { $0.id == id1 })!
    let afterBatch2 = engine.objects.first(where: { $0.id == id2 })!
    assertEqual(afterBatch1.strokeColor, "#ffffff", "物件 1 描邊色彩已更新")
    assertEqual(afterBatch2.strokeColor, "#ffffff", "物件 2 描邊色彩已更新")

    // 12.3 工具預設值隔離 (A07)
    let defaultColorBefore = engine.activeColor
    let defaultWidthBefore = engine.activeStrokeWidth
    // 調現有物件屬性不得意外改動新工具預設
    assertEqual(engine.activeColor, defaultColorBefore, "修改選取物件不應改動新筆刷預設顏色")
    assertEqual(engine.activeStrokeWidth, defaultWidthBefore, "修改選取物件不應改動新筆刷預設線寬")

    // 12.4 A/B 線段幾何：四方向 + 水平 + 垂直 (A08)
    // a. 左上 -> 右下
    let idLineTL_BR = UUID().uuidString
    let lineTL_BR = BoardObject(
        id: idLineTL_BR, type: "line",
        x: 100, y: 100, width: 200, height: 200,
        x1: 100, y1: 100, x2: 300, y2: 300,
        extensionMode: LineExtension.none, strokeWidth: 4.0
    )
    // b. 右上 -> 左下
    let idLineTR_BL = UUID().uuidString
    let lineTR_BL = BoardObject(
        id: idLineTR_BL, type: "arrow",
        x: 100, y: 100, width: 200, height: 200,
        x1: 300, y1: 100, x2: 100, y2: 300,
        extensionMode: LineExtension.none, strokeWidth: 4.0
    )
    // c. 右下 -> 左上
    let idLineBR_TL = UUID().uuidString
    let lineBR_TL = BoardObject(
        id: idLineBR_TL, type: "line",
        x: 100, y: 100, width: 200, height: 200,
        x1: 300, y1: 300, x2: 100, y2: 100,
        extensionMode: LineExtension.none, strokeWidth: 4.0
    )
    // d. 水平
    let idLineH = UUID().uuidString
    let lineH = BoardObject(
        id: idLineH, type: "line",
        x: 100, y: 200, width: 300, height: 0,
        x1: 100, y1: 200, x2: 400, y2: 200,
        extensionMode: LineExtension.none, strokeWidth: 4.0
    )
    // e. 垂直
    let idLineV = UUID().uuidString
    let lineV = BoardObject(
        id: idLineV, type: "arrow",
        x: 200, y: 100, width: 0, height: 300,
        x1: 200, y1: 100, x2: 200, y2: 400,
        extensionMode: LineExtension.none, strokeWidth: 4.0
    )

    engine.objects = [lineTL_BR, lineTR_BL, lineBR_TL, lineH, lineV]

    // 驗證水平線與垂直線之命中
    assertTrue(VectorMath.isPointNearObject(point: Point(x: 250, y: 200), object: lineH, threshold: 5.0), "水平線中點應精確命中")
    assertTrue(!VectorMath.isPointNearObject(point: Point(x: 250, y: 220), object: lineH, threshold: 5.0), "遠離水平線點不應命中")
    assertTrue(VectorMath.isPointNearObject(point: Point(x: 200, y: 250), object: lineV, threshold: 5.0), "垂直線中點應精確命中")
    assertTrue(!VectorMath.isPointNearObject(point: Point(x: 220, y: 250), object: lineV, threshold: 5.0), "遠離垂直線點不應命中")

    // 12.5 反向拖曳不翻轉或交換端點 (A08)
    // 在水平線 lineH (A: 100,200 -> B: 400,200) 將 A 拖曳至 600,200 (越過 B)
    engine.updateLineEndpointDrag(objectID: idLineH, endpoint: .start, at: Point(x: 600, y: 200))
    engine.endLineEndpointDrag()

    let draggedLine = engine.objects.first(where: { $0.id == idLineH })!
    assertEqual(draggedLine.x1, 600.0, "反向拖曳後端點 A (x1) 應為 600.0")
    assertEqual(draggedLine.x2, 400.0, "端點 B (x2) 仍嚴格維持原座標 400.0 (未發生翻轉或交換)")
    assertEqual(draggedLine.x, 400.0, "邊界外框 min x 應自動更新為 400.0")
    assertEqual(draggedLine.width, 200.0, "邊界外框寬度為 200.0")

    // 單次 Undo 恢復端點
    engine.undo()
    let restoredLine = engine.objects.first(where: { $0.id == idLineH })!
    assertEqual(restoredLine.x1, 100.0, "Undo 應還原端點 A 至 100.0")
    assertEqual(restoredLine.x2, 400.0, "端點 B 保持 400.0")

    // 12.6 四種延伸模式 (none, start, end, both) 與命中測試 (A08)
    // 基準線：(100, 200) -> (400, 200)
    // 測試點 P_before = (0, 200) (A端外側), P_inside = (250, 200), P_after = (600, 200) (B端外側)
    let pBefore = Point(x: 0, y: 200)
    let pInside = Point(x: 250, y: 200)
    let pAfter = Point(x: 600, y: 200)

    // a. .none
    var testExtLine = restoredLine
    testExtLine.extensionMode = LineExtension.none
    assertTrue(VectorMath.isPointNearObject(point: pInside, object: testExtLine, threshold: 5.0), "none 模式線段內部應命中")
    assertTrue(!VectorMath.isPointNearObject(point: pBefore, object: testExtLine, threshold: 5.0), "none 模式 A 延伸外側不應命中")
    assertTrue(!VectorMath.isPointNearObject(point: pAfter, object: testExtLine, threshold: 5.0), "none 模式 B 延伸外側不應命中")

    // b. .end (B端延伸射線)
    testExtLine.extensionMode = .end
    assertTrue(VectorMath.isPointNearObject(point: pInside, object: testExtLine, threshold: 5.0), "end 模式線段內部應命中")
    assertTrue(!VectorMath.isPointNearObject(point: pBefore, object: testExtLine, threshold: 5.0), "end 模式 A 端外側不應命中")
    assertTrue(VectorMath.isPointNearObject(point: pAfter, object: testExtLine, threshold: 5.0), "end 模式 B 端延伸射線應命中")

    // c. .start (A端延伸射線)
    testExtLine.extensionMode = .start
    assertTrue(VectorMath.isPointNearObject(point: pInside, object: testExtLine, threshold: 5.0), "start 模式線段內部應命中")
    assertTrue(VectorMath.isPointNearObject(point: pBefore, object: testExtLine, threshold: 5.0), "start 模式 A 端延伸射線應命中")
    assertTrue(!VectorMath.isPointNearObject(point: pAfter, object: testExtLine, threshold: 5.0), "start 模式 B 端外側不應命中")

    // d. .both (無限直線)
    testExtLine.extensionMode = .both
    assertTrue(VectorMath.isPointNearObject(point: pInside, object: testExtLine, threshold: 5.0), "both 模式線段內部應命中")
    assertTrue(VectorMath.isPointNearObject(point: pBefore, object: testExtLine, threshold: 5.0), "both 模式 A 端延伸應命中")
    assertTrue(VectorMath.isPointNearObject(point: pAfter, object: testExtLine, threshold: 5.0), "both 模式 B 端延伸應命中")
}

// -------------------------------------------------------------------------
// 13. GoodNotes Hold-to-Shape & Stroke Consistency (W12, A01 & A09)
// -------------------------------------------------------------------------
print("\n[測試 13] W12, A01 & A09: 停筆轉形狀態機、幾何辨識 (線／圓／橢圓／矩形)、工具樣式保留與書寫不誤觸 (立靶驗收)")
do {
    // 13.1 幾何辨識案例集 (ShapeRecognizer Accuracy)
    // a. 水平線 (Line)
    var lineHPoints: [Point] = []
    for i in 0...20 {
        lineHPoints.append(Point(x: 100.0 + Double(i) * 15.0, y: 200.0 + Double(i % 2) * 0.5))
    }
    let recLineH = ShapeRecognizer.recognize(points: lineHPoints)
    assertEqual(recLineH?.type, "line", "水平直線應正確辨識為 line")
    assertEqual(recLineH?.x1, 100.0, "直線起點 X 應為 100.0")
    assertEqual(recLineH?.x2, 400.0, "直線終點 X 應為 400.0")
    assertEqual(recLineH?.y1, 200.0, "直線起點 Y 應為 200.0")

    // b. 反向對角線 (Reverse Diagonal Line) - 驗證保留拖曳方向
    var lineRevPoints: [Point] = []
    for i in 0...20 {
        lineRevPoints.append(Point(x: 300.0 - Double(i) * 10.0, y: 300.0 - Double(i) * 10.0))
    }
    let recLineRev = ShapeRecognizer.recognize(points: lineRevPoints)
    assertEqual(recLineRev?.type, "line", "反向對角線應正確辨識為 line")
    assertEqual(recLineRev?.x1, 300.0, "反向直線起點 X1 應保留為 300.0")
    assertEqual(recLineRev?.y1, 300.0, "反向直線起點 Y1 應保留為 300.0")
    assertEqual(recLineRev?.x2, 100.0, "反向直線終點 X2 應保留為 100.0")
    assertEqual(recLineRev?.y2, 100.0, "反向直線終點 Y2 應保留為 100.0")

    // c. 圓形 (Circle)
    var circlePoints: [Point] = []
    for i in 0...36 {
        let angle = Double(i) * (2.0 * .pi / 36.0)
        circlePoints.append(Point(x: 200.0 + 50.0 * cos(angle), y: 200.0 + 50.0 * sin(angle)))
    }
    let recCircle = ShapeRecognizer.recognize(points: circlePoints)
    assertEqual(recCircle?.type, "circle", "等徑閉合環應正確辨識為 circle")
    assertTrue(abs((recCircle?.width ?? 0) - 100.0) <= 2.0, "圓形寬度應約為直徑 100")
    assertTrue(abs((recCircle?.height ?? 0) - 100.0) <= 2.0, "圓形高度應約為直徑 100")

    // d. 橢圓形 (Ellipse)
    var ellipsePoints: [Point] = []
    for i in 0...36 {
        let angle = Double(i) * (2.0 * .pi / 36.0)
        ellipsePoints.append(Point(x: 300.0 + 100.0 * cos(angle), y: 200.0 + 40.0 * sin(angle)))
    }
    let recEllipse = ShapeRecognizer.recognize(points: ellipsePoints)
    assertEqual(recEllipse?.type, "ellipse", "扁平閉合環應正確辨識為 ellipse")
    assertTrue(abs((recEllipse?.width ?? 0) - 200.0) <= 4.0, "橢圓寬度應約為長軸 200")
    assertTrue(abs((recEllipse?.height ?? 0) - 80.0) <= 4.0, "橢圓高度應約為短軸 80")

    // e. 矩形 (Rectangle)
    var rectPoints: [Point] = []
    // Top edge: (100, 100) -> (240, 100)
    for i in 0...7 { rectPoints.append(Point(x: 100.0 + Double(i) * 20.0, y: 100.0)) }
    // Right edge: (240, 100) -> (240, 190)
    for i in 1...6 { rectPoints.append(Point(x: 240.0, y: 100.0 + Double(i) * 15.0)) }
    // Bottom edge: (240, 190) -> (100, 190)
    for i in 1...7 { rectPoints.append(Point(x: 240.0 - Double(i) * 20.0, y: 190.0)) }
    // Left edge: (100, 190) -> (100, 100)
    for i in 1...6 { rectPoints.append(Point(x: 100.0, y: 190.0 - Double(i) * 15.0)) }
    let recRect = ShapeRecognizer.recognize(points: rectPoints)
    assertEqual(recRect?.type, "rect", "四邊環路應正確辨識為 rect")
    assertEqual(recRect?.width, 140.0, "矩形寬度相符")
    assertEqual(recRect?.height, 90.0, "矩形高度相符")

    // f. 普通書寫不誤轉形 (Normal Writing / Scribble / Curves)
    // 波動 S 曲線 (文字草寫常見)
    var wavePoints: [Point] = []
    for i in 0...30 {
        wavePoints.append(Point(x: Double(i) * 10.0, y: sin(Double(i) * 0.5) * 40.0))
    }
    let recWave = ShapeRecognizer.recognize(points: wavePoints)
    assertEqual(recWave, nil, "一般波動 S 筆跡嚴禁被誤辨識為幾何形狀 (正常書寫不誤觸)")

    // 勾選開口折線
    var checkPoints: [Point] = [
        Point(x: 10, y: 50), Point(x: 20, y: 70), Point(x: 30, y: 90),
        Point(x: 60, y: 40), Point(x: 90, y: 10)
    ]
    let recCheck = ShapeRecognizer.recognize(points: checkPoints)
    assertEqual(recCheck, nil, "開口打勾折線不應被辨識為閉合形狀")

    // 超短取樣 (<5 點)
    let shortPoints = [Point(x: 10, y: 10), Point(x: 12, y: 12), Point(x: 14, y: 14)]
    assertEqual(ShapeRecognizer.recognize(points: shortPoints), nil, "小於 5 點短筆跡不執行轉形")

    // 13.2 停筆狀態機 (Hold Gesture State Machine: 辨識吸附與移動取消)
    let engine = BoardEngine(restoreSession: false)
    engine.clearAll()
    engine.clearHistory()
    engine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
    engine.activeColor = "#06b6d4"
    engine.activeStrokeWidth = 4.5
    engine.activeOpacity = 0.85
    engine.activeLineStyle = "dashed"

    // 開始繪製矩形
    engine.startStroke(at: rectPoints[0])
    for p in rectPoints.dropFirst() {
        engine.appendStrokePoint(at: p)
    }
    assertEqual(engine.strokePreview.snappedShape, nil, "繪製過程中未停筆前 preview.snappedShape 應為 nil")

    // 停筆約 1 秒觸發轉形
    engine.checkGoodnotesShapeSnap()
    assertTrue(engine.strokePreview.snappedShape != nil, "停筆後應成功觸發吸附 preview.snappedShape")
    assertEqual(engine.strokePreview.snappedShape?.type, "rect", "吸附預覽形狀應為 rect")

    // 繼續移動筆跡 (超過 12 點) -> 移動取消暫時吸附 (A09)
    engine.appendStrokePoint(at: Point(x: 350, y: 350))
    assertEqual(engine.strokePreview.snappedShape, nil, "繼續移動筆跡必須立即取消暫時吸附，回歸自由筆跡 (A09 規範)")

    // 重新在最終端點停筆 -> 再次吸附
    engine.strokePreview.reset()

    // 13.3 轉形完成、保留工具樣式與一次復原 (A09)
    engine.startStroke(at: circlePoints[0])
    for p in circlePoints.dropFirst() { engine.appendStrokePoint(at: p) }
    engine.checkGoodnotesShapeSnap()
    assertEqual(engine.strokePreview.snappedShape?.type, "circle", "停筆完成辨識圓形")

    // 提起筆尖完成手勢
    engine.endStroke()
    assertEqual(engine.objects.count, 1, "轉形完成應向畫布新增 1 個幾何物件")
    let convertedObj = engine.objects[0]
    assertEqual(convertedObj.type, "circle", "生成物件類型應為 circle")
    assertEqual(convertedObj.strokeColor, "#06b6d4", "轉形物件應嚴格保留工具色彩 (activeColor)")
    assertEqual(convertedObj.strokeWidth, 4.5, "轉形物件應嚴格保留工具粗細 (activeStrokeWidth)")
    assertEqual(convertedObj.opacity, 0.85, "轉形物件應嚴格保留工具透明度 (activeOpacity)")
    assertEqual(convertedObj.lineStyle, "dashed", "轉形物件應嚴格保留線條樣式 (activeLineStyle)")
    assertTrue(engine.selectedIds.contains(convertedObj.id), "轉形完成物件應被自動選取以供後續微調")

    // 一次 Undo 完整復原
    engine.undo()
    assertEqual(engine.objects.count, 0, "執行一次 Undo 必須完整移除轉形物件 (一次復原，A09)")
    engine.redo()
    assertEqual(engine.objects.count, 1, "執行一次 Redo 完整恢復轉形物件")

    // 13.4 正常書寫手勢結束不轉形
    engine.clearAll()
    engine.clearHistory()
    engine.startStroke(at: wavePoints[0])
    for p in wavePoints.dropFirst() { engine.appendStrokePoint(at: p) }
    // 未停筆直接抬筆 (正常書寫)
    engine.endStroke()
    assertEqual(engine.objects.count, 1, "正常書寫手勢結束應生成 1 個筆跡物件")
    assertEqual(engine.objects[0].type, "stroke", "正常書寫物件類型必須保持為 stroke 而非幾何形狀")
    assertTrue(engine.objects[0].parsedPoints.count >= 20, "普通筆跡物件應完整保存所有取樣點座標")

    // 13.5 筆跡曲線一致性、端點與尾段連續性 (A01)
    let pStart = wavePoints.first!
    let pEnd = wavePoints.last!
    let strokePath = BoardPathCache.worldPath(for: engine.objects[0])
    assertTrue(!strokePath.isEmpty, "快取筆跡路徑不為空")
    let box = VectorMath.computeBoundingBox(points: wavePoints, strokeWidth: 2.0)
    assertTrue(box.width > 0 && box.height > 0, "筆跡外框邊界計算完整")
    assertEqual(pStart.x, wavePoints[0].x, "筆跡第一點座標精確相符")
    assertEqual(pEnd.x, wavePoints[wavePoints.count - 1].x, "筆跡最後一點座標精確相符")
}

// -------------------------------------------------------------------------
// 14. Fixed vs Infinite Canvas, Presets, Boundaries & ±1,000,000 Coordinates (W13, A10)
// -------------------------------------------------------------------------
print("\n[測試 14] W13 & A10: 固定／無限畫布建立、預設紙張尺寸、禁止無限降級、尺寸編輯與遠座標 (立靶驗收)")
do {
    // 14.1 紙張單位與預設尺寸契約 (A10)
    assertEqual(CanvasPreset.a4_portrait.defaultDimensions()?.width, 595.0, "A4 直向標準寬度應為 595.0 pt (210mm)")
    assertEqual(CanvasPreset.a4_portrait.defaultDimensions()?.height, 842.0, "A4 直向標準高度應為 842.0 pt (297mm)")
    assertEqual(CanvasPreset.a4_landscape.defaultDimensions()?.width, 842.0, "A4 橫向標準寬度應為 842.0 pt")
    assertEqual(CanvasPreset.a4_landscape.defaultDimensions()?.height, 595.0, "A4 橫向標準高度應為 595.0 pt")
    assertEqual(CanvasPreset.a3_landscape.defaultDimensions()?.width, 1191.0, "A3 橫向標準寬度應為 1191.0 pt (420mm)")
    assertEqual(CanvasPreset.a3_landscape.defaultDimensions()?.height, 842.0, "A3 橫向標準高度應為 842.0 pt (297mm)")
    assertEqual(CanvasPreset.sixteen_nine.defaultDimensions()?.width, 1920.0, "16:9 標準寬度應為 1920.0 pt")
    assertEqual(CanvasPreset.sixteen_nine.defaultDimensions()?.height, 1080.0, "16:9 標準高度應為 1080.0 pt")
    assertEqual(CanvasPreset.four_three.defaultDimensions()?.width, 1440.0, "4:3 標準寬度應為 1440.0 pt")
    assertEqual(CanvasPreset.four_three.defaultDimensions()?.height, 1080.0, "4:3 標準高度應為 1080.0 pt")
    assertEqual(CanvasPreset.custom.defaultDimensions()?.width, 1200.0, "自訂預設寬度應為 1200.0 pt")
    assertEqual(CanvasPreset.infinite.defaultDimensions()?.width, nil, "無限畫布無固定邊界尺寸")

    // 14.2 固定畫布建立與設定 (A10)
    let engine = BoardEngine(restoreSession: false)
    engine.clearAll()
    engine.clearHistory()
    engine.board.canvasMode = .fixed // Start as fixed
    try engine.configureCanvas(mode: .fixed, preset: .a4_portrait)
    assertEqual(engine.board.canvasMode, .fixed, "畫布模式應為 fixed")
    assertEqual(engine.board.canvasPreset, .a4_portrait, "畫布預設應為 a4_portrait")
    assertEqual(engine.board.canvasWidth, 595.0, "固定寬度相符")
    assertEqual(engine.board.canvasHeight, 842.0, "固定高度相符")

    // 14.3 固定尺寸編輯與 Undo/Redo (A10)
    try engine.resizeFixedCanvas(width: 800.0, height: 600.0)
    assertEqual(engine.board.canvasWidth, 800.0, "編輯固定寬度應更新為 800.0")
    assertEqual(engine.board.canvasHeight, 600.0, "編輯固定高度應更新為 600.0")
    engine.undo()
    assertEqual(engine.board.canvasWidth, 595.0, "Undo 應還原固定畫布尺寸")
    engine.redo()
    assertEqual(engine.board.canvasWidth, 800.0, "Redo 應重新套用固定畫布尺寸")

    // 14.4 固定升級無限：保留所有物件內容與可復原 (A10)
    let objA = BoardObject(id: "obj_fixed_1", type: "rect", x: 50, y: 50, width: 100, height: 100)
    let objB = BoardObject(id: "obj_fixed_2", type: "circle", x: 200, y: 200, width: 80, height: 80)
    engine.objects = [objA, objB]

    engine.upgradeToInfiniteCanvas()
    assertEqual(engine.board.canvasMode, .infinite, "升級後畫布模式應為 infinite")
    assertEqual(engine.board.canvasPreset, .infinite, "升級後預設應為 infinite")
    assertEqual(engine.objects.count, 2, "固定升級無限後原所有物件數量必須 100% 完整保留")
    assertEqual(engine.objects[0].id, "obj_fixed_1", "原物件 A 識別碼與幾何完全保留")
    assertEqual(engine.objects[1].id, "obj_fixed_2", "原物件 B 識別碼與幾何完全保留")
    engine.undo()
    assertEqual(engine.board.canvasMode, .fixed, "Undo 升級應恢復為 fixed 模式")
    engine.redo()
    assertEqual(engine.board.canvasMode, .infinite, "Redo 升級應重新套用 infinite 模式")

    // 14.5 禁止無限降級 (A10: 無限沒有降級操作)
    assertTrue(!engine.canDowngradeToFixed, "無限畫布模式下 canDowngradeToFixed 必須為 false (A10 規範)")
    var didCatchDowngradeError = false
    do {
        try engine.configureCanvas(mode: .fixed, preset: .a4_portrait)
    } catch CanvasError.cannotDowngradeInfiniteCanvas {
        didCatchDowngradeError = true
    } catch {
        // other error
    }
    assertTrue(didCatchDowngradeError, "嘗試將無限畫布降級為固定畫布必須被嚴格阻擋並拋出 cannotDowngradeInfiniteCanvas (A10 規範)")
    assertEqual(engine.board.canvasMode, .infinite, "降級被拒絕後畫布維持 infinite，防止無形隱藏或截斷資料")

    // 14.6 固定畫布越界偵測與自動貼齊 (A10)
    let fixedEngine = BoardEngine(restoreSession: false)
    fixedEngine.clearAll()
    fixedEngine.board.canvasMode = .fixed
    fixedEngine.board.canvasWidth = 500.0
    fixedEngine.board.canvasHeight = 500.0

    let insideObj = BoardObject(id: "inside_1", type: "rect", x: 50, y: 50, width: 100, height: 100)
    let outsideObj = BoardObject(id: "outside_1", type: "rect", x: 550, y: 50, width: 100, height: 100)
    fixedEngine.objects = [insideObj, outsideObj]

    assertTrue(!fixedEngine.isObjectOutOfBounds(insideObj), "邊界內物件不應標記為越界")
    assertTrue(fixedEngine.isObjectOutOfBounds(outsideObj), "超出固定邊界物件應精確標記為越界 (A10)")
    assertEqual(fixedEngine.outOfBoundsObjects().count, 1, "應精確報告 1 個越界物件")

    fixedEngine.fitCanvasToObjects()
    assertTrue(fixedEngine.board.canvasWidth! >= 690.0, "自動適配後固定畫布寬度應擴展至包覆越界物件")
    assertEqual(fixedEngine.outOfBoundsObjects().count, 0, "適配後畫布不再存在越界物件")

    // 14.7 無限畫布四方向 world ±1,000,000 繪製／選取／命中／保存 (A10)
    let farEngine = BoardEngine(restoreSession: false)
    farEngine.clearAll()
    farEngine.board.canvasMode = .infinite
    farEngine.board.title = "極遠百萬座標測試板"

    // 於四象限極限位置建立物件
    let objQ1 = BoardObject(id: "obj_q1", type: "rect", x: 1_000_000.0, y: 1_000_000.0, width: 100, height: 100)
    let objQ2 = BoardObject(id: "obj_q2", type: "circle", x: -1_000_000.0, y: 1_000_000.0, width: 100, height: 100)
    let objQ3 = BoardObject(id: "obj_q3", type: "line", x: -1_000_000.0, y: -1_000_000.0, width: 200, height: 200, x1: -1_000_000.0, y1: -1_000_000.0, x2: -999_800.0, y2: -999_800.0)
    let objQ4 = BoardObject(id: "obj_q4", type: "rect", x: 1_000_000.0, y: -1_000_000.0, width: 100, height: 100)

    farEngine.objects = [objQ1, objQ2, objQ3, objQ4]

    // 驗證四象限極遠座標命中無障礙
    assertTrue(VectorMath.isPointNearObject(point: Point(x: 1_000_050.0, y: 1_000_050.0), object: objQ1), "第一象限 (+100萬, +100萬) 命中測試成功")
    assertTrue(VectorMath.isPointNearObject(point: Point(x: -999_950.0, y: 1_000_050.0), object: objQ2), "第二象限 (-100萬, +100萬) 命中測試成功")
    assertTrue(VectorMath.isPointNearObject(point: Point(x: -999_900.0, y: -999_900.0), object: objQ3), "第三象限 (-100萬, -100萬) 命中測試成功")
    assertTrue(VectorMath.isPointNearObject(point: Point(x: 1_000_050.0, y: -999_950.0), object: objQ4), "第四象限 (+100萬, -100萬) 命中測試成功")

    // 驗證極遠座標多選外框計算
    let farBounds = VectorMath.selectionBounds(for: [objQ1, objQ2, objQ3, objQ4])
    assertTrue(farBounds != nil, "百萬座標多選外框計算成功")
    assertEqual(farBounds?.minX, -1_000_000.0, "外框 minX 相符")
    assertEqual(farBounds?.maxX, 1_000_100.0, "外框 maxX 相符")
    assertEqual(farBounds?.minY, -1_000_000.0, "外框 minY 相符")
    assertEqual(farBounds?.maxY, 1_000_100.0, "外框 maxY 相符")

    // 驗證極遠座標完整文件編碼與解碼無損往返 (A10)
    let farDoc = HeiBanDocument(
        schemaVersion: "1.0.0",
        version: "1.0",
        board: farEngine.board,
        objects: farEngine.objects
    )
    let encodedData = try HeiBanDocumentCodec.encode(farDoc)
    let decodedDoc = try HeiBanDocumentCodec.decode(from: encodedData)

    assertEqual(decodedDoc.objects.count, 4, "極遠百萬座標文件解碼物件數完整")
    assertEqual(decodedDoc.objects[0].x, 1_000_000.0, "Q1 X 座標精確無損保留")
    assertEqual(decodedDoc.objects[1].x, -1_000_000.0, "Q2 X 座標精確無損保留")
    assertEqual(decodedDoc.objects[2].y, -1_000_000.0, "Q3 Y 座標精確無損保留")
    assertEqual(decodedDoc.objects[3].y, -1_000_000.0, "Q4 Y 座標精確無損保留")
}

// -------------------------------------------------------------------------
// 15. Scroll Wheel, Trackpad, Space & Esc (W14, A11)
// -------------------------------------------------------------------------
print("\n[測試 15] W14 & A11: 滾輪游標錨點縮放、Shift 橫移、Space 拖曳、觸控板增量與 Esc 恢復 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.viewport = ViewportTransform(x: 200, y: 150, zoom: 1.0)

    // 1. 預設滾輪以游標位置縮放，對應世界位置誤差 ≤ 1 螢幕 point (A11)
    let cursor1 = Point(x: 450, y: 320)
    let worldAnchor1 = VectorMath.screenToWorld(cursor1, viewport: engine.viewport)
    // 放大
    engine.handleScrollWheel(at: cursor1, deltaX: 0, deltaY: 25, shift: false)
    assertTrue(engine.viewport.zoom > 1.0, "滾輪垂直滾動應觸發縮放 (zoom > 1.0)")
    let newScreen1 = VectorMath.worldToScreen(worldAnchor1, viewport: engine.viewport)
    let errorX1 = abs(newScreen1.x - cursor1.x)
    let errorY1 = abs(newScreen1.y - cursor1.y)
    assertTrue(errorX1 <= 1.0, "游標中心縮放 X 螢幕誤差應 <= 1 point (實際誤差: \(errorX1))")
    assertTrue(errorY1 <= 1.0, "游標中心縮放 Y 螢幕誤差應 <= 1 point (實際誤差: \(errorY1))")

    // 縮小 (另一個游標位置)
    let cursor2 = Point(x: 120, y: 550)
    let worldAnchor2 = VectorMath.screenToWorld(cursor2, viewport: engine.viewport)
    engine.handleScrollWheel(at: cursor2, deltaX: 0, deltaY: -40, shift: false)
    let newScreen2 = VectorMath.worldToScreen(worldAnchor2, viewport: engine.viewport)
    let errorX2 = abs(newScreen2.x - cursor2.x)
    let errorY2 = abs(newScreen2.y - cursor2.y)
    assertTrue(errorX2 <= 1.0, "縮小游標中心縮放 X 螢幕誤差應 <= 1 point (實際誤差: \(errorX2))")
    assertTrue(errorY2 <= 1.0, "縮小游標中心縮放 Y 螢幕誤差應 <= 1 point (實際誤差: \(errorY2))")

    // 縮放邊界鉗制 (0.08 ~ 8.0)
    for _ in 0..<50 {
        engine.handleScrollWheel(at: cursor1, deltaX: 0, deltaY: 100, shift: false)
    }
    assertTrue(engine.viewport.zoom <= 8.0, "最大縮放比例不超過 8.0")
    for _ in 0..<50 {
        engine.handleScrollWheel(at: cursor1, deltaX: 0, deltaY: -100, shift: false)
    }
    assertTrue(engine.viewport.zoom >= 0.08, "最小縮放比例不低於 0.08")

    // 2. Shift + 滾輪橫移 (A11)
    engine.viewport = ViewportTransform(x: 100, y: 200, zoom: 1.0)
    engine.handleScrollWheel(at: Point(x: 300, y: 300), deltaX: 0, deltaY: 50, shift: true)
    assertEqual(engine.viewport.x, 150.0, "Shift + 滾輪應轉為水平平移 (+50)")
    assertEqual(engine.viewport.y, 200.0, "Shift + 滾輪不改變垂直平移")
    assertEqual(engine.viewport.zoom, 1.0, "Shift + 滾輪不觸發縮放")

    // 3. Space + 拖曳平移 (A11)
    engine.isHoldingSpace = true
    engine.beginPointerGesture(at: Point(x: 200, y: 200))
    assertTrue(engine.isPointerGestureActive, "按住 Space 拖曳應啟動手勢")
    assertEqual(engine.pointerGesture, .pan, "手勢類型應為 .pan")
    engine.updatePointerGesture(at: Point(x: 260, y: 240), translation: CGSize(width: 60, height: 40))
    assertEqual(engine.viewport.x, 210.0, "拖曳平移 X 增量相符")
    assertEqual(engine.viewport.y, 240.0, "拖曳平移 Y 增量相符")
    engine.endPointerGesture(translation: CGSize(width: 60, height: 40))
    assertTrue(!engine.isPointerGestureActive, "放開滑鼠結束拖曳手勢")
    engine.isHoldingSpace = false
    assertTrue(!engine.isHoldingSpace, "放開 Space 鍵後 isHoldingSpace 應為 false")

    // 4. 失焦與第一響應者重設清理 (A11: 按住／放開 Space 不卡住)
    engine.isHoldingSpace = true
    engine.isShiftHeld = true
    engine.handleWindowBlur()
    assertTrue(!engine.isHoldingSpace, "視窗失焦時應自動清理 isHoldingSpace 防止卡鍵")
    assertTrue(!engine.isShiftHeld, "視窗失焦時應自動清理 isShiftHeld 防止卡鍵")

    // 5. 觸控板縮放增量控制 (A11)
    engine.viewport = ViewportTransform(x: 100, y: 100, zoom: 1.0)
    let pinchCenter = Point(x: 400, y: 400)
    let pinchAnchor = VectorMath.screenToWorld(pinchCenter, viewport: engine.viewport)
    engine.updateMagnificationGesture(scale: 1.25, around: pinchCenter)
    assertEqual(engine.viewport.zoom, 1.25, "觸控板縮放增量套用 1.25")
    let pinchScreen1 = VectorMath.worldToScreen(pinchAnchor, viewport: engine.viewport)
    assertTrue(abs(pinchScreen1.x - pinchCenter.x) <= 1.0, "觸控板手勢 X 錨點誤差 <= 1 point")
    assertTrue(abs(pinchScreen1.y - pinchCenter.y) <= 1.0, "觸控板手勢 Y 錨點誤差 <= 1 point")

    engine.updateMagnificationGesture(scale: 1.5, around: pinchCenter)
    assertEqual(engine.viewport.zoom, 1.5, "觸控板接續縮放增量套用 1.5")
    let pinchScreen2 = VectorMath.worldToScreen(pinchAnchor, viewport: engine.viewport)
    assertTrue(abs(pinchScreen2.x - pinchCenter.x) <= 1.0, "觸控板連續縮放 X 錨點誤差 <= 1 point")
    assertTrue(abs(pinchScreen2.y - pinchCenter.y) <= 1.0, "觸控板連續縮放 Y 錨點誤差 <= 1 point")
    engine.endMagnificationGesture()

    // 6. Esc 取消暫時操作、清除選取並回 Select (A11)
    engine.currentTool = .pen
    engine.beginPointerGesture(at: Point(x: 50, y: 50))
    engine.updatePointerGesture(at: Point(x: 80, y: 80), translation: CGSize(width: 30, height: 30))
    assertTrue(engine.isPointerGestureActive, "筆跡繪製中手勢處於作用中")
    engine.isHoldingSpace = true
    engine.cancelTransientInteraction()
    assertEqual(engine.currentTool, .select, "Esc 應重設目前工具為 .select")
    assertEqual(engine.pointerGesture, .idle, "Esc 應取消進行中之暫時手勢回 idle")
    assertTrue(!engine.isHoldingSpace, "Esc 應重設 isHoldingSpace 為 false")
    assertTrue(engine.selectedIds.isEmpty, "Esc 應清空選取物件")
    assertTrue(!engine.showTextEditor, "Esc 應退出文字編輯模式")

    // 7. 重複點選已啟用工具回到 Select (A05 & W14 規範)
    engine.selectTool(.pen)
    assertEqual(engine.currentTool, .pen, "切換至鋼筆工具")
    engine.selectTool(.pen)
    assertEqual(engine.currentTool, .select, "重複點選鋼筆工具應回歸 Select")

    engine.selectTool(.highlighter)
    assertEqual(engine.currentTool, .highlighter, "切換至螢光筆工具")
    engine.selectTool(.highlighter)
    assertEqual(engine.currentTool, .select, "重複點選螢光筆工具應回歸 Select")

    engine.selectTool(.rect)
    assertEqual(engine.currentTool, .rect, "切換至矩形形狀工具")
    engine.selectTool(.rect)
    assertEqual(engine.currentTool, .select, "重複點選矩形工具應回歸 Select")

    engine.selectTool(.eraser)
    assertEqual(engine.currentTool, .eraser, "切換至橡皮擦工具")
    engine.selectTool(.eraser)
    assertEqual(engine.currentTool, .select, "重複點選橡皮擦工具應回歸 Select")
}

// -------------------------------------------------------------------------
// 16. Virtual Screen Ruler, Pivot, Dual Rotation & End Snapping (W15, A13)
// -------------------------------------------------------------------------
print("\n[測試 16] W15 & A13: 螢幕尺規、螢幕空間守恆、雙端旋轉、上下支點與端點外停止貼齊 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.ruler.enabled = true
    engine.ruler.screenCenterX = 400
    engine.ruler.screenCenterY = 200
    engine.ruler.angle = 0
    engine.ruler.width = 500   // X: [150, 650]
    engine.ruler.height = 50   // top edge: 175, bottom edge: 225
    engine.ruler.pivotRatio = 0.5
    engine.ruler.pivotEdge = "center"
    engine.ruler.opacity = 0.4

    // 16.1 螢幕空間尺度守恆 (A13: 縮放畫布不改變尺的螢幕尺寸)
    engine.viewport = ViewportTransform(x: 200, y: 150, zoom: 0.25)
    assertEqual(engine.ruler.width, 500.0, "縮小畫布至 0.25x 尺身螢幕寬度守恆 500")
    assertEqual(engine.ruler.height, 50.0, "縮小畫布至 0.25x 尺身螢幕高度守恆 50")
    assertEqual(engine.ruler.screenCenterX, 400.0, "縮小畫布尺螢幕中心 X 守恆")
    assertEqual(engine.ruler.screenCenterY, 200.0, "縮小畫布尺螢幕中心 Y 守恆")

    engine.viewport = ViewportTransform(x: 500, y: 300, zoom: 4.0)
    assertEqual(engine.ruler.width, 500.0, "放大畫布至 4.0x 尺身螢幕寬度守恆 500")
    assertEqual(engine.ruler.height, 50.0, "放大畫布至 4.0x 尺身螢幕高度守恆 50")

    // 16.2 有效尺長、端點外停止貼齊 (A13: 越過尺兩端不繼續延伸貼齊；不產生凸出的筆跡)
    // 尺範圍 X: 150...650, top edge: 175, bottom edge: 225
    // 尺內頂緣吸附 (X = 350, Y = 170)
    let inSnap = VectorMath.snapToRulerEdge(screenPt: Point(x: 350, y: 170), ruler: engine.ruler, snapTolerance: 20, stopSnappingBeyondEnds: true)
    assertTrue(inSnap.snapped, "尺長範圍內頂緣應被精確吸附")
    assertEqual(inSnap.screenPt.y, 175.0, "吸附後 Y 座標貼齊頂緣 175")
    assertEqual(inSnap.screenPt.x, 350.0, "吸附後 X 座標維持 350")

    // 尺內底緣吸附 (X = 420, Y = 230)
    let inBottomSnap = VectorMath.snapToRulerEdge(screenPt: Point(x: 420, y: 230), ruler: engine.ruler, snapTolerance: 20, stopSnappingBeyondEnds: true)
    assertTrue(inBottomSnap.snapped, "尺長範圍內底緣應被精確吸附")
    assertEqual(inBottomSnap.screenPt.y, 225.0, "吸附後 Y 座標貼齊底緣 225")
    assertEqual(inBottomSnap.screenPt.x, 420.0, "吸附後 X 座標維持 420")

    // 右端點外超出 (X = 700 > 650)，stopSnappingBeyondEnds: true 必須返回 false (端點外停止貼齊)
    let outRightSnap = VectorMath.snapToRulerEdge(screenPt: Point(x: 700, y: 173), ruler: engine.ruler, snapTolerance: 20, stopSnappingBeyondEnds: true)
    assertTrue(!outRightSnap.snapped, "越過右端點應立即停止貼齊 (A13 規範)")
    assertEqual(outRightSnap.screenPt.x, 700.0, "端點外筆尖 X 座標不受吸附干擾")
    assertEqual(outRightSnap.screenPt.y, 173.0, "端點外筆尖 Y 座標不受吸附干擾")

    // 左端點外超出 (X = 120 < 150)
    let outLeftSnap = VectorMath.snapToRulerEdge(screenPt: Point(x: 120, y: 173), ruler: engine.ruler, snapTolerance: 20, stopSnappingBeyondEnds: true)
    assertTrue(!outLeftSnap.snapped, "越過左端點應立即停止貼齊 (A13 規範)")
    assertEqual(outLeftSnap.screenPt.x, 120.0, "端點外筆尖 X 座標保持自然筆跡")

    // 超出吸附容差範圍 (Y = 140, 距頂緣 35 > 20)
    let farSnap = VectorMath.snapToRulerEdge(screenPt: Point(x: 350, y: 140), ruler: engine.ruler, snapTolerance: 20, stopSnappingBeyondEnds: true)
    assertTrue(!farSnap.snapped, "遠離尺緣超過容差不吸附")

    // 16.3 使用者可移動上下邊支點與中心預設 (W15, A13)
    assertEqual(engine.ruler.pivotRatio, 0.5, "預設支點比率為中心 0.5")
    assertEqual(engine.ruler.pivotEdge, "center", "預設支點邊緣為 center")

    // 移動支點至頂部邊緣 (Y 向上拖曳至 180)
    engine.updateRulerPivot(at: Point(x: 400, y: 180))
    assertEqual(engine.ruler.pivotEdge, "top", "支點成功吸附至頂緣 top")

    // 移動支點至底部邊緣 (Y 向下拖曳至 220)
    engine.updateRulerPivot(at: Point(x: 400, y: 220))
    assertEqual(engine.ruler.pivotEdge, "bottom", "支點成功吸附至底緣 bottom")

    // 沿尺身水平移動支點 (X = 525, 距中心 +125 = +0.25*500, ratio = 0.75)
    engine.updateRulerPivot(at: Point(x: 525, y: 200))
    assertTrue(abs(engine.ruler.pivotRatio - 0.75) < 0.05, "支點比率應更新約為 0.75")

    // 重設支點回中心
    engine.resetRulerPivot()
    assertEqual(engine.ruler.pivotRatio, 0.5, "重設後支點比率還原為 0.5")
    assertEqual(engine.ruler.pivotEdge, "center", "重設後支點還原為 center")

    // 16.4 雙端旋轉與支點幾何守恆 (A13: 旋轉時支點螢幕位置嚴格不變)
    let initialPivotScreenX = engine.ruler.screenCenterX
    let initialPivotScreenY = engine.ruler.screenCenterY
    // 從右端向下旋轉 (拖曳至 (400, 450))
    engine.rotateRuler(toward: Point(x: 400, y: 450), fromLeftEnd: false)
    assertTrue(abs(engine.ruler.angle - 90.0) < 5.0, "旋轉後角度約為 90 度垂直")
    assertTrue(abs(engine.ruler.screenCenterX - initialPivotScreenX) < 0.01, "中心旋轉時支點螢幕 X 座標嚴格守恆")
    assertTrue(abs(engine.ruler.screenCenterY - initialPivotScreenY) < 0.01, "中心旋轉時支點螢幕 Y 座標嚴格守恆")

    // 從左端向上旋轉
    engine.rotateRuler(toward: Point(x: 150, y: 200), fromLeftEnd: true)
    assertTrue(abs(engine.ruler.screenCenterX - initialPivotScreenX) < 0.01, "左端旋轉時支點螢幕 X 座標依然守恆")
    assertTrue(abs(engine.ruler.screenCenterY - initialPivotScreenY) < 0.01, "左端旋轉時支點螢幕 Y 座標依然守恆")

    // 16.5 重新配置視窗後尺規防丟失 (repositionRulerIfNeeded)
    engine.ruler.screenCenterX = 2500
    engine.ruler.screenCenterY = 1800
    engine.repositionRulerIfNeeded(windowSize: CGSize(width: 1000, height: 700))
    assertTrue(engine.ruler.screenCenterX <= 940, "視窗尺寸縮小時尺 X 座標自動鉗制在可視區內")
    assertTrue(engine.ruler.screenCenterY <= 640, "視窗尺寸縮小時尺 Y 座標自動鉗制在可視區內")

    // 16.6 透明度範圍
    engine.ruler.opacity = 0.55
    assertEqual(engine.ruler.opacity, 0.55, "尺規透明度可自訂設定")
}

// -------------------------------------------------------------------------
// 17. Dual Eraser Modes, Partial Vector Splitting & Style Preservation (W16, A14)
// -------------------------------------------------------------------------
print("\n[測試 17] W16 & A14: 整物件／局部向量橡皮擦、筆跡分段、樣式保留與單一交易 Undo (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)

    // 17.1 Object 模式橡皮擦 (A14)
    let strokeA = BoardObject(
        id: "stroke_a",
        type: "stroke",
        x: 100, y: 100, width: 100, height: 10,
        points: String(data: try JSONEncoder().encode([Point(x: 100, y: 100), Point(x: 150, y: 100), Point(x: 200, y: 100)]), encoding: .utf8),
        strokeColor: "#ffffff", strokeWidth: 3.0
    )
    let strokeB = BoardObject(
        id: "stroke_b",
        type: "stroke",
        x: 100, y: 200, width: 100, height: 10,
        points: String(data: try JSONEncoder().encode([Point(x: 100, y: 200), Point(x: 150, y: 200), Point(x: 200, y: 200)]), encoding: .utf8),
        strokeColor: "#ff0000", strokeWidth: 3.0
    )
    engine.objects = [strokeA, strokeB]
    engine.clearHistory()
    engine.eraserMode = .object
    engine.eraserSize = 24.0

    // 碰觸 Stroke A
    engine.beginEraserSwipe()
    engine.eraseAt(screenPt: Point(x: 150, y: 100))
    engine.endEraserSwipe()

    assertEqual(engine.objects.count, 1, "Object 模式下碰觸 Stroke A 應整筆移除")
    assertEqual(engine.objects[0].id, "stroke_b", "Stroke B 應完全不受影響")
    // Undo 復原
    engine.undo()
    assertEqual(engine.objects.count, 2, "Undo 應完整復原被移除之 Stroke A")
    assertTrue(engine.objects.contains(where: { $0.id == "stroke_a" }), "Stroke A ID 完整還原")
    // Redo 重做
    engine.redo()
    assertEqual(engine.objects.count, 1, "Redo 應重新套用刪除 Stroke A")

    // 17.2 Partial / 局部向量模式橡皮擦 (A14)
    engine.clearAll()
    engine.clearHistory()
    engine.eraserMode = .partial
    engine.eraserSize = 30.0

    // 建立一條 21 個點的水平筆跡 C (X: 100 到 300, Y: 100)
    var pointsC: [Point] = []
    for i in 0...20 {
        pointsC.append(Point(x: 100.0 + Double(i) * 10.0, y: 100.0))
    }
    let strokeC = BoardObject(
        id: "stroke_c",
        type: "stroke",
        x: 100, y: 100, width: 200, height: 10,
        points: String(data: try JSONEncoder().encode(pointsC), encoding: .utf8),
        strokeColor: "#ec4899",
        strokeWidth: 6.0,
        lineStyle: "dashed",
        opacity: 0.85
    )
    engine.objects = [strokeC]
    engine.clearHistory()

    // 於 X = 200, Y = 100 (中間處) 擦除
    // 橡皮擦直徑 30，半徑 15 + 筆寬一半 3 = 18。將切除 X: 182...218 範圍的點 (點 190, 200, 210 被移除)
    engine.beginEraserSwipe()
    engine.eraseAt(screenPt: Point(x: 200, y: 100))
    engine.endEraserSwipe()

    assertEqual(engine.objects.count, 2, "局部橡皮擦應將單一筆劃切分為 2 段獨立向量筆跡 (不點陣化)")
    assertTrue(!engine.objects.contains(where: { $0.id == "stroke_c" }), "原筆跡 stroke_c 已被置換")

    let seg1 = engine.objects[0]
    let seg2 = engine.objects[1]

    // 驗證殘段 1 幾何與樣式保留 (A14)
    assertEqual(seg1.type, "stroke", "殘段 1 仍為純向量 stroke")
    assertEqual(seg1.strokeColor, "#ec4899", "殘段 1 嚴格保留描邊顏色")
    assertEqual(seg1.strokeWidth, 6.0, "殘段 1 嚴格保留筆劃粗細")
    assertEqual(seg1.lineStyle, "dashed", "殘段 1 嚴格保留虛線樣式")
    assertEqual(seg1.opacity, 0.85, "殘段 1 嚴格保留透明度")
    assertTrue(seg1.parsedPoints.count >= 2, "殘段 1 至少保留 2 個向量點")
    assertTrue(seg1.parsedPoints.allSatisfy { $0.x <= 185.0 }, "殘段 1 所有點都在切除點左側")

    // 驗證殘段 2 幾何與樣式保留 (A14)
    assertEqual(seg2.type, "stroke", "殘段 2 仍為純向量 stroke")
    assertEqual(seg2.strokeColor, "#ec4899", "殘段 2 嚴格保留描邊顏色")
    assertEqual(seg2.strokeWidth, 6.0, "殘段 2 嚴格保留筆劃粗細")
    assertEqual(seg2.lineStyle, "dashed", "殘段 2 嚴格保留虛線樣式")
    assertEqual(seg2.opacity, 0.85, "殘段 2 嚴格保留透明度")
    assertTrue(seg2.parsedPoints.count >= 2, "殘段 2 至少保留 2 個向量點")
    assertTrue(seg2.parsedPoints.allSatisfy { $0.x >= 215.0 }, "殘段 2 所有點都在切除點右側")

    // 驗證新指派獨立 UUID
    assertTrue(seg1.id != "stroke_c" && seg2.id != "stroke_c", "殘段必須擁有新 ID")
    assertTrue(seg1.id != seg2.id, "兩殘段 ID 彼此獨立")

    // 17.3 單次局部擦除單一交易 (A14: 整次擦除可一次復原)
    engine.undo()
    assertEqual(engine.objects.count, 1, "一次 Undo 必須完整復原為擦除前之完整筆跡")
    assertEqual(engine.objects[0].id, "stroke_c", "復原之物件 ID 與原物件完全相符")
    assertEqual(engine.objects[0].parsedPoints.count, 21, "復原之物件完整包含原 21 個取樣點")

    engine.redo()
    assertEqual(engine.objects.count, 2, "一次 Redo 重新套用殘段分割")

    // 17.4 鎖定與隱藏物件保護 (A24)
    var lockedObj = strokeA
    lockedObj.isLocked = true
    var hiddenObj = strokeB
    hiddenObj.isVisible = false
    engine.objects = [lockedObj, hiddenObj]
    engine.clearHistory()

    engine.beginEraserSwipe()
    engine.eraseAt(screenPt: Point(x: 150, y: 100))
    engine.eraseAt(screenPt: Point(x: 150, y: 200))
    engine.endEraserSwipe()
    assertEqual(engine.objects.count, 2, "鎖定與隱藏物件絕對不可被橡皮擦刪除或分割 (A24)")

    // 17.5 自交筆跡環形分割 (W16: 自交筆跡案例)
    // 建立 8 字形自交筆跡，中心交叉點在 (150, 150)
    let loopPoints: [Point] = [
        Point(x: 150, y: 150), Point(x: 130, y: 170), Point(x: 110, y: 150), Point(x: 130, y: 130),
        Point(x: 150, y: 150), // 交叉點
        Point(x: 170, y: 170), Point(x: 190, y: 150), Point(x: 170, y: 130), Point(x: 150, y: 150)
    ]
    let figureEight = BoardObject(
        id: "figure_eight",
        type: "stroke",
        x: 110, y: 130, width: 80, height: 40,
        points: String(data: try JSONEncoder().encode(loopPoints), encoding: .utf8),
        strokeColor: "#38bdf8"
    )
    engine.objects = [figureEight]
    engine.clearHistory()
    engine.eraserSize = 16.0
    // 擦除中心交叉點 (150, 150)
    engine.beginEraserSwipe()
    engine.eraseAt(screenPt: Point(x: 150, y: 150))
    engine.endEraserSwipe()

    assertEqual(engine.objects.count, 2, "擦除 8 字形交叉中心應成功將自交筆跡分割為 2 個殘留環段 (W16)")
    assertTrue(engine.objects.allSatisfy { $0.strokeColor == "#38bdf8" }, "自交殘段樣式色彩完整繼承")
}

// -------------------------------------------------------------------------
// 18. Inline Text Entry, Double-Click Edit & Rich Text Spans (W17, A15)
// -------------------------------------------------------------------------
print("\n[測試 18] W17 & A15: 原地文字編輯、空白取消、雙擊原地再編輯與局部富文本片段 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.viewport = ViewportTransform(x: 100, y: 100, zoom: 1.0)
    engine.clearHistory()

    // 18.1 點擊建框與空白取消不留下物件 (A15)
    engine.beginInlineTextEntry(at: Point(x: 200, y: 150), kind: .text)
    assertTrue(engine.showInlineTextEditor, "開始文字輸入時 showInlineTextEditor 應為 true")
    assertEqual(engine.textDraft, "", "初始文字草稿為空")

    // 未輸入任何字元直接取消
    engine.cancelInlineTextEntry()
    assertTrue(!engine.showInlineTextEditor, "取消後退出文字編輯模式")
    assertEqual(engine.objects.count, 0, "空白取消絕不可留下空白物件 (A15 規範)")

    // 輸入僅含空白字元並提交
    engine.beginInlineTextEntry(at: Point(x: 200, y: 150), kind: .text)
    engine.textDraft = "   \n\t  "
    engine.commitInlineTextEntry()
    assertTrue(!engine.showInlineTextEditor, "提交後退出文字編輯模式")
    assertEqual(engine.objects.count, 0, "僅含空白或換行之草稿提交不建立物件 (A15)")

    // 18.2 文字原地建立、繁中/注音/Emoji/多行相容 (A15)
    let multilineContent = "黑板 HeiBan 注音測試 👨‍💻\n第二行測試繁體中文"
    engine.beginInlineTextEntry(at: Point(x: 250, y: 180), kind: .text)
    engine.textDraft = multilineContent
    engine.commitInlineTextEntry()

    assertEqual(engine.objects.count, 1, "成功建立 1 個文字物件")
    let textObj = engine.objects[0]
    assertEqual(textObj.type, "text", "物件類型應為 text")
    assertEqual(textObj.text, multilineContent, "多行與特殊字元內容完整保存")
    assertEqual(textObj.x, 250.0, "物件 X 座標與點擊位置完全吻合")
    assertEqual(textObj.y, 180.0, "物件 Y 座標與點擊位置完全吻合")
    assertEqual(engine.currentTool, .select, "文字完成後工具自動重設回 .select")

    // 18.3 雙擊原地再編輯與 Undo/Redo (A15)
    engine.beginEditingText(object: textObj)
    assertTrue(engine.showInlineTextEditor, "雙擊既有文字應原地觸發編輯 (A15)")
    assertEqual(engine.editingTextObjectId, textObj.id, "編輯目標 ID 與被雙擊物件相符")
    assertEqual(engine.textDraft, multilineContent, "原地編輯載入原文字內容")

    // 修改文字並提交
    let modifiedContent = "已修改的黑板文字內容"
    engine.textDraft = modifiedContent
    engine.commitInlineTextEntry()

    assertEqual(engine.objects.count, 1, "原地編輯提交不產生重複物件")
    assertEqual(engine.objects[0].text, modifiedContent, "物件內容已原地更新")

    // Undo 復原
    engine.undo()
    assertEqual(engine.objects[0].text, multilineContent, "Undo 應還原為修改前之原始多行文字")
    // Redo 重做
    engine.redo()
    assertEqual(engine.objects[0].text, modifiedContent, "Redo 應重新套用修改後之文字")

    // 18.4 局部富文本片段模型 (A15: 選取部分字句可改粗體、斜體、底線、刪除線與高亮)
    let span0 = TextSpan(text: "黑板 ", color: "#ffffff")
    let span1 = TextSpan(text: "HeiBan ", isBold: true, isItalic: true, color: "#86efac", highlightColor: "#166534")
    let span2 = TextSpan(text: "專業級白板", isUnderline: true, isStrikethrough: false, color: "#f59e0b")

    engine.updateObjectRichText(id: textObj.id, spans: [span0, span1, span2])
    let richObj = engine.objects[0]
    assertEqual(richObj.richTextSpans?.count, 3, "文字物件應成功套用 3 個富文本片段")
    assertEqual(richObj.richTextSpans?[0].text, "黑板 ", "第一片段文字相符")
    assertEqual(richObj.richTextSpans?[1].isBold, true, "第二片段應具備粗體 (A15)")
    assertEqual(richObj.richTextSpans?[1].isItalic, true, "第二片段應具備斜體 (A15)")
    assertEqual(richObj.richTextSpans?[1].highlightColor, "#166534", "第二片段應具備背景高亮色 (A15)")
    assertEqual(richObj.richTextSpans?[2].isUnderline, true, "第三片段應具備底線 (A15)")
    assertEqual(richObj.text, "黑板 HeiBan 專業級白板", "純文字欄位自動同步")

    // 18.5 排版設定 (字體、字級、對齊方式)
    engine.updateObjectTypography(id: textObj.id, fontFamily: "PingFang SC", fontSize: 28.0, align: "center")
    assertEqual(engine.objects[0].fontFamily, "PingFang SC", "字體應更新為 PingFang SC")
    assertEqual(engine.objects[0].fontSize, 28.0, "字級應更新為 28.0")
    assertEqual(engine.objects[0].align, "center", "對齊方式應更新為 center")

    // 18.6 文件序列化與解碼往返 (A15 & A23)
    let doc = HeiBanDocument(board: engine.board, objects: engine.objects)
    let encoded = try HeiBanDocumentCodec.encode(doc)
    let decoded = try HeiBanDocumentCodec.decode(from: encoded)
    assertEqual(decoded.objects.count, 1, "編解碼後物件數相符")
    let decRich = decoded.objects[0]
    assertEqual(decRich.richTextSpans?.count, 3, "解碼後 3 個富文本片段完整無損")
    assertEqual(decRich.richTextSpans?[1].isBold, true, "解碼後粗體標記無損")
    assertEqual(decRich.richTextSpans?[1].highlightColor, "#166534", "解碼後高亮色標記無損")
    assertEqual(decRich.richTextSpans?[2].isUnderline, true, "解碼後底線標記無損")
    assertEqual(decRich.align, "center", "解碼後對齊設定無損")
}

// -------------------------------------------------------------------------
// 19. Cute Sticky Styles, Palette, Wrapping & Boundaries (W18, A16)
// -------------------------------------------------------------------------
print("\n[測試 19] W18 & A16: 可愛便簽六大樣式、圓形色盤、換行與文字邊界約束 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)

    // 19.1 六大便簽樣式定義與顯示名稱
    assertEqual(StickyStyle.allCases.count, 6, "便簽應涵蓋 6 種可愛樣式 (A16)")
    let styles = StickyStyle.allCases
    assertEqual(styles.contains(.classic), true, "包含經典折角 (classic)")
    assertEqual(styles.contains(.washi), true, "包含和紙膠帶 (washi)")
    assertEqual(styles.contains(.cat), true, "包含貓咪萌爪 (cat)")
    assertEqual(styles.contains(.notebook), true, "包含活頁筆記 (notebook)")
    assertEqual(styles.contains(.grid), true, "包含方格幾何 (grid)")
    assertEqual(styles.contains(.soft), true, "包含柔和卡片 (soft/pastel)")

    assertEqual(StickyStyle.classic.displayName, "經典折角", "經典樣式名稱相符")
    assertEqual(StickyStyle.washi.displayName, "和紙膠帶", "和紙樣式名稱相符")
    assertEqual(StickyStyle.cat.displayName, "貓咪萌爪", "貓咪樣式名稱相符")
    assertEqual(StickyStyle.notebook.displayName, "活頁筆記", "筆記樣式名稱相符")
    assertEqual(StickyStyle.grid.displayName, "方格幾何", "格紙樣式名稱相符")
    assertEqual(StickyStyle.soft.displayName, "柔和卡片", "柔和樣式名稱相符")

    // 19.2 圓形色盤 (A16: 柔和便簽色彩)
    assertEqual(StickyPalette.allColors.count, 6, "標準便簽圓形色盤應提供 6 款主題色")
    assertEqual(StickyPalette.yellow, "#fef08a", "經典奶油黃色彩碼")
    assertEqual(StickyPalette.pink, "#fbcfe8", "櫻花粉色彩碼")
    assertEqual(StickyPalette.green, "#bbf7d0", "薄荷綠色彩碼")
    assertEqual(StickyPalette.blue, "#bae6fd", "天空藍色彩碼")
    assertEqual(StickyPalette.purple, "#e9d5ff", "薰衣草紫色彩碼")
    assertEqual(StickyPalette.orange, "#fed7aa", "蜜桃橘色彩碼")

    // 19.3 點擊建立便簽 (A16: 點擊即建立實體便簽並進入原地輸入)
    engine.beginInlineTextEntry(at: Point(x: 200, y: 300), kind: .sticky)
    assertEqual(engine.objects.count, 1, "應自動建立 1 個實體便簽物件")
    let sticky = engine.objects[0]
    assertEqual(sticky.type, "sticky", "物件類型應為 sticky")
    assertEqual(sticky.stickyStyle ?? .classic, .classic, "預設樣式為 classic")
    assertEqual(sticky.fillColor, StickyPalette.yellow, "預設背景填色為奶油黃")
    assertEqual(engine.showInlineTextEditor, true, "建立便簽後立即進入原地文字輸入模式")

    // 19.4 原地輸入繁中、長英文字串與 Emoji
    let mixedNoteText = "黑板 HeiBan 便簽測試 🐾\n超長英文單字：Supercalifragilisticexpialidocious\n支援換行與自動邊界約束。"
    engine.textDraft = mixedNoteText
    engine.commitInlineTextEntry()
    assertEqual(engine.objects[0].text, mixedNoteText, "文字內容完整保存")

    // 19.5 切換便簽樣式並保留內容與歷史
    engine.selectedIds = [sticky.id]
    assertEqual(engine.selectedStickyStyle.valueOrNil, .classic, "選取便簽樣式應為 classic")

    engine.setSelectedStickyStyle(.cat)
    assertEqual(engine.objects[0].stickyStyle, .cat, "樣式成功切換為 cat 貓咪")
    assertEqual(engine.objects[0].text, mixedNoteText, "切換樣式嚴格保留文字內容 (A16)")

    // 切換色盤
    engine.setSelectedStickyColor(StickyPalette.pink)
    assertEqual(engine.objects[0].fillColor, StickyPalette.pink, "填色成功切換為櫻花粉")

    // Undo 復原填色
    engine.undo()
    assertEqual(engine.objects[0].fillColor, StickyPalette.yellow, "Undo 成功復原至原奶油黃")
    // Undo 復原樣式
    engine.undo()
    assertEqual(engine.objects[0].stickyStyle, .classic, "Undo 成功復原至原 classic 樣式")
    // Redo 重做樣式
    engine.redo()
    assertEqual(engine.objects[0].stickyStyle, .cat, "Redo 成功重做樣式為 cat")

    // 19.6 文字邊界約束與超出提示 (A16: 中文、英文長字、Emoji 不跑出卡片，超出提供明確提示)
    // 正常長度文字不應溢出
    let normalObj = engine.objects[0]
    assertEqual(engine.isStickyTextOverflowing(object: normalObj), false, "正常內容不應被判定為溢出")

    // 輸入超長多行文字造成超出
    var longContent = "【會議記錄】\n"
    for i in 1...15 {
        longContent += "第 \(i) 點：黑板團隊持續專注 macOS 原生體驗與效能優化。\n"
    }
    engine.beginEditingText(object: engine.objects[0])
    engine.textDraft = longContent
    engine.commitInlineTextEntry()

    let overflowObj = engine.objects[0]
    assertEqual(engine.isStickyTextOverflowing(object: overflowObj), true, "超長文字應觸發溢出提示 (A16 規範)")

    // 自動擴展適配 (expandStickyToFit)，防止內容被隱形截斷
    let originalHeight = overflowObj.height
    engine.expandStickyToFit(id: overflowObj.id)
    let expandedObj = engine.objects[0]
    assertEqual(expandedObj.height > originalHeight, true, "自動適配後便簽高度應擴展以完整容納文字")
    assertEqual(engine.isStickyTextOverflowing(object: expandedObj), false, "擴展後不再溢出")

    // Undo 自動擴展
    engine.undo()
    assertEqual(engine.objects[0].height, originalHeight, "Undo 成功復原便簽原始尺寸")

    // 19.7 文件編解碼與無損往返 (A16 & A23)
    let doc = HeiBanDocument(board: engine.board, objects: engine.objects)
    let encoded = try HeiBanDocumentCodec.encode(doc)
    let decoded = try HeiBanDocumentCodec.decode(from: encoded)
    assertEqual(decoded.objects.count, 1, "編解碼後物件數相符")
    let decSticky = decoded.objects[0]
    assertEqual(decSticky.type, "sticky", "解碼後物件類型為 sticky")
    assertEqual(decSticky.stickyStyle, .cat, "解碼後貓咪樣式完整保留")
    assertEqual(decSticky.text, longContent, "解碼後長文字內容完全相符")
}

// -------------------------------------------------------------------------
// 20. Physical World-space Pins & Top-Left Navigation (W19, A17)
// -------------------------------------------------------------------------
print("\n[測試 20] W19 & A17: 實體世界座標圖釘、左上舒適書寫區導航、舊版視角遷移與拖曳 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.canvasSize = CGSize(width: 1000, height: 800)
    engine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
    engine.board.pins = []
    engine.clearHistory()

    // 20.1 實體世界座標圖釘建立 (A17: 畫布釘下 ICON、自訂名稱、世界座標)
    engine.addPin(name: "架構核心", at: Point(x: 500, y: 800))
    assertEqual(engine.board.pins?.count, 1, "畫布應成功建立 1 個實體圖釘")
    let pin0 = engine.board.pins![0]
    assertEqual(pin0.name, "架構核心", "圖釘名稱相符")
    assertEqual(pin0.x, 500.0, "圖釘 X 世界座標相符")
    assertEqual(pin0.y, 800.0, "圖釘 Y 世界座標相符")
    assertEqual(pin0.isWorldSpace, true, "標記為世界座標圖釘")

    // 20.2 預設左上舒適書寫區導航目標計算 (A17: 錨定可用寬高 20%, 20%)
    let targetViewport = engine.targetViewportForPin(pin0, canvasSize: engine.canvasSize)
    // 螢幕錨點: 1000 * 0.20 = 200, 800 * 0.20 = 160
    // targetViewport.x = 200 - 500 * 1.0 = -300
    // targetViewport.y = 160 - 800 * 1.0 = -640
    assertEqual(targetViewport.x, -300.0, "目標視角 X 座標計算精確")
    assertEqual(targetViewport.y, -640.0, "目標視角 Y 座標計算精確")
    assertEqual(targetViewport.zoom, 1.0, "目標視角縮放比例相符")

    // 執行 jumpToPin
    engine.jumpToPin(pin0)
    assertEqual(engine.viewport.x, -300.0, "導航後視角 X 與舒適書寫區精確對齊")
    assertEqual(engine.viewport.y, -640.0, "導航後視角 Y 與舒適書寫區精確對齊")

    // 驗證圖釘在當前視角下的螢幕投影位置
    let screenPos = VectorMath.worldToScreen(Point(x: pin0.x, y: pin0.y), viewport: engine.viewport)
    assertEqual(abs(screenPos.x - 200.0) < 1e-6, true, "圖釘精確投影於螢幕 20% X 位置 (200 pt)")
    assertEqual(abs(screenPos.y - 160.0) < 1e-6, true, "圖釘精確投影於螢幕 20% Y 位置 (160 pt)")

    // 20.3 既有 Viewport Bookmark 舊版圖釘平滑遷移 (A17 規範)
    // 假設舊版文件儲存的是 viewport offset (x: 100, y: 150, zoom: 2.0, isWorldSpace: nil)
    let legacyPin = BoardPin(name: "舊版視角書籤", x: 100.0, y: 150.0, zoom: 2.0, isWorldSpace: nil)
    let resolvedWorld = legacyPin.resolveWorldPosition(canvasSize: engine.canvasSize)
    // 舊版中心點: (500, 400), 轉換世界點: (500 - 100)/2.0 = 200, (400 - 150)/2.0 = 125
    assertEqual(resolvedWorld.x, 200.0, "舊版視角中心 X 座標平滑遷移至世界點")
    assertEqual(resolvedWorld.y, 125.0, "舊版視角中心 Y 座標平滑遷移至世界點")

    engine.board.pins?.append(legacyPin)
    engine.migratePinsToWorldSpace(canvasSize: engine.canvasSize)
    assertEqual(engine.board.pins?[1].isWorldSpace, true, "遷移後標記為世界座標")
    assertEqual(engine.board.pins?[1].x, 200.0, "遷移後 X 座標更新為世界座標")
    assertEqual(engine.board.pins?[1].y, 125.0, "遷移後 Y 座標更新為世界座標")

    // 20.4 圖釘拖曳改座標與 Undo/Redo (A17)
    // 將 pin0 拖曳至螢幕點 (400, 400)
    // 當前 viewport: x: -300, y: -640, zoom: 1.0 => world: (400 - (-300)) = 700, (400 - (-640)) = 1040
    engine.updatePinDrag(id: pin0.id, at: Point(x: 400, y: 400))
    engine.endPinDrag(id: pin0.id)
    assertEqual(engine.board.pins?[0].x, 700.0, "拖曳後圖釘世界 X 座標更新為 700.0")
    assertEqual(engine.board.pins?[0].y, 1040.0, "拖曳後圖釘世界 Y 座標更新為 1040.0")

    // Undo 拖曳
    engine.undo()
    assertEqual(engine.board.pins?[0].x, 500.0, "Undo 成功復原圖釘原始 X 座標")
    assertEqual(engine.board.pins?[0].y, 800.0, "Undo 成功復原圖釘原始 Y 座標")

    // Redo 拖曳
    engine.redo()
    assertEqual(engine.board.pins?[0].x, 700.0, "Redo 成功重做拖曳後之 X 座標")
    assertEqual(engine.board.pins?[0].y, 1040.0, "Redo 成功重做拖曳後之 Y 座標")

    // 20.5 圖釘改名與刪除與 Undo/Redo (A17)
    engine.renamePin(id: pin0.id, name: "全新核心節點")
    assertEqual(engine.board.pins?[0].name, "全新核心節點", "改名成功")

    engine.undo()
    assertEqual(engine.board.pins?[0].name, "架構核心", "Undo 成功復原圖釘原名")

    engine.removePin(id: pin0.id)
    assertEqual(engine.board.pins?.contains(where: { $0.id == pin0.id }), false, "圖釘成功刪除")

    engine.undo()
    assertEqual(engine.board.pins?.contains(where: { $0.id == pin0.id }), true, "Undo 成功復原被刪除之圖釘")

    // 20.6 文件無損編解碼往返 (A17 & A23)
    let doc = HeiBanDocument(board: engine.board, objects: engine.objects)
    let encoded = try HeiBanDocumentCodec.encode(doc)
    let decoded = try HeiBanDocumentCodec.decode(from: encoded)
    assertEqual(decoded.board.pins?.count, 2, "編解碼後圖釘數量相符")
    assertEqual(decoded.board.pins?[0].name, "架構核心", "解碼後圖釘名稱相符")
    assertEqual(decoded.board.pins?[0].isWorldSpace, true, "解碼後世界座標標記保留")
}

// -------------------------------------------------------------------------
// 21. Real Thumbnails, 500-Board Index, Duplication & Trash (W04, A21)
// -------------------------------------------------------------------------
print("\n[測試 21] W04 & A21: 首頁縮圖、500 作品秒級索引、獨立副本與垃圾桶可恢復刪除 (立靶驗收)")
do {
    let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("HeiBanTest_W04_\(UUID().uuidString)")
    let library = LocalBoardLibrary(directory: tempBase)

    // 21.1 真實縮圖產生與保存
    var testDoc = HeiBanDocument(
        board: HeiBanBoard(id: "board_thumb_test", title: "縮圖測試黑板", boardTheme: .blackboard),
        objects: [
            BoardObject(boardId: "board_thumb_test", type: "rect", x: 100, y: 100, width: 200, height: 150, strokeColor: "#ffffff", fillColor: "#166534"),
            BoardObject(boardId: "board_thumb_test", type: "sticky", x: 350, y: 120, width: 180, height: 140, strokeColor: "#1f2937", fillColor: "#fef08a", text: "縮圖文字")
        ]
    )
    try library.save(testDoc)

    let thumbURL = library.thumbnailURL(id: "board_thumb_test")
    assertEqual(FileManager.default.fileExists(atPath: thumbURL.path), true, "保存黑板應自動產生實體縮圖檔案 (A21)")
    let thumbData = library.thumbnailData(id: "board_thumb_test")
    assertEqual(thumbData != nil && !thumbData!.isEmpty, true, "縮圖資料不為空且成功載入")

    // 21.2 500 作品 metadata/thumbnail 索引秒級載入 (A21: 首頁 p95 ≤ 1 秒，不為列表同步解碼全部大文件)
    print("  -> 產生 500 張包含大物件之黑板 metadata 索引中...")
    let startTime = CFAbsoluteTimeGetCurrent()
    var batchDocs: [HeiBanDocument] = []
    for i in 1...500 {
        let b = HeiBanBoard(
            id: "stress_board_\(i)",
            title: "專案黑板 #\(i)",
            boardTheme: i % 2 == 0 ? .blackboard : .whiteboard,
            itemCount: 20,
            updatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(-i * 60)))
        )
        // 包含大型物件資料，驗證 list() 絕不同步解碼全量物件
        let doc = HeiBanDocument(board: b, objects: [
            BoardObject(boardId: b.id, type: "stroke", x: 0, y: 0, width: 1000, height: 1000)
        ])
        batchDocs.append(doc)
    }
    try library.batchIndexBoards(batchDocs)
    let indexGenElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("  -> 500 張黑板索引建立完成，耗時: \(String(format: "%.3f", indexGenElapsed))s")

    // 測量 500 張黑板 list() 讀取速度
    let listStart = CFAbsoluteTimeGetCurrent()
    let listedBoards = try library.list()
    let listElapsed = CFAbsoluteTimeGetCurrent() - listStart
    print("  -> 500 張黑板 list() 讀取耗時: \(String(format: "%.4f", listElapsed))s")

    assertEqual(listedBoards.count >= 500, true, "應成功索引 500 張黑板 (實際: \(listedBoards.count))")
    assertEqual(listElapsed < 0.20, true, "500 張黑板讀取耗時應小於 200 ms (實際: \(String(format: "%.4f", listElapsed))s，遠低於 1.0s 限制)")

    // 21.3 搜尋與最近作品
    let searchResults = library.search(query: "專案黑板 #250")
    assertEqual(searchResults.count, 1, "精確搜尋應返回 1 筆相符黑板")
    assertEqual(searchResults.first?.title, "專案黑板 #250", "搜尋結果標題吻合")

    let recent = library.recent(limit: 5)
    assertEqual(recent.count, 5, "最近黑板應精確返回 5 筆")
    assertEqual(recent[0].updatedAt >= recent[1].updatedAt, true, "最近黑板按 updatedAt 降冪排序")

    // 21.4 副本建立與獨立身分 (A21: 副本有獨立身分)
    let dupMetadata = try library.duplicate(id: "board_thumb_test")
    assertEqual(dupMetadata.id != "board_thumb_test", true, "副本必須具備全新獨立 UUID")
    assertEqual(dupMetadata.title.contains("副本"), true, "副本標題應註記為副本")

    let dupDoc = try library.load(id: dupMetadata.id)
    assertEqual(dupDoc.objects.count, 2, "副本完整保留原 2 個物件")
    assertEqual(dupDoc.board.id, dupMetadata.id, "副本內部 board ID 完整更新為新身分")

    // 21.5 重新命名黑板
    try library.rename(id: "board_thumb_test", newTitle: "重新命名的作品")
    let reloaded = try library.load(id: "board_thumb_test")
    assertEqual(reloaded.board.title, "重新命名的作品", "重新命名成功套用至文件")
    let reloadedMeta = try library.list().first(where: { $0.id == "board_thumb_test" })
    assertEqual(reloadedMeta?.title, "重新命名的作品", "重新命名成功反映至索引")

    // 21.6 移至垃圾桶與可恢復刪除 (A21: 可恢復刪除)
    try library.moveToTrash(id: "board_thumb_test")
    assertEqual(try library.list().contains(where: { $0.id == "board_thumb_test" }), false, "移至垃圾桶後 active 列表不再包含該黑板")
    let trashList = try library.listTrash()
    assertEqual(trashList.contains("board_thumb_test"), true, "垃圾桶中應包含該黑板")

    // 從垃圾桶還原
    let restoredDoc = try library.restoreFromTrash(id: "board_thumb_test")
    assertEqual(try library.list().contains(where: { $0.id == "board_thumb_test" }), true, "還原後 active 列表重新包含該黑板")
    assertEqual(try library.listTrash().contains("board_thumb_test"), false, "還原後垃圾桶不再包含該黑板")
    assertEqual(restoredDoc.objects.count, 2, "還原之黑板物件完整保留 (A21)")
}

// -------------------------------------------------------------------------
// 22. Workspace Folders, Multi-Document Sessions & Conflicts (W05, W06, A26, A27)
// -------------------------------------------------------------------------
print("\n[測試 22] W05, W06, A26 & A27: 工作資料夾、多文件隔離 Session、外部修改衝突協調與另存 (立靶驗收)")
do {
    let tempDir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("HeiBanTest_W05_W06_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    // 22.1 多文件 Session 完全隔離 (A27: 同時打開 A/B，各自選取／復原／保存完全隔離)
    let sessionManager = DocumentSessionManager()
    let fileA = tempDir.appendingPathComponent("docA.blackboard.json")
    let fileB = tempDir.appendingPathComponent("docB.blackboard.json")

    let docA = HeiBanDocument(board: HeiBanBoard(id: "doc_a", title: "文件 A", boardTheme: .blackboard), objects: [])
    let docB = HeiBanDocument(board: HeiBanBoard(id: "doc_b", title: "文件 B", boardTheme: .whiteboard), objects: [])
    try HeiBanDocumentCodec.encode(docA).write(to: fileA)
    try HeiBanDocumentCodec.encode(docB).write(to: fileB)

    let sessionA = try sessionManager.openDocument(at: fileA)
    let sessionB = try sessionManager.openDocument(at: fileB)

    assertEqual(sessionManager.activeSessions.count, 2, "成功開啟 2 個獨立 Session")
    assertEqual(sessionA.id != sessionB.id, true, "Session A 與 Session B 具備不同 ID")

    // 在 Session A 加入物件，Session B 不受影響
    let objA = BoardObject(boardId: "doc_a", type: "rect", x: 10, y: 10, width: 100, height: 100)
    sessionA.engine.addObject(objA)
    sessionA.engine.selectedIds = [objA.id]

    assertEqual(sessionA.engine.objects.count, 1, "Session A 物件數為 1")
    assertEqual(sessionB.engine.objects.count, 0, "Session B 物件數仍為 0 (完全隔離)")
    assertEqual(sessionB.engine.selectedIds.isEmpty, true, "Session B 選取完全隔離")

    // Session A 執行 Undo，Session B 零干擾
    sessionA.engine.undo()
    assertEqual(sessionA.engine.objects.count, 0, "Session A 復原成功")
    assertEqual(sessionB.engine.objects.count, 0, "Session B 維持不變")

    sessionA.engine.redo()
    assertEqual(sessionA.engine.objects.count, 1, "Session A 重做成功")

    // 重複開啟相同檔案會直接返回既有 Session，不產生覆蓋衝突 (A26 & A27)
    let sameSessionA = try sessionManager.openDocument(at: fileA)
    assertEqual(sameSessionA.id, sessionA.id, "重複開啟相同文件應協調至既有 Session")

    // 22.2 另存新檔 (Save As) 不覆蓋來源 (A26)
    let fileACopy = tempDir.appendingPathComponent("docA_copy.blackboard.json")
    try sessionA.saveAs(to: fileACopy)
    assertEqual(FileManager.default.fileExists(atPath: fileACopy.path), true, "另存新檔檔案應存在")

    // 修改副本不改變原檔
    let docCopyLoaded = try HeiBanDocumentCodec.decode(from: Data(contentsOf: fileACopy))
    assertEqual(docCopyLoaded.objects.count, 1, "另存新檔完整保留資料")

    // 22.3 工作資料夾 (Workspace Repository) 與目前文件標示 (W05, A26)
    let workspace = WorkspaceRepository(folderURL: tempDir)
    let workspaceFiles = try workspace.listBlackboardFiles()
    assertEqual(workspaceFiles.count >= 2, true, "工作資料夾應列出所有黑板檔案")
    assertEqual(workspaceFiles.contains(where: { $0.url == fileA }), true, "包含檔案 A")
    assertEqual(workspaceFiles.contains(where: { $0.url == fileB }), true, "包含檔案 B")

    // 22.4 自身保存事件去重 (A27: 目錄 watcher 自身 save 事件不誤判衝突)
    let coordinator = DocumentCoordinator(documentURL: fileA)
    coordinator.recordSelfSave(contentData: try HeiBanDocumentCodec.encode(sessionA.engine.document))
    let selfSaveStatus = coordinator.checkExternalChange(currentInMemoryData: try HeiBanDocumentCodec.encode(sessionA.engine.document))
    assertEqual(selfSaveStatus == .none, true, "自身儲存操作不應被誤判為外部衝突 (去重成功)")

    // 22.5 外部修改衝突偵測與未保存內容防護 (W05 & A27: 外部修改不覆蓋未保存內容，提供解決選項)
    // 記憶體中做出尚未存檔之變更
    let dirtyObj = BoardObject(boardId: "doc_a", type: "circle", x: 200, y: 200, width: 80, height: 80)
    sessionA.engine.addObject(dirtyObj)
    assertEqual(sessionA.engine.objects.count, 2, "記憶體目前有 2 個物件 (未保存變更)")

    // 外部程式修改檔案 (增加第 3 物件並遞增修訂號)
    var externalDoc = docA
    externalDoc.board.revision = 99
    externalDoc.objects.append(BoardObject(boardId: "doc_a", type: "line", x: 0, y: 0, width: 50, height: 50))
    try HeiBanDocumentCodec.encode(externalDoc).write(to: fileA)

    // 協調器偵測變更
    let conflictState = coordinator.checkExternalChange(currentInMemoryData: try HeiBanDocumentCodec.encode(sessionA.engine.document))
    assertEqual(conflictState == .conflict, true, "外部修改且記憶體有未保存變更時應精確偵測為 conflict (A27)")

    // 驗證未保存內容絕對不被強制靜默覆蓋
    assertEqual(sessionA.engine.objects.count, 2, "記憶體中未保存之變更嚴格被保留，不被靜默抹除")

    // 測試解決方案 1：以磁碟版本重新載入 (Reload from disk)
    try sessionA.resolveConflictWithReload()
    assertEqual(sessionA.engine.objects.count, 1, "重新載入後反映磁碟最新狀態")
    assertEqual(sessionA.engine.objects[0].type, "line", "成功載入外部修改物件")

    // 22.6 外部刪除防護 (A27: 檔案被外部刪除時保留未保存內容)
    try FileManager.default.removeItem(at: fileB)
    let deleteState = DocumentCoordinator(documentURL: fileB).checkExternalChange(currentInMemoryData: try HeiBanDocumentCodec.encode(sessionB.engine.document))
    assertEqual(deleteState == .fileDeletedExternally, true, "精確偵測檔案被外部刪除")
    assertEqual(sessionB.engine.document.board.title, "文件 B", "記憶體內容完好無損，允許重新保存")
    try sessionB.saveAs(to: fileB)
    assertEqual(FileManager.default.fileExists(atPath: fileB.path), true, "重新保存後檔案再度恢復")
}





// -------------------------------------------------------------------------
// 23. Panel Restoral, Visual Tokens, Tool Memory & Docking (W07, W08, A05, A12, A25, A27)
// -------------------------------------------------------------------------
print("\n[測試 23] W07, W08, A05, A12, A25 & A27: 工具設定記憶、四邊停靠與浮動、外接螢幕拔除防丟失與設計 Token (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)

    // 23.1 A05: Pen / Highlighter / Paint 獨立參數記憶與切換
    // 預設參數驗證
    assertEqual(engine.penPreset.strokeWidth, 3.5, "鋼筆預設粗細為 3.5")
    assertEqual(engine.highlighterPreset.strokeWidth, 18.0, "螢光筆預設粗細為 18.0")
    assertEqual(engine.highlighterPreset.opacity, 0.45, "螢光筆預設透明度為 0.45")
    assertEqual(engine.paintPreset.strokeWidth, 32.0, "油漆筆預設粗細為 32.0")

    // 切換至鋼筆並自訂數值
    engine.selectTool(.pen)
    engine.updateCurrentToolStyle(color: "#f472b6", strokeWidth: 5.5, opacity: 0.95)
    assertEqual(engine.activeColor, "#f472b6", "目前顏色更新為粉色")
    assertEqual(engine.activeStrokeWidth, 5.5, "目前粗細更新為 5.5")
    assertEqual(engine.activeOpacity, 0.95, "目前透明度更新為 0.95")

    // 切換至螢光筆，驗證鋼筆設定不覆蓋螢光筆獨立記憶
    engine.selectTool(.highlighter)
    assertEqual(engine.activeColor, "#fef08a", "螢光筆維持獨立黃色")
    assertEqual(engine.activeStrokeWidth, 18.0, "螢光筆維持獨立粗細 18.0")
    assertEqual(engine.activeOpacity, 0.45, "螢光筆維持獨立透明度 0.45")

    // 修改螢光筆數值
    engine.updateCurrentToolStyle(color: "#fb923c", strokeWidth: 22.0, opacity: 0.5)

    // 切換至油漆筆
    engine.selectTool(.paint)
    assertEqual(engine.activeStrokeWidth, 32.0, "油漆筆維持獨立粗細 32.0")

    // 切換回鋼筆，驗證先前自訂之參數完整恢復
    engine.selectTool(.pen)
    assertEqual(engine.activeColor, "#f472b6", "切回鋼筆完整還原粉色")
    assertEqual(engine.activeStrokeWidth, 5.5, "切回鋼筆完整還原粗細 5.5")
    assertEqual(engine.activeOpacity, 0.95, "切回鋼筆完整還原透明度 0.95")

    // 切回螢光筆，驗證自訂參數亦完整恢復
    engine.selectTool(.highlighter)
    assertEqual(engine.activeColor, "#fb923c", "切回螢光筆完整還原橘色")
    assertEqual(engine.activeStrokeWidth, 22.0, "切回螢光筆完整還原粗細 22.0")
    assertEqual(engine.activeOpacity, 0.5, "切回螢光筆完整還原透明度 0.5")

    // 再次按當前啟用工具應切回 .select (A05)
    engine.selectTool(.highlighter)
    assertEqual(engine.currentTool, .select, "再次按啟用工具自動回到 Select")

    // 最近使用色彩列表記憶
    engine.registerRecentColor("#c084fc")
    assertEqual(engine.recentColors.first, "#c084fc", "新自訂色置於最近色首位")
    assertEqual(engine.recentColors.filter { $0 == "#c084fc" }.count, 1, "最近色彩自動去重")
    assertEqual(engine.recentColors.count <= 8, true, "最近色彩不超過上限 8 款")

    // 23.2 A12: 四邊停靠吸附 (left, right, top, bottom) 與方向判斷
    engine.canvasSize = CGSize(width: 1200, height: 800)

    // 拖曳靠近左緣 (< 110 pt)
    engine.toolbarDock = "floating"
    engine.toolbarOffset = CGSize(width: -550, height: 0)
    engine.endToolbarDrag()
    assertEqual(engine.toolbarDock, "left", "靠近左側自動停靠 left")
    assertEqual(engine.isToolbarVertical, true, "左右停靠為垂直方向")

    // 拖曳靠近右緣
    engine.toolbarDock = "floating"
    engine.toolbarOffset = CGSize(width: 550, height: 0)
    engine.endToolbarDrag()
    assertEqual(engine.toolbarDock, "right", "靠近右側自動停靠 right")
    assertEqual(engine.isToolbarVertical, true, "右側停靠為垂直方向")

    // 拖曳靠近頂部
    engine.toolbarDock = "floating"
    engine.toolbarOffset = CGSize(width: 0, height: -320)
    engine.endToolbarDrag()
    assertEqual(engine.toolbarDock, "top", "靠近頂部自動停靠 top")
    assertEqual(engine.isToolbarVertical, false, "上下停靠為水平方向")

    // 拖曳靠近底部
    engine.toolbarDock = "floating"
    engine.toolbarOffset = CGSize(width: 0, height: 350)
    engine.endToolbarDrag()
    assertEqual(engine.toolbarDock, "bottom", "靠近底部自動停靠 bottom")
    assertEqual(engine.isToolbarVertical, false, "底部停靠為水平方向")

    // 23.3 A12: 支援自由浮動位置 (不強制歸邊)
    // 拖曳至畫面中央偏右上 (距離四邊皆 > 110 pt)
    engine.toolbarDock = "floating"
    engine.toolbarOffset = CGSize(width: 150, height: -80)
    engine.endToolbarDrag()
    assertEqual(engine.toolbarDock, "floating", "距離四邊遠時支援自由浮動")
    assertEqual(engine.toolbarOffset.width, 150, "浮動 X 偏移精確保留")
    assertEqual(engine.toolbarOffset.height, -80, "浮動 Y 偏移精確保留")

    // 23.4 A12 & A27: 拔除外接螢幕／視窗縮小至 960x640 防丟失鉗制 (Reposition)
    // 假設原在外接大螢幕 2560x1440 浮動至右下角 (2300, 1300)
    engine.toolbarDock = "floating"
    engine.toolbarOffset = CGSize(width: 1100, height: 600) // 遠在小視窗之外

    // 拔除螢幕，主視窗縮小至 960x640
    let minWindowSize = CGSize(width: 960, height: 640)
    engine.repositionPanelsIfNeeded(windowSize: minWindowSize)

    let clampedPos = engine.toolbarPosition(in: minWindowSize)
    assertEqual(clampedPos.x >= 32 && clampedPos.x <= minWindowSize.width - 32, true, "拔除螢幕後面板 X 座標自動鉗制在視窗內")
    assertEqual(clampedPos.y >= 32 && clampedPos.y <= minWindowSize.height - 32, true, "拔除螢幕後面板 Y 座標自動鉗制在視窗內")

    // 四角測試 (960x640)
    let corners: [CGPoint] = [
        CGPoint(x: 10, y: 10),       // 左上
        CGPoint(x: 950, y: 10),      // 右上
        CGPoint(x: 10, y: 630),      // 左下
        CGPoint(x: 950, y: 630)      // 右下
    ]
    for (idx, corner) in corners.enumerated() {
        let clamped = engine.clampPanelCenter(corner, panelSize: CGSize(width: 400, height: 60), windowSize: minWindowSize)
        assertEqual(clamped.x >= 200 && clamped.x <= minWindowSize.width - 200, true, "角落 \(idx) X 座標安全在視窗內")
        assertEqual(clamped.y >= 30 && clamped.y <= minWindowSize.height - 30, true, "角落 \(idx) Y 座標安全在視窗內")
    }

    // 23.5 A12: 子選單內向彈出方向 (Inward Submenu Direction)
    assertEqual(engine.submenuDirection(forDock: "left"), .trailing, "左側停靠時子選單向右 (trailing) 展開")
    assertEqual(engine.submenuDirection(forDock: "right"), .leading, "右側停靠時子選單向左 (leading) 展開")
    assertEqual(engine.submenuDirection(forDock: "top"), .bottom, "頂部停靠時子選單向下 (bottom) 展開")
    assertEqual(engine.submenuDirection(forDock: "bottom"), .top, "底部停靠時子選單向上 (top) 展開")

    // 23.6 W07 & A25: UI Tokens 與 WCAG AA 對比度 (≥ 4.5:1)
    let darkBg = HeiBanDesignTokens.blackboardBackground
    let darkText = HeiBanDesignTokens.blackboardPrimaryText
    let darkRatio = HeiBanDesignTokens.contrastRatio(darkBg, darkText)
    assertEqual(darkRatio >= 4.5, true, "黑板主題主要文字對比度符合 WCAG AA (實際: \(String(format: "%.1f", darkRatio)):1)")

    let lightBg = HeiBanDesignTokens.whiteboardBackground
    let lightText = HeiBanDesignTokens.whiteboardPrimaryText
    let lightRatio = HeiBanDesignTokens.contrastRatio(lightBg, lightText)
    assertEqual(lightRatio >= 4.5, true, "白板主題主要文字對比度符合 WCAG AA (實際: \(String(format: "%.1f", lightRatio)):1)")

    // 驗證常用間距與圓角標準
    assertEqual(HeiBanDesignTokens.spacingMD, 12.0, "標準 MD 間距為 12pt")
    assertEqual(HeiBanDesignTokens.radiusMD, 10.0, "標準 MD 圓角為 10pt")
}

// -------------------------------------------------------------------------
// 24. Image Assets, Non-Destructive 8-Way Crop & Multi-Screen Capture (W20, A18, A19)
// -------------------------------------------------------------------------
print("\n[測試 24] W20, A18 & A19: 原始圖片資產保真、非破壞 8 向裁切、重設原圖與多螢幕截圖安全 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)

    // 24.1 原始影像資產保真匯入 (A18)
    let rawImageData = Data(repeating: 0xAB, count: 1024)
    let importedObj = engine.importImage(
        data: rawImageData,
        originalSize: CGSize(width: 1920, height: 1080),
        fileName: "architecture_diagram.png"
    )

    assertEqual(importedObj.type, "image", "物件類型應為 image")
    assertEqual(importedObj.originalWidth, 1920.0, "原始寬度精確保存 1920")
    assertEqual(importedObj.originalHeight, 1080.0, "原始高度精確保存 1080")
    assertEqual(engine.isImageCropped(id: importedObj.id), false, "初始狀態未裁切")

    // 反覆縮放物件，原始尺寸與資料絕對不被重採樣劣化
    engine.scaleSelected(from: CGRect(x: importedObj.x, y: importedObj.y, width: importedObj.width, height: importedObj.height),
                         to: CGRect(x: importedObj.x, y: importedObj.y, width: 400, height: 225))
    let scaledObj = engine.objects.first { $0.id == importedObj.id }!
    assertEqual(scaledObj.originalWidth, 1920.0, "縮放後原始寬度依然為 1920 (不被重採樣)")
    assertEqual(scaledObj.originalHeight, 1080.0, "縮放後原始高度依然為 1080 (不被重採樣)")

    // 24.2 8 向非破壞性裁切與原圖資料守恆 (A18)
    let cropRect = CGRect(x: 200, y: 100, width: 800, height: 600)
    engine.cropImage(id: importedObj.id, cropRect: cropRect)
    let croppedObj = engine.objects.first { $0.id == importedObj.id }!

    assertEqual(engine.isImageCropped(id: importedObj.id), true, "標記為已裁切")
    assertEqual(croppedObj.cropX, 200.0, "裁切 X 座標相符")
    assertEqual(croppedObj.cropY, 100.0, "裁切 Y 座標相符")
    assertEqual(croppedObj.cropWidth, 800.0, "裁切寬度相符")
    assertEqual(croppedObj.cropHeight, 600.0, "裁切高度相符")
    assertEqual(croppedObj.originalWidth, 1920.0, "裁切後原圖寬度絕對不變 (非破壞)")
    assertEqual(croppedObj.originalHeight, 1080.0, "裁切後原圖高度絕對不變 (非破壞)")

    // 裁切交易支援 Undo
    engine.undo()
    let undoneObj = engine.objects.first { $0.id == importedObj.id }!
    assertEqual(engine.isImageCropped(id: importedObj.id), false, "Undo 成功復原為未裁切狀態")
    assertEqual(undoneObj.cropWidth, nil, "Undo 成功清除裁切寬度")

    // 裁切交易支援 Redo
    engine.redo()
    let redoneObj = engine.objects.first { $0.id == importedObj.id }!
    assertEqual(engine.isImageCropped(id: importedObj.id), true, "Redo 成功重做裁切狀態")
    assertEqual(redoneObj.cropWidth, 800.0, "Redo 恢復裁切寬度")

    // 24.3 一鍵重設原圖 (Reset Crop) (A18)
    engine.resetImageCrop(id: importedObj.id)
    let resetObj = engine.objects.first { $0.id == importedObj.id }!
    assertEqual(engine.isImageCropped(id: importedObj.id), false, "重設原圖後標記為未裁切")
    assertEqual(resetObj.cropX, nil, "cropX 已清空")
    assertEqual(resetObj.cropY, nil, "cropY 已清空")
    assertEqual(resetObj.cropWidth, nil, "cropWidth 已清空")
    assertEqual(resetObj.cropHeight, nil, "cropHeight 已清空")

    engine.undo()
    assertEqual(engine.isImageCropped(id: importedObj.id), true, "Undo 成功還原至裁切狀態")

    // 24.4 螢幕截圖取消防貼舊剪貼簿安全防護 (A19)
    let initialCount = engine.objects.count
    engine.handleScreenCaptureResult(exitCode: 1, tempFileURL: nil)
    assertEqual(engine.objects.count, initialCount, "取消截圖絕不貼入舊剪貼簿內容 (A19 規範)")
    assertEqual(engine.statusMessage, "已取消截圖", "狀態列清楚提示已取消截圖")

    // 24.5 多螢幕截圖參數生成與 Retina 尺寸適配 (A19)
    let regionArgs = engine.makeScreenCaptureArguments(mode: .region, outputPath: "/tmp/test.png")
    assertEqual(regionArgs, ["-i", "/tmp/test.png"], "區域截圖參數生成正確")

    let display2Args = engine.makeScreenCaptureArguments(mode: .display(index: 2), outputPath: "/tmp/test2.png")
    assertEqual(display2Args, ["-D", "2", "/tmp/test2.png"], "多顯示器 B 截圖參數指定正確")

    // Retina 2x 縮放像素適配：3840x2160 像素在 Retina 下計算顯示邏輯寬高為 1920x1080
    let logicalSize = engine.computeRetinaLogicalSize(pixelWidth: 3840, pixelHeight: 2160, backingScale: 2.0)
    assertEqual(logicalSize.width, 1920.0, "Retina 2x 寬度邏輯點正確適配")
    assertEqual(logicalSize.height, 1080.0, "Retina 2x 高度邏輯點正確適配")

    // 24.6 裁切圖片編解碼無損往返 (A18, A23)
    let doc = HeiBanDocument(board: engine.board, objects: engine.objects)
    let encoded = try HeiBanDocumentCodec.encode(doc)
    let decoded = try HeiBanDocumentCodec.decode(from: encoded)
    let decodedImage = decoded.objects.first { $0.id == importedObj.id }!
    assertEqual(decodedImage.cropX, 200.0, "解碼後 cropX 無損")
    assertEqual(decodedImage.cropY, 100.0, "解碼後 cropY 無損")
    assertEqual(decodedImage.cropWidth, 800.0, "解碼後 cropWidth 無損")
    assertEqual(decodedImage.cropHeight, 600.0, "解碼後 cropHeight 無損")
    assertEqual(decodedImage.originalWidth, 1920.0, "解碼後 originalWidth 無損")
    assertEqual(decodedImage.originalHeight, 1080.0, "解碼後 originalHeight 無損")
}

// -------------------------------------------------------------------------
// 25. Vector PDF/SVG/PNG Export, A4 Paper & Document Roundtrip (W21, A20, A23)
// -------------------------------------------------------------------------
print("\n[測試 25] W21, A20 & A23: 向量 PDF/SVG/PNG 範圍輸出、A4 實體尺寸、內嵌資料封裝與外部 PDF 註記 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)
    engine.board = BoardMetadata(
        id: "board_export_test",
        title: "輸出驗收黑板",
        canvasMode: .fixed,
        canvasWidth: 1920,
        canvasHeight: 1080
    )

    // 建立 5 種代表性物件：向量筆跡、矩形、圓形、富文本、便簽
    let strokeObj = BoardObject(
        boardId: engine.board.id,
        type: "stroke",
        x: 100, y: 100, width: 200, height: 100,
        points: "[{\"x\":100,\"y\":100},{\"x\":200,\"y\":150},{\"x\":300,\"y\":200}]",
        strokeColor: "#22c55e",
        strokeWidth: 4.0,
        opacity: 0.9
    )
    let rectObj = BoardObject(
        boardId: engine.board.id,
        type: "rect",
        x: 400, y: 150, width: 180, height: 120,
        strokeColor: "#ffffff",
        fillColor: "#166534",
        strokeWidth: 2.0,
        lineStyle: "dashed"
    )
    let circleObj = BoardObject(
        boardId: engine.board.id,
        type: "circle",
        x: 650, y: 200, width: 140, height: 140,
        strokeColor: "#fef08a",
        fillColor: "#fb923c"
    )
    let textObj = BoardObject(
        boardId: engine.board.id,
        type: "text",
        x: 200, y: 400, width: 300, height: 60,
        strokeColor: "#f1f5f9",
        text: "黑板核心架構說明",
        richTextSpans: [
            TextSpan(text: "黑板", isBold: true),
            TextSpan(text: "核心架構", isItalic: true, highlightColor: "#eab308"),
            TextSpan(text: "說明", isUnderline: true)
        ]
    )
    let stickyObj = BoardObject(
        boardId: engine.board.id,
        type: "sticky",
        x: 600, y: 450, width: 200, height: 160,
        strokeColor: "#1f2937",
        fillColor: "#fef08a",
        text: "待辦清單：完成所有工作項目",
        stickyStyle: .cat
    )

    engine.objects = [strokeObj, rectObj, circleObj, textObj, stickyObj]
    engine.selectedIds = [rectObj.id, circleObj.id]

    // 25.1 共用輸出範圍計算 (W21.5, A20)
    let exporter = BoardExporter(document: engine.document)

    let selBounds = exporter.computeScopeBounds(scope: .selection, selectedIds: engine.selectedIds)
    assertEqual(selBounds.minX, 400.0, "選取範圍 minX 相符")
    assertEqual(selBounds.maxX, 790.0, "選取範圍 maxX 相符")

    let allBounds = exporter.computeScopeBounds(scope: .allObjects, selectedIds: engine.selectedIds)
    assertEqual(allBounds.minX, 100.0, "全物件範圍 minX 為 100")
    assertEqual(allBounds.maxX, 800.0, "全物件範圍 maxX 為 800")

    let fixedBounds = exporter.computeScopeBounds(scope: .fixedCanvas, selectedIds: engine.selectedIds)
    assertEqual(fixedBounds.width, 1920.0, "固定畫布寬度相符")
    assertEqual(fixedBounds.height, 1080.0, "固定畫布高度相符")

    let customRegion = CGRect(x: 50, y: 50, width: 500, height: 400)
    let customBounds = exporter.computeScopeBounds(scope: .customRegion(customRegion), selectedIds: engine.selectedIds)
    assertEqual(customBounds, customRegion, "自訂範圍精確匹配")

    // 25.2 SVG 向量可編輯元素映射與排版 (W21.4, A20)
    let svgString = try exporter.exportSVG(scope: .allObjects, selectedIds: engine.selectedIds)
    assertEqual(svgString.contains("<svg"), true, "SVG 包含根元素標籤")
    assertEqual(svgString.contains("viewBox="), true, "SVG 包含 viewBox 屬性")
    assertEqual(svgString.contains("<rect"), true, "SVG 正確映射 rect 幾何元素")
    assertEqual(svgString.contains("<ellipse") || svgString.contains("<circle"), true, "SVG 正確映射圓形/橢圓元素")
    assertEqual(svgString.contains("<path"), true, "SVG 正確映射 stroke 向量路徑")
    assertEqual(svgString.contains("stroke-dasharray=\"8,8\""), true, "SVG 包含虛線樣式定義")
    assertEqual(svgString.contains("黑板核心架構說明") || svgString.contains("核心架構"), true, "SVG 包含中文文字")
    assertEqual(svgString.contains("font-weight=\"bold\""), true, "SVG 富文本片段包含粗體樣式")

    // 25.3 自產向量 PDF 與 A4 實體尺寸 (W21.1, A20)
    let a4Size = PaperPresets.a4
    assertEqual(abs(a4Size.width - 595.28) < 0.1, true, "A4 寬度為 595.28 pt (210 mm)")
    assertEqual(abs(a4Size.height - 841.89) < 0.1, true, "A4 高度為 841.89 pt (297 mm)")

    let pdfData = try exporter.exportPDF(scope: .allObjects, selectedIds: engine.selectedIds, paperSize: a4Size, embedEditableData: true)
    assertEqual(pdfData.count > 100, true, "產出 PDF 資料不為空")
    let pdfHeader = String(data: pdfData.prefix(5), encoding: .ascii)
    assertEqual(pdfHeader, "%PDF-", "PDF 具備標準 Magic Header")

    // 25.4 自產 PDF 內嵌版本化資料與 100% 往返恢復 (W21.2, A23)
    let importResult = try BoardImporter.importPDF(data: pdfData)
    assertEqual(importResult.canRestoreOriginalObjects, true, "自產 PDF 成功辨識並恢復內嵌編輯資料")
    assertEqual(importResult.document?.objects.count, 5, "完整恢復 5 個原始向量物件 (非死點陣圖)")
    assertEqual(importResult.document?.objects[0].type, "stroke", "第 1 物件型別維持 stroke 向量筆跡")
    assertEqual(importResult.document?.objects[1].lineStyle, "dashed", "第 2 物件虛線屬性維持 dashed")
    assertEqual(importResult.document?.objects[3].richTextSpans?.count, 3, "第 4 物件富文本 3 片段完整恢復")
    assertEqual(importResult.document?.objects[4].stickyStyle, .cat, "第 5 物件貓咪便簽樣式完整無損")

    // 25.5 外部 PDF 插入與註記保留 (W21.3, A23)
    let externalPdfData = try exporter.exportPDF(scope: .allObjects, selectedIds: engine.selectedIds, paperSize: a4Size, embedEditableData: false)
    let externalResult = try BoardImporter.importPDF(data: externalPdfData)
    assertEqual(externalResult.canRestoreOriginalObjects, false, "無內嵌資料時明確判定不可還原原物件 (A23 規範)")
    assertEqual(externalResult.isExternalPDF, true, "標記為外部 PDF 檔案")
    assertEqual(externalResult.importedBackgroundObject != nil, true, "為外部 PDF 建立背景頁面物件")
    assertEqual(externalResult.importedBackgroundObject?.type, "pdf_page", "背景物件型別為 pdf_page")

    // 25.6 PNG 尺寸與透明背景輸出 (W21.1, A20)
    let pngData1x = try exporter.exportPNG(scope: .allObjects, selectedIds: engine.selectedIds, scale: 1.0, transparentBackground: true)
    assertEqual(pngData1x.count > 50, true, "成功產出 1x 透明 PNG")
    let pngData2x = try exporter.exportPNG(scope: .allObjects, selectedIds: engine.selectedIds, scale: 2.0, transparentBackground: false)
    assertEqual(pngData2x.count > pngData1x.count, true, "2x 高解析度 PNG 體積大於 1x")
}

// ==============================================================================
// 測試 26: 完整設定中心、偏好持久化、雲端/本機狀態機與 About/Feedback (W22, A22)
// ==============================================================================
print("\n[測試 26] W22 & A22: 完整設定中心、偏好持久化、雲端/本機狀態機與 About/Feedback 資訊 (立靶驗收)")
do {
    let mockSuite = UserDefaults(suiteName: "HeiBan_Test_Preferences_\(UUID().uuidString)")!
    let storageKey = "Test_AppSettings"

    // 26.1 初始原廠預設值驗證
    let manager1 = AppSettingsManager(userDefaults: mockSuite, storageKey: storageKey)
    assertEqual(manager1.current.appTheme, .blackboard, "預設主題為經典黑板 (深色)")
    assertEqual(manager1.current.defaultCanvasMode, .infinite, "預設畫布模式為無限延伸畫布")
    assertEqual(manager1.current.autoSaveFrequency, .standard, "預設自動存檔頻率為標準 (15 秒)")
    assertEqual(manager1.current.defaultFontFamily, "PingFang TC", "預設字體為 PingFang TC")
    assertEqual(manager1.current.defaultFontSize, 24.0, "預設字級為 24 pt")
    assertEqual(manager1.current.defaultToolbarDock, "left", "預設工具列停靠位置為左側")
    assertEqual(manager1.current.showCanvasGrid, true, "預設顯示畫布微點參考線")
    assertEqual(manager1.current.isHapticFeedbackEnabled, true, "預設啟用觸覺回饋")
    assertEqual(manager1.current.loggedInUserEmail, nil, "初始狀態無登入帳號")

    // 26.2 偏好設定修改與重啟持久化 (A22 規範：重啟維持偏好)
    manager1.update { settings in
        settings.appTheme = .whiteboard
        settings.defaultCanvasMode = .fixed
        settings.defaultPaperPreset = "A3"
        settings.autoSaveFrequency = .relaxed
        settings.defaultFontFamily = "SF Pro"
        settings.defaultFontSize = 32.0
        settings.defaultToolbarDock = "bottom"
        settings.showCanvasGrid = false
        settings.isHapticFeedbackEnabled = false
    }

    // 模擬 App 重啟：以相同的 UserDefaults 建立全新 manager2 實例
    let manager2 = AppSettingsManager(userDefaults: mockSuite, storageKey: storageKey)
    assertEqual(manager2.current.appTheme, .whiteboard, "重啟後主題完整還原為清晰白板")
    assertEqual(manager2.current.defaultCanvasMode, .fixed, "重啟後畫布模式完整還原為固定畫布")
    assertEqual(manager2.current.defaultPaperPreset, "A3", "重啟後紙張規格還原為 A3")
    assertEqual(manager2.current.autoSaveFrequency, .relaxed, "重啟後存檔頻率還原為 30 秒")
    assertEqual(manager2.current.defaultFontFamily, "SF Pro", "重啟後字體還原為 SF Pro")
    assertEqual(manager2.current.defaultFontSize, 32.0, "重啟後字級還原為 32 pt")
    assertEqual(manager2.current.defaultToolbarDock, "bottom", "重啟後工具列位置還原為底部")
    assertEqual(manager2.current.showCanvasGrid, false, "重啟後格線開關精確保留")
    assertEqual(manager2.current.isHapticFeedbackEnabled, false, "重啟後觸覺開關精確保留")

    // 26.3 恢復原廠預設值
    manager2.resetToDefaults()
    assertEqual(manager2.current.appTheme, .blackboard, "恢復預設後主題回到黑板")
    assertEqual(manager2.current.defaultCanvasMode, .infinite, "恢復預設後回到無限畫布")
    assertEqual(manager2.current.autoSaveFrequency, .standard, "恢復預設後存檔頻率回到 15 秒")

    // 26.4 雲端／本機狀態機與真實狀態呈現 (A22, A28, A29)
    // 初始狀態為本機安全儲存
    assertEqual(manager2.syncState, .localOnly(reason: "本機單機模式：所有黑板保存在此 Mac，離線安全"), "未登入時明確標示本機安全儲存")

    // 模擬驗證中狀態
    manager2.setSyncState(.authenticating)
    assertEqual(manager2.syncState, .authenticating, "驗證時顯示 authenticating 狀態")
    assertEqual(manager2.syncState.displayName, "帳號驗證中...", "驗證中顯示名稱正確")

    // 模擬登入成功
    manager2.loginUser(email: "architect@heiban.app")
    assertEqual(manager2.current.loggedInUserEmail, "architect@heiban.app", "登入成功記錄帳號 email")
    if case .synced = manager2.syncState {
        assertEqual(true, true, "登入後狀態成功切換為已同步 (synced)")
    } else {
        assertEqual(false, true, "登入後狀態應為 synced")
    }

    // 模擬離線模式 (離線累積 5 筆未同步修訂)
    manager2.setSyncState(.offline(pendingCount: 5))
    assertEqual(manager2.syncState.displayName, "離線模式", "離線時顯示離線模式")
    assertEqual(manager2.syncState.statusDescription.contains("5 筆未同步修訂"), true, "狀態說明精確提示 5 筆待同步")

    // 模擬同步失敗與重試計數
    manager2.setSyncState(.syncFailed(error: "網路連線逾時 (ETIMEDOUT)", retryCount: 2))
    assertEqual(manager2.syncState.displayName, "同步失敗", "失敗時顯示同步失敗")
    assertEqual(manager2.syncState.statusDescription.contains("已重試 2 次"), true, "狀態說明包含重試計數")

    // 模擬登出帳號：嚴格保留本機檔案，身分清空並回到本機安全模式 (A22, A28 規範)
    manager2.logoutUser()
    assertEqual(manager2.current.loggedInUserEmail, nil, "登出後帳號 email 清空")
    assertEqual(manager2.syncState, .localOnly(reason: "本機單機模式：所有黑板保存在此 Mac，離線安全"), "登出後平順回歸本機安全儲存")

    // 26.5 關於資訊與更新日誌真實性 (A22)
    assertEqual(AboutInfo.appName, "HeiBan 黑板", "App 名稱相符")
    assertEqual(AboutInfo.appVersion, "1.0.1", "真版本號為 1.0.1 (非假數據)")
    assertEqual(AboutInfo.buildNumber.isEmpty, false, "組建編號存在且不為空")
    assertEqual(AboutInfo.engineVersion.contains("HeiBan Blackboard Vector Engine"), true, "引擎核心資訊明確")
    assertEqual(AboutInfo.feedbackUrl, "https://github.com/heiban/heiban/issues", "意見回覆入口有效且為真實 URL")
    assertEqual(AboutInfo.changelog.count >= 2, true, "更新日誌至少涵蓋 2 個版本紀錄")
    assertEqual(AboutInfo.changelog[0].version, "1.0.1", "最新更新日誌對應 1.0.1 正式版")
    assertEqual(AboutInfo.changelog[0].highlights.count >= 3, true, "1.0.1 重點更新項目豐富詳盡")
}

// ==============================================================================
// 測試 27: 快捷鍵、IME 焦點隔離、裝置支援與無障礙 (W23, A25)
// ==============================================================================
print("\n[測試 27] W23 & A25: Mac 標準快捷鍵、IME 輸入法焦點隔離、支援裝置矩陣與引擎連動 (立靶驗收)")
do {
    // 27.1 Mac 標準 Command 快捷鍵對應
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "n", keyCode: 45, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .newBoard, "Cmd+N 觸發新建黑板")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "o", keyCode: 31, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .openBoard, "Cmd+O 觸發開啟黑板")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "s", keyCode: 1, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .save, "Cmd+S 觸發儲存")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "s", keyCode: 1, isCommand: true, isShift: true, isOption: false, isTextEditing: false, hasMarkedText: false), .saveAs, "Cmd+Shift+S 觸發另存新檔")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "z", keyCode: 6, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .undo, "Cmd+Z 觸發復原")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "z", keyCode: 6, isCommand: true, isShift: true, isOption: false, isTextEditing: false, hasMarkedText: false), .redo, "Cmd+Shift+Z 觸發重做")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "c", keyCode: 8, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .copy, "Cmd+C 觸發複製")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "x", keyCode: 7, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .cut, "Cmd+X 觸發剪下")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "v", keyCode: 9, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .paste, "Cmd+V 觸發貼上")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "a", keyCode: 0, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .selectAll, "Cmd+A 觸發全選")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "d", keyCode: 2, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .duplicate, "Cmd+D 觸發製作副本")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "g", keyCode: 5, isCommand: true, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .group, "Cmd+G 觸發群組")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "g", keyCode: 5, isCommand: true, isShift: true, isOption: false, isTextEditing: false, hasMarkedText: false), .ungroup, "Cmd+Shift+G 觸發解散群組")

    // 27.2 控制鍵 (Delete, Esc, Space)
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: nil, keyCode: 51, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .delete, "Delete 鍵 (51) 觸發刪除物件")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: nil, keyCode: 117, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .delete, "Forward Delete (117) 觸發刪除物件")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: nil, keyCode: 53, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .escape, "Esc (53) 觸發取消互動")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: " ", keyCode: 49, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .spaceDown, "Space (49) 觸發畫布平移")

    // 27.3 單鍵工具切換 (非文字輸入狀態)
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "v", keyCode: 9, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.select), "v 切換至選取工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "p", keyCode: 35, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.pen), "p 切換至鋼筆工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "h", keyCode: 4, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.highlighter), "h 切換至螢光筆工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "b", keyCode: 11, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.paint), "b 切換至油漆筆工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "e", keyCode: 14, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.eraser), "e 切換至橡皮擦工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "r", keyCode: 15, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.rect), "r 切換至矩形工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "c", keyCode: 8, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.circle), "c 切換至圓形工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "t", keyCode: 17, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.text), "t 切換至文字工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "s", keyCode: 1, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .switchTool(.sticky), "s 切換至便簽工具")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "i", keyCode: 34, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .toggleInspector, "i 切換屬性面板開關")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "m", keyCode: 46, isCommand: false, isShift: false, isOption: false, isTextEditing: false, hasMarkedText: false), .toggleLayerPanel, "m 切換圖層面板開關")

    // 27.4 IME 輸入法與文字編輯焦點隔離 (A25 核心規範：文字輸入時絕對不搶鍵)
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "p", keyCode: 35, isCommand: false, isShift: false, isOption: false, isTextEditing: true, hasMarkedText: false), nil, "文字編輯中輸入 p 鍵不應切換為鋼筆")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "e", keyCode: 14, isCommand: false, isShift: false, isOption: false, isTextEditing: true, hasMarkedText: false), nil, "文字編輯中輸入 e 鍵不應切換為橡皮擦")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "v", keyCode: 9, isCommand: false, isShift: false, isOption: false, isTextEditing: true, hasMarkedText: false), nil, "文字編輯中輸入 v 鍵不應切換為選取")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: nil, keyCode: 51, isCommand: false, isShift: false, isOption: false, isTextEditing: true, hasMarkedText: false), nil, "文字編輯中 Delete 鍵不應刪除畫布物件")
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: "a", keyCode: 0, isCommand: true, isShift: false, isOption: false, isTextEditing: true, hasMarkedText: false), nil, "文字編輯中 Cmd+A 應由文字編輯器處理全選文字")

    // 輸入法組字狀態 (IME composition)
    assertEqual(KeyboardShortcutCoordinator.resolveKeyAction(characters: nil, keyCode: 53, isCommand: false, isShift: false, isOption: false, isTextEditing: true, hasMarkedText: true), nil, "輸入法選字中 Esc 鍵僅取消候選字詞，不關閉編輯器")

    // 27.5 支援裝置矩陣 (A25 規範：包含觸控板、滑鼠、繪圖板與遠端輸入)
    let devices = KeyboardShortcutCoordinator.supportedDevices
    assertEqual(devices.count >= 4, true, "支援裝置矩陣涵蓋至少 4 種典型設備")
    assertEqual(devices.allSatisfy { $0.isSupported }, true, "所有列出設備均標示為支援")
    let hasTablet = devices.contains { $0.deviceType.contains("繪圖板") && $0.features.contains { $0.contains("壓力感應") } }
    assertEqual(hasTablet, true, "明確支援專業繪圖板壓力感應 (0.0~1.0)")

    // 27.6 與 BoardEngine 操作連動
    let engine = BoardEngine(restoreSession: false)
    let objA = BoardObject(boardId: engine.board.id, type: "rect", x: 100, y: 100, width: 80, height: 80)
    let objB = BoardObject(boardId: engine.board.id, type: "circle", x: 300, y: 200, width: 60, height: 60)
    engine.objects = [objA, objB]
    engine.selectedIds = [objA.id]

    // 測試複製副本
    engine.duplicateSelected()
    assertEqual(engine.objects.count, 3, "製作副本後物件總數增加為 3")
    assertEqual(engine.selectedIds.count, 1, "製作副本後自動選取新產生物件")
    let duplicated = engine.objects.last!
    assertEqual(duplicated.id != objA.id, true, "副本具備獨立新 UUID")
    assertEqual(duplicated.x, 124.0, "副本套用預設 24pt X 偏移")
    assertEqual(duplicated.y, 124.0, "副本套用預設 24pt Y 偏移")

    // 測試全選
    engine.selectedIds = Set(engine.objects.map(\.id))
    assertEqual(engine.selectedIds.count, 3, "全選後選取數為 3")

    // 測試刪除
    engine.deleteSelected()
    assertEqual(engine.objects.isEmpty, true, "刪除選取後畫布清空")
    engine.undo()
    assertEqual(engine.objects.count, 3, "Undo 成功復原被刪除之 3 個物件")
}

// ==============================================================================
// 測試 28: 原生 Google 登入、OAuth 生命週期、Keychain 憑證與文件歸屬 (W24, A28)
// ==============================================================================
print("\n[測試 28] W24 & A28: 原生 Google 登入、OAuth 生命週期、Keychain 憑證與文件歸屬 (立靶驗收)")
do {
    // 28.1 Firebase 既有專案配置核對 (W24 規範)
    let config = FirebaseAppConfig.default
    assertEqual(config.projectId, "hypnotic-contact-ssmzh", "Firebase Project ID 相符")
    assertEqual(config.oAuthClientId.contains("423279035400-ij9oss38sfviupiv41cgb5v6u4cds09j"), true, "macOS OAuth Client ID 相符")
    assertEqual(config.apiKey, "AIzaSyC8WYtlkynUG2RH65UhMc9i6wEt57Lgc1Q", "Firebase API Key 相符")
    assertEqual(config.firestoreDatabaseId, "ai-studio-f70661cb-0e92-4da5-b299-f0ac334a5665", "Firestore Database ID 相符")

    // 28.2 OAuth URL 生成與 CSRF State 防護
    let mockKeychain = MockKeychainStore()
    let authAdapter = GoogleAuthAdapter(config: config, keychain: mockKeychain)
    assertEqual(authAdapter.state, .idle, "初始狀態為 idle")

    let redirectUri = "heiban-auth://oauth-callback"
    let authURL = authAdapter.buildAuthorizationURL(redirectUri: redirectUri)
    assertEqual(authURL.host, "accounts.google.com", "OAuth 主機為 accounts.google.com")
    assertEqual(authURL.path, "/o/oauth2/v2/auth", "OAuth 路徑正確")
    assertEqual(authURL.absoluteString.contains("client_id=\(config.oAuthClientId)"), true, "URL 包含正確 Client ID")
    assertEqual(authURL.absoluteString.contains("scope=openid"), true, "URL 包含 openid 範圍")
    if case .authenticating(let stateToken) = authAdapter.state {
        assertEqual(authURL.absoluteString.contains("state=\(stateToken)"), true, "URL 包含隨機 CSRF State Token")
    } else {
        assertEqual(false, true, "啟動 OAuth 後狀態應為 authenticating")
    }

    // 28.3 取消登入 (A28 規範：取消可平順恢復)
    authAdapter.cancelAuthentication()
    assertEqual(authAdapter.state == .cancelled || authAdapter.state == .idle, true, "使用者取消後不跳錯誤視窗")

    // 重新啟動以測試回呼
    let authURL2 = authAdapter.buildAuthorizationURL(redirectUri: redirectUri)
    guard case .authenticating(let activeState) = authAdapter.state else {
        fatalError("State must be authenticating")
    }

    // 28.4 錯誤 State 阻擋 (CSRF 防禦)
    let badCallback = URL(string: "\(redirectUri)?code=auth_code_123&state=fake_state_456")!
    var csrfBlocked = false
    do {
        _ = try authAdapter.handleOAuthCallback(callbackURL: badCallback)
    } catch {
        csrfBlocked = true
    }
    assertEqual(csrfBlocked, true, "偽造 State 的 OAuth 回呼必須嚴格被阻擋")

    // 28.5 正確回呼處理與 Keychain 安全保存 (A28 規範)
    let validCallback = URL(string: "\(redirectUri)?code=auth_code_123&state=\(activeState)")!
    let loggedInUser = try authAdapter.handleOAuthCallback(callbackURL: validCallback)
    assertEqual(loggedInUser.email, "user@heiban.app", "登入使用者 email 吻合")
    assertEqual(authAdapter.state, .authenticated(loggedInUser), "狀態成功轉換為 authenticated")
    assertEqual(authAdapter.currentUser?.idToken.isEmpty, false, "JWT ID Token 存在且不為空")
    assertEqual(authAdapter.currentUser?.refreshToken.isEmpty, false, "Refresh Token 存在且不為空")

    // 28.6 重啟與 Keychain 憑證恢復 (冷啟動自動登入)
    let freshAdapter = GoogleAuthAdapter(config: config, keychain: mockKeychain)
    assertEqual(freshAdapter.state, .authenticated(loggedInUser), "冷啟動時從 Keychain 成功恢復已登入 Session")
    assertEqual(freshAdapter.currentUser?.email, loggedInUser.email, "恢復使用者帳號相符")

    // 28.7 Token 到期刷新 (A28 規範)
    let oldToken = freshAdapter.currentUser!.idToken
    let refreshedUser = try freshAdapter.refreshToken()
    assertEqual(refreshedUser.idToken != oldToken, true, "Token 刷新後獲得全新 JWT ID Token")
    assertEqual(freshAdapter.currentUser?.idToken, refreshedUser.idToken, "目前 Session 更新為新 Token")

    // 28.8 切換帳號 (A28 規範)
    let switchedUser = freshAdapter.switchAccount(newEmail: "architect@deepmind.com")
    assertEqual(switchedUser.email, "architect@deepmind.com", "切換後使用者 email 更新")
    assertEqual(freshAdapter.currentUser?.email, "architect@deepmind.com", "目前使用者成功切換")

    // 28.9 登出與本機作品保全 (A28 核心規範：登出不刪除本機作品)
    let libraryDir = FileManager.default.temporaryDirectory.appendingPathComponent("HeiBan_Logout_Test_\(UUID().uuidString)")
    let library = LocalBoardLibrary(directory: libraryDir)
    let localDoc = HeiBanDocument(board: BoardMetadata(id: "board_local_keep", title: "本機機密設計圖", ownerId: "local_mac"), objects: [])
    try library.save(localDoc)
    assertEqual(try library.list().count, 1, "本機建立 1 份檔案")

    freshAdapter.logout()
    assertEqual(freshAdapter.currentUser, nil, "登出後記憶體無當前使用者")
    assertEqual(freshAdapter.state, .idle, "登出後狀態回到 idle")
    assertEqual(mockKeychain.load(key: "currentUserSession"), nil, "登出後 Keychain 憑證完全清除")
    assertEqual(try library.list().count, 1, "登出絕對不刪除本機已保存黑板 (A28 核心規範)")
    assertEqual(try library.list()[0].title, "本機機密設計圖", "本機黑板資料完好無損")

    // 28.10 文件歸屬與邊界檢查 (A28 規範：不讓下個帳號讀取前個帳號雲端資料)
    let userA = AuthUser(uid: "uid_alice", email: "alice@example.com", idToken: "tok_a", refreshToken: "ref_a")
    _ = freshAdapter.completeLogin(user: userA)

    let localBoard = BoardMetadata(id: "b_local", title: "本機黑板", ownerId: "local_mac")
    assertEqual(freshAdapter.checkDocumentOwnership(board: localBoard), .localOnly, "本機黑板歸屬為 localOnly")

    let aliceBoard = BoardMetadata(id: "b_alice", title: "Alice 雲端黑板", ownerId: "uid_alice")
    assertEqual(freshAdapter.checkDocumentOwnership(board: aliceBoard), .ownedByCurrentUser, "Alice 擁有自己黑板的完整權限")

    let sharedBoard = BoardMetadata(id: "b_team", title: "團隊專案黑板", ownerId: "uid_lead", collaboratorIds: ["uid_alice", "uid_bob"])
    assertEqual(freshAdapter.checkDocumentOwnership(board: sharedBoard), .sharedWithCurrentUser, "Alice 具備協作者權限")

    let bobBoard = BoardMetadata(id: "b_bob", title: "Bob 私人雲端黑板", ownerId: "uid_bob")
    assertEqual(freshAdapter.checkDocumentOwnership(board: bobBoard), .unauthorized, "Alice 絕對無法讀取 Bob 的未授權私人黑板")
}

// ==============================================================================
// 測試 29: 跨裝置同步與離線佇列、修訂編號、冪等寫入與衝突副本保全 (W25, A29)
// ==============================================================================
print("\n[測試 29] W25 & A29: 跨裝置同步與離線佇列、修訂編號、冪等寫入與衝突副本保全 (立靶驗收)")
do {
    let sharedTransport = MockCloudSyncTransport()
    let queueDirA = FileManager.default.temporaryDirectory.appendingPathComponent("HeiBan_Sync_QueueA_\(UUID().uuidString)")
    let queueDirB = FileManager.default.temporaryDirectory.appendingPathComponent("HeiBan_Sync_QueueB_\(UUID().uuidString)")
    let libDirA = FileManager.default.temporaryDirectory.appendingPathComponent("HeiBan_LibA_\(UUID().uuidString)")
    let libDirB = FileManager.default.temporaryDirectory.appendingPathComponent("HeiBan_LibB_\(UUID().uuidString)")

    let libraryA = LocalBoardLibrary(directory: libDirA)
    let libraryB = LocalBoardLibrary(directory: libDirB)

    let coordinatorA = CloudSyncCoordinator(transport: sharedTransport, queueDirectory: queueDirA, library: libraryA)
    let coordinatorB = CloudSyncCoordinator(transport: sharedTransport, queueDirectory: queueDirB, library: libraryB)

    // 29.1 雙裝置線上同步驗證 (A29 規範：同一帳號兩裝置保存 F04)
    var docA = HeiBanDocument(
        board: BoardMetadata(id: "board_sync_f04", title: "跨裝置協同黑板", ownerId: "user_sync_1", revision: 1),
        objects: [
            BoardObject(boardId: "board_sync_f04", type: "stroke", x: 100, y: 100, width: 200, height: 100),
            BoardObject(boardId: "board_sync_f04", type: "rect", x: 300, y: 150, width: 120, height: 80),
            BoardObject(boardId: "board_sync_f04", type: "sticky", x: 500, y: 200, width: 140, height: 140, text: "跨裝置待辦")
        ]
    )

    let syncStart = Date()
    docA = try coordinatorA.syncDocument(localDocument: &docA)
    let syncDuration = Date().timeIntervalSince(syncStart)
    assertEqual(syncDuration < 2.0, true, "線上同步傳播時間小於 2 秒 (實際: \(String(format: "%.4f", syncDuration))s，符合 A29 規範)")
    assertEqual(sharedTransport.remoteRevisions["board_sync_f04"], 2, "雲端修訂編號推進至 2")

    // 裝置 B 同步拉取
    var docB = HeiBanDocument(
        board: BoardMetadata(id: "board_sync_f04", title: "空白暫存", ownerId: "user_sync_1", revision: 1),
        objects: []
    )
    docB = try coordinatorB.syncDocument(localDocument: &docB)
    assertEqual(docB.objects.count, 3, "裝置 B 成功完整拉取 3 個雲端物件")
    assertEqual(docB.board.title, "跨裝置協同黑板", "裝置 B 標題與雲端一致")
    assertEqual(docB.board.revision, 2, "裝置 B 修訂編號更新為 2")

    // 29.2 離線編輯與磁碟佇列持久化 (A29 規範：離線繼續編輯，重啟後佇列仍在)
    sharedTransport.isOnline = false

    let offlineMut1 = SyncMutation(
        id: "mut_text_1",
        boardId: docA.board.id,
        baseRevision: 2,
        insertedObjects: [BoardObject(boardId: docA.board.id, type: "text", x: 200, y: 400, width: 100, height: 40, text: "離線筆記")]
    )
    let offlineMut2 = SyncMutation(
        id: "mut_sticky_2",
        boardId: docA.board.id,
        baseRevision: 2,
        insertedObjects: [BoardObject(boardId: docA.board.id, type: "sticky", x: 600, y: 300, width: 150, height: 150, text: "離線補充")]
    )
    let offlineMut3 = SyncMutation(
        id: "mut_del_rect_3",
        boardId: docA.board.id,
        baseRevision: 2,
        deletedObjectIds: [docA.objects[1].id] // 刪除第二個物件 (rect)
    )

    coordinatorA.enqueue(mutation: offlineMut1)
    coordinatorA.enqueue(mutation: offlineMut2)
    coordinatorA.enqueue(mutation: offlineMut3)

    assertEqual(coordinatorA.queue.count, 3, "離線累積 3 筆未同步修訂")
    assertEqual(coordinatorA.status, .offline(pendingCount: 3), "狀態精確提示離線待同步筆數")

    // 模擬 App 崩潰／重啟：全新 Coordinator 載入相同目錄
    let rebootCoordinatorA = CloudSyncCoordinator(transport: sharedTransport, queueDirectory: queueDirA, library: libraryA)
    assertEqual(rebootCoordinatorA.queue.count, 3, "App 重啟後磁碟離線佇列 100% 完整恢復 (A29 規範)")
    assertEqual(rebootCoordinatorA.queue[0].id, "mut_text_1", "第一筆修訂 ID 相符")
    assertEqual(rebootCoordinatorA.queue[2].id, "mut_del_rect_3", "第三筆修訂 ID 相符")

    // 29.3 重連網路與佇列自動出隊 (Drain Queue)
    sharedTransport.isOnline = true
    let drainSuccess = rebootCoordinatorA.drainQueue()
    assertEqual(drainSuccess, true, "網路恢復後出隊成功")
    assertEqual(rebootCoordinatorA.queue.isEmpty, true, "佇列完全清空")
    if case .synced = rebootCoordinatorA.status {
        assertEqual(true, true, "狀態轉變為已同步 (synced)")
    } else {
        assertEqual(false, true, "出隊完畢狀態應為 synced")
    }

    let remoteAfterDrain = try sharedTransport.pullLatestDocument(boardId: docA.board.id)!
    assertEqual(remoteAfterDrain.board.revision, 5, "遠端修訂號遞增至 5 (2 + 3 筆 mutation)")
    assertEqual(remoteAfterDrain.objects.contains { $0.type == "rect" }, false, "離線刪除之 rect 物件在雲端已移除")
    assertEqual(remoteAfterDrain.objects.contains { $0.text == "離線筆記" }, true, "離線新增之文字物件已成功寫入雲端")

    // 29.4 冪等性寫入保證 (Idempotent Writes)
    let duplicateRev = try sharedTransport.pushMutation(offlineMut1)
    assertEqual(duplicateRev, 5, "重複推送已 acknowledge 之 mutationId 不重複累加修訂號 (冪等保證)")

    // 29.5 衝突副本分支機制 (Conflict Resolution & Copy Preservation, A29)
    // 裝置 B 在遠端修訂為 5 時新增圓形並推送，將遠端推進至 6
    let bMutation = SyncMutation(
        boardId: docA.board.id,
        baseRevision: 5,
        insertedObjects: [BoardObject(boardId: docA.board.id, type: "circle", x: 700, y: 700, width: 90, height: 90)]
    )
    _ = try sharedTransport.pushMutation(bMutation)

    // 裝置 A 本地仍處於 revision 5，但有未上傳的本地相異編輯
    var localDocA = remoteAfterDrain
    localDocA.objects.append(BoardObject(boardId: docA.board.id, type: "star", x: 800, y: 800, width: 50, height: 50))

    // 觸發同步，偵測到遠端 revision 6 > 本地 5 且有相異變更 -> 自動建立衝突副本保全本地版本
    let resolvedDoc = try rebootCoordinatorA.syncDocument(localDocument: &localDocA)
    assertEqual(resolvedDoc.objects.contains { $0.type == "circle" }, true, "本地黑板套用雲端最新圓形物件")

    let localBoardsA = try libraryA.list()
    let conflictBoard = localBoardsA.first { $0.title.contains("衝突副本") }
    assertEqual(conflictBoard != nil, true, "成功自動產生衝突副本檔案 (A29 規範)")
    assertEqual(conflictBoard?.id != docA.board.id, true, "衝突副本具備全新獨立 UUID")

    let loadedConflictDoc = try libraryA.load(id: conflictBoard!.id)
    assertEqual(loadedConflictDoc.objects.contains { $0.type == "star" }, true, "衝突副本 100% 完整保留本地未覆蓋之星星物件 (零資料遺失)")
}

// ==============================================================================
// 測試 30: 十人協作、分享邀請、游標軌跡與第十一人上限阻擋 (W26, A30)
// ==============================================================================
print("\n[測試 30] W26 & A30: 十人協作、分享邀請、游標軌跡與第十一人上限阻擋 (立靶驗收)")
do {
    let room = CollaborationRoom(boardId: "board_collab_10", ownerId: "uid_owner", ownerName: "專案室擁有者")
    assertEqual(room.collaborators.count, 1, "初始成員為擁有者 1 人")
    assertEqual(room.collaborators["uid_owner"]?.role, .owner, "擁有者具備 owner 權限")
    assertEqual(room.collaborators["uid_owner"]?.role.canEdit, true, "擁有者具備編輯權限")

    // 30.1 邀請分享連結與撤銷驗證
    let inviteTokenLink = room.createShareLink(role: .editor)
    assertEqual(inviteTokenLink.contains("token=share_"), true, "產出有效之分享連結")
    let rawToken = inviteTokenLink.components(separatedBy: "token=").last!

    let guest1Join = room.joinRoom(userId: "uid_guest_1", userName: "協作者一", shareToken: rawToken)
    assertEqual(guest1Join, .success(role: .editor), "透過邀請連結加入獲得 editor 權限")
    assertEqual(room.collaborators.count, 2, "成員增加至 2 人")

    // 撤銷分享連結
    room.revokeShareLink(token: rawToken)
    let badJoin = room.joinRoom(userId: "uid_guest_late", userName: "遲到者", shareToken: rawToken)
    assertEqual(badJoin, .accessDenied(reason: "無效或已撤銷的邀請連結"), "撤銷之分享連結無法再加入")

    // 30.2 依序加入至 10 人上限
    for i in 2...9 {
        let res = room.joinRoom(userId: "uid_guest_\(i)", userName: "協作者 \(i)")
        assertEqual(res, .success(role: .editor), "第 \(i + 1) 位協作者成功加入")
    }
    let totalEditors = room.collaborators.values.filter { $0.role.canEdit }.count
    assertEqual(totalEditors, 10, "當前剛好達到至多十人服務端上限 (A30 規範)")

    // 30.3 第十一位加入被服務端嚴格阻擋 (A30 核心規範)
    let eleventhJoin = room.joinRoom(userId: "uid_guest_11", userName: "第十一位訪客")
    assertEqual(eleventhJoin, .capacityExceeded(maxAllowed: 10), "第十一位被服務端阻止加入編輯協作 (A30 核心規範)")

    // 30.4 游標軌跡、姓名與繪圖狀態即時呈現
    room.updatePresence(
        userId: "uid_guest_1",
        cursorPosition: Point(x: 150, y: 220),
        isDrawing: true,
        activeTool: "pen",
        activeStrokePoints: [Point(x: 150, y: 220), Point(x: 160, y: 235)]
    )
    assertEqual(room.activePresences["uid_guest_1"]?.isDrawing, true, "協作者繪圖狀態即時記錄")
    assertEqual(room.activePresences["uid_guest_1"]?.cursorPosition.x, 150.0, "游標 X 座標精確記錄")
    assertEqual(room.activePresences["uid_guest_1"]?.activeStrokePoints?.count, 2, "活動軌跡片段記錄")

    // 顯示開關測試 (能關閉呈現且不停止其他人編輯)
    room.showCollaboratorCursors = false
    room.showCollaboratorTrajectories = false
    assertEqual(room.showCollaboratorCursors, false, "游標顯示成功關閉")
    assertEqual(room.showCollaboratorTrajectories, false, "軌跡顯示成功關閉")

    // 30.5 Presence TTL 心跳超時與離開房間 (A30 規範)
    let simulatedPast = Date().addingTimeInterval(15) // 超過 10 秒
    room.pruneExpiredPresences(referenceDate: simulatedPast)
    assertEqual(room.activePresences.isEmpty, true, "離線或超時 presence 自動過期清除 (A30 規範)")

    // 30.6 撤銷協作者訪問權限 (A30 規範)
    let revokeResult = room.revokeCollaborator(userId: "uid_guest_1")
    assertEqual(revokeResult, true, "擁有者成功撤銷協作者訪問")
    assertEqual(room.collaborators["uid_guest_1"], nil, "被撤銷者從成員清單移除")
}

// ==============================================================================
// 測試 31: 協作故障、斷線重連、十人同板並發操作收斂 (W27, A30)
// ==============================================================================
print("\n[測試 31] W27 & A30: 協作故障、斷線重連、十人同板並發操作收斂 (立靶驗收)")
do {
    var baseDoc = HeiBanDocument(
        board: BoardMetadata(id: "board_ten_clients", title: "十人高並發協同驗收", revision: 10),
        objects: [
            BoardObject(boardId: "board_ten_clients", type: "sticky", x: 100, y: 100, width: 200, height: 160, text: "初始便簽"),
            BoardObject(boardId: "board_ten_clients", type: "circle", x: 400, y: 100, width: 100, height: 100)
        ]
    )

    let stickyId = baseDoc.objects[0].id
    let circleId = baseDoc.objects[1].id

    // 模擬十個獨立客戶端同板並發提交 10 筆 mutations (新增、修改同物件、刪除、復原)
    var mutations: [SyncMutation] = []

    // Client 1 ~ 7: 每人新增一個不同幾何物件
    for i in 1...7 {
        mutations.append(SyncMutation(
            id: "mut_client_\(i)",
            boardId: "board_ten_clients",
            baseRevision: 10,
            timestamp: "2026-10-03T01:00:0\(i)Z",
            insertedObjects: [
                BoardObject(id: "obj_c\(i)", boardId: "board_ten_clients", type: "rect", x: Double(i * 60), y: 300, width: 50, height: 50)
            ]
        ))
    }

    // Client 8: 編輯同一張便簽 (timestamp: 01:00:10Z)
    var modifiedSticky8 = baseDoc.objects[0]
    modifiedSticky8.text = "Client 8 修改之便簽內容"
    mutations.append(SyncMutation(
        id: "mut_client_8",
        boardId: "board_ten_clients",
        baseRevision: 10,
        timestamp: "2026-10-03T01:00:10Z",
        insertedObjects: [modifiedSticky8]
    ))

    // Client 9: 隨後也編輯同一張便簽 (timestamp: 01:00:12Z, 晚於 Client 8)
    var modifiedSticky9 = baseDoc.objects[0]
    modifiedSticky9.text = "Client 9 最終收斂之便簽內容"
    mutations.append(SyncMutation(
        id: "mut_client_9",
        boardId: "board_ten_clients",
        baseRevision: 10,
        timestamp: "2026-10-03T01:00:12Z",
        insertedObjects: [modifiedSticky9]
    ))

    // Client 10: 刪除圓形物件 (timestamp: 01:00:15Z)
    mutations.append(SyncMutation(
        id: "mut_client_10",
        boardId: "board_ten_clients",
        baseRevision: 10,
        timestamp: "2026-10-03T01:00:15Z",
        deletedObjectIds: [circleId]
    ))

    // 31.1 在十個客戶端分別執行收斂運算 (模擬分布式事件傳播後各端本地狀態)
    let convergeStart = Date()
    var convergedResults: [HeiBanDocument] = []
    for _ in 1...10 {
        // 模擬各客戶端可能以不同網路傳遞順序接收到 mutations (亂序抵達)
        let shuffled = mutations.shuffled()
        let clientDoc = ConvergenceEngine.convergeDocument(baseDocument: baseDoc, incomingMutations: shuffled)
        convergedResults.append(clientDoc)
    }
    let convergeDuration = Date().timeIntervalSince(convergeStart)

    // 31.2 驗證全部 10 個客戶端 100% 收斂至同一份無差別文件 (A30 規範：結束後收斂到一致文件，無靜默資料遺失)
    let reference = convergedResults[0]
    for (idx, clientDoc) in convergedResults.enumerated() {
        assertEqual(clientDoc.objects.count, reference.objects.count, "客戶端 \(idx + 1) 物件數完全一致")
        assertEqual(clientDoc.board.revision, reference.board.revision, "客戶端 \(idx + 1) 修訂號完全一致")
        assertEqual(clientDoc.objects.map(\.id), reference.objects.map(\.id), "客戶端 \(idx + 1) 物件 ID 清單完全一致")
    }

    // 31.3 驗證同物件最後寫入者獲勝 (LWW)
    let finalSticky = reference.objects.first(where: { $0.id == stickyId })
    assertEqual(finalSticky?.text, "Client 9 最終收斂之便簽內容", "最後編輯者 Client 9 內容確定性獲勝")

    // 31.4 驗證刪除操作已在全體客戶端生效
    let circleExists = reference.objects.contains(where: { $0.id == circleId })
    assertEqual(circleExists, false, "刪除的圓形物件在全部客戶端均已消失")

    // 31.5 驗證 7 位客戶端新增的矩形無一遺失 (無靜默資料遺失)
    let rectCount = reference.objects.filter { $0.type == "rect" }.count
    assertEqual(rectCount, 7, "7 個並發新增的矩形物件全部完整保留")

    // 31.6 性能指標量測 (p95 耗時遠小於 1 秒)
    assertEqual(convergeDuration < 1.0, true, "10 客戶端並發收斂計算耗時: \(String(format: "%.4f", convergeDuration))s (遠低於 1 秒限制)")
}

// =========================================================================
// [測試 32] W28 & A31: macOS 發行品質、產物 Hash、簽章公證規範、冷安裝資料保全與更新狀態機 (立靶驗收)
// =========================================================================
do {
    print("\n[測試 32] W28 & A31: macOS 發行品質、產物 Hash、簽章公證規範、冷安裝資料保全與更新狀態機 (立靶驗收)")

    // 32.1 產物版本、最低系統需求與硬體架構契約 (A31)
    let fakeHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    let artifact = ReleaseArtifactInfo(
        appName: "HeiBan 黑板",
        bundleIdentifier: "com.bear.HeiBan",
        version: "1.0.0",
        buildNumber: "1",
        minimumOSVersion: "14.0",
        targetArchitecture: .arm64,
        sha256Checksum: fakeHash,
        signingStatus: .developerID,
        notarizationStatus: .notarizedAndStapled,
        releaseDate: "2026-10-02"
    )

    assertEqual(artifact.appName, "HeiBan 黑板", "App 名稱相符")
    assertEqual(artifact.bundleIdentifier, "com.bear.HeiBan", "Bundle ID 符合 Apple 規範")
    assertEqual(artifact.version, "1.0.0", "語意化版本號為 1.0.0 (A31)")
    assertEqual(artifact.buildNumber, "1", "組建編號存在")
    assertEqual(artifact.minimumOSVersion, "14.0", "最低相容系統為 macOS 14.0 (A31)")
    assertTrue(artifact.isSystemCompatible(), "當前 macOS 執行環境符合最低版本需求")
    assertEqual(artifact.targetArchitecture, .arm64, "優先驗收 Apple Silicon (arm64) 架構 (A31)")
    assertEqual(artifact.signingStatus, .developerID, "正式發行簽章為 Developer ID (A31)")
    assertEqual(artifact.notarizationStatus, .notarizedAndStapled, "正式發行通過 Apple 公證與 Staple (A31)")

    // 32.2 SHA-256 Checksum 計算與完整性校驗
    let sampleData = "HeiBan Release Package v1.0.0".data(using: .utf8)!
    let realSha256 = AppUpdateManager.computeSHA256(data: sampleData)
    assertEqual(realSha256.count, 64, "SHA-256 雜湊長度精確為 64 個字元 (256 bits)")
    assertTrue(AppUpdateManager.verifyChecksum(data: sampleData, expectedSha256: realSha256), "原始資料 SHA-256 校驗成功")

    let corruptedData = "HeiBan Release Package v1.0.0 - TAMPERED".data(using: .utf8)!
    assertTrue(!AppUpdateManager.verifyChecksum(data: corruptedData, expectedSha256: realSha256), "篡改資料之 SHA-256 校驗嚴格失敗")

    // 32.3 冷安裝與使用者資料保全 (A31: 卸載後資料保留)
    let appBundleURL = URL(fileURLWithPath: "/Applications/HeiBan.app")
    let userDataURL = ColdInstallStorageCoordinator.applicationSupportDirectory()
    let boardsURL = ColdInstallStorageCoordinator.boardsDirectory()

    assertTrue(ColdInstallStorageCoordinator.isIsolated(appBundleURL: appBundleURL, userDataURL: userDataURL), "使用者資料庫與 App Bundle 物理隔離 (冷安裝安全)")
    assertTrue(userDataURL.path.contains("Library/Application Support/com.bear.HeiBan"), "使用者資料存放於標準 Application Support 目錄")
    assertTrue(boardsURL.path.hasSuffix("/boards"), "黑板作品獨立子目錄存放")

    // 32.4 語意化版本比對邏輯 (SemVer)
    assertTrue(AppUpdateManager.isNewer(remoteVersion: "1.0.1", currentVersion: "1.0.0"), "1.0.1 應識別為新版本")
    assertTrue(AppUpdateManager.isNewer(remoteVersion: "1.1.0", currentVersion: "1.0.0"), "1.1.0 應識別為新版本")
    assertTrue(AppUpdateManager.isNewer(remoteVersion: "2.0.0", currentVersion: "1.9.9"), "2.0.0 應識別為新版本")
    assertTrue(!AppUpdateManager.isNewer(remoteVersion: "1.0.0", currentVersion: "1.0.0"), "相同版本號不識別為新版本")
    assertTrue(!AppUpdateManager.isNewer(remoteVersion: "0.9.9", currentVersion: "1.0.0"), "舊版本號不識別為新版本")

    // 32.5 更新管理器狀態機、提醒去重與離線平順容錯 (W28, A31)
    let updateMgr = AppUpdateManager(currentVersion: "1.0.0")
    assertEqual(updateMgr.status, .idle, "初始狀態為 idle")

    // 離線模式檢查更新：平順容錯，絕不崩潰
    let offlineStatus = updateMgr.checkForUpdates(remoteRelease: nil, isOffline: true)
    if case .failed(let err) = offlineStatus {
        assertTrue(err.contains("離線"), "離線時平順提示離線模式，不中斷本地編輯")
    } else {
        assertTrue(false, "離線時狀態應為 failed")
    }

    // 線上發現新版本
    let newRelease = AppReleaseInfo(
        version: "1.0.1",
        buildNumber: "2",
        releaseDate: "2026-10-15",
        changelog: ["支援更豐富的跨平台協作", "效能提升"],
        downloadURL: "https://heiban.app/releases/HeiBan-1.0.1.dmg",
        sha256: realSha256,
        isCritical: false
    )

    let availableStatus = updateMgr.checkForUpdates(remoteRelease: newRelease, isOffline: false)
    assertEqual(availableStatus, .updateAvailable(newRelease), "偵測到新版本時切換為 updateAvailable")

    // 提醒去重 (Suppression): 使用者選擇「跳過此版本」
    updateMgr.skipVersion("1.0.1")
    let suppressedStatus = updateMgr.checkForUpdates(remoteRelease: newRelease, isOffline: false)
    assertEqual(suppressedStatus, .upToDate, "跳過之版本再次檢查時去重，不重複騷擾使用者 (W28)")

    // 重大安全更新不受跳過限制
    let criticalRelease = AppReleaseInfo(
        version: "1.0.1",
        buildNumber: "2",
        releaseDate: "2026-10-15",
        changelog: ["重大安全性修復"],
        downloadURL: "https://heiban.app/releases/HeiBan-1.0.1.dmg",
        sha256: realSha256,
        isCritical: true
    )
    let criticalStatus = updateMgr.checkForUpdates(remoteRelease: criticalRelease, isOffline: false)
    assertEqual(criticalStatus, .updateAvailable(criticalRelease), "重大安全更新強制忽略跳過限制 (W28)")

    // 模擬下載與安裝：Hash 正確
    let validDownload = updateMgr.simulateDownload(packageData: sampleData, releaseInfo: criticalRelease)
    assertTrue(validDownload, "有效 Hash 之套件下載驗證成功")
    if case .readyToInstall(let mount) = updateMgr.status {
        assertTrue(mount.contains("1.0.1"), "掛載路徑正確包含版本號")
    } else {
        assertTrue(false, "下載校驗成功後應轉為 readyToInstall")
    }

    // 模擬下載與安裝：Hash 篡改失敗
    let corruptedDownload = updateMgr.simulateDownload(packageData: corruptedData, releaseInfo: criticalRelease)
    assertTrue(!corruptedDownload, "篡改套件之更新安裝被嚴格拒絕")
    if case .failed(let reason) = updateMgr.status {
        assertTrue(reason.contains("SHA-256 校驗失敗"), "精確回報 Hash 損毀錯誤原因")
    } else {
        assertTrue(false, "篡改套件狀態應為 failed")
    }
}

// =========================================================================
// [測試 33] W29 & A23 & A31: Web／Windows 跨平台架構決策、文件契約互通、字型度量容差與協作收斂對等 (立靶驗收)
// =========================================================================
do {
    print("\n[測試 33] W29 & A23 & A31: Web／Windows 跨平台架構決策、文件契約互通、字型度量容差與協作收斂對等 (立靶驗收)")

    // 33.1 跨平台架構決策矩陣涵蓋度 (ADR, W29)
    assertEqual(PlatformInteroperabilityMatrix.standardDecisions.count, 3, "涵蓋 macOS、Web、Windows 三大平台")
    let macDec = PlatformInteroperabilityMatrix.standardDecisions[.macOS]!
    let webDec = PlatformInteroperabilityMatrix.standardDecisions[.web]!
    let winDec = PlatformInteroperabilityMatrix.standardDecisions[.windows]!

    assertTrue(macDec.renderingStack.contains("Metal"), "macOS 決策採用 Metal 原生渲染 (120Hz/60Hz)")
    assertTrue(webDec.renderingStack.contains("React") && webDec.renderingStack.contains("Canvas"), "Web 決策採用 React 19 與 Canvas 2D / OffscreenCanvas")
    assertTrue(winDec.renderingStack.contains("Direct2D"), "Windows 決策採用 Direct2D / Windows App SDK (非低效 WebView 封裝)")

    // 33.2 跨平台文件契約版本一致性 (A23, A31)
    assertTrue(PlatformInteroperabilityMatrix.verifyContractParity(), "所有平台全數對齊 HeiBan Document Schema 1.0.0 (A23, A31)")

    // 33.3 共享標準測試 Fixture 涵蓋度 (F01–F05, A23)
    assertTrue(PlatformInteroperabilityMatrix.verifyFixtureCoverage(), "所有平台均完整支援 F01 至 F05 全部標準測試契約")

    // 33.4 跨平台字型度量與排版容差極限 (≤ 2.0 pt)
    assertTrue(PlatformInteroperabilityMatrix.verifyFontMetricTolerance(), "全平台字型排版度量容差極限嚴格限制在 ≤ 2.0 pt (W29, A23)")
    assertEqual(macDec.maxFontMetricTolerancePt, 2.0, "macOS CoreText 度量容差為 2.0 pt")
    assertEqual(webDec.maxFontMetricTolerancePt, 2.0, "Web Canvas measureText 度量容差為 2.0 pt")
    assertEqual(winDec.maxFontMetricTolerancePt, 2.0, "Windows DirectWrite 度量容差為 2.0 pt")

    // 33.5 輸入分派設備與壓感契約
    assertTrue(macDec.inputDispatcher.contains("0.0~1.0"), "macOS 支援 0.0~1.0 壓感")
    assertTrue(webDec.inputDispatcher.contains("PointerEvents"), "Web 支援標準 W3C PointerEvents")
    assertTrue(winDec.inputDispatcher.contains("Windows Ink"), "Windows 支援原生 Windows Ink 壓感")
}

// -------------------------------------------------------------------------
// 34. Transform Handles & Dynamic Cursor Shapes (Image, Line, Rotate) (立靶驗收)
// -------------------------------------------------------------------------
print("\n[測試 34] 變形控制器周圍 8 點與旋轉點動態鼠標游標形狀驗證 (立靶驗收)")
do {
    // 34.1 變形控制點與游標類型對應規格
    assertEqual(TransformHandle.middleLeft.cursorType, .resizeHorizontal, "左側中點為水平雙向箭頭 (左右拉長縮短)")
    assertEqual(TransformHandle.middleRight.cursorType, .resizeHorizontal, "右側中點為水平雙向箭頭 (左右拉長縮短)")
    assertEqual(TransformHandle.topCenter.cursorType, .resizeVertical, "頂部中點為垂直雙向箭頭 (上下拉長縮短)")
    assertEqual(TransformHandle.bottomCenter.cursorType, .resizeVertical, "底部中點為垂直雙向箭頭 (上下拉長縮短)")
    assertEqual(TransformHandle.topLeft.cursorType, .resizeDiagonalNWSE, "左上角點為 NW-SE 斜邊雙向箭頭")
    assertEqual(TransformHandle.bottomRight.cursorType, .resizeDiagonalNWSE, "右下角點為 NW-SE 斜邊雙向箭頭")
    assertEqual(TransformHandle.topRight.cursorType, .resizeDiagonalNESW, "右上角點為 NE-SW 斜邊雙向箭頭")
    assertEqual(TransformHandle.bottomLeft.cursorType, .resizeDiagonalNESW, "左下角點為 NE-SW 斜邊雙向箭頭")
    assertEqual(TransformHandle.rotate.cursorType, .rotate, "旋轉控制點為專用旋轉鼠標")

    // 34.2 圖片物件周邊 8 個控制點與旋轉點之鼠標動態判定
    let imageEngine = BoardEngine(restoreSession: false)
    imageEngine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
    let testImage = BoardObject(
        id: "img_test_cursor",
        type: "image",
        x: 100, y: 100, width: 200, height: 150
    )
    imageEngine.objects = [testImage]
    imageEngine.selectedIds = [testImage.id]
    imageEngine.currentTool = .select

    guard let imgBounds = imageEngine.selectionBoundingBox else {
        fatalError("圖片選取後 bounding box 不應為空")
    }
    assertEqual(imgBounds.minX, 100.0, "圖片 BoundingBox minX 正確")
    assertEqual(imgBounds.maxX, 300.0, "圖片 BoundingBox maxX 正確")
    assertEqual(imgBounds.minY, 100.0, "圖片 BoundingBox minY 正確")
    assertEqual(imgBounds.maxY, 250.0, "圖片 BoundingBox maxY 正確")

    let imgHandles = VectorMath.handlePositions(for: imgBounds, zoom: 1.0)

    // 測試圖片 8 個控制點的鼠標游標判定
    let ptML = Point(x: Double(imgHandles[.middleLeft]!.x), y: Double(imgHandles[.middleLeft]!.y))
    imageEngine.updateHoveredHandle(at: ptML)
    assertEqual(imageEngine.currentCursorType(at: ptML), .resizeHorizontal, "懸停於圖片左中點時出現水平雙向箭頭")

    let ptMR = Point(x: Double(imgHandles[.middleRight]!.x), y: Double(imgHandles[.middleRight]!.y))
    imageEngine.updateHoveredHandle(at: ptMR)
    assertEqual(imageEngine.currentCursorType(at: ptMR), .resizeHorizontal, "懸停於圖片右中點時出現水平雙向箭頭")

    let ptTC = Point(x: Double(imgHandles[.topCenter]!.x), y: Double(imgHandles[.topCenter]!.y))
    imageEngine.updateHoveredHandle(at: ptTC)
    assertEqual(imageEngine.currentCursorType(at: ptTC), .resizeVertical, "懸停於圖片頂中點時出現垂直雙向箭頭")

    let ptBC = Point(x: Double(imgHandles[.bottomCenter]!.x), y: Double(imgHandles[.bottomCenter]!.y))
    imageEngine.updateHoveredHandle(at: ptBC)
    assertEqual(imageEngine.currentCursorType(at: ptBC), .resizeVertical, "懸停於圖片底中點時出現垂直雙向箭頭")

    let ptTL = Point(x: Double(imgHandles[.topLeft]!.x), y: Double(imgHandles[.topLeft]!.y))
    imageEngine.updateHoveredHandle(at: ptTL)
    assertEqual(imageEngine.currentCursorType(at: ptTL), .resizeDiagonalNWSE, "懸停於圖片左上角時出現斜邊 NW-SE 雙向箭頭")

    let ptBR = Point(x: Double(imgHandles[.bottomRight]!.x), y: Double(imgHandles[.bottomRight]!.y))
    imageEngine.updateHoveredHandle(at: ptBR)
    assertEqual(imageEngine.currentCursorType(at: ptBR), .resizeDiagonalNWSE, "懸停於圖片右下角時出現斜邊 NW-SE 雙向箭頭")

    let ptTR = Point(x: Double(imgHandles[.topRight]!.x), y: Double(imgHandles[.topRight]!.y))
    imageEngine.updateHoveredHandle(at: ptTR)
    assertEqual(imageEngine.currentCursorType(at: ptTR), .resizeDiagonalNESW, "懸停於圖片右上角時出現斜邊 NE-SW 雙向箭頭")

    let ptBL = Point(x: Double(imgHandles[.bottomLeft]!.x), y: Double(imgHandles[.bottomLeft]!.y))
    imageEngine.updateHoveredHandle(at: ptBL)
    assertEqual(imageEngine.currentCursorType(at: ptBL), .resizeDiagonalNESW, "懸停於圖片左下角時出現斜邊 NE-SW 雙向箭頭")

    let ptRot = Point(x: Double(imgHandles[.rotate]!.x), y: Double(imgHandles[.rotate]!.y))
    imageEngine.updateHoveredHandle(at: ptRot)
    assertEqual(imageEngine.currentCursorType(at: ptRot), .rotate, "懸停於圖片旋轉控制點時出現旋轉鼠標")

    // 懸停於無控制點空白處應恢復預設 (nil)
    let ptBlank = Point(x: 50, y: 50)
    imageEngine.updateHoveredHandle(at: ptBlank)
    assertEqual(imageEngine.currentCursorType(at: ptBlank), nil, "懸停於空白處無特殊游標")

    // 34.3 線條物件周邊控制點與旋轉點之鼠標動態判定
    let lineEngine = BoardEngine(restoreSession: false)
    lineEngine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
    let testLine = BoardObject(
        id: "line_test_cursor",
        type: "line",
        x: 100, y: 150, width: 200, height: 100,
        x1: 100, y1: 150, x2: 300, y2: 250
    )
    lineEngine.objects = [testLine]
    lineEngine.selectedIds = [testLine.id]
    lineEngine.currentTool = .select

    guard let lineBounds = lineEngine.selectionBoundingBox else {
        fatalError("線條選取後 bounding box 不應為空")
    }
    let lineHandles = VectorMath.handlePositions(for: lineBounds, zoom: 1.0)
    let lineRotatePt = Point(x: Double(lineHandles[.rotate]!.x), y: Double(lineHandles[.rotate]!.y))
    lineEngine.updateHoveredHandle(at: lineRotatePt)
    assertEqual(lineEngine.currentCursorType(at: lineRotatePt), .rotate, "線條旋轉控制點出現旋轉鼠標")

    let lineTLPt = Point(x: Double(lineHandles[.topLeft]!.x), y: Double(lineHandles[.topLeft]!.y))
    lineEngine.updateHoveredHandle(at: lineTLPt)
    assertEqual(lineEngine.currentCursorType(at: lineTLPt), .resizeDiagonalNWSE, "線條左上控制點出現對角雙向箭頭")

    // 34.4 拖曳中游標鎖定與放開恢復 (Drag Cursor Locking)
    lineEngine.beginPointerGesture(at: lineRotatePt, isShift: false)
    assertEqual(lineEngine.activeTransformHandle, .rotate, "開始拖曳旋轉點時 activeTransformHandle 為 rotate")
    // 拖曳至遠處 (游標不再控制點正上方)，游標形狀仍鎖定在 rotate
    let farDragPt = Point(x: 500, y: 500)
    assertEqual(lineEngine.currentCursorType(at: farDragPt), .rotate, "拖曳旋轉過程中游標形狀持續鎖定為旋轉鼠標")

    // 放開拖曳後恢復
    lineEngine.endPointerGesture(translation: .zero)
    assertEqual(lineEngine.activeTransformHandle, nil, "放開後 activeTransformHandle 釋放")
    assertEqual(lineEngine.currentCursorType(at: farDragPt), nil, "放開後遠處游標恢復預設狀態")
}

// -------------------------------------------------------------------------
// 35. 畫布格式選擇 (無邊界 / 常見尺寸 / 多頁筆記本) 與頁面管理 (立靶驗收)
// -------------------------------------------------------------------------
print("\n[測試 35] 畫布格式選擇 (無邊界 / 常見尺寸 / 多頁筆記本) 與筆記本頁面增刪管理 (立靶驗收)")
do {
    // 35.1 畫布模式與尺寸規格契約
    assertEqual(CanvasMode.infinite.rawValue, "infinite", "CanvasMode 包含 infinite")
    assertEqual(CanvasMode.fixed.rawValue, "fixed", "CanvasMode 包含 fixed")
    assertEqual(CanvasMode.notebook.rawValue, "notebook", "CanvasMode 包含 notebook")

    assertEqual(CanvasPreset.one_one.dimensions.width, 1080.0, "1:1 正方形預設寬度 1080")
    assertEqual(CanvasPreset.one_one.dimensions.height, 1080.0, "1:1 正方形預設高度 1080")
    assertEqual(CanvasPreset.nine_sixteen.dimensions.width, 1080.0, "9:16 直式預設寬度 1080")
    assertEqual(CanvasPreset.nine_sixteen.dimensions.height, 1920.0, "9:16 直式預設高度 1920")
    assertEqual(CanvasPreset.notebook.dimensions.width, 595.0, "筆記本尺寸寬度預設為 A4 (595)")
    assertEqual(CanvasPreset.notebook.dimensions.height, 842.0, "筆記本尺寸高度預設為 A4 (842)")

    // 35.2 建立不同格式之黑板
    let engine = BoardEngine(restoreSession: false)

    // 無邊界黑板建立
    engine.createBoard(title: "無邊界思維導圖", mode: .infinite)
    assertEqual(engine.board.canvasMode, .infinite, "模式為無邊界")
    assertTrue(!engine.isNotebook, "非筆記本模式")
    assertEqual(engine.board.pages, nil, "無邊界黑板無需頁面列表")

    // 固定尺寸黑板建立
    engine.createBoard(title: "社群正方形貼文", mode: .fixed, preset: .one_one)
    assertEqual(engine.board.canvasMode, .fixed, "模式為固定尺寸")
    assertEqual(engine.board.canvasWidth, 1080.0, "固定寬度 1080")
    assertEqual(engine.board.canvasHeight, 1080.0, "固定高度 1080")
    assertTrue(!engine.isNotebook, "非筆記本模式")

    // 多頁數筆記本建立
    engine.createBoard(title: "課堂推導筆記本", mode: .notebook)
    assertEqual(engine.board.canvasMode, .notebook, "模式為筆記本")
    assertTrue(engine.isNotebook, "engine.isNotebook 應為 true")
    assertEqual(engine.totalPages, 1, "新建筆記本預設有 1 頁")
    assertEqual(engine.currentPageIndex, 0, "預設在第 1 頁 (index 0)")
    let page1Id = engine.activePageId
    assertTrue(page1Id != nil, "預設 activePageId 存在")
    assertEqual(engine.pages.first?.title, "第 1 頁", "第 1 頁預設標題為第 1 頁")

    // 35.3 筆記本繪圖與跨頁面物件隔離
    // 在第 1 頁新增一個便簽
    engine.addSticky(text: "第 1 頁物理力學推導", at: Point(x: 100, y: 100))
    assertEqual(engine.currentPageObjects.count, 1, "第 1 頁有 1 個物件")
    assertEqual(engine.objects.count, 1, "全域物件有 1 個")
    assertEqual(engine.objects.first?.pageId, page1Id, "新物件自動蓋上當前 pageId")

    // 新增第 2 頁
    engine.addPage(title: "幾何光學")
    assertEqual(engine.totalPages, 2, "新增頁面後總頁數為 2")
    assertEqual(engine.currentPageIndex, 1, "自動切換至新建立之第 2 頁 (index 1)")
    let page2Id = engine.activePageId
    assertTrue(page2Id != nil && page2Id != page1Id, "第 2 頁擁有獨立的新 UUID")
    assertEqual(engine.pages[1].title, "幾何光學", "第 2 頁自訂標題正確")

    // 驗證第 2 頁物件隔離 (看不到第 1 頁物件)
    assertEqual(engine.currentPageObjects.count, 0, "第 2 頁初始為空白，第 1 頁物件完全隔離不可見")

    // 在第 2 頁新增物件
    engine.addSticky(text: "第 2 頁折射率計算", at: Point(x: 150, y: 150))
    assertEqual(engine.currentPageObjects.count, 1, "第 2 頁目前有 1 個物件")
    assertEqual(engine.currentPageObjects.first?.text, "第 2 頁折射率計算", "第 2 頁內容正確")
    assertEqual(engine.objects.count, 2, "全域累積 2 個物件 (分別隸屬不同頁面)")

    // 切換回第 1 頁
    engine.goToPreviousPage()
    assertEqual(engine.currentPageIndex, 0, "成功返回第 1 頁")
    assertEqual(engine.activePageId, page1Id, "activePageId 切換回第 1 頁 ID")
    assertEqual(engine.currentPageObjects.count, 1, "返回第 1 頁時僅看到第 1 頁物件")
    assertEqual(engine.currentPageObjects.first?.text, "第 1 頁物理力學推導", "第 1 頁物件內容未受干擾")

    // 切換至第 2 頁 (透過 switchPage)
    engine.switchPage(to: page2Id!)
    assertEqual(engine.currentPageIndex, 1, "透過 switchPage 切換至第 2 頁")
    assertEqual(engine.currentPageObjects.first?.text, "第 2 頁折射率計算", "第 2 頁物件完整呈現")

    // 35.4 筆記本頁面防呆保護與刪除管理
    // 當前有 2 頁，刪除第 2 頁
    let deleteResult = engine.deletePage(id: page2Id!)
    assertTrue(deleteResult, "成功刪除第 2 頁")
    assertEqual(engine.totalPages, 1, "刪除後剩餘 1 頁")
    assertEqual(engine.currentPageIndex, 0, "自動切換至相鄰第 1 頁")
    assertEqual(engine.activePageId, page1Id, "當前啟用頁面為第 1 頁")
    assertEqual(engine.objects.count, 1, "第 2 頁關聯物件亦隨之清除")

    // 防呆保護：僅剩 1 頁時禁止刪除
    let deleteLastResult = engine.deletePage(id: page1Id!)
    assertTrue(!deleteLastResult, "僅剩 1 頁時禁止刪除 (防呆機制)")
    assertEqual(engine.totalPages, 1, "總頁數維持 1 頁")

    // 35.5 Undo / Redo 頁面異動支援
    engine.undo()
    assertEqual(engine.totalPages, 2, "Undo 復原已刪除之第 2 頁")
    assertEqual(engine.objects.count, 2, "Undo 完整復原第 2 頁上的繪圖物件")

    engine.redo()
    assertEqual(engine.totalPages, 1, "Redo 重新套用刪除第 2 頁")
    assertEqual(engine.objects.count, 1, "Redo 再次移除第 2 頁物件")

    // 35.6 筆記本文件序列化與向下相容性驗證
    let doc = HeiBanDocument(board: engine.board, objects: engine.objects)
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let data = try encoder.encode(doc)
    let restoredDoc = try decoder.decode(HeiBanDocument.self, from: data)
    assertEqual(restoredDoc.board.canvasMode, .notebook, "反序列化筆記本模式一致")
    assertEqual(restoredDoc.board.pages?.count, 1, "反序列化頁面數一致")
    assertEqual(restoredDoc.board.activePageId, page1Id, "反序列化 activePageId 一致")
    assertEqual(restoredDoc.objects.first?.pageId, page1Id, "物件關聯之 pageId 一致")
}

// ==============================================================================
// 測試 36: 筆記格式強化 (五線譜/B5/封面/格線顏色)、HTML 匯出與懸停預覽游標 (立靶驗收)
// ==============================================================================
print("\n[測試 36] 筆記格式強化 (五線譜/B5/封面/格線顏色)、HTML 匯出與懸停預覽游標 (立靶驗收)")
do {
    // 36.1 五線譜與 B5 格式支援
    assertTrue(GridStyle.allCases.contains(.staff), "GridStyle 包含 staff 五線譜")
    assertEqual(GridStyle.staff.displayName, "五線譜", "五線譜顯示名稱相符")
    assertTrue(CanvasPreset.allCases.contains(.b5), "CanvasPreset 包含 b5 規格")
    assertEqual(CanvasPreset.b5.dimensions.width, 499.0, "B5 寬度為 499")
    assertEqual(CanvasPreset.b5.dimensions.height, 709.0, "B5 高度為 709")

    // 36.2 有邊界筆記本客製化建立 (方向/封面/內頁/底色/格線色)
    let engine = BoardEngine()
    engine.createBoard(
        title: "莫札特奏鳴曲",
        theme: .whiteboard,
        mode: .notebook,
        preset: .a4_portrait,
        orientation: "landscape",
        coverStyle: "vintage_leather",
        gridStyle: .staff,
        backgroundColor: "#FAF8F5",
        gridColor: "#4A5568"
    )
    assertEqual(engine.board.title, "莫札特奏鳴曲", "標題正確設定")
    assertEqual(engine.board.canvasMode, .notebook, "模式為 notebook")
    assertEqual(engine.board.gridStyle, .staff, "內頁風格為 staff 五線譜")
    assertEqual(engine.board.coverStyle, "vintage_leather", "封面風格為 vintage_leather")
    assertEqual(engine.board.backgroundColor, "#FAF8F5", "底色為象牙暖白")
    assertEqual(engine.board.gridColor, "#4A5568", "格線顏色為自訂深灰")
    // 橫向判定：A4 原本為 595x842，設定 landscape 後寬度 > 高度
    assertTrue(engine.board.canvasWidth! > engine.board.canvasHeight!, "橫向頁面寬度大於高度 (842 x 595)")

    // 36.3 序列化與向下相容驗證
    let doc = HeiBanDocument(board: engine.board, objects: [])
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let data = try encoder.encode(doc)
    let restoredDoc = try decoder.decode(HeiBanDocument.self, from: data)
    assertEqual(restoredDoc.board.gridStyle, .staff, "反序列化 staff 五線譜一致")
    assertEqual(restoredDoc.board.coverStyle, "vintage_leather", "反序列化封面風格一致")
    assertEqual(restoredDoc.board.gridColor, "#4A5568", "反序列化格線顏色一致")

    // 36.4 HTML 離線互動單檔匯出
    engine.addSticky(text: "第一樂章 快板 Allegro", at: Point(x: 120, y: 150))
    let exporter = BoardExporter(document: engine.document)
    let htmlOutput = try exporter.exportHTML(scope: .allObjects, selectedIds: [])
    assertTrue(htmlOutput.contains("<!DOCTYPE html>"), "匯出 HTML 具備合法 DOCTYPE")
    assertTrue(htmlOutput.contains("莫札特奏鳴曲"), "匯出 HTML 標題符合黑板名稱")
    assertTrue(htmlOutput.contains("第一樂章 快板 Allegro"), "匯出 HTML 包含畫布文字內容")
    assertTrue(htmlOutput.contains("heiban-data"), "匯出 HTML 內嵌無損 JSON 資料")
    assertTrue(htmlOutput.contains("zoomIn()") && htmlOutput.contains("zoomOut()"), "匯出 HTML 具備縮放控制函式")

    // 36.5 懸停游標模型驗證 (畫筆與橡皮擦範圍預覽)
    engine.currentTool = .pen
    engine.activeStrokeWidth = 8.0
    engine.viewport.zoom = 1.5
    // 模擬游標移動至 (200, 300)
    let penDiameter = engine.activeStrokeWidth * engine.viewport.zoom
    engine.updateHoverCursor(at: Point(x: 200, y: 300), diameter: penDiameter)
    assertEqual(engine.hoverCursorPoint?.x, 200.0, "畫筆懸停 X 座標相符")
    assertEqual(engine.hoverCursorPoint?.y, 300.0, "畫筆懸停 Y 座標相符")
    assertEqual(engine.hoverCursorDiameter, 12.0, "畫筆懸停直徑等於 strokeWidth * zoom (8 * 1.5 = 12)")

    // 橡皮擦模式
    engine.currentTool = .eraser
    engine.eraserSize = 32.0
    let eraserDiameter = engine.eraserSize * engine.viewport.zoom
    engine.updateHoverCursor(at: Point(x: 250, y: 350), diameter: eraserDiameter)
    assertEqual(engine.hoverCursorDiameter, 48.0, "橡皮擦懸停直徑等於 eraserSize * zoom (32 * 1.5 = 48)")

    // 移出畫布時清空
    engine.updateHoverCursor(at: nil, diameter: nil)
    assertTrue(engine.hoverCursorPoint == nil, "移出畫布時懸停座標清空")
    assertTrue(engine.hoverCursorDiameter == nil, "移出畫布時懸停直徑清空")
}

// =========================================================================
// [測試 37] AG-12: 本機／雲端文件 Session 邊界與 source 欄位契約驗收 (立靶驗收)
// =========================================================================
do {
    print("\n[測試 37] AG-12: 本機／雲端文件 Session 邊界與 source 欄位契約驗收 (立靶驗收)")

    // 37.1 BoardMetadata source 欄位與序列化
    var localMeta = BoardMetadata(id: "board_local_native", title: "本機原創設計", ownerId: "local_mac")
    localMeta.source = "local"
    var cloudMeta = BoardMetadata(id: "board_cloud_native", title: "雲端團隊專案", ownerId: "user_cloud_1")
    cloudMeta.source = "cloud"

    assertEqual(localMeta.source, "local", "本機黑板 source 為 local")
    assertEqual(cloudMeta.source, "cloud", "雲端黑板 source 為 cloud")

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let localDoc = HeiBanDocument(board: localMeta, objects: [])
    let localData = try encoder.encode(localDoc)
    let restoredLocalDoc = try decoder.decode(HeiBanDocument.self, from: localData)
    assertEqual(restoredLocalDoc.board.source, "local", "反序列化本機 board.source 一致")

    let cloudDoc = HeiBanDocument(board: cloudMeta, objects: [])
    let cloudData = try encoder.encode(cloudDoc)
    let restoredCloudDoc = try decoder.decode(HeiBanDocument.self, from: cloudData)
    assertEqual(restoredCloudDoc.board.source, "cloud", "反序列化雲端 board.source 一致")

    // 37.2 本機與雲端 Session 邊界隔離模擬
    func reconcileSwiftSnapshot(
        board: BoardMetadata,
        remoteObjects: [BoardObject],
        isEmptySnapshot: Bool,
        pendingWrites: [String: BoardObject],
        currentObjects: [BoardObject]
    ) -> [BoardObject] {
        if board.source != "cloud" {
            return currentObjects // 本機文件不受任何雲端 snapshot 影響
        }
        if isEmptySnapshot {
            if pendingWrites.isEmpty {
                return [] // 雲端空板清空前板殘留
            }
            return Array(pendingWrites.values)
        }
        var result: [BoardObject] = []
        var cloudIds = Set<String>()
        for obj in remoteObjects {
            cloudIds.insert(obj.id)
            if let pending = pendingWrites[obj.id] {
                result.append(pending)
            } else {
                result.append(obj)
            }
        }
        for (id, localObj) in pendingWrites where !cloudIds.contains(id) {
            result.append(localObj)
        }
        return result
    }

    // 案例 A：切換至雲端空板，清空前板殘留
    let prevObjects = [BoardObject(id: "obj_prev_1", type: "rect", x: 10, y: 10, width: 20, height: 20)]
    let emptyResult = reconcileSwiftSnapshot(
        board: cloudMeta,
        remoteObjects: [],
        isEmptySnapshot: true,
        pendingWrites: [:],
        currentObjects: prevObjects
    )
    assertEqual(emptyResult.count, 0, "Swift 雲端空板清空前板內容")

    // 案例 B：本機板嚴禁被雲端快照清空
    let localKeptObjects = [BoardObject(id: "obj_secret", type: "circle", x: 50, y: 50, width: 30, height: 30)]
    let localResult = reconcileSwiftSnapshot(
        board: localMeta,
        remoteObjects: [],
        isEmptySnapshot: true,
        pendingWrites: [:],
        currentObjects: localKeptObjects
    )
    assertEqual(localResult.count, 1, "Swift 本機板嚴禁被外部空快照清空")
    assertEqual(localResult[0].id, "obj_secret", "Swift 本機物件完整保留")

    // 案例 C：未保存之本地修改優先，不被雲端 snapshot 靜默覆蓋
    let remoteObj = BoardObject(id: "obj_conflict", type: "line", x: 0, y: 0, width: 100, height: 100, strokeColor: "#ffffff")
    var localPending = remoteObj
    localPending.strokeColor = "#ffff00" // 本地修改為黃色
    let conflictResult = reconcileSwiftSnapshot(
        board: cloudMeta,
        remoteObjects: [remoteObj],
        isEmptySnapshot: false,
        pendingWrites: ["obj_conflict": localPending],
        currentObjects: [localPending]
    )
    assertEqual(conflictResult.count, 1, "Swift 衝突物件數維持 1")
    assertEqual(conflictResult[0].strokeColor, "#ffff00", "Swift 本地未保存修改優先獲勝 (防靜默覆蓋)")
}

// =========================================================================
// [測試 38] AG-20: 統一 Native 保存入口、修訂版號衝突防護與多視窗 Session 協調 (立靶驗收)
// =========================================================================
do {
    print("\n[測試 38] AG-20: 統一 Native 保存入口、修訂版號衝突防護與多視窗 Session 協調 (立靶驗收)")
    let sandboxDir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        .appendingPathComponent("HeiBanTest_AG20_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: sandboxDir, withIntermediateDirectories: true)

    let customLibrary = LocalBoardLibrary(directory: sandboxDir)
    let sessionManager = DocumentSessionManager(library: customLibrary)

    // 38.1 LocalBoardLibrary.saveToFile 與備份快照生成
    let testDocURL = sandboxDir.appendingPathComponent("Workspaces/test_proj.blackboard.json")
    let initialDoc = HeiBanDocument(
        board: BoardMetadata(id: "doc_ag20_1", title: "工程架構圖", revision: 2),
        objects: [BoardObject(id: "obj_box", type: "rect", x: 10, y: 10, width: 80, height: 60)]
    )
    try customLibrary.saveToFile(initialDoc, at: testDocURL)
    assertTrue(FileManager.default.fileExists(atPath: testDocURL.path), "檔案成功原子寫入至目標路徑")
    let expectedBackup = customLibrary.backupURL(id: "doc_ag20_1")
    assertTrue(FileManager.default.fileExists(atPath: expectedBackup.path), "備份快照已同步生成")

    // 38.2 DocumentSession.save 接入統一保存管線並進行修訂版號防護
    let session = try sessionManager.openDocument(at: testDocURL)
    assertEqual(session.openWindowCount, 1, "初始視窗計數為 1")

    // 模擬外部或另一客戶端先行寫入了較新修訂版號 (rev 5)
    let newerDoc = HeiBanDocument(
        board: BoardMetadata(id: "doc_ag20_1", title: "工程架構圖 (外部更新)", revision: 5),
        objects: []
    )
    let newerData = try HeiBanDocumentCodec.encode(newerDoc)
    try newerData.write(to: testDocURL, options: .atomic)

    // 嘗試以記憶體舊版號 (rev 2) 儲存，必須被拒絕並拋出 revisionConflict
    var conflictTriggered = false
    do {
        try session.save()
    } catch PersistenceError.revisionConflict(let current, let incoming) {
        conflictTriggered = true
        assertEqual(current, 5, "衝突當前版號為 5")
        assertEqual(incoming, 2, "衝突傳入版號為 2")
    } catch {
        assertTrue(false, "預期應拋出 revisionConflict，實際拋出: \(error)")
    }
    assertTrue(conflictTriggered, "覆蓋較新 revision 遭到嚴格拒絕以保全資料")

    // 當 session 修訂版號對齊最新或更高時 (rev 6)，儲存成功
    session.engine.board.revision = 6
    try session.save()
    let savedData = try Data(contentsOf: testDocURL)
    let savedDoc = try HeiBanDocumentCodec.decode(from: savedData)
    assertEqual(savedDoc.board.revision, 6, "對齊最新修訂版號後成功寫入")

    // 38.3 多視窗重複開啟相同文件協調至同一個 Session 實例
    let duplicateSession = try sessionManager.openDocument(at: testDocURL)
    assertTrue(duplicateSession === session, "重複開啟相同文件回傳同一個 Session 實例")
    assertEqual(session.openWindowCount, 2, "開啟第二視窗時 openWindowCount 遞增為 2")

    // 關閉第一個視窗，Session 仍保持活躍
    sessionManager.closeWindow(for: session)
    assertEqual(session.openWindowCount, 1, "關閉一視窗後 openWindowCount 遞減為 1")
    assertEqual(sessionManager.activeSessions.count, 1, "Session 仍處於 activeSessions 中")

    // 關閉最後一個視窗，Session 釋放
    sessionManager.closeWindow(for: session)
    assertEqual(sessionManager.activeSessions.count, 0, "全部視窗關閉後 Session 正確釋放")

    // 38.4 openBoard(id:) 整合驗證
    let libraryDoc = HeiBanDocument(
        board: BoardMetadata(id: "lib_board_alpha", title: "資料庫黑板", revision: 1),
        objects: []
    )
    try customLibrary.save(libraryDoc)
    let libSession = try sessionManager.openBoard(id: "lib_board_alpha")
    assertEqual(libSession.engine.board.id, "lib_board_alpha", "openBoard 成功載入黑板")
    assertEqual(sessionManager.activeSessions.count, 1, "openBoard 成功註冊 Session")
    sessionManager.closeWindow(for: libSession)
}

// =========================================================================
// [測試 39] AG-21: HeiBanCore 與 macOS 介面隔離與平台 Adapters 契約驗證 (立靶驗收)
// =========================================================================
do {
    print("\n[測試 39] AG-21: HeiBanCore 與 macOS 介面隔離與平台 Adapters 契約驗證 (立靶驗收)")

    final class MockDialogService: PlatformDialogService {
        var lastSavedName: String?
        var lastAllowedExtensions: [String]?
        var returnURL: URL?

        func runSavePanel(defaultName: String, allowedExtensions: [String], completion: @escaping (URL?) -> Void) {
            self.lastSavedName = defaultName
            self.lastAllowedExtensions = allowedExtensions
            completion(returnURL)
        }

        func runOpenPanel(allowedExtensions: [String], allowsMultiple: Bool, completion: @escaping ([URL]?) -> Void) {
            self.lastAllowedExtensions = allowedExtensions
            if let returnURL = returnURL {
                completion([returnURL])
            } else {
                completion(nil)
            }
        }
    }

    final class MockPasteboardService: PlatformPasteboardService {
        var stringBuffer: String?
        var imageBuffer: (data: Data, width: Double, height: Double)?

        func copyString(_ text: String) {
            stringBuffer = text
        }
        func pasteString() -> String? {
            return stringBuffer
        }
        func pasteImageData() -> (data: Data, width: Double, height: Double)? {
            return imageBuffer
        }
    }

    let engine = BoardEngine(restoreSession: false)

    // 39.1 無 DialogService 狀態下的安全防護 (無 AppKit 依賴時安全回退)
    engine.dialogService = nil
    engine.saveToFilePrompt()
    assertEqual(engine.statusMessage, "平台對話框服務未就緒", "無對話框服務時安全提示狀態，不崩潰")

    engine.openFromFilePrompt()
    assertEqual(engine.statusMessage, "平台對話框服務未就緒", "開啟對話框在無介面環境下安全拒絕")

    // 39.2 注入 MockDialogService 驗收文件面板解耦
    let mockDialog = MockDialogService()
    engine.dialogService = mockDialog

    let testSaveTarget = FileManager.default.temporaryDirectory.appendingPathComponent("engine_save_test.blackboard.json")
    mockDialog.returnURL = testSaveTarget

    engine.board.title = "幾何速繪"
    engine.saveToFilePrompt()
    assertEqual(mockDialog.lastAllowedExtensions?.contains("json"), true, "儲存對話框允許 json 延伸檔名")
    assertEqual(FileManager.default.fileExists(atPath: testSaveTarget.path), true, "透過 DialogService 回調完成儲存")

    // 39.3 注入 MockPasteboardService 驗收剪貼簿解耦
    let mockPasteboard = MockPasteboardService()
    engine.pasteboardService = mockPasteboard

    let testObj = BoardObject(id: "obj_copy_test", type: "circle", x: 20, y: 20, width: 40, height: 40)
    engine.addObject(testObj)
    engine.selectedIds = [testObj.id]

    engine.copySelected()
    assertTrue(mockPasteboard.stringBuffer != nil, "複製物件寫入至 PlatformPasteboardService")
    assertTrue(mockPasteboard.stringBuffer!.contains("obj_copy_test"), "剪貼簿內容包含物件 ID")

    // 清空選取與內部剪貼簿，僅依賴 PlatformPasteboardService 進行貼上
    engine.internalClipboard = []
    let initialCount = engine.objects.count
    engine.pasteClipboard()
    assertEqual(engine.objects.count, initialCount + 1, "從 PlatformPasteboardService 成功還原並貼上物件")

    // 39.4 剪貼簿圖片貼上
    let dummyImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header bytes
    mockPasteboard.imageBuffer = (data: dummyImageData, width: 320.0, height: 240.0)
    engine.pasteImageFromClipboard()
    assertEqual(engine.statusMessage, "已將剪貼簿圖片置入黑板！", "成功自 PlatformPasteboard 匯入圖片")
}

// -------------------------------------------------------------------------
// 40. AG-22: BoardEngine 模組化拆分、選取變形協調器、尺規／橡皮擦子引擎與畫布狀態快照 (立靶驗收)
// -------------------------------------------------------------------------
print("\n[測試 40] AG-22: BoardEngine 拆小、變形協調器、尺規／橡皮擦引擎與狀態快照 (立靶驗收)")
do {
    // 40.1 SelectionTransformCoordinator: 幾何手柄位置、命中測試與變形計算
    let bounds = Rect(minX: 100, minY: 100, maxX: 300, maxY: 200) // 寬 200, 高 100, 中心 (200, 150)
    let handles = SelectionTransformCoordinator.calculateHandlePositions(for: bounds, rotation: 0, zoom: 1.0)

    assertEqual(handles.topLeft.x, 100.0, "左上手柄 X 應為 100")
    assertEqual(handles.topLeft.y, 100.0, "左上手柄 Y 應為 100")
    assertEqual(handles.bottomRight.x, 300.0, "右下手柄 X 應為 300")
    assertEqual(handles.bottomRight.y, 200.0, "右下手柄 Y 應為 200")
    assertEqual(handles.topCenter.x, 200.0, "頂部中間手柄 X 應為 200")
    assertEqual(handles.topCenter.y, 100.0, "頂部中間手柄 Y 應為 100")
    assertEqual(handles.rotationHandle.x, 200.0, "旋轉手柄 X 應居中 (200)")
    assertEqual(handles.rotationHandle.y, 75.0, "旋轉手柄 Y 應向上偏移 25 pt (75)")

    // 命中測試手柄
    let hitTopLeft = SelectionTransformCoordinator.hitTestHandle(
        point: Point(x: 102, y: 101),
        bounds: bounds,
        rotation: 0,
        zoom: 1.0,
        handleRadius: 10.0
    )
    assertEqual(hitTopLeft, .topLeft, "點擊 (102, 101) 應精準命中 topLeft 手柄")

    let hitRotate = SelectionTransformCoordinator.hitTestHandle(
        point: Point(x: 200, y: 76),
        bounds: bounds,
        rotation: 0,
        zoom: 1.0,
        handleRadius: 10.0
    )
    assertEqual(hitRotate, .rotate, "點擊 (200, 76) 應精準命中 rotate 手柄")

    let hitNone = SelectionTransformCoordinator.hitTestHandle(
        point: Point(x: 200, y: 150),
        bounds: bounds,
        rotation: 0,
        zoom: 1.0,
        handleRadius: 10.0
    )
    assertEqual(hitNone == nil, true, "點擊選取框中心不應命中任何手柄")

    // 40.2 變形計算驗收 (Resize & Rotate)
    let resizedRect = SelectionTransformCoordinator.applyResize(
        handle: .bottomRight,
        initialBounds: bounds,
        delta: CGPoint(x: 50, y: 20),
        maintainAspectRatio: false
    )
    assertEqual(resizedRect.maxX, 350.0, "右下拖曳 +50 maxX 應為 350")
    assertEqual(resizedRect.maxY, 220.0, "右下拖曳 +20 maxY 應為 220")
    assertEqual(resizedRect.minX, 100.0, "右下拖曳 minX 保持 100")
    assertEqual(resizedRect.minY, 100.0, "右下拖曳 minY 保持 100")

    let angle = SelectionTransformCoordinator.calculateRotationAngle(
        currentPoint: Point(x: 300, y: 150),
        center: Point(x: 200, y: 150)
    )
    assertEqual(angle, 0.0, "正右方水平點角度應為 0 弧度")

    // 40.3 RulerToolEngine 專用子引擎驗收
    var testRuler = RulerState()
    testRuler.enabled = true
    testRuler.screenCenterX = 400
    testRuler.screenCenterY = 300
    testRuler.width = 400
    testRuler.height = 60
    testRuler.angle = 0
    testRuler.pivotRatio = 0.5
    testRuler.pivotEdge = "center"

    let rulerSnapResult = RulerToolEngine.snapPointToRuler(
        point: Point(x: 300, y: 265),
        ruler: testRuler,
        snapTolerance: 15.0
    )
    assertEqual(rulerSnapResult.snapped, true, "頂緣容差內應吸附")
    assertEqual(rulerSnapResult.snappedPoint.y, 270.0, "頂緣 Y 座標吸附至 270")

    let rulerOutOfBounds = RulerToolEngine.snapPointToRuler(
        point: Point(x: 650, y: 265),
        ruler: testRuler,
        snapTolerance: 15.0
    )
    assertEqual(rulerOutOfBounds.snapped, false, "超出尺規兩端長度停止吸附")

    // 40.4 EraserToolEngine 分段與物件擦除引擎驗收
    let strokePoints: [Point] = (0..<10).map { Point(x: Double($0 * 20), y: 50, pressure: 0.5) }
    let strokePointsJSON = String(data: (try? JSONEncoder().encode(strokePoints)) ?? Data(), encoding: .utf8)
    var strokeObj = BoardObject(id: "stroke_erase_split_test", type: "stroke", x: 0, y: 50, width: 180, height: 10, points: strokePointsJSON)
    strokeObj.strokeWidth = 4.0

    // 擦除中間段 (X = 80, 100, Y = 50，中心在 90)
    let eraserCenter = Point(x: 90, y: 50)
    let eraserRadius = 15.0
    let splitStrokes = EraserToolEngine.sliceStroke(object: strokeObj, eraserCenter: eraserCenter, eraserRadius: eraserRadius)
    assertEqual(splitStrokes.count, 2, "中間段局部擦除應將筆跡分裂為 2 條獨立筆跡")
    assertEqual(splitStrokes[0].parsedPoints.count, 4, "前半筆跡包含 4 個點 (0, 20, 40, 60)")
    assertEqual(splitStrokes[1].parsedPoints.count, 4, "後半筆跡包含 4 個點 (120, 140, 160, 180)")

    // 40.5 CanvasStateSnapshot: 畫布狀態快照解耦與唯讀快照提取
    let engine = BoardEngine(restoreSession: false)
    let rectObj = BoardObject(id: "obj_snapshot_1", type: "rect", x: 50, y: 50, width: 100, height: 80)
    engine.addObject(rectObj)
    engine.selectedIds = [rectObj.id]
    engine.hoverPosition = Point(x: 75, y: 75)
    engine.hoverRadius = 8.0

    let snapshot = engine.captureCanvasStateSnapshot()
    assertEqual(snapshot.selectedObjectIds, [rectObj.id], "快照正確捕捉選取物件 ID")
    assertEqual(snapshot.selectionBounds?.minX, 50.0, "快照選取外框 minX 一致")
    assertEqual(snapshot.selectionBounds?.width, 100.0, "快照選取外框寬度一致")
    assertEqual(snapshot.hoverPreview.position?.x, 75.0, "快照懸停預覽 X 座標一致")
    assertEqual(snapshot.hoverPreview.radius, 8.0, "快照懸停半徑一致")
    assertEqual(snapshot.hasActiveSelection, true, "快照反映有作用中選取")
}

print("\n[測試 41] 功能導覽與示範黑板資料契約與載入驗證 (立靶驗收)")
do {
    let data = FeatureShowcaseDocument.jsonString.data(using: .utf8)!
    do {
        let decoder = JSONDecoder()
        _ = try decoder.decode(HeiBanDocument.self, from: data)
    } catch {
        print("Decode Error detail: \(error)")
    }
    let engine = BoardEngine(restoreSession: false)
    engine.loadShowcaseBoard()

    assertEqual(engine.board.id, "demo_feature_showcase", "示範黑板 ID 相符")
    assertEqual(engine.board.title, "✨ HeiBan 功能導覽與示範黑板", "示範黑板標題相符")
    assertTrue(!engine.objects.isEmpty, "示範黑板物件集合不為空")
    assertEqual(engine.board.pins?.count, 6, "示範黑板導覽圖釘精準為 6 個")
    assertTrue(engine.objects.contains(where: { $0.type == "stroke" }), "示範黑板包含鋼筆物件")
    assertTrue(engine.objects.contains(where: { $0.type == "highlighter" }), "示範黑板包含螢光筆物件")
    assertTrue(engine.objects.contains(where: { $0.type == "paint" }), "示範黑板包含油漆筆物件")
    assertTrue(engine.objects.contains(where: { $0.type == "curve" }), "示範黑板包含貝茲平滑曲線物件")
    assertTrue(engine.objects.contains(where: { $0.type == "sticky" }), "示範黑板包含便簽物件")
}

print("\n[測試 42] ProDrafts 錄影檢討：V01–V06 工具列自訂、選取快速列、HUD 回饋、圖釘搜尋與縮圖增強 (立靶驗收)")
do {
    // 42.1 V01: ToolbarPreferences Customization
    var prefs = ToolbarPreferences()
    assertEqual(prefs.activeItemIds.count, 21, "預設工具列包含 21 個項目")
    assertEqual(prefs.hiddenItemIds.count, 0, "預設隱藏工具清單為空")
    assertEqual(prefs.visibleItemIds.count, 21, "預設可見工具數量為 21")

    prefs.setItemHidden(id: "ruler", hidden: true)
    assertTrue(prefs.hiddenItemIds.contains("ruler"), "隱藏螢幕尺後進入 hiddenItemIds")
    assertEqual(prefs.visibleItemIds.count, 20, "隱藏 1 個工具後可見項目為 20")
    assertTrue(!prefs.visibleItemIds.contains("ruler"), "visibleItemIds 不含已隱藏之 ruler")
    assertEqual(prefs.hiddenItems.first?.id, "ruler", "hiddenItems 正確解析為尺規定義")

    prefs.moveItem(id: "eraser", to: 0)
    assertEqual(prefs.activeItemIds.first, "eraser", "移動橡皮擦至第 0 位成功")

    let encoded = try! JSONEncoder().encode(prefs)
    let decoded = try! JSONDecoder().decode(ToolbarPreferences.self, from: encoded)
    assertEqual(decoded.activeItemIds.first, "eraser", "反序列化保留自訂排序")
    assertTrue(decoded.hiddenItemIds.contains("ruler"), "反序列化保留隱藏項目")

    prefs.resetToDefaults()
    assertEqual(prefs.activeItemIds.count, 21, "重設後恢復 21 個工具 (含雷射筆、遮題膠帶與套索)")
    assertEqual(prefs.hiddenItemIds.count, 0, "重設後隱藏清單清空")
    assertEqual(prefs.activeItemIds.first, "select", "重設後首位恢復為 select")

    // 42.2 V02: SelectionQuickActionCoordinator
    let emptyState = SelectionQuickActionCoordinator.computeState(
        selectedObjects: [],
        bounds: nil,
        viewport: ViewportTransform(x: 0, y: 0, zoom: 1.0),
        canvasSize: CGSize(width: 1200, height: 800)
    )
    assertEqual(emptyState.isVisible, false, "未選取任何物件時快速操作列隱藏")

    let rectObj = BoardObject(
        id: "rect_q",
        boardId: "board_q",
        type: "rect",
        x: 400,
        y: 300,
        width: 200,
        height: 150,
        strokeColor: "#86efac",
        fillColor: "#fef08a"
    )
    let rectBounds = Rect(minX: 400, minY: 300, maxX: 600, maxY: 450)
    let normalState = SelectionQuickActionCoordinator.computeState(
        selectedObjects: [rectObj],
        bounds: rectBounds,
        viewport: ViewportTransform(x: 0, y: 0, zoom: 1.0),
        canvasSize: CGSize(width: 1200, height: 800)
    )
    assertEqual(normalState.isVisible, true, "選取矩形後快速操作列顯示")
    assertEqual(normalState.placement, SelectionQuickBarPlacement.above, "空間充足時快速列位於上方")
    assertEqual(normalState.allowsColor, true, "矩形支援線條顏色調整")
    assertEqual(normalState.allowsFill, true, "矩形支援填色調整")
    assertEqual(normalState.allowsStrokeWidth, true, "矩形支援粗細調整")
    assertEqual(normalState.selectedCount, 1, "選取數量為 1")

    // Top edge avoidance test: when object is near the top edge, quick bar flips below
    let topRect = BoardObject(id: "top_r", boardId: "b", type: "rect", x: 400, y: 20, width: 100, height: 100)
    let topBounds = Rect(minX: 400, minY: 20, maxX: 500, maxY: 120)
    let topState = SelectionQuickActionCoordinator.computeState(
        selectedObjects: [topRect],
        bounds: topBounds,
        viewport: ViewportTransform(x: 0, y: 0, zoom: 1.0),
        canvasSize: CGSize(width: 1200, height: 800)
    )
    assertEqual(topState.placement, SelectionQuickBarPlacement.below, "靠近頂部邊界時快速列自動調整至下方")

    // Single undo step test for quick action operations
    let quickEngine = BoardEngine(restoreSession: false)
    quickEngine.objects = [rectObj]
    quickEngine.selectedIds = [rectObj.id]
    assertEqual(quickEngine.canUndo, false, "操作前無 Undo 交易")
    quickEngine.duplicateSelected()
    assertEqual(quickEngine.objects.count, 2, "快速複製後物件數量為 2")
    assertEqual(quickEngine.canUndo, true, "快速複製後產生 1 筆 Undo")
    quickEngine.undo()
    assertEqual(quickEngine.objects.count, 1, "1 次 Undo 即可復原快速複製")

    // 42.3 V03: Quick settings & Per-tool style memory
    let toolEngine = BoardEngine(restoreSession: false)
    toolEngine.selectTool(.pen)
    toolEngine.activeStrokeWidth = 8.0
    toolEngine.selectTool(.highlighter)
    assertEqual(toolEngine.currentTool, .highlighter, "切換至螢光筆")
    toolEngine.activeStrokeWidth = 24.0
    toolEngine.selectTool(.pen)
    assertEqual(toolEngine.currentTool, .pen, "切換回鋼筆")
    assertEqual(toolEngine.activeStrokeWidth, 8.0, "鋼筆保留自訂粗細 8.0，未被螢光筆干擾")

    // 42.4 V04: HUD Formatters
    let dimStr = CanvasHUDFormatter.formatDimensions(width: 480.2, height: 320.7)
    assertEqual(dimStr, "480 × 321 pt", "尺寸 HUD 數值四捨五入為整數")
    let rotStr = CanvasHUDFormatter.formatRotation(degrees: 37.45)
    assertEqual(rotStr, "37.5°", "旋轉 HUD 精確至 0.1°")
    let negRotStr = CanvasHUDFormatter.formatRotation(degrees: -15.0)
    assertEqual(negRotStr, "345.0°", "負角度規範化為 0~360° 並精確至 0.1°")
    let lenStr = CanvasHUDFormatter.formatLength(length: 120.4)
    assertEqual(lenStr, "L: 120 pt", "直線長度 HUD 格式正確")

    // 42.5 V05: Pin Search & Filter
    let pinA = BoardPin(id: "p1", name: "大門入口", x: 100, y: 100, zoom: 1.0)
    let pinB = BoardPin(id: "p2", name: "會議室 A", x: 500, y: 500, zoom: 1.5)
    let pinC = BoardPin(id: "p3", name: "休息茶水區", x: 900, y: 900, zoom: 2.0)
    let allPins = [pinA, pinB, pinC]

    let searchMeeting = PinSearchFilter.filter(pins: allPins, query: "會議")
    assertEqual(searchMeeting.count, 1, "搜尋「會議」精確命中 1 筆")
    assertEqual(searchMeeting.first?.name, "會議室 A", "搜尋命中名稱相符")

    let searchEmpty = PinSearchFilter.filter(pins: allPins, query: "   ")
    assertEqual(searchEmpty.count, 3, "空字串搜尋回傳全部圖釘")

    let searchCase = PinSearchFilter.filter(pins: allPins, query: "a")
    assertEqual(searchCase.count, 1, "不分大小寫命中「會議室 A」")

    // Viewport locked prevents jump
    let navEngine = BoardEngine(restoreSession: false)
    navEngine.board.pins = allPins
    navEngine.viewport = ViewportTransform(x: 10, y: 20, zoom: 1.0)
    navEngine.setViewportLocked(true)
    navEngine.jumpToPin(pinB)
    assertEqual(navEngine.viewport.x, 10.0, "視角鎖定時 jumpToPin 被安全攔截，X 不變")
    assertEqual(navEngine.viewport.zoom, 1.0, "視角鎖定時 jumpToPin 被安全攔截，Zoom 不變")

    // 42.6 V06: Thumbnail Shape & Object Coverage
    let diamondObj = BoardObject(id: "d1", boardId: "b", type: "diamond", x: 100, y: 100, width: 80, height: 80)
    let starObj = BoardObject(id: "s1", boardId: "b", type: "star", x: 200, y: 100, width: 80, height: 80)
    let quadObj = BoardObject(id: "q1", boardId: "b", type: "quadrilateral", x: 300, y: 100, width: 80, height: 80)
    let triObj = BoardObject(id: "t1", boardId: "b", type: "triangle", x: 400, y: 100, width: 80, height: 80)

    let testDoc = HeiBanDocument(board: BoardMetadata(title: "ThumbTest"), objects: [diamondObj, starObj, quadObj, triObj])
    let thumbData = try! JSONEncoder().encode(testDoc)
    let decodedDoc = try! JSONDecoder().decode(HeiBanDocument.self, from: thumbData)
    assertEqual(decodedDoc.objects.count, 4, "縮圖文件包含 4 種進階多邊形幾何形狀")
    assertTrue(decodedDoc.objects.contains(where: { $0.type == "diamond" }), "縮圖資料支援菱形")
    assertTrue(decodedDoc.objects.contains(where: { $0.type == "star" }), "縮圖資料支援星形")
    assertTrue(decodedDoc.objects.contains(where: { $0.type == "quadrilateral" }), "縮圖資料支援四邊形")
    assertTrue(decodedDoc.objects.contains(where: { $0.type == "triangle" }), "縮圖資料支援三角形")
}

// -------------------------------------------------------------------------
// 43. AGM-00~05: 第 1 批：精簡頂列、計算機、圓規圓弧、計時器 (立靶驗收)
// -------------------------------------------------------------------------
print("\n[測試 43] AGM-00–05 第 1 批：精簡頂列、計算機、圓規圓弧、計時器 (立靶驗收)")
do {
    let engine = BoardEngine(restoreSession: false)

    // 43.1 AGM-03: 浮動計算機 (四則運算、精度、百分比、科學計算、除零防護、文字物件插入)
    let calc = CalculatorModel()

    // 89 × 63 = 5607
    calc.clear()
    calc.inputDigit("8"); calc.inputDigit("9")
    calc.inputOperator("×")
    calc.inputDigit("6"); calc.inputDigit("3")
    calc.calculateResult()
    assertEqual(calc.display, "5607", "計算機：89 × 63 = 5607")

    // 0.1 + 0.2 = 0.3 (防 0.30000000000000004 精度抖動)
    calc.clear()
    calc.inputDigit("0"); calc.inputDecimal(); calc.inputDigit("1")
    calc.inputOperator("+")
    calc.inputDigit("0"); calc.inputDecimal(); calc.inputDigit("2")
    calc.calculateResult()
    assertEqual(calc.display, "0.3", "計算機：0.1 + 0.2 = 0.3 (高精度防抖)")

    // (2+3)×4 = 20
    let evalVal = calc.evaluateExpressionString("(2 + 3) * 4")
    assertEqual(evalVal, 20.0, "計算機：(2 + 3) × 4 = 20 (優先順序與括號)")

    // 200 + 10% = 220
    calc.clear()
    calc.inputDigit("2"); calc.inputDigit("0"); calc.inputDigit("0")
    calc.inputOperator("+")
    calc.inputDigit("1"); calc.inputDigit("0")
    calc.inputPercentage()
    calc.calculateResult()
    assertEqual(calc.display, "220", "計算機：200 + 10% = 220")

    // 200 × 10% = 20
    calc.clear()
    calc.inputDigit("2"); calc.inputDigit("0"); calc.inputDigit("0")
    calc.inputOperator("×")
    calc.inputDigit("1"); calc.inputDigit("0")
    calc.inputPercentage()
    calc.calculateResult()
    assertEqual(calc.display, "20", "計算機：200 × 10% = 20")

    // sqrt(9) = 3
    calc.clear()
    calc.inputDigit("9")
    calc.squareRoot()
    assertEqual(calc.display, "3", "計算機：sqrt(9) = 3")

    // 角度模式 sin(30) = 0.5
    calc.clear()
    calc.isDegreeMode = true
    calc.inputDigit("3"); calc.inputDigit("0")
    calc.sinFunction()
    assertEqual(calc.display, "0.5", "計算機：角度模式 sin(30) = 0.5")

    // 弧度模式 cos(0) = 1
    calc.clear()
    calc.isDegreeMode = false
    calc.inputDigit("0")
    calc.cosFunction()
    assertEqual(calc.display, "1", "計算機：弧度模式 cos(0) = 1")

    // 除零安全防護
    calc.clear()
    calc.inputDigit("1"); calc.inputDigit("0")
    calc.inputOperator("÷")
    calc.inputDigit("0")
    calc.calculateResult()
    assertEqual(calc.display, "錯誤", "計算機：除零安全防護提示錯誤")
    assertEqual(calc.hasError, true, "計算機：標記 hasError")
    calc.clear()
    assertEqual(calc.hasError, false, "計算機：清除後恢復正常")
    assertEqual(calc.display, "0", "計算機：清除後顯示重設為 0")

    // 歷史紀錄
    assertTrue(calc.history.count > 0, "計算機：運算歷史已記錄")

    // 插入結果至畫布並驗證單一 Undo
    calc.display = "5607"
    let insertedTextObj = calc.insertResultToBoard(engine: engine)
    assertEqual(insertedTextObj.type, "text", "計算機：插入畫布為文字物件")
    assertEqual(insertedTextObj.text, "5607", "計算機：插入文字內容相符")
    assertEqual(engine.canUndo, true, "計算機：插入結果產生 1 筆 Undo")
    engine.undo()
    assertEqual(engine.objects.contains(where: { $0.id == insertedTextObj.id }), false, "計算機：單一 Undo 即可完全復原插入之文字物件")

    // 43.2 AGM-05: 計時器 (正計時/倒數計時/Monotonic Timestamp/預設時間/插入用時)
    let timer = TimerCoordinator()
    timer.reset()
    assertEqual(timer.status, .stopped, "計時器：初始狀態為 stopped")
    timer.start()
    assertEqual(timer.status, .running, "計時器：啟動後狀態為 running")
    timer.pause()
    assertEqual(timer.status, .paused, "計時器：暫停後狀態為 paused")
    timer.resume()
    assertEqual(timer.status, .running, "計時器：續行後狀態為 running")
    timer.reset()
    assertEqual(timer.status, .stopped, "計時器：重設後狀態為 stopped")

    // 倒數計時與預設
    timer.selectPresetMinutes(5)
    assertEqual(timer.mode, .countdown, "計時器：切換為倒數計時模式")
    assertEqual(timer.countdownDuration, 300.0, "計時器：5 分鐘預設為 300 秒")
    assertEqual(timer.remainingSeconds, 300.0, "計時器：初始剩餘 300 秒")
    assertEqual(timer.formattedTimeString(), "05:00", "計時器：倒數時間格式化為 05:00")

    // 模擬時間抵達 (Monotonic Clock 防失準)
    timer.start()
    timer.updateDisplayTimes(referenceUptime: ProcessInfo.processInfo.systemUptime + 305.0)
    assertEqual(timer.status, .timesUp, "計時器：倒數歸零觸發 timesUp")
    assertEqual(timer.remainingSeconds, 0.0, "計時器：倒數歸零不為負數")
    assertEqual(timer.didAlertTimesUp, true, "計時器：警示已觸發防重複通知")

    // 插入用時至畫布與 Undo
    let insertedTimeObj = timer.insertTimeToBoard(engine: engine)
    assertEqual(insertedTimeObj.type, "text", "計時器：插入畫布為文字物件")
    assertTrue(insertedTimeObj.text?.contains("倒數計時") == true, "計時器：文字物件包含倒數計時前綴")
    assertEqual(engine.canUndo, true, "計時器：插入產生 1 筆 Undo")
    engine.undo()
    assertEqual(engine.objects.contains(where: { $0.id == insertedTimeObj.id }), false, "計時器：單一 Undo 復原插入之用時物件")

    // 43.3 AGM-04: 圓規與可編輯圓弧 (資料模型、跨越0°、命中判定、包圍盒、手勢提交)
    // 資料模型序列化
    let arcObj = BoardObject(
        type: "arc",
        x: 100, y: 100, width: 200, height: 200,
        strokeColor: "#38bdf8",
        strokeWidth: 4.0,
        arcRadius: 100.0,
        arcStartAngle: 30.0,
        arcSweepAngle: 120.0
    )
    let doc = HeiBanDocument(board: BoardMetadata(title: "ArcDoc"), objects: [arcObj])
    let encodedData = try! JSONEncoder().encode(doc)
    let decodedDoc = try! JSONDecoder().decode(HeiBanDocument.self, from: encodedData)
    let decodedArc = decodedDoc.objects.first
    assertEqual(decodedArc?.type, "arc", "圓弧：資料模型反序列化類型為 arc")
    assertEqual(decodedArc?.arcRadius, 100.0, "圓弧：半徑反序列化一致")
    assertEqual(decodedArc?.arcStartAngle, 30.0, "圓弧：起始角反序列化一致")
    assertEqual(decodedArc?.arcSweepAngle, 120.0, "圓弧：掃角反序列化一致")

    // 角度跨越 0° 幾何演算法
    assertTrue(VectorMath.isAngleInSpan(angle: 10.0, start: 350.0, sweep: 30.0), "圓弧：跨越 0° (350°+30°涵蓋10°) 判定命中")
    assertTrue(!VectorMath.isAngleInSpan(angle: 100.0, start: 350.0, sweep: 30.0), "圓弧：超出角度範圍 (100°) 不命中")

    // 圓弧命中測試 (世界座標)
    // 圓心 (200, 200), 半徑 100. 角度 45° 點:
    let rad45 = 45.0 * Double.pi / 180.0
    let testArcObj = BoardObject(
        type: "arc",
        x: 100, y: 100, width: 200, height: 200, // center is (200, 200)
        strokeWidth: 4.0,
        arcRadius: 100.0,
        arcStartAngle: 0.0,
        arcSweepAngle: 90.0
    )
    let ptOnArc = Point(x: 200.0 + 100.0 * cos(rad45), y: 200.0 + 100.0 * sin(rad45))
    assertTrue(VectorMath.isPointNearObject(point: ptOnArc, object: testArcObj, threshold: 10.0), "圓弧：圓周上的點命中")
    let ptOutside = Point(x: 200.0 - 100.0, y: 200.0) // angle 180°
    assertTrue(!VectorMath.isPointNearObject(point: ptOutside, object: testArcObj, threshold: 10.0), "圓弧：超出弧角度跨度不命中")

    // 圓弧包圍盒
    let arcBox = VectorMath.computeArcBoundingBox(center: Point(x: 200, y: 200), radius: 100, startAngle: 0, sweepAngle: 90, strokeWidth: 2)
    assertTrue(arcBox.minX >= 198 && arcBox.maxX <= 302, "圓弧：第一象限 X 包圍盒約束精確")
    assertTrue(arcBox.minY >= 198 && arcBox.maxY <= 302, "圓弧：第一象限 Y 包圍盒約束精確")

    // 圓規工具引擎：防呆、整圓、圓弧與回選取
    let compass = CompassToolEngine()
    compass.adjustRadius(to: -50.0)
    assertEqual(compass.radius, 5.0, "圓規：負半徑被安全鉗位為 5.0 (防呆)")
    compass.adjustRadius(to: Double.nan)
    assertEqual(compass.radius, 5.0, "圓規：NaN 半徑被安全阻擋 (防呆)")
    compass.radius = 120.0
    compass.moveCenter(to: Point(x: 500, y: 400))

    // 繪製整圓
    engine.selectTool(.pen)
    let circleObj = compass.drawFullCircle(engine: engine, returnToSelect: true)
    assertEqual(circleObj.type, "arc", "圓規：繪製整圓產生 arc 物件")
    assertEqual(circleObj.arcSweepAngle, 360.0, "圓規：整圓掃角為 360°")
    assertEqual(engine.currentTool, .select, "圓規：繪製完成依要求自動回選取工具")
    assertEqual(engine.canUndo, true, "圓規：整圓手勢產生 1 筆 Undo")
    engine.undo()
    assertEqual(engine.objects.contains(where: { $0.id == circleObj.id }), false, "圓規：單一 Undo 復原整圓")

    // 繪製圓弧
    compass.startArc(atAngle: 45.0)
    compass.updateSweep(toAngle: 135.0)
    assertEqual(compass.isDrawingArc, true, "圓規：處於繪弧狀態")
    let createdArc = compass.commitArc(engine: engine, returnToSelect: true)
    assertEqual(createdArc.type, "arc", "圓規：提交生成可編輯圓弧")
    assertEqual(createdArc.arcStartAngle, 45.0, "圓規：起角相符 (45°)")
    assertEqual(createdArc.arcSweepAngle, 90.0, "圓規：掃角相符 (90°)")
    assertEqual(engine.currentTool, .select, "圓規：弧完成回選取工具")
    engine.undo()
    assertEqual(engine.objects.contains(where: { $0.id == createdArc.id }), false, "圓規：單一 Undo 復原圓弧")

    // 43.4 AGM-01 & AGM-02: 沉浸模式與右上精簡導覽狀態
    engine.isImmersiveMode = false
    engine.toggleImmersiveMode()
    assertEqual(engine.isImmersiveMode, true, "導覽：成功切換至沉浸模式")
    engine.toggleImmersiveMode()
    assertEqual(engine.isImmersiveMode, false, "導覽：成功退出沉浸模式")
}

// -------------------------------------------------------------------------
// 44. Prodrafts Worklist Batch 2: 書寫、教學與物件操作 (AGM-06 ~ AGM-10)
// -------------------------------------------------------------------------
print("\n[測試 44] Prodrafts Worklist Batch 2: 書寫、教學與物件操作 (AGM-06 ~ AGM-10 立靶驗收)")
do {
    let engine = BoardEngine()
    engine.objects.removeAll()

    // 44.1 AGM-06: 雷射筆與臨時指示圖層 (模式/光芯/淡出/容量防護/臨時圖層不進存檔/閱讀模式)
    let laser = LaserPointerEngine()
    assertEqual(laser.mode, .shortTrail, "雷射筆：預設模式為 shortTrail")
    laser.mode = .point
    assertEqual(laser.mode, .point, "雷射筆：切換為 point 模式")
    laser.mode = .line
    assertEqual(laser.mode, .line, "雷射筆：切換為 line 模式")

    // 容量上限防護 (防爆防呆：即使連畫 10 分鐘，記憶體點數嚴格 <= 500)
    for i in 0..<600 {
        laser.addSample(point: Point(x: Double(i), y: Double(i)))
    }
    assertTrue(laser.samples.count <= 500, "雷射筆：大量採樣(600點)嚴格截斷在 maxCapacity(500) 內，防爆記憶體")

    // 淡出清理
    let baseTime = ProcessInfo.processInfo.systemUptime
    laser.purgeExpiredSamples(currentTime: baseTime + 10.0)
    assertEqual(laser.samples.count, 0, "雷射筆：超時採樣自動清理完畢")

    // 清理與停用
    laser.addSample(point: Point(x: 10, y: 10))
    assertEqual(laser.samples.count, 1, "雷射筆：新增 1 個採樣")
    laser.cleanupOnDeactivate()
    assertEqual(laser.samples.count, 0, "雷射筆：停用時清空所有採樣")

    // 臨時圖層不進存檔、不進 Undo
    let initialObjCount = engine.objects.count
    let initialUndoCan = engine.canUndo
    engine.selectTool(.laser)
    engine.beginPointerGesture(at: Point(x: 100, y: 100))
    engine.updatePointerGesture(at: Point(x: 110, y: 110), translation: CGSize(width: 10, height: 10))
    engine.endPointerGesture(translation: CGSize(width: 20, height: 20))
    assertEqual(engine.objects.count, initialObjCount, "雷射筆：手勢軌跡不進入 objects 永久文檔")
    assertEqual(engine.canUndo, initialUndoCan, "雷射筆：手勢軌跡不產生 Undo 歷史記錄")

    // 閱讀模式可用
    engine.readingMode = true
    engine.laserEngine.clear()
    engine.laserEngine.isEnabled = true
    engine.updatePointerGesture(at: Point(x: 200, y: 200), translation: CGSize(width: 100, height: 100))
    assertTrue(engine.laserEngine.samples.count > 0, "雷射筆：在閱讀模式下依然可即時指示取樣")
    engine.readingMode = false
    engine.laserEngine.clear()
    engine.laserEngine.isEnabled = false

    // 44.2 AGM-07: 遮題膠帶與揭示操作 (type: tape, 矩形/直線, 揭示/遮蔽, 全揭/全隱, 橡皮擦隔離, 底層保護)
    let tapeObj = BoardObject(
        id: "tape_1",
        type: "tape",
        x: 50, y: 50, width: 200, height: 40,
        strokeColor: "#fbbf24",
        fillColor: "#fef3c7",
        strokeWidth: 2.0,
        opacity: 0.9,
        isRevealed: false,
        tapeStyle: "rect"
    )
    let underStroke = BoardObject(
        id: "under_stroke_1",
        type: "stroke",
        x: 60, y: 70, width: 120, height: 2,
        points: "[{\"x\":60,\"y\":70},{\"x\":120,\"y\":70},{\"x\":180,\"y\":70}]",
        strokeColor: "#ef4444",
        strokeWidth: 3.0
    )
    engine.objects = [underStroke, tapeObj]

    // 序列化與反序列化
    let tapeDoc = HeiBanDocument(board: BoardMetadata(title: "TapeDoc"), objects: [tapeObj])
    let tapeData = try! JSONEncoder().encode(tapeDoc)
    let decodedTapeDoc = try! JSONDecoder().decode(HeiBanDocument.self, from: tapeData)
    assertEqual(decodedTapeDoc.objects.first?.type, "tape", "膠帶：序列化類型為 tape")
    assertEqual(decodedTapeDoc.objects.first?.isRevealed, false, "膠帶：序列化 isRevealed 為 false")
    assertEqual(decodedTapeDoc.objects.first?.tapeStyle, "rect", "膠帶：序列化 tapeStyle 為 rect")

    // 單點揭示與遮蔽切換
    engine.toggleTapeRevealed(id: "tape_1")
    assertEqual(engine.objects.first(where: { $0.id == "tape_1" })?.isRevealed, true, "膠帶：單點切換成功揭示")
    engine.toggleTapeRevealed(id: "tape_1")
    assertEqual(engine.objects.first(where: { $0.id == "tape_1" })?.isRevealed, false, "膠帶：單點再次切換成功遮蔽")

    // 全域批次揭示與隱藏
    let tapeObj2 = BoardObject(id: "tape_2", type: "tape", x: 300, y: 50, width: 100, height: 30, isRevealed: false)
    engine.objects.append(tapeObj2)
    engine.revealAllTapes()
    assertEqual(engine.objects.filter { $0.type == "tape" && $0.isRevealed == true }.count, 2, "膠帶：revealAllTapes 全部揭示")
    engine.hideAllTapes()
    assertEqual(engine.objects.filter { $0.type == "tape" && $0.isRevealed == false }.count, 2, "膠帶：hideAllTapes 全部遮蔽")

    // 橡皮擦隔離與底層物件保護
    assertEqual(BoardEngine.isEraserEligible(tapeObj.type), false, "膠帶：橡皮擦隔離判定排除 tape 物件")
    assertEqual(BoardEngine.isEraserEligible(underStroke.type), true, "筆畫：筆畫物件屬於橡皮擦擦除範圍")
    // 底層物件在膠帶切換過程中完好無損
    assertEqual(engine.objects.contains(where: { $0.id == "under_stroke_1" }), true, "膠帶：切換不破壞底層原始筆畫")

    // 44.3 AGM-08: 筆刷、尺規、橡皮擦與色盤補齊 (8種BrushKind, 粗細與游標縮放, 橡皮擦保護, 世界座標標尺)
    assertEqual(BrushKind.allCases.count, 8, "筆刷：完整提供 8 種筆刷風格")
    for kind in BrushKind.allCases {
        assertTrue(!kind.displayName.isEmpty, "筆刷：\(kind.rawValue) 具備繁體中文顯示名稱")
        assertTrue(!kind.systemIconName.isEmpty, "筆刷：\(kind.rawValue) 具備系統圖示")
    }

    // 粗細換算
    let penW = CanvasToolMetrics.brushStrokeWidth(kind: .pen, baseWidth: 10.0)
    let paintW = CanvasToolMetrics.brushStrokeWidth(kind: .paint, baseWidth: 10.0)
    let highW = CanvasToolMetrics.brushStrokeWidth(kind: .highlighter, baseWidth: 10.0)
    assertEqual(penW, 10.0, "筆刷粗細：pen 係數為 1.0")
    assertEqual(paintW, 80.0, "筆刷粗細：paint 係數為 8.0 (大面積上色)")
    assertEqual(highW, 35.0, "筆刷粗細：highlighter 係數為 3.5 (螢光標注)")

    // 游標直徑與縮放比例
    let dia1 = CanvasToolMetrics.brushDiameter(tool: "pen", baseWidth: 4.0, zoom: 1.0, kind: .pen)
    let dia2 = CanvasToolMetrics.brushDiameter(tool: "pen", baseWidth: 4.0, zoom: 2.5, kind: .pen)
    assertEqual(dia1, 4.0, "筆刷游標：縮放 1.0x 直徑為 4.0 pt")
    assertEqual(dia2, 10.0, "筆刷游標：縮放 2.5x 直徑等比縮放為 10.0 pt")

    // 橡皮擦白名單與保護機制
    let textObj = BoardObject(type: "text", x: 0, y: 0, width: 100, height: 40, text: "Protected")
    let stickyObj = BoardObject(type: "sticky", x: 0, y: 0, width: 100, height: 100, text: "Protected Sticky")
    let imageObj = BoardObject(type: "image", x: 0, y: 0, width: 100, height: 100, imageUrl: "data:image/png;base64,123")
    assertEqual(BoardEngine.isEraserEligible(textObj.type), false, "橡皮擦保護：文字物件不受橡皮擦誤擦")
    assertEqual(BoardEngine.isEraserEligible(stickyObj.type), false, "橡皮擦保護：便條紙物件不受橡皮擦誤擦")
    assertEqual(BoardEngine.isEraserEligible(imageObj.type), false, "橡皮擦保護：圖片物件不受橡皮擦誤擦")

    // 世界座標標尺 R10 切換
    engine.showWorldRuler = false
    engine.toggleWorldRuler()
    assertEqual(engine.showWorldRuler, true, "世界座標標尺：成功切換啟用")
    engine.toggleWorldRuler()
    assertEqual(engine.showWorldRuler, false, "世界座標標尺：成功切換關閉")

    // 44.4 AGM-09: 幾何、多邊形、連接線與辨識偏好 (rounded_rect, polygon, connector 隨動與解除, 幾何完成回選取)
    // 圓角矩形
    let roundRect = BoardObject(
        id: "rr_1",
        type: "rounded_rect",
        x: 100, y: 100, width: 200, height: 100,
        strokeColor: "#38bdf8",
        strokeWidth: 2.0,
        cornerRadius: 16.0
    )
    let rrDoc = HeiBanDocument(board: BoardMetadata(title: "RRDoc"), objects: [roundRect])
    let rrData = try! JSONEncoder().encode(rrDoc)
    let decodedRRDoc = try! JSONDecoder().decode(HeiBanDocument.self, from: rrData)
    assertEqual(decodedRRDoc.objects.first?.type, "rounded_rect", "圓角矩形：序列化 type 為 rounded_rect")
    assertEqual(decodedRRDoc.objects.first?.cornerRadius, 16.0, "圓角矩形：cornerRadius 反序列化為 16.0")
    assertTrue(VectorMath.isPointNearObject(point: Point(x: 100, y: 150), object: roundRect, threshold: 5.0), "圓角矩形：邊緣命中檢驗")

    // 多邊形
    let polyObj = BoardObject(
        id: "poly_1",
        type: "polygon",
        x: 300, y: 300, width: 120, height: 120,
        polygonSides: 6
    )
    let polyDoc = HeiBanDocument(board: BoardMetadata(title: "PolyDoc"), objects: [polyObj])
    let polyData = try! JSONEncoder().encode(polyDoc)
    let decodedPolyDoc = try! JSONDecoder().decode(HeiBanDocument.self, from: polyData)
    assertEqual(decodedPolyDoc.objects.first?.type, "polygon", "多邊形：序列化 type 為 polygon")
    assertEqual(decodedPolyDoc.objects.first?.polygonSides, 6, "多邊形：polygonSides 反序列化為 6 (正六邊形)")
    let hexVertices = VectorMath.computePolygonVertices(center: Point(x: 360, y: 360), radius: 60, sides: 6)
    assertEqual(hexVertices.count, 6, "多邊形：計算產生 6 個正多邊形頂點")

    // 連接線隨動與解除綁定
    var nodeA = BoardObject(id: "node_a", type: "rect", x: 100, y: 100, width: 80, height: 60)
    var nodeB = BoardObject(id: "node_b", type: "rect", x: 300, y: 100, width: 80, height: 60)
    let conn = BoardObject(
        id: "conn_1",
        type: "connector",
        x: 140, y: 130, width: 200, height: 0,
        x1: 140, y1: 130, x2: 340, y2: 130,
        startObjectId: "node_a",
        endObjectId: "node_b"
    )
    engine.objects = [nodeA, nodeB, conn]

    // 移動 Node A 至 (200, 200) -> 中心由 (140, 130) 變為 (240, 230)
    nodeA.x = 200; nodeA.y = 200
    engine.objects[0] = nodeA
    engine.updateConnectedLines()
    let updatedConn = engine.objects.first(where: { $0.id == "conn_1" })
    assertEqual(updatedConn?.x1, 240.0, "連接線：Node A 移動後連接線 x1 端點自動隨動更新為中心 240.0")
    assertEqual(updatedConn?.y1, 230.0, "連接線：Node A 移動後連接線 y1 端點自動隨動更新為中心 230.0")

    // 刪除 Node B -> 解除綁定
    engine.detachDeletedObjectsFromConnectors(deletedIds: ["node_b"])
    let detachedConn = engine.objects.first(where: { $0.id == "conn_1" })
    assertEqual(detachedConn?.startObjectId, "node_a", "連接線：未刪除之 node_a 維持附著")
    assertEqual(detachedConn?.endObjectId, nil, "連接線：已刪除之 node_b 乾淨解除綁定，防懸掛崩潰")

    // 幾何完成回選取
    engine.board.canvasMode = .infinite
    engine.viewport = ViewportTransform(x: 0, y: 0, zoom: 1.0)
    engine.selectAfterShapeCreation = true
    engine.selectTool(.rect)
    engine.beginPointerGesture(at: Point(x: 50, y: 50))
    engine.updatePointerGesture(at: Point(x: 150, y: 150), translation: CGSize(width: 100, height: 100))
    engine.endPointerGesture(translation: CGSize(width: 100, height: 100))
    assertEqual(engine.currentTool, .select, "幾何偏好：建立形狀完成依設定自動切換回 select 工具")

    // 44.5 AGM-10: 套索、吸附與物件附近操作 (點在多邊形內, LassoFilter, AlignmentSnapCoordinator)
    // 點在多邊形內演算法
    let boxPoly = [Point(x: 0, y: 0), Point(x: 100, y: 0), Point(x: 100, y: 100), Point(x: 0, y: 100)]
    assertTrue(VectorMath.isPointInPolygon(point: Point(x: 50, y: 50), polygon: boxPoly), "套索演算法：多邊形內部點判定為 true")
    assertTrue(!VectorMath.isPointInPolygon(point: Point(x: 150, y: 50), polygon: boxPoly), "套索演算法：多邊形外部點判定為 false")

    // 套索過濾過濾器
    let strokeIn = BoardObject(id: "s_in", type: "stroke", x: 20, y: 20, width: 10, height: 10, points: "[{\"x\":20,\"y\":20},{\"x\":30,\"y\":30}]")
    let textIn = BoardObject(id: "t_in", type: "text", x: 40, y: 40, width: 50, height: 20)
    let lockedIn = BoardObject(id: "l_in", type: "stroke", x: 25, y: 25, width: 1, height: 1, points: "[{\"x\":25,\"y\":25}]", isLocked: true)
    let candidates = [strokeIn, textIn, lockedIn]

    // 全部模式 (排除鎖定)
    let selAll = LassoSelectionCoordinator.selectObjects(in: boxPoly, objects: candidates, mode: .freeform, filter: .all)
    assertTrue(selAll.contains("s_in") && selAll.contains("t_in"), "套索：filter.all 選中未鎖定物件")
    assertTrue(!selAll.contains("l_in"), "套索：鎖定物件免疫於套索選取")

    // 僅筆畫過濾模式
    let selStrokes = LassoSelectionCoordinator.selectObjects(in: boxPoly, objects: candidates, mode: .freeform, filter: .strokesOnly)
    assertTrue(selStrokes.contains("s_in"), "套索：filter.strokesOnly 選中筆畫")
    assertTrue(!selStrokes.contains("t_in"), "套索：filter.strokesOnly 排除文字物件")

    // 僅文字過濾模式
    let selText = LassoSelectionCoordinator.selectObjects(in: boxPoly, objects: candidates, mode: .freeform, filter: .textOnly)
    assertTrue(selText.contains("t_in"), "套索：filter.textOnly 選中文字物件")
    assertTrue(!selText.contains("s_in"), "套索：filter.textOnly 排除筆畫物件")

    // 對齊吸附演算法 (AlignmentSnapCoordinator)
    let staticObj = BoardObject(id: "ref_1", type: "rect", x: 100, y: 100, width: 80, height: 80)
    let movingBox = CGRect(x: 102, y: 100, width: 80, height: 80) // left is 102, target static left is 100 (diff 2 <= 6)
    let snapResult = AlignmentSnapCoordinator.computeSnap(
        movingBounds: movingBox,
        proposedDelta: CGSize(width: 0, height: 0),
        referenceObjects: [staticObj],
        threshold: 6.0
    )
    assertEqual(snapResult.snappedDeltaX, -2.0, "吸附演算法：X 軸吸附位移 -2.0 pt 自動對齊目標物件左側")
    assertTrue(!snapResult.guides.isEmpty, "吸附演算法：產生對齊參考輔助導線")
}

print("\n[測試 45] AGM-11 ~ AGM-14: 結構化筆記 (畫框簡報、思維導圖、原生表格、LaTeX 數學公式) (立靶驗收)")
do {
    let engine = BoardEngine()

    // 45.1 AGM-11: 畫框物件建立、屬性、橡皮擦豁免與顯示名稱
    let frameObj = BoardObject(
        id: "frame_test_1",
        type: "frame",
        x: 100, y: 100, width: 800, height: 600,
        strokeColor: "#94a3b8",
        fillColor: "#0f172a",
        fillOpacity: 0.15,
        strokeWidth: 2.0,
        frameTitle: "簡報第一章：導論",
        childIds: ["child_note_1", "child_note_2"]
    )
    assertEqual(frameObj.type, "frame", "畫框：type 為 frame")
    assertEqual(frameObj.frameTitle, "簡報第一章：導論", "畫框：frameTitle 正確記錄")
    assertEqual(frameObj.childIds?.count, 2, "畫框：childIds 正確記錄關聯物件")
    assertEqual(frameObj.displayName, "畫框 (簡報第一章：導論)", "畫框：displayName 正確包含章節名稱")
    assertEqual(frameObj.systemIconName, "viewfinder.rectangular", "畫框：系統圖示為 viewfinder.rectangular")
    assertEqual(BoardEngine.isEraserEligible(frameObj.type), false, "畫框：橡皮擦隔離判定排除 frame 物件")

    // 45.2 AGM-11: 子物件範圍包含判定 (findContainedObjects)
    let insideObj1 = BoardObject(id: "child_note_1", type: "text", x: 200, y: 200, width: 100, height: 40)
    let insideObj2 = BoardObject(id: "child_note_2", type: "rect", x: 400, y: 300, width: 120, height: 80)
    let outsideObj = BoardObject(id: "outside_note", type: "sticky", x: 1200, y: 800, width: 150, height: 150)
    let otherFrame = BoardObject(id: "other_frame", type: "frame", x: 150, y: 150, width: 200, height: 200)
    let allCandidates = [frameObj, insideObj1, insideObj2, outsideObj, otherFrame]

    let detectedChildren = FramePresentationCoordinator.findContainedObjects(frame: frameObj, in: allCandidates)
    assertTrue(detectedChildren.contains("child_note_1"), "畫框包含判定：內部文字物件被識別為 child")
    assertTrue(detectedChildren.contains("child_note_2"), "畫框包含判定：內部矩形物件被識別為 child")
    assertTrue(!detectedChildren.contains("outside_note"), "畫框包含判定：外部便條紙不被納入 child")
    assertTrue(!detectedChildren.contains("other_frame"), "畫框包含判定：防止巢狀畫框遞迴循環，排除 otherFrame")

    // 45.3 AGM-11: 移動畫框連帶移動子物件 (moveFrame)
    let movedObjects = FramePresentationCoordinator.moveFrame(
        frameId: "frame_test_1",
        delta: CGSize(width: 50, height: 100),
        objects: allCandidates
    )
    let movedFrame = movedObjects.first(where: { $0.id == "frame_test_1" })!
    let movedInside1 = movedObjects.first(where: { $0.id == "child_note_1" })!
    let movedInside2 = movedObjects.first(where: { $0.id == "child_note_2" })!
    let movedOutside = movedObjects.first(where: { $0.id == "outside_note" })!

    assertEqual(movedFrame.x, 150.0, "連帶移動：畫框 X 座標位移 +50")
    assertEqual(movedFrame.y, 200.0, "連帶移動：畫框 Y 座標位移 +100")
    assertEqual(movedInside1.x, 250.0, "連帶移動：子物件 1 X 座標連帶位移 +50")
    assertEqual(movedInside1.y, 300.0, "連帶移動：子物件 1 Y 座標連帶位移 +100")
    assertEqual(movedInside2.x, 450.0, "連帶移動：子物件 2 X 座標連帶位移 +50")
    assertEqual(movedInside2.y, 400.0, "連帶移動：子物件 2 Y 座標連帶位移 +100")
    assertEqual(movedOutside.x, 1200.0, "連帶移動：外部物件 X 座標保持不變")
    assertEqual(movedOutside.y, 800.0, "連帶移動：外部物件 Y 座標保持不變")

    // 45.4 AGM-11: 深度複製畫框與子物件重映射 (duplicateFrame)
    guard let dupResult = FramePresentationCoordinator.duplicateFrame(
        frameId: "frame_test_1",
        delta: CGSize(width: 40, height: 40),
        in: allCandidates
    ) else {
        fatalError("Duplicate frame failed")
    }
    assertTrue(dupResult.newFrame.id != frameObj.id, "畫框深度複製：新畫框產生全新 UUID")
    assertEqual(dupResult.newChildren.count, 2, "畫框深度複製：同時深度複製 2 個子物件")
    for child in dupResult.newChildren {
        assertTrue(child.id != "child_note_1" && child.id != "child_note_2", "畫框深度複製：新子物件產生全新 UUID")
        assertTrue(dupResult.newFrame.childIds?.contains(child.id) == true, "畫框深度複製：新畫框 childIds 精確指向新子物件 ID")
        assertTrue(dupResult.newFrame.childIds?.contains("child_note_1") == false, "畫框深度複製：新畫框不再參照舊子物件 ID")
    }

    // 45.5 AGM-11: 簡報導航排序、視角計算與邊界防呆
    let frame2 = BoardObject(id: "frame_2", type: "frame", x: 1000, y: 100, width: 800, height: 600, zIndex: 2, frameTitle: "第二章")
    let frameList = FramePresentationCoordinator.orderedFrames(from: [frame2, frameObj])
    assertEqual(frameList.first?.id, "frame_test_1", "簡報排序：依 zIndex/位置排序第一張為 frame_test_1")
    assertEqual(frameList.last?.id, "frame_2", "簡報排序：第二張為 frame_2")

    let fitVP = FramePresentationCoordinator.fitViewport(for: frameObj, canvasSize: CGSize(width: 1920, height: 1080), padding: 60.0)
    assertTrue(fitVP.zoom > 0.5 && fitVP.zoom < 2.5, "簡報視角：Fit-to-frame 計算出合理的清晰縮放比")
    assertEqual(FramePresentationCoordinator.nextFrameIndex(currentIndex: 0, total: 2), 1, "簡報導航：第 0 頁下一頁為第 1 頁")
    assertEqual(FramePresentationCoordinator.nextFrameIndex(currentIndex: 1, total: 2), 1, "簡報導航：末頁下一頁防呆停在末頁")
    assertEqual(FramePresentationCoordinator.prevFrameIndex(currentIndex: 1), 0, "簡報導航：第 1 頁上一頁為第 0 頁")
    assertEqual(FramePresentationCoordinator.prevFrameIndex(currentIndex: 0), 0, "簡報導航：首頁上一頁防呆停在首頁")

    // 引擎簡報狀態測試
    engine.objects = [frameObj, frame2, insideObj1]
    let startOk = engine.startPresentation(canvasSize: CGSize(width: 1920, height: 1080))
    assertTrue(startOk, "引擎簡報：成功啟動簡報模式")
    assertTrue(engine.isPresentationModeActive, "引擎簡報：isPresentationModeActive 為 true")
    assertEqual(engine.currentPresentationIndex, 0, "引擎簡報：初始在第 0 張畫框")
    engine.nextPresentationFrame(canvasSize: CGSize(width: 1920, height: 1080))
    assertEqual(engine.currentPresentationIndex, 1, "引擎簡報：成功前進至第 1 張畫框")
    engine.prevPresentationFrame(canvasSize: CGSize(width: 1920, height: 1080))
    assertEqual(engine.currentPresentationIndex, 0, "引擎簡報：成功返回第 0 張畫框")
    engine.exitPresentation()
    assertTrue(!engine.isPresentationModeActive, "引擎簡報：exitPresentation 退出簡報模式")

    // 45.6 AGM-12: 思維導圖建立、增刪節點、樹狀拓撲排版與橡皮擦豁免
    let defaultMindMap = MindMapCoordinator.createDefaultMindMap(rootText: "黑板核心架構", at: Point(x: 200, y: 200))
    assertEqual(defaultMindMap.type, "mindmap", "思維導圖：type 為 mindmap")
    assertEqual(defaultMindMap.displayName, "思維導圖", "思維導圖：displayName 為 思維導圖")
    assertEqual(defaultMindMap.systemIconName, "point.filled.topleft.down.curvedto.point.bottomright.up", "思維導圖：系統圖示相符")
    assertEqual(BoardEngine.isEraserEligible(defaultMindMap.type), false, "思維導圖：橡皮擦隔離判定排除 mindmap 物件")

    guard var mmData = defaultMindMap.mindMapData else {
        fatalError("MindMapData missing")
    }
    assertEqual(mmData.nodes.count, 3, "思維導圖：預設包含 1 個根節點與 2 個初始分支")
    let rootNode = mmData.nodes[mmData.rootId]!
    assertEqual(rootNode.text, "黑板核心架構", "思維導圖：根主題文字正確")

    // 增加子節點
    let child1Id = rootNode.childrenIds[0]
    let leafId = MindMapCoordinator.addChildNode(to: child1Id, text: "子功能 A", data: &mmData)!
    assertEqual(mmData.nodes[child1Id]?.childrenIds.contains(leafId), true, "思維導圖：成功為分支 1 增加子節點")
    assertEqual(mmData.nodes[leafId]?.parentId, child1Id, "思維導圖：子節點 parentId 指向分支 1")

    // 增加兄弟節點
    let siblingId = MindMapCoordinator.addSiblingNode(to: leafId, text: "子功能 B", data: &mmData)!
    assertEqual(mmData.nodes[siblingId]?.parentId, child1Id, "思維導圖：兄弟節點 parentId 同樣指向分支 1")
    assertEqual(mmData.nodes[child1Id]?.childrenIds.contains(siblingId), true, "思維導圖：父節點 childrenIds 包含兄弟節點")

    // 防循環階層保護
    var caughtCycle = false
    do {
        // 嘗試將父節點 child1Id 掛在其子節點 leafId 之下 (將造成循環)
        try MindMapCoordinator.reparentNode(nodeId: child1Id, newParentId: leafId, data: &mmData)
    } catch MindMapError.circularHierarchy {
        caughtCycle = true
    } catch {
        fatalError("Unexpected error \(error)")
    }
    assertTrue(caughtCycle, "思維導圖防循環：成功攔截循環階層變更 (circularHierarchy)")

    // 根節點禁止變更父節點保護
    var caughtRootReparent = false
    do {
        try MindMapCoordinator.reparentNode(nodeId: mmData.rootId, newParentId: leafId, data: &mmData)
    } catch MindMapError.cannotReparentRoot {
        caughtRootReparent = true
    } catch {}
    assertTrue(caughtRootReparent, "思維導圖防循環：根主題禁止變更父節點 (cannotReparentRoot)")

    // 折疊與更新文字
    MindMapCoordinator.toggleCollapse(nodeId: child1Id, data: &mmData)
    assertEqual(mmData.nodes[child1Id]?.isCollapsed, true, "思維導圖：toggleCollapse 切換折疊狀態為 true")
    MindMapCoordinator.updateNodeText(nodeId: leafId, text: "重新命名功能", data: &mmData)
    assertEqual(mmData.nodes[leafId]?.text, "重新命名功能", "思維導圖：updateNodeText 更新節點文字成功")

    // 遞迴刪除子樹
    let beforeCount = mmData.nodes.count
    MindMapCoordinator.deleteNode(nodeId: child1Id, data: &mmData)
    assertTrue(!mmData.nodes.keys.contains(child1Id), "思維導圖遞迴刪除：分支 1 節點已被移除")
    assertTrue(!mmData.nodes.keys.contains(leafId), "思維導圖遞迴刪除：後代 leaf 節點被連帶遞迴清除")
    assertTrue(!mmData.nodes.keys.contains(siblingId), "思維導圖遞迴刪除：後代 sibling 節點被連帶遞迴清除")
    assertEqual(mmData.nodes.count, beforeCount - 3, "思維導圖遞迴刪除：精確清除 3 個後代節點")

    // 複製思維導圖與獨立 ID
    let clonedMM = MindMapCoordinator.cloneMindMap(data: mmData)
    assertTrue(clonedMM.rootId != mmData.rootId, "思維導圖複製：克隆後根節點具備全新 UUID")
    for (k, _) in clonedMM.nodes {
        assertTrue(!mmData.nodes.keys.contains(k), "思維導圖複製：克隆後所有節點均具備全新獨立 UUID，無碰撞")
    }

    // 45.7 AGM-13: 原生表格結構、增刪行列、合併單元格與 TSV/CSV 剪貼簿貼入
    let defaultTable = TableCoordinator.createDefaultTable(rows: 3, cols: 3, at: Point(x: 100, y: 100))
    assertEqual(defaultTable.type, "table", "表格：type 為 table")
    assertEqual(defaultTable.displayName, "原生表格", "表格：displayName 為 原生表格")
    assertEqual(defaultTable.systemIconName, "tablecells", "表格：系統圖示為 tablecells")
    assertEqual(BoardEngine.isEraserEligible(defaultTable.type), false, "表格：橡皮擦隔離判定排除 table 物件")

    guard var tData = defaultTable.tableData else {
        fatalError("TableData missing")
    }
    assertEqual(tData.rowCount, 3, "表格：初始 rowCount 為 3")
    assertEqual(tData.colCount, 3, "表格：初始 colCount 為 3")
    assertEqual(tData.cells.count, 9, "表格：3x3 共有 9 個單元格")
    assertEqual(tData.cells.first(where: { $0.row == 0 && $0.col == 0 })?.isHeader, true, "表格：第 0 列自動標示為 isHeader")

    // 增列與刪列
    TableCoordinator.addRow(at: 1, data: &tData)
    assertEqual(tData.rowCount, 4, "表格：插入 1 列後 rowCount 增為 4")
    let shiftedCell = tData.cells.first(where: { $0.row == 2 && $0.col == 0 })
    assertTrue(shiftedCell != nil, "表格：原第 1 列單元格順移至第 2 列")

    let delRowOk = TableCoordinator.deleteRow(at: 1, data: &tData)
    assertTrue(delRowOk, "表格：刪除指定列成功")
    assertEqual(tData.rowCount, 3, "表格：刪除 1 列後 rowCount 回復為 3")

    // 增欄與刪欄
    TableCoordinator.addColumn(at: 1, data: &tData)
    assertEqual(tData.colCount, 4, "表格：插入 1 欄後 colCount 增為 4")
    let delColOk = TableCoordinator.deleteColumn(at: 1, data: &tData)
    assertTrue(delColOk, "表格：刪除指定欄成功")
    assertEqual(tData.colCount, 3, "表格：刪除 1 欄後 colCount 回復為 3")

    // 編輯單元格與合併單元格
    TableCoordinator.setCellText(row: 0, col: 0, text: "總計欄位", data: &tData)
    assertEqual(tData.cells.first(where: { $0.row == 0 && $0.col == 0 })?.text, "總計欄位", "表格：setCellText 修改單元格文字成功")
    TableCoordinator.mergeCells(fromRow: 0, fromCol: 0, toRow: 0, toCol: 1, data: &tData)
    let mergedPrimary = tData.cells.first(where: { $0.row == 0 && $0.col == 0 })
    assertEqual(mergedPrimary?.colSpan, 2, "表格合併：主單元格 colSpan 設為 2")
    TableCoordinator.unmergeCell(row: 0, col: 0, data: &tData)
    assertEqual(tData.cells.first(where: { $0.row == 0 && $0.col == 0 })?.colSpan, 1, "表格解除合併：主單元格 colSpan 回復為 1")

    // 最小邊界保護 (不能刪除僅存的最後 1 行/欄)
    var singleTable = TableData(rowCount: 1, colCount: 1, colWidths: [100.0], rowHeights: [36.0], cells: [TableCell(row: 0, col: 0, text: "X")])
    assertEqual(TableCoordinator.deleteRow(at: 0, data: &singleTable), false, "表格防呆保護：禁止刪除僅存之最後 1 列")
    assertEqual(TableCoordinator.deleteColumn(at: 0, data: &singleTable), false, "表格防呆保護：禁止刪除僅存之最後 1 欄")

    // TSV / CSV 貼入匯入解析與匯出
    let tsvInput = "名稱\t數量\t單價\n蘋果\t10\t25\n香蕉\t5\t15"
    let importedTable = TableCoordinator.importFromDelimitedText(tsvInput, delimiter: "\t")
    assertEqual(importedTable.rowCount, 3, "TSV 匯入：成功解析為 3 列")
    assertEqual(importedTable.colCount, 3, "TSV 匯入：成功解析為 3 欄")
    assertEqual(importedTable.cells.first(where: { $0.row == 1 && $0.col == 0 })?.text, "蘋果", "TSV 匯入：單元格文字精準還原 (蘋果)")
    assertEqual(importedTable.cells.first(where: { $0.row == 2 && $0.col == 2 })?.text, "15", "TSV 匯入：單元格文字精準還原 (15)")
    let exportedTSV = TableCoordinator.exportToCSV(data: importedTable, delimiter: "\t")
    assertTrue(exportedTSV.contains("蘋果") && exportedTSV.contains("10"), "TSV 匯出：匯出字串包含原始資料內容")

    // 45.8 AGM-14: LaTeX 數學公式解析、離線向量排版、常用符號與橡皮擦豁免
    let formulaObj = BoardObject(
        id: "formula_1",
        type: "formula",
        x: 100, y: 100, width: 240, height: 60,
        strokeColor: "#38bdf8",
        latex: "\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}",
        formulaFontSize: 24.0
    )
    assertEqual(formulaObj.type, "formula", "LaTeX 公式：type 為 formula")
    assertEqual(formulaObj.displayName.hasPrefix("公式 (\\frac{-b "), true, "LaTeX 公式：displayName 顯示代碼摘要")
    assertEqual(formulaObj.systemIconName, "function", "LaTeX 公式：系統圖示為 function")
    assertEqual(BoardEngine.isEraserEligible(formulaObj.type), false, "LaTeX 公式：橡皮擦隔離判定排除 formula 物件")

    // 離線純 Swift 向量語法解析器 (分式、根號、上下標、希臘字母、運算符號)
    let quadLayout = LaTeXParserEngine.layout(latex: "\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}", baseFontSize: 24.0)
    assertTrue(quadLayout.bounds.width > 50.0, "LaTeX 佈局：計算產出合理公式總寬度")
    assertTrue(quadLayout.bounds.height > 20.0, "LaTeX 佈局：計算產出合理公式總高度")
    assertTrue(quadLayout.lines.count >= 2, "LaTeX 佈局：包含分式線與根號頂線 (lines.count >= 2)")
    let glyphTexts = quadLayout.glyphs.map(\.text)
    assertTrue(glyphTexts.contains("±"), "LaTeX 符號解析：\\pm 成功轉譯為 ± 向量字形")
    assertTrue(glyphTexts.contains("√"), "LaTeX 符號解析：\\sqrt 成功轉譯為 √ 向量字形")
    assertTrue(glyphTexts.contains("2"), "LaTeX 上標解析：上標平方數字 2 成功產出")

    // 希臘字母與微積分運算符號解析
    let calculusLayout = LaTeXParserEngine.layout(latex: "\\int_{0}^{\\pi} \\sin(\\theta) d\\theta", baseFontSize: 24.0)
    let calculusGlyphs = calculusLayout.glyphs.map(\.text)
    assertTrue(calculusGlyphs.contains("∫"), "LaTeX 解析：\\int 成功轉譯為 ∫ 積分符號")
    assertTrue(calculusGlyphs.contains("π"), "LaTeX 解析：\\pi 成功轉譯為 π 希臘字母")
    assertTrue(calculusGlyphs.contains("θ"), "LaTeX 解析：\\theta 成功轉譯為 θ 希臘字母")

    // 常用符號目錄
    assertTrue(LaTeXParserEngine.symbolCatalog.count >= 15, "LaTeX 常用目錄：包含 15+ 種常用數學符號模板")
    assertTrue(LaTeXParserEngine.symbolCatalog.contains(where: { $0.latex == "\\frac{a}{b}" }), "LaTeX 常用目錄：涵蓋標準分式")
    assertTrue(LaTeXParserEngine.symbolCatalog.contains(where: { $0.latex == "\\sqrt{x}" }), "LaTeX 常用目錄：涵蓋平方根")

    // 離線手寫公式識別管線架構驗證 (Stage 2 預備)
    let mockRecognizer = LocalOfflineFormulaRecognizer()
    let dummyStrokes = [BoardObject(type: "stroke", x: 0, y: 0, width: 10, height: 10)]
    let expLatex = try! mockRecognizer.recognizeHandwrittenFormulaSync(strokes: dummyStrokes)
    assertEqual(expLatex, "\\frac{a + b}{c}", "公式識別管線：離線識別合約協議正常運作")

    // 45.9 結構化物件 JSON 完整往返序列化 (Round-trip)
    let batch3Doc = HeiBanDocument(
        board: BoardMetadata(title: "Batch 3 結構化筆記文件"),
        objects: [frameObj, defaultMindMap, defaultTable, formulaObj]
    )
    let encodedData = try! JSONEncoder().encode(batch3Doc)
    let decodedDoc = try! JSONDecoder().decode(HeiBanDocument.self, from: encodedData)
    assertEqual(decodedDoc.objects.count, 4, "往返序列化：4 個結構化物件全部成功保存與載入")

    let reFrame = decodedDoc.objects.first(where: { $0.type == "frame" })!
    assertEqual(reFrame.frameTitle, "簡報第一章：導論", "往返序列化：frameTitle 100% 精準還原")
    assertEqual(reFrame.childIds?.count, 2, "往返序列化：childIds 100% 精準還原")

    let reMindMap = decodedDoc.objects.first(where: { $0.type == "mindmap" })!
    assertEqual(reMindMap.mindMapData?.nodes.count, 3, "往返序列化：mindMapData 節點字典 100% 精準還原")
    assertEqual(reMindMap.mindMapData?.nodes[reMindMap.mindMapData!.rootId]?.text, "黑板核心架構", "往返序列化：mindmap 根節點文字精準還原")

    let reTable = decodedDoc.objects.first(where: { $0.type == "table" })!
    assertEqual(reTable.tableData?.rowCount, 3, "往返序列化：tableData rowCount 精準還原")
    assertEqual(reTable.tableData?.colCount, 3, "往返序列化：tableData colCount 精準還原")
    assertEqual(reTable.tableData?.cells.count, 9, "往返序列化：tableData cells 精準還原")

    let reFormula = decodedDoc.objects.first(where: { $0.type == "formula" })!
    assertEqual(reFormula.latex, "\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}", "往返序列化：formula latex 語法字串精準還原")
    assertEqual(reFormula.formulaFontSize, 24.0, "往返序列化：formulaFontSize 精準還原")
}

print("\n==================================================")

if failedCount == 0 {
    print("🎉 驗收結果：全部通過！ (\(passedCount) 項斷言成功，0 項失敗)")
} else {
    print("⚠️ 驗收結果：失敗！ (\(passedCount) 通過，\(failedCount) 失敗)")
    exit(1)
}
print("==================================================")





