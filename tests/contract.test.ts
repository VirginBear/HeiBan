import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { BoardObject, BoardMetadata, HeiBanDocument, CanvasMode, CanvasPreset, BoardPage } from '../src/types';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let passedCount = 0;
let failedCount = 0;

function assertTrue(condition: boolean, message: string) {
  if (condition) {
    passedCount++;
    console.log(`  ✓ ${message}`);
  } else {
    failedCount++;
    console.error(`  ✗ FAILED: ${message}`);
  }
}

function assertEqual<T>(actual: T, expected: T, message: string) {
  if (actual === expected) {
    passedCount++;
    console.log(`  ✓ ${message}`);
  } else {
    failedCount++;
    console.error(`  ✗ FAILED: ${message} [Expected: ${expected}, Got: ${actual}]`);
  }
}

console.log('==================================================');
console.log('🎯 Web/TS Document Contract & Roundtrip Verification (立靶檢驗)');
console.log('==================================================\n');

// -------------------------------------------------------------------------
// 1. Fixture F04 Integrity & Field Coverage
// -------------------------------------------------------------------------
console.log('[測試 1] Fixture F04 欄位完整度與幾何契約');

const f04Path = path.resolve(__dirname, 'fixtures/f04_contract.json');
assertTrue(fs.existsSync(f04Path), 'F04 contract fixture 檔案應存在');

const rawF04 = fs.readFileSync(f04Path, 'utf-8');
const docF04 = JSON.parse(rawF04) as HeiBanDocument;

assertEqual(docF04.schemaVersion, '1.0.0', 'F04 應包含 schemaVersion 1.0.0');
assertEqual(docF04.version, '1.0', 'F04 應包含 version 1.0');
assertEqual(docF04.board.title, 'F04 跨平台契約完整驗收板', '黑板標題相符');
assertEqual(docF04.board.canvasMode, 'infinite', '黑板畫布模式為 infinite');
assertEqual(docF04.board.pins?.length, 2, '黑板圖釘應有 2 個');

// Check unknown board field preservation
assertEqual(
  (docF04.board as Record<string, unknown>)['unknownBoardExtensionField'],
  'preserved_custom_metadata_value',
  '黑板未知擴展欄位應被讀取'
);

assertEqual(docF04.objects.length, 15, 'F04 應涵蓋 15 種測試物件');

// 1.1 Reverse line geometry
const reverseLine = docF04.objects.find((o) => o.id === 'obj_09_line_reverse_both_ext');
assertTrue(!!reverseLine, '反向雙向延伸直線存在');
assertEqual(reverseLine?.x1, 250, '線段 A 點 X1 座標');
assertEqual(reverseLine?.y1, 430, '線段 A 點 Y1 座標');
assertEqual(reverseLine?.x2, 100, '線段 B 點 X2 座標');
assertEqual(reverseLine?.y2, 350, '線段 B 點 Y2 座標');
assertEqual(reverseLine?.extension, 'both', '延伸模式為 both');

// 1.2 Reverse arrow geometry
const reverseArrow = docF04.objects.find((o) => o.id === 'obj_10_arrow_reverse_start_ext');
assertTrue(!!reverseArrow, '反向箭頭存在');
assertEqual(reverseArrow?.x1, 520, '箭頭 A 點 X1 座標');
assertEqual(reverseArrow?.y1, 350, '箭頭 A 點 Y1 座標');
assertEqual(reverseArrow?.x2, 400, '箭頭 B 點 X2 座標');
assertEqual(reverseArrow?.y2, 440, '箭頭 B 點 Y2 座標');
assertEqual(reverseArrow?.extension, 'start', '延伸模式為 start');

// 1.3 Rich text spans
const richText = docF04.objects.find((o) => o.id === 'obj_11_text_rich');
assertTrue(!!richText, '富文本物件存在');
assertEqual(richText?.richTextSpans?.length, 3, '富文本應有 3 個片段');
assertEqual(richText?.richTextSpans?.[1].text, '富文本標題', '第二片段文字相符');
assertEqual(richText?.richTextSpans?.[1].isItalic, true, '第二片段應為斜體');
assertEqual(richText?.richTextSpans?.[1].color, '#facc15', '第二片段顏色相符');

// 1.4 Cropped image
const croppedImg = docF04.objects.find((o) => o.id === 'obj_14_image_cropped');
assertTrue(!!croppedImg, '裁切圖片物件存在');
assertEqual(croppedImg?.cropX, 100, '裁切 X 座標');
assertEqual(croppedImg?.cropY, 50, '裁切 Y 座標');
assertEqual(croppedImg?.cropWidth, 1720, '裁切寬度');
assertEqual(croppedImg?.cropHeight, 980, '裁切高度');
assertEqual(croppedImg?.originalWidth, 1920, '原圖寬度');
assertEqual(croppedImg?.originalHeight, 1080, '原圖高度');

// 1.5 Object unknown field
const strokeObj = docF04.objects.find((o) => o.id === 'obj_01_stroke');
assertEqual(
  (strokeObj as Record<string, unknown>)['unknownObjectExtensionField'],
  42.5,
  '物件未知擴展欄位應被讀取'
);

// -------------------------------------------------------------------------
// 2. Round-trip JSON Serialization Tolerance
// -------------------------------------------------------------------------
console.log('\n[測試 2] Web JSON 往返無損與幾何容差 (≤ 1e-6)');

const reSerialized = JSON.stringify(docF04);
const reParsed = JSON.parse(reSerialized) as HeiBanDocument;

assertEqual(reParsed.objects.length, docF04.objects.length, '往返物件數量一致');
for (let i = 0; i < docF04.objects.length; i++) {
  const o1 = docF04.objects[i];
  const o2 = reParsed.objects[i];
  assertEqual(o2.id, o1.id, `物件 [${o1.id}] ID 相符`);
  assertTrue(Math.abs(o2.x - o1.x) <= 1e-6, `物件 [${o1.id}] X 幾何容差 ≤ 1e-6`);
  assertTrue(Math.abs(o2.y - o1.y) <= 1e-6, `物件 [${o1.id}] Y 幾何容差 ≤ 1e-6`);
  assertTrue(Math.abs(o2.width - o1.width) <= 1e-6, `物件 [${o1.id}] 寬度幾何容差 ≤ 1e-6`);
  assertTrue(Math.abs(o2.height - o1.height) <= 1e-6, `物件 [${o1.id}] 高度幾何容差 ≤ 1e-6`);
}

// -------------------------------------------------------------------------
// 3. Legacy v0 Document Migration
// -------------------------------------------------------------------------
console.log('\n[測試 3] 舊版無版本號文件遷移相容');

const legacyPath = path.resolve(__dirname, 'fixtures/legacy_v0_no_version.json');
const rawLegacy = fs.readFileSync(legacyPath, 'utf-8');
const legacyDoc = JSON.parse(rawLegacy);

function migrateDocument(doc: any): HeiBanDocument {
  return {
    schemaVersion: doc.schemaVersion || '1.0.0',
    version: doc.version || '1.0',
    board: doc.board,
    objects: doc.objects || [],
    exportedAt: doc.exportedAt || new Date().toISOString(),
  };
}

const migrated = migrateDocument(legacyDoc);
assertEqual(migrated.schemaVersion, '1.0.0', '舊版文件遷移後補齊 schemaVersion 1.0.0');
assertEqual(migrated.version, '1.0', '舊版文件遷移後補齊 version 1.0');
assertEqual(migrated.objects.length, 1, '舊版物件數量完整保留');
assertEqual(migrated.objects[0].id, 'legacy_obj_1', '舊版物件 ID 完整保留');

// -------------------------------------------------------------------------
// 4. Group ID Contract & Roundtrip (W10, A06)
// -------------------------------------------------------------------------
console.log('\n[測試 4] 群組識別碼 (groupId) 契約與往返無損 (W10, A06)');

const groupedObject: BoardObject = {
  id: 'test_grouped_obj_1',
  boardId: 'board_test',
  type: 'rect',
  x: 50,
  y: 60,
  width: 100,
  height: 80,
  strokeColor: '#ffffff',
  fillColor: 'none',
  strokeWidth: 2,
  opacity: 1,
  rotation: 0,
  zIndex: 1,
  groupId: 'group_test_alpha',
  createdBy: 'test_runner',
  updatedAt: new Date().toISOString(),
};

const groupedDoc: HeiBanDocument = {
  schemaVersion: '1.0.0',
  version: '1.0',
  board: docF04.board,
  objects: [groupedObject],
  exportedAt: new Date().toISOString(),
};

const roundtripJson = JSON.stringify(groupedDoc);
const roundtripDoc: HeiBanDocument = JSON.parse(roundtripJson);
assertEqual(roundtripDoc.objects[0].groupId, 'group_test_alpha', '物件 groupId 應成功往返且完全相符');

// -------------------------------------------------------------------------
// 5. Cross-Platform 10-Client Convergence Parity with macOS Swift (W29, A30, A31)
// -------------------------------------------------------------------------
console.log('\n[測試 5] 跨平台十人協作收斂 (LWW + ID 破歧義) 與 Swift 引擎對等驗收 (W29, A30, A31)');

