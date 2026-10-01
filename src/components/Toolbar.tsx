import React, { useState, useEffect, useRef } from 'react';
import { ToolType, EraserMode } from '../types';
import {
  MousePointer,
  Edit2,
  Highlighter,
  Eraser,
  Ruler,
  Square,
  Circle,
  Triangle,
  ArrowUpRight,
  Minus,
  Star,
  Type,
  StickyNote,
  Image as ImageIcon,
  Pin,
  Undo2,
  Redo2,
  ZoomIn,
  ZoomOut,
  Camera,
  Trash,
  ChevronUp,
  ChevronRight,
  GripHorizontal,
  GripVertical,
  Palette,
  Columns,
  Rows,
  Move,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  ArrowDown,
} from 'lucide-react';
import { CircularColorPicker } from './CircularColorPicker';

interface ToolbarProps {
  currentTool: ToolType;
  rulerEnabled: boolean;
  eraserMode: EraserMode;
  canUndo: boolean;
  canRedo: boolean;
  zoom: number;
  activeColor?: string;
  onChangeColor?: (color: string) => void;
  onSelectTool: (tool: ToolType) => void;
  onToggleRuler: () => void;
  onToggleEraserMode: () => void;
  onUploadImage: (file: File) => void;
  onOpenScreenCapture: () => void;
  onClearCanvas: () => void;
  onUndo: () => void;
  onRedo: () => void;
  onZoomIn: () => void;
  onZoomOut: () => void;
  onResetZoom: () => void;
}

const TOOLBAR_COLORS = [
  { id: 'rgba(23, 23, 23, 0.95)', name: '黑曜炭黑 (預設)', border: 'border-neutral-700/80' },
  { id: 'rgba(74, 78, 86, 0.96)', name: '老鼠灰工作室', border: 'border-neutral-500/80' },
  { id: 'rgba(20, 48, 38, 0.95)', name: '墨綠黑板', border: 'border-emerald-600/60' },
  { id: 'rgba(30, 41, 59, 0.95)', name: '科技深藍', border: 'border-blue-600/60' },
  { id: 'rgba(49, 27, 85, 0.95)', name: '尊爵紫金', border: 'border-purple-600/60' },
  { id: 'rgba(245, 245, 247, 0.94)', name: '晶瑩冰白 (淺色)', border: 'border-neutral-300' },
];

