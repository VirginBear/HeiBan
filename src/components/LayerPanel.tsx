import React, { useState, useRef } from 'react';
import { BoardObject } from '../types';
import {
  Layers,
  Eye,
  EyeOff,
  Lock,
  Unlock,
  Trash2,
  ArrowUp,
  ArrowDown,
  ChevronsUp,
  ChevronsDown,
  Edit3,
  Square,
  Circle,
  Type,
  FileText,
  Image as ImageIcon,
  Highlighter,
  Pin,
  X,
  GripVertical,
} from 'lucide-react';

interface LayerPanelProps {
  objects: BoardObject[];
  selectedIds: string[];
  isOpen: boolean;
  onClose: () => void;
  onSelect: (id: string, multi: boolean) => void;
  onUpdateObject: (id: string, partial: Partial<BoardObject>) => void;
  onReorder: (id: string, action: 'top' | 'up' | 'down' | 'bottom') => void;
  onReorderBatch?: (newOrderedIds: string[]) => void;
  onDelete: (id: string) => void;
}

export const LayerPanel: React.FC<LayerPanelProps> = ({
  objects,
  selectedIds,
  isOpen,
  onClose,
  onSelect,
  onUpdateObject,
  onReorder,
  onReorderBatch,
  onDelete,
}) => {
  // Drag-and-drop state (iPhone style grip handle)
  const [draggedId, setDraggedId] = useState<string | null>(null);
  const [dragOverId, setDragOverId] = useState<string | null>(null);

  if (!isOpen) return null;

  // Highest zIndex at the top
  const sorted = [...objects].sort((a, b) => b.zIndex - a.zIndex);

  const getObjectIcon = (type: BoardObject['type']) => {
    switch (type) {
      case 'stroke':
        return <Edit3 className="w-4 h-4 text-emerald-400" />;
      case 'highlighter':
        return <Highlighter className="w-4 h-4 text-yellow-400" />;
      case 'rect':
        return <Square className="w-4 h-4 text-blue-400" />;
      case 'circle':
        return <Circle className="w-4 h-4 text-purple-400" />;
      case 'text':
        return <Type className="w-4 h-4 text-pink-400" />;
      case 'sticky':
        return <FileText className="w-4 h-4 text-amber-400" />;
      case 'image':
        return <ImageIcon className="w-4 h-4 text-teal-400" />;
      case 'pin':
        return <Pin className="w-4 h-4 text-rose-400 rotate-45" />;
      default:
        return <Layers className="w-4 h-4 text-neutral-400" />;
    }
  };

  const getObjectLabel = (obj: BoardObject) => {
    switch (obj.type) {
      case 'stroke':
        return '筆畫物件';
      case 'highlighter':
        return '螢光標記';
      case 'rect':
        return '矩形圖案';
      case 'circle':
        return '圓形圖案';
      case 'line':
        return '直線線段';
      case 'arrow':
        return '箭頭線段';
      case 'text':
        return obj.text ? `文字: "${obj.text.slice(0, 12)}..."` : '文字區塊';
      case 'sticky':
        return obj.text ? `便簽: "${obj.text.slice(0, 12)}..."` : '便簽便利貼';
      case 'image':
        return '高畫質影像';
      case 'pin':
        return obj.text ? `圖釘: "${obj.text}"` : '畫布圖釘物件';
      default:
        return '向量繪圖物件';
    }
  };

  // iPhone Style Drag handlers
  const handleDragStart = (id: string, e: React.DragEvent) => {
    setDraggedId(id);
    e.dataTransfer.effectAllowed = 'move';
  };

  const handleDragOver = (id: string, e: React.DragEvent) => {
    e.preventDefault();
    if (draggedId !== id) {
      setDragOverId(id);
    }
  };

  const handleDrop = (targetId: string, e: React.DragEvent) => {
    e.preventDefault();
    if (!draggedId || draggedId === targetId) {
      setDraggedId(null);
      setDragOverId(null);
      return;
    }

    // Compute new order
    const currentOrder = sorted.map((o) => o.id);
    const fromIndex = currentOrder.indexOf(draggedId);
    const toIndex = currentOrder.indexOf(targetId);

    if (fromIndex !== -1 && toIndex !== -1) {
      const newOrder = [...currentOrder];
      const [moved] = newOrder.splice(fromIndex, 1);
      newOrder.splice(toIndex, 0, moved);

      // Reassign zIndex so that the top item gets highest zIndex
      if (onReorderBatch) {
        onReorderBatch(newOrder);
      } else {
        // Fallback: assign zIndexes in descending order
        newOrder.forEach((id, index) => {
          onUpdateObject(id, { zIndex: newOrder.length - index });
        });
      }
    }

    setDraggedId(null);
    setDragOverId(null);
  };

  return (
    <aside
      aria-label="圖層管理"
      className="absolute right-4 top-16 bottom-20 w-84 bg-neutral-900/95 backdrop-blur-2xl border border-neutral-700/80 rounded-3xl shadow-2xl flex flex-col z-40 overflow-hidden text-neutral-200 animate-in fade-in slide-in-from-right-4 duration-200"
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3.5 border-b border-neutral-800">
        <div className="flex items-center gap-2">
          <Layers className="w-4 h-4 text-cyan-400" />
          <h2 className="font-bold text-sm tracking-wide text-white">圖層管理</h2>
          <span className="text-xs px-2 py-0.5 rounded-full bg-neutral-800 text-neutral-400 font-mono">
            {objects.length}
          </span>
        </div>
        <button
          onClick={onClose}
          className="p-1 rounded-xl hover:bg-neutral-800 text-neutral-400 hover:text-white transition-colors"
          title="關閉面板"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      <div className="px-4 py-1.5 text-[11px] text-neutral-400 border-b border-neutral-800/60 bg-neutral-950/30 flex items-center justify-between">
        <span>按住右側 ≡ 手柄可直接拖曳上下排序</span>
        <span className="text-[10px] text-neutral-500 font-mono">iPhone 樣式</span>
      </div>

      {/* Layer List */}
      <div className="flex-1 overflow-y-auto p-2 space-y-1.5 scrollbar-thin">
        {sorted.length === 0 ? (
          <div className="h-48 flex flex-col items-center justify-center text-center p-4 text-neutral-500">
            <Layers className="w-10 h-10 mb-2 opacity-30" />
            <p className="text-xs">黑板上尚無物件</p>
          </div>
        ) : (
          sorted.map((obj) => {
            const isSelected = selectedIds.includes(obj.id);
            const isDraggingThis = draggedId === obj.id;
            const isDragOverThis = dragOverId === obj.id;

            return (
              <div
                key={obj.id}
                draggable
                onDragStart={(e) => handleDragStart(obj.id, e)}
                onDragOver={(e) => handleDragOver(obj.id, e)}
                onDrop={(e) => handleDrop(obj.id, e)}
                onClick={(e) => onSelect(obj.id, e.shiftKey || e.metaKey || e.ctrlKey)}
                className={`group flex items-center gap-2 px-3 py-2 rounded-2xl text-xs cursor-pointer transition-all border select-none ${
                  isDraggingThis
                    ? 'opacity-40 border-dashed border-cyan-400 bg-neutral-800/40'
                    : isDragOverThis
                    ? 'border-t-2 border-cyan-400 bg-cyan-900/20'
                    : isSelected
                    ? 'bg-blue-600/25 border-blue-500/50 text-white shadow-sm'
                    : 'bg-neutral-800/40 border-transparent hover:bg-neutral-800/80 text-neutral-300'
                }`}
              >
                {/* Object Icon */}
                <div className="p-1.5 rounded-xl bg-neutral-800/80 flex items-center justify-center shrink-0">
                  {getObjectIcon(obj.type)}
                </div>

                {/* Color Dot */}
                <div
                  className="w-3.5 h-3.5 rounded-full shrink-0 border border-white/20 shadow-inner"
                  style={{
                    backgroundColor:
                      obj.type === 'sticky' ? obj.fillColor : obj.strokeColor || '#ffffff',
                  }}
                />

                {/* Label */}
                <div className="flex-1 min-w-0">
                  <div className="truncate font-medium">{getObjectLabel(obj)}</div>
                  <div className="text-[10px] text-neutral-500">
                    層級 Z: {obj.zIndex}
                  </div>
                </div>

                {/* Quick Controls */}
                <div className="flex items-center gap-0.5 opacity-80 group-hover:opacity-100 shrink-0">
                  {/* Lock Toggle */}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onUpdateObject(obj.id, { isLocked: !obj.isLocked });
                    }}
                    className={`p-1 rounded-lg transition-colors ${
                      obj.isLocked
                        ? 'text-amber-400 hover:bg-neutral-700'
                        : 'text-neutral-500 hover:text-white hover:bg-neutral-700'
                    }`}
                    title={obj.isLocked ? '已鎖定' : '鎖定圖層'}
                  >
                    {obj.isLocked ? <Lock className="w-3 h-3" /> : <Unlock className="w-3 h-3" />}
                  </button>

                  {/* Visibility Toggle */}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onUpdateObject(obj.id, { isVisible: obj.isVisible === false });
                    }}
                    className={`p-1 rounded-lg transition-colors ${
                      obj.isVisible === false
                        ? 'text-red-400 hover:bg-neutral-700'
                        : 'text-neutral-500 hover:text-white hover:bg-neutral-700'
                    }`}
                    title={obj.isVisible === false ? '點擊顯示' : '隱藏圖層'}
                  >
                    {obj.isVisible === false ? (
                      <EyeOff className="w-3 h-3" />
                    ) : (
                      <Eye className="w-3 h-3" />
                    )}
                  </button>

                  {/* Delete */}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onDelete(obj.id);
                    }}
                    className="p-1 hover:bg-red-500/20 text-neutral-500 hover:text-red-400 rounded-lg transition-colors"
                    title="刪除"
                  >
                    <Trash2 className="w-3 h-3" />
                  </button>
                </div>

                {/* iPhone Style Drag Handle (三條槓拖拉手柄) */}
                <div
                  className="p-1 text-neutral-500 hover:text-white cursor-grab active:cursor-grabbing hover:bg-neutral-700/60 rounded-lg transition-colors shrink-0 ml-0.5"
                  title="按住此處上下拖拉調整圖層順序 (iPhone 手勢)"
                >
                  <GripVertical className="w-4 h-4" />
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Footer Batch Reorder */}
      {selectedIds.length > 0 && (
        <div className="p-3 border-t border-neutral-800 bg-neutral-900/90 flex items-center justify-between text-xs text-neutral-400">
          <span>已選取 {selectedIds.length} 個物件</span>
          <div className="flex items-center gap-1.5">
            <button
              onClick={() => onReorder(selectedIds[0], 'top')}
              className="px-2.5 py-1 bg-neutral-800 hover:bg-neutral-700 rounded-xl text-neutral-200 flex items-center gap-1 text-[11px]"
              title="置頂"
            >
              <ChevronsUp className="w-3 h-3" /> 置頂
            </button>
            <button
              onClick={() => onReorder(selectedIds[0], 'bottom')}
              className="px-2.5 py-1 bg-neutral-800 hover:bg-neutral-700 rounded-xl text-neutral-200 flex items-center gap-1 text-[11px]"
              title="置底"
            >
              <ChevronsDown className="w-3 h-3" /> 置底
            </button>
          </div>
        </div>
      )}
    </aside>
  );
};
