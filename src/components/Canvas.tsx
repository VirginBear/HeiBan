import React, { useRef, useState, useEffect, useCallback, useImperativeHandle, forwardRef } from 'react';
import {
  BoardObject,
  ToolType,
  Point,
  ViewportTransform,
  RulerState,
  BoardMetadata,
  BoardPin,
  UserPresence,
  EraserMode,
  LineExtension,
} from '../types';
import {
  pointsToSvgPath,
  computeBoundingBox,
  snapToScreenRulerEdge,
  isPointInObject,
  isObjectInMarquee,
  erasePointsAtPoint,
  computeLineRenderCoordinates,
} from '../utils/vector';
import { recognizeGoodnotesShape, RecognizedShape } from '../utils/goodnotes';
import { RulerOverlay } from './RulerOverlay';
import { CollaboratorCursors } from './CollaboratorCursors';
import { Pin, X, CornerLeftUp } from 'lucide-react';

type FreehandPreviewHandle = {
  setPoints: (points: Point[]) => void;
  finish: () => void;
  clear: () => void;
};

const PREVIEW_SEGMENTS_PER_PATH = 64;

function getCurveSegment(points: Point[], index: number, includeMove: boolean) {
  const previous = points[Math.max(0, index - 1)];
  const start = points[index];
  const end = points[index + 1];
  const next = points[Math.min(points.length - 1, index + 2)];
  const cp1x = start.x + (end.x - previous.x) / 6;
  const cp1y = start.y + (end.y - previous.y) / 6;
  const cp2x = end.x - (next.x - start.x) / 6;
  const cp2y = end.y - (next.y - start.y) / 6;
  const move = includeMove ? `M ${start.x} ${start.y}` : '';
  return `${move} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${end.x} ${end.y}`;
}

const FreehandPreview = React.memo(forwardRef<FreehandPreviewHandle, {
  visible: boolean;
  color: string;
  width: number;
  opacity: number;
}>(function FreehandPreview({ visible, color, width, opacity }, ref) {
  const groupRef = useRef<SVGGElement>(null);
  const latestPointsRef = useRef<Point[] | null>(null);
  const frameRef = useRef<number | null>(null);
  const committedSegmentsRef = useRef(0);
  const chunkPathRef = useRef<SVGPathElement | null>(null);
  const chunkSegmentCountRef = useRef(0);
  const chunkDataRef = useRef('');
  const tailPathRef = useRef<SVGPathElement | null>(null);

  const createPath = () => {
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('fill', 'none');
    groupRef.current?.appendChild(path);
    return path;
  };

  const appendCommittedSegment = (points: Point[], index: number) => {
    if (!chunkPathRef.current) {
      chunkPathRef.current = createPath();
      chunkSegmentCountRef.current = 0;
      chunkDataRef.current = '';
      chunkDataRef.current = getCurveSegment(points, index, true);
    } else {
      chunkDataRef.current += getCurveSegment(points, index, false);
    }
    chunkSegmentCountRef.current += 1;
    if (chunkSegmentCountRef.current >= PREVIEW_SEGMENTS_PER_PATH) {
      chunkPathRef.current.setAttribute('d', chunkDataRef.current);
      chunkPathRef.current = null;
      chunkSegmentCountRef.current = 0;
      chunkDataRef.current = '';
    }
  };

  const drawPendingSegments = (points: Point[], flush: boolean) => {
    const group = groupRef.current;
    if (!group || points.length === 0) return;
    const stableSegmentCount = points.length < 3 ? 0 : points.length - 2;
    const targetSegmentCount = flush ? Math.max(0, points.length - 1) : stableSegmentCount;

    while (committedSegmentsRef.current < targetSegmentCount) {
      appendCommittedSegment(points, committedSegmentsRef.current);
      committedSegmentsRef.current += 1;
    }
    if (chunkPathRef.current && chunkDataRef.current) {
      chunkPathRef.current.setAttribute('d', chunkDataRef.current);
    }

    if (flush) {
      tailPathRef.current?.remove();
      tailPathRef.current = null;
      if (points.length === 1) {
        const point = points[0];
        const dot = tailPathRef.current ?? createPath();
        dot.setAttribute('d', `M ${point.x} ${point.y} L ${point.x + 0.1} ${point.y + 0.1}`);
        tailPathRef.current = dot;
      }
      return;
    }

    if (!tailPathRef.current) tailPathRef.current = createPath();
    if (points.length === 1) {
      const point = points[0];
      tailPathRef.current.setAttribute('d', `M ${point.x} ${point.y} L ${point.x + 0.1} ${point.y + 0.1}`);
    } else if (points.length === 2) {
      tailPathRef.current.setAttribute('d', `M ${points[0].x} ${points[0].y} L ${points[1].x} ${points[1].y}`);
    } else {
      tailPathRef.current.setAttribute('d', `M ${points[points.length - 2].x} ${points[points.length - 2].y}${getCurveSegment(points, points.length - 2, false)}`);
    }
  };

  const clear = () => {
    if (frameRef.current !== null) cancelAnimationFrame(frameRef.current);
    frameRef.current = null;
    groupRef.current?.replaceChildren();
    latestPointsRef.current = null;
    committedSegmentsRef.current = 0;
    chunkPathRef.current = null;
    chunkSegmentCountRef.current = 0;
    chunkDataRef.current = '';
    tailPathRef.current = null;
  };

  useImperativeHandle(ref, () => ({
    setPoints: (points) => {
      latestPointsRef.current = points;
      if (frameRef.current === null) {
        frameRef.current = requestAnimationFrame(() => {
          frameRef.current = null;
          if (latestPointsRef.current) drawPendingSegments(latestPointsRef.current, false);
        });
      }
    },
    finish: () => {
      if (frameRef.current !== null) cancelAnimationFrame(frameRef.current);
      frameRef.current = null;
      if (latestPointsRef.current) drawPendingSegments(latestPointsRef.current, true);
    },
    clear,
  }), []);
  useEffect(() => () => {
    if (frameRef.current !== null) cancelAnimationFrame(frameRef.current);
  }, []);
  return <g ref={groupRef} display={visible ? undefined : 'none'} stroke={color} strokeWidth={width} fill="none" opacity={opacity} strokeLinecap="round" strokeLinejoin="round" />;
}));

interface CanvasProps {
  board: BoardMetadata;
  objects: BoardObject[];
  selectedIds: string[];
  currentTool: ToolType;
  eraserMode: EraserMode;
  ruler: RulerState;
  viewport: ViewportTransform;
  presences: UserPresence[];
  currentUserId?: string;
  showCursors: boolean;
  activeColor: string;
  activeStrokeWidth: number;
  activeLineStyle?: 'solid' | 'dashed';
  activeOpacity?: number;
  onUpdateViewport: (viewport: ViewportTransform) => void;
  onUpdateRuler: (partial: Partial<RulerState>) => void;
  onAddObject: (obj: BoardObject) => void;
  onUpdateObject: (id: string, partial: Partial<BoardObject>) => void;
  onDeleteObjects: (ids: string[]) => void;
  onSelectObjects: (ids: string[]) => void;
  onPointerTrack: (x: number, y: number, isDrawing: boolean) => void;
  onAddPin?: (name: string, x: number, y: number, zoom: number) => void;
  onUpdatePin?: (id: string, partial: Partial<BoardPin>) => void;
  onDeletePin?: (id: string) => void;
  onJumpToPin?: (pin: BoardPin) => void;
  onSelectTool?: (tool: ToolType) => void;
  onCropImage?: (obj: BoardObject) => void;
  isSelectingExportRange?: boolean;
  onExportCustomRange?: (bounds: { minX: number; minY: number; maxX: number; maxY: number }, format: 'svg' | 'png' | 'pdf') => void;
  onCancelExportRange?: () => void;
}

