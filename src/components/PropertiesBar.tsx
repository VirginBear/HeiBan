import React, { useState, useEffect, useRef } from 'react';
import { BoardObject, LineExtension } from '../types';
import {
  Trash2,
  Copy,
  ChevronsUp,
  ChevronsDown,
  Lock,
  Unlock,
  Eye,
  ArrowRight,
  ArrowLeft,
  MoveHorizontal,
  Bold,
  Italic,
  Underline,
  Strikethrough,
  Highlighter,
  AlignLeft,
  AlignCenter,
  AlignRight,
  Crop,
  RotateCcw,
  GripVertical,
  Move,
  ArrowUp,
  ArrowDown,
} from 'lucide-react';
import { CircularColorPicker } from './CircularColorPicker';

interface PropertiesBarProps {
  selectedObjects: BoardObject[];
  onUpdate: (partial: Partial<BoardObject>) => void;
  onDelete: () => void;
  onDuplicate: () => void;
  onReorder: (action: 'top' | 'up' | 'down' | 'bottom') => void;
  onCropImage?: (obj: BoardObject) => void;
  onResetImage?: (obj: BoardObject) => void;
}

const CHALK_COLORS = [
  '#ffffff', // Chalk White
  '#fef08a', // Pastel Yellow
  '#86efac', // Mint Green
  '#93c5fd', // Sky Blue
  '#f472b6', // Chalk Pink
  '#fdba74', // Peach Orange
  '#c084fc', // Lavender
  '#f87171', // Coral Red
  '#1e293b', // Slate Dark
];

const HIGHLIGHT_COLORS = [
  { id: 'none', label: '無高亮', color: 'transparent' },
  { id: '#fef08a', label: '黃色螢光', color: '#fef08a' },
  { id: '#86efac', label: '綠色螢光', color: '#86efac' },
  { id: '#93c5fd', label: '藍色螢光', color: '#93c5fd' },
  { id: '#f472b6', label: '粉色螢光', color: '#f472b6' },
  { id: '#fed7aa', label: '橘色螢光', color: '#fed7aa' },
];

const FONT_FAMILIES = [
  { id: 'system-ui, sans-serif', name: '現代黑體' },
  { id: '"Caveat", "Comic Sans MS", cursive', name: '黑板手寫' },
  { id: 'Georgia, serif', name: '經典明體' },
  { id: '"Courier New", monospace', name: '等寬程式' },
];

