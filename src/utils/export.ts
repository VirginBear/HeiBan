import { jsPDF } from 'jspdf';
import { BoardObject, BoardMetadata, Point } from '../types';
import { pointsToSvgPath } from './vector';

/**
 * Generate a pure vector SVG string from board objects
 */
export function generateSvg(
  objects: BoardObject[],
  board: BoardMetadata,
  padding = 40,
  customBounds?: { minX: number; minY: number; maxX: number; maxY: number }
): { svgString: string; width: number; height: number } {
  const visibleObjects = objects.filter((o) => o.isVisible !== false);

  let minX: number;
  let minY: number;
  let maxX: number;
  let maxY: number;

  if (customBounds) {
    minX = Math.round(customBounds.minX);
    minY = Math.round(customBounds.minY);
    maxX = Math.round(customBounds.maxX);
    maxY = Math.round(customBounds.maxY);
  } else if (visibleObjects.length === 0) {
    const width = 1200;
    const height = 800;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
      <rect width="100%" height="100%" fill="${board.backgroundColor}" />
      <text x="50%" y="50%" text-anchor="middle" fill="#888" font-size="20">黑板空白無內容</text>
    </svg>`;
    return { svgString: svg, width, height };
  } else {
    minX = Infinity;
    minY = Infinity;
    maxX = -Infinity;
    maxY = -Infinity;

    for (const obj of visibleObjects) {
      const oMinX = Math.min(obj.x, obj.x + obj.width);
      const oMaxX = Math.max(obj.x, obj.x + obj.width);
      const oMinY = Math.min(obj.y, obj.y + obj.height);
      const oMaxY = Math.max(obj.y, obj.y + obj.height);

      if (oMinX < minX) minX = oMinX;
      if (oMaxX > maxX) maxX = oMaxX;
      if (oMinY < minY) minY = oMinY;
      if (oMaxY > maxY) maxY = oMaxY;
    }

    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;
  }

  const width = Math.max(100, Math.ceil(maxX - minX));
  const height = Math.max(100, Math.ceil(maxY - minY));

  // Sort objects by zIndex
  const sorted = [...visibleObjects].sort((a, b) => a.zIndex - b.zIndex);

  let elementsSvg = '';

  for (const obj of sorted) {
    const opacity = obj.opacity ?? 1;
    const rot = obj.rotation || 0;
    const transform = rot !== 0 ? `transform="rotate(${rot} ${obj.x + obj.width / 2} ${obj.y + obj.height / 2})"` : '';

    switch (obj.type) {
      case 'stroke':
      case 'highlighter':
      case 'paint': {
        if (obj.points) {
          try {
            const points: Point[] = JSON.parse(obj.points);
            const d = pointsToSvgPath(points);
            const strokeLinecap = 'round';
            const strokeLinejoin = 'round';
            elementsSvg += `<path d="${d}" stroke="${obj.strokeColor}" stroke-width="${obj.strokeWidth}" fill="none" opacity="${opacity}" stroke-linecap="${strokeLinecap}" stroke-linejoin="${strokeLinejoin}" ${transform} />\n`;
          } catch {
            // ignore
          }
        }
        break;
      }
      case 'rect': {
        elementsSvg += `<rect x="${obj.x}" y="${obj.y}" width="${obj.width}" height="${obj.height}" fill="${obj.fillColor || 'none'}" stroke="${obj.strokeColor}" stroke-width="${obj.strokeWidth}" opacity="${opacity}" rx="8" ${transform} />\n`;
        break;
      }
      case 'circle': {
        const cx = obj.x + obj.width / 2;
        const cy = obj.y + obj.height / 2;
        const rx = Math.abs(obj.width) / 2;
        const ry = Math.abs(obj.height) / 2;
        elementsSvg += `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${obj.fillColor || 'none'}" stroke="${obj.strokeColor}" stroke-width="${obj.strokeWidth}" opacity="${opacity}" ${transform} />\n`;
        break;
      }
      case 'triangle': {
        const p1 = `${obj.x + obj.width / 2},${obj.y}`;
        const p2 = `${obj.x},${obj.y + obj.height}`;
        const p3 = `${obj.x + obj.width},${obj.y + obj.height}`;
        elementsSvg += `<polygon points="${p1} ${p2} ${p3}" fill="${obj.fillColor || 'none'}" stroke="${obj.strokeColor}" stroke-width="${obj.strokeWidth}" opacity="${opacity}" stroke-linejoin="round" ${transform} />\n`;
        break;
      }
      case 'diamond': {
        const p1 = `${obj.x + obj.width / 2},${obj.y}`;
        const p2 = `${obj.x + obj.width},${obj.y + obj.height / 2}`;
        const p3 = `${obj.x + obj.width / 2},${obj.y + obj.height}`;
        const p4 = `${obj.x},${obj.y + obj.height / 2}`;
        elementsSvg += `<polygon points="${p1} ${p2} ${p3} ${p4}" fill="${obj.fillColor || 'none'}" stroke="${obj.strokeColor}" stroke-width="${obj.strokeWidth}" opacity="${opacity}" stroke-linejoin="round" ${transform} />\n`;
        break;
      }
      case 'line': {
        const x1 = obj.x1 !== undefined ? obj.x1 : obj.x;
        const y1 = obj.y1 !== undefined ? obj.y1 : obj.y;
        const x2 = obj.x2 !== undefined ? obj.x2 : obj.x + obj.width;
        const y2 = obj.y2 !== undefined ? obj.y2 : obj.y + obj.height;
        const dashAttr = obj.lineStyle === 'dashed' ? 'stroke-dasharray="8 6"' : '';
        elementsSvg += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${obj.strokeColor}" stroke-width="${obj.strokeWidth}" ${dashAttr} stroke-linecap="round" opacity="${opacity}" ${transform} />\n`;
        break;
      }
      case 'arrow': {
        const x1 = obj.x1 !== undefined ? obj.x1 : obj.x;
        const y1 = obj.y1 !== undefined ? obj.y1 : obj.y;
        const x2 = obj.x2 !== undefined ? obj.x2 : obj.x + obj.width;
        const y2 = obj.y2 !== undefined ? obj.y2 : obj.y + obj.height;
        const dashAttr = obj.lineStyle === 'dashed' ? 'stroke-dasharray="8 6"' : '';
        const angle = Math.atan2(y2 - y1, x2 - x1);
        const arrowLength = Math.max(14, obj.strokeWidth * 3);
        const arrowAngle = Math.PI / 6;
        const ax1 = x2 - arrowLength * Math.cos(angle - arrowAngle);
        const ay1 = y2 - arrowLength * Math.sin(angle - arrowAngle);
        const ax2 = x2 - arrowLength * Math.cos(angle + arrowAngle);
        const ay2 = y2 - arrowLength * Math.sin(angle + arrowAngle);
        elementsSvg += `
          <g opacity="${opacity}" ${transform}>
            <line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${obj.strokeColor}" stroke-width="${obj.strokeWidth}" ${dashAttr} stroke-linecap="round" />
            <polygon points="${x2},${y2} ${ax1},${ay1} ${ax2},${ay2}" fill="${obj.strokeColor}" />
          </g>\n`;
        break;
      }
      case 'sticky': {
        const textLines = (obj.text || '').split('\n');
        const tspans = textLines
          .map((line, i) => `<tspan x="${obj.x + 16}" dy="${i === 0 ? 0 : '1.3em'}">${escapeXml(line)}</tspan>`)
          .join('');
        elementsSvg += `
          <g opacity="${opacity}" ${transform}>
            <rect x="${obj.x}" y="${obj.y}" width="${obj.width}" height="${obj.height}" fill="${obj.fillColor || '#fef08a'}" rx="8" filter="drop-shadow(2px 4px 6px rgba(0,0,0,0.15))" />
            <text x="${obj.x + 16}" y="${obj.y + 30}" font-family="sans-serif" font-size="${obj.fontSize || 16}" fill="${obj.strokeColor || '#1f2937'}">${tspans}</text>
          </g>\n`;
        break;
      }
      case 'text': {
        const textLines = (obj.text || '').split('\n');
        const tspans = textLines
          .map((line, i) => `<tspan x="${obj.x}" dy="${i === 0 ? 0 : '1.3em'}">${escapeXml(line)}</tspan>`)
          .join('');
        
        let textDecor = '';
        if (obj.isUnderline && obj.isStrikethrough) textDecor = 'underline line-through';
        else if (obj.isUnderline) textDecor = 'underline';
        else if (obj.isStrikethrough) textDecor = 'line-through';

        const fontWeight = obj.isBold ? 'bold' : 'normal';
        const fontStyle = obj.isItalic ? 'italic' : 'normal';
        const highlightSvg = obj.highlightColor && obj.highlightColor !== 'none' && obj.highlightColor !== 'transparent'
          ? `<rect x="${obj.x - 4}" y="${obj.y}" width="${obj.width + 8}" height="${obj.height}" fill="${obj.highlightColor}" opacity="0.6" rx="4" />`
          : '';

        elementsSvg += `
          <g opacity="${opacity}" ${transform}>
            ${highlightSvg}
            <text x="${obj.x}" y="${obj.y + (obj.fontSize || 20)}" font-family="${obj.fontFamily || 'sans-serif'}" font-size="${obj.fontSize || 20}" font-weight="${fontWeight}" font-style="${fontStyle}" text-decoration="${textDecor}" fill="${obj.strokeColor}">${tspans}</text>
          </g>\n`;
        break;
      }
      case 'image': {
        if (obj.imageUrl) {
          elementsSvg += `<image href="${obj.imageUrl}" x="${obj.x}" y="${obj.y}" width="${obj.width}" height="${obj.height}" preserveAspectRatio="none" opacity="${opacity}" ${transform} />\n`;
        }
        break;
      }
    }
  }

  const svgString = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}" viewBox="${minX} ${minY} ${width} ${height}">
    <rect x="${minX}" y="${minY}" width="${width}" height="${height}" fill="${board.backgroundColor}" />
    ${elementsSvg}
  </svg>`;

  return { svgString, width, height };
}

/**
 * Generate a fast SVG data URL thumbnail of the board
 */
export function generateBoardThumbnailDataUrl(
  objects: BoardObject[],
  board: BoardMetadata
): string {
  try {
    const { svgString } = generateSvg(objects, board, 20);
    const encoded = encodeURIComponent(svgString)
      .replace(/'/g, '%27')
      .replace(/"/g, '%22');
    return `data:image/svg+xml;charset=utf-8,${encoded}`;
  } catch {
    return '';
  }
}

function escapeXml(unsafe: string): string {
  return unsafe.replace(/[<>&'"]/g, (c) => {
    switch (c) {
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '&':
        return '&amp;';
      case '\'':
        return '&apos;';
      case '"':
        return '&quot;';
      default:
        return c;
    }
  });
}

/**
 * Trigger file download helper
 */
export function downloadFile(content: string, filename: string, mimeType: string) {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/**
 * Export board to vector SVG file
 */
export function exportToSvgFile(
  objects: BoardObject[],
  board: BoardMetadata,
  customBounds?: { minX: number; minY: number; maxX: number; maxY: number }
) {
  const { svgString } = generateSvg(objects, board, 40, customBounds);
  const cleanTitle = (board.title || 'blackboard').replace(/[^\w\u4e00-\u9fa5]/gi, '_');
  downloadFile(svgString, `${cleanTitle}${customBounds ? '_custom_range' : ''}.svg`, 'image/svg+xml');
}

/**
 * Export board to PDF file
 */
export async function exportToPdfFile(
  objects: BoardObject[],
  board: BoardMetadata,
  customBounds?: { minX: number; minY: number; maxX: number; maxY: number }
) {
  const { svgString, width, height } = generateSvg(objects, board, 40, customBounds);

  // Render SVG to high-res image and insert into PDF
  const img = new Image();
  const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(svgBlob);

  await new Promise<void>((resolve, reject) => {
    img.onload = () => resolve();
    img.onerror = reject;
    img.src = url;
  });

  const canvas = document.createElement('canvas');
  // High quality 2x resolution
  const scale = 2;
  canvas.width = width * scale;
  canvas.height = height * scale;
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.scale(scale, scale);
    ctx.drawImage(img, 0, 0);
  }
  URL.revokeObjectURL(url);

  const imgData = canvas.toDataURL('image/png', 1.0);
  const orientation = width >= height ? 'l' : 'p';
  const pdf = new jsPDF({
    orientation,
    unit: 'px',
    format: [width, height],
  });

  pdf.addImage(imgData, 'PNG', 0, 0, width, height);
  const cleanTitle = (board.title || 'blackboard').replace(/[^\w\u4e00-\u9fa5]/gi, '_');
  pdf.save(`${cleanTitle}${customBounds ? '_custom_range' : ''}.pdf`);
}

/**
 * Export board to PNG file
 */
export async function exportToPngFile(
  objects: BoardObject[],
  board: BoardMetadata,
  customBounds?: { minX: number; minY: number; maxX: number; maxY: number }
) {
  const { svgString, width, height } = generateSvg(objects, board, 40, customBounds);
  const img = new Image();
  const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(svgBlob);

  await new Promise<void>((resolve, reject) => {
    img.onload = () => resolve();
    img.onerror = reject;
    img.src = url;
  });

  const canvas = document.createElement('canvas');
  const scale = 2;
  canvas.width = width * scale;
  canvas.height = height * scale;
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.scale(scale, scale);
    ctx.drawImage(img, 0, 0);
  }
  URL.revokeObjectURL(url);

  const pngUrl = canvas.toDataURL('image/png', 1.0);
  const a = document.createElement('a');
  a.href = pngUrl;
  const cleanTitle = (board.title || 'blackboard').replace(/[^\w\u4e00-\u9fa5]/gi, '_');
  a.download = `${cleanTitle}${customBounds ? '_custom_range' : ''}.png`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

/**
 * Export board to project JSON
 */
export function exportToJsonFile(objects: BoardObject[], board: BoardMetadata) {
  const payload = {
    version: '1.0',
    board,
    objects,
    exportedAt: new Date().toISOString(),
  };
  const jsonStr = JSON.stringify(payload, null, 2);
  const cleanTitle = (board.title || 'blackboard').replace(/[^\w\u4e00-\u9fa5]/gi, '_');
  downloadFile(jsonStr, `${cleanTitle}.blackboard.json`, 'application/json');
}