export const Canvas: React.FC<CanvasProps> = ({
  board,
  objects,
  selectedIds,
  currentTool,
  eraserMode,
  ruler,
  viewport,
  presences,
  currentUserId,
  showCursors,
  activeColor,
  activeStrokeWidth,
  activeLineStyle = 'solid',
  activeOpacity = 1,
  onUpdateViewport,
  onUpdateRuler,
  onAddObject,
  onUpdateObject,
  onDeleteObjects,
  onSelectObjects,
  onPointerTrack,
  onAddPin,
  onUpdatePin,
  onDeletePin,
  onJumpToPin,
  onSelectTool,
  onCropImage,
  isSelectingExportRange,
  onExportCustomRange,
  onCancelExportRange,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);

  // Range Export selection state (自訂框選輸出範圍)
  const [rangeExportBox, setRangeExportBox] = useState<{ startX: number; startY: number; currentX: number; currentY: number } | null>(null);
  const isDraggingExportRangeRef = useRef(false);

  // Navigation State
  const [isSpacePressed, setIsSpacePressed] = useState(false);
  const [isPanning, setIsPanning] = useState(false);
  const panStartRef = useRef<{ x: number; y: number; viewX: number; viewY: number }>({
    x: 0,
    y: 0,
    viewX: 0,
    viewY: 0,
  });

  // Freehand stroke in progress
  const [currentStroke, setCurrentStroke] = useState<Point[] | null>(null);
  const currentStrokeRef = useRef<Point[] | null>(null);
  const freehandPreviewRef = useRef<FreehandPreviewHandle>(null);

  // GoodNotes Gesture: Hold for 1 second to snap to shape
  const holdTimerRef = useRef<number | null>(null);
  const lastMovePosRef = useRef<Point | null>(null);
  const [snappedShape, setSnappedShape] = useState<RecognizedShape | null>(null);

  // Direct Line / Shape in progress
  const [shapeStart, setShapeStart] = useState<Point | null>(null);
  const [shapeCurrent, setShapeCurrent] = useState<Point | null>(null);

  // Marquee selection
  const [marquee, setMarquee] = useState<{ startX: number; startY: number; currentX: number; currentY: number } | null>(null);

  // Transforming objects
  // Dedicated Line Endpoint dragging state
  const [lineHandleDrag, setLineHandleDrag] = useState<{
    objectId: string;
    endpoint: 'A' | 'B';
    initialX1: number;
    initialY1: number;
    initialX2: number;
    initialY2: number;
  } | null>(null);

  // General 2D Move / Resize / Rotate state
  const [transformState, setTransformState] = useState<{
    type: 'move' | 'resize' | 'rotate';
    handle?: string;
    startWorldX: number;
    startWorldY: number;
    center?: { x: number; y: number };
    startAngle?: number;
    initialObjects: {
      id: string;
      x: number;
      y: number;
      width: number;
      height: number;
      rotation?: number;
      x1?: number;
      y1?: number;
      x2?: number;
      y2?: number;
    }[];
    initialBBox: { minX: number; minY: number; maxX: number; maxY: number; width: number; height: number };
  } | null>(null);

  // Inline text editing
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editText, setEditText] = useState('');

  // Ephemeral new text drafting (disappears if empty)
  const [newTextDraft, setNewTextDraft] = useState<{ x: number; y: number } | null>(null);
  const [draftContent, setDraftContent] = useState('');
  const draftContentRef = useRef('');
  draftContentRef.current = draftContent;
  const draftTextareaRef = useRef<HTMLTextAreaElement>(null);
  const isComposingRef = useRef(false);

  useEffect(() => {
    if (newTextDraft) {
      setTimeout(() => {
        draftTextareaRef.current?.focus();
      }, 50);
    }
  }, [newTextDraft]);

  // Interactive Canvas Pin dragging & renaming
  const [draggingPinId, setDraggingPinId] = useState<string | null>(null);
  const [editingPinId, setEditingPinId] = useState<string | null>(null);
  const [editingPinName, setEditingPinName] = useState('');
  const [newPinDraft, setNewPinDraft] = useState<{ x: number; y: number } | null>(null);
  const [newPinDraftName, setNewPinDraftName] = useState('');

  // Space key pan navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'Space' && !['INPUT', 'TEXTAREA'].includes((e.target as HTMLElement).tagName)) {
        setIsSpacePressed(true);
      }
      if (e.key === 'Escape') {
        setEditingId(null);
        onSelectObjects([]);
        setSnappedShape(null);
        setNewTextDraft(null);
        setNewPinDraft(null);
        if (onSelectTool) onSelectTool('select');
      }
    };
    const handleKeyUp = (e: KeyboardEvent) => {
      if (e.code === 'Space') {
        setIsSpacePressed(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, [onSelectObjects, onSelectTool]);

  // Screen to World coords
  const screenToWorld = useCallback(
    (screenX: number, screenY: number): Point => {
      const rect = containerRef.current?.getBoundingClientRect();
      const clientX = screenX - (rect?.left || 0);
      const clientY = screenY - (rect?.top || 0);
      return {
        x: (clientX - viewport.x) / viewport.zoom,
        y: (clientY - viewport.y) / viewport.zoom,
      };
    },
    [viewport]
  );

  // World to Screen coords
  const worldToScreen = useCallback(
    (worldX: number, worldY: number): Point => {
      return {
        x: worldX * viewport.zoom + viewport.x,
        y: worldY * viewport.zoom + viewport.y,
      };
    },
    [viewport]
  );

  // CAD-style Native Wheel Zoom centered on mouse cursor position (CAD/Figma手感，滑鼠游標為中心放大縮小)
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const onNativeWheel = (e: WheelEvent) => {
      e.preventDefault();
      e.stopPropagation();

      // Shift + Wheel = horizontal pan
      if (e.shiftKey) {
        onUpdateViewport({
          x: Math.round(viewport.x - e.deltaY),
          y: viewport.y,
          zoom: viewport.zoom,
        });
        return;
      }

      const rect = el.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;

      // CAD zoom factor: smooth scaling relative to mouse position
      const zoomFactor = e.deltaY < 0 ? 1.14 : 0.88;
      const newZoom = Math.min(8.0, Math.max(0.08, Number((viewport.zoom * zoomFactor).toFixed(4))));

      const newX = mouseX - (mouseX - viewport.x) * (newZoom / viewport.zoom);
      const newY = mouseY - (mouseY - viewport.y) * (newZoom / viewport.zoom);

      onUpdateViewport({
        x: Math.round(newX),
        y: Math.round(newY),
        zoom: newZoom,
      });
    };

    el.addEventListener('wheel', onNativeWheel, { passive: false });
    return () => {
      el.removeEventListener('wheel', onNativeWheel);
    };
  }, [viewport, onUpdateViewport]);

  const clearHoldTimer = () => {
    if (holdTimerRef.current) {
      window.clearTimeout(holdTimerRef.current);
      holdTimerRef.current = null;
    }
  };

  // Pointer Down
  const handlePointerDown = (e: React.PointerEvent) => {
    if (e.button === 1 || isSpacePressed) {
      setIsPanning(true);
      panStartRef.current = {
        x: e.clientX,
        y: e.clientY,
        viewX: viewport.x,
        viewY: viewport.y,
      };
      (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
      return;
    }

    if (e.button !== 0) return;

    const screenPt: Point = { x: e.clientX, y: e.clientY, pressure: e.pressure || 0.5 };
    let worldPt = screenToWorld(e.clientX, e.clientY);

    // Physical screen ruler snap
    if (ruler.enabled && (currentTool === 'pen' || currentTool === 'highlighter' || currentTool === 'paint' || currentTool === 'line')) {
      const { snapped, screenPt: snappedScreen } = snapToScreenRulerEdge(screenPt, ruler);
      if (snapped) {
        worldPt = screenToWorld(snappedScreen.x, snappedScreen.y);
      }
    }

    onPointerTrack(worldPt.x, worldPt.y, true);

    // Range Export Dragging (自訂框選輸出範圍)
    if (isSelectingExportRange) {
      isDraggingExportRangeRef.current = true;
      setRangeExportBox({
        startX: worldPt.x,
        startY: worldPt.y,
        currentX: worldPt.x,
        currentY: worldPt.y,
      });
      (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
      return;
    }

    // Eraser Tool
    if (currentTool === 'eraser') {
      handleEraseAtPoint(worldPt);
      (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
      return;
    }

    // Freehand Pen / Highlighter / Paint (油漆筆刷)
    if (currentTool === 'pen' || currentTool === 'highlighter' || currentTool === 'paint') {
      const initialStroke = [worldPt];
      freehandPreviewRef.current?.clear();
      currentStrokeRef.current = initialStroke;
      freehandPreviewRef.current?.setPoints(initialStroke);
      setCurrentStroke(initialStroke);
      setSnappedShape(null);
      lastMovePosRef.current = worldPt;

      if (currentTool !== 'paint') {
        clearHoldTimer();
        holdTimerRef.current = window.setTimeout(() => {
          const latestStroke = currentStrokeRef.current;
          if (latestStroke) {
            if (latestStroke && latestStroke.length >= 5) {
              const recognized = recognizeGoodnotesShape(latestStroke);
              if (recognized) {
                setSnappedShape(recognized);
              }
            }
          }
        }, 850);
      }

      (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
      return;
    }

    // Line, Arrow, Rect, Circle...
    if (['line', 'arrow', 'rect', 'circle', 'triangle', 'diamond', 'star'].includes(currentTool)) {
      setShapeStart(worldPt);
      setShapeCurrent(worldPt);
      (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
      return;
    }

    // Sticky Note (便簽: 預設經典可愛手帳便簽，字數永遠包覆在內)
    if (currentTool === 'sticky') {
      const newId = 'sticky_' + Date.now();
      const stickyObj: BoardObject = {
        id: newId,
        boardId: board.id,
        type: 'sticky',
        x: Math.round(worldPt.x - 90),
        y: Math.round(worldPt.y - 90),
        width: 180,
        height: 180,
        strokeColor: '#1f2937',
        fillColor: '#fef08a',
        stickyStyle: 'classic',
        strokeWidth: 1,
        opacity: 1,
        rotation: 0,
        zIndex: objects.length + 1,
        text: '在此輸入便簽內容...',
        fontSize: 15,
        createdBy: currentUserId || 'anonymous',
        updatedAt: new Date().toISOString(),
      };
      onAddObject(stickyObj);
      onSelectObjects([newId]);
      setEditingId(newId);
      setEditText('在此輸入便簽內容...');
      if (onSelectTool) onSelectTool('select');
      return;
    }

    // Text Tool (T: 點擊畫布直接開啟文字輸入，立即輸入無障礙)
    if (currentTool === 'text') {
      // Check if user clicked an existing text object to edit directly
      const sorted = [...objects].sort((a, b) => b.zIndex - a.zIndex);
      const clickedText = sorted.find(
        (o) => (o.type === 'text' || o.type === 'sticky') && isPointInObject(worldPt, o)
      );
      if (clickedText) {
        setEditingId(clickedText.id);
        setEditText(clickedText.text || '');
        onSelectObjects([clickedText.id]);
        return;
      }

      // Activate inline text drafting directly at mouse position!
      setNewTextDraft({ x: Math.round(worldPt.x), y: Math.round(worldPt.y) });
      setDraftContent('');
      return;
    }

    // Pin Tool (Drops interactive, draggable Pushpin on canvas with custom naming)
    if (currentTool === 'pin') {
      const defaultName = `圖釘 #${(board.pins?.length || 0) + 1}`;
      setNewPinDraft({ x: Math.round(worldPt.x), y: Math.round(worldPt.y) });
      setNewPinDraftName(defaultName);
      return;
    }

    // Select Tool
    if (currentTool === 'select') {
      const sorted = [...objects].sort((a, b) => b.zIndex - a.zIndex);
      const clicked = sorted.find((o) => isPointInObject(worldPt, o));

      if (clicked) {
        const isMulti = e.shiftKey || e.metaKey || e.ctrlKey;
        let newSelected = [clicked.id];
        if (isMulti) {
          newSelected = selectedIds.includes(clicked.id)
            ? selectedIds.filter((id) => id !== clicked.id)
            : [...selectedIds, clicked.id];
        }
        onSelectObjects(newSelected);

        if (!clicked.isLocked) {
          const objsToMove = objects.filter((o) => newSelected.includes(o.id));
          let bMinX = Infinity, bMinY = Infinity, bMaxX = -Infinity, bMaxY = -Infinity;
          for (const o of objsToMove) {
            const ox = o.x1 !== undefined ? Math.min(o.x1, o.x2 ?? o.x1) : o.x;
            const oy = o.y1 !== undefined ? Math.min(o.y1, o.y2 ?? o.y1) : o.y;
            const ow = o.x1 !== undefined ? Math.abs((o.x2 ?? ox) - ox) : o.width;
            const oh = o.y1 !== undefined ? Math.abs((o.y2 ?? oy) - oy) : o.height;
            bMinX = Math.min(bMinX, ox);
            bMinY = Math.min(bMinY, oy);
            bMaxX = Math.max(bMaxX, ox + ow);
            bMaxY = Math.max(bMaxY, oy + oh);
          }
          setTransformState({
            type: 'move',
            startWorldX: worldPt.x,
            startWorldY: worldPt.y,
            initialObjects: objsToMove.map((o) => ({
              id: o.id,
              x: o.x,
              y: o.y,
              width: o.width,
              height: o.height,
              x1: o.x1,
              y1: o.y1,
              x2: o.x2,
              y2: o.y2,
            })),
            initialBBox: {
              minX: bMinX,
              minY: bMinY,
              maxX: bMaxX,
              maxY: bMaxY,
              width: Math.max(1, bMaxX - bMinX),
              height: Math.max(1, bMaxY - bMinY),
            },
          });
        }
      } else {
        if (!e.shiftKey) {
          onSelectObjects([]);
        }
        setMarquee({
          startX: worldPt.x,
          startY: worldPt.y,
          currentX: worldPt.x,
          currentY: worldPt.y,
        });
      }
      (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
    }
  };

  // Eraser handler helper
  const handleEraseAtPoint = (worldPt: Point) => {
    if (eraserMode === 'object') {
      const hit = objects.filter((o) => !o.isLocked && isPointInObject(worldPt, o, 16)).map((o) => o.id);
      if (hit.length > 0) {
        onDeleteObjects(hit);
      }
    } else {
      const eraserRadius = 14;
      for (const obj of objects) {
        if (obj.isLocked || (obj.type !== 'stroke' && obj.type !== 'highlighter' && obj.type !== 'paint') || !obj.points) {
          if (!obj.isLocked && isPointInObject(worldPt, obj, 10)) {
            onDeleteObjects([obj.id]);
          }
          continue;
        }
        try {
          const pts: Point[] = JSON.parse(obj.points);
          const segments = erasePointsAtPoint(pts, worldPt, eraserRadius);
          if (segments.length === 0) {
            onDeleteObjects([obj.id]);
          } else if (segments.length === 1 && segments[0].length !== pts.length) {
            onUpdateObject(obj.id, { points: JSON.stringify(segments[0]) });
          } else if (segments.length > 1) {
            onUpdateObject(obj.id, { points: JSON.stringify(segments[0]) });
            for (let i = 1; i < segments.length; i++) {
              const newSegmentId = 'stroke_split_' + Date.now() + '_' + i;
              const bbox = computeBoundingBox(segments[i], obj.strokeWidth);
              onAddObject({
                ...obj,
                id: newSegmentId,
                x: bbox.minX,
                y: bbox.minY,
                width: bbox.width,
                height: bbox.height,
                points: JSON.stringify(segments[i]),
                updatedAt: new Date().toISOString(),
              });
            }
          }
        } catch {
          // ignore
        }
      }
    }
  };

  // Pointer Move
  const handlePointerMove = (e: React.PointerEvent) => {
    if (isPanning) {
      const dx = e.clientX - panStartRef.current.x;
      const dy = e.clientY - panStartRef.current.y;
      onUpdateViewport({
        x: panStartRef.current.viewX + dx,
        y: panStartRef.current.viewY + dy,
        zoom: viewport.zoom,
      });
      return;
    }

    const screenPt: Point = { x: e.clientX, y: e.clientY, pressure: e.pressure || 0.5 };
    let worldPt = screenToWorld(e.clientX, e.clientY);

    // Ruler snap check
    if (ruler.enabled && (currentTool === 'pen' || currentTool === 'highlighter' || currentTool === 'line')) {
      const { snapped, screenPt: snappedScreen } = snapToScreenRulerEdge(screenPt, ruler);
      if (snapped) {
        worldPt = screenToWorld(snappedScreen.x, snappedScreen.y);
      }
    }

    onPointerTrack(worldPt.x, worldPt.y, !!currentStroke);

    // Range Export box drag
    if (isSelectingExportRange && isDraggingExportRangeRef.current && rangeExportBox) {
      setRangeExportBox((prev) => (prev ? { ...prev, currentX: worldPt.x, currentY: worldPt.y } : null));
      return;
    }

    // Physical pin dragging across canvas
    if (draggingPinId) {
      if (onUpdatePin) {
        onUpdatePin(draggingPinId, {
          x: Math.round(worldPt.x),
          y: Math.round(worldPt.y),
        });
      }
      return;
    }

    // Eraser drag
    if (currentTool === 'eraser' && e.buttons === 1) {
      handleEraseAtPoint(worldPt);
      return;
    }

    // Line Endpoint dragging (Handle A or Handle B)
    if (lineHandleDrag) {
      const obj = objects.find((o) => o.id === lineHandleDrag.objectId);
      if (obj) {
        if (lineHandleDrag.endpoint === 'A') {
          const newX1 = Math.round(worldPt.x);
          const newY1 = Math.round(worldPt.y);
          const x2 = obj.x2 ?? obj.x + obj.width;
          const y2 = obj.y2 ?? obj.y + obj.height;
          onUpdateObject(obj.id, {
            x1: newX1,
            y1: newY1,
            x: Math.min(newX1, x2),
            y: Math.min(newY1, y2),
            width: Math.abs(x2 - newX1),
            height: Math.abs(y2 - newY1),
          });
        } else {
          const x1 = obj.x1 ?? obj.x;
          const y1 = obj.y1 ?? obj.y;
          const newX2 = Math.round(worldPt.x);
          const newY2 = Math.round(worldPt.y);
          onUpdateObject(obj.id, {
            x2: newX2,
            y2: newY2,
            x: Math.min(x1, newX2),
            y: Math.min(y1, newY2),
            width: Math.abs(newX2 - x1),
            height: Math.abs(newY2 - y1),
          });
        }
      }
      return;
    }

    // Freehand stroke
    if (currentStroke) {
      const nextStroke = currentStrokeRef.current ?? currentStroke;
      const nativeEvent = e.nativeEvent as PointerEvent;
      const coalescedSamples = nativeEvent.getCoalescedEvents?.() ?? [];
      const samples = coalescedSamples.length > 0 ? coalescedSamples : [nativeEvent];
      const appendSample = (sample: PointerEvent) => {
        const sampleScreen: Point = {
          x: sample.clientX,
          y: sample.clientY,
          pressure: sample.pressure || 0.5,
        };
        let sampleWorld = screenToWorld(sample.clientX, sample.clientY);
        if (ruler.enabled && (currentTool === 'pen' || currentTool === 'highlighter' || currentTool === 'paint')) {
          const { snapped, screenPt: snappedScreen } = snapToScreenRulerEdge(sampleScreen, ruler);
          if (snapped) sampleWorld = screenToWorld(snappedScreen.x, snappedScreen.y);
        }

        const previous = nextStroke[nextStroke.length - 1];
        const screenDistance = Math.hypot(sampleWorld.x - previous.x, sampleWorld.y - previous.y) * viewport.zoom;
        if (screenDistance < 0.35) return;
        nextStroke.push(sampleWorld);

        if (lastMovePosRef.current) {
          const jitter = Math.hypot(
            sampleWorld.x - lastMovePosRef.current.x,
            sampleWorld.y - lastMovePosRef.current.y
          );
          if (jitter > 8) {
            lastMovePosRef.current = sampleWorld;
            setSnappedShape(null);
            clearHoldTimer();
            holdTimerRef.current = window.setTimeout(() => {
              const latestStroke = currentStrokeRef.current;
              if (latestStroke && latestStroke.length >= 5) {
                const recognized = recognizeGoodnotesShape(latestStroke);
                if (recognized) setSnappedShape(recognized);
              }
            }, 850);
          }
        }
      };

      for (const sample of samples) appendSample(sample);
      // Some browsers exclude the dispatching pointer event from the coalesced list.
      const lastSample = samples[samples.length - 1];
      if (lastSample.clientX !== e.clientX || lastSample.clientY !== e.clientY) {
        appendSample(nativeEvent);
      }
      currentStrokeRef.current = nextStroke;
      freehandPreviewRef.current?.setPoints(nextStroke);
      return;
    }

    // Direct line or shape drag
    if (shapeStart) {
      setShapeCurrent(worldPt);
      return;
    }

    // Marquee
    if (marquee) {
      setMarquee((prev) => (prev ? { ...prev, currentX: worldPt.x, currentY: worldPt.y } : null));
      const minX = Math.min(marquee.startX, worldPt.x);
      const maxX = Math.max(marquee.startX, worldPt.x);
      const minY = Math.min(marquee.startY, worldPt.y);
      const maxY = Math.max(marquee.startY, worldPt.y);
      const matched = objects.filter((o) => isObjectInMarquee(o, minX, minY, maxX, maxY)).map((o) => o.id);
      onSelectObjects(matched);
      return;
    }

    // Move or Resize non-line objects
    if (transformState) {
      const dx = worldPt.x - transformState.startWorldX;
      const dy = worldPt.y - transformState.startWorldY;

      if (transformState.type === 'move') {
        for (const init of transformState.initialObjects) {
          if (init.x1 !== undefined && init.x2 !== undefined) {
            onUpdateObject(init.id, {
              x1: Math.round(init.x1 + dx),
              y1: Math.round((init.y1 || 0) + dy),
              x2: Math.round(init.x2 + dx),
              y2: Math.round((init.y2 || 0) + dy),
              x: Math.round(init.x + dx),
              y: Math.round(init.y + dy),
            });
          } else {
            onUpdateObject(init.id, {
              x: Math.round(init.x + dx),
              y: Math.round(init.y + dy),
            });
          }
        }
      } else if (transformState.type === 'resize' && transformState.handle) {
        const h = transformState.handle;
        const bbox = transformState.initialBBox;

        let scaleX = 1;
        let scaleY = 1;
        let anchorX = bbox.minX;
        let anchorY = bbox.minY;

        if (h.includes('r')) {
          scaleX = Math.max(0.05, (bbox.width + dx) / bbox.width);
          anchorX = bbox.minX;
        } else if (h.includes('l')) {
          scaleX = Math.max(0.05, (bbox.width - dx) / bbox.width);
          anchorX = bbox.maxX;
        }

        if (h.includes('b')) {
          scaleY = Math.max(0.05, (bbox.height + dy) / bbox.height);
          anchorY = bbox.minY;
        } else if (h.includes('t')) {
          scaleY = Math.max(0.05, (bbox.height - dy) / bbox.height);
          anchorY = bbox.maxY;
        }

        for (const init of transformState.initialObjects) {
          const relX = init.x - anchorX;
          const relY = init.y - anchorY;

          let newX = anchorX + relX * scaleX;
          let newY = anchorY + relY * scaleY;
          let newW = Math.max(10, Math.round(init.width * scaleX));
          let newH = Math.max(10, Math.round(init.height * scaleY));

          if (h.includes('l')) newX = anchorX - (bbox.maxX - init.x) * scaleX;
          if (h.includes('t')) newY = anchorY - (bbox.maxY - init.y) * scaleY;

          if (init.x1 !== undefined && init.x2 !== undefined) {
            const rx1 = init.x1 - anchorX;
            const ry1 = (init.y1 || 0) - anchorY;
            const rx2 = init.x2 - anchorX;
            const ry2 = (init.y2 || 0) - anchorY;
            onUpdateObject(init.id, {
              x1: Math.round(anchorX + rx1 * scaleX),
              y1: Math.round(anchorY + ry1 * scaleY),
              x2: Math.round(anchorX + rx2 * scaleX),
              y2: Math.round(anchorY + ry2 * scaleY),
              x: Math.round(newX),
              y: Math.round(newY),
              width: newW,
              height: newH,
            });
          } else {
            onUpdateObject(init.id, {
              x: Math.round(newX),
              y: Math.round(newY),
              width: newW,
              height: newH,
            });
          }
        }
      } else if (transformState.type === 'rotate') {
        const center = transformState.center || {
          x: (transformState.initialBBox.minX + transformState.initialBBox.maxX) / 2,
          y: (transformState.initialBBox.minY + transformState.initialBBox.maxY) / 2,
        };
        const currentAngle = Math.atan2(worldPt.y - center.y, worldPt.x - center.x) * 180 / Math.PI;
        const delta = currentAngle - (transformState.startAngle || 0);

        for (const init of transformState.initialObjects) {
          const initRot = init.rotation || 0;
          const newRot = Math.round((initRot + delta) % 360);
          onUpdateObject(init.id, { rotation: newRot });
        }
      }
    }
  };

  // Pointer Up
  const handlePointerUp = (e: React.PointerEvent) => {
    (e.target as HTMLElement).releasePointerCapture?.(e.pointerId);
    clearHoldTimer();

    if (isPanning) {
      setIsPanning(false);
      return;
    }

    if (isSelectingExportRange && isDraggingExportRangeRef.current) {
      isDraggingExportRangeRef.current = false;
      return;
    }

    const pointerUpWorldPt = screenToWorld(e.clientX, e.clientY);
    onPointerTrack(pointerUpWorldPt.x, pointerUpWorldPt.y, false);

    if (currentStrokeRef.current && (currentTool === 'pen' || currentTool === 'highlighter' || currentTool === 'paint')) {
      const screenPt: Point = { x: e.clientX, y: e.clientY, pressure: e.pressure || 0.5 };
      let finalWorldPt = pointerUpWorldPt;
      if (ruler.enabled) {
        const { snapped, screenPt: snappedScreen } = snapToScreenRulerEdge(screenPt, ruler);
        if (snapped) finalWorldPt = screenToWorld(snappedScreen.x, snappedScreen.y);
      }
      const latestStroke = currentStrokeRef.current;
      const lastPoint = latestStroke[latestStroke.length - 1];
      if (Math.hypot(finalWorldPt.x - lastPoint.x, finalWorldPt.y - lastPoint.y) * viewport.zoom >= 0.35) {
        latestStroke.push(finalWorldPt);
        freehandPreviewRef.current?.setPoints(latestStroke);
      }
    }
    if (currentStrokeRef.current) freehandPreviewRef.current?.finish();

    if (draggingPinId) {
      setDraggingPinId(null);
      return;
    }

    if (lineHandleDrag) {
      setLineHandleDrag(null);
      return;
    }

    // Finalize Freehand or GoodNotes Snapped Shape
    if (snappedShape) {
      const isHighlighter = currentTool === 'highlighter';
      if (snappedShape.type === 'line') {
        const newLine: BoardObject = {
          id: 'line_' + Date.now(),
          boardId: board.id,
          type: 'line',
          x1: snappedShape.x,
          y1: snappedShape.y,
          x2: snappedShape.x + snappedShape.width,
          y2: snappedShape.y + snappedShape.height,
          x: Math.min(snappedShape.x, snappedShape.x + snappedShape.width),
          y: Math.min(snappedShape.y, snappedShape.y + snappedShape.height),
          width: Math.abs(snappedShape.width),
          height: Math.abs(snappedShape.height),
          extension: 'none',
          strokeColor: isHighlighter ? (activeColor || '#facc15') : (activeColor || '#ffffff'),
          fillColor: 'none',
          strokeWidth: isHighlighter ? Math.max(12, activeStrokeWidth * 2) : activeStrokeWidth,
          lineStyle: activeLineStyle,
          opacity: isHighlighter ? (activeOpacity || 0.4) : (activeOpacity ?? 1),
          rotation: 0,
          zIndex: objects.length + 1,
          createdBy: currentUserId || 'anonymous',
          updatedAt: new Date().toISOString(),
        };
        onAddObject(newLine);
        onSelectObjects([newLine.id]);
      } else {
        const newShape: BoardObject = {
          id: snappedShape.type + '_' + Date.now(),
          boardId: board.id,
          type: snappedShape.type as any,
          x: snappedShape.x,
          y: snappedShape.y,
          width: snappedShape.width,
          height: snappedShape.height,
          strokeColor: isHighlighter ? (activeColor || '#facc15') : (activeColor || '#ffffff'),
          fillColor: 'none',
          strokeWidth: isHighlighter ? Math.max(12, activeStrokeWidth * 2) : activeStrokeWidth,
          lineStyle: activeLineStyle,
          opacity: isHighlighter ? (activeOpacity || 0.4) : (activeOpacity ?? 1),
          rotation: 0,
          zIndex: objects.length + 1,
          createdBy: currentUserId || 'anonymous',
          updatedAt: new Date().toISOString(),
        };
        onAddObject(newShape);
        onSelectObjects([newShape.id]);
      }
      currentStrokeRef.current = null;
      setCurrentStroke(null);
      setSnappedShape(null);
      return;
    }

    const completedStroke = currentStrokeRef.current ?? currentStroke;
    if (completedStroke && completedStroke.length > 0) {
      const bbox = computeBoundingBox(completedStroke, activeStrokeWidth);
      const isHighlighter = currentTool === 'highlighter';
      const newStroke: BoardObject = {
        id: 'stroke_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6),
        boardId: board.id,
        type: isHighlighter ? 'highlighter' : 'stroke',
        x: bbox.minX,
        y: bbox.minY,
        width: bbox.width,
        height: bbox.height,
        points: JSON.stringify(completedStroke),
        strokeColor: isHighlighter ? (activeColor || '#facc15') : (activeColor || '#ffffff'),
        fillColor: 'none',
        strokeWidth: isHighlighter ? Math.max(12, activeStrokeWidth * 2) : activeStrokeWidth,
        opacity: isHighlighter ? (activeOpacity || 0.4) : (activeOpacity ?? 1),
        rotation: 0,
        zIndex: objects.length + 1,
        createdBy: currentUserId || 'anonymous',
        updatedAt: new Date().toISOString(),
      };
      onAddObject(newStroke);
      currentStrokeRef.current = null;
      setCurrentStroke(null);
      return;
    }

    // Finalize Direct Line or Arrow: STORES TRUE x1, y1, x2, y2!
    if (shapeStart && shapeCurrent) {
      if (currentTool === 'line' || currentTool === 'arrow') {
        const x1 = Math.round(shapeStart.x);
        const y1 = Math.round(shapeStart.y);
        const x2 = Math.round(shapeCurrent.x);
        const y2 = Math.round(shapeCurrent.y);

        const newLine: BoardObject = {
          id: currentTool + '_' + Date.now(),
          boardId: board.id,
          type: currentTool,
          x1,
          y1,
          x2,
          y2,
          x: Math.min(x1, x2),
          y: Math.min(y1, y2),
          width: Math.abs(x2 - x1),
          height: Math.abs(y2 - y1),
          extension: 'none',
          strokeColor: activeColor || '#ffffff',
          fillColor: 'none',
          strokeWidth: activeStrokeWidth || 3,
          lineStyle: activeLineStyle,
          opacity: 1,
          rotation: 0,
          zIndex: objects.length + 1,
          createdBy: currentUserId || 'anonymous',
          updatedAt: new Date().toISOString(),
        };
        onAddObject(newLine);
        onSelectObjects([newLine.id]);
      } else {
        const minX = Math.min(shapeStart.x, shapeCurrent.x);
        const minY = Math.min(shapeStart.y, shapeCurrent.y);
        const width = Math.max(10, Math.abs(shapeCurrent.x - shapeStart.x));
        const height = Math.max(10, Math.abs(shapeCurrent.y - shapeStart.y));

        const newShape: BoardObject = {
          id: currentTool + '_' + Date.now(),
          boardId: board.id,
          type: currentTool as any,
          x: Math.round(minX),
          y: Math.round(minY),
          width: Math.round(width),
          height: Math.round(height),
          strokeColor: activeColor || '#ffffff',
          fillColor: 'none',
          strokeWidth: activeStrokeWidth || 3,
          lineStyle: activeLineStyle,
          opacity: 1,
          rotation: 0,
          zIndex: objects.length + 1,
          createdBy: currentUserId || 'anonymous',
          updatedAt: new Date().toISOString(),
        };
        onAddObject(newShape);
        onSelectObjects([newShape.id]);
      }
      setShapeStart(null);
      setShapeCurrent(null);
      return;
    }

    if (marquee) setMarquee(null);
    if (transformState) setTransformState(null);
  };

  // Start Line Handle Drag
  const handleLineHandlePointerDown = (obj: BoardObject, endpoint: 'A' | 'B', e: React.PointerEvent) => {
    e.stopPropagation();
    const x1 = obj.x1 ?? obj.x;
    const y1 = obj.y1 ?? obj.y;
    const x2 = obj.x2 ?? obj.x + obj.width;
    const y2 = obj.y2 ?? obj.y + obj.height;

    setLineHandleDrag({
      objectId: obj.id,
      endpoint,
      initialX1: x1,
      initialY1: y1,
      initialX2: x2,
      initialY2: y2,
    });
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };

  // Resize handle pointer down
  const handleResizePointerDown = (handle: string, e: React.PointerEvent) => {
    e.stopPropagation();
    const worldPt = screenToWorld(e.clientX, e.clientY);
    const selectedObjs = objects.filter((o) => selectedIds.includes(o.id));
    if (selectedObjs.length === 0) return;

    let bMinX = Infinity, bMinY = Infinity, bMaxX = -Infinity, bMaxY = -Infinity;
    for (const o of selectedObjs) {
      if (o.type === 'line' || o.type === 'arrow') {
        const x1 = o.x1 ?? o.x;
        const y1 = o.y1 ?? o.y;
        const x2 = o.x2 ?? (o.x + o.width);
        const y2 = o.y2 ?? (o.y + o.height);
        bMinX = Math.min(bMinX, Math.min(x1, x2));
        bMinY = Math.min(bMinY, Math.min(y1, y2));
        bMaxX = Math.max(bMaxX, Math.max(x1, x2));
        bMaxY = Math.max(bMaxY, Math.max(y1, y2));
      } else {
        bMinX = Math.min(bMinX, o.x);
        bMinY = Math.min(bMinY, o.y);
        bMaxX = Math.max(bMaxX, o.x + o.width);
        bMaxY = Math.max(bMaxY, o.y + o.height);
      }
    }

    setTransformState({
      type: 'resize',
      handle,
      startWorldX: worldPt.x,
      startWorldY: worldPt.y,
      initialObjects: selectedObjs.map((o) => ({
        id: o.id,
        x: o.x,
        y: o.y,
        width: o.width,
        height: o.height,
        rotation: o.rotation || 0,
        x1: o.x1,
        y1: o.y1,
        x2: o.x2,
        y2: o.y2,
      })),
      initialBBox: {
        minX: bMinX,
        minY: bMinY,
        maxX: bMaxX,
        maxY: bMaxY,
        width: Math.max(1, bMaxX - bMinX),
        height: Math.max(1, bMaxY - bMinY),
      },
    });
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };

  // Rotate handle pointer down
  const handleRotatePointerDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    const worldPt = screenToWorld(e.clientX, e.clientY);
    const selectedObjs = objects.filter((o) => selectedIds.includes(o.id));
    if (selectedObjs.length === 0) return;

    let bMinX = Infinity, bMinY = Infinity, bMaxX = -Infinity, bMaxY = -Infinity;
    for (const o of selectedObjs) {
      if (o.type === 'line' || o.type === 'arrow') {
        const x1 = o.x1 ?? o.x;
        const y1 = o.y1 ?? o.y;
        const x2 = o.x2 ?? (o.x + o.width);
        const y2 = o.y2 ?? (o.y + o.height);
        bMinX = Math.min(bMinX, Math.min(x1, x2));
        bMinY = Math.min(bMinY, Math.min(y1, y2));
        bMaxX = Math.max(bMaxX, Math.max(x1, x2));
        bMaxY = Math.max(bMaxY, Math.max(y1, y2));
      } else {
        bMinX = Math.min(bMinX, o.x);
        bMinY = Math.min(bMinY, o.y);
        bMaxX = Math.max(bMaxX, o.x + o.width);
        bMaxY = Math.max(bMaxY, o.y + o.height);
      }
    }

    const centerX = (bMinX + bMaxX) / 2;
    const centerY = (bMinY + bMaxY) / 2;
    const startAngle = Math.atan2(worldPt.y - centerY, worldPt.x - centerX) * 180 / Math.PI;

    setTransformState({
      type: 'rotate',
      handle: 'rotate',
      startWorldX: worldPt.x,
      startWorldY: worldPt.y,
      center: { x: centerX, y: centerY },
      startAngle,
      initialObjects: selectedObjs.map((o) => ({
        id: o.id,
        x: o.x,
        y: o.y,
        width: o.width,
        height: o.height,
        rotation: o.rotation || 0,
        x1: o.x1,
        y1: o.y1,
        x2: o.x2,
        y2: o.y2,
      })),
      initialBBox: {
        minX: bMinX,
        minY: bMinY,
        maxX: bMaxX,
        maxY: bMaxY,
        width: Math.max(1, bMaxX - bMinX),
        height: Math.max(1, bMaxY - bMinY),
      },
    });
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };

  const handleDoubleClick = (obj: BoardObject) => {
    if (obj.type === 'text' || obj.type === 'sticky') {
      setEditingId(obj.id);
      setEditText(obj.text || '');
    } else if (obj.type === 'image') {
      if (onCropImage) onCropImage(obj);
    }
  };

  const handleFinishEditing = () => {
    if (editingId) {
      if (!editText.trim()) {
        onDeleteObjects([editingId]);
        onSelectObjects([]);
      } else {
        onUpdateObject(editingId, { text: editText });
      }
      setEditingId(null);
    }
  };

  // Check if exactly one Line or Arrow is selected
  const selectedObjects = objects.filter((o) => selectedIds.includes(o.id) && o.isVisible !== false);
  const isSingleLineSelected = selectedObjects.length === 1 && (selectedObjects[0].type === 'line' || selectedObjects[0].type === 'arrow');
  const singleLineObj = isSingleLineSelected ? selectedObjects[0] : null;

  // Selection tight Bounding Box (For all objects including lines and images)
  let selectionBox: { minX: number; minY: number; maxX: number; maxY: number; width: number; height: number } | null = null;
  if (selectedObjects.length > 0) {
    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;
    for (const obj of selectedObjects) {
      if (obj.type === 'line' || obj.type === 'arrow') {
        const x1 = obj.x1 ?? obj.x;
        const y1 = obj.y1 ?? obj.y;
        const x2 = obj.x2 ?? (obj.x + obj.width);
        const y2 = obj.y2 ?? (obj.y + obj.height);
        minX = Math.min(minX, Math.min(x1, x2));
        minY = Math.min(minY, Math.min(y1, y2));
        maxX = Math.max(maxX, Math.max(x1, x2));
        maxY = Math.max(maxY, Math.max(y1, y2));
      } else {
        minX = Math.min(minX, obj.x);
        minY = Math.min(minY, obj.y);
        maxX = Math.max(maxX, obj.x + obj.width);
        maxY = Math.max(maxY, obj.y + obj.height);
      }
    }
    selectionBox = {
      minX,
      minY,
      maxX,
      maxY,
      width: Math.max(1, maxX - minX),
      height: Math.max(1, maxY - minY),
    };
  }

  // Render Background Grid
  const renderBackgroundPattern = () => {
    const gridStyle = board.gridStyle || 'grid';
    if (gridStyle === 'blank') return null;

    const patternSize = 32 * viewport.zoom;
    const strokeColor = board.boardTheme === 'whiteboard' ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.09)';
    const dotColor = board.boardTheme === 'whiteboard' ? 'rgba(0,0,0,0.18)' : 'rgba(255,255,255,0.18)';

    if (gridStyle === 'dots') {
      return (
        <svg className="absolute inset-0 w-full h-full pointer-events-none">
          <defs>
            <pattern
              id="dot-pattern"
              x={viewport.x % patternSize}
              y={viewport.y % patternSize}
              width={patternSize}
              height={patternSize}
              patternUnits="userSpaceOnUse"
            >
              <circle cx={patternSize / 2} cy={patternSize / 2} r={1.5} fill={dotColor} />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#dot-pattern)" />
        </svg>
      );
    }

    if (gridStyle === 'lines') {
      return (
        <svg className="absolute inset-0 w-full h-full pointer-events-none">
          <defs>
            <pattern
              id="line-pattern"
              x={viewport.x % patternSize}
              y={viewport.y % patternSize}
              width={patternSize}
              height={patternSize}
              patternUnits="userSpaceOnUse"
            >
              <line x1="0" y1={patternSize} x2={patternSize} y2={patternSize} stroke={strokeColor} strokeWidth="1" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#line-pattern)" />
        </svg>
      );
    }

    return (
      <svg className="absolute inset-0 w-full h-full pointer-events-none">
        <defs>
          <pattern
            id="grid-pattern"
            x={viewport.x % patternSize}
            y={viewport.y % patternSize}
            width={patternSize}
            height={patternSize}
            patternUnits="userSpaceOnUse"
          >
            <path d={`M ${patternSize} 0 L 0 0 0 ${patternSize}`} fill="none" stroke={strokeColor} strokeWidth="1" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid-pattern)" />
      </svg>
    );
  };

  return (
    <div
      ref={containerRef}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onDoubleClick={(e) => {
        const worldPt = screenToWorld(e.clientX, e.clientY);
        const sorted = [...objects].sort((a, b) => b.zIndex - a.zIndex);
        const clicked = sorted.find((o) => isPointInObject(worldPt, o));
        if (clicked) {
          handleDoubleClick(clicked);
        } else if (!isSelectingExportRange && currentTool === 'select') {
          // Double click on blank canvas: create new text draft immediately!
          setNewTextDraft({ x: Math.round(worldPt.x), y: Math.round(worldPt.y) });
          setDraftContent('');
        }
      }}
      className={`relative w-full h-full overflow-hidden select-none ${
        isSpacePressed || isPanning
          ? 'cursor-grab active:cursor-grabbing'
          : isSelectingExportRange
          ? 'cursor-crosshair'
          : currentTool === 'select'
          ? 'cursor-default'
          : currentTool === 'eraser'
          ? 'cursor-cell'
          : 'cursor-crosshair'
      }`}
      style={{
        backgroundColor: board.canvasMode === 'infinite' ? (board.backgroundColor || '#172e25') : '#262930',
        touchAction: 'none',
      }}
    >
      {/* Infinite Canvas Background Grid (覆蓋全螢幕，無限畫布全幅展開，無邊界限制) */}
      {board.canvasMode === 'infinite' && renderBackgroundPattern()}

      {/* Fixed Canvas Paper Surface (固定尺寸紙張：A4、16:9 等，外圍為老鼠灰工作區) */}
      {board.canvasMode === 'fixed' && (
        <div
          className="absolute rounded-3xl overflow-hidden pointer-events-none border-2 border-white/20 shadow-2xl transition-all"
          style={{
            left: `${viewport.x}px`,
            top: `${viewport.y}px`,
            width: `${(board.canvasWidth || 1920) * viewport.zoom}px`,
            height: `${(board.canvasHeight || 1080) * viewport.zoom}px`,
            backgroundColor: board.backgroundColor || '#172e25',
            boxShadow: '0 35px 90px -15px rgba(0,0,0,0.9), 0 0 0 1px rgba(255,255,255,0.12)',
          }}
        >
          {/* Inner Grid Pattern within the paper */}
          {renderBackgroundPattern()}
          <div className="absolute top-3 left-4 px-2.5 py-1 rounded-lg bg-black/60 text-neutral-300 text-[10px] font-mono border border-white/10 flex items-center gap-1.5 backdrop-blur-md">
            <span className="w-1.5 h-1.5 rounded-full bg-cyan-400" />
            <span>
              {board.canvasPreset === 'a4_landscape'
                ? 'A4 橫向'
                : board.canvasPreset === 'a4_portrait'
                ? 'A4 直向'
                : board.canvasPreset === '16_9'
                ? '16:9 簡報'
                : board.canvasPreset === 'a3_landscape'
                ? 'A3 橫向'
                : board.canvasPreset === '4_3'
                ? '4:3 課堂'
                : '固定規格紙張'}{' '}
              ({board.canvasWidth || 1920} × {board.canvasHeight || 1080})
            </span>
          </div>
        </div>
      )}

      {/* Main Canvas SVG Layer */}
      <svg
        className="absolute inset-0 w-full h-full pointer-events-none"
        style={{
          transform: `translate3d(${viewport.x}px, ${viewport.y}px, 0) scale(${viewport.zoom})`,
          transformOrigin: '0 0',
        }}
      >
        {/* Render Saved Objects */}
        {[...objects]
          .sort((a, b) => a.zIndex - b.zIndex)
          .map((obj) => {
            if (obj.isVisible === false) return null;
            const rot = obj.rotation || 0;
            const transform = rot !== 0 ? `rotate(${rot} ${obj.x + obj.width / 2} ${obj.y + obj.height / 2})` : '';
            const isDashed = obj.lineStyle === 'dashed';
            const dashArray = isDashed ? '8 6' : undefined;

            switch (obj.type) {
              case 'stroke':
              case 'highlighter': {
                if (!obj.points) return null;
                try {
                  const pts: Point[] = JSON.parse(obj.points);
                  const d = pointsToSvgPath(pts);
                  return (
                    <path
                      key={obj.id}
                      d={d}
                      stroke={obj.strokeColor}
                      strokeWidth={obj.strokeWidth}
                      fill="none"
                      opacity={obj.opacity ?? 1}
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      transform={transform}
                    />
                  );
                } catch {
                  return null;
                }
              }
              case 'line': {
                const x1 = obj.x1 !== undefined ? obj.x1 : obj.x;
                const y1 = obj.y1 !== undefined ? obj.y1 : obj.y;
                const x2 = obj.x2 !== undefined ? obj.x2 : obj.x + obj.width;
                const y2 = obj.y2 !== undefined ? obj.y2 : obj.y + obj.height;
                const { rx1, ry1, rx2, ry2 } = computeLineRenderCoordinates(x1, y1, x2, y2, obj.extension);

                return (
                  <line
                    key={obj.id}
                    x1={rx1}
                    y1={ry1}
                    x2={rx2}
                    y2={ry2}
                    stroke={obj.strokeColor}
                    strokeWidth={obj.strokeWidth}
                    strokeDasharray={dashArray}
                    strokeLinecap="round"
                    opacity={obj.opacity ?? 1}
                    transform={transform}
                  />
                );
              }
              case 'arrow': {
                const x1 = obj.x1 !== undefined ? obj.x1 : obj.x;
                const y1 = obj.y1 !== undefined ? obj.y1 : obj.y;
                const x2 = obj.x2 !== undefined ? obj.x2 : obj.x + obj.width;
                const y2 = obj.y2 !== undefined ? obj.y2 : obj.y + obj.height;
                const { rx1, ry1, rx2, ry2 } = computeLineRenderCoordinates(x1, y1, x2, y2, obj.extension);

                const angle = Math.atan2(ry2 - ry1, rx2 - rx1);
                const arrowLen = Math.max(14, obj.strokeWidth * 3);
                const arrowAngle = Math.PI / 6;
                const ax1 = rx2 - arrowLen * Math.cos(angle - arrowAngle);
                const ay1 = ry2 - arrowLen * Math.sin(angle - arrowAngle);
                const ax2 = rx2 - arrowLen * Math.cos(angle + arrowAngle);
                const ay2 = ry2 - arrowLen * Math.sin(angle + arrowAngle);

                return (
                  <g key={obj.id} opacity={obj.opacity ?? 1} transform={transform}>
                    <line
                      x1={rx1}
                      y1={ry1}
                      x2={rx2}
                      y2={ry2}
                      stroke={obj.strokeColor}
                      strokeWidth={obj.strokeWidth}
                      strokeDasharray={dashArray}
                      strokeLinecap="round"
                    />
                    <polygon points={`${rx2},${ry2} ${ax1},${ay1} ${ax2},${ay2}`} fill={obj.strokeColor} />
                  </g>
                );
              }
              case 'rect': {
                return (
                  <rect
                    key={obj.id}
                    x={obj.x}
                    y={obj.y}
                    width={obj.width}
                    height={obj.height}
                    fill={obj.fillColor || 'none'}
                    stroke={obj.strokeColor}
                    strokeWidth={obj.strokeWidth}
                    strokeDasharray={dashArray}
                    opacity={obj.opacity ?? 1}
                    rx="6"
                    transform={transform}
                  />
                );
              }
              case 'circle': {
                const cx = obj.x + obj.width / 2;
                const cy = obj.y + obj.height / 2;
                return (
                  <ellipse
                    key={obj.id}
                    cx={cx}
                    cy={cy}
                    rx={Math.abs(obj.width) / 2}
                    ry={Math.abs(obj.height) / 2}
                    fill={obj.fillColor || 'none'}
                    stroke={obj.strokeColor}
                    strokeWidth={obj.strokeWidth}
                    strokeDasharray={dashArray}
                    opacity={obj.opacity ?? 1}
                    transform={transform}
                  />
                );
              }
              case 'triangle': {
                const p1 = `${obj.x + obj.width / 2},${obj.y}`;
                const p2 = `${obj.x},${obj.y + obj.height}`;
                const p3 = `${obj.x + obj.width},${obj.y + obj.height}`;
                return (
                  <polygon
                    key={obj.id}
                    points={`${p1} ${p2} ${p3}`}
                    fill={obj.fillColor || 'none'}
                    stroke={obj.strokeColor}
                    strokeWidth={obj.strokeWidth}
                    strokeDasharray={dashArray}
                    opacity={obj.opacity ?? 1}
                    strokeLinejoin="round"
                    transform={transform}
                  />
                );
              }
              case 'star': {
                const cx = obj.x + obj.width / 2;
                const cy = obj.y + obj.height / 2;
                const rOut = Math.min(obj.width, obj.height) / 2;
                const rIn = rOut * 0.45;
                let ptsStr = '';
                for (let i = 0; i < 10; i++) {
                  const r = i % 2 === 0 ? rOut : rIn;
                  const a = (i * Math.PI) / 5 - Math.PI / 2;
                  ptsStr += `${cx + r * Math.cos(a)},${cy + r * Math.sin(a)} `;
                }
                return (
                  <polygon
                    key={obj.id}
                    points={ptsStr.trim()}
                    fill={obj.fillColor || 'none'}
                    stroke={obj.strokeColor}
                    strokeWidth={obj.strokeWidth}
                    strokeDasharray={dashArray}
                    opacity={obj.opacity ?? 1}
                    strokeLinejoin="round"
                    transform={transform}
                  />
                );
              }
              case 'sticky': {
                if (editingId === obj.id) return null;
                const style = obj.stickyStyle || 'classic';
                const fillColor = obj.fillColor && obj.fillColor !== 'none' ? obj.fillColor : '#fef08a';
                const textColor = obj.strokeColor || '#1f2937';

                return (
                  <foreignObject
                    key={obj.id}
                    x={obj.x}
                    y={obj.y}
                    width={obj.width}
                    height={obj.height}
                    transform={transform}
                    opacity={obj.opacity ?? 1}
                    onDoubleClick={() => handleDoubleClick(obj)}
                    className="pointer-events-auto cursor-pointer"
                  >
                    <div
                      className={`w-full h-full relative p-3.5 flex flex-col justify-start overflow-hidden select-none transition-shadow ${
                        style === 'classic'
                          ? 'rounded-2xl shadow-lg border border-black/10'
                          : style === 'washi'
                          ? 'rounded-2xl shadow-md border border-neutral-700/20'
                          : style === 'cat'
                          ? 'rounded-2xl shadow-lg border-2 border-amber-400/30'
                          : style === 'notebook'
                          ? 'rounded-xl shadow-md border border-sky-400/30'
                          : style === 'grid'
                          ? 'rounded-2xl shadow-md border border-emerald-400/30'
                          : 'rounded-3xl shadow-xl border border-white/20'
                      }`}
                      style={{
                        backgroundColor: fillColor,
                        color: textColor,
                      }}
                    >
                      {/* Cute Style Decorative Headers */}
                      {style === 'washi' && (
                        <div
                          className="absolute -top-1 left-1/2 -translate-x-1/2 w-16 h-3 rounded-sm shadow-sm opacity-90 pointer-events-none"
                          style={{
                            background: 'repeating-linear-gradient(45deg, #f472b6, #f472b6 6px, #fb7185 6px, #fb7185 12px)',
                          }}
                        />
                      )}
                      {style === 'cat' && (
                        <div className="absolute top-1 right-2 flex items-center gap-0.5 text-xs opacity-80 pointer-events-none">
                          <span>🐾</span>
                        </div>
                      )}
                      {style === 'notebook' && (
                        <div className="absolute top-0 left-0 right-0 h-2.5 flex items-center justify-around px-3 opacity-60 pointer-events-none">
                          <span className="w-1.5 h-1.5 rounded-full bg-neutral-600" />
                          <span className="w-1.5 h-1.5 rounded-full bg-neutral-600" />
                          <span className="w-1.5 h-1.5 rounded-full bg-neutral-600" />
                          <span className="w-1.5 h-1.5 rounded-full bg-neutral-600" />
                        </div>
                      )}
                      {style === 'grid' && (
                        <div
                          className="absolute inset-0 opacity-10 pointer-events-none"
                          style={{
                            backgroundImage: 'linear-gradient(#000 1px, transparent 1px), linear-gradient(90deg, #000 1px, transparent 1px)',
                            backgroundSize: '12px 12px',
                          }}
                        />
                      )}
                      {style === 'classic' && (
                        <div
                          className="absolute bottom-0 right-0 w-4 h-4 pointer-events-none"
                          style={{
                            background: 'linear-gradient(135deg, transparent 50%, rgba(0,0,0,0.18) 50%)',
                          }}
                        />
                      )}

                      {/* Text strictly wrapped and clipped within sticky boundary - never overflows! */}
                      <div
                        className="w-full flex-1 overflow-hidden font-sans leading-relaxed tracking-tight"
                        style={{
                          fontSize: `${obj.fontSize || 15}px`,
                          wordBreak: 'break-word',
                          overflowWrap: 'break-word',
                          whiteSpace: 'pre-wrap',
                          maxHeight: '100%',
                        }}
                      >
                        {obj.text || ''}
                      </div>
                    </div>
                  </foreignObject>
                );
              }
              case 'text': {
                if (editingId === obj.id) return null;
                const lines = (obj.text || '').split('\n');
                let textDecor = 'none';
                if (obj.isUnderline && obj.isStrikethrough) textDecor = 'underline line-through';
                else if (obj.isUnderline) textDecor = 'underline';
                else if (obj.isStrikethrough) textDecor = 'line-through';

                const hasHighlight = obj.highlightColor && obj.highlightColor !== 'none' && obj.highlightColor !== 'transparent';
                const fontSize = obj.fontSize || 20;

                return (
                  <g
                    key={obj.id}
                    onDoubleClick={() => handleDoubleClick(obj)}
                    transform={transform}
                    opacity={obj.opacity ?? 1}
                    className="pointer-events-auto cursor-pointer select-none"
                  >
                    {hasHighlight && (
                      <rect
                        x={obj.x - 4}
                        y={obj.y}
                        width={Math.max(obj.width, (obj.text?.length || 1) * fontSize * 0.6) + 8}
                        height={Math.max(obj.height, fontSize * 1.35 * Math.max(1, lines.length))}
                        fill={obj.highlightColor}
                        opacity={0.55}
                        rx="4"
                      />
                    )}
                    <text
                      x={obj.x}
                      y={obj.y + fontSize}
                      fontFamily={obj.fontFamily || 'system-ui, sans-serif'}
                      fontSize={fontSize}
                      fontWeight={obj.isBold ? 'bold' : 'normal'}
                      fontStyle={obj.isItalic ? 'italic' : 'normal'}
                      textDecoration={textDecor}
                      fill={obj.strokeColor}
                    >
                      {lines.map((l, idx) => (
                        <tspan key={idx} x={obj.x} dy={idx === 0 ? 0 : '1.3em'}>
                          {l}
                        </tspan>
                      ))}
                    </text>
                  </g>
                );
              }
              case 'image': {
                return (
                  <g
                    key={obj.id}
                    onDoubleClick={() => onCropImage && onCropImage(obj)}
                    className="cursor-pointer"
                    transform={transform}
                  >
                    <image
                      href={obj.imageUrl}
                      x={obj.x}
                      y={obj.y}
                      width={obj.width}
                      height={obj.height}
                      preserveAspectRatio="none"
                      opacity={obj.opacity ?? 1}
                    />
                  </g>
                );
              }
              default:
                return null;
            }
          })}

        {/* Imperative memoized preview avoids rerendering every board object per pointer sample. */}
        <FreehandPreview
          ref={freehandPreviewRef}
          visible={!!currentStroke && !snappedShape}
          color={currentTool === 'highlighter' ? (activeColor || '#facc15') : activeColor}
          width={currentTool === 'highlighter' ? Math.max(12, activeStrokeWidth * 2) : activeStrokeWidth}
          opacity={currentTool === 'highlighter' ? (activeOpacity || 0.4) : (activeOpacity ?? 1)}
        />

        {/* GoodNotes Snapped Shape Preview */}
        {snappedShape && (
          <g>
            {snappedShape.type === 'line' ? (
              <line
                x1={snappedShape.x}
                y1={snappedShape.y}
                x2={snappedShape.x + snappedShape.width}
                y2={snappedShape.y + snappedShape.height}
                stroke={activeColor || '#ffffff'}
                strokeWidth={activeStrokeWidth || 3}
                strokeLinecap="round"
              />
            ) : snappedShape.type === 'circle' ? (
              <ellipse
                cx={snappedShape.x + snappedShape.width / 2}
                cy={snappedShape.y + snappedShape.height / 2}
                rx={snappedShape.width / 2}
                ry={snappedShape.height / 2}
                fill="none"
                stroke={activeColor || '#ffffff'}
                strokeWidth={activeStrokeWidth || 3}
              />
            ) : (
              <rect
                x={snappedShape.x}
                y={snappedShape.y}
                width={snappedShape.width}
                height={snappedShape.height}
                fill="none"
                stroke={activeColor || '#ffffff'}
                strokeWidth={activeStrokeWidth || 3}
                rx="6"
              />
            )}
          </g>
        )}

        {/* Direct Line / Arrow Dragging Preview */}
        {shapeStart && shapeCurrent && (currentTool === 'line' || currentTool === 'arrow') && (
          <g>
            <line
              x1={shapeStart.x}
              y1={shapeStart.y}
              x2={shapeCurrent.x}
              y2={shapeCurrent.y}
              stroke={activeColor || '#ffffff'}
              strokeWidth={activeStrokeWidth || 3}
              strokeDasharray={activeLineStyle === 'dashed' ? '8 6' : undefined}
              strokeLinecap="round"
            />
            {currentTool === 'arrow' && (
              (() => {
                const angle = Math.atan2(shapeCurrent.y - shapeStart.y, shapeCurrent.x - shapeStart.x);
                const arrowLen = Math.max(14, activeStrokeWidth * 3);
                const arrowAngle = Math.PI / 6;
                const ax1 = shapeCurrent.x - arrowLen * Math.cos(angle - arrowAngle);
                const ay1 = shapeCurrent.y - arrowLen * Math.sin(angle - arrowAngle);
                const ax2 = shapeCurrent.x - arrowLen * Math.cos(angle + arrowAngle);
                const ay2 = shapeCurrent.y - arrowLen * Math.sin(angle + arrowAngle);
                return (
                  <polygon
                    points={`${shapeCurrent.x},${shapeCurrent.y} ${ax1},${ay1} ${ax2},${ay2}`}
                    fill={activeColor || '#ffffff'}
                  />
                );
              })()
            )}
          </g>
        )}

        {/* Direct Rect / Circle Dragging Preview */}
        {shapeStart && shapeCurrent && ['rect', 'circle', 'triangle', 'star'].includes(currentTool) && (
          (() => {
            const minX = Math.min(shapeStart.x, shapeCurrent.x);
            const minY = Math.min(shapeStart.y, shapeCurrent.y);
            const w = Math.abs(shapeCurrent.x - shapeStart.x);
            const h = Math.abs(shapeCurrent.y - shapeStart.y);
            if (currentTool === 'circle') {
              return (
                <ellipse
                  cx={minX + w / 2}
                  cy={minY + h / 2}
                  rx={w / 2}
                  ry={h / 2}
                  fill="none"
                  stroke={activeColor || '#ffffff'}
                  strokeWidth={activeStrokeWidth || 3}
                  strokeDasharray={activeLineStyle === 'dashed' ? '8 6' : undefined}
                />
              );
            }
            return (
              <rect
                x={minX}
                y={minY}
                width={w}
                height={h}
                fill="none"
                stroke={activeColor || '#ffffff'}
                strokeWidth={activeStrokeWidth || 3}
                strokeDasharray={activeLineStyle === 'dashed' ? '8 6' : undefined}
                rx="6"
              />
            );
          })()
        )}

        {/* Marquee Drag Box */}
        {marquee && (
          <rect
            x={Math.min(marquee.startX, marquee.currentX)}
            y={Math.min(marquee.startY, marquee.currentY)}
            width={Math.abs(marquee.currentX - marquee.startX)}
            height={Math.abs(marquee.currentY - marquee.startY)}
            fill="rgba(59, 130, 246, 0.15)"
            stroke="#3b82f6"
            strokeWidth="1.5"
            strokeDasharray="4 2"
          />
        )}
      </svg>

      {/* Line Endpoint A & B Interactive Drag Handles (解決直線方框思維的根本錯誤！) */}
      {singleLineObj && currentTool === 'select' && (
        (() => {
          const x1 = singleLineObj.x1 ?? singleLineObj.x;
          const y1 = singleLineObj.y1 ?? singleLineObj.y;
          const x2 = singleLineObj.x2 ?? singleLineObj.x + singleLineObj.width;
          const y2 = singleLineObj.y2 ?? singleLineObj.y + singleLineObj.height;

          const sA = worldToScreen(x1, y1);
          const sB = worldToScreen(x2, y2);

          return (
            <div className="absolute inset-0 pointer-events-none z-30">
              {/* Handle A (起點 A 控制鈕) */}
              <div
                onPointerDown={(e) => handleLineHandlePointerDown(singleLineObj, 'A', e)}
                className="absolute w-5 h-5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-blue-500 border-2 border-white shadow-xl pointer-events-auto cursor-move hover:scale-125 transition-transform flex items-center justify-center text-[9px] font-bold text-white"
                style={{ left: `${sA.x}px`, top: `${sA.y}px` }}
                title="直線端點 A (拖曳可任意改變長度與角度，不變形)"
              >
                A
              </div>

              {/* Handle B (終點 B 控制鈕) */}
              <div
                onPointerDown={(e) => handleLineHandlePointerDown(singleLineObj, 'B', e)}
                className="absolute w-5 h-5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-blue-500 border-2 border-white shadow-xl pointer-events-auto cursor-move hover:scale-125 transition-transform flex items-center justify-center text-[9px] font-bold text-white"
                style={{ left: `${sB.x}px`, top: `${sB.y}px` }}
                title="直線端點 B (拖曳可任意改變長度與角度，不變形)"
              >
                B
              </div>
            </div>
          );
        })()
      )}

      {/* Selection Bounding Box, 8 Handles & Rotation Handle */}
      {selectionBox && currentTool === 'select' && (
        <div
          className="absolute pointer-events-none z-20 border-2 border-blue-500/90 rounded-sm shadow-sm"
          style={{
            left: `${selectionBox.minX * viewport.zoom + viewport.x}px`,
            top: `${selectionBox.minY * viewport.zoom + viewport.y}px`,
            width: `${selectionBox.width * viewport.zoom}px`,
            height: `${selectionBox.height * viewport.zoom}px`,
          }}
        >
          {/* Rotation Handle Connector Stem */}
          <div className="absolute left-1/2 -top-6 w-[1.5px] h-6 bg-blue-500 -translate-x-1/2 pointer-events-none" />

          {/* Rotation Handle with Custom Circular Arrow Cursor */}
          <div
            onPointerDown={handleRotatePointerDown}
            style={{
              cursor: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'%3E%3Cpath d='M21 12a9 9 0 1 1-9-9c2.52 0 4.85.83 6.72 2.24' fill='none' stroke='white' stroke-width='4' stroke-linecap='round'/%3E%3Cpolyline points='21 3 21 8 16 8' fill='none' stroke='white' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/%3E%3Cpath d='M21 12a9 9 0 1 1-9-9c2.52 0 4.85.83 6.72 2.24' fill='none' stroke='%230f172a' stroke-width='1.8' stroke-linecap='round'/%3E%3Cpolyline points='21 3 21 8 16 8' fill='none' stroke='%230f172a' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") 12 12, grab`,
            }}
            className="absolute left-1/2 -top-6 -translate-x-1/2 -translate-y-1/2 w-4 h-4 bg-white border-2 border-blue-600 rounded-full shadow-md pointer-events-auto hover:scale-125 transition-transform flex items-center justify-center group"
            title="旋轉控制點 (拖曳可旋轉物件)"
          >
            <div className="w-1.5 h-1.5 rounded-full bg-blue-600 pointer-events-none" />
          </div>

          {/* 8 Perimeter Resize Handles */}
          {[
            { id: 'tl', class: '-left-2 -top-2 cursor-nwse-resize', title: '左上角 (斜邊拉長縮短)' },
            { id: 'tm', class: 'left-1/2 -translate-x-1/2 -top-2 cursor-ns-resize', title: '頂部 (上下拉長縮短)' },
            { id: 'tr', class: '-right-2 -top-2 cursor-nesw-resize', title: '右上角 (斜邊拉長縮短)' },
            { id: 'mr', class: '-right-2 top-1/2 -translate-y-1/2 cursor-ew-resize', title: '右側 (左右拉長縮短)' },
            { id: 'br', class: '-right-2 -bottom-2 cursor-nwse-resize', title: '右下角 (斜邊拉長縮短)' },
            { id: 'bm', class: 'left-1/2 -translate-x-1/2 -bottom-2 cursor-ns-resize', title: '底部 (上下拉長縮短)' },
            { id: 'bl', class: '-left-2 -bottom-2 cursor-nesw-resize', title: '左下角 (斜邊拉長縮短)' },
            { id: 'ml', class: '-left-2 top-1/2 -translate-y-1/2 cursor-ew-resize', title: '左側 (左右拉長縮短)' },
          ].map((h) => (
            <div
              key={h.id}
              onPointerDown={(e) => handleResizePointerDown(h.id, e)}
              title={h.title}
              className={`absolute w-3.5 h-3.5 bg-white border-2 border-blue-600 rounded-sm shadow-md pointer-events-auto hover:scale-125 transition-transform ${h.class}`}
            />
          ))}
        </div>
      )}

      {/* Inline Text / Sticky Editing Overlay */}
      {editingId && (
        (() => {
          const obj = objects.find((o) => o.id === editingId);
          if (!obj) return null;
          const screen = worldToScreen(obj.x, obj.y);

          return (
            <div
              onPointerDown={(e) => e.stopPropagation()}
              onMouseDown={(e) => e.stopPropagation()}
              onClick={(e) => e.stopPropagation()}
              className="absolute z-40 pointer-events-auto"
              style={{
                left: `${screen.x}px`,
                top: `${screen.y}px`,
              }}
            >
              <textarea
                autoFocus
                value={editText}
                onChange={(e) => setEditText(e.target.value)}
                onCompositionStart={() => {
                  isComposingRef.current = true;
                }}
                onCompositionEnd={() => {
                  isComposingRef.current = false;
                }}
                onBlur={handleFinishEditing}
                onKeyDown={(e) => {
                  if (isComposingRef.current) return;
                  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
                    handleFinishEditing();
                  } else if (e.key === 'Escape') {
                    setEditingId(null);
                  }
                }}
                className="p-2.5 rounded-xl bg-neutral-900 text-white border-2 border-blue-500 shadow-2xl outline-none resize-none font-sans select-text cursor-text"
                style={{
                  width: `${Math.max(160, obj.width * viewport.zoom)}px`,
                  height: `${Math.max(60, obj.height * viewport.zoom)}px`,
                  fontSize: `${(obj.fontSize || 18) * viewport.zoom}px`,
                }}
              />
              <div className="flex items-center gap-1.5 mt-1">
                <button
                  type="button"
                  onMouseDown={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    handleFinishEditing();
                  }}
                  className="px-2.5 py-0.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-[11px] font-bold shadow cursor-pointer"
                >
                  ✓ 完成
                </button>
              </div>
            </div>
          );
        })()
      )}

      {/* Ephemeral New Text Draft Overlay (Auto-disappears if empty on blur/escape!) */}
      {newTextDraft && (
        (() => {
          const screen = worldToScreen(newTextDraft.x, newTextDraft.y);

          const commitNewDraft = () => {
            if (draftContent.trim()) {
              const newId = 'text_' + Date.now();
              const newObj: BoardObject = {
                id: newId,
                boardId: board.id,
                type: 'text',
                x: newTextDraft.x,
                y: newTextDraft.y,
                width: Math.max(160, draftContent.length * 16),
                height: 48,
                strokeColor: activeColor || '#ffffff',
                fillColor: 'none',
                strokeWidth: 1,
                opacity: 1,
                rotation: 0,
                zIndex: objects.length + 1,
                text: draftContent,
                fontSize: 24,
                fontFamily: 'system-ui, sans-serif',
                createdBy: currentUserId || 'anonymous',
                updatedAt: new Date().toISOString(),
              };
              onAddObject(newObj);
              onSelectObjects([newId]);
              if (onSelectTool) onSelectTool('select');
            }
            setNewTextDraft(null);
            setDraftContent('');
          };

          return (
            <div
              onPointerDown={(e) => e.stopPropagation()}
              onMouseDown={(e) => e.stopPropagation()}
              onClick={(e) => e.stopPropagation()}
              className="absolute z-40 pointer-events-auto"
              style={{
                left: `${screen.x}px`,
                top: `${screen.y}px`,
              }}
            >
              <textarea
                ref={draftTextareaRef}
                autoFocus
                placeholder="在此輸入文字... (Enter 完成 / Shift+Enter 換行 / 點空白處自動儲存)"
                value={draftContent}
                onChange={(e) => setDraftContent(e.target.value)}
                onCompositionStart={() => {
                  isComposingRef.current = true;
                }}
                onCompositionEnd={() => {
                  isComposingRef.current = false;
                }}
                onBlur={() => {
                  commitNewDraft();
                }}
                onKeyDown={(e) => {
                  if (isComposingRef.current) return;
                  if (e.key === 'Escape') {
                    setNewTextDraft(null);
                    setDraftContent('');
                  } else if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    commitNewDraft();
                  }
                }}
                className="p-3 rounded-2xl bg-neutral-900/95 backdrop-blur-xl border-2 border-cyan-400 text-white shadow-2xl outline-none resize-none font-sans min-w-[280px] min-h-[70px] select-text cursor-text"
                style={{
                  fontSize: `${24 * viewport.zoom}px`,
                  color: activeColor || '#ffffff',
                }}
              />
              <div className="flex items-center gap-1.5 mt-1.5">
                <button
                  type="button"
                  onMouseDown={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    commitNewDraft();
                  }}
                  className="px-3 py-1 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow flex items-center gap-1 cursor-pointer"
                >
                  ✓ 完成 (Enter)
                </button>
                <button
                  type="button"
                  onMouseDown={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    setNewTextDraft(null);
                    setDraftContent('');
                  }}
                  className="px-3 py-1 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-neutral-300 text-xs font-medium cursor-pointer"
                >
                  ✕ 取消 (Esc)
                </button>
              </div>
            </div>
          );
        })()
      )}

      {/* Ephemeral New Pin Naming Dialog on Canvas (自訂圖釘名稱) */}
      {newPinDraft && (
        (() => {
          const screen = worldToScreen(newPinDraft.x, newPinDraft.y);
          const handleConfirmPin = () => {
            const finalName = newPinDraftName.trim() || `圖釘 #${(board.pins?.length || 0) + 1}`;
            if (onAddPin) {
              onAddPin(finalName, newPinDraft.x, newPinDraft.y, viewport.zoom);
            }
            setNewPinDraft(null);
            setNewPinDraftName('');
            if (onSelectTool) onSelectTool('select');
          };

          return (
            <div
              onPointerDown={(e) => e.stopPropagation()}
              className="absolute z-40 pointer-events-auto -translate-x-4 -translate-y-14 bg-neutral-900/98 backdrop-blur-xl border border-rose-500/80 rounded-2xl p-3 shadow-2xl flex flex-col gap-2 min-w-[240px] animate-in fade-in zoom-in-95 duration-100"
              style={{ left: `${screen.x}px`, top: `${screen.y}px` }}
            >
              <div className="flex items-center gap-1.5 text-xs font-bold text-rose-300">
                <Pin className="w-3.5 h-3.5 rotate-45 text-rose-400" />
                <span>設定圖釘名稱</span>
              </div>
              <input
                type="text"
                autoFocus
                placeholder="輸入圖釘名稱 (如：解題公式、重點大綱)..."
                value={newPinDraftName}
                onChange={(e) => setNewPinDraftName(e.target.value)}
                onKeyDown={(e) => {
                  e.stopPropagation();
                  if (e.key === 'Enter') handleConfirmPin();
                  if (e.key === 'Escape') setNewPinDraft(null);
                }}
                className="px-2.5 py-1.5 rounded-xl bg-neutral-800 border border-neutral-700 text-xs text-white placeholder-neutral-500 outline-none focus:border-rose-400"
              />
              <div className="flex items-center justify-end gap-1.5">
                <button
                  type="button"
                  onClick={() => setNewPinDraft(null)}
                  className="px-2.5 py-1 rounded-lg text-neutral-400 hover:text-white hover:bg-neutral-800 text-xs transition-colors"
                >
                  取消
                </button>
                <button
                  type="button"
                  onClick={handleConfirmPin}
                  className="px-3.5 py-1 rounded-lg bg-rose-600 hover:bg-rose-500 text-white font-bold text-xs shadow transition-colors"
                >
                  ✓ 釘上
                </button>
              </div>
            </div>
          );
        })()
      )}

      {/* Custom Range Export Box on Infinite/Bounded Canvas (自訂框選輸出範圍) */}
      {isSelectingExportRange && rangeExportBox && (
        (() => {
          const minX = Math.min(rangeExportBox.startX, rangeExportBox.currentX);
          const maxX = Math.max(rangeExportBox.startX, rangeExportBox.currentX);
          const minY = Math.min(rangeExportBox.startY, rangeExportBox.currentY);
          const maxY = Math.max(rangeExportBox.startY, rangeExportBox.currentY);
          const width = maxX - minX;
          const height = maxY - minY;
          if (width < 6 && height < 6) return null;

          const sMin = worldToScreen(minX, minY);
          const sW = width * viewport.zoom;
          const sH = height * viewport.zoom;

          return (
            <div
              className="absolute z-40 border-2 border-dashed border-cyan-400 bg-cyan-500/10 pointer-events-auto rounded-lg shadow-2xl"
              style={{
                left: `${sMin.x}px`,
                top: `${sMin.y}px`,
                width: `${sW}px`,
                height: `${sH}px`,
              }}
            >
              {/* Floating Action Bar above the selection */}
              <div className="absolute -top-12 left-0 flex items-center gap-1.5 px-3 py-1.5 rounded-2xl bg-neutral-900/98 backdrop-blur-xl border border-cyan-400 text-white shadow-2xl text-xs whitespace-nowrap">
                <span className="font-mono text-cyan-300 font-bold">
                  {Math.round(width)} × {Math.round(height)} px
                </span>
                <div className="h-3 w-[1px] bg-neutral-700 mx-1" />
                <button
                  type="button"
                  onClick={() => onExportCustomRange?.({ minX, minY, maxX, maxY }, 'svg')}
                  className="px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-medium"
                >
                  匯出 SVG
                </button>
                <button
                  type="button"
                  onClick={() => onExportCustomRange?.({ minX, minY, maxX, maxY }, 'png')}
                  className="px-2.5 py-1 rounded-lg bg-blue-600 hover:bg-blue-500 text-white font-medium"
                >
                  匯出 PNG
                </button>
                <button
                  type="button"
                  onClick={() => onExportCustomRange?.({ minX, minY, maxX, maxY }, 'pdf')}
                  className="px-2.5 py-1 rounded-lg bg-purple-600 hover:bg-purple-500 text-white font-medium"
                >
                  匯出 PDF
                </button>
                <button
                  type="button"
                  onClick={onCancelExportRange}
                  className="px-2 py-1 rounded-lg bg-neutral-800 hover:bg-neutral-700 text-neutral-300"
                >
                  ✕ 取消 (Esc)
                </button>
              </div>
            </div>
          );
        })()
      )}

      {/* Interactive Physical Pushpin Objects on Canvas (可拖拉，點擊平滑移動置於左上方視角，點名稱可自訂修改) */}
      {board.pins &&
        board.pins.map((pin) => {
          const screen = worldToScreen(pin.x, pin.y);
          const isRenaming = editingPinId === pin.id;

          const handleSavePinName = () => {
            if (editingPinName.trim() && onUpdatePin) {
              onUpdatePin(pin.id, { name: editingPinName.trim() });
            }
            setEditingPinId(null);
          };

          return (
            <div
              key={pin.id}
              style={{
                left: `${screen.x}px`,
                top: `${screen.y}px`,
              }}
              onPointerDown={(e) => {
                if (isRenaming) return;
                e.stopPropagation();
                setDraggingPinId(pin.id);
                (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
              }}
              className="absolute -translate-x-3.5 -translate-y-8 z-30 select-none group pointer-events-auto cursor-grab active:cursor-grabbing hover:scale-105 transition-transform"
              title={`實體圖釘：${pin.name} (可自由拖拉位置，點擊名稱自訂修改，點擊按鈕平滑移動置於左上方視角)`}
            >
              <div className="flex items-center gap-1.5">
                {/* 3D Pushpin Icon & Tip */}
                <div className="flex flex-col items-center">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-rose-600 to-red-400 border-2 border-white shadow-xl flex items-center justify-center text-white">
                    <Pin className="w-4 h-4 rotate-45 filter drop-shadow" />
                  </div>
                  <div className="w-1.5 h-3 bg-neutral-300 -mt-0.5 rounded-b-sm border border-neutral-600 shadow" />
                </div>

                {/* Pin Name Badge & Quick Jump */}
                <div className="bg-neutral-900/95 backdrop-blur-md border border-neutral-700/80 px-2.5 py-1 rounded-xl shadow-xl flex items-center gap-1.5 text-xs text-white">
                  {isRenaming ? (
                    <input
                      type="text"
                      autoFocus
                      value={editingPinName}
                      onChange={(e) => setEditingPinName(e.target.value)}
                      onKeyDown={(e) => {
                        e.stopPropagation();
                        if (e.key === 'Enter') handleSavePinName();
                        if (e.key === 'Escape') setEditingPinId(null);
                      }}
                      onBlur={handleSavePinName}
                      className="w-24 px-1.5 py-0.5 bg-neutral-800 border border-rose-500 rounded text-xs text-white outline-none"
                    />
                  ) : (
                    <span
                      onClick={(e) => {
                        e.stopPropagation();
                        setEditingPinId(pin.id);
                        setEditingPinName(pin.name);
                      }}
                      className="font-semibold max-w-[120px] truncate cursor-pointer hover:text-rose-300 hover:underline"
                      title="點擊修改圖釘名稱"
                    >
                      {pin.name}
                    </span>
                  )}

                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      if (onJumpToPin) onJumpToPin(pin);
                    }}
                    className="p-1 rounded-lg hover:bg-neutral-800 text-rose-400 hover:text-rose-300 transition-colors"
                    title="平滑移動置於左上方視角"
                  >
                    <CornerLeftUp className="w-3.5 h-3.5" />
                  </button>
                  {onDeletePin && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeletePin(pin.id);
                      }}
                      className="opacity-0 group-hover:opacity-100 p-1 rounded-lg hover:bg-red-500/20 text-neutral-400 hover:text-red-400 transition-opacity"
                      title="刪除圖釘"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}

      {/* Physical Acrylic Ruler Overlay */}
      <RulerOverlay
        ruler={ruler}
        onUpdateRuler={onUpdateRuler}
        onClose={() => onUpdateRuler({ enabled: false })}
      />

      {/* Collaborator Live Cursors */}
      <CollaboratorCursors
        presences={presences}
        currentUserId={currentUserId}
        viewport={viewport}
        visible={showCursors}
      />
    </div>
  );
};
