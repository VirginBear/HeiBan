import React, { useState } from 'react';
import { BoardMetadata, BoardTheme } from '../types';
import {
  FolderPlus,
  Trash2,
  ExternalLink,
  X,
  Sparkles,
  Palette,
  Check,
  Calendar,
} from 'lucide-react';

interface BoardModalProps {
  isOpen: boolean;
  boards: BoardMetadata[];
  currentBoardId: string;
  onClose: () => void;
  onSelectBoard: (boardId: string) => void;
  onCreateBoard: (title: string, theme: BoardTheme) => void;
  onDeleteBoard: (boardId: string) => void;
}

export const BoardModal: React.FC<BoardModalProps> = ({
  isOpen,
  boards,
  currentBoardId,
  onClose,
  onSelectBoard,
  onCreateBoard,
  onDeleteBoard,
}) => {
  const [newTitle, setNewTitle] = useState('');
  const [selectedTheme, setSelectedTheme] = useState<BoardTheme>('blackboard');

  if (!isOpen) return null;

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;
    onCreateBoard(newTitle.trim(), selectedTheme);
    setNewTitle('');
  };

  const themeOptions: { id: BoardTheme; name: string; bg: string }[] = [
    { id: 'blackboard', name: '經典綠黑板', bg: '#172e25' },
    { id: 'dark', name: '深炭黑黑板', bg: '#121316' },
    { id: 'whiteboard', name: '純淨白板', bg: '#f8fafc' },
    { id: 'slate', name: '石板灰', bg: '#1e2430' },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-md animate-in fade-in duration-150">
      <div className="w-full max-w-xl bg-neutral-900 border border-neutral-700/80 rounded-3xl shadow-2xl overflow-hidden flex flex-col text-neutral-200">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-neutral-800">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-emerald-600/30 text-emerald-400 flex items-center justify-center border border-emerald-500/30">
              <Sparkles className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base font-bold text-white tracking-tight">我的黑板作品集</h2>
              <p className="text-xs text-neutral-400">跨裝置即時同步，隨時切換或開新畫布</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl hover:bg-neutral-800 text-neutral-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6 max-h-[70vh] overflow-y-auto scrollbar-thin">
          {/* Create New Board Form */}
          <form
            onSubmit={handleCreate}
            className="p-4 rounded-2xl bg-neutral-800/40 border border-neutral-700/60 space-y-3"
          >
            <div className="text-xs font-semibold text-neutral-300 flex items-center gap-1.5">
              <FolderPlus className="w-4 h-4 text-emerald-400" />
              <span>建立全新黑板</span>
            </div>

            <div className="flex gap-2">
              <input
                type="text"
                placeholder="輸入黑板名稱 (例如：數學筆記、設計腦力激盪...)"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                className="flex-1 px-3.5 py-2 rounded-xl bg-neutral-900 border border-neutral-700 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-emerald-500 transition-colors"
              />
              <button
                type="submit"
                disabled={!newTitle.trim()}
                className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-medium text-xs transition-colors shrink-0 shadow-md"
              >
                立即建立
              </button>
            </div>

            {/* Initial theme choice */}
            <div className="flex items-center gap-2 pt-1">
              <span className="text-[11px] text-neutral-400">風格：</span>
              <div className="flex items-center gap-1.5">
                {themeOptions.map((t) => (
                  <button
                    type="button"
                    key={t.id}
                    onClick={() => setSelectedTheme(t.id)}
                    className={`flex items-center gap-1.5 px-2 py-1 rounded-lg text-[11px] border transition-all ${
                      selectedTheme === t.id
                        ? 'border-emerald-500 bg-emerald-500/20 text-white'
                        : 'border-neutral-700 text-neutral-400 hover:bg-neutral-800'
                    }`}
                  >
                    <div
                      className="w-3 h-3 rounded-full border border-neutral-600"
                      style={{ backgroundColor: t.bg }}
                    />
                    <span>{t.name}</span>
                  </button>
                ))}
              </div>
            </div>
          </form>

          {/* Existing Boards List */}
          <div>
            <div className="text-xs font-semibold text-neutral-400 uppercase tracking-wider mb-2.5">
              所有黑板紀錄 ({boards.length})
            </div>

            <div className="space-y-2">
              {boards.map((b) => {
                const isCurrent = b.id === currentBoardId;
                return (
                  <div
                    key={b.id}
                    onClick={() => {
                      onSelectBoard(b.id);
                      onClose();
                    }}
                    className={`flex items-center justify-between p-3.5 rounded-2xl border cursor-pointer transition-all ${
                      isCurrent
                        ? 'bg-emerald-600/10 border-emerald-500/60 shadow-sm'
                        : 'bg-neutral-800/30 border-neutral-800 hover:border-neutral-700 hover:bg-neutral-800/60'
                    }`}
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div
                        className="w-8 h-8 rounded-xl border border-white/20 shrink-0 shadow-inner flex items-center justify-center text-xs font-bold text-white/70"
                        style={{ backgroundColor: b.backgroundColor }}
                      >
                        板
                      </div>
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <h3 className="font-semibold text-sm text-white truncate">{b.title}</h3>
                          {isCurrent && (
                            <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 text-[10px] font-medium border border-emerald-500/30">
                              目前開啟
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-3 text-[11px] text-neutral-400 mt-0.5">
                          <span className="flex items-center gap-1">
                            <Calendar className="w-3 h-3" />
                            {new Date(b.updatedAt || b.createdAt).toLocaleDateString()}
                          </span>
                          <span>•</span>
                          <span>建立者: {b.ownerName || '匿名'}</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-1">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          if (confirm(`確定要刪除黑板「${b.title}」嗎？此動作無法復原。`)) {
                            onDeleteBoard(b.id);
                          }
                        }}
                        className="p-2 hover:bg-red-500/20 text-neutral-400 hover:text-red-400 rounded-xl transition-colors"
                        title="刪除黑板"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
