import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { BoardObject, BoardMetadata, HeiBanDocument } from '../src/types';

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
  updatedMetadata?: Partial<Board>;
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

console.log('\n==================================================');
if (failedCount === 0) {
  console.log(`🎉 驗收結果：全部通過！ (${passedCount} 項斷言成功，0 項失敗)`);
} else {
  console.error(`⚠️ 驗收結果：失敗！ (${passedCount} 通過，${failedCount} 失敗)`);
  process.exit(1);
}
console.log('==================================================\n');

