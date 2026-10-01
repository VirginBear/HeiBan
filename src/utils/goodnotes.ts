import { Point, BoardObject } from '../types';

export interface RecognizedShape {
  type: 'line' | 'circle' | 'rect';
  x: number;
  y: number;
  width: number;
  height: number;
  points?: Point[];
}

/**
 * Recognizes if a stroke represents a geometric shape when held for ~0.8s
 */
export function recognizeGoodnotesShape(points: Point[]): RecognizedShape | null {
  if (!points || points.length < 5) return null;

  const start = points[0];
  const end = points[points.length - 1];

  // 1. Calculate path length and straight line distance
  let totalPathLength = 0;
  for (let i = 0; i < points.length - 1; i++) {
    totalPathLength += Math.hypot(points[i + 1].x - points[i].x, points[i + 1].y - points[i].y);
  }

  const straightDist = Math.hypot(end.x - start.x, end.y - start.y);

  // --- Line Recognition ---
  // If straight distance is at least 84% of total traveled path, it's a straight line
  if (straightDist > 30 && straightDist / totalPathLength > 0.84) {
    return {
      type: 'line',
      x: Math.round(start.x),
      y: Math.round(start.y),
      width: Math.round(end.x - start.x),
      height: Math.round(end.y - start.y),
    };
  }

  // Calculate bounding box and centroid
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  let sumX = 0;
  let sumY = 0;

  for (const p of points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
    sumX += p.x;
    sumY += p.y;
  }

  const width = Math.max(20, maxX - minX);
  const height = Math.max(20, maxY - minY);
  const cx = sumX / points.length;
  const cy = sumY / points.length;

  const startEndGap = Math.hypot(end.x - start.x, end.y - start.y);
  const maxDim = Math.max(width, height);

  // --- Circle / Ellipse Recognition ---
  // If loop is relatively closed (gap < 40% of max dimension) and has reasonable area
  if (startEndGap < maxDim * 0.45 && width > 25 && height > 25) {
    // Check radius consistency from centroid
    let radialVariance = 0;
    const avgR = (width + height) / 4;
    for (const p of points) {
      const dist = Math.hypot(p.x - cx, p.y - cy);
      radialVariance += Math.abs(dist - avgR);
    }
    const avgVariance = radialVariance / points.length;

    if (avgVariance / avgR < 0.42) {
      return {
        type: 'circle',
        x: Math.round(minX),
        y: Math.round(minY),
        width: Math.round(width),
        height: Math.round(height),
      };
    }

    // Otherwise check if it looks like a rectangle
    return {
      type: 'rect',
      x: Math.round(minX),
      y: Math.round(minY),
      width: Math.round(width),
      height: Math.round(height),
    };
  }

  return null;
}