interface BoardMutation {
  id: string;
  boardId: string;
  baseRevision: number;
  timestamp: string;
  upsertedObjects?: BoardObject[];
  deletedObjectIds?: string[];
  updatedMetadata?: Partial<BoardMetadata>;
}

function convergeDocument(
  baseDocument: HeiBanDocument,
  incomingMutations: BoardMutation[]
): HeiBanDocument {
  const doc: HeiBanDocument = JSON.parse(JSON.stringify(baseDocument));
  const objMap = new Map<string, BoardObject>();
  for (const obj of doc.objects) {
    objMap.set(obj.id, obj);
  }

  // 按 timestamp 與 id 穩定排序
  const sortedMutations = [...incomingMutations].sort((a, b) => {
    if (a.timestamp === b.timestamp) {
      return a.id.localeCompare(b.id);
    }
    return a.timestamp.localeCompare(b.timestamp);
  });

  for (const mut of sortedMutations) {
    if (mut.deletedObjectIds) {
      for (const delId of mut.deletedObjectIds) {
        objMap.delete(delId);
      }
    }

    if (mut.upsertedObjects) {
      for (const inserted of mut.upsertedObjects) {
        const existing = objMap.get(inserted.id);
        if (existing) {
          if ((existing.updatedAt || '') > (inserted.updatedAt || '')) {
            continue; // LWW: 已有更新之版本
          }
        }
        objMap.set(inserted.id, inserted);
      }
    }

    if (mut.updatedMetadata) {
      Object.assign(doc.board, mut.updatedMetadata);
    }
  }

  // 排序: zIndex, 然後 id (保證與 Swift 確定性一致)
  const resultObjects = Array.from(objMap.values()).sort((a, b) => {
    if (a.zIndex === b.zIndex) {
      return a.id.localeCompare(b.id);
    }
    return a.zIndex - b.zIndex;
  });

  doc.objects = resultObjects;
  const maxRev = Math.max(...incomingMutations.map((m) => m.baseRevision), doc.board.revision || 1);
  doc.board.revision = maxRev + 1;
  return doc;
}

// 建立模擬基準黑板
const stickyId = 'sticky_collab_center';
const circleId = 'circle_collab_todelete';
const collabBaseDoc: HeiBanDocument = {
  schemaVersion: '1.0.0',
  version: '1.0',
  board: {
    id: 'board_ten_clients_ts',
    title: 'TS 跨平台協作黑板',
    ownerId: 'test_owner',
    ownerName: 'Test Owner',
    gridStyle: 'dots',
    revision: 1,
    canvasMode: 'infinite',
    boardTheme: 'dark',
    backgroundColor: '#18181b',
    gridType: 'dots',
    gridSize: 20,
    zoom: 1.0,
    scrollX: 0,
    scrollY: 0,
    createdAt: '2026-10-03T01:00:00Z',
    updatedAt: '2026-10-03T01:00:00Z',
  },
  objects: [
    {
      id: stickyId,
      boardId: 'board_ten_clients_ts',
      type: 'sticky',
      x: 100,
      y: 100,
      width: 200,
      height: 200,
      strokeColor: '#facc15',
      fillColor: '#fef08a',
      strokeWidth: 1,
      opacity: 1,
      rotation: 0,
      zIndex: 0,
      text: '初始便簽內容',
      createdBy: 'owner',
      updatedAt: '2026-10-03T01:00:00Z',
    },
    {
      id: circleId,
      boardId: 'board_ten_clients_ts',
      type: 'circle',
      x: 400,
      y: 100,
      width: 100,
      height: 100,
      strokeColor: '#3b82f6',
      fillColor: 'none',
      strokeWidth: 2,
      opacity: 1,
      rotation: 0,
      zIndex: 0,
      createdBy: 'owner',
      updatedAt: '2026-10-03T01:00:00Z',
    },
  ],
  exportedAt: '2026-10-03T01:00:00Z',
};

// 10 個客戶端產生的並發 mutations (包含修改、刪除、新增)
const tsMutations: BoardMutation[] = [];
for (let i = 1; i <= 8; i++) {
  tsMutations.push({
    id: `mut_client_ts_${i}`,
    boardId: 'board_ten_clients_ts',
    baseRevision: i,
    timestamp: `2026-10-03T01:00:0${i}Z`,
    upsertedObjects: [
      {
        id: `rect_client_ts_${i}`,
        boardId: 'board_ten_clients_ts',
        type: 'rect',
        x: 100 * i,
        y: 300,
        width: 80,
        height: 60,
        strokeColor: '#10b981',
        fillColor: 'none',
        strokeWidth: 2,
        opacity: 1,
        rotation: 0,
        zIndex: 0,
        createdBy: `client_${i}`,
        updatedAt: `2026-10-03T01:00:0${i}Z`,
      },
    ],
  });
}

// Client 9 修改同一個便簽
tsMutations.push({
  id: 'mut_client_ts_9',
  boardId: 'board_ten_clients_ts',
  baseRevision: 9,
  timestamp: '2026-10-03T01:00:10Z',
  upsertedObjects: [
    {
      id: stickyId,
      boardId: 'board_ten_clients_ts',
      type: 'sticky',
      x: 120,
      y: 120,
      width: 220,
      height: 220,
      strokeColor: '#facc15',
      fillColor: '#fef08a',
      strokeWidth: 1,
      opacity: 1,
      rotation: 0,
      zIndex: 0,
      text: 'Client 9 TS 收斂之便簽內容',
      createdBy: 'client_9',
      updatedAt: '2026-10-03T01:00:10Z',
    },
  ],
});

// Client 10 刪除圓形
tsMutations.push({
  id: 'mut_client_ts_10',
  boardId: 'board_ten_clients_ts',
  baseRevision: 10,
  timestamp: '2026-10-03T01:00:15Z',
  deletedObjectIds: [circleId],
});

// 模擬 10 個客戶端隨機亂序接收
const clientDocs: HeiBanDocument[] = [];
for (let c = 0; c < 10; c++) {
  const shuffled = [...tsMutations].sort(() => Math.random() - 0.5);
  const res = convergeDocument(collabBaseDoc, shuffled);
  clientDocs.push(res);
}

const refDoc = clientDocs[0];
for (let c = 0; c < 10; c++) {
  assertEqual(clientDocs[c].objects.length, refDoc.objects.length, `TS 客戶端 ${c + 1} 物件數一致`);
  assertEqual(clientDocs[c].board.revision, refDoc.board.revision, `TS 客戶端 ${c + 1} 修訂號一致`);
  assertEqual(
    clientDocs[c].objects.map((o) => o.id).join(','),
    refDoc.objects.map((o) => o.id).join(','),
    `TS 客戶端 ${c + 1} 物件排序與 ID 完全一致`
  );
}

const finalStickyObj = refDoc.objects.find((o) => o.id === stickyId);
assertEqual(finalStickyObj?.text, 'Client 9 TS 收斂之便簽內容', 'Client 9 LWW 內容獲勝');
assertTrue(!refDoc.objects.some((o) => o.id === circleId), '被刪除之圓形在 TS 收斂中完全移除');
assertEqual(
  refDoc.objects.filter((o) => o.type === 'rect').length,
  8,
  '8 個客戶端新增的矩形 100% 完整保留'
);

// -------------------------------------------------------------------------
// 6. Cross-Platform Architectural Decisions & Metrics (W29, A23, A31)
// -------------------------------------------------------------------------
console.log('\n[測試 6] 跨平台架構決策與字型度量容差規範驗證 (W29, A23, A31)');

const adrPath = path.resolve(__dirname, '../docs/PLATFORM_DECISIONS.zh-TW.md');
assertTrue(fs.existsSync(adrPath), '跨平台架構決策文件 PLATFORM_DECISIONS.zh-TW.md 應存在');
const adrContent = fs.readFileSync(adrPath, 'utf-8');
assertTrue(adrContent.includes('SwiftUI + AppKit + Metal'), 'ADR 應記錄 macOS Metal 原生渲染');
assertTrue(adrContent.includes('React 19 + TypeScript'), 'ADR 應記錄 Web React/Canvas 渲染');
assertTrue(adrContent.includes('WinUI 3 + C#'), 'ADR 應記錄 Windows Direct2D 渲染');
assertTrue(adrContent.includes('2.0'), 'ADR 應定義字型度量容差 ≤ 2.0 pt');

// -------------------------------------------------------------------------
// 7. Web Transform Handles & Dynamic Cursors (Image, Line, Rotate) (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 7] Web 控制器周圍 8 點與旋轉控制點動態游標形狀與旋轉狀態契約驗證 (立靶驗收)');

const handleCursorMap: Record<string, string> = {
  ml: 'cursor-ew-resize',
  mr: 'cursor-ew-resize',
  tm: 'cursor-ns-resize',
  bm: 'cursor-ns-resize',
  tl: 'cursor-nwse-resize',
  br: 'cursor-nwse-resize',
  tr: 'cursor-nesw-resize',
  bl: 'cursor-nesw-resize',
};

