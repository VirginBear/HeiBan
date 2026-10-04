import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import { BoardObject, BoardMetadata, HeiBanDocument, Point } from '../src/types';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const fixturesDir = path.resolve(__dirname, '../tests/fixtures');

if (!fs.existsSync(fixturesDir)) {
  fs.mkdirSync(fixturesDir, { recursive: true });
}

// Pseudo-random number generator with deterministic seed (Linear Congruential Generator)
class DeterministicPRNG {
  private state: number;
  constructor(seed = 42) {
    this.state = seed;
  }
  next(): number {
    this.state = (this.state * 1664525 + 1013904223) % 4294967296;
    return this.state / 4294967296;
  }
  range(min: number, max: number): number {
    return min + this.next() * (max - min);
  }
}

// Generate F01: Daily 1,000 objects
function generateF01(): HeiBanDocument {
  const rng = new DeterministicPRNG(1001);
  const objects: BoardObject[] = [];

  // 1. 500 strokes with 100 points each
  for (let i = 0; i < 500; i++) {
    const originX = rng.range(-2000, 2000);
    const originY = rng.range(-2000, 2000);
    const points: Point[] = [];
    let curX = originX;
    let curY = originY;
    for (let p = 0; p < 100; p++) {
      curX += rng.range(-8, 8);
      curY += rng.range(-8, 8);
      points.push({
        x: Math.round(curX * 100) / 100,
        y: Math.round(curY * 100) / 100,
        pressure: Math.round(rng.range(0.3, 0.9) * 100) / 100,
      });
    }
    objects.push({
      id: `f01_stroke_${i}`,
      boardId: 'board_f01',
      type: 'stroke',
      x: originX,
      y: originY,
      width: Math.abs(curX - originX) + 10,
      height: Math.abs(curY - originY) + 10,
      points: JSON.stringify(points),
      strokeColor: i % 2 === 0 ? '#86efac' : '#fef08a',
      fillColor: 'none',
      strokeWidth: rng.range(2, 6),
      opacity: 1,
      rotation: 0,
      zIndex: i + 1,
      createdBy: 'f01_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 2. 300 shapes & lines
  const shapes: Array<'rect' | 'circle' | 'triangle' | 'diamond' | 'star' | 'line' | 'arrow'> = [
    'rect',
    'circle',
    'triangle',
    'diamond',
    'star',
    'line',
    'arrow',
  ];
  for (let i = 0; i < 300; i++) {
    const type = shapes[i % shapes.length];
    const x = rng.range(-2500, 2500);
    const y = rng.range(-2500, 2500);
    const w = rng.range(60, 240);
    const h = rng.range(60, 240);
    objects.push({
      id: `f01_shape_${i}`,
      boardId: 'board_f01',
      type,
      x,
      y,
      width: w,
      height: h,
      x1: type === 'line' || type === 'arrow' ? x : undefined,
      y1: type === 'line' || type === 'arrow' ? y : undefined,
      x2: type === 'line' || type === 'arrow' ? x + w : undefined,
      y2: type === 'line' || type === 'arrow' ? y + h : undefined,
      extension: type === 'line' || type === 'arrow' ? 'none' : undefined,
      strokeColor: '#38bdf8',
      fillColor: type === 'rect' || type === 'circle' ? '#38bdf822' : 'none',
      strokeWidth: 3,
      opacity: 0.9,
      rotation: rng.range(0, 45),
      zIndex: 500 + i + 1,
      createdBy: 'f01_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 3. 100 text objects
  for (let i = 0; i < 100; i++) {
    objects.push({
      id: `f01_text_${i}`,
      boardId: 'board_f01',
      type: 'text',
      x: rng.range(-2000, 2000),
      y: rng.range(-2000, 2000),
      width: 180,
      height: 40,
      text: `日常黑板筆記標記 #${i + 1}`,
      fontSize: 20,
      strokeColor: '#ffffff',
      fillColor: 'none',
      strokeWidth: 1,
      opacity: 1,
      rotation: 0,
      zIndex: 800 + i + 1,
      createdBy: 'f01_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 4. 98 sticky notes
  for (let i = 0; i < 98; i++) {
    objects.push({
      id: `f01_sticky_${i}`,
      boardId: 'board_f01',
      type: 'sticky',
      x: rng.range(-2000, 2000),
      y: rng.range(-2000, 2000),
      width: 160,
      height: 160,
      stickyStyle: 'classic',
      text: `待辦事項便簽 #${i + 1}\n- 討論項目\n- 執行追蹤`,
      fontSize: 16,
      strokeColor: '#1f2937',
      fillColor: '#fef08a',
      strokeWidth: 1,
      opacity: 1,
      rotation: rng.range(-5, 5),
      zIndex: 900 + i + 1,
      createdBy: 'f01_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 5. 2 PNG images (3840x2160)
  for (let i = 0; i < 2; i++) {
    objects.push({
      id: `f01_image_${i}`,
      boardId: 'board_f01',
      type: 'image',
      x: i === 0 ? -1000 : 500,
      y: -500,
      width: 960,
      height: 540,
      imageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      originalImageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      originalWidth: 3840,
      originalHeight: 2160,
      strokeColor: 'none',
      fillColor: 'none',
      strokeWidth: 0,
      opacity: 1,
      rotation: 0,
      zIndex: 998 + i + 1,
      createdBy: 'f01_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  const board: BoardMetadata = {
    id: 'board_f01',
    title: 'F01 日常混合板 (1,000 物件基準)',
    ownerId: 'perf_tester',
    ownerName: '效能量測員',
    backgroundColor: '#172e25',
    gridStyle: 'grid',
    boardTheme: 'blackboard',
    canvasMode: 'infinite',
    itemCount: objects.length,
    pins: [
      { id: 'pin_f01_center', name: '中心視角', x: 0, y: 0, zoom: 1, createdAt: '2026-10-02T00:00:00.000Z' },
    ],
    createdAt: '2026-10-02T00:00:00.000Z',
    updatedAt: '2026-10-02T00:00:00.000Z',
  };

  return {
    schemaVersion: '1.0.0',
    version: '1.0',
    board,
    objects,
    exportedAt: '2026-10-02T00:00:00.000Z',
  };
}

// Generate F02: Long stroke (10,000 points fixed trajectory + 10 mixed multi-segment strokes)
function generateF02(): HeiBanDocument {
  const rng = new DeterministicPRNG(2002);
  const objects: BoardObject[] = [];

  // 1. Fixed 10,000-point long trajectory (S-curves, spirals, reversals)
  const trajectoryPoints: Point[] = [];
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < 10000; i++) {
    const angle = i * 0.05;
    const radius = 50 + (i % 500) * 0.8;
    cx = Math.sin(angle) * radius + (i * 0.2);
    cy = Math.cos(angle * 1.3) * radius;
    trajectoryPoints.push({
      x: Math.round(cx * 100) / 100,
      y: Math.round(cy * 100) / 100,
      pressure: 0.5 + 0.3 * Math.sin(i * 0.1),
    });
  }

  objects.push({
    id: 'f02_stroke_10k_points',
    boardId: 'board_f02',
    type: 'stroke',
    x: 0,
    y: 0,
    width: 2500,
    height: 1200,
    points: JSON.stringify(trajectoryPoints),
    strokeColor: '#f43f5e',
    fillColor: 'none',
    strokeWidth: 4,
    opacity: 1,
    rotation: 0,
    zIndex: 1,
    createdBy: 'f02_generator',
    updatedAt: '2026-10-02T00:00:00.000Z',
  });

  // 2. 10 continuous multi-segment strokes (each 500 points)
  for (let s = 0; s < 10; s++) {
    const sPoints: Point[] = [];
    let px = (s - 5) * 200;
    let py = 1500;
    for (let p = 0; p < 500; p++) {
      px += rng.range(-6, 6);
      py += rng.range(-6, 6);
      sPoints.push({
        x: Math.round(px * 100) / 100,
        y: Math.round(py * 100) / 100,
        pressure: 0.6,
      });
    }
    objects.push({
      id: `f02_stroke_extra_${s}`,
      boardId: 'board_f02',
      type: 'stroke',
      x: px,
      y: py,
      width: 400,
      height: 400,
      points: JSON.stringify(sPoints),
      strokeColor: '#a855f7',
      fillColor: 'none',
      strokeWidth: 3,
      opacity: 0.8,
      rotation: 0,
      zIndex: s + 2,
      createdBy: 'f02_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  const board: BoardMetadata = {
    id: 'board_f02',
    title: 'F02 長筆跡板 (10,000 點固定軌跡與累積延遲量測)',
    ownerId: 'perf_tester',
    ownerName: '效能量測員',
    backgroundColor: '#172e25',
    gridStyle: 'lines',
    boardTheme: 'blackboard',
    canvasMode: 'infinite',
    itemCount: objects.length,
    pins: [{ id: 'pin_f02_start', name: '軌跡起點', x: 0, y: 0, zoom: 1, createdAt: '2026-10-02T00:00:00.000Z' }],
    createdAt: '2026-10-02T00:00:00.000Z',
    updatedAt: '2026-10-02T00:00:00.000Z',
  };

  return {
    schemaVersion: '1.0.0',
    version: '1.0',
    board,
    objects,
    exportedAt: '2026-10-02T00:00:00.000Z',
  };
}

// Generate F03: Stress 10,000 objects + 8 high-res PNG placeholders
function generateF03(): HeiBanDocument {
  const rng = new DeterministicPRNG(3003);
  const objects: BoardObject[] = [];

  // 1. 5,000 strokes with 50 points each
  for (let i = 0; i < 5000; i++) {
    const originX = rng.range(-10000, 10000);
    const originY = rng.range(-10000, 10000);
    const points: Point[] = [];
    let curX = originX;
    let curY = originY;
    for (let p = 0; p < 50; p++) {
      curX += rng.range(-10, 10);
      curY += rng.range(-10, 10);
      points.push({
        x: Math.round(curX * 10) / 10,
        y: Math.round(curY * 10) / 10,
      });
    }
    objects.push({
      id: `f03_stroke_${i}`,
      boardId: 'board_f03',
      type: 'stroke',
      x: originX,
      y: originY,
      width: Math.abs(curX - originX) + 10,
      height: Math.abs(curY - originY) + 10,
      points: JSON.stringify(points),
      strokeColor: '#86efac',
      fillColor: 'none',
      strokeWidth: 3,
      opacity: 1,
      rotation: 0,
      zIndex: i + 1,
      createdBy: 'f03_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 2. 3,000 shapes/lines
  for (let i = 0; i < 3000; i++) {
    const x = rng.range(-12000, 12000);
    const y = rng.range(-12000, 12000);
    objects.push({
      id: `f03_shape_${i}`,
      boardId: 'board_f03',
      type: i % 2 === 0 ? 'rect' : 'circle',
      x,
      y,
      width: rng.range(50, 200),
      height: rng.range(50, 200),
      strokeColor: '#38bdf8',
      fillColor: 'none',
      strokeWidth: 2,
      opacity: 0.9,
      rotation: 0,
      zIndex: 5000 + i + 1,
      createdBy: 'f03_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 3. 1,000 text objects
  for (let i = 0; i < 1000; i++) {
    objects.push({
      id: `f03_text_${i}`,
      boardId: 'board_f03',
      type: 'text',
      x: rng.range(-10000, 10000),
      y: rng.range(-10000, 10000),
      width: 150,
      height: 30,
      text: `壓力標記 ${i}`,
      fontSize: 18,
      strokeColor: '#ffffff',
      fillColor: 'none',
      strokeWidth: 1,
      opacity: 1,
      rotation: 0,
      zIndex: 8000 + i + 1,
      createdBy: 'f03_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 4. 992 sticky notes
  for (let i = 0; i < 992; i++) {
    objects.push({
      id: `f03_sticky_${i}`,
      boardId: 'board_f03',
      type: 'sticky',
      x: rng.range(-10000, 10000),
      y: rng.range(-10000, 10000),
      width: 120,
      height: 120,
      text: `壓測便箋 ${i}`,
      fontSize: 14,
      strokeColor: '#1f2937',
      fillColor: '#fef08a',
      strokeWidth: 1,
      opacity: 1,
      rotation: 0,
      zIndex: 9000 + i + 1,
      createdBy: 'f03_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  // 5. 8 PNG image placeholders (3840x2160)
  for (let i = 0; i < 8; i++) {
    objects.push({
      id: `f03_image_${i}`,
      boardId: 'board_f03',
      type: 'image',
      x: -4000 + i * 1000,
      y: -3000,
      width: 800,
      height: 450,
      imageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      originalImageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      originalWidth: 3840,
      originalHeight: 2160,
      strokeColor: 'none',
      fillColor: 'none',
      strokeWidth: 0,
      opacity: 1,
      rotation: 0,
      zIndex: 9992 + i + 1,
      createdBy: 'f03_generator',
      updatedAt: '2026-10-02T00:00:00.000Z',
    });
  }

  const board: BoardMetadata = {
    id: 'board_f03',
    title: 'F03 壓力板 (10,000 物件與大範圍空間索引)',
    ownerId: 'perf_tester',
    ownerName: '效能量測員',
    backgroundColor: '#172e25',
    gridStyle: 'grid',
    boardTheme: 'blackboard',
    canvasMode: 'infinite',
    itemCount: objects.length,
    pins: [
      { id: 'pin_f03_origin', name: '原點', x: 0, y: 0, zoom: 1, createdAt: '2026-10-02T00:00:00.000Z' },
    ],
    createdAt: '2026-10-02T00:00:00.000Z',
    updatedAt: '2026-10-02T00:00:00.000Z',
  };

  return {
    schemaVersion: '1.0.0',
    version: '1.0',
    board,
    objects,
    exportedAt: '2026-10-02T00:00:00.000Z',
  };
}

function writeFixture(filename: string, doc: HeiBanDocument) {
  const filePath = path.join(fixturesDir, filename);
  const json = JSON.stringify(doc, null, 2);
  fs.writeFileSync(filePath, json, 'utf-8');
  const hash = crypto.createHash('sha256').update(json).digest('hex');
  const sizeKb = (Buffer.byteLength(json, 'utf-8') / 1024).toFixed(1);
  console.log(`✓ 產出 ${filename} (${doc.objects.length} 物件, ${sizeKb} KB, SHA-256: ${hash.slice(0, 16)}...)`);
}

console.log('🚀 開始產生固定驗收 Fixtures (F01, F02, F03)...');
writeFixture('f01_daily_1k.json', generateF01());
writeFixture('f02_long_stroke_10k.json', generateF02());
writeFixture('f03_stress_10k.json', generateF03());
console.log('🎉 所有固定 Fixtures 產出完成！');