export const PropertiesBar: React.FC<PropertiesBarProps> = ({
  selectedObjects,
  onUpdate,
  onDelete,
  onDuplicate,
  onReorder,
  onCropImage,
  onResetImage,
}) => {
  // Draggable position state
  const [position, setPosition] = useState<{ x: number; y: number } | null>(() => {
    try {
      const saved = localStorage.getItem('heiban_prop_bar_pos');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });
  const [isDragging, setIsDragging] = useState(false);
  const dragOffsetRef = useRef<{ x: number; y: number }>({ x: 0, y: 0 });
  const [showCircularPicker, setShowCircularPicker] = useState(false);
  const [showDockMenu, setShowDockMenu] = useState(false);

  const handleDock = (loc: 'top' | 'bottom' | 'left' | 'right') => {
    const winW = window.innerWidth;
    const winH = window.innerHeight;
    let pos = { x: Math.round(winW / 2 - 220), y: 70 };
    if (loc === 'top') pos = { x: Math.round(winW / 2 - 220), y: 70 };
    if (loc === 'bottom') pos = { x: Math.round(winW / 2 - 220), y: winH - 120 };
    if (loc === 'left') pos = { x: 20, y: 130 };
    if (loc === 'right') pos = { x: Math.max(20, winW - 480), y: 130 };
    setPosition(pos);
    try {
      localStorage.setItem('heiban_prop_bar_pos', JSON.stringify(pos));
    } catch {
      // ignore
    }
    setShowDockMenu(false);
  };

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

      const newPos = { x: newX, y: newY };
      setPosition(newPos);
      try {
        localStorage.setItem('heiban_prop_bar_pos', JSON.stringify(newPos));
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

  if (selectedObjects.length === 0) return null;

  const first = selectedObjects[0];
  const hasFill = ['rect', 'circle', 'triangle', 'diamond', 'star', 'sticky'].includes(first.type);
  const isLineOrArrow = first.type === 'line' || first.type === 'arrow';
  const isShape = ['rect', 'circle', 'triangle', 'star', 'diamond'].includes(first.type);
  const isText = first.type === 'text' || first.type === 'sticky';
  const isPin = first.type === 'pin';

  const currentExtension: LineExtension = first.extension || 'none';

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
      className="z-40 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl px-3 py-2 shadow-2xl flex items-center gap-2.5 text-neutral-200 animate-in fade-in zoom-in-95 duration-150 flex-wrap max-w-[95vw]"
    >
      {/* Drag Handle & Position Adjust Menu (手柄：可任意拖曳放置或一鍵停靠) */}
      <div className="relative flex items-center border-r border-neutral-800 pr-1.5 gap-0.5">
        <div
          onPointerDown={handleDragHandlePointerDown}
          className="text-neutral-500 hover:text-white cursor-grab active:cursor-grabbing p-1 rounded-lg hover:bg-white/10 transition-colors flex items-center justify-center shrink-0"
          title="按住拖曳物件屬性板位置"
        >
          <GripVertical className="w-4 h-4" />
        </div>
        <button
          onClick={() => setShowDockMenu(!showDockMenu)}
          className="text-neutral-500 hover:text-neutral-200 p-0.5 rounded hover:bg-white/5 transition-colors"
          title="快速調整屬性板位置 (置頂/置底/靠左/靠右)"
        >
          <Move className="w-3 h-3" />
        </button>

        {showDockMenu && (
          <div className="absolute top-8 left-0 z-50 w-36 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-1.5 shadow-2xl space-y-1 text-xs animate-in fade-in duration-100">
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
              <span>靠左停靠</span>
            </button>
            <button
              onClick={() => handleDock('right')}
              className="w-full flex items-center gap-2 px-2 py-1 rounded-xl text-neutral-300 hover:bg-neutral-800 hover:text-white transition-colors"
            >
              <ArrowRight className="w-3 h-3 text-rose-400" />
              <span>靠右停靠</span>
            </button>
          </div>
        )}
      </div>

      {/* Color Selector (純圓形調色盤) */}
      <div className="flex items-center gap-1.5 border-r border-neutral-800 pr-2.5">
        <span className="text-[11px] text-neutral-400 font-medium">顏色:</span>
        <div className="flex items-center gap-1.5">
          {CHALK_COLORS.map((c) => (
            <button
              key={c}
              onClick={() => onUpdate({ strokeColor: c })}
              className={`w-6 h-6 rounded-full border-2 transition-all hover:scale-125 ${
                first.strokeColor?.toLowerCase() === c.toLowerCase()
                  ? 'border-white scale-110 shadow-md ring-2 ring-blue-500'
                  : 'border-neutral-600/70 hover:border-neutral-400'
              }`}
              style={{ backgroundColor: c }}
              title={c}
            />
          ))}

          {/* Dedicated Circular Custom Color Palette Button (純圓形漸層調色盤) */}
          <div className="relative">
            <button
              type="button"
              onClick={() => setShowCircularPicker(!showCircularPicker)}
              className="relative w-6 h-6 rounded-full overflow-hidden cursor-pointer border-2 border-white/70 flex items-center justify-center shadow-md hover:scale-125 transition-transform"
              style={{
                background: 'conic-gradient(from 0deg, red, yellow, lime, aqua, blue, magenta, red)',
              }}
              title="開啟圓形調色盤 (色相環/自訂色)"
            >
              <div className="w-2.5 h-2.5 rounded-full bg-white/80 pointer-events-none" />
            </button>

            {showCircularPicker && (
              <div className="absolute top-8 left-0 z-50">
                <CircularColorPicker
                  color={first.strokeColor || '#ffffff'}
                  onChange={(newHex) => onUpdate({ strokeColor: newHex })}
                  onClose={() => setShowCircularPicker(false)}
                  title="物件圓形調色盤"
                />
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Opacity Slider */}
      <div className="flex items-center gap-1.5 border-r border-neutral-800 pr-3">
        <Eye className="w-3.5 h-3.5 text-cyan-400" />
        <span className="text-[11px] text-neutral-400 font-medium">不透明:</span>
        <input
          type="range"
          min="0.1"
          max="1"
          step="0.05"
          value={first.opacity ?? 1}
          onChange={(e) => onUpdate({ opacity: parseFloat(e.target.value) })}
          className="w-16 h-1.5 bg-neutral-700 rounded-lg appearance-none cursor-pointer"
        />
        <span className="text-[10px] font-mono text-neutral-400 w-7">
          {Math.round((first.opacity ?? 1) * 100)}%
        </span>
      </div>

      {/* Rich Text & PDF-style Highlighting Controls (粗體、斜體、底線、刪除線、文字高亮) */}
      {isText && (
        <div className="flex items-center gap-2 border-r border-neutral-800 pr-3 flex-wrap">
          {/* Font Family */}
          <select
            value={first.fontFamily || 'system-ui, sans-serif'}
            onChange={(e) => onUpdate({ fontFamily: e.target.value })}
            className="bg-neutral-800 text-white text-xs px-2 py-1 rounded-lg border border-neutral-700 outline-none"
          >
            {FONT_FAMILIES.map((f) => (
              <option key={f.id} value={f.id}>
                {f.name}
              </option>
            ))}
          </select>

          {/* Font Size */}
          <div className="flex items-center gap-0.5">
            {[14, 18, 24, 32, 48].map((s) => (
              <button
                key={s}
                onClick={() => onUpdate({ fontSize: s })}
                className={`px-1.5 py-0.5 rounded text-[10px] font-mono border transition-colors ${
                  first.fontSize === s
                    ? 'border-blue-400 bg-blue-500/20 text-white'
                    : 'border-neutral-700 text-neutral-400 hover:bg-neutral-800'
                }`}
              >
                {s}
              </button>
            ))}
          </div>

          {/* B / I / U / S */}
          <div className="flex items-center gap-0.5 bg-neutral-800/80 p-0.5 rounded-xl border border-neutral-700">
            <button
              onClick={() => onUpdate({ isBold: !first.isBold })}
              className={`p-1 rounded-lg transition-colors ${
                first.isBold ? 'bg-blue-600 text-white' : 'text-neutral-400 hover:text-white'
              }`}
              title="粗體 (Bold)"
            >
              <Bold className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => onUpdate({ isItalic: !first.isItalic })}
              className={`p-1 rounded-lg transition-colors ${
                first.isItalic ? 'bg-blue-600 text-white' : 'text-neutral-400 hover:text-white'
              }`}
              title="斜體 (Italic)"
            >
              <Italic className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => onUpdate({ isUnderline: !first.isUnderline })}
              className={`p-1 rounded-lg transition-colors ${
                first.isUnderline ? 'bg-blue-600 text-white' : 'text-neutral-400 hover:text-white'
              }`}
              title="底線 (Underline)"
            >
              <Underline className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => onUpdate({ isStrikethrough: !first.isStrikethrough })}
              className={`p-1 rounded-lg transition-colors ${
                first.isStrikethrough ? 'bg-blue-600 text-white' : 'text-neutral-400 hover:text-white'
              }`}
              title="刪除線 (Strikethrough)"
            >
              <Strikethrough className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* PDF-Style Highlight Color (高亮螢光標記) */}
          <div className="flex items-center gap-1 bg-neutral-800/80 px-2 py-0.5 rounded-xl border border-neutral-700">
            <Highlighter className="w-3.5 h-3.5 text-yellow-400" />
            <span className="text-[10px] text-neutral-400">高亮:</span>
            {HIGHLIGHT_COLORS.map((hc) => (
              <button
                key={hc.id}
                onClick={() => onUpdate({ highlightColor: hc.id === 'none' ? 'none' : hc.id })}
                className={`w-4 h-4 rounded-full border transition-transform hover:scale-110 ${
                  first.highlightColor === hc.id || (!first.highlightColor && hc.id === 'none')
                    ? 'border-white scale-110 ring-1 ring-blue-400'
                    : 'border-neutral-600'
                }`}
                style={{ backgroundColor: hc.color === 'transparent' ? '#333' : hc.color }}
                title={hc.label}
              />
            ))}
          </div>

          {/* Alignment */}
          <div className="flex items-center gap-0.5 bg-neutral-800/80 p-0.5 rounded-xl border border-neutral-700">
            <button
              onClick={() => onUpdate({ align: 'left' })}
              className={`p-1 rounded-lg ${
                first.align === 'left' || !first.align ? 'bg-blue-600 text-white' : 'text-neutral-400 hover:text-white'
              }`}
              title="靠左對齊"
            >
              <AlignLeft className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => onUpdate({ align: 'center' })}
              className={`p-1 rounded-lg ${
                first.align === 'center' ? 'bg-blue-600 text-white' : 'text-neutral-400 hover:text-white'
              }`}
              title="置中對齊"
            >
              <AlignCenter className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => onUpdate({ align: 'right' })}
              className={`p-1 rounded-lg ${
                first.align === 'right' ? 'bg-blue-600 text-white' : 'text-neutral-400 hover:text-white'
              }`}
              title="靠右對齊"
            >
              <AlignRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      )}

      {/* Ray Extension Mode: None, Start/Left, End/Right, Both */}
      {isLineOrArrow && (
        <div className="flex items-center gap-1.5 border-r border-neutral-800 pr-3">
          <span className="text-[11px] text-neutral-400 font-medium">射線/延伸:</span>
          <div className="flex items-center gap-1 bg-neutral-800/80 p-0.5 rounded-xl border border-neutral-700">
            <button
              onClick={() => onUpdate({ extension: 'none' })}
              className={`px-2 py-0.5 rounded-lg text-[10px] transition-colors ${
                currentExtension === 'none'
                  ? 'bg-blue-600 text-white font-medium shadow-sm'
                  : 'text-neutral-400 hover:text-white'
              }`}
              title="雙邊不延伸 (線段 A-B)"
            >
              不延伸
            </button>
            <button
              onClick={() => onUpdate({ extension: 'start' })}
              className={`flex items-center gap-0.5 px-2 py-0.5 rounded-lg text-[10px] transition-colors ${
                currentExtension === 'start'
                  ? 'bg-blue-600 text-white font-medium shadow-sm'
                  : 'text-neutral-400 hover:text-white'
              }`}
              title="向 A 端(左)延伸為射線"
            >
              <ArrowLeft className="w-3 h-3" />
              <span>左延伸</span>
            </button>
            <button
              onClick={() => onUpdate({ extension: 'end' })}
              className={`flex items-center gap-0.5 px-2 py-0.5 rounded-lg text-[10px] transition-colors ${
                currentExtension === 'end'
                  ? 'bg-blue-600 text-white font-medium shadow-sm'
                  : 'text-neutral-400 hover:text-white'
              }`}
              title="向 B 端(右)延伸為射線"
            >
              <span>右延伸</span>
              <ArrowRight className="w-3 h-3" />
            </button>
            <button
              onClick={() => onUpdate({ extension: 'both' })}
              className={`flex items-center gap-0.5 px-2 py-0.5 rounded-lg text-[10px] transition-colors ${
                currentExtension === 'both'
                  ? 'bg-blue-600 text-white font-medium shadow-sm'
                  : 'text-neutral-400 hover:text-white'
              }`}
              title="雙邊無限延伸 (直線)"
            >
              <MoveHorizontal className="w-3 h-3" />
              <span>雙邊延伸</span>
            </button>
          </div>
        </div>
      )}

      {/* Cute Sticky Note Styles & Pastel Colors (便簽樣式：可愛手帳、和紙膠帶、貓咪肉球、橫線活頁、復古方格、柔和圓角) */}
      {first.type === 'sticky' && (
        <div className="flex items-center gap-2 border-r border-neutral-800 pr-3">
          <span className="text-[11px] text-neutral-400 font-medium">便簽樣式:</span>
          <div className="flex items-center gap-1 bg-neutral-800/80 p-0.5 rounded-xl border border-neutral-700">
            {[
              { id: 'classic', label: '經典', icon: '📝' },
              { id: 'washi', label: '和紙膠帶', icon: '🎀' },
              { id: 'cat', label: '貓咪肉球', icon: '🐾' },
              { id: 'notebook', label: '活頁紙', icon: '📒' },
              { id: 'grid', label: '方格', icon: '📐' },
              { id: 'soft', label: '柔和雲朵', icon: '☁️' },
            ].map((st) => (
              <button
                key={st.id}
                onClick={() => onUpdate({ stickyStyle: st.id as any })}
                className={`px-2 py-1 rounded-lg text-xs flex items-center gap-1 transition-all ${
                  (first.stickyStyle || 'classic') === st.id
                    ? 'bg-amber-500/20 text-amber-300 font-bold border border-amber-400/40 shadow-sm'
                    : 'text-neutral-400 hover:text-white hover:bg-neutral-700/50'
                }`}
                title={st.label}
              >
                <span>{st.icon}</span>
                <span className="text-[10px] hidden sm:inline">{st.label}</span>
              </button>
            ))}
          </div>

          <span className="text-[11px] text-neutral-400 font-medium ml-1">底色:</span>
          <div className="flex items-center gap-1">
            {[
              { color: '#fef08a', name: '暖暖黃' },
              { color: '#fed7aa', name: '蜜桃杏' },
              { color: '#bbf7d0', name: '薄荷綠' },
              { color: '#bfdbfe', name: '晴空藍' },
              { color: '#fbcfe8', name: '草莓粉' },
              { color: '#ddd6fe', name: '薰衣紫' },
              { color: '#ffffff', name: '純淨白' },
            ].map((c) => (
              <button
                key={c.color}
                onClick={() => onUpdate({ fillColor: c.color })}
                className={`w-4 h-4 rounded-full border transition-transform hover:scale-125 ${
                  first.fillColor === c.color ? 'border-white scale-110 shadow-sm ring-1 ring-blue-400' : 'border-neutral-600'
                }`}
                style={{ backgroundColor: c.color }}
                title={c.name}
              />
            ))}
          </div>
        </div>
      )}

      {/* Image Crop & Reset Controls (截圖/匯入圖片二次裁切與重置) */}
      {first.type === 'image' && (
        <div className="flex items-center gap-1.5 border-r border-neutral-800 pr-3">
          <button
            onClick={() => onCropImage && onCropImage(first)}
            className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-cyan-600/25 hover:bg-cyan-600/40 text-cyan-300 text-xs font-semibold border border-cyan-500/40 transition-colors shadow-sm"
            title="二次裁切圖片保留範圍"
          >
            <Crop className="w-3.5 h-3.5" />
            <span>二次裁切</span>
          </button>
          <button
            onClick={() => onResetImage && onResetImage(first)}
            className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-neutral-300 hover:text-white text-xs font-medium transition-colors"
            title="重置為剛匯入的原始高畫質圖片"
          >
            <RotateCcw className="w-3.5 h-3.5 text-amber-400" />
            <span>重置原始</span>
          </button>
        </div>
      )}

      {/* Actions */}
      <div className="flex items-center gap-1">
        <button
          onClick={onDuplicate}
          className="p-1.5 hover:bg-neutral-800 rounded-lg text-neutral-400 hover:text-white transition-colors"
          title="複製物件 (Ctrl+D)"
        >
          <Copy className="w-3.5 h-3.5" />
        </button>

        <button
          onClick={() => onReorder('top')}
          className="p-1.5 hover:bg-neutral-800 rounded-lg text-neutral-400 hover:text-white transition-colors"
          title="置頂"
        >
          <ChevronsUp className="w-3.5 h-3.5" />
        </button>

        <button
          onClick={() => onReorder('bottom')}
          className="p-1.5 hover:bg-neutral-800 rounded-lg text-neutral-400 hover:text-white transition-colors"
          title="置底"
        >
          <ChevronsDown className="w-3.5 h-3.5" />
        </button>

        <button
          onClick={() => onUpdate({ isLocked: !first.isLocked })}
          className={`p-1.5 rounded-lg transition-colors ${
            first.isLocked ? 'text-amber-400 bg-amber-500/10' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'
          }`}
          title={first.isLocked ? '解鎖物件' : '鎖定物件'}
        >
          {first.isLocked ? <Lock className="w-3.5 h-3.5" /> : <Unlock className="w-3.5 h-3.5" />}
        </button>

        <button
          onClick={onDelete}
          className="p-1.5 hover:bg-red-500/20 text-neutral-400 hover:text-red-400 rounded-lg transition-colors ml-1"
          title="刪除"
        >
          <Trash2 className="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
  );
};