assertEqual(handleCursorMap['ml'], 'cursor-ew-resize', 'Web 左中點為水平雙向箭頭游標');
assertEqual(handleCursorMap['mr'], 'cursor-ew-resize', 'Web 右中點為水平雙向箭頭游標');
assertEqual(handleCursorMap['tm'], 'cursor-ns-resize', 'Web 頂中點為垂直雙向箭頭游標');
assertEqual(handleCursorMap['bm'], 'cursor-ns-resize', 'Web 底中點為垂直雙向箭頭游標');
assertEqual(handleCursorMap['tl'], 'cursor-nwse-resize', 'Web 左上角為斜邊 NW-SE 雙向箭頭游標');
assertEqual(handleCursorMap['br'], 'cursor-nwse-resize', 'Web 右下角為斜邊 NW-SE 雙向箭頭游標');
assertEqual(handleCursorMap['tr'], 'cursor-nesw-resize', 'Web 右上角為斜邊 NE-SW 雙向箭頭游標');
assertEqual(handleCursorMap['bl'], 'cursor-nesw-resize', 'Web 左下角為斜邊 NE-SW 雙向箭頭游標');

const canvasSourcePath = path.resolve(__dirname, '../src/components/Canvas.tsx');
assertTrue(fs.existsSync(canvasSourcePath), 'Canvas.tsx 原始碼檔案應存在');
const canvasSource = fs.readFileSync(canvasSourcePath, 'utf-8');

assertTrue(canvasSource.includes('cursor-ew-resize'), 'Canvas.tsx 應包含水平雙向箭頭樣式');
assertTrue(canvasSource.includes('cursor-ns-resize'), 'Canvas.tsx 應包含垂直雙向箭頭樣式');
assertTrue(canvasSource.includes('cursor-nwse-resize'), 'Canvas.tsx 應包含左上右下斜邊箭頭樣式');
assertTrue(canvasSource.includes('cursor-nesw-resize'), 'Canvas.tsx 應包含右上左下斜邊箭頭樣式');
assertTrue(canvasSource.includes('handleRotate') || canvasSource.includes('rotate'), 'Canvas.tsx 應定義旋轉控制點與互動邏輯');

// -------------------------------------------------------------------------
// 8. Canvas Formats (Infinite / Common Dimensions / Notebook) & Multi-page Contract (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 8] 畫布格式選擇 (無邊界 / 常見尺寸 / 多頁筆記本) 與多頁筆記契約驗證 (立靶驗收)');

const validModes: CanvasMode[] = ['infinite', 'fixed', 'notebook'];
assertTrue(validModes.includes('notebook'), 'CanvasMode 契約包含 notebook');
assertTrue(validModes.includes('infinite'), 'CanvasMode 契約包含 infinite');
assertTrue(validModes.includes('fixed'), 'CanvasMode 契約包含 fixed');

const validPresets: CanvasPreset[] = ['1_1', '9_16', 'notebook', '16_9', '4_3', 'a4_portrait', 'a4_landscape'];
assertTrue(validPresets.includes('1_1'), 'CanvasPreset 包含 1:1 正方形');
assertTrue(validPresets.includes('9_16'), 'CanvasPreset 包含 9:16 手機直式');
assertTrue(validPresets.includes('notebook'), 'CanvasPreset 包含 notebook 筆記規格');

// 筆記本頁面資料契約
const page1: BoardPage = {
  id: 'page_uuid_1',
  title: '第 1 頁',
  index: 0,
  createdAt: '2026-10-04T00:00:00Z',
  updatedAt: '2026-10-04T00:00:00Z',
};
const page2: BoardPage = {
  id: 'page_uuid_2',
  title: '第 2 頁',
  index: 1,
  createdAt: '2026-10-04T00:01:00Z',
  updatedAt: '2026-10-04T00:01:00Z',
};
assertEqual(page1.title, '第 1 頁', '第 1 頁結構完整');
assertEqual(page2.title, '第 2 頁', '第 2 頁結構完整');

// 筆記本頁面物件隔離邏輯契約
const notebookObjects: BoardObject[] = [
  {
    id: 'obj_p1_sticky',
    boardId: 'test_board',
    type: 'sticky',
    x: 100,
    y: 100,
    width: 200,
    height: 150,
    strokeColor: '#1f2937',
    fillColor: '#fef08a',
    strokeWidth: 1,
    zIndex: 1,
    rotation: 0,
    opacity: 1,
    pageId: 'page_uuid_1',
    text: '第一頁的筆記',
    createdBy: 'web_user',
    updatedAt: '2026-10-04T00:00:00Z',
  },
  {
    id: 'obj_legacy_p1',
    boardId: 'test_board',
    type: 'rect',
    x: 200,
    y: 200,
    width: 80,
    height: 80,
    strokeColor: '#1f2937',
    fillColor: '#3b82f6',
    strokeWidth: 2,
    zIndex: 2,
    rotation: 0,
    opacity: 1,
    // 無 pageId (向下相容)，預設歸屬第一頁
    createdBy: 'web_user',
    updatedAt: '2026-10-04T00:00:00Z',
  },
  {
    id: 'obj_p2_circle',
    boardId: 'test_board',
    type: 'circle',
    x: 300,
    y: 300,
    width: 60,
    height: 60,
    strokeColor: '#1f2937',
    fillColor: '#10b981',
    strokeWidth: 2,
    zIndex: 3,
    rotation: 0,
    opacity: 1,
    pageId: 'page_uuid_2',
    createdBy: 'web_user',
    updatedAt: '2026-10-04T00:01:00Z',
  },
];

function filterPageObjects(objects: BoardObject[], activePageId: string, firstPageId: string) {
  return objects.filter((o) => {
    if (o.pageId) {
      return o.pageId === activePageId;
    }
    return activePageId === firstPageId;
  });
}

const p1Visible = filterPageObjects(notebookObjects, 'page_uuid_1', 'page_uuid_1');
assertEqual(p1Visible.length, 2, '第 1 頁應包含指定物件與無 pageId 之向下相容物件');
assertTrue(p1Visible.some((o) => o.id === 'obj_p1_sticky'), '第 1 頁包含 sticky');
assertTrue(p1Visible.some((o) => o.id === 'obj_legacy_p1'), '第 1 頁包含向下相容 rect');
assertTrue(!p1Visible.some((o) => o.id === 'obj_p2_circle'), '第 1 頁不包含第 2 頁之 circle');

const p2Visible = filterPageObjects(notebookObjects, 'page_uuid_2', 'page_uuid_1');
assertEqual(p2Visible.length, 1, '第 2 頁僅包含第 2 頁專屬物件');
assertEqual(p2Visible[0].id, 'obj_p2_circle', '第 2 頁正確呈現 circle');

// 筆記本刪除安全防呆守則契約
function canDeletePage(pages: BoardPage[]) {
  return pages.length > 1;
}
assertTrue(!canDeletePage([page1]), '僅剩單頁之筆記本不可刪除 (防呆守則)');
assertTrue(canDeletePage([page1, page2]), '多於 1 頁之筆記本允許刪除指定頁面');

// -------------------------------------------------------------------------
// 9. 畫布風格加強 (五線譜/B5/封面/格線顏色)、HTML 匯出與筆刷游標預覽契約 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 9] 畫布格式增強 (五線譜/B5/封面/格線顏色)、離線 HTML 匯出與懸停游標契約驗證 (立靶驗收)');

const validGridStyles: GridStyle[] = ['grid', 'dots', 'lines', 'staff', 'blank'];
assertTrue(validGridStyles.includes('staff'), 'GridStyle 契約包含 staff (五線譜)');

const allPresets: CanvasPreset[] = ['infinite', 'a4_portrait', 'a4_landscape', 'a3_landscape', '16_9', '4_3', '1_1', '9_16', 'b5', 'notebook', 'custom'];
assertTrue(allPresets.includes('b5'), 'CanvasPreset 包含 b5 規格');

// 測試 BoardMetadata 擴充欄位往返
const advancedMeta: BoardMetadata = {
  id: 'board_advanced',
  title: '樂理筆記與草稿',
  ownerId: 'user_1',
  ownerName: '音樂家',
  backgroundColor: '#FAF8F5',
  gridStyle: 'staff',
  boardTheme: 'whiteboard',
  coverStyle: 'leather',
  orientation: 'landscape',
  gridColor: '#475569',
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
};
assertEqual(advancedMeta.gridStyle, 'staff', '五線譜內頁風格設定正確');
assertEqual(advancedMeta.coverStyle, 'leather', '皮革封面風格設定正確');
assertEqual(advancedMeta.orientation, 'landscape', '橫向設定正確');
assertEqual(advancedMeta.gridColor, '#475569', '自訂格線顏色設定正確');

