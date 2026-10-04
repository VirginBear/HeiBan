import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { performance } from 'perf_hooks';
import { HeiBanDocument, Point } from '../src/types';
import { pointsToSvgPath } from '../src/utils/vector';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const fixturesDir = path.resolve(__dirname, '../tests/fixtures');

function loadJson(name: string): string {
  const p = path.join(fixturesDir, name);
  return fs.readFileSync(p, 'utf-8');
}

function stats(values: number[]) {
  const sorted = [...values].sort((a, b) => a - b);
  const sum = sorted.reduce((acc, v) => acc + v, 0);
  const avg = sum / sorted.length;
  const p50 = sorted[Math.floor(sorted.length * 0.5)];
  const p95 = sorted[Math.floor(sorted.length * 0.95)];
  return { min: sorted[0], max: sorted[sorted.length - 1], avg, p50, p95 };
}

console.log('================================================================================');
console.log('⚡ HeiBan Web Benchmark Harness (F01 / F02 / F03 - 5 Rounds Profile)');
console.log('================================================================================\n');

const rawF01 = loadJson('f01_daily_1k.json');
const rawF02 = loadJson('f02_long_stroke_10k.json');
const rawF03 = loadJson('f03_stress_10k.json');

// --- Benchmark 1: F01 (1,000 objects) JSON Parse & SVG Path Generation ---
const f01ParseTimes: number[] = [];
const f01PathTimes: number[] = [];

for (let r = 1; r <= 5; r++) {
  const t0 = performance.now();
  const doc = JSON.parse(rawF01) as HeiBanDocument;
  const t1 = performance.now();
  f01ParseTimes.push(t1 - t0);

  const t2 = performance.now();
  let strokeCount = 0;
  for (const obj of doc.objects) {
    if (obj.points) {
      try {
        const pts: Point[] = JSON.parse(obj.points);
        const _svg = pointsToSvgPath(pts);
        strokeCount++;
      } catch {
        // ignore
      }
    }
  }
  const t3 = performance.now();
  f01PathTimes.push(t3 - t2);
}

// --- Benchmark 2: F02 (10,000 points long stroke) Processing ---
const f02ParseTimes: number[] = [];
const f02PathTimes: number[] = [];

for (let r = 1; r <= 5; r++) {
  const t0 = performance.now();
  const doc = JSON.parse(rawF02) as HeiBanDocument;
  const t1 = performance.now();
  f02ParseTimes.push(t1 - t0);

  const t2 = performance.now();
  const longObj = doc.objects.find((o) => o.id === 'f02_stroke_10k_points');
  if (longObj && longObj.points) {
    const pts: Point[] = JSON.parse(longObj.points);
    const _svg = pointsToSvgPath(pts);
  }
  const t3 = performance.now();
  f02PathTimes.push(t3 - t2);
}

// --- Benchmark 3: F03 (10,000 objects) Stress Load ---
const f03ParseTimes: number[] = [];

for (let r = 1; r <= 5; r++) {
  const t0 = performance.now();
  const doc = JSON.parse(rawF03) as HeiBanDocument;
  const t1 = performance.now();
  f03ParseTimes.push(t1 - t0);
}

const sF01Parse = stats(f01ParseTimes);
const sF01Path = stats(f01PathTimes);
const sF02Parse = stats(f02ParseTimes);
const sF02Path = stats(f02PathTimes);
const sF03Parse = stats(f03ParseTimes);

console.log('| 測試項目 | R1 (ms) | R2 (ms) | R3 (ms) | R4 (ms) | R5 (ms) | p50 (中位數) | p95 (ms) |');
console.log('|---|---|---|---|---|---|---|---|');
console.log(`| F01 (1k) JSON Parse | ${f01ParseTimes.map((v) => v.toFixed(2)).join(' | ')} | ${sF01Parse.p50.toFixed(2)} | ${sF01Parse.p95.toFixed(2)} |`);
console.log(`| F01 (1k) 500筆跡 SVG重建 | ${f01PathTimes.map((v) => v.toFixed(2)).join(' | ')} | ${sF01Path.p50.toFixed(2)} | ${sF01Path.p95.toFixed(2)} |`);
console.log(`| F02 10k點長筆跡 Parse | ${f02ParseTimes.map((v) => v.toFixed(2)).join(' | ')} | ${sF02Parse.p50.toFixed(2)} | ${sF02Parse.p95.toFixed(2)} |`);
console.log(`| F02 10k點長筆跡 SVG重建 | ${f02PathTimes.map((v) => v.toFixed(2)).join(' | ')} | ${sF02Path.p50.toFixed(2)} | ${sF02Path.p95.toFixed(2)} |`);
console.log(`| F03 (10k) 壓力板 Parse | ${f03ParseTimes.map((v) => v.toFixed(2)).join(' | ')} | ${sF03Parse.p50.toFixed(2)} | ${sF03Parse.p95.toFixed(2)} |`);

const mem = process.memoryUsage();
console.log(`\nNode.js 記憶體使用: RSS ${(mem.rss / 1024 / 1024).toFixed(1)} MB, Heap Used ${(mem.heapUsed / 1024 / 1024).toFixed(1)} MB`);
console.log('================================================================================');
