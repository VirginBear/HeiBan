import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Check, X, Copy, RotateCcw } from 'lucide-react';

interface CircularColorPickerProps {
  color: string;
  onChange: (hexColor: string) => void;
  onClose?: () => void;
  title?: string;
}

// Convert HSL to HEX
function hslToHex(h: number, s: number, l: number): string {
  const sat = s / 100;
  const light = l / 100;
  const a = sat * Math.min(light, 1 - light);
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    const color = light - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
    return Math.round(255 * color)
      .toString(16)
      .padStart(2, '0');
  };
  return `#${f(0)}${f(8)}${f(4)}`;
}

// Convert HEX to HSL
function hexToHsl(hex: string): { h: number; s: number; l: number } {
  let c = hex.replace('#', '').trim();
  if (c.length === 3) c = c.split('').map((x) => x + x).join('');
  if (c.length !== 6) return { h: 0, s: 0, l: 100 };

  const num = parseInt(c, 16);
  const r = ((num >> 16) & 255) / 255;
  const g = ((num >> 8) & 255) / 255;
  const b = (num & 255) / 255;

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  let s = 0;
  const l = (max + min) / 2;

  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r:
        h = (g - b) / d + (g < b ? 6 : 0);
        break;
      case g:
        h = (b - r) / d + 2;
        break;
      case b:
        h = (r - g) / d + 4;
        break;
    }
    h = Math.round(h * 60);
  }

  return { h, s: Math.round(s * 100), l: Math.round(l * 100) };
}

// Circular Preset Swatches
const CIRCULAR_PRESETS = [
  { hex: '#ffffff', name: '粉筆白' },
  { hex: '#fef08a', name: '粉筆黃' },
  { hex: '#86efac', name: '薄荷綠' },
  { hex: '#93c5fd', name: '天空藍' },
  { hex: '#f472b6', name: '珊瑚粉' },
  { hex: '#fdba74', name: '活力橘' },
  { hex: '#c084fc', name: '夢幻紫' },
  { hex: '#f87171', name: '警示紅' },
  { hex: '#38bdf8', name: '晴空藍' },
  { hex: '#fbbf24', name: '耀眼金' },
  { hex: '#34d399', name: '翡翠綠' },
  { hex: '#1e293b', name: '黑板黑' },
];

