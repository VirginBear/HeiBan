/**
 * Tool Metrics and Dimension Parity Utility (筆刷與橡皮擦尺寸 1:1 精確對齊模組)
 *
 * Ensures that the hover indicator preview diameter, in-flight drawing stroke width,
 * and committed board object stroke width match with 100% pixel-perfect fidelity.
 */

export function getToolStrokeWidth(tool: string, activeStrokeWidth: number): number {
  const base = Math.max(1, activeStrokeWidth || 2);
  if (tool === 'paint') {
    return Math.max(24, (activeStrokeWidth || 4) * 8.0);
  }
  if (tool === 'highlighter') {
    return Math.max(12, (activeStrokeWidth || 4) * 3.5);
  }
  return base;
}

export function getEraserRadius(eraserMode: string = 'object'): number {
  // Pixel mode: 16 world units radius (32 diameter)
  // Object mode: 18 world units radius (36 diameter)
  return eraserMode === 'pixel' ? 16 : 18;
}

export function getToolHoverDiameter(
  tool: string,
  activeStrokeWidth: number,
  zoom: number,
  eraserMode: string = 'object'
): number {
  const currentZoom = Math.max(0.1, zoom || 1.0);
  if (tool === 'eraser') {
    const radius = getEraserRadius(eraserMode);
    return Math.max(8, radius * 2 * currentZoom);
  }
  const strokeWidth = getToolStrokeWidth(tool, activeStrokeWidth);
  return Math.max(3, strokeWidth * currentZoom);
}
