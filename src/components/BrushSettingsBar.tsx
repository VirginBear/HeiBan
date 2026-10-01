import React, { useState, useEffect, useRef } from 'react';
import { ToolType } from '../types';
import {
  Edit2,
  Highlighter,
  Minus,
  Eye,
  Sliders,
  X,
  GripVertical,
  Palette,
  Move,
  ArrowUp,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  Columns,
  Rows,
} from 'lucide-react';
import { CircularColorPicker } from './CircularColorPicker';

interface BrushSettingsBarProps {
  currentTool: ToolType;
  activeColor: string;
  activeStrokeWidth: number;
  activeLineStyle: 'solid' | 'dashed';
  activeOpacity: number;
  onChangeColor: (color: string) => void;
  onChangeStrokeWidth: (width: number) => void;
  onChangeLineStyle: (style: 'solid' | 'dashed') => void;
  onChangeOpacity: (opacity: number) => void;
  onClose?: () => void;
}

const CHALK_COLORS = [
  { id: '#ffffff', name: '粉筆白' },
  { id: '#fef08a', name: '嫩黃色' },
  { id: '#86efac', name: '薄荷綠' },
  { id: '#93c5fd', name: '天空藍' },
  { id: '#f472b6', name: '粉紅色' },
  { id: '#fdba74', name: '粉橘色' },
  { id: '#c084fc', name: '薰衣草紫' },
  { id: '#f87171', name: '珊瑚紅' },
  { id: '#1e293b', name: '深炭黑' },
];

const HIGHLIGHTER_COLORS = [
  { id: '#facc15', name: '螢光鮮黃' },
  { id: '#4ade80', name: '螢光薄荷綠' },
  { id: '#38bdf8', name: '螢光晴空藍' },
  { id: '#f472b6', name: '螢光櫻花粉' },
  { id: '#fb923c', name: '螢光活力橘' },
  { id: '#c084fc', name: '螢光薰衣紫' },
  { id: '#f87171', name: '螢光珊瑚紅' },
];

const STROKE_PRESETS = [
  { label: '細', width: 2 },
  { label: '中', width: 4 },
  { label: '粗', width: 8 },
  { label: '特粗', width: 16 },
  { label: '超粗', width: 24 },
];

const HIGHLIGHTER_STROKES = [
  { label: '細', width: 12 },
  { label: '中', width: 20 },
  { label: '粗', width: 32 },
  { label: '特粗', width: 48 },
];