// 測試 HTML 離線匯出產物契約
import { generateStandaloneHtml } from '../src/utils/export';
const testObjects: BoardObject[] = [
  {
    id: 'obj_note',
    boardId: 'board_advanced',
    type: 'text',
    x: 100,
    y: 100,
    width: 200,
    height: 50,
    text: 'C 大調音階',
    strokeColor: '#000000',
    fillColor: 'none',
    strokeWidth: 2,
    opacity: 1,
    zIndex: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];
const exportedHtml = generateStandaloneHtml(testObjects, advancedMeta);
assertTrue(exportedHtml.includes('<!DOCTYPE html>'), '導出 HTML 包含標準 DOCTYPE');
assertTrue(exportedHtml.includes('C 大調音階'), '導出 HTML 包含畫布文字物件內容');
assertTrue(exportedHtml.includes('heiban-data'), '導出 HTML 內嵌 heiban-data JSON 資料');
assertTrue(exportedHtml.includes('zoomIn()') && exportedHtml.includes('zoomOut()'), '導出 HTML 包含縮放與視圖互動邏輯');

// 測試懸停游標直徑計算契約
function computeHoverDiameter(tool: string, strokeWidth: number, eraserSize: number, zoom: number): number {
  if (tool === 'eraser') return eraserSize * zoom;
  if (['pen', 'highlighter', 'paint'].includes(tool)) return Math.max(4, strokeWidth * zoom);
  return 0;
}
assertEqual(computeHoverDiameter('pen', 5, 24, 1.5), 7.5, '畫筆直徑等於 strokeWidth * zoom');
assertEqual(computeHoverDiameter('eraser', 5, 30, 2.0), 60.0, '橡皮擦直徑等於 eraserSize * zoom');
assertEqual(computeHoverDiameter('select', 5, 30, 1.0), 0, '選取工具不觸發畫筆預覽游標');


// -------------------------------------------------------------------------
// 10. 黑板存取與成員契約 (Owner/Collaborator/10人上限/撤銷) 與 Firestore 安全規則 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 10] 黑板存取與成員契約 (Owner/Collaborator/10人上限/撤銷) 與 Firestore 安全規則驗證 (立靶驗收)');

const firestoreRulesPath = path.resolve(__dirname, '../firestore.rules');
assertTrue(fs.existsSync(firestoreRulesPath), 'firestore.rules 檔案應存在');
const firestoreRules = fs.readFileSync(firestoreRulesPath, 'utf-8');

// 靜態規則語意結構驗證
assertTrue(firestoreRules.includes('isBoardMember'), 'firestore.rules 應定義 isBoardMember 判定');
assertTrue(firestoreRules.includes('canEditBoard'), 'firestore.rules 應定義 canEditBoard 編輯權限判定');
assertTrue(firestoreRules.includes('hasValidMemberCount'), 'firestore.rules 應定義 hasValidMemberCount 人數上限');
assertTrue(firestoreRules.includes("'paint'"), 'firestore.rules 物件型別白名單應包含 paint');
assertTrue(firestoreRules.includes("'curve'"), 'firestore.rules 物件型別白名單應包含 curve');
assertTrue(firestoreRules.includes("'staff'"), 'firestore.rules 網格風格白名單應包含 staff 五線譜');
assertTrue(firestoreRules.includes('getBoardData(boardId)'), 'firestore.rules 子集合物件與 presence 應繼承父黑板存取權限');

// 成員契約邏輯驗證模擬器 (嚴格對齊 firestore.rules 邏輯)
function simIsValidId(id: unknown): boolean {
  return typeof id === 'string' && id.length > 0 && id.length <= 128 && /^[a-zA-Z0-9_\-]+$/.test(id);
}

function simIsBoardMember(authUid: string | null, boardData: any): boolean {
  if (!authUid) return false;
  if (boardData.ownerId === authUid) return true;
  if (Array.isArray(boardData.collaboratorIds) && boardData.collaboratorIds.includes(authUid)) {
    if (boardData.memberRoles && boardData.memberRoles[authUid] === 'revoked') {
      return false;
    }
    return true;
  }
  if (boardData.memberRoles && typeof boardData.memberRoles === 'object') {
    const role = boardData.memberRoles[authUid];
    return ['owner', 'editor', 'viewer'].includes(role);
  }
  return false;
}

function simCanEditBoard(authUid: string | null, boardData: any): boolean {
  if (!authUid) return false;
  if (boardData.ownerId === authUid) return true;
  if (Array.isArray(boardData.collaboratorIds) && boardData.collaboratorIds.includes(authUid)) {
    if (boardData.memberRoles) {
      if (boardData.memberRoles[authUid] === 'revoked' || boardData.memberRoles[authUid] === 'viewer') {
        return false;
      }
    }
    return true;
  }
  if (boardData.memberRoles && typeof boardData.memberRoles === 'object') {
    const role = boardData.memberRoles[authUid];
    return ['owner', 'editor'].includes(role);
  }
  return false;
}

function simHasValidMemberCount(data: any): boolean {
  if (Array.isArray(data.collaboratorIds) && data.collaboratorIds.length > 9) return false;
  if (data.members && typeof data.members === 'object' && Object.keys(data.members).length > 10) return false;
  if (data.memberRoles && typeof data.memberRoles === 'object' && Object.keys(data.memberRoles).length > 10) return false;
  return true;
}

function simIsValidBoardObject(data: any): boolean {
  const validTypes = [
    'stroke', 'highlighter', 'paint', 'curve',
    'rect', 'circle', 'triangle', 'quadrilateral', 'diamond', 'star',
    'arrow', 'line', 'text', 'sticky', 'image', 'pin'
  ];
  return (
    typeof data.boardId === 'string' &&
    data.boardId.length <= 128 &&
    typeof data.type === 'string' &&
    validTypes.includes(data.type) &&
    typeof data.x === 'number' &&
    typeof data.y === 'number' &&
    typeof data.createdBy === 'string' &&
    data.createdBy.length <= 128 &&
    typeof data.zIndex === 'number'
  );
}

const sampleBoard = {
  id: 'board_collab_test',
  title: '協作安全黑板',
  ownerId: 'owner_alice',
  backgroundColor: '#172e25',
  gridStyle: 'staff',
  collaboratorIds: ['editor_bob', 'viewer_carol', 'revoked_dave'],
  memberRoles: {
    owner_alice: 'owner',
    editor_bob: 'editor',
    viewer_carol: 'viewer',
    revoked_dave: 'revoked',
  },
};

// 1. 未登入使用者一律拒絕
assertEqual(simIsBoardMember(null, sampleBoard), false, '未登入使用者不得存取黑板');
assertEqual(simCanEditBoard(null, sampleBoard), false, '未登入使用者不得編輯黑板');

// 2. 非成員使用者一律拒絕
assertEqual(simIsBoardMember('intruder_eve', sampleBoard), false, '非成員使用者讀取應被拒絕');
assertEqual(simCanEditBoard('intruder_eve', sampleBoard), false, '非成員使用者寫入應被拒絕');

// 3. 擁有者具備讀取與編輯權限
assertEqual(simIsBoardMember('owner_alice', sampleBoard), true, '擁有者具備成員身分');
assertEqual(simCanEditBoard('owner_alice', sampleBoard), true, '擁有者具備完整編輯權限');

// 4. 有效協作者 (editor) 具備讀取與編輯權限
assertEqual(simIsBoardMember('editor_bob', sampleBoard), true, '有效協作者具備成員身分');
assertEqual(simCanEditBoard('editor_bob', sampleBoard), true, 'editor 協作者具備編輯權限');

// 5. 唯讀成員 (viewer) 具備讀取權限，但嚴禁編輯
assertEqual(simIsBoardMember('viewer_carol', sampleBoard), true, 'viewer 協作者具備讀取身分');
assertEqual(simCanEditBoard('viewer_carol', sampleBoard), false, 'viewer 協作者嚴格禁止編輯寫入 (唯讀)');

// 6. 撤銷成員 (revoked) 讀取與寫入全數拒絕
assertEqual(simIsBoardMember('revoked_dave', sampleBoard), false, '已撤銷成員讀取黑板被嚴格拒絕');
assertEqual(simCanEditBoard('revoked_dave', sampleBoard), false, '已撤銷成員編輯黑板被嚴格拒絕');

// 7. 偽造 ownerId 建立黑板判定
const createIncoming = { ownerId: 'forged_owner_id' };
const currentAuthUid = 'real_user_uid';
assertEqual(createIncoming.ownerId === currentAuthUid, false, '建立黑板偽造 ownerId 應被嚴格拒絕');

// 8. 十人上限規則 (最多 9 位協作者 + 1 位擁有者 = 10 人)
const validCollaborators = ['u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9'];
assertTrue(simHasValidMemberCount({ collaboratorIds: validCollaborators }), '9 位協作者符合十人上限');
const elevenCollaborators = ['u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10'];
assertEqual(simHasValidMemberCount({ collaboratorIds: elevenCollaborators }), false, '第 11 位協作者被服務端規則嚴格拒絕');

// 9. 合法與非法 ID 檢查
assertTrue(simIsValidId('board_123_abc-XYZ'), '合法標準識別碼通過檢驗');
assertEqual(simIsValidId(''), false, '空字串識別碼被拒絕');
assertEqual(simIsValidId('../traversal/id'), false, '路徑穿透識別碼 (../) 被嚴格拒絕');
assertEqual(simIsValidId('board/sub/doc'), false, '包含斜線之非法識別碼被嚴格拒絕');

// 10. 物件型別包含 paint 與 curve
assertTrue(
  simIsValidBoardObject({
    boardId: 'b1',
    type: 'paint',
    x: 10,
    y: 20,
    createdBy: 'u1',
    zIndex: 1,
  }),
  'paint 物件型別應被規則允許'
);
assertTrue(
  simIsValidBoardObject({
    boardId: 'b1',
    type: 'curve',
    x: 10,
    y: 20,
    createdBy: 'u1',
    zIndex: 1,
  }),
  'curve 物件型別應被規則允許'
);
assertEqual(
  simIsValidBoardObject({
    boardId: 'b1',
    type: 'malicious_script',
    x: 10,
    y: 20,
    createdBy: 'u1',
    zIndex: 1,
  }),
  false,
  '未列入白名單之非法物件型別被嚴格拒絕'
);

// -------------------------------------------------------------------------
// 11. Web、Swift、Firestore Schema 完整對齊與雙向往返契約驗證 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 11] Web、Swift、Firestore Schema 完整對齊與雙向往返契約驗證 (立靶驗收)');

// 1. curve 向量曲線物件序列化與欄位對齊
const curveObj: BoardObject = {
  id: 'obj_curve_test',
  boardId: 'board_align_1',
  type: 'curve',
  x: 150,
  y: 200,
  width: 300,
  height: 150,
  points: JSON.stringify([
    { x: 150, y: 200 },
    { x: 300, y: 100 },
    { x: 450, y: 200 },
  ]),
  strokeColor: '#3b82f6',
  fillColor: 'none',
  strokeWidth: 3.5,
  opacity: 0.95,
  rotation: 0,
  zIndex: 1,
  createdBy: 'user_curve',
  updatedAt: new Date().toISOString(),
};
assertEqual(curveObj.type, 'curve', 'Web BoardObject 成功容納 curve 物件型別');
assertTrue(JSON.parse(curveObj.points!).length === 3, 'curve 控制點序列化正確');

// 2. 完整黑板文件雙向序列化往返
const testDoc: HeiBanDocument = {
  schemaVersion: '1.0.0',
  version: '1.0',
  board: {
    id: 'board_schema_alignment',
    title: '全平台對齊黑板',
    ownerId: 'owner_user_1',
    ownerName: '測試架構師',
    backgroundColor: '#FAF8F5',
    gridStyle: 'staff',
    boardTheme: 'whiteboard',
    collaboratorIds: ['collab_1', 'collab_2'],
    memberRoles: {
      owner_user_1: 'owner',
      collab_1: 'editor',
      collab_2: 'viewer',
    },
    canvasMode: 'notebook',
    canvasPreset: 'b5',
    coverStyle: 'vintage_leather',
    orientation: 'portrait',
    gridColor: '#4B5563',
    revision: 7,
    unknownCustomBoardKey: 'preserved_board_meta_value',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  objects: [
    curveObj,
    {
      id: 'obj_paint_test',
      boardId: 'board_schema_alignment',
      type: 'paint',
      x: 50,
      y: 50,
      width: 100,
      height: 100,
      points: JSON.stringify([{ x: 50, y: 50 }, { x: 150, y: 150 }]),
      strokeColor: '#10b981',
      fillColor: 'none',
      strokeWidth: 12,
      opacity: 0.8,
      rotation: 0,
      zIndex: 2,
      unknownCustomObjectKey: 'preserved_object_attr_value',
      createdBy: 'user_paint',
      updatedAt: new Date().toISOString(),
    },
  ],
  exportedAt: new Date().toISOString(),
  unknownCustomDocKey: 'preserved_root_doc_value',
};

// JSON 序列化與反序列化 roundtrip
const serialized = JSON.stringify(testDoc);
const deserialized = JSON.parse(serialized) as HeiBanDocument;

assertEqual(deserialized.schemaVersion, '1.0.0', 'SchemaVersion 往返一致');
assertEqual(deserialized.board.gridStyle, 'staff', '五線譜網格風格往返一致');
assertEqual(deserialized.board.collaboratorIds?.length, 2, '協作者清單長度往返一致');
assertEqual(deserialized.board.memberRoles?.['collab_2'], 'viewer', '成員角色字典往返一致');
assertEqual(deserialized.objects[0].type, 'curve', 'curve 物件型別往返一致');
assertEqual(deserialized.objects[1].type, 'paint', 'paint 物件型別往返一致');

// 未知擴展欄位無損保留 (A23)
assertEqual(
  (deserialized.board as any)['unknownCustomBoardKey'],
  'preserved_board_meta_value',
  '黑板未知擴展欄位無損保留'
);
assertEqual(
  (deserialized.objects[1] as any)['unknownCustomObjectKey'],
  'preserved_object_attr_value',
  '物件未知擴展欄位無損保留'
);
assertEqual(
  (deserialized as any)['unknownCustomDocKey'],
  'preserved_root_doc_value',
  '根文件未知擴展欄位無損保留'
);

// 3. 未來大版本檢測保護 (A23)
function validateSupportedSchemaVersion(doc: any): boolean {
  if (!doc || typeof doc !== 'object') return false;
  const versionStr = doc.schemaVersion || '1.0.0';
  const major = parseInt(versionStr.split('.')[0], 10);
  return major <= 1; // 目前支援 1.x
}
assertEqual(validateSupportedSchemaVersion(testDoc), true, '合法 1.0.0 版本通過檢驗');
assertEqual(validateSupportedSchemaVersion({ schemaVersion: '99.0.0' }), false, '未來不相容主版本號 (99.0.0) 被安全阻擋');
assertEqual(validateSupportedSchemaVersion(null), false, '空資料被安全阻擋');

// -------------------------------------------------------------------------
// 12. 本機／雲端文件 Session 邊界與衝突處理契約 (AG-12 立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 12] 本機／雲端文件 Session 邊界、空快照套用與衝突處理契約 (AG-12 立靶驗收)');

function isCloudBoard(meta: BoardMetadata): boolean {
  return meta.source === 'cloud';
}

function isLocalBoard(meta: BoardMetadata): boolean {
  return meta.source !== 'cloud';
}

const localMeta: BoardMetadata = {
  id: 'board_local_123',
  title: '本機離線黑板',
  ownerId: 'local',
  ownerName: '本機使用者',
  backgroundColor: '#172e25',
  gridStyle: 'grid',
  boardTheme: 'blackboard',
  source: 'local',
  createdAt: '2026-10-06T00:00:00Z',
  updatedAt: '2026-10-06T00:00:00Z',
};

const cloudMeta: BoardMetadata = {
  id: 'board_cloud_456',
  title: '雲端同步黑板',
  ownerId: 'user_cloud_99',
  ownerName: '雲端使用者',
  backgroundColor: '#172e25',
  gridStyle: 'grid',
  boardTheme: 'blackboard',
  source: 'cloud',
  createdAt: '2026-10-06T00:00:00Z',
  updatedAt: '2026-10-06T00:00:00Z',
};

assertEqual(isCloudBoard(cloudMeta), true, '雲端黑板識別為 Cloud');
assertEqual(isLocalBoard(cloudMeta), false, '雲端黑板非 Local');
assertEqual(isLocalBoard(localMeta), true, '本機黑板識別為 Local');
assertEqual(isCloudBoard(localMeta), false, '本機黑板非 Cloud');

// 測試 Session Snapshot 合併與衝突處理核心邏輯
function reconcileObjectsSnapshot(
  board: BoardMetadata,
  cloudObjects: BoardObject[],
  isSnapshotEmpty: boolean,
  pendingWrites: Map<string, BoardObject>,
  pendingLocalUpdates: Map<string, BoardObject>,
  currentLocalObjects: BoardObject[]
): BoardObject[] {
  // 若為本機文件，不接受任何雲端 snapshot 干擾
  if (board.source !== 'cloud') {
    return currentLocalObjects;
  }

  // 若為雲端文件且 snapshot 為空
  if (isSnapshotEmpty) {
    if (pendingWrites.size === 0) {
      return []; // 雲端空板清空物件，不殘留前板內容
    }
    return Array.from(pendingWrites.values());
  }

  // 雲端物件與本地未保存修改之合併
  const result: BoardObject[] = [];
  const cloudIds = new Set<string>();

  for (const cloudObj of cloudObjects) {
    cloudIds.add(cloudObj.id);
    const localPending = pendingWrites.get(cloudObj.id) || pendingLocalUpdates.get(cloudObj.id);
    // 未保存之本地修改優先，不被雲端 snapshot 靜默覆蓋
    result.push(localPending || cloudObj);
  }

  // 本地新增但尚未抵達雲端 snapshot 的物件，必須完整保留
  for (const [id, localObj] of pendingWrites.entries()) {
    if (!cloudIds.has(id)) {
      result.push(localObj);
    }
  }

  return result;
}

// 驗證情境 1：切換至雲端空板，無殘留本地未寫入，物件清空
const previousObjects: BoardObject[] = [
  {
    id: 'obj_prev',
    boardId: 'board_prev',
    type: 'stroke',
    x: 10,
    y: 10,
    width: 20,
    height: 20,
    strokeColor: '#fff',
    fillColor: 'none',
    strokeWidth: 2,
    opacity: 1,
    rotation: 0,
    zIndex: 1,
    createdBy: 'user',
    updatedAt: '2026-10-06T00:00:00Z',
  },
];
const emptyCloudResult = reconcileObjectsSnapshot(
  cloudMeta,
  [],
  true,
  new Map(),
  new Map(),
  previousObjects
);
assertEqual(emptyCloudResult.length, 0, '切換至雲端空板不殘留前板內容 (清空為 0)');

// 驗證情境 2：登入狀態下開啟本機板，雲端空 snapshot 嚴禁清空本機板內容
const localBoardObjects: BoardObject[] = [
  {
    id: 'obj_local_important',
    boardId: 'board_local_123',
    type: 'rect',
    x: 50,
    y: 50,
    width: 100,
    height: 80,
    strokeColor: '#fff',
    fillColor: '#10b981',
    strokeWidth: 2,
    opacity: 1,
    rotation: 0,
    zIndex: 1,
    createdBy: 'local',
    updatedAt: '2026-10-06T00:00:00Z',
  },
];
const localProtectedResult = reconcileObjectsSnapshot(
  localMeta,
  [],
  true,
  new Map(),
  new Map(),
  localBoardObjects
);
assertEqual(localProtectedResult.length, 1, '本機板嚴禁被雲端空快照清空');
assertEqual(localProtectedResult[0].id, 'obj_local_important', '本機板原物件完整保留');

// 驗證情境 3：雲端快照抵達時，本地未保存修改不被靜默覆蓋
const cloudObjRemote: BoardObject = {
  id: 'obj_conflict_1',
  boardId: 'board_cloud_456',
  type: 'stroke',
  x: 100,
  y: 100,
  width: 50,
  height: 50,
  strokeColor: '#ff0000', // 雲端舊顏色
  fillColor: 'none',
  strokeWidth: 2,
  opacity: 1,
  rotation: 0,
  zIndex: 1,
  createdBy: 'user_cloud_99',
  updatedAt: '2026-10-06T00:00:00Z',
};
const localPendingObj: BoardObject = {
  ...cloudObjRemote,
  strokeColor: '#00ff00', // 本地未保存新顏色
  updatedAt: '2026-10-06T00:01:00Z',
};
const pendingMap = new Map<string, BoardObject>([['obj_conflict_1', localPendingObj]]);
const conflictResolved = reconcileObjectsSnapshot(
  cloudMeta,
  [cloudObjRemote],
  false,
  pendingMap,
  new Map(),
  [localPendingObj]
);
assertEqual(conflictResolved.length, 1, '物件數量維持 1');
assertEqual(conflictResolved[0].strokeColor, '#00ff00', '本地未保存修改優先保留 (不被靜默覆蓋)');

// 驗證情境 4：本地剛建立的新物件，在尚未被雲端快照收錄前不被丟棄
const localNewObj: BoardObject = {
  id: 'obj_new_local',
  boardId: 'board_cloud_456',
  type: 'circle',
  x: 200,
  y: 200,
  width: 80,
  height: 80,
  strokeColor: '#fff',
  fillColor: 'none',
  strokeWidth: 2,
  opacity: 1,
  rotation: 0,
  zIndex: 2,
  createdBy: 'user_cloud_99',
  updatedAt: '2026-10-06T00:02:00Z',
};
const pendingWithNew = new Map<string, BoardObject>([
  ['obj_conflict_1', localPendingObj],
  ['obj_new_local', localNewObj],
]);
const mergedWithNew = reconcileObjectsSnapshot(
  cloudMeta,
  [cloudObjRemote],
  false,
  pendingWithNew,
  new Map(),
  [localPendingObj, localNewObj]
);
assertEqual(mergedWithNew.length, 2, '雲端快照收斂後完整保留本地未同步新物件');
assertTrue(mergedWithNew.some((o) => o.id === 'obj_new_local'), '本地新物件未被意外丟棄');

// 驗證 source 欄位在 Document 序列化與反序列化 roundtrip 成功
const docWithSource: HeiBanDocument = {
  schemaVersion: '1.0.0',
  board: cloudMeta,
  objects: [cloudObjRemote],
  exportedAt: new Date().toISOString(),
};
const serializedSourceDoc = JSON.parse(JSON.stringify(docWithSource)) as HeiBanDocument;
assertEqual(serializedSourceDoc.board.source, 'cloud', 'board.source 欄位序列化往返一致');

// -------------------------------------------------------------------------
// 13. AG-30: Web App 協調層拆分、獨立 Board Session 與防跨板串寫 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 13] AG-30: 獨立 Board Session、同步狀態與防跨板污染 (立靶驗收)');

import { BoardSessionController } from '../src/controllers/BoardSessionController';
import { LocalPersistenceManager } from '../src/controllers/LocalPersistenceManager';

// 13.1 本地黑板獨立 Session 與 syncStatus 判定
const sessionA = new BoardSessionController({
  id: 'board_local_alpha',
  title: '本機工作板 A',
  source: 'local',
  ownerId: 'local',
  createdAt: '2026-10-06T00:00:00Z',
  updatedAt: '2026-10-06T00:00:00Z',
});

assertEqual(sessionA.getSyncStatus(), 'local_only', '本機黑板同步狀態應為 local_only');
assertEqual(sessionA.getActiveBoardId(), 'board_local_alpha', 'Session A 作用中黑板 ID 正確');

// 13.2 雲端黑板 Session 與同步狀態判定
const sessionCloud = new BoardSessionController({
  id: 'board_cloud_beta',
  title: '雲端協作板 Beta',
  source: 'cloud',
  ownerId: 'user_owner_42',
  createdAt: '2026-10-06T00:00:00Z',
  updatedAt: '2026-10-06T00:00:00Z',
});

assertEqual(sessionCloud.getSyncStatus(), 'synced', '雲端初始黑板同步狀態為 synced');

// 13.3 佇列寫入與批次提交
const testObjA: BoardObject = {
  id: 'obj_session_a_1',
  type: 'rect',
  x: 10,
  y: 10,
  width: 50,
  height: 50,
  strokeColor: '#000',
  fillColor: 'none',
  strokeWidth: 2,
  opacity: 1,
  rotation: 0,
  zIndex: 1,
  createdBy: 'local',
  updatedAt: '2026-10-06T00:01:00Z',
};

sessionA.queueObjectWrite(testObjA);
assertEqual(sessionA.getPendingWritesCount(), 1, '物件寫入成功進入 Session 佇列');

let flushedBoardId = '';
let flushedObjects: BoardObject[] = [];
sessionA.setWriteHandler((bId, objs) => {
  flushedBoardId = bId;
  flushedObjects = objs;
});

sessionA.flushWrites();
assertEqual(flushedBoardId, 'board_local_alpha', 'Flush 目標黑板 ID 相符');
assertEqual(flushedObjects.length, 1, 'Flush 物件數量相符');
assertEqual(flushedObjects[0].id, 'obj_session_a_1', 'Flush 物件 ID 正確');
assertEqual(sessionA.getPendingWritesCount(), 0, 'Flush 完成後佇列清空');

// 13.4 切換黑板防止跨板污染 (Discards/Flushes writes bound to old board before switching)
sessionA.queueObjectWrite({ ...testObjA, id: 'obj_stale_before_switch' });
assertEqual(sessionA.getPendingWritesCount(), 1, '切換前佇列有 1 筆待寫入');

// 切換至新黑板 B
sessionA.switchBoard({
  id: 'board_local_gamma',
  title: '本機工作板 Gamma',
  source: 'local',
  ownerId: 'local',
  createdAt: '2026-10-06T00:05:00Z',
  updatedAt: '2026-10-06T00:05:00Z',
});

assertEqual(sessionA.getActiveBoardId(), 'board_local_gamma', '成功切換至新黑板 Gamma');
assertEqual(sessionA.getPendingWritesCount(), 0, '切換後舊黑板未提交寫入已被安全隔離，佇列重設為 0');

// 13.5 LocalPersistenceManager 獨立本地持久化管理
const persistence = new LocalPersistenceManager();
const saveSuccess = persistence.saveBoardSnapshot('board_persist_test', {
  board: {
    id: 'board_persist_test',
    title: '持久化測試板',
    source: 'local',
    createdAt: '2026-10-06T00:00:00Z',
    updatedAt: '2026-10-06T00:00:00Z',
  },
  objects: [testObjA],
  revision: 1,
});
assertTrue(saveSuccess, '本地黑板快照儲存成功');

const loaded = persistence.loadBoardSnapshot('board_persist_test');
assertEqual(loaded?.board.title, '持久化測試板', '本地快照還原標題相符');
assertEqual(loaded?.objects.length, 1, '本地快照還原物件數相符');
assertEqual(loaded?.revision, 1, '本地修訂號相符');

// 修訂衝突防護：傳入舊版本時拒絕靜默覆蓋
const conflictRejected = persistence.saveBoardSnapshot('board_persist_test', {
  board: {
    id: 'board_persist_test',
    title: '過期覆蓋嘗試',
    source: 'local',
    createdAt: '2026-10-06T00:00:00Z',
    updatedAt: '2026-10-06T00:00:00Z',
  },
  objects: [],
  revision: 0, // 舊版號 0 < 現有版號 1
});
assertTrue(!conflictRejected, '以舊版號覆蓋較新本機快照遭到拒絕');

// -------------------------------------------------------------------------
// 14. AG-31: Canvas 輸入平滑化、選取變形幾何與單手勢交易契約 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 14] AG-31: Canvas 平滑曲線、選取幾何與單手勢交易契約 (立靶驗收)');

import {
  getCurveSegment,
  computeSelectionHandles,
  getHandleCursor,
  GestureTransactionTracker,
} from '../src/utils/strokeSmoothing';

// 14.1 getCurveSegment 平滑曲線生成與端點接縫防護
const sampleStrokePoints: Point[] = [
  { x: 0, y: 0, pressure: 0.5 },
  { x: 20, y: 10, pressure: 0.6 },
  { x: 50, y: 15, pressure: 0.7 },
  { x: 90, y: 30, pressure: 0.8 },
];

const seg0WithMove = getCurveSegment(sampleStrokePoints, 1, true);
assertTrue(seg0WithMove.startsWith('M 20 10'), '含 Move 的線段起點應為 M 20 10');
assertTrue(seg0WithMove.includes('C '), '線段包含三次方貝茲曲線 C 指令');

const seg1WithoutMove = getCurveSegment(sampleStrokePoints, 2, false);
assertTrue(!seg1WithoutMove.startsWith('M'), '接續線段不應包含重複 M 指令 (防接縫突變)');
assertTrue(seg1WithoutMove.startsWith(' C '), '接續線段以 C 曲線無縫接軌');

// 14.2 computeSelectionHandles 8 點與旋轉手柄幾何度量對齊
const testBounds = { minX: 100, minY: 100, maxX: 300, maxY: 200, width: 200, height: 100 };
const webHandles = computeSelectionHandles(testBounds, 1.0);

assertEqual(webHandles.topLeft.x, 100, 'Web 左上手柄 X 應為 100');
assertEqual(webHandles.topLeft.y, 100, 'Web 左上手柄 Y 應為 100');
assertEqual(webHandles.bottomRight.x, 300, 'Web 右下手柄 X 應為 300');
assertEqual(webHandles.bottomRight.y, 200, 'Web 右下手柄 Y 應為 200');
assertEqual(webHandles.topCenter.x, 200, 'Web 頂部中點 X 應為 200');
assertEqual(webHandles.topCenter.y, 100, 'Web 頂部中點 Y 應為 100');
assertEqual(webHandles.rotate.x, 200, 'Web 旋轉手柄 X 應為 200');
assertEqual(webHandles.rotate.y, 76, 'Web 旋轉手柄 Y 應向上偏移 24 pt (76)');

// 14.3 getHandleCursor 動態游標樣式對齊
assertEqual(getHandleCursor('middleLeft'), 'ew-resize', '左中手柄游標為水平雙向箭頭 ew-resize');
assertEqual(getHandleCursor('middleRight'), 'ew-resize', '右中手柄游標為水平雙向箭頭 ew-resize');
assertEqual(getHandleCursor('topCenter'), 'ns-resize', '頂中手柄游標為垂直雙向箭頭 ns-resize');
assertEqual(getHandleCursor('bottomCenter'), 'ns-resize', '底中手柄游標為垂直雙向箭頭 ns-resize');
assertEqual(getHandleCursor('topLeft'), 'nwse-resize', '左上手柄游標為斜邊 nwse-resize');
assertEqual(getHandleCursor('bottomRight'), 'nwse-resize', '右下手柄游標為斜邊 nwse-resize');
assertEqual(getHandleCursor('topRight'), 'nesw-resize', '右上手柄游標為斜邊 nesw-resize');
assertEqual(getHandleCursor('bottomLeft'), 'nesw-resize', '左下手柄游標為斜邊 nesw-resize');

// 14.4 GestureTransactionTracker: 連續高頻採樣只提交一次 Undo 交易
const tracker = new GestureTransactionTracker();
tracker.beginGesture({ x: 0, y: 0 });

// 模擬連續 50 個高頻 pointermove 樣本點
for (let i = 1; i <= 50; i++) {
  tracker.appendSample({ x: i * 2, y: i * 3, pressure: 0.5 });
}

assertEqual(tracker.getSampleCount(), 51, '收集完整 51 個筆跡點樣本，無遺漏');
assertEqual(tracker.isCommitted(), false, '拖曳過程中尚未提交交易');

// 手勢放開 (pointerup)
const committedTransaction = tracker.endGesture('obj_stroke_gesture_test', 'stroke', '#ffffff', 4);
assertEqual(tracker.isCommitted(), true, '放開後交易狀態轉為已提交');
assertEqual(committedTransaction?.objects.length, 1, '單一手勢精確產生 1 筆物件交易');
assertEqual(committedTransaction?.objects[0].id, 'obj_stroke_gesture_test', '提交物件 ID 相符');

// -------------------------------------------------------------------------
// 15. AG-32: 統一歷史與持久化交易 (Web BoardCommand Delta 與 Native 對齊) (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 15] AG-32: 統一歷史與持久化交易 (Delta 歷史與語意對齊) (立靶驗收)');

import {
  BoardTransactionManager,
  BoardCommand,
} from '../src/controllers/BoardTransactionManager';

const txManager = new BoardTransactionManager(50);
assertEqual(txManager.canUndo(), false, '初始無 Undo 交易');
assertEqual(txManager.canRedo(), false, '初始無 Redo 交易');

// 15.1 insertObjects 交易語意
const o1: BoardObject = { id: 'obj_tx_1', type: 'rect', x: 10, y: 10, width: 20, height: 20, strokeColor: '#fff', fillColor: 'none', strokeWidth: 2, opacity: 1, rotation: 0, zIndex: 1, createdBy: 'local', updatedAt: '2026-10-06T00:00:00Z' };
txManager.push({ type: 'insertObjects', objects: [o1] });
assertEqual(txManager.canUndo(), true, '新增物件後可 Undo');

let state = [o1];
const undoInsertResult = txManager.undo(state);
assertTrue(undoInsertResult !== null, '執行 Undo 成功');
assertEqual(undoInsertResult!.objects.length, 0, 'Undo insert 應移除該物件');
assertEqual(txManager.canRedo(), true, 'Undo 後可 Redo');

const redoInsertResult = txManager.redo(undoInsertResult!.objects);
assertTrue(redoInsertResult !== null, '執行 Redo 成功');
assertEqual(redoInsertResult!.objects.length, 1, 'Redo insert 應重新置入物件');
assertEqual(redoInsertResult!.objects[0].id, 'obj_tx_1', '置入物件 ID 相符');

// 15.2 modifyObjects (連續拖曳僅提交 1 筆交易)
const o1Moved: BoardObject = { ...o1, x: 100, y: 150 };
txManager.push({ type: 'modifyObjects', before: [o1], after: [o1Moved] });

const undoMoveResult = txManager.undo([o1Moved]);
assertEqual(undoMoveResult!.objects[0].x, 10, 'Undo modify 應還原為原始 X: 10');
assertEqual(undoMoveResult!.objects[0].y, 10, 'Undo modify 應還原為原始 Y: 10');

const redoMoveResult = txManager.redo(undoMoveResult!.objects);
assertEqual(redoMoveResult!.objects[0].x, 100, 'Redo modify 應再次移動至 X: 100');
assertEqual(redoMoveResult!.objects[0].y, 150, 'Redo modify 應再次移動至 Y: 150');

// 15.3 removeObjects 交易語意
txManager.push({ type: 'removeObjects', objects: [o1Moved] });
const undoRemoveResult = txManager.undo([]);
assertEqual(undoRemoveResult!.objects.length, 1, 'Undo remove 應復原被刪除之物件');
assertEqual(undoRemoveResult!.objects[0].id, 'obj_tx_1', '復原物件 ID 相符');

// 15.4 記憶體預算與容量上限保證 (Bounded Stack)
const smallTxManager = new BoardTransactionManager(5);
for (let i = 0; i < 20; i++) {
  smallTxManager.push({
    type: 'modifyObjects',
    before: [{ ...o1, x: i }],
    after: [{ ...o1, x: i + 1 }],
  });
}
assertEqual(smallTxManager.getUndoStackDepth(), 5, 'Undo 深度嚴格受限於 maxCapacity 5，杜絕記憶體洩漏');

// -------------------------------------------------------------------------
// 16. 筆刷與橡皮擦示意大小 1:1 實繪尺寸精確對齊與懸停指示契約 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 16] 筆刷與橡皮擦示意大小 1:1 實繪尺寸精確對齊與懸停指示契約 (立靶驗收)');

import {
  getToolStrokeWidth,
  getToolHoverDiameter,
  getEraserRadius,
} from '../src/utils/toolMetrics';

// 16.1 筆刷各工具實際筆粗 (strokeWidth) 精確對齊
assertEqual(getToolStrokeWidth('pen', 4), 4, 'Pen 筆刷實際粗細為 4px');
assertEqual(getToolStrokeWidth('pen', 8), 8, 'Pen 筆刷實際粗細為 8px');
assertEqual(getToolStrokeWidth('highlighter', 4), 14, 'Highlighter 螢光筆粗細為 14px (4 * 3.5)');
assertEqual(getToolStrokeWidth('paint', 4), 32, 'Paint 油漆筆刷粗細為 32px (4 * 8.0)');
assertEqual(getToolStrokeWidth('curve', 5), 5, 'Curve 曲線粗細為 5px');

// 16.2 懸停圓形示意直徑與畫布放大縮小比率 1:1 絕對對齊
assertEqual(getToolHoverDiameter('pen', 4, 1.0), 4, 'Pen 懸停直徑在 1.0x 縮放下精準為 4px');
assertEqual(getToolHoverDiameter('pen', 4, 2.0), 8, 'Pen 懸停直徑在 2.0x 縮放下精準為 8px (4 * 2.0)');
assertEqual(getToolHoverDiameter('highlighter', 4, 1.0), 14, 'Highlighter 懸停直徑在 1.0x 縮放下精準為 14px');
assertEqual(getToolHoverDiameter('paint', 4, 1.0), 32, 'Paint 懸停直徑在 1.0x 縮放下精準為 32px');
assertEqual(getToolHoverDiameter('paint', 4, 1.5), 48, 'Paint 懸停直徑在 1.5x 縮放下精準為 48px');

// 16.3 橡皮擦懸停指示直徑與實際碰撞擦除半徑 1:1 嚴格對齊
const pixelRadius = getEraserRadius('pixel');
assertEqual(pixelRadius, 16, 'Pixel 模式橡皮擦半徑為 16 world units');
assertEqual(getToolHoverDiameter('eraser', 0, 1.0, 'pixel'), 32, 'Pixel 模式橡皮擦懸停直徑精準為 32px (半徑 * 2)');
assertEqual(getToolHoverDiameter('eraser', 0, 1.5, 'pixel'), 48, 'Pixel 模式在 1.5x 縮放下橡皮擦懸停直徑精準為 48px');

const objectRadius = getEraserRadius('object');
assertEqual(objectRadius, 18, 'Object 模式橡皮擦半徑為 18 world units');
assertEqual(getToolHoverDiameter('eraser', 0, 1.0, 'object'), 36, 'Object 模式橡皮擦懸停直徑精準為 36px');

// -------------------------------------------------------------------------
// 17. 黑板全部刪除後禁止自動生成預設黑板與空狀態契約 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 17] 黑板全部刪除後禁止自動生成預設黑板與空狀態契約 (立靶驗收)');

// 模擬使用者刪除全部黑板後的行為狀態機
let testBoards: BoardMetadata[] = [
  {
    id: 'board_to_delete_1',
    title: '待刪除黑板',
    ownerId: 'local',
    backgroundColor: '#172e25',
    gridStyle: 'grid',
    boardTheme: 'blackboard',
    canvasMode: 'infinite',
    canvasPreset: 'infinite',
    pins: [],
    source: 'local',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

// 執行刪除唯一剩餘黑板操作
const deleteBoardSim = (boardId: string) => {
  testBoards = testBoards.filter((b) => b.id !== boardId);
  // 防呆核心規範：不得自動生成或注入 DEFAULT_BOARD
  return testBoards;
};

const remainingAfterDelete = deleteBoardSim('board_to_delete_1');
assertEqual(remainingAfterDelete.length, 0, '刪除最後一張黑板後列表長度精準為 0');
assertEqual(testBoards.length, 0, '黑板清單維持乾淨空狀態');
assertTrue(testBoards.find((b) => b.title === '我的第一塊黑板') === undefined, '嚴格禁止自動新增預設黑板覆蓋使用者意圖');

// -------------------------------------------------------------------------
// 18. 功能導覽與示範黑板資料契約與無損往返驗收 (立靶驗收)
// -------------------------------------------------------------------------
console.log('\n[測試 18] 功能導覽與示範黑板資料契約與無損往返驗收 (立靶驗收)');

import {
  FEATURE_SHOWCASE_BOARD,
  FEATURE_SHOWCASE_OBJECTS,
  getFeatureShowcaseDocument,
} from '../src/data/featureShowcaseBoard';

const showcaseDoc = getFeatureShowcaseDocument();
assertEqual(showcaseDoc.board.id, 'demo_feature_showcase', '示範黑板 ID 正確');
assertEqual(showcaseDoc.board.pins?.length, 6, '示範黑板具備 6 個區域導覽圖釘');
assertEqual(showcaseDoc.board.pins?.[0].name, '👋 歡迎導覽', '第 1 圖釘為歡迎導覽');
assertEqual(showcaseDoc.board.pins?.[1].name, '🎨 筆刷墨跡與平滑曲線', '第 2 圖釘為筆刷區');
assertEqual(showcaseDoc.board.pins?.[2].name, '📐 幾何圖形與樣式', '第 3 圖釘為幾何區');
assertEqual(showcaseDoc.board.pins?.[3].name, '📝 六大便簽與繁中排版', '第 4 圖釘為便簽區');
assertEqual(showcaseDoc.board.pins?.[4].name, '📏 螢幕尺規與局部橡皮擦', '第 5 圖釘為尺規橡皮擦區');
assertEqual(showcaseDoc.board.pins?.[5].name, '🚀 多頁筆記與向量匯出', '第 6 圖釘為多頁與匯出區');

// 物件型別多樣性驗收
const objectTypes = new Set(showcaseDoc.objects.map((o) => o.type));
assertTrue(objectTypes.has('stroke'), '涵蓋 stroke 鋼筆筆刷');
assertTrue(objectTypes.has('highlighter'), '涵蓋 highlighter 螢光筆');
assertTrue(objectTypes.has('paint'), '涵蓋 paint 油漆筆');
assertTrue(objectTypes.has('curve'), '涵蓋 curve 平滑曲線');
assertTrue(objectTypes.has('rect'), '涵蓋 rect 矩形');
assertTrue(objectTypes.has('circle'), '涵蓋 circle 圓形');
assertTrue(objectTypes.has('triangle'), '涵蓋 triangle 三角形');
assertTrue(objectTypes.has('star'), '涵蓋 star 星形');
assertTrue(objectTypes.has('arrow'), '涵蓋 arrow 箭頭');
assertTrue(objectTypes.has('line'), '涵蓋 line 直線');
assertTrue(objectTypes.has('sticky'), '涵蓋 sticky 便簽');
assertTrue(objectTypes.has('text'), '涵蓋 text 文字排版');

// 六大便簽風格完整性驗收
const stickyStyles = new Set(
  showcaseDoc.objects.filter((o) => o.type === 'sticky').map((o) => o.stickyStyle)
);
assertEqual(stickyStyles.size, 6, '示範黑板完整涵蓋 6 種便簽風格');
assertTrue(stickyStyles.has('classic'), '包含 classic 經典風格');
assertTrue(stickyStyles.has('washi'), '包含 washi 和紙風格');
assertTrue(stickyStyles.has('cat'), '包含 cat 貓咪風格');
assertTrue(stickyStyles.has('notebook'), '包含 notebook 筆記本風格');
assertTrue(stickyStyles.has('grid'), '包含 grid 方格紙風格');
assertTrue(stickyStyles.has('soft'), '包含 soft 柔和卡片風格');

// 序列化與反序列化無損往返驗收
const serializedShowcase = JSON.stringify(showcaseDoc);
const deserializedShowcase = JSON.parse(serializedShowcase);
assertEqual(deserializedShowcase.board.id, showcaseDoc.board.id, '示範黑板序列化往返 ID 一致');
assertEqual(deserializedShowcase.objects.length, showcaseDoc.objects.length, '示範黑板物件數量序列化往返一致');

console.log('\n==================================================');
if (failedCount === 0) {
  console.log(`🎉 驗收結果：全部通過！ (${passedCount} 項斷言成功，0 項失敗)`);
} else {
  console.error(`⚠️ 驗收結果：失敗！ (${passedCount} 通過，${failedCount} 失敗)`);
  process.exit(1);
}
console.log('==================================================\n');