export const Toolbar: React.FC<ToolbarProps> = ({
  currentTool,
  rulerEnabled,
  eraserMode,
  canUndo,
  canRedo,
  zoom,
  onSelectTool,
  onToggleRuler,
  onToggleEraserMode,
  onUploadImage,
  onOpenScreenCapture,
  onClearCanvas,
  onUndo,
  onRedo,
  onZoomIn,
  onZoomOut,
  onResetZoom,
  activeColor,
  onChangeColor,
}) => {
  const [showShapeMenu, setShowShapeMenu] = useState(false);
  const [showEraserMenu, setShowEraserMenu] = useState(false);
  const [showColorPicker, setShowColorPicker] = useState(false);
  const [showCustomCircularPicker, setShowCustomCircularPicker] = useState(false);
  const [showBrushColorMenu, setShowBrushColorMenu] = useState(false);
  const [toolbarBgColor, setToolbarBgColor] = useState(() => {
    try {
      return localStorage.getItem('blackboard_toolbar_color') || 'rgba(23, 23, 23, 0.95)';
    } catch {
      return 'rgba(23, 23, 23, 0.95)';
    }
  });

  const handleUpdateToolbarColor = (color: string) => {
    setToolbarBgColor(color);
    try {
      localStorage.setItem('blackboard_toolbar_color', color);
    } catch {
      // ignore
    }
  };

  // Position & Draggable state
  // null = default docked at bottom center
  const [position, setPosition] = useState<{ x: number; y: number } | null>(() => {
    try {
      const saved = localStorage.getItem('blackboard_toolbar_pos');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });
  const [isDragging, setIsDragging] = useState(false);
  const dragOffsetRef = useRef<{ x: number; y: number }>({ x: 0, y: 0 });

  // Orientation: 'horizontal' vs 'vertical' (支援手動切換與側邊豎直排版)
  const [orientation, setOrientation] = useState<'horizontal' | 'vertical'>(() => {
    try {
      const saved = localStorage.getItem('blackboard_toolbar_orient') as 'horizontal' | 'vertical';
      return saved || 'horizontal';
    } catch {
      return 'horizontal';
    }
  });

  const [showDockMenu, setShowDockMenu] = useState(false);

  const handleDock = (loc: 'bottom' | 'top' | 'left' | 'right') => {
    const winW = window.innerWidth;
    const winH = window.innerHeight;
    let pos = { x: Math.round(winW / 2 - 240), y: winH - 90 };
    if (loc === 'bottom') {
      pos = { x: Math.round(winW / 2 - 240), y: winH - 90 };
      setOrientation('horizontal');
    } else if (loc === 'top') {
      pos = { x: Math.round(winW / 2 - 240), y: 70 };
      setOrientation('horizontal');
    } else if (loc === 'left') {
      pos = { x: 16, y: 120 };
      setOrientation('vertical');
    } else if (loc === 'right') {
      pos = { x: Math.max(20, winW - 74), y: 120 };
      setOrientation('vertical');
    }
    setPosition(pos);
    try {
      localStorage.setItem('blackboard_toolbar_pos', JSON.stringify(pos));
      localStorage.setItem('blackboard_toolbar_orient', loc === 'left' || loc === 'right' ? 'vertical' : 'horizontal');
    } catch {}
    setShowDockMenu(false);
  };

  // Determine orientation dynamically based on proximity to edges only if position exists and not user-pinned
  useEffect(() => {
    if (!position) return;
    const winW = window.innerWidth;
    const winH = window.innerHeight;

    const distTop = position.y;
    const distBottom = winH - (position.y + 60);
    const distLeft = position.x;
    const distRight = winW - (position.x + 60);

    const minDistY = Math.min(distTop, distBottom);
    const minDistX = Math.min(distLeft, distRight);

    // If clearly closer to left or right screen edge (< 120px) -> switch to vertical
    if (minDistX < 120 && minDistX < minDistY) {
      setOrientation('vertical');
    } else if (minDistY < 120 && minDistY <= minDistX) {
      setOrientation('horizontal');
    }
  }, [position]);

  // Global window listeners during dragging so dragging never drops or stutters
  useEffect(() => {
    if (!isDragging) return;

    const onWindowPointerMove = (e: PointerEvent) => {
      const winW = window.innerWidth;
      const winH = window.innerHeight;

      let newX = e.clientX - dragOffsetRef.current.x;
      let newY = e.clientY - dragOffsetRef.current.y;

      // Clamp within viewport
      newX = Math.max(10, Math.min(winW - 70, newX));
      newY = Math.max(10, Math.min(winH - 70, newY));

      const newPos = { x: newX, y: newY };
      setPosition(newPos);
      try {
        localStorage.setItem('blackboard_toolbar_pos', JSON.stringify(newPos));
      } catch {
        // ignore
      }
    };

    const onWindowPointerUp = () => {
      setIsDragging(false);
    };

    window.addEventListener('pointermove', onWindowPointerMove);
    window.addEventListener('pointerup', onWindowPointerUp);
    return () => {
      window.removeEventListener('pointermove', onWindowPointerMove);
      window.removeEventListener('pointerup', onWindowPointerUp);
    };
  }, [isDragging]);

  const handleDragHandlePointerDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    setIsDragging(true);

    const rect = e.currentTarget.parentElement?.getBoundingClientRect();
    if (rect) {
      dragOffsetRef.current = {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top,
      };
      if (!position) {
        setPosition({ x: rect.left, y: rect.top });
      }
    }
  };

  // Clicking an active tool button again turns it OFF and reverts to 'select'!
  const handleToolClick = (tool: ToolType) => {
    if (currentTool === tool) {
      onSelectTool('select');
    } else {
      onSelectTool(tool);
    }
  };

  const shapes: { id: ToolType; label: string; icon: React.ReactNode }[] = [
    { id: 'line', label: '直線', icon: <Minus className="w-4 h-4" /> },
    { id: 'arrow', label: '箭頭', icon: <ArrowUpRight className="w-4 h-4" /> },
    { id: 'rect', label: '矩形', icon: <Square className="w-4 h-4" /> },
    { id: 'circle', label: '圓形', icon: <Circle className="w-4 h-4" /> },
    { id: 'triangle', label: '三角形', icon: <Triangle className="w-4 h-4" /> },
    { id: 'star', label: '星形', icon: <Star className="w-4 h-4" /> },
  ];

  const handleImageFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      onUploadImage(file);
      e.target.value = '';
    }
  };

  const isShapeActive = ['rect', 'circle', 'triangle', 'arrow', 'line', 'star', 'diamond'].includes(
    currentTool
  );

  const stylePosition: React.CSSProperties = position
    ? {
        position: 'absolute',
        left: `${position.x}px`,
        top: `${position.y}px`,
        transform: 'none',
        backgroundColor: toolbarBgColor,
      }
    : {
        position: 'absolute',
        bottom: '20px',
        left: '50%',
        transform: 'translateX(-50%)',
        backgroundColor: toolbarBgColor,
      };

  const isRightSide = position ? position.x > window.innerWidth / 2 : false;

  return (
    <nav
      aria-label="白板工具列"
      style={stylePosition}
      className={`z-30 pointer-events-auto flex items-center backdrop-blur-xl border border-neutral-700/80 rounded-2xl shadow-2xl text-neutral-200 select-none transition-all ${
        orientation === 'horizontal' ? 'flex-row gap-1.5 px-3 py-2' : 'flex-col gap-1 p-2 w-14'
      }`}
    >
      {/* Draggable Drag Handle & Quick Docking (可任意拖曳放置或一鍵停靠側邊豎直) */}
      <div
        className={`relative flex items-center ${
          orientation === 'horizontal'
            ? 'border-r border-white/10 pr-1.5 gap-0.5'
            : 'border-b border-white/10 pb-1.5 flex-col gap-1 w-full'
        }`}
      >
        <div
          onPointerDown={handleDragHandlePointerDown}
          className="text-neutral-500 hover:text-white cursor-grab active:cursor-grabbing p-1 rounded-lg hover:bg-white/10 transition-colors flex items-center justify-center shrink-0"
          title="按住拖曳控制板 (可拖至螢幕任一處)"
        >
          {orientation === 'horizontal' ? (
            <GripVertical className="w-4 h-4" />
          ) : (
            <GripHorizontal className="w-4 h-4" />
          )}
        </div>
        <button
          type="button"
          onClick={() => setShowDockMenu(!showDockMenu)}
          className="text-neutral-500 hover:text-cyan-400 p-0.5 rounded hover:bg-white/10 transition-colors"
          title="快速停靠位置 (置底/置頂/靠左側邊/靠右側邊)"
        >
          <Move className="w-3.5 h-3.5" />
        </button>

        {showDockMenu && (
          <div
            className={`absolute z-50 w-36 bg-neutral-900/98 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-1.5 shadow-2xl space-y-1 text-xs animate-in fade-in duration-100 ${
              orientation === 'horizontal'
                ? 'bottom-12 left-0'
                : isRightSide
                ? 'right-16 top-0'
                : 'left-16 top-0'
            }`}
          >
            <div className="text-[10px] text-neutral-400 font-medium px-2 py-0.5">快速停靠:</div>
            <button
              onClick={() => handleDock('bottom')}
              className="w-full flex items-center gap-2 px-2 py-1 rounded-xl text-neutral-300 hover:bg-neutral-800 hover:text-white transition-colors"
            >
              <ArrowDown className="w-3 h-3 text-emerald-400" />
              <span>螢幕底部橫向</span>
            </button>
            <button
              onClick={() => handleDock('left')}
              className="w-full flex items-center gap-2 px-2 py-1 rounded-xl text-neutral-300 hover:bg-neutral-800 hover:text-white transition-colors"
            >
              <ArrowLeft className="w-3 h-3 text-amber-400" />
              <span>靠左側邊豎直</span>
            </button>
            <button
              onClick={() => handleDock('right')}
              className="w-full flex items-center gap-2 px-2 py-1 rounded-xl text-neutral-300 hover:bg-neutral-800 hover:text-white transition-colors"
            >
              <ArrowRight className="w-3 h-3 text-rose-400" />
              <span>靠右側邊豎直</span>
            </button>
            <button
              onClick={() => handleDock('top')}
              className="w-full flex items-center gap-2 px-2 py-1 rounded-xl text-neutral-300 hover:bg-neutral-800 hover:text-white transition-colors"
            >
              <ArrowUp className="w-3 h-3 text-cyan-400" />
              <span>螢幕頂部橫向</span>
            </button>
          </div>
        )}
      </div>

      {/* Undo & Redo */}
      <div
        className={`flex items-center shrink-0 ${
          orientation === 'horizontal'
            ? 'flex-row gap-0.5 border-r border-white/10 pr-1.5'
            : 'flex-col gap-0.5 border-b border-white/10 pb-1.5'
        }`}
      >
        <button
          onClick={onUndo}
          disabled={!canUndo}
          className={`p-2 rounded-xl transition-colors ${
            canUndo
              ? 'text-neutral-300 hover:text-white hover:bg-white/10'
              : 'text-neutral-600 cursor-not-allowed'
          }`}
          title="復原 (Ctrl+Z)"
        >
          <Undo2 className="w-4 h-4" />
        </button>
        <button
          onClick={onRedo}
          disabled={!canRedo}
          className={`p-2 rounded-xl transition-colors ${
            canRedo
              ? 'text-neutral-300 hover:text-white hover:bg-white/10'
              : 'text-neutral-600 cursor-not-allowed'
          }`}
          title="重做 (Ctrl+Y)"
        >
          <Redo2 className="w-4 h-4" />
        </button>
      </div>

      {/* Select / Move */}
      <button
        onClick={() => onSelectTool('select')}
        className={`p-2 rounded-xl flex items-center justify-center transition-all ${
          currentTool === 'select'
            ? 'bg-blue-600 text-white shadow-md shadow-blue-500/30'
            : 'text-neutral-400 hover:text-white hover:bg-white/10'
        }`}
        title="選取工具 (V) - 點選或框選物件"
      >
        <MousePointer className="w-4 h-4" />
      </button>

      {/* Pen (Freehand + Hold to shape) */}
      <button
        onClick={() => handleToolClick('pen')}
        className={`p-2 rounded-xl flex items-center justify-center transition-all ${
          currentTool === 'pen'
            ? 'bg-emerald-600 text-white shadow-md shadow-emerald-500/30'
            : 'text-neutral-400 hover:text-white hover:bg-white/10'
        }`}
        title={
          currentTool === 'pen'
            ? '向量畫筆 (啟用中，再次點擊切回選取工具)'
            : '向量畫筆 (P) - 畫完停留1秒自動轉直線/圓形'
        }
      >
        <Edit2 className="w-4 h-4" />
      </button>

      {/* Highlighter (真實螢光筆 ICON) */}
      <button
        onClick={() => handleToolClick('highlighter')}
        className={`p-2 rounded-xl flex items-center justify-center transition-all ${
          currentTool === 'highlighter'
            ? 'bg-yellow-600 text-white shadow-md shadow-yellow-500/30'
            : 'text-neutral-400 hover:text-white hover:bg-white/10'
        }`}
        title={
          currentTool === 'highlighter'
            ? '螢光筆 (啟用中，再次點擊切回選取工具)'
            : '螢光筆 (H) - 半透明重點標記'
        }
      >
        <Highlighter className="w-4 h-4" />
      </button>

      {/* Quick Active Color Swatch for Drawing Tools (工具列即時調色盤，不用到處找調色) */}
      {onChangeColor && (
        <div className="relative">
          <button
            type="button"
            onClick={() => setShowBrushColorMenu(!showBrushColorMenu)}
            className="w-6 h-6 rounded-full border-2 border-white/80 shadow-md hover:scale-125 transition-transform flex items-center justify-center p-0.5 shrink-0"
            style={{ backgroundColor: activeColor || '#ffffff' }}
            title={`目前畫筆/螢光筆色彩: ${activeColor} (點擊調整)`}
          >
            <div className="w-1.5 h-1.5 rounded-full bg-black/30 pointer-events-none" />
          </button>

          {showBrushColorMenu && (
            <div
              className={`absolute z-50 p-2 bg-neutral-900/98 backdrop-blur-xl border border-neutral-700/80 rounded-2xl shadow-2xl animate-in fade-in zoom-in-95 duration-100 ${
                orientation === 'horizontal'
                  ? 'bottom-12 -left-16'
                  : position && position.x > (window.innerWidth / 2)
                  ? 'right-14 top-0'
                  : 'left-14 top-0'
              }`}
            >
              <CircularColorPicker
                color={activeColor || '#ffffff'}
                onChange={(c) => {
                  onChangeColor(c);
                }}
                onClose={() => setShowBrushColorMenu(false)}
                title="調整畫筆 / 螢光筆顏色"
              />
            </div>
          )}
        </div>
      )}

      {/* Eraser */}
      <div className="relative">
        <button
          onClick={() => {
            if (currentTool === 'eraser') {
              setShowEraserMenu(!showEraserMenu);
            } else {
              onSelectTool('eraser');
            }
          }}
          className={`flex items-center gap-1 p-2 rounded-xl transition-all ${
            currentTool === 'eraser'
              ? 'bg-rose-600 text-white shadow-md shadow-rose-500/30'
              : 'text-neutral-400 hover:text-white hover:bg-white/10'
          }`}
          title={`橡皮擦 (E) - 目前為 [${eraserMode === 'object' ? '整筆刪除' : '像素擦除'}]`}
        >
          <Eraser className="w-4 h-4" />
          <span className="text-[9px] font-bold px-1 rounded bg-black/40">
            {eraserMode === 'object' ? '整筆' : '像素'}
          </span>
        </button>

        {showEraserMenu && (
          <div
            className={`absolute z-50 w-44 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-1.5 shadow-2xl space-y-1 ${
              orientation === 'horizontal' ? 'bottom-12 left-0' : isRightSide ? 'right-16 top-0' : 'left-16 top-0'
            }`}
          >
            <button
              onClick={() => {
                if (eraserMode !== 'object') onToggleEraserMode();
                setShowEraserMenu(false);
              }}
              className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-xl text-xs ${
                eraserMode === 'object'
                  ? 'bg-rose-600 text-white'
                  : 'text-neutral-300 hover:bg-neutral-800'
              }`}
            >
              <span>整筆物件橡皮擦</span>
              <span className="text-[10px] text-neutral-300">碰觸即刪</span>
            </button>
            <button
              onClick={() => {
                if (eraserMode !== 'pixel') onToggleEraserMode();
                setShowEraserMenu(false);
              }}
              className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-xl text-xs ${
                eraserMode === 'pixel'
                  ? 'bg-rose-600 text-white'
                  : 'text-neutral-300 hover:bg-neutral-800'
              }`}
            >
              <span>精細像素橡皮擦</span>
              <span className="text-[10px] text-neutral-300">擦除片段</span>
            </button>
          </div>
        )}
      </div>

      {/* Screen-spanning Ruler */}
      <button
        onClick={onToggleRuler}
        className={`p-2 rounded-xl flex items-center justify-center transition-all ${
          rulerEnabled
            ? 'bg-amber-600 text-white shadow-md shadow-amber-500/30'
            : 'text-neutral-400 hover:text-white hover:bg-white/10'
        }`}
        title={rulerEnabled ? '直尺規 (開啟中，點擊關閉)' : '螢幕壓克力直尺 (R)'}
      >
        <Ruler className="w-4 h-4" />
      </button>

      {/* Shapes (Straight Line A to B, Arrow, Rect...) */}
      <div className="relative">
        <button
          onClick={() => {
            if (isShapeActive) {
              onSelectTool('select');
              setShowShapeMenu(false);
            } else {
              setShowShapeMenu(!showShapeMenu);
            }
          }}
          className={`flex items-center gap-0.5 p-2 rounded-xl transition-all ${
            isShapeActive
              ? 'bg-purple-600 text-white shadow-md shadow-purple-500/30'
              : 'text-neutral-400 hover:text-white hover:bg-white/10'
          }`}
          title={isShapeActive ? '幾何圖形 (啟用中，點擊切回選取工具)' : '幾何圖形與直線 (S)'}
        >
          <Minus className="w-4 h-4" />
          {orientation === 'horizontal' ? (
            <ChevronUp className="w-3 h-3 text-neutral-400" />
          ) : (
            <ChevronRight className="w-3 h-3 text-neutral-400" />
          )}
        </button>

        {showShapeMenu && (
          <div
            className={`absolute z-50 w-36 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-1.5 shadow-2xl grid grid-cols-2 gap-1 ${
              orientation === 'horizontal' ? 'bottom-12 left-0' : isRightSide ? 'right-16 top-0' : 'left-16 top-0'
            }`}
          >
            {shapes.map((s) => (
              <button
                key={s.id}
                onClick={() => {
                  handleToolClick(s.id);
                  setShowShapeMenu(false);
                }}
                className={`flex items-center gap-1.5 px-2 py-1.5 rounded-xl text-xs transition-colors ${
                  currentTool === s.id
                    ? 'bg-purple-600 text-white'
                    : 'text-neutral-300 hover:bg-neutral-800 hover:text-white'
                }`}
              >
                {s.icon}
                <span className="text-[11px]">{s.label}</span>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Text Tool */}
      <button
        onClick={() => handleToolClick('text')}
        className={`p-2 rounded-xl flex items-center justify-center transition-all ${
          currentTool === 'text'
            ? 'bg-pink-600 text-white shadow-md shadow-pink-500/30'
            : 'text-neutral-400 hover:text-white hover:bg-white/10'
        }`}
        title={currentTool === 'text' ? '文字區塊 (啟用中，點擊切回選取工具)' : '文字區塊 (T)'}
      >
        <Type className="w-4 h-4" />
      </button>

      {/* Sticky Note */}
      <button
        onClick={() => handleToolClick('sticky')}
        className={`p-2 rounded-xl flex items-center justify-center transition-all ${
          currentTool === 'sticky'
            ? 'bg-amber-500 text-white shadow-md shadow-amber-500/30'
            : 'text-neutral-400 hover:text-white hover:bg-white/10'
        }`}
        title={currentTool === 'sticky' ? '便簽便利貼 (啟用中，點擊切回選取工具)' : '便簽便利貼 (N)'}
      >
        <StickyNote className="w-4 h-4" />
      </button>

      {/* Pushpin Tool */}
      <button
        onClick={() => handleToolClick('pin')}
        className={`p-2 rounded-xl flex items-center justify-center transition-all ${
          currentTool === 'pin'
            ? 'bg-rose-600 text-white shadow-md shadow-rose-500/30'
            : 'text-neutral-400 hover:text-white hover:bg-white/10'
        }`}
        title={currentTool === 'pin' ? '實體圖釘 (啟用中，點擊畫布釘下圖釘)' : '實體圖釘工具 (點擊畫布釘下標記)'}
      >
        <Pin className="w-4 h-4 rotate-45" />
      </button>

      {/* Screen Snipping Button */}
      <button
        onClick={onOpenScreenCapture}
        className="p-2 rounded-xl flex items-center justify-center text-cyan-400 hover:text-white hover:bg-cyan-600/30 transition-colors"
        title="螢幕截圖 - 局部裁切與一鍵貼上"
      >
        <Camera className="w-4 h-4" />
      </button>

      {/* High Quality Image Upload */}
      <label
        className="p-2 rounded-xl flex items-center justify-center text-neutral-400 hover:text-white hover:bg-white/10 cursor-pointer transition-colors"
        title="匯入高畫質圖片 (支援二次裁切與還原)"
      >
        <ImageIcon className="w-4 h-4" />
        <input type="file" accept="image/*" className="hidden" onChange={handleImageFileChange} />
      </label>

      {/* Control Board Theme Color Picker (控制板顏色自訂) */}
      <div className="relative">
        <button
          onClick={() => setShowColorPicker(!showColorPicker)}
          className="p-2 rounded-xl flex items-center justify-center text-neutral-400 hover:text-white hover:bg-white/10 transition-colors"
          title="自訂控制板背景顏色與風格"
        >
          <Palette className="w-4 h-4 text-emerald-400" />
        </button>

        {showColorPicker && (
          <div
            className={`absolute z-50 w-44 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-2.5 shadow-2xl space-y-2 ${
              orientation === 'horizontal' ? 'bottom-12 right-0' : isRightSide ? 'right-16 top-0' : 'left-16 top-0'
            }`}
          >
            <div className="text-[11px] font-semibold text-neutral-300">控制板自訂外觀</div>
            <div className="space-y-1">
              {TOOLBAR_COLORS.map((tc) => (
                <button
                  key={tc.id}
                  onClick={() => {
                    handleUpdateToolbarColor(tc.id);
                    setShowColorPicker(false);
                  }}
                  className="w-full flex items-center gap-2 px-2 py-1 rounded-lg text-xs text-left text-neutral-300 hover:bg-neutral-800 transition-colors"
                >
                  <div
                    className="w-3.5 h-3.5 rounded-full border border-white/20 shrink-0"
                    style={{ backgroundColor: tc.id }}
                  />
                  <span className="truncate">{tc.name}</span>
                </button>
              ))}
            </div>
            <div className="border-t border-neutral-800 pt-1.5 flex items-center justify-between text-[11px] text-neutral-400">
              <span>自訂色彩:</span>
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setShowCustomCircularPicker(!showCustomCircularPicker)}
                  className="relative w-6 h-6 rounded-full overflow-hidden cursor-pointer border border-white/60 flex items-center justify-center shadow hover:scale-125 transition-transform"
                  style={{
                    background: 'conic-gradient(from 0deg, red, yellow, lime, aqua, blue, magenta, red)',
                  }}
                  title="開啟圓形調色盤"
                >
                  <div className="w-2 h-2 rounded-full bg-white/80 pointer-events-none" />
                </button>

                {showCustomCircularPicker && (
                  <div className="absolute bottom-8 right-0 z-50">
                    <CircularColorPicker
                      color={toolbarBgColor.startsWith('#') ? toolbarBgColor : '#171717'}
                      onChange={(newHex) => {
                        handleUpdateToolbarColor(newHex);
                      }}
                      onClose={() => setShowCustomCircularPicker(false)}
                      title="控制板圓形調色盤"
                    />
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Orientation Toggle Button (橫向 ⇄ 側邊豎直排版切換) */}
      <button
        type="button"
        onClick={() => {
          const next = orientation === 'horizontal' ? 'vertical' : 'horizontal';
          setOrientation(next);
          try {
            localStorage.setItem('blackboard_toolbar_orient', next);
          } catch {}
        }}
        className="p-2 rounded-xl flex items-center justify-center text-neutral-400 hover:text-cyan-400 hover:bg-white/10 transition-colors"
        title={orientation === 'vertical' ? '切換為橫向工具列' : '切換為側邊豎直工具列'}
      >
        {orientation === 'vertical' ? (
          <Columns className="w-4 h-4 text-cyan-400" />
        ) : (
          <Rows className="w-4 h-4 text-cyan-400" />
        )}
      </button>

      {/* Clear Canvas */}
      <button
        onClick={onClearCanvas}
        className="p-2 rounded-xl flex items-center justify-center text-neutral-500 hover:text-red-400 hover:bg-red-500/20 transition-colors"
        title="一鍵清除畫布"
      >
        <Trash className="w-4 h-4" />
      </button>

      {/* Zoom controls */}
      <div
        className={`flex items-center gap-1 text-xs text-neutral-400 font-mono shrink-0 ${
          orientation === 'horizontal'
            ? 'flex-row border-l border-white/10 pl-1.5'
            : 'flex-col border-t border-white/10 pt-1.5'
        }`}
      >
        <button
          onClick={onZoomOut}
          className="p-1 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
          title="縮小"
        >
          <ZoomOut className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={onResetZoom}
          className="px-1 py-0.5 hover:text-white hover:bg-white/10 rounded text-[10px] font-medium"
          title="重設縮放 100%"
        >
          {Math.round(zoom * 100)}%
        </button>
        <button
          onClick={onZoomIn}
          className="p-1 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
          title="放大"
        >
          <ZoomIn className="w-3.5 h-3.5" />
        </button>
      </div>
    </nav>
  );
};
