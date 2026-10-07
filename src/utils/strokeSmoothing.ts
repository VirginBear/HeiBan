import { Point, BoardObject } from '../types';

export function getCurveSegment(points: Point[], index: number, includeMove: boolean): string {
  const previous = points[Math.max(0, index - 1)];
  const start = points[index];
  const end = points[Math.min(points.length - 1, index + 1)];
  const next = points[Math.min(points.length - 1, index + 2)];

  const cp1x = start.x + (end.x - previous.x) / 6;
  const cp1y = start.y + (end.y - previous.y) / 6;
  const cp2x = end.x - (next.x - start.x) / 6;
  const cp2y = end.y - (next.y - start.y) / 6;

  const move = includeMove ? `M ${start.x} ${start.y}` : '';
  const prefix = includeMove ? '' : ' ';
  return `${move}${prefix}C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${end.x} ${end.y}`;
}

export interface SelectionHandlesPositions {
  topLeft: { x: number; y: number };
  topCenter: { x: number; y: number };
  topRight: { x: number; y: number };
  middleRight: { x: number; y: number };
  bottomRight: { x: number; y: number };
  bottomCenter: { x: number; y: number };
  bottomLeft: { x: number; y: number };
  middleLeft: { x: number; y: number };
  rotate: { x: number; y: number };
}

export function computeSelectionHandles(
  bounds: { minX: number; minY: number; maxX: number; maxY: number },
  zoom: number = 1.0
): SelectionHandlesPositions {
  const minX = bounds.minX;
  const maxX = bounds.maxX;
  const minY = bounds.minY;
  const maxY = bounds.maxY;
  const midX = (minX + maxX) / 2;
  const midY = (minY + maxY) / 2;
  const rotateOffsetY = 24 / Math.max(0.1, zoom);

  return {
    topLeft: { x: minX, y: minY },
    topCenter: { x: midX, y: minY },
    topRight: { x: maxX, y: minY },
    middleRight: { x: maxX, y: midY },
    bottomRight: { x: maxX, y: maxY },
    bottomCenter: { x: midX, y: maxY },
    bottomLeft: { x: minX, y: maxY },
    middleLeft: { x: minX, y: midY },
    rotate: { x: midX, y: minY - rotateOffsetY },
  };
}

export function getHandleCursor(handle: string): string {
  switch (handle) {
    case 'middleLeft':
    case 'middleRight':
      return 'ew-resize';
    case 'topCenter':
    case 'bottomCenter':
      return 'ns-resize';
    case 'topLeft':
    case 'bottomRight':
      return 'nwse-resize';
    case 'topRight':
    case 'bottomLeft':
      return 'nesw-resize';
    case 'rotate':
      return 'grab';
    default:
      return 'default';
  }
}

export interface GestureTransaction {
  objects: BoardObject[];
  timestamp: string;
}

export class GestureTransactionTracker {
  private activeSamples: Point[] = [];
  private committed: boolean = false;

  public beginGesture(startPoint: Point): void {
    this.activeSamples = [{ ...startPoint }];
    this.committed = false;
  }

  public appendSample(point: Point): void {
    if (!this.committed) {
      this.activeSamples.push({ ...point });
    }
  }

  public getSampleCount(): number {
    return this.activeSamples.length;
  }

  public isCommitted(): boolean {
    return this.committed;
  }

  public endGesture(
    objectId: string,
    type: string,
    strokeColor: string,
    strokeWidth: number
  ): GestureTransaction | null {
    if (this.activeSamples.length === 0) return null;
    this.committed = true;

    const xs = this.activeSamples.map((p) => p.x);
    const ys = this.activeSamples.map((p) => p.y);
    const minX = Math.min(...xs);
    const maxX = Math.max(...xs);
    const minY = Math.min(...ys);
    const maxY = Math.max(...ys);

    const committedObj: BoardObject = {
      id: objectId,
      type,
      x: minX,
      y: minY,
      width: Math.max(1, maxX - minX),
      height: Math.max(1, maxY - minY),
      points: JSON.stringify(this.activeSamples),
      strokeColor,
      fillColor: 'none',
      strokeWidth,
      opacity: 1,
      rotation: 0,
      zIndex: 1,
      createdBy: 'local_web',
      updatedAt: new Date().toISOString(),
    };

    return {
      objects: [committedObj],
      timestamp: new Date().toISOString(),
    };
  }
}
