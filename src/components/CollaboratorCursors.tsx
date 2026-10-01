import React from 'react';
import { UserPresence, ViewportTransform } from '../types';

interface CollaboratorCursorsProps {
  presences: UserPresence[];
  currentUserId?: string;
  viewport: ViewportTransform;
  visible: boolean;
}

export const CollaboratorCursors: React.FC<CollaboratorCursorsProps> = ({
  presences,
  currentUserId,
  viewport,
  visible,
}) => {
  if (!visible) return null;

  const others = presences.filter((p) => p.userId !== currentUserId);

  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden z-30">
      {others.map((p) => {
        // Convert canvas coordinates to screen coordinates
        const screenX = p.cursorX * viewport.zoom + viewport.x;
        const screenY = p.cursorY * viewport.zoom + viewport.y;

        // Skip if outside viewport window
        if (
          screenX < -100 ||
          screenY < -100 ||
          screenX > window.innerWidth + 100 ||
          screenY > window.innerHeight + 100
        ) {
          return null;
        }

        const color = p.color || '#3b82f6';

        return (
          <div
            key={p.userId}
            className="absolute transition-all duration-75 ease-out pointer-events-none will-change-transform flex items-start gap-1"
            style={{
              transform: `translate3d(${screenX}px, ${screenY}px, 0)`,
            }}
          >
            {/* Custom SVG Cursor Arrow */}
            <svg
              className="w-5 h-5 drop-shadow-md -rotate-12 transform origin-top-left"
              viewBox="0 0 24 24"
              fill={color}
              stroke="#ffffff"
              strokeWidth="1.5"
            >
              <path d="M5.653 3.123A1.2 1.2 0 0 1 7.42 2.22l11.4 6.6a1.2 1.2 0 0 1 .1 2.05l-4.5 3.15 3.35 6.7a1.2 1.2 0 0 1-1.6 1.6l-3.35-6.7-4.1 3.7A1.2 1.2 0 0 1 6.5 18.5V3.8c0-.25.1-.48.27-.67z" />
            </svg>

            {/* User Badge / Name tag */}
            <div
              className="px-2 py-0.5 rounded-full text-xs font-medium text-white shadow-md flex items-center gap-1.5 whitespace-nowrap backdrop-blur-sm -ml-1 mt-3"
              style={{ backgroundColor: color }}
            >
              {p.photoURL ? (
                <img
                  src={p.photoURL}
                  alt={p.displayName}
                  className="w-3.5 h-3.5 rounded-full border border-white/50 object-cover"
                />
              ) : (
                <span className="w-2 h-2 rounded-full bg-white/70 animate-pulse" />
              )}
              <span>{p.displayName || '協作者'}</span>
              {p.isDrawing && (
                <span className="text-[10px] bg-black/25 px-1 rounded">繪製中...</span>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
};
