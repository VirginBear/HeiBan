import { Point, BoardObject, RulerState, LineExtension } from '../types';

/**
 * Convert sampled points into a Catmull–Rom-derived cubic Bézier path.
 * The old midpoint quadratic approximation cut corners and could look creased
 * when pointer samples were sparse; these control points keep the curve tangent
 * continuous while passing through each captured sample.
 */
export function pointsToSvgPath(points: Point[]): string {
  if (!points || points.length === 0) return '';
  if (points.length === 1) {
    return `M ${points[0].x} ${points[0].y} L ${points[0].x + 0.1} ${points[0].y + 0.1}`;
  }
  if (points.length === 2) {
    return `M ${points[0].x} ${points[0].y} L ${points[1].x} ${points[1].y}`;
  }

  let d = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i++) {
    const previous = points[Math.max(0, i - 1)];
    const start = points[i];
    const end = points[i + 1];
    const next = points[Math.min(points.length - 1, i + 2)];
    const cp1x = start.x + (end.x - previous.x) / 6;
    const cp1y = start.y + (end.y - previous.y) / 6;
    const cp2x = end.x - (next.x - start.x) / 6;
    const cp2y = end.y - (next.y - start.y) / 6;
    d += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${end.x} ${end.y}`;
  }
  return d;
}

/**
 * Compute the bounding box of a list of points
 */
export function computeBoundingBox(points: Point[], strokeWidth: number = 2) {
  if (!points || points.length === 0) {
    return { minX: 0, minY: 0, maxX: 0, maxY: 0, width: 0, height: 0 };
  }
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;

  for (const p of points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }

  const pad = strokeWidth / 2;
  return {
    minX: minX - pad,
    minY: minY - pad,
    maxX: maxX + pad,
    maxY: maxY + pad,
    width: Math.max(1, maxX - minX + strokeWidth),
    height: Math.max(1, maxY - minY + strokeWidth),
  };
}

/**
 * Snap point to ruler straight edge WITH strict length limiter
 */
export function snapToScreenRulerEdge(
  screenPt: Point,
  ruler: RulerState,
  snapTolerance = 28
): { snapped: boolean; screenPt: Point } {
  if (!ruler.enabled) return { snapped: false, screenPt };

  const rad = (ruler.angle * Math.PI) / 180;
  const cos = Math.cos(-rad);
  const sin = Math.sin(-rad);

  // Transform point relative to ruler center
  const dx = screenPt.x - ruler.screenCenterX;
  const dy = screenPt.y - ruler.screenCenterY;
  const localX = dx * cos - dy * sin;
  const localY = dx * sin + dy * cos;

  const halfW = (ruler.width || 1200) / 2;
  const halfH = ruler.height / 2;

  // Strict limiter: drawing must be strictly within the ruler's physical length [-halfW, halfW]
  if (localX < -halfW - 10 || localX > halfW + 10) {
    return { snapped: false, screenPt };
  }

  // Check top straight edge (localY = -halfH)
  const distTop = Math.abs(localY - (-halfH));
  // Check bottom straight edge (localY = halfH)
  const distBottom = Math.abs(localY - halfH);

  const rCos = Math.cos(rad);
  const rSin = Math.sin(rad);

  // Clamp localX strictly to [-halfW, halfW] so stroke does NOT poke out beyond the ruler ends!
  const clampedLocalX = Math.max(-halfW, Math.min(halfW, localX));

  if (distTop < snapTolerance) {
    const snappedLocalY = -halfH;
    return {
      snapped: true,
      screenPt: {
        x: ruler.screenCenterX + clampedLocalX * rCos - snappedLocalY * rSin,
        y: ruler.screenCenterY + clampedLocalX * rSin + snappedLocalY * rCos,
        pressure: screenPt.pressure,
      },
    };
  }

  if (distBottom < snapTolerance) {
    const snappedLocalY = halfH;
    return {
      snapped: true,
      screenPt: {
        x: ruler.screenCenterX + clampedLocalX * rCos - snappedLocalY * rSin,
        y: ruler.screenCenterY + clampedLocalX * rSin + snappedLocalY * rCos,
        pressure: screenPt.pressure,
      },
    };
  }

  return { snapped: false, screenPt };
}

/**
 * Compute line or ray rendering coordinates based on extension mode
 */
export function computeLineRenderCoordinates(
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  extension: LineExtension = 'none'
): { rx1: number; ry1: number; rx2: number; ry2: number } {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len = Math.hypot(dx, dy);

  if (len === 0 || extension === 'none') {
    return { rx1: x1, ry1: y1, rx2: x2, ry2: y2 };
  }

  const uX = dx / len;
  const uY = dy / len;
  const extendDistance = 5000; // project far across canvas for ray/line

  let rx1 = x1;
  let ry1 = y1;
  let rx2 = x2;
  let ry2 = y2;

  if (extension === 'end' || extension === 'both') {
    rx2 = x2 + uX * extendDistance;
    ry2 = y2 + uY * extendDistance;
  }

  if (extension === 'start' || extension === 'both') {
    rx1 = x1 - uX * extendDistance;
    ry1 = y1 - uY * extendDistance;
  }

  return { rx1, ry1, rx2, ry2 };
}

/**
 * Check if a point hits an object
 */
export function isPointInObject(point: Point, obj: BoardObject, tolerance = 10): boolean {
  if (obj.isVisible === false) return false;

  if (obj.type === 'stroke' || obj.type === 'highlighter') {
    if (!obj.points) return false;
    try {
      const points: Point[] = JSON.parse(obj.points);
      const tol = (obj.strokeWidth / 2) + tolerance;
      for (let i = 0; i < points.length; i++) {
        const p = points[i];
        if (Math.hypot(p.x - point.x, p.y - point.y) <= tol) return true;
        if (i < points.length - 1) {
          if (distToSegment(point, p, points[i + 1]) <= tol) return true;
        }
      }
    } catch {
      return false;
    }
    return false;
  }

  // Exact A-B line checking
  if (obj.type === 'line' || obj.type === 'arrow') {
    const x1 = obj.x1 !== undefined ? obj.x1 : obj.x;
    const y1 = obj.y1 !== undefined ? obj.y1 : obj.y;
    const x2 = obj.x2 !== undefined ? obj.x2 : (obj.x + obj.width);
    const y2 = obj.y2 !== undefined ? obj.y2 : (obj.y + obj.height);
    const p1 = { x: x1, y: y1 };
    const p2 = { x: x2, y: y2 };
    return distToSegment(point, p1, p2) <= (obj.strokeWidth / 2 + tolerance);
  }

  // Rect, sticky note, image, text, shapes
  const minX = Math.min(obj.x, obj.x + obj.width) - tolerance;
  const maxX = Math.max(obj.x, obj.x + obj.width) + tolerance;
  const minY = Math.min(obj.y, obj.y + obj.height) - tolerance;
  const maxY = Math.max(obj.y, obj.y + obj.height) + tolerance;

  return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY;
}

function distToSegment(p: Point, v: Point, w: Point) {
  const l2 = (w.x - v.x) ** 2 + (w.y - v.y) ** 2;
  if (l2 === 0) return Math.hypot(p.x - v.x, p.y - v.y);
  let t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(p.x - (v.x + t * (w.x - v.x)), p.y - (v.y + t * (w.y - v.y)));
}

/**
 * Pixel Eraser: splits or removes points within eraser radius
 */
export function erasePointsAtPoint(
  points: Point[],
  eraserPoint: Point,
  radius: number
): Point[][] {
  const segments: Point[][] = [];
  let currentSegment: Point[] = [];

  for (const p of points) {
    const dist = Math.hypot(p.x - eraserPoint.x, p.y - eraserPoint.y);
    if (dist > radius) {
      currentSegment.push(p);
    } else {
      if (currentSegment.length > 1) {
        segments.push(currentSegment);
      }
      currentSegment = [];
    }
  }

  if (currentSegment.length > 1) {
    segments.push(currentSegment);
  }

  return segments;
}

/**
 * Check if an object intersects marquee box
 */
export function isObjectInMarquee(
  obj: BoardObject,
  minX: number,
  minY: number,
  maxX: number,
  maxY: number
): boolean {
  if (obj.isVisible === false) return false;
  if (obj.type === 'line' || obj.type === 'arrow') {
    const x1 = obj.x1 !== undefined ? obj.x1 : obj.x;
    const y1 = obj.y1 !== undefined ? obj.y1 : obj.y;
    const x2 = obj.x2 !== undefined ? obj.x2 : (obj.x + obj.width);
    const y2 = obj.y2 !== undefined ? obj.y2 : (obj.y + obj.height);
    const lMinX = Math.min(x1, x2);
    const lMaxX = Math.max(x1, x2);
    const lMinY = Math.min(y1, y2);
    const lMaxY = Math.max(y1, y2);
    return !(lMaxX < minX || lMinX > maxX || lMaxY < minY || lMinY > maxY);
  }
  const oMinX = Math.min(obj.x, obj.x + obj.width);
  const oMaxX = Math.max(obj.x, obj.x + obj.width);
  const oMinY = Math.min(obj.y, obj.y + obj.height);
  const oMaxY = Math.max(obj.y, obj.y + obj.height);

  return !(oMaxX < minX || oMinX > maxX || oMaxY < minY || oMinY > maxY);
}