export const BrushSettingsBar: React.FC<BrushSettingsBarProps> = ({
  currentTool,
  activeColor,
  activeStrokeWidth,
  activeLineStyle,
  activeOpacity,
  onChangeColor,
  onChangeStrokeWidth,
  onChangeLineStyle,
  onChangeOpacity,
  onClose,
}) => {
  // Draggable positioning state
  const [position, setPosition] = useState<{ x: number; y: number } | null>(() => {
    try {
      const saved = localStorage.getItem('heiban_brush_settings_pos');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });
  const [isDragging, setIsDragging] = useState(false);
  const dragOffsetRef = useRef<{ x: number; y: number }>({ x: 0, y: 0 });
  const [showCircularPicker, setShowCircularPicker] = useState(false);
  const [showDockMenu, setShowDockMenu] = useState(false);

  // Window drag listeners
  useEffect(() => {
    if (!isDragging) return;

    const onPointerMove = (e: PointerEvent) => {
      const winW = window.innerWidth;
      const winH = window.innerHeight;

      let newX = e.clientX - dragOffsetRef.current.x;
      let newY = e.clientY - dragOffsetRef.current.y;

      newX = Math.max(10, Math.min(winW - 160, newX));
      newY = Math.max(10, Math.min(winH - 60, newY));

      if (newX < 120 || winW - (newX + 80) < 120) {
        setIsVertical(true);
      } else if (newY < 120 || winH - (newY + 80) < 120) {
        setIsVertical(false);
      }

      const newPos = { x: newX, y: newY };
      setPosition(newPos);
      try {
        localStorage.setItem('heiban_brush_settings_pos', JSON.stringify(newPos));
      } catch {
        // ignore
      }
    };

    const onPointerUp = () => {
      setIsDragging(false);
    };

    window.addEventListener('pointermove', onPointerMove);
    window.addEventListener('pointerup', onPointerUp);
    return () => {
      window.removeEventListener('pointermove', onPointerMove);
      window.removeEventListener('pointerup', onPointerUp);
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

  const [isVertical, setIsVertical] = useState(false);

  const handleDock = (loc: 'top' | 'bottom' | 'left' | 'right') => {
    const winW = window.innerWidth;
    const winH = window.innerHeight;
    let pos = { x: Math.round(winW / 2 - 220), y: 70 };
    if (loc === 'top') {
      pos = { x: Math.round(winW / 2 - 220), y: 70 };
      setIsVertical(false);
    }
    if (loc === 'bottom') {
      pos = { x: Math.round(winW / 2 - 220), y: winH - 120 };
      setIsVertical(false);
    }
    if (loc === 'left') {
      pos = { x: 20, y: 130 };
      setIsVertical(true);
    }
    if (loc === 'right') {
      pos = { x: Math.max(20, winW - 90), y: 130 };
      setIsVertical(true);
    }
    setPosition(pos);
    try {
      localStorage.setItem('heiban_brush_settings_pos', JSON.stringify(pos));
    } catch {
      // ignore
    }
    setShowDockMenu(false);
  };

  // Only show when a drawing/brush tool is active
  const isBrushTool = ['pen', 'highlighter', 'line', 'arrow', 'rect', 'circle', 'triangle', 'star', 'diamond'].includes(
    currentTool
  );

  if (!isBrushTool) return null;

  const isHighlighter = currentTool === 'highlighter';
  const colors = isHighlighter ? HIGHLIGHTER_COLORS : CHALK_COLORS;
  const strokePresets = isHighlighter ? HIGHLIGHTER_STROKES : STROKE_PRESETS;

  const stylePosition: React.CSSProperties = position
    ? {
        position: 'absolute',
        left: `${position.x}px`,
        top: `${position.y}px`,
        transform: 'none',
      }
    : {
        position: 'absolute',
        top: '64px',
        left: '50%',
        transform: 'translateX(-50%)',
      };

  return (
    <div
      onPointerDown={(e) => e.stopPropagation()}
      style={stylePosition}
      className={`z-40 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl shadow-2xl flex select-none animate-in fade-in zoom-in-95 duration-150 text-neutral-200 ${
        isVertical
          ? 'flex-col items-center gap-3 p-2.5 w-16'
          : 'items-center gap-2.5 px-3 py-2 flex-wrap max-w-[95vw]'
      }`}
    >
      {/* Drag Handle & Position Adjust Menu (手柄：可任意拖曳放置或一鍵停靠) */}
      <div
        className={`relative flex items-center ${
          isVertical ? 'flex-col border-b border-neutral-800 pb-2 w-full gap-1' : 'border-r border-neutral-800 pr-1.5 gap-0.5'
        }`}
      >
        <div
          onPointerDown={handleDragHandlePointerDown}
          className="text-neutral-500 hover:text-white cursor-grab active:cursor-grabbing p-1 rounded-lg hover:bg-white/10 transition-colors flex items-center justify-center shrink-0"
          title="按住拖曳畫筆控制板位置 (可任意拖至螢幕任一處)"
        >
          <GripVertical className="w-4 h-4" />
        </div>
        <div className="flex items-center gap-0.5">
          <button
            onClick={() => setShowDockMenu(!showDockMenu)}
            className="text-neutral-500 hover:text-neutral-200 p-0.5 rounded hover:bg-white/5 transition-colors"
            title="快速停靠位置 (置頂/置底/靠左/靠右)"
          >
            <Move className="w-3 h-3" />
          </button>
          <button
            onClick={() => setIsVertical(!isVertical)}
            className="text-neutral-500 hover:text-cyan-400 p-0.5 rounded hover:bg-white/5 transition-colors"
            title={isVertical ? '切換為橫向' : '切換為側邊豎直'}
          >
            {isVertical ? <Columns className="w-3 h-3 text-cyan-400" /> : <Rows className="w-3 h-3 text-cyan-400" />}
          </button>
        </div>

        {showDockMenu && (
          <div
            className={`absolute z-50 w-36 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-1.5 shadow-2xl space-y-1 text-xs animate-in fade-in duration-100 ${
              isVertical ? 'left-16 top-0' : 'top-8 left-0'
            }`}
          >
            <div className="text-[10px] text-neutral-400 font-medium px-2 py-0.5">快速停靠位置:</div>
            <button
              onClick={() => handleDock('top')}
              className="w-full flex items-center gap-2 px-2 py-1 rounded-xl text-neutral-300 hover:bg-neutral-800 hover:text-white transition-colors"
            >
              <ArrowUp className="w-3 h-3 text-cyan-400" />
              <span>螢幕頂部</span>
            </button>
            <button
              onClick={() => handleDock('bottom')}
              className="w-full flex items-center gap-2 px-2 py-1 rounded-xl text-neutral-300 hover:bg-neutral-800 hover:text-white transition-colors"
            >
              <ArrowDown className="w-3 h-3 text-emerald-400" />
              <span>螢幕底部</span>
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
          </div>
        )}
      </div>

      {/* Tool Indicator */}
      <div
        className={`flex items-center justify-center ${
          isVertical ? 'border-b border-neutral-800 pb-2 w-full' : 'border-r border-neutral-800 pr-2.5'
        }`}
      >
        {currentTool === 'highlighter' ? (
          <div
            className="flex items-center gap-1 text-xs text-yellow-400 font-bold px-2 py-0.5 rounded-full bg-yellow-500/10 border border-yellow-500/20"
            title="螢光筆調色與筆刷"
          >
            <Highlighter className="w-3.5 h-3.5" />
            {!isVertical && <span>螢光筆</span>}
          </div>
        ) : currentTool === 'pen' ? (
          <div
            className="flex items-center gap-1 text-xs text-emerald-400 font-bold px-2 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/20"
            title="向量畫筆調色與筆刷"
          >
            <Edit2 className="w-3.5 h-3.5" />
            {!isVertical && <span>畫筆</span>}
          </div>
        ) : (
          <div
            className="flex items-center gap-1 text-xs text-purple-400 font-bold px-2 py-0.5 rounded-full bg-purple-500/10 border border-purple-500/20"
            title="幾何線條調色"
          >
            <Minus className="w-3.5 h-3.5" />
            {!isVertical && <span>線條</span>}
          </div>
        )}
      </div>

      {/* Circular Color Palette (支援螢光筆專屬調色與圓形調色盤) */}
      <div
        className={`flex items-center ${
          isVertical
            ? 'flex-col border-b border-neutral-800 pb-2 w-full gap-1.5'
            : 'border-r border-neutral-800 pr-2.5 gap-1.5'
        }`}
      >
        {!isVertical && (
          <span className="text-[11px] text-neutral-400 font-medium">
            {isHighlighter ? '螢光色:' : '調色:'}
          </span>
        )}
        <div className={`flex items-center ${isVertical ? 'grid grid-cols-2 gap-1.5' : 'gap-1.5'}`}>
          {colors.slice(0, isVertical ? 6 : colors.length).map((c) => (
            <button
              key={c.id}
              onClick={() => onChangeColor(c.id)}
              className={`w-5 h-5 rounded-full border-2 transition-all hover:scale-125 ${
                activeColor.toLowerCase() === c.id.toLowerCase()
                  ? 'border-white scale-110 shadow-md ring-2 ring-blue-500'
                  : 'border-neutral-600/70 hover:border-neutral-400'
              }`}
              style={{ backgroundColor: c.id }}
              title={c.name}
            />
          ))}

          {/* Dedicated Circular Custom Color Palette Button (純圓形漸層調色盤) */}
          <div className="relative">
            <button
              type="button"
              onClick={() => setShowCircularPicker(!showCircularPicker)}
              className="relative w-5 h-5 rounded-full overflow-hidden cursor-pointer border-2 border-white/70 flex items-center justify-center shadow-md hover:scale-125 transition-transform"
              style={{
                background: 'conic-gradient(from 0deg, red, yellow, lime, aqua, blue, magenta, red)',
              }}
              title="開啟圓形調色盤 (色相環/自訂色)"
            >
              <div className="w-2 h-2 rounded-full bg-white/80 pointer-events-none" />
            </button>

            {showCircularPicker && (
              <div
                className={`absolute z-50 ${
                  isVertical
                    ? position && position.x > window.innerWidth / 2
                      ? 'right-16 top-0'
                      : 'left-16 top-0'
                    : 'top-8 left-0'
                }`}
              >
                <CircularColorPicker
                  color={activeColor}
                  onChange={onChangeColor}
                  onClose={() => setShowCircularPicker(false)}
                  title={isHighlighter ? '螢光筆圓形調色盤' : '畫筆圓形調色盤'}
                />
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Stroke Width Presets & Slider */}
      <div
        className={`flex items-center ${
          isVertical
            ? 'flex-col border-b border-neutral-800 pb-2 w-full gap-1.5'
            : 'border-r border-neutral-800 pr-2.5 gap-1.5'
        }`}
      >
        {!isVertical && <span className="text-[11px] text-neutral-400 font-medium">粗細:</span>}
        <div className={`flex items-center ${isVertical ? 'flex-col gap-1' : 'gap-1'}`}>
          {strokePresets.map((p) => (
            <button
              key={p.width}
              onClick={() => onChangeStrokeWidth(p.width)}
              className={`px-1.5 py-0.5 rounded-full text-[10px] font-medium border transition-colors ${
                activeStrokeWidth === p.width
                  ? 'border-blue-400 bg-blue-500/20 text-white font-bold'
                  : 'border-neutral-700 text-neutral-400 hover:bg-neutral-800'
              }`}
              title={`${p.label} (${p.width}px)`}
            >
              {p.label}
            </button>
          ))}
        </div>
        {!isVertical && (
          <>
            <input
              type="range"
              min={isHighlighter ? '6' : '1'}
              max={isHighlighter ? '64' : '36'}
              value={activeStrokeWidth}
              onChange={(e) => onChangeStrokeWidth(parseInt(e.target.value, 10))}
              className="w-14 h-1.5 bg-neutral-700 rounded-full appearance-none cursor-pointer ml-1"
              title={`目前粗細: ${activeStrokeWidth}px`}
            />
            <span className="text-[10px] font-mono text-neutral-400 w-6">{activeStrokeWidth}px</span>
          </>
        )}
      </div>

      {/* Opacity Slider */}
      <div
        className={`flex items-center ${
          isVertical ? 'flex-col border-b border-neutral-800 pb-2 w-full gap-1' : 'border-r border-neutral-800 pr-2.5 gap-1.5'
        }`}
      >
        <Eye className="w-3.5 h-3.5 text-cyan-400" />
        {!isVertical && <span className="text-[11px] text-neutral-400 font-medium">透明度:</span>}
        <input
          type="range"
          min="0.1"
          max="1"
          step="0.05"
          value={activeOpacity}
          onChange={(e) => onChangeOpacity(parseFloat(e.target.value))}
          className={`${isVertical ? 'w-12' : 'w-14'} h-1.5 bg-neutral-700 rounded-full appearance-none cursor-pointer`}
          title={`透明度: ${Math.round(activeOpacity * 100)}%`}
        />
      </div>

      {/* Line Style Toggle: Solid vs Dashed */}
      {!isHighlighter && (
        <div className={`flex items-center ${isVertical ? 'flex-col gap-1 w-full' : 'gap-1'}`}>
          <button
            onClick={() => onChangeLineStyle('solid')}
            className={`px-2 py-0.5 rounded-full text-[10px] transition-colors ${
              activeLineStyle === 'solid'
                ? 'bg-blue-600 text-white font-medium shadow-sm'
                : 'text-neutral-400 hover:text-white hover:bg-neutral-800'
            }`}
            title="實線"
          >
            實線
          </button>
          <button
            onClick={() => onChangeLineStyle('dashed')}
            className={`px-2 py-0.5 rounded-full text-[10px] transition-colors ${
              activeLineStyle === 'dashed'
                ? 'bg-blue-600 text-white font-medium shadow-sm'
                : 'text-neutral-400 hover:text-white hover:bg-neutral-800'
            }`}
            title="虛線"
          >
            虛線
          </button>
        </div>
      )}

      {onClose && (
        <button
          onClick={onClose}
          className="p-1 rounded-full hover:bg-neutral-800 text-neutral-500 hover:text-white transition-colors"
          title="收合調色板"
        >
          <X className="w-3.5 h-3.5" />
        </button>
      )}
    </div>
  );
};
