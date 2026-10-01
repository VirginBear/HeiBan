import React, { useState, useRef, useEffect } from 'react';
import { Crop, RotateCcw, Check, X } from 'lucide-react';
import { BoardObject } from '../types';

interface ImageCropModalProps {
  imageObject: BoardObject | null;
  isOpen: boolean;
  onClose: () => void;
  onSaveCrop: (objectId: string, newImageUrl: string, newWidth: number, newHeight: number) => void;
  onResetOriginal: (objectId: string) => void;
}

export const ImageCropModal: React.FC<ImageCropModalProps> = ({
  imageObject,
  isOpen,
  onClose,
  onSaveCrop,
  onResetOriginal,
}) => {
  const [crop, setCrop] = useState<{ x: number; y: number; width: number; height: number }>({
    x: 0.1,
    y: 0.1,
    width: 0.8,
    height: 0.8,
  });
  const [isDragging, setIsDragging] = useState<string | null>(null);
  const [dragStart, setDragStart] = useState<{ x: number; y: number; crop: typeof crop } | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    if (isOpen) {
      setCrop({ x: 0.05, y: 0.05, width: 0.9, height: 0.9 });
    }
  }, [isOpen, imageObject?.id]);

  if (!isOpen || !imageObject || !imageObject.imageUrl) return null;

  const currentSrc = imageObject.originalImageUrl || imageObject.imageUrl;

  const handlePointerDown = (handle: string, e: React.PointerEvent) => {
    e.stopPropagation();
    setIsDragging(handle);
    setDragStart({ x: e.clientX, y: e.clientY, crop: { ...crop } });
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging || !dragStart || !containerRef.current) return;
    const rect = containerRef.current.getBoundingClientRect();
    const dx = (e.clientX - dragStart.x) / rect.width;
    const dy = (e.clientY - dragStart.y) / rect.height;

    const init = dragStart.crop;
    let newCrop = { ...init };

    if (isDragging === 'move') {
      newCrop.x = Math.max(0, Math.min(1 - init.width, init.x + dx));
      newCrop.y = Math.max(0, Math.min(1 - init.height, init.y + dy));
    } else {
      if (isDragging.includes('l')) {
        const nx = Math.max(0, Math.min(init.x + init.width - 0.1, init.x + dx));
        newCrop.width = init.width + (init.x - nx);
        newCrop.x = nx;
      }
      if (isDragging.includes('r')) {
        newCrop.width = Math.max(0.1, Math.min(1 - init.x, init.width + dx));
      }
      if (isDragging.includes('t')) {
        const ny = Math.max(0, Math.min(init.y + init.height - 0.1, init.y + dy));
        newCrop.height = init.height + (init.y - ny);
        newCrop.y = ny;
      }
      if (isDragging.includes('b')) {
        newCrop.height = Math.max(0.1, Math.min(1 - init.y, init.height + dy));
      }
    }

    setCrop(newCrop);
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    (e.target as HTMLElement).releasePointerCapture?.(e.pointerId);
    setIsDragging(null);
    setDragStart(null);
  };

  const handleConfirmCrop = () => {
    const img = imgRef.current;
    if (!img) return;

    const canvas = document.createElement('canvas');
    const sx = crop.x * img.naturalWidth;
    const sy = crop.y * img.naturalHeight;
    const sw = crop.width * img.naturalWidth;
    const sh = crop.height * img.naturalHeight;

    canvas.width = Math.max(1, Math.round(sw));
    canvas.height = Math.max(1, Math.round(sh));

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.drawImage(img, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height);
    const croppedDataUrl = canvas.toDataURL('image/png');

    // Scale new dimensions proportionally based on current board object size
    const currentW = imageObject.width;
    const newW = Math.round(currentW * crop.width);
    const newH = Math.round((newW * canvas.height) / canvas.width);

    onSaveCrop(imageObject.id, croppedDataUrl, newW, newH);
    onClose();
  };

  const handleReset = () => {
    onResetOriginal(imageObject.id);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-150 select-none">
      <div className="w-full max-w-3xl bg-neutral-900 border border-neutral-700/80 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-neutral-800">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-cyan-600/20 text-cyan-400">
              <Crop className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-base text-white">圖片二次裁切</h3>
              <p className="text-xs text-neutral-400">拖曳裁切框調整保留範圍，可隨時還原至最初匯入狀態</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 text-neutral-400 hover:text-white rounded-xl hover:bg-neutral-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Image & Interactive Crop Box Area */}
        <div className="flex-1 p-6 flex items-center justify-center overflow-hidden bg-neutral-950/70">
          <div
            ref={containerRef}
            onPointerMove={handlePointerMove}
            onPointerUp={handlePointerUp}
            className="relative inline-block max-h-[55vh] max-w-full select-none"
          >
            <img
              ref={imgRef}
              src={currentSrc}
              alt="裁切預覽"
              className="max-h-[55vh] max-w-full object-contain pointer-events-none rounded shadow"
            />

            {/* Dark Mask Overlay Outside Crop Box */}
            <div className="absolute inset-0 pointer-events-none">
              {/* Top Mask */}
              <div
                className="absolute bg-black/60 top-0 left-0 right-0"
                style={{ height: `${crop.y * 100}%` }}
              />
              {/* Bottom Mask */}
              <div
                className="absolute bg-black/60 left-0 right-0 bottom-0"
                style={{ height: `${(1 - (crop.y + crop.height)) * 100}%` }}
              />
              {/* Left Mask */}
              <div
                className="absolute bg-black/60 left-0"
                style={{
                  top: `${crop.y * 100}%`,
                  height: `${crop.height * 100}%`,
                  width: `${crop.x * 100}%`,
                }}
              />
              {/* Right Mask */}
              <div
                className="absolute bg-black/60 right-0"
                style={{
                  top: `${crop.y * 100}%`,
                  height: `${crop.height * 100}%`,
                  width: `${(1 - (crop.x + crop.width)) * 100}%`,
                }}
              />
            </div>

            {/* Active Crop Box with Handles */}
            <div
              onPointerDown={(e) => handlePointerDown('move', e)}
              className="absolute border-2 border-cyan-400 shadow-2xl cursor-move pointer-events-auto"
              style={{
                left: `${crop.x * 100}%`,
                top: `${crop.y * 100}%`,
                width: `${crop.width * 100}%`,
                height: `${crop.height * 100}%`,
              }}
            >
              {/* Grid 3x3 lines */}
              <div className="absolute inset-0 grid grid-cols-3 grid-rows-3 pointer-events-none opacity-40">
                <div className="border-r border-b border-white" />
                <div className="border-r border-b border-white" />
                <div className="border-b border-white" />
                <div className="border-r border-b border-white" />
                <div className="border-r border-b border-white" />
                <div className="border-b border-white" />
                <div className="border-r border-white" />
                <div className="border-r border-white" />
                <div />
              </div>

              {/* 8 Resize Handles */}
              {[
                { id: 'tl', class: '-left-2 -top-2 cursor-nwse-resize' },
                { id: 'tm', class: 'left-1/2 -translate-x-1/2 -top-2 cursor-ns-resize' },
                { id: 'tr', class: '-right-2 -top-2 cursor-nesw-resize' },
                { id: 'mr', class: '-right-2 top-1/2 -translate-y-1/2 cursor-ew-resize' },
                { id: 'br', class: '-right-2 -bottom-2 cursor-nwse-resize' },
                { id: 'bm', class: 'left-1/2 -translate-x-1/2 -bottom-2 cursor-ns-resize' },
                { id: 'bl', class: '-left-2 -bottom-2 cursor-nesw-resize' },
                { id: 'ml', class: '-left-2 top-1/2 -translate-y-1/2 cursor-ew-resize' },
              ].map((h) => (
                <div
                  key={h.id}
                  onPointerDown={(e) => handlePointerDown(h.id, e)}
                  className={`absolute w-3.5 h-3.5 bg-white border-2 border-cyan-500 rounded-sm shadow-md hover:scale-125 transition-transform ${h.class}`}
                />
              ))}
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="px-6 py-4 border-t border-neutral-800 bg-neutral-900/90 flex items-center justify-between">
          <button
            onClick={handleReset}
            className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-neutral-300 hover:text-white text-xs font-medium transition-colors"
            title="還原為剛匯入的高畫質完整圖片"
          >
            <RotateCcw className="w-4 h-4 text-amber-400" />
            <span>重置原始圖片</span>
          </button>

          <div className="flex items-center gap-2">
            <button
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-xs text-neutral-400 hover:text-white hover:bg-neutral-800 transition-colors"
            >
              取消
            </button>
            <button
              onClick={handleConfirmCrop}
              className="flex items-center gap-1.5 px-5 py-2 rounded-xl bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 text-white text-xs font-bold shadow-lg transition-transform active:scale-95"
            >
              <Check className="w-4 h-4" />
              <span>確認裁切並套用</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
