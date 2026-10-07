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
      case 'paint':
      case 'curve': {
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
  const { jsPDF } = await import('jspdf');
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
    schemaVersion: '1.0.0',
    version: '1.0',
    board,
    objects,
    exportedAt: new Date().toISOString(),
  };
  const jsonStr = JSON.stringify(payload, null, 2);
  const cleanTitle = (board.title || 'blackboard').replace(/[^\w\u4e00-\u9fa5]/gi, '_');
  downloadFile(jsonStr, `${cleanTitle}.blackboard.json`, 'application/json');
}

/**
 * Generate a standalone offline interactive HTML document
 */
export function generateStandaloneHtml(
  objects: BoardObject[],
  board: BoardMetadata,
  customBounds?: { minX: number; minY: number; maxX: number; maxY: number }
): string {
  const { svgString, width, height } = generateSvg(objects, board, 40, customBounds);
  const title = board.title || 'HeiBan 黑板作品';
  const bgColor = board.backgroundColor || '#172e25';
  const payload = {
    schemaVersion: '1.0.0',
    version: '1.0',
    board,
    objects,
    exportedAt: new Date().toISOString(),
  };
  const jsonStr = JSON.stringify(payload, null, 2);

  const pages = board.pages || [];
  let pageTabsHtml = '';
  if (pages.length > 1) {
    pageTabsHtml = "<div class='page-bar'>";
    pages.forEach((p, idx) => {
      const activeClass = idx === 0 ? 'active' : '';
      pageTabsHtml += `<button class='page-tab ${activeClass}' onclick='switchPage("${p.id}")'>${p.title}</button>`;
    });
    pageTabsHtml += '</div>';
  }

  return `<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} - HeiBan 離線導出</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body, html { width: 100%; height: 100%; overflow: hidden; background-color: ${bgColor}; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; user-select: none; }
    #header { position: absolute; top: 16px; left: 16px; z-index: 100; display: flex; align-items: center; gap: 12px; background: rgba(20, 24, 33, 0.82); backdrop-filter: blur(16px); padding: 8px 16px; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.12); color: #fff; box-shadow: 0 8px 24px rgba(0,0,0,0.3); }
    #title { font-size: 14px; font-weight: 600; }
    .badge { font-size: 10px; background: rgba(56, 189, 248, 0.2); color: #38bdf8; padding: 2px 8px; border-radius: 999px; border: 1px solid rgba(56, 189, 248, 0.3); }
    #controls { position: absolute; bottom: 20px; left: 50%; transform: translateX(-50%); z-index: 100; display: flex; gap: 8px; background: rgba(20, 24, 33, 0.85); backdrop-filter: blur(16px); padding: 6px 12px; border-radius: 30px; border: 1px solid rgba(255, 255, 255, 0.15); box-shadow: 0 8px 30px rgba(0,0,0,0.35); }
    .ctrl-btn { background: transparent; border: none; color: #e2e8f0; font-size: 13px; font-weight: 600; padding: 6px 12px; border-radius: 20px; cursor: pointer; transition: background 0.15s, color 0.15s; }
    .ctrl-btn:hover { background: rgba(255, 255, 255, 0.12); color: #fff; }
    #viewport { width: 100%; height: 100%; position: absolute; inset: 0; cursor: grab; display: flex; align-items: center; justify-content: center; overflow: hidden; }
    #viewport:active { cursor: grabbing; }
    #canvas-container { transform-origin: 0 0; transition: transform 0.04s ease-out; box-shadow: 0 10px 40px rgba(0,0,0,0.4); border-radius: 8px; }
    svg { display: block; width: 100%; height: 100%; }
    .page-bar { display: flex; gap: 4px; margin-left: 8px; }
    .page-tab { background: rgba(255, 255, 255, 0.08); border: 1px solid rgba(255, 255, 255, 0.12); color: #cbd5e1; font-size: 11px; padding: 4px 10px; border-radius: 8px; cursor: pointer; }
    .page-tab.active { background: #3b82f6; color: #fff; font-weight: bold; border-color: #60a5fa; }
  </style>
</head>
<body>
  <div id="header">
    <span id="title">${title}</span>
    <span class="badge">HeiBan 向量畫布</span>
    ${pageTabsHtml}
  </div>

  <div id="controls">
    <button class="ctrl-btn" onclick="zoomIn()">放大 (+)</button>
    <button class="ctrl-btn" onclick="resetZoom()">100%</button>
    <button class="ctrl-btn" onclick="zoomOut()">縮小 (-)</button>
    <button class="ctrl-btn" onclick="fitView()">適配視窗</button>
  </div>

  <div id="viewport" onmousedown="startPan(event)" onwheel="handleWheel(event)">
    <div id="canvas-container">
      ${svgString}
    </div>
  </div>

  <script id="heiban-data" type="application/json">
  ${jsonStr}
  </script>

  <script>
    let scale = 1.0;
    let panX = 0, panY = 0;
    let isPanning = false;
    let startX = 0, startY = 0;
    const container = document.getElementById('canvas-container');
    const origWidth = ${width};
    const origHeight = ${height};

    function updateTransform() {
      container.style.transform = \`translate(\${panX}px, \${panY}px) scale(\${scale})\`;
    }

    function zoomIn() { scale = Math.min(6.0, scale * 1.25); updateTransform(); }
    function zoomOut() { scale = Math.max(0.1, scale / 1.25); updateTransform(); }
    function resetZoom() { scale = 1.0; panX = (window.innerWidth - origWidth) / 2; panY = (window.innerHeight - origHeight) / 2; updateTransform(); }
    function fitView() {
      const padding = 60;
      const scaleX = (window.innerWidth - padding) / origWidth;
      const scaleY = (window.innerHeight - padding) / origHeight;
      scale = Math.min(scaleX, scaleY, 1.5);
      panX = (window.innerWidth - origWidth * scale) / 2;
      panY = (window.innerHeight - origHeight * scale) / 2;
      updateTransform();
    }

    function startPan(e) {
      if (e.target.closest('#header') || e.target.closest('#controls')) return;
      isPanning = true;
      startX = e.clientX - panX;
      startY = e.clientY - panY;
      window.addEventListener('mousemove', onPan);
      window.addEventListener('mouseup', endPan);
    }

    function onPan(e) {
      if (!isPanning) return;
      panX = e.clientX - startX;
      panY = e.clientY - startY;
      updateTransform();
    }

    function endPan() {
      isPanning = false;
      window.removeEventListener('mousemove', onPan);
      window.removeEventListener('mouseup', endPan);
    }

    function handleWheel(e) {
      e.preventDefault();
      const zoomFactor = e.deltaY < 0 ? 1.1 : 0.9;
      const mouseX = e.clientX;
      const mouseY = e.clientY;
      const newScale = Math.min(8.0, Math.max(0.1, scale * zoomFactor));
      panX = mouseX - (mouseX - panX) * (newScale / scale);
      panY = mouseY - (mouseY - panY) * (newScale / scale);
      scale = newScale;
      updateTransform();
    }

    window.addEventListener('load', fitView);
  </script>
</body>
</html>`;
}

/**
 * Export board to standalone interactive HTML file
 */
export function exportToHtmlFile(
  objects: BoardObject[],
  board: BoardMetadata,
  customBounds?: { minX: number; minY: number; maxX: number; maxY: number }
) {
  const htmlContent = generateStandaloneHtml(objects, board, customBounds);
  const cleanTitle = (board.title || 'blackboard').replace(/[^\w\u4e00-\u9fa5]/gi, '_');
  downloadFile(htmlContent, `${cleanTitle}${customBounds ? '_custom_range' : ''}.html`, 'text/html');
}
