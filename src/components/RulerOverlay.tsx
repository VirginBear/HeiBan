import React, { useRef } from 'react';
import { RulerState } from '../types';
import { RotateCw, X, Move, MapPin, Eye } from 'lucide-react';

interface RulerOverlayProps {
  ruler: RulerState;
  onUpdateRuler: (partial: Partial<RulerState>) => void;
  onClose: () => void;
}

export const RulerOverlay: React.FC<RulerOverlayProps> = ({
  ruler,
  onUpdateRuler,
  onClose,
}) => {
  const isDraggingBodyRef = useRef(false);
  const dragStartRef = useRef({ x: 0, y: 0, centerX: 0, centerY: 0 });

  if (!ruler.enabled) return null;

  const rulerWidth = ruler.width || 1100;
  const rulerHeight = ruler.height || 80;
  const rulerOpacity = ruler.opacity ?? 0.35;
  const pivotRatio = ruler.pivotRatio ?? 0; // -0.5 (left) to 0.5 (right)
  const pivotEdge = ruler.pivotEdge || 'center'; // 'top' | 'center' | 'bottom'

  // Calculate Screen coordinates of the Pivot Point
  const rad = (ruler.angle * Math.PI) / 180;
  const cos = Math.cos(rad);
  const sin = Math.sin(rad);

  const localPivotX = pivotRatio * rulerWidth;
  const localPivotY = pivotEdge === 'top' ? -rulerHeight / 2 : pivotEdge === 'bottom' ? rulerHeight / 2 : 0;

  const screenPivotX = ruler.screenCenterX + localPivotX * cos - localPivotY * sin;
  const screenPivotY = ruler.screenCenterY + localPivotX * sin + localPivotY * cos;

  // Drag the body to move ruler across screen
  const handleBodyPointerDown = (e: React.PointerEvent) => {
    if (
      (e.target as HTMLElement).closest('.ruler-handle') ||
      (e.target as HTMLElement).closest('.ruler-action') ||
      (e.target as HTMLElement).closest('.ruler-pivot')
    ) {
      return;
    }
    e.stopPropagation();
    isDraggingBodyRef.current = true;
    dragStartRef.current = {
      x: e.clientX,
      y: e.clientY,
      centerX: ruler.screenCenterX,
      centerY: ruler.screenCenterY,
    };

    let rafId: number | null = null;
    let pendingPos: { x: number; y: number } | null = null;

    const handlePointerMove = (moveEv: PointerEvent) => {
      if (!isDraggingBodyRef.current) return;
      const dx = moveEv.clientX - dragStartRef.current.x;
      const dy = moveEv.clientY - dragStartRef.current.y;
      pendingPos = {
        x: dragStartRef.current.centerX + dx,
        y: dragStartRef.current.centerY + dy,
      };
      if (rafId === null) {
        rafId = requestAnimationFrame(() => {
          rafId = null;
          if (pendingPos) {
            onUpdateRuler({
              screenCenterX: pendingPos.x,
              screenCenterY: pendingPos.y,
            });
          }
        });
      }
    };

    const handlePointerUp = () => {
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
      if (pendingPos) {
        onUpdateRuler({
          screenCenterX: pendingPos.x,
          screenCenterY: pendingPos.y,
        });
      }
      isDraggingBodyRef.current = false;
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerUp);
    };

    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerUp);
  };

  // Drag the Pivot point to set custom rotation center
  const handlePivotPointerDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    let rafId: number | null = null;
    let pendingPivot: { pivotRatio: number; pivotEdge: 'top' | 'center' | 'bottom' } | null = null;

    const handlePointerMove = (moveEv: PointerEvent) => {
      // Convert pointer to ruler local coordinates
      const dx = moveEv.clientX - ruler.screenCenterX;
      const dy = moveEv.clientY - ruler.screenCenterY;
      const rCos = Math.cos(-rad);
      const rSin = Math.sin(-rad);
      const locX = dx * rCos - dy * rSin;
      const locY = dx * rSin + dy * rCos;

      const newRatio = Math.max(-0.45, Math.min(0.45, locX / rulerWidth));
      let newEdge: 'top' | 'center' | 'bottom' = 'center';
      if (locY < -rulerHeight / 4) newEdge = 'top';
      else if (locY > rulerHeight / 4) newEdge = 'bottom';

      pendingPivot = { pivotRatio: newRatio, pivotEdge: newEdge };
      if (rafId === null) {
        rafId = requestAnimationFrame(() => {
          rafId = null;
          if (pendingPivot) {
            onUpdateRuler(pendingPivot);
          }
        });
      }
    };

    const handlePointerUp = () => {
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
      if (pendingPivot) {
        onUpdateRuler(pendingPivot);
      }
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerUp);
    };

    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerUp);
  };

  // Drag either left or right handle at the ends to rotate the ruler AROUND THE PIVOT
  const handleEndHandleRotate = (isRightEnd: boolean, e: React.PointerEvent) => {
    e.stopPropagation();
    let rafId: number | null = null;
    let pendingRotate: { angle: number; screenCenterX: number; screenCenterY: number } | null = null;

    const handlePointerMove = (moveEv: PointerEvent) => {
      // Angle from pivot point to cursor
      let curRad = Math.atan2(moveEv.clientY - screenPivotY, moveEv.clientX - screenPivotX);
      let deg = (curRad * 180) / Math.PI;

      // Calculate initial relative angle of the handle from the pivot
      const handleLocalX = isRightEnd ? rulerWidth / 2 : -rulerWidth / 2;
      const handleLocalY = 0;
      const baseOffsetRad = Math.atan2(handleLocalY - localPivotY, handleLocalX - localPivotX);
      const baseOffsetDeg = (baseOffsetRad * 180) / Math.PI;

      let newAngle = (deg - baseOffsetDeg) % 360;
      if (newAngle < 0) newAngle += 360;

      // Snap to standard 0, 30, 45, 60, 90, 180, 270 degrees
      const snapAngles = [0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330, 360];
      for (const snap of snapAngles) {
        if (Math.abs(newAngle - snap) < 2) {
          newAngle = snap % 360;
          break;
        }
      }

      // Keep screen pivot stationary while rotating around it
      const newRad = (newAngle * Math.PI) / 180;
      const nCos = Math.cos(newRad);
      const nSin = Math.sin(newRad);
      const newCenterX = screenPivotX - (localPivotX * nCos - localPivotY * nSin);
      const newCenterY = screenPivotY - (localPivotX * nSin + localPivotY * nCos);

      pendingRotate = {
        angle: Math.round(newAngle),
        screenCenterX: newCenterX,
        screenCenterY: newCenterY,
      };

      if (rafId === null) {
        rafId = requestAnimationFrame(() => {
          rafId = null;
          if (pendingRotate) {
            onUpdateRuler(pendingRotate);
          }
        });
      }
    };

    const handlePointerUp = () => {
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
      if (pendingRotate) {
        onUpdateRuler(pendingRotate);
      }
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerUp);
    };

    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerUp);
  };

  // Wheel to rotate
  const handleWheel = (e: React.WheelEvent) => {
    e.stopPropagation();
    const delta = e.deltaY > 0 ? 2 : -2;
    let newAngle = (ruler.angle + delta) % 360;
    if (newAngle < 0) newAngle += 360;
    onUpdateRuler({ angle: newAngle });
  };

  // Generate tick marks along physical length
  const totalCm = 50;
  const ticks = [];
  for (let i = 0; i <= totalCm; i++) {
    const isMajor = i % 5 === 0;
    const isCm = i % 10 === 0;
    const leftPx = (i / totalCm) * (rulerWidth - 80) + 40;
    ticks.push(
      <div
        key={`t-${i}`}
        className="absolute top-0 pointer-events-none"
        style={{ left: `${leftPx}px` }}
      >
        <div
          className={`w-[1px] ${
            isCm ? 'h-4 bg-neutral-900' : isMajor ? 'h-2.5 bg-neutral-700' : 'h-1.5 bg-neutral-500'
          }`}
        />
        {isCm && (
          <span className="text-[10px] font-mono font-bold text-neutral-900 absolute -bottom-3.5 -left-1">
            {i / 10}
          </span>
        )}
      </div>
    );
    // Bottom scale ticks
    ticks.push(
      <div
        key={`b-${i}`}
        className="absolute bottom-0 pointer-events-none"
        style={{ left: `${leftPx}px` }}
      >
        <div
          className={`w-[1px] absolute bottom-0 ${
            isCm ? 'h-4 bg-neutral-900' : isMajor ? 'h-2.5 bg-neutral-700' : 'h-1.5 bg-neutral-500'
          }`}
        />
      </div>
    );
  }

  return (
    <div
      onPointerDown={handleBodyPointerDown}
      onWheel={handleWheel}
      className="fixed z-40 select-none cursor-grab active:cursor-grabbing backdrop-blur-md rounded-2xl border-2 border-amber-300/80 shadow-2xl transition-shadow"
      style={{
        width: `${rulerWidth}px`,
        height: `${rulerHeight}px`,
        left: `${ruler.screenCenterX - rulerWidth / 2}px`,
        top: `${ruler.screenCenterY - rulerHeight / 2}px`,
        backgroundColor: `rgba(254, 243, 199, ${rulerOpacity})`,
        transform: `rotate(${ruler.angle}deg)`,
        transformOrigin: 'center center',
        touchAction: 'none',
      }}
    >
      <div className="relative w-full h-full overflow-hidden rounded-2xl">
        {ticks}

        {/* Center Move Badge & Opacity Controls */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-neutral-900/85 text-white shadow-lg border border-white/20 pointer-events-none text-xs">
            <Move className="w-3.5 h-3.5 text-amber-400" />
            <span className="font-mono font-bold">{ruler.angle}°</span>
            <span className="text-[10px] text-neutral-400 hidden sm:inline">拖曳移動 / 兩端旋轉</span>
          </div>

          {/* Opacity Selector (透明度調整) */}
          <div className="ruler-action pointer-events-auto flex items-center gap-1 px-2 py-1 rounded-full bg-neutral-900/80 text-white shadow border border-white/20 text-[10px]">
            <Eye className="w-3 h-3 text-cyan-400" />
            <span>透:</span>
            {[0.2, 0.4, 0.7].map((op) => (
              <button
                key={op}
                onClick={(e) => {
                  e.stopPropagation();
                  onUpdateRuler({ opacity: op });
                }}
                className={`px-1.5 py-0.5 rounded transition-colors ${
                  Math.abs(rulerOpacity - op) < 0.08
                    ? 'bg-amber-500 text-neutral-950 font-bold'
                    : 'text-neutral-400 hover:text-white'
                }`}
              >
                {Math.round(op * 100)}%
              </button>
            ))}
          </div>

          <button
            onClick={(e) => {
              e.stopPropagation();
              onClose();
            }}
            className="ruler-action pointer-events-auto p-1.5 rounded-full bg-neutral-900/80 text-neutral-300 hover:text-white hover:bg-neutral-900 shadow border border-white/20 transition-colors"
            title="關閉尺規"
          >
            <X className="w-3 h-3" />
          </button>
        </div>

        {/* User-Draggable Rotation Pivot (使用者可拖拉的旋轉固定支點) */}
        <div
          onPointerDown={handlePivotPointerDown}
          className="ruler-pivot absolute z-50 pointer-events-auto cursor-grab active:cursor-grabbing -translate-x-1/2 -translate-y-1/2 group"
          style={{
            left: `${rulerWidth / 2 + localPivotX}px`,
            top: `${rulerHeight / 2 + localPivotY}px`,
          }}
          title="旋轉固定支點：拖曳可移動至上方刻度、下方刻度或任意位置"
        >
          <div className="relative flex items-center justify-center">
            <div className="w-6 h-6 rounded-full bg-rose-600/90 border-2 border-white shadow-lg flex items-center justify-center text-white text-[10px] font-bold group-hover:scale-110 transition-transform">
              <MapPin className="w-3.5 h-3.5" />
            </div>
            <span className="absolute -bottom-5 whitespace-nowrap text-[9px] px-1.5 py-0.5 rounded bg-black/80 text-rose-300 font-medium opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
              旋轉支點 ({pivotEdge === 'top' ? '上刻度' : pivotEdge === 'bottom' ? '下刻度' : '中心'})
            </span>
          </div>
        </div>

        {/* Left End Rotation Handle */}
        <div
          onPointerDown={(e) => handleEndHandleRotate(false, e)}
          className="ruler-handle absolute left-3 top-1/2 -translate-y-1/2 flex items-center gap-1 px-2.5 py-1 rounded-xl bg-amber-500 hover:bg-amber-400 text-neutral-950 font-bold text-[11px] shadow-lg cursor-alias pointer-events-auto border border-white/80 active:scale-105 transition-transform"
          title="以支點為中心拖曳旋轉"
        >
          <RotateCw className="w-3.5 h-3.5" />
          <span>左端旋轉</span>
        </div>

        {/* Right End Rotation Handle */}
        <div
          onPointerDown={(e) => handleEndHandleRotate(true, e)}
          className="ruler-handle absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-1 px-2.5 py-1 rounded-xl bg-amber-500 hover:bg-amber-400 text-neutral-950 font-bold text-[11px] shadow-lg cursor-alias pointer-events-auto border border-white/80 active:scale-105 transition-transform"
          title="以支點為中心拖曳旋轉"
        >
          <RotateCw className="w-3.5 h-3.5" />
          <span>右端旋轉</span>
        </div>
      </div>
    </div>
  );
};
