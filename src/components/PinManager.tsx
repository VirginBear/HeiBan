import React, { useState } from 'react';
import { BoardPin, ViewportTransform } from '../types';
import { Pin, Plus, Trash2, X, CornerLeftUp, Edit3, Check } from 'lucide-react';

interface PinManagerProps {
  pins: BoardPin[];
  viewport: ViewportTransform;
  isOpen: boolean;
  onClose: () => void;
  onAddPin: (name: string, x: number, y: number, zoom: number) => void;
  onUpdatePin?: (id: string, partial: Partial<BoardPin>) => void;
  onDeletePin: (id: string) => void;
  onJumpToPin: (pin: BoardPin) => void;
}

export const PinManager: React.FC<PinManagerProps> = ({
  pins,
  viewport,
  isOpen,
  onClose,
  onAddPin,
  onUpdatePin,
  onDeletePin,
  onJumpToPin,
}) => {
  const [newPinName, setNewPinName] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingName, setEditingName] = useState('');

  if (!isOpen) return null;

  const handleAddCurrentLocation = (e: React.FormEvent) => {
    e.preventDefault();
    const name = newPinName.trim() || `畫布圖釘 #${pins.length + 1}`;
    // Pin at comfortable center of current view
    const centerX = Math.round((window.innerWidth / 2 - viewport.x) / viewport.zoom);
    const centerY = Math.round((window.innerHeight / 2 - viewport.y) / viewport.zoom);
    onAddPin(name, centerX, centerY, viewport.zoom);
    setNewPinName('');
  };

  const handleSaveRename = (id: string) => {
    if (editingName.trim() && onUpdatePin) {
      onUpdatePin(id, { name: editingName.trim() });
    }
    setEditingId(null);
  };

  return (
    <div className="absolute left-4 top-16 z-40 w-80 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl shadow-2xl p-4 text-neutral-200 animate-in fade-in slide-in-from-top-2 duration-150">
      <div className="flex items-center justify-between pb-3 border-b border-neutral-800">
        <div className="flex items-center gap-2">
          <Pin className="w-4 h-4 text-rose-400 rotate-45" />
          <h2 className="text-sm font-bold text-white">畫布實體圖釘</h2>
          <span className="text-[10px] px-2 py-0.5 rounded-full bg-rose-500/20 text-rose-300 font-mono">
            {pins.length}
          </span>
        </div>
        <button
          onClick={onClose}
          className="p-1 text-neutral-400 hover:text-white rounded-lg hover:bg-neutral-800 transition-colors"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      <div className="py-2 text-[11px] text-neutral-400 leading-relaxed">
        圖釘會以真實圖釘 ICON 顯示在畫布上，可自由拖曳並自訂名稱；點擊圖釘或列表會以<span className="text-rose-400 font-semibold">平滑曲線自動移動置於「左上方」</span>視角。
      </div>

      {/* Add current view form */}
      <form onSubmit={handleAddCurrentLocation} className="space-y-2 mt-1">
        <div className="flex gap-1.5">
          <input
            type="text"
            placeholder="自訂圖釘名稱 (如：解題公式、板書大綱)..."
            value={newPinName}
            onChange={(e) => setNewPinName(e.target.value)}
            className="flex-1 px-3 py-1.5 rounded-xl bg-neutral-800 border border-neutral-700 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-rose-500"
          />
          <button
            type="submit"
            className="p-2 rounded-xl bg-rose-600 hover:bg-rose-500 text-white shadow transition-colors flex items-center justify-center shrink-0"
            title="釘選目前視野"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>
      </form>

      {/* Pins List */}
      <div className="mt-3 space-y-1.5 max-h-56 overflow-y-auto scrollbar-thin">
        {pins.length === 0 ? (
          <div className="text-center py-5 text-neutral-500 text-xs space-y-1">
            <Pin className="w-6 h-6 mx-auto opacity-30 rotate-45" />
            <p>尚未建立圖釘</p>
            <p className="text-[10px] text-neutral-600">可使用下方工具列的圖釘工具，直接點擊畫布釘上！</p>
          </div>
        ) : (
          pins.map((pin) => (
            <div
              key={pin.id}
              onClick={() => onJumpToPin(pin)}
              className="group flex items-center justify-between p-2 rounded-xl bg-neutral-800/40 hover:bg-neutral-800 border border-transparent hover:border-neutral-700 cursor-pointer transition-all"
            >
              <div className="flex items-center gap-2 min-w-0 flex-1">
                <div className="p-1 rounded-lg bg-rose-500/20 text-rose-400 group-hover:scale-110 transition-transform shrink-0">
                  <Pin className="w-3.5 h-3.5 rotate-45" />
                </div>
                <div className="min-w-0 flex-1">
                  {editingId === pin.id ? (
                    <div className="flex items-center gap-1" onClick={(e) => e.stopPropagation()}>
                      <input
                        type="text"
                        autoFocus
                        value={editingName}
                        onChange={(e) => setEditingName(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') handleSaveRename(pin.id);
                          if (e.key === 'Escape') setEditingId(null);
                        }}
                        className="w-full px-1.5 py-0.5 bg-neutral-900 border border-rose-500 rounded text-xs text-white outline-none"
                      />
                      <button
                        onClick={() => handleSaveRename(pin.id)}
                        className="p-1 text-emerald-400 hover:text-white"
                      >
                        <Check className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ) : (
                    <>
                      <div className="text-xs font-medium text-neutral-200 truncate flex items-center gap-1.5">
                        <span className="truncate">{pin.name}</span>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setEditingId(pin.id);
                            setEditingName(pin.name);
                          }}
                          className="opacity-0 group-hover:opacity-100 p-0.5 text-neutral-500 hover:text-neutral-300"
                          title="修改圖釘名稱"
                        >
                          <Edit3 className="w-3 h-3" />
                        </button>
                      </div>
                      <div className="text-[10px] text-neutral-500 font-mono">
                        ({Math.round(pin.x)}, {Math.round(pin.y)})
                      </div>
                    </>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-1 shrink-0">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onJumpToPin(pin);
                  }}
                  className="p-1 text-neutral-400 hover:text-white rounded-lg hover:bg-neutral-700 transition-colors"
                  title="平滑移動置於左上方視角"
                >
                  <CornerLeftUp className="w-3.5 h-3.5 text-rose-400" />
                </button>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onDeletePin(pin.id);
                  }}
                  className="opacity-0 group-hover:opacity-100 p-1 hover:bg-neutral-700 text-neutral-400 hover:text-red-400 rounded-lg transition-all"
                  title="刪除圖釘"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