export const CircularColorPicker: React.FC<CircularColorPickerProps> = ({
  color,
  onChange,
  onClose,
  title = '圓形調色盤',
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  const initialHsl = hexToHsl(color || '#ffffff');
  const [hue, setHue] = useState(initialHsl.h);
  const [saturation, setSaturation] = useState(initialHsl.s);
  const [lightness, setLightness] = useState(Math.max(10, Math.min(95, initialHsl.l)));
  const [isDraggingWheel, setIsDraggingWheel] = useState(false);
  const [copied, setCopied] = useState(false);

  const WHEEL_SIZE = 190;
  const RADIUS = WHEEL_SIZE / 2;

  // Render the circular color wheel on the canvas
  const drawWheel = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, WHEEL_SIZE, WHEEL_SIZE);

    const imgData = ctx.createImageData(WHEEL_SIZE, WHEEL_SIZE);
    const data = imgData.data;

    for (let y = 0; y < WHEEL_SIZE; y++) {
      for (let x = 0; x < WHEEL_SIZE; x++) {
        const dx = x - RADIUS;
        const dy = y - RADIUS;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist <= RADIUS) {
          // Angle in degrees [0, 360)
          let angle = (Math.atan2(dy, dx) * 180) / Math.PI;
          if (angle < 0) angle += 360;

          // Saturation [0, 1]
          const sat = dist / RADIUS;
          // Use current lightness
          const rgb = hslToRgb(angle, sat, lightness / 100);

          const idx = (y * WHEEL_SIZE + x) * 4;
          data[idx] = rgb[0];
          data[idx + 1] = rgb[1];
          data[idx + 2] = rgb[2];
          // Smooth antialiased circular edge
          const edgeAlpha = dist > RADIUS - 1 ? Math.max(0, RADIUS - dist) : 1;
          data[idx + 3] = Math.round(255 * edgeAlpha);
        }
      }
    }

    ctx.putImageData(imgData, 0, 0);
  }, [lightness, RADIUS, WHEEL_SIZE]);

  useEffect(() => {
    drawWheel();
  }, [drawWheel]);

  // Sync internal state if external color changes
  useEffect(() => {
    const hsl = hexToHsl(color);
    setHue(hsl.h);
    setSaturation(hsl.s);
    if (hsl.l > 0 && hsl.l < 100) {
      setLightness(hsl.l);
    }
  }, [color]);

  // Convert HSL to RGB [0-255, 0-255, 0-255]
  function hslToRgb(h: number, s: number, l: number): [number, number, number] {
    const a = s * Math.min(l, 1 - l);
    const f = (n: number) => {
      const k = (n + h / 30) % 12;
      const col = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
      return Math.round(col * 255);
    };
    return [f(0), f(8), f(4)];
  }

  // Handle pointer interactions on the circular wheel
  const handlePointerWheel = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;

    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const dx = x - RADIUS;
    const dy = y - RADIUS;
    const dist = Math.sqrt(dx * dx + dy * dy);

    let angle = (Math.atan2(dy, dx) * 180) / Math.PI;
    if (angle < 0) angle += 360;

    const sat = Math.min(100, Math.round((Math.min(dist, RADIUS) / RADIUS) * 100));
    const h = Math.round(angle);

    setHue(h);
    setSaturation(sat);

    const newHex = hslToHex(h, sat, lightness);
    onChange(newHex);
  };

  const handlePointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
    e.stopPropagation();
    setIsDraggingWheel(true);
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
    handlePointerWheel(e);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!isDraggingWheel) return;
    e.stopPropagation();
    handlePointerWheel(e);
  };

  const handlePointerUp = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (isDraggingWheel) {
      e.stopPropagation();
      setIsDraggingWheel(false);
      (e.target as HTMLElement).releasePointerCapture?.(e.pointerId);
    }
  };

  const currentHex = hslToHex(hue, saturation, lightness);

  // Compute pointer thumb position in pixels
  const thumbRadius = (saturation / 100) * RADIUS;
  const thumbAngleRad = (hue * Math.PI) / 180;
  const thumbX = RADIUS + thumbRadius * Math.cos(thumbAngleRad);
  const thumbY = RADIUS + thumbRadius * Math.sin(thumbAngleRad);

  const handleCopyHex = () => {
    navigator.clipboard.writeText(currentHex);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div
      ref={containerRef}
      onPointerDown={(e) => e.stopPropagation()}
      className="z-50 bg-neutral-900/98 backdrop-blur-2xl border border-neutral-700/80 rounded-3xl p-4 shadow-2xl text-neutral-200 select-none w-72 animate-in fade-in zoom-in-95 duration-150"
    >
      {/* Header */}
      <div className="flex items-center justify-between pb-2 border-b border-neutral-800 mb-3">
        <div className="flex items-center gap-2">
          <div
            className="w-4 h-4 rounded-full border-2 border-white/60 shadow"
            style={{
              background: 'conic-gradient(from 0deg, red, yellow, lime, aqua, blue, magenta, red)',
            }}
          />
          <h3 className="text-xs font-bold text-white tracking-wide">{title}</h3>
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="p-1 rounded-full text-neutral-400 hover:text-white hover:bg-neutral-800 transition-colors"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        )}
      </div>

      {/* Main Circular Color Wheel Canvas */}
      <div className="relative mx-auto flex items-center justify-center p-1">
        <div className="relative rounded-full shadow-2xl overflow-hidden border-2 border-neutral-600/70">
          <canvas
            ref={canvasRef}
            width={WHEEL_SIZE}
            height={WHEEL_SIZE}
            onPointerDown={handlePointerDown}
            onPointerMove={handlePointerMove}
            onPointerUp={handlePointerUp}
            className="cursor-crosshair block touch-none"
          />

          {/* Interactive Circular Thumb Marker */}
          <div
            className="absolute w-4 h-4 rounded-full border-2 border-white shadow-lg pointer-events-none -translate-x-1/2 -translate-y-1/2 ring-2 ring-black/40"
            style={{
              left: `${thumbX}px`,
              top: `${thumbY}px`,
              backgroundColor: currentHex,
            }}
          />
        </div>
      </div>

      {/* Circular Brightness (Lightness) Slider */}
      <div className="mt-3 px-1 space-y-1">
        <div className="flex items-center justify-between text-[11px] text-neutral-400">
          <span>亮度調節</span>
          <span className="font-mono text-neutral-300">{lightness}%</span>
        </div>
        <div className="relative flex items-center">
          <input
            type="range"
            min="5"
            max="95"
            value={lightness}
            onChange={(e) => {
              const newL = parseInt(e.target.value, 10);
              setLightness(newL);
              const updated = hslToHex(hue, saturation, newL);
              onChange(updated);
            }}
            className="w-full h-2.5 rounded-full appearance-none cursor-pointer border border-neutral-700 outline-none"
            style={{
              background: `linear-gradient(to right, #000000, ${hslToHex(hue, saturation, 50)}, #ffffff)`,
            }}
          />
        </div>
      </div>

      {/* Quick Circular Preset Swatches (100% Round Swatches) */}
      <div className="mt-3.5 pt-2.5 border-t border-neutral-800">
        <div className="text-[10px] font-medium text-neutral-400 mb-1.5 flex items-center justify-between">
          <span>粉筆與常用圓盤</span>
          <button
            onClick={() => {
              setHue(0);
              setSaturation(0);
              setLightness(100);
              onChange('#ffffff');
            }}
            className="text-[10px] text-neutral-500 hover:text-neutral-300 flex items-center gap-1"
            title="重設為純白"
          >
            <RotateCcw className="w-2.5 h-2.5" /> 重設
          </button>
        </div>
        <div className="grid grid-cols-6 gap-2 place-items-center">
          {CIRCULAR_PRESETS.map((p) => (
            <button
              key={p.hex}
              onClick={() => {
                const hsl = hexToHsl(p.hex);
                setHue(hsl.h);
                setSaturation(hsl.s);
                setLightness(hsl.l);
                onChange(p.hex);
              }}
              className={`w-6 h-6 rounded-full border-2 transition-all hover:scale-125 shadow-sm ${
                currentHex.toLowerCase() === p.hex.toLowerCase()
                  ? 'border-white scale-110 shadow-md ring-2 ring-emerald-500'
                  : 'border-neutral-700/80 hover:border-neutral-400'
              }`}
              style={{ backgroundColor: p.hex }}
              title={p.name}
            />
          ))}
        </div>
      </div>

      {/* Live Preview Circle & Hex Info */}
      <div className="mt-3 pt-2 border-t border-neutral-800 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div
            className="w-7 h-7 rounded-full border-2 border-white shadow-md"
            style={{ backgroundColor: currentHex }}
          />
          <span className="font-mono text-xs font-bold text-white tracking-wider">
            {currentHex.toUpperCase()}
          </span>
        </div>
        <button
          onClick={handleCopyHex}
          className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-neutral-800 hover:bg-neutral-700 text-neutral-300 hover:text-white text-[11px] transition-colors border border-neutral-700/60"
          title="複製色碼"
        >
          {copied ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
          <span>{copied ? '已複製' : '複製'}</span>
        </button>
      </div>
    </div>
  );
};
