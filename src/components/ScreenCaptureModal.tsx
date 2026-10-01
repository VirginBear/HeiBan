import React, { useState, useRef } from 'react';
import { Camera, Crop, Check, X, Monitor, Clipboard, Sparkles, AlertCircle } from 'lucide-react';

interface ScreenCaptureModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCaptureComplete: (dataUrl: string) => void;
  onStartCanvasAreaSnipping?: () => void;
}

export const ScreenCaptureModal: React.FC<ScreenCaptureModalProps> = ({
  isOpen,
  onClose,
  onCaptureComplete,
  onStartCanvasAreaSnipping,
}) => {
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [isCropping, setIsCropping] = useState(false);
  const [cropBox, setCropBox] = useState<{ startX: number; startY: number; width: number; height: number } | null>(null);
  const [isDraggingCrop, setIsDraggingCrop] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const previewImgRef = useRef<HTMLImageElement>(null);

  if (!isOpen) return null;

  // 1. Native getDisplayMedia screen capture
  const startScreenCapture = async () => {
    setErrorMsg(null);
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getDisplayMedia) {
        throw new Error('此瀏覽器或預覽環境未提供 getDisplayMedia API，請使用「剪貼簿貼上」或「黑板區域截圖」。');
      }

      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: { displaySurface: 'monitor' },
      });

      const video = document.createElement('video');
      video.srcObject = stream;
      await video.play();

      await new Promise((r) => setTimeout(r, 250));

      const canvas = document.createElement('canvas');
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      }

      stream.getTracks().forEach((track) => track.stop());

      const dataUrl = canvas.toDataURL('image/png', 1.0);
      setCapturedImage(dataUrl);
      setIsCropping(false);
      setCropBox(null);
    } catch (err: any) {
      console.warn('Screen capture failed:', err);
      setErrorMsg(
        err.name === 'NotAllowedError'
          ? '使用者已取消選擇或瀏覽器 iframe 權限限制。建議使用下方「直接讀取系統剪貼簿」或快捷鍵 Win+Shift+S 截圖後 Ctrl+V 貼上！'
          : `截圖提示: ${err.message || '瀏覽器環境限制'}`
      );
    }
  };

  // 2. Read directly from system clipboard (Win+Shift+S or Mac Cmd+Shift+4)
  const handleReadClipboard = async () => {
    setErrorMsg(null);
    try {
      if (!navigator.clipboard || !navigator.clipboard.read) {
        throw new Error('瀏覽器不支援 clipboard.read，請直接在畫布上按 Ctrl+V 即可貼上！');
      }
      const clipboardItems = await navigator.clipboard.read();
      for (const item of clipboardItems) {
        const imageType = item.types.find((type) => type.startsWith('image/'));
        if (imageType) {
          const blob = await item.getType(imageType);
          const reader = new FileReader();
          reader.onload = (e) => {
            const dataUrl = e.target?.result as string;
            setCapturedImage(dataUrl);
            setIsCropping(false);
            setCropBox(null);
          };
          reader.readAsDataURL(blob);
          return;
        }
      }
      setErrorMsg('系統剪貼簿中未偵測到圖片。請先使用鍵盤 Win+Shift+S (或 Mac Cmd+Shift+4) 截圖，再點擊讀取！');
    } catch (err: any) {
      setErrorMsg('讀取剪貼簿失敗：' + (err.message || '請直接在黑板畫布按 Ctrl+V 貼上截圖'));
    }
  };

  // Crop interaction handlers
  const handleCropPointerDown = (e: React.PointerEvent) => {
    if (!previewImgRef.current) return;
    const rect = previewImgRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    setIsDraggingCrop(true);
    setCropBox({ startX: x, startY: y, width: 0, height: 0 });
  };

  const handleCropPointerMove = (e: React.PointerEvent) => {
    if (!isDraggingCrop || !cropBox || !previewImgRef.current) return;
    const rect = previewImgRef.current.getBoundingClientRect();
    const currentX = Math.max(0, Math.min(rect.width, e.clientX - rect.left));
    const currentY = Math.max(0, Math.min(rect.height, e.clientY - rect.top));

    setCropBox({
      startX: Math.min(cropBox.startX, currentX),
      startY: Math.min(cropBox.startY, currentY),
      width: Math.abs(currentX - cropBox.startX),
      height: Math.abs(currentY - cropBox.startY),
    });
  };

  const handleCropPointerUp = () => {
    setIsDraggingCrop(false);
  };

  const handleConfirmFull = () => {
    if (capturedImage) {
      onCaptureComplete(capturedImage);
      handleReset();
    }
  };

  const handleConfirmCrop = () => {
    if (!capturedImage || !cropBox || !previewImgRef.current) return;

    const img = new Image();
    img.onload = () => {
      const rect = previewImgRef.current!.getBoundingClientRect();
      const scaleX = img.naturalWidth / rect.width;
      const scaleY = img.naturalHeight / rect.height;

      const cropX = cropBox.startX * scaleX;
      const cropY = cropBox.startY * scaleY;
      const cropW = Math.max(20, cropBox.width * scaleX);
      const cropH = Math.max(20, cropBox.height * scaleY);

      const canvas = document.createElement('canvas');
      canvas.width = cropW;
      canvas.height = cropH;
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.drawImage(img, cropX, cropY, cropW, cropH, 0, 0, cropW, cropH);
      }
      const croppedUrl = canvas.toDataURL('image/png', 1.0);
      onCaptureComplete(croppedUrl);
      handleReset();
    };
    img.src = capturedImage;
  };

  const handleReset = () => {
    setCapturedImage(null);
    setIsCropping(false);
    setCropBox(null);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-in fade-in duration-200">
      <div className="w-full max-w-2xl bg-neutral-900 border border-neutral-700/80 rounded-3xl shadow-2xl overflow-hidden flex flex-col text-neutral-200">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-neutral-800">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-cyan-600/30 text-cyan-400 flex items-center justify-center border border-cyan-500/30">
              <Camera className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base font-bold text-white tracking-tight">螢幕擷取與局部截圖工具</h2>
              <p className="text-xs text-neutral-400">支援自選螢幕 A / B 截圖、剪貼簿一鍵貼上與裁切</p>
            </div>
          </div>
          <button
            onClick={handleReset}
            className="p-1.5 rounded-xl hover:bg-neutral-800 text-neutral-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-4">
          {errorMsg && (
            <div className="p-3 rounded-xl bg-amber-500/20 border border-amber-500/40 text-amber-200 text-xs flex items-start gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 text-amber-400 mt-0.5" />
              <span>{errorMsg}</span>
            </div>
          )}

          {!capturedImage ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {/* Option 1: Native Screen Capture */}
              <div className="p-5 rounded-2xl bg-neutral-800/40 border border-neutral-700/70 flex flex-col items-center justify-between text-center space-y-3">
                <Monitor className="w-10 h-10 text-cyan-400" />
                <div className="space-y-1">
                  <div className="text-sm font-bold text-white">獨立選取螢幕 (螢幕 A / B)</div>
                  <div className="text-[11px] text-neutral-400">
                    系統跳出多螢幕視窗，可直接選取獨立螢幕 A 或 螢幕 B 進行原畫質擷取
                  </div>
                </div>
                <button
                  onClick={startScreenCapture}
                  className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-cyan-600 hover:bg-cyan-500 text-white font-medium text-xs shadow-md transition-all"
                >
                  <Camera className="w-4 h-4" />
                  <span>選取螢幕截圖</span>
                </button>
              </div>

              {/* Option 2: System Clipboard Direct Read (100% reliable) */}
              <div className="p-5 rounded-2xl bg-neutral-800/40 border border-neutral-700/70 flex flex-col items-center justify-between text-center space-y-3">
                <Clipboard className="w-10 h-10 text-emerald-400" />
                <div className="space-y-1">
                  <div className="text-sm font-bold text-white">從系統剪貼簿讀取截圖</div>
                  <div className="text-[11px] text-neutral-400">
                    使用 Win+Shift+S (或 Mac 截圖) 後，點擊此按鈕或直接在黑板按 Ctrl+V 貼上
                  </div>
                </div>
                <button
                  onClick={handleReadClipboard}
                  className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-medium text-xs shadow-md transition-all"
                >
                  <Clipboard className="w-4 h-4" />
                  <span>讀取剪貼簿截圖</span>
                </button>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              <div
                className="relative max-h-96 overflow-hidden rounded-2xl bg-black border border-neutral-800 flex items-center justify-center cursor-crosshair select-none"
                onPointerDown={isCropping ? handleCropPointerDown : undefined}
                onPointerMove={isCropping ? handleCropPointerMove : undefined}
                onPointerUp={isCropping ? handleCropPointerUp : undefined}
              >
                <img
                  ref={previewImgRef}
                  src={capturedImage}
                  alt="Capture preview"
                  className="max-h-96 w-auto object-contain pointer-events-none"
                />

                {isCropping && cropBox && cropBox.width > 2 && (
                  <div
                    className="absolute border-2 border-cyan-400 bg-cyan-400/20 pointer-events-none rounded shadow-2xl"
                    style={{
                      left: `${cropBox.startX}px`,
                      top: `${cropBox.startY}px`,
                      width: `${cropBox.width}px`,
                      height: `${cropBox.height}px`,
                    }}
                  />
                )}
              </div>

              <div className="flex items-center justify-between pt-2">
                <button
                  onClick={() => setCapturedImage(null)}
                  className="px-3 py-1.5 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs text-neutral-300 transition-colors"
                >
                  重新選擇
                </button>

                <div className="flex items-center gap-2">
                  {!isCropping ? (
                    <>
                      <button
                        onClick={() => setIsCropping(true)}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs text-white border border-neutral-600 transition-colors"
                      >
                        <Crop className="w-3.5 h-3.5 text-cyan-400" />
                        <span>裁切局部區域</span>
                      </button>
                      <button
                        onClick={handleConfirmFull}
                        className="flex items-center gap-1.5 px-4 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-xs text-white font-medium shadow-md transition-colors"
                      >
                        <Check className="w-3.5 h-3.5" />
                        <span>匯入完整截圖</span>
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        onClick={() => setIsCropping(false)}
                        className="px-3 py-1.5 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs text-neutral-400 transition-colors"
                      >
                        取消裁切
                      </button>
                      <button
                        onClick={handleConfirmCrop}
                        disabled={!cropBox || cropBox.width < 10}
                        className="flex items-center gap-1.5 px-4 py-1.5 rounded-xl bg-cyan-600 hover:bg-cyan-500 disabled:opacity-50 text-xs text-white font-medium shadow-md transition-colors"
                      >
                        <Check className="w-3.5 h-3.5" />
                        <span>完成裁切並匯入</span>
                      </button>
                    </>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
