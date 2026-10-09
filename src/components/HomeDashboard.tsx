import React, { useState } from 'react';
import { User } from 'firebase/auth';
import { BoardMetadata, BoardTheme, CanvasMode, CanvasPreset, GridStyle } from '../types';
import {
  FolderPlus,
  Plus,
  Trash2,
  Share2,
  Calendar,
  Layers,
  Settings,
  MessageSquare,
  LogOut,
  LogIn,
  Search,
  Check,
  Sparkles,
  ExternalLink,
  ChevronDown,
  X,
  Palette,
  Maximize2,
  FileText,
  BookOpen,
  CircleHelp,
} from 'lucide-react';
import { SettingsModal } from './SettingsModal';

interface HomeDashboardProps {
  boards: BoardMetadata[];
  currentBoardId: string;
  user: User | null;
  onOpenBoard: (boardId: string) => void;
  onCreateBoard: (
    title: string,
    theme: BoardTheme,
    canvasMode?: CanvasMode,
    canvasPreset?: CanvasPreset,
    width?: number,
    height?: number,
    options?: {
      orientation?: 'portrait' | 'landscape';
      coverStyle?: string;
      gridStyle?: GridStyle;
      backgroundColor?: string;
      gridColor?: string;
    }
  ) => void;
  onDeleteBoard: (boardId: string) => void;
  onLoadShowcaseBoard?: () => void;
  onSignIn: () => void;
  onSignOut: () => void;
  defaultTheme?: BoardTheme;
  onChangeDefaultTheme?: (theme: BoardTheme) => void;
  defaultFont?: string;
  onChangeDefaultFont?: (font: string) => void;
}

export const HomeDashboard: React.FC<HomeDashboardProps> = ({
  boards,
  currentBoardId,
  user,
  onOpenBoard,
  onCreateBoard,
  onDeleteBoard,
  onLoadShowcaseBoard,
  onSignIn,
  onSignOut,
  defaultTheme = 'blackboard',
  onChangeDefaultTheme,
  defaultFont,
  onChangeDefaultFont,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [showProfileMenu, setShowProfileMenu] = useState(false);
  const [showFeedbackModal, setShowFeedbackModal] = useState(false);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newBoardTitle, setNewBoardTitle] = useState('');
  const [newBoardTheme, setNewBoardTheme] = useState<BoardTheme>('blackboard');
  const [newCanvasMode, setNewCanvasMode] = useState<CanvasMode>('infinite');
  const [newCanvasPreset, setNewCanvasPreset] = useState<CanvasPreset>('a4_portrait');
  const [newOrientation, setNewOrientation] = useState<'portrait' | 'landscape'>('portrait');
  const [newCoverStyle, setNewCoverStyle] = useState<string>('classic_blackboard');
  const [newGridStyle, setNewGridStyle] = useState<GridStyle>('grid');
  const [newBgColor, setNewBgColor] = useState<string>('#172e25');
  const [newGridColor, setNewGridColor] = useState<string | undefined>(undefined);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [feedbackText, setFeedbackText] = useState('');
  const [feedbackSuccess, setFeedbackSuccess] = useState(false);

  const filteredBoards = boards.filter((b) =>
    (b.title || '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  const handleShareBoard = (b: BoardMetadata, e: React.MouseEvent) => {
    e.stopPropagation();
    const url = new URL(window.location.href);
    url.searchParams.set('board', b.id);
    navigator.clipboard.writeText(url.toString());
    setCopiedId(b.id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleSendFeedback = (e: React.FormEvent) => {
    e.preventDefault();
    if (!feedbackText.trim()) return;
    setFeedbackSuccess(true);
    setTimeout(() => {
      setFeedbackSuccess(false);
      setShowFeedbackModal(false);
      setFeedbackText('');
    }, 1500);
  };

  const templateThemes: { id: BoardTheme; title: string; bg: string; subtitle: string }[] = [
    { id: 'blackboard', title: '經典綠黑板', bg: '#172e25', subtitle: '墨綠粉筆課堂風格' },
    { id: 'dark', title: '深炭黑畫布', bg: '#121316', subtitle: '現代暗色高對比' },
    { id: 'whiteboard', title: '純淨白板', bg: '#f8fafc', subtitle: '簡報與腦力激盪' },
    { id: 'slate', title: '石板灰風格', bg: '#1e2430', subtitle: '工程幾何製圖' },
  ];

  return (
    <div className="heiban-home w-full h-full flex flex-col overflow-y-auto font-sans select-none scrollbar-thin">
      {/* Top Header */}
      <header className="heiban-home-header sticky top-0 z-30 backdrop-blur-xl border-b px-6 py-3.5 flex items-center justify-between gap-4">
        {/* Brand */}
        <div className="flex items-center gap-3">
          <img src="/wordmark.png" alt="黑板：手寫筆記 Logo" width={112} height={60} className="w-28 h-15 rounded-xl bg-[#fafaf2] p-1.5 object-contain shrink-0" />
          <div>
            <h1 className="font-semibold text-lg tracking-tight leading-none flex items-center gap-2">
              HeiBan 黑板 <span className="text-xs font-medium">工作區</span>
            </h1>
            <p className="text-[11px] mt-1">向量白板工作空間</p>
          </div>
        </div>

        {/* Center Search Bar */}
        <div className="heiban-home-search flex-1 max-w-md hidden sm:flex items-center gap-2 px-3.5 py-2 rounded-xl border text-xs transition-colors">
          <Search className="w-4 h-4 text-neutral-400 shrink-0" />
          <input
            type="text"
            placeholder="搜尋我的黑板作品..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-transparent placeholder-neutral-500 outline-none"
          />
        </div>

        {/* Right Settings Button & User Profile */}
        <div className="flex items-center gap-2">
          {/* Settings Button (首頁設定按鈕) */}
          <button
            onClick={() => setShowSettingsModal(true)}
            className="heiban-home-utility flex items-center gap-1.5 px-3 py-2 rounded-xl border transition-colors text-xs font-medium"
            title="開啟系統偏好設定、Google帳號管理與意見回覆"
          >
            <Settings className="w-4 h-4" />
            <span className="hidden sm:inline">設定</span>
          </button>

          {/* User Profile Dropdown */}
          <div className="relative">
            {user ? (
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setShowProfileMenu(!showProfileMenu)}
                  className="flex items-center gap-2 px-2.5 py-1 rounded-2xl hover:bg-neutral-800 border border-neutral-700/60 transition-all text-xs"
                >
                  <img
                    src={user.photoURL || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&fit=crop&q=80'}
                    alt={user.displayName || '使用者'}
                    className="w-7 h-7 rounded-full object-cover border border-emerald-500/40"
                  />
                  <span className="font-medium text-neutral-200 hidden md:inline truncate max-w-[120px]">
                    {user.displayName || 'Google 使用者'}
                  </span>
                  <ChevronDown className="w-3.5 h-3.5 text-neutral-400" />
                </button>

                {showProfileMenu && (
                  <div className="absolute right-0 top-12 w-64 bg-neutral-900/95 backdrop-blur-2xl border border-neutral-700/80 rounded-2xl p-2 shadow-2xl z-50 text-xs space-y-1 animate-in fade-in zoom-in-95 duration-150">
                    <div className="px-3 py-2 border-b border-neutral-800">
                      <div className="font-semibold text-white truncate">{user.displayName}</div>
                      <div className="text-[11px] text-neutral-400 truncate">{user.email}</div>
                    </div>

                    <button
                      onClick={() => {
                        setShowSettingsModal(true);
                        setShowProfileMenu(false);
                      }}
                      className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-neutral-300 hover:text-white hover:bg-neutral-800 text-left transition-colors"
                    >
                      <Settings className="w-4 h-4 text-cyan-400" />
                      <span>偏好與帳號設定</span>
                    </button>

                    <div className="border-t border-neutral-800 my-1" />

                    <button
                      onClick={() => {
                        onSignOut();
                        setShowProfileMenu(false);
                      }}
                      className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-red-400 hover:bg-red-500/20 text-left transition-colors"
                    >
                      <LogOut className="w-4 h-4" />
                      <span>登出 Google 帳號</span>
                    </button>
                  </div>
                )}
              </div>
            ) : (
                <button
                  onClick={onSignIn}
                className="heiban-home-signin flex items-center gap-2 px-4 py-2 rounded-xl text-white font-medium text-xs transition-colors"
              >
                <LogIn className="w-4 h-4" />
                <span>Google 登入</span>
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="heiban-home-main max-w-6xl w-full mx-auto px-6 py-10 space-y-10">
        {/* Compact Quick Creation Bar (簡潔緊湊型建立畫布區，不再佔用巨大篇幅) */}
        <div className="heiban-home-create border rounded-2xl p-4 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <button
              onClick={() => {
                setNewBoardTitle('');
                setShowCreateModal(true);
              }}
              className="heiban-home-create-button flex items-center gap-2 px-4 py-2.5 rounded-xl text-white font-medium text-sm transition-colors shrink-0"
            >
              <Plus className="w-4 h-4" />
              <span>建立全新黑板畫布</span>
            </button>
            <span className="text-xs text-neutral-500 hidden lg:inline">
              從空白畫布開始，之後可調整尺寸與底色
            </span>
          </div>

          {/* Quick theme choices and optional help */}
          <div className="flex items-center gap-1.5 overflow-x-auto">
            <span className="text-[11px] text-neutral-500 mr-1 hidden sm:inline">快速建立</span>
            {templateThemes.map((tpl) => (
              <button
                key={tpl.id}
                onClick={() => onCreateBoard(`未命名黑板 - ${tpl.title}`, tpl.id, 'infinite')}
                className="heiban-home-theme-button flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border transition-colors text-xs shrink-0"
                title={`快速以 ${tpl.title} 建立無限無邊界畫布`}
              >
                <div
                  className="w-3.5 h-3.5 rounded-full border border-white/20 shrink-0"
                  style={{ backgroundColor: tpl.bg }}
                />
                <span>{tpl.title}</span>
              </button>
            ))}
            {onLoadShowcaseBoard && (
              <button
                onClick={onLoadShowcaseBoard}
                className="p-1.5 rounded-lg text-neutral-500 hover:text-neutral-200 transition-colors shrink-0"
                title="開啟功能導覽" aria-label="開啟功能導覽"
              >
                <CircleHelp size={16} />
              </button>
            )}
          </div>
        </div>

        {/* Recent Boards Section (Word / Figma style) */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-xl font-semibold tracking-tight">最近使用</h2>
              <p className="text-sm text-neutral-500 mt-1">選取一面黑板，繼續你的工作。</p>
            </div>
            <span className="heiban-home-count text-xs px-2.5 py-1 rounded-full">
              共 {filteredBoards.length} 個作品
            </span>
          </div>

          {filteredBoards.length === 0 ? (
            <div className="py-16 text-center border-2 border-dashed border-neutral-800 rounded-3xl bg-neutral-900/30 space-y-4">
              <FolderPlus className="w-10 h-10 text-neutral-600 mx-auto" />
              <div>
                <p className="text-sm text-neutral-300 font-medium">尚無黑板作品</p>
                <p className="text-xs text-neutral-500 mt-0.5">選擇有邊界畫布、無邊界畫布或筆記本，開始第一份作品。</p>
              </div>
              <div className="flex items-center justify-center gap-3 pt-1">
                <button
                  onClick={() => setShowCreateModal(true)}
                  className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-medium shadow-md transition-colors"
                >
                  ＋ 建立新黑板
                </button>
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
              {filteredBoards.map((b) => (
                <div
                  key={b.id}
                  onClick={() => onOpenBoard(b.id)}
                  className="heiban-home-board group relative rounded-2xl border overflow-hidden cursor-pointer transition-all hover:-translate-y-0.5 flex flex-col"
                >
                  {/* Visual Board Canvas Preview (畫面截圖/縮圖) */}
                  <div
                    className="heiban-home-board-preview relative w-full h-44 overflow-hidden border-b flex items-center justify-center"
                    style={{ backgroundColor: b.backgroundColor || '#172e25' }}
                  >
                    {b.thumbnail ? (
                      <img
                        src={b.thumbnail}
                        alt={b.title}
                        className="w-full h-full object-cover pointer-events-none group-hover:scale-105 transition-transform duration-300"
                      />
                    ) : (
                      <>
                        {/* Subtle grid pattern simulation */}
                        <div className="absolute inset-0 opacity-20 bg-[radial-gradient(#fff_1px,transparent_1px)] [background-size:16px_16px]" />

                        {/* Visual Blackboard Art Stamp Preview */}
                        <div className="text-center p-4 z-10 pointer-events-none">
                          <div className="text-2xl font-semibold tracking-tight text-white/40">
                            {b.title || '未命名黑板'}
                          </div>
                        </div>
                      </>
                    )}

                    {/* Hover Action Overlay */}
                    <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 backdrop-blur-[2px] transition-opacity flex items-center justify-center gap-3">
                      <span className="heiban-home-open-board px-4 py-2 rounded-lg text-white text-sm font-medium transition-transform scale-95 group-hover:scale-100">
                        開啟黑板
                      </span>
                    </div>
                  </div>

                  {/* Card Details Footer */}
                  <div className="heiban-home-board-footer p-4 flex items-center justify-between">
                    <div className="min-w-0 pr-2">
                      <div className="font-semibold text-sm truncate group-hover:text-emerald-700 transition-colors">
                        {b.title || '未命名黑板'}
                      </div>
                      <div className="flex items-center gap-2 text-[11px] text-neutral-400 mt-1">
                        <span className="flex items-center gap-1">
                          <Calendar className="w-3 h-3" />
                          {new Date(b.updatedAt || b.createdAt).toLocaleDateString()}
                        </span>
                        <span>•</span>
                        <span>{b.ownerName || '匿名'}</span>
                      </div>
                    </div>

                    {/* Quick Card Action Buttons */}
                    <div className="flex items-center gap-1 shrink-0">
                      <button
                        onClick={(e) => handleShareBoard(b, e)}
                        className={`p-2 rounded-xl text-xs transition-colors ${
                          copiedId === b.id
                            ? 'bg-emerald-600/30 text-emerald-300'
                            : 'text-neutral-400 hover:text-white hover:bg-neutral-800'
                        }`}
                        title="複製協作分享連結"
                      >
                        {copiedId === b.id ? <Check className="w-4 h-4" /> : <Share2 className="w-4 h-4" />}
                      </button>

                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          if (confirm(`確定要刪除「${b.title}」嗎？`)) {
                            onDeleteBoard(b.id);
                          }
                        }}
                        className="p-2 rounded-xl text-neutral-400 hover:text-red-400 hover:bg-red-500/20 transition-colors"
                        title="刪除黑板"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Feedback Modal (意見回報) */}
      {showFeedbackModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-in fade-in duration-150">
          <div className="w-full max-w-md bg-neutral-900 border border-neutral-700/80 rounded-3xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-neutral-800">
              <div className="flex items-center gap-2">
                <MessageSquare className="w-4 h-4 text-emerald-400" />
                <h3 className="font-bold text-sm text-white">意見回報與功能建議</h3>
              </div>
              <button
                onClick={() => setShowFeedbackModal(false)}
                className="p-1 text-neutral-400 hover:text-white rounded-lg hover:bg-neutral-800"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {feedbackSuccess ? (
              <div className="py-6 text-center text-emerald-400 font-medium text-xs flex flex-col items-center gap-2">
                <Check className="w-8 h-8 rounded-full bg-emerald-500/20 p-1.5" />
                <span>感謝您的寶貴反饋！我們將持續優化黑板功能。</span>
              </div>
            ) : (
              <form onSubmit={handleSendFeedback} className="space-y-3">
                <textarea
                  rows={4}
                  placeholder="請在此輸入您在繪圖、協作或工具使用上的任何建議與反饋..."
                  value={feedbackText}
                  onChange={(e) => setFeedbackText(e.target.value)}
                  className="w-full p-3 rounded-2xl bg-neutral-800 border border-neutral-700 text-xs text-white placeholder-neutral-500 outline-none focus:border-emerald-500"
                  autoFocus
                />
                <div className="flex justify-end gap-2">
                  <button
                    type="button"
                    onClick={() => setShowFeedbackModal(false)}
                    className="px-3 py-1.5 rounded-xl bg-neutral-800 text-xs text-neutral-400 hover:text-white"
                  >
                    取消
                  </button>
                  <button
                    type="submit"
                    disabled={!feedbackText.trim()}
                    className="px-4 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-xs text-white font-medium shadow-md"
                  >
                    送出建議
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* Create New Board Custom Modal (自訂尺寸與無限畫布) */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-in fade-in duration-150">
          <div className="w-full max-w-lg bg-neutral-900 border border-neutral-700/80 rounded-3xl p-6 shadow-2xl space-y-5 text-neutral-200">
            <div className="flex items-center justify-between pb-3 border-b border-neutral-800">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-xl bg-emerald-600/20 text-emerald-400 flex items-center justify-center border border-emerald-500/30">
                  <Plus className="w-4 h-4" />
                </div>
                <div>
                  <h3 className="font-bold text-sm text-white">建立全新黑板畫布</h3>
                  <p className="text-[11px] text-neutral-400">自訂畫布名稱、底色風格與畫布邊界模式</p>
                </div>
              </div>
              <button
                onClick={() => setShowCreateModal(false)}
                className="p-1.5 text-neutral-400 hover:text-white rounded-xl hover:bg-neutral-800 transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Board Title */}
            <div>
              <label className="text-xs text-neutral-400 font-medium block mb-1">黑板名稱：</label>
              <input
                type="text"
                autoFocus
                placeholder="例如：物理力學推導、數學幾何證明、產品架構圖..."
                value={newBoardTitle}
                onChange={(e) => setNewBoardTitle(e.target.value)}
                className="w-full px-3.5 py-2 rounded-xl bg-neutral-800 border border-neutral-700 text-xs text-white placeholder-neutral-500 outline-none focus:border-emerald-500"
              />
            </div>

            {/* Canvas Mode Selection: Infinite vs Fixed */}
            <div>
              <label className="text-xs text-neutral-400 font-medium block mb-1.5">
                畫布邊界模式 (從一開始自由決定)：
              </label>
              <div className="grid grid-cols-3 gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setNewCanvasMode('infinite');
                    setNewCanvasPreset('infinite');
                  }}
                  className={`p-3 rounded-2xl border text-left transition-all ${
                    newCanvasMode === 'infinite'
                      ? 'border-emerald-500 bg-emerald-500/10 text-white shadow-md ring-1 ring-emerald-500'
                      : 'border-neutral-800 bg-neutral-800/40 text-neutral-400 hover:text-white hover:bg-neutral-800'
                  }`}
                >
                  <div className="flex items-center gap-1.5 font-bold text-xs text-emerald-400 mb-1">
                    <Maximize2 className="w-3.5 h-3.5" />
                    <span>♾️ 無限畫布</span>
                  </div>
                  <div className="text-[10px] text-neutral-400 leading-relaxed">
                    推薦！無限展開自由塗鴉、推導與筆記。
                  </div>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setNewCanvasMode('fixed');
                    if (newCanvasPreset === 'infinite' || newCanvasPreset === 'notebook') setNewCanvasPreset('16_9');
                  }}
                  className={`p-3 rounded-2xl border text-left transition-all ${
                    newCanvasMode === 'fixed'
                      ? 'border-cyan-500 bg-cyan-500/10 text-white shadow-md ring-1 ring-cyan-500'
                      : 'border-neutral-800 bg-neutral-800/40 text-neutral-400 hover:text-white hover:bg-neutral-800'
                  }`}
                >
                  <div className="flex items-center gap-1.5 font-bold text-xs text-cyan-400 mb-1">
                    <FileText className="w-3.5 h-3.5" />
                    <span>📄 固定單頁規格</span>
                  </div>
                  <div className="text-[10px] text-neutral-400 leading-relaxed">
                    提供 16:9、4:3、1:1、9:16、A4 紙張規格。
                  </div>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setNewCanvasMode('notebook');
                    setNewCanvasPreset('a4_portrait');
                  }}
                  className={`p-3 rounded-2xl border text-left transition-all ${
                    newCanvasMode === 'notebook'
                      ? 'border-purple-500 bg-purple-500/10 text-white shadow-md ring-1 ring-purple-500'
                      : 'border-neutral-800 bg-neutral-800/40 text-neutral-400 hover:text-white hover:bg-neutral-800'
                  }`}
                >
                  <div className="flex items-center gap-1.5 font-bold text-xs text-purple-400 mb-1">
                    <BookOpen className="w-3.5 h-3.5" />
                    <span>📓 多頁筆記本</span>
                  </div>
                  <div className="text-[10px] text-neutral-400 leading-relaxed">
                    支援多頁增刪、封面風格、方向與五線譜/格子內頁。
                  </div>
                </button>
              </div>

              {/* Bounded Notebook / Fixed Canvas Customization Options */}
              {(newCanvasMode === 'notebook' || newCanvasMode === 'fixed') && (
                <div className="mt-3 p-3.5 rounded-2xl bg-neutral-800/60 border border-neutral-700/60 space-y-3">
                  {/* Paper Size */}
                  <div>
                    <div className="text-[11px] text-neutral-300 font-medium mb-1.5">1. 頁面尺寸規格：</div>
                    <div className="grid grid-cols-4 gap-1.5 text-xs">
                      {[
                        { key: 'a4_portrait', label: 'A4 紙張', size: '595 × 842' },
                        { key: 'a3_landscape', label: 'A3 紙張', size: '1191 × 842' },
                        { key: 'b5', label: 'B5 筆記', size: '499 × 709' },
                        { key: '16_9', label: '16:9 簡報', size: '1920 × 1080' },
                        { key: '4_3', label: '4:3 課堂', size: '1440 × 1080' },
                        { key: '1_1', label: '1:1 正方形', size: '1080 × 1080' },
                        { key: '9_16', label: '9:16 手機直式', size: '1080 × 1920' },
                        { key: 'custom', label: '2K 寬螢幕', size: '2560 × 1440' },
                      ].map((p) => (
                        <button
                          key={p.key}
                          type="button"
                          onClick={() => setNewCanvasPreset(p.key as any)}
                          className={`p-2 rounded-xl text-left border transition-all ${
                            newCanvasPreset === p.key
                              ? 'border-purple-400 bg-purple-500/20 text-white font-bold'
                              : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:text-white'
                          }`}
                        >
                          <div className="font-semibold text-[11px]">{p.label}</div>
                          <div className="text-[9px] text-neutral-400 font-mono">{p.size}</div>
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Orientation: Portrait vs Landscape */}
                  <div>
                    <div className="text-[11px] text-neutral-300 font-medium mb-1.5">2. 頁面方向：</div>
                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <button
                        type="button"
                        onClick={() => setNewOrientation('portrait')}
                        className={`p-2 rounded-xl border text-center transition-all ${
                          newOrientation === 'portrait'
                            ? 'border-purple-400 bg-purple-500/20 text-white font-bold'
                            : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:text-white'
                        }`}
                      >
                        📱 直向 (Portrait)
                      </button>
                      <button
                        type="button"
                        onClick={() => setNewOrientation('landscape')}
                        className={`p-2 rounded-xl border text-center transition-all ${
                          newOrientation === 'landscape'
                            ? 'border-purple-400 bg-purple-500/20 text-white font-bold'
                            : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:text-white'
                        }`}
                      >
                        💻 橫向 (Landscape)
                      </button>
                    </div>
                  </div>

                  {/* Notebook Cover Style */}
                  {newCanvasMode === 'notebook' && (
                    <div>
                      <div className="text-[11px] text-neutral-300 font-medium mb-1.5">3. 筆記本封面風格：</div>
                      <div className="grid grid-cols-3 gap-1.5 text-xs">
                        {[
                          { id: 'classic_blackboard', name: '經典黑板', bg: '#172e25' },
                          { id: 'vintage_leather', name: '復古皮革', bg: '#4a2c11' },
                          { id: 'obsidian_black', name: '曜石黑', bg: '#18181b' },
                          { id: 'warm_kraft', name: '溫暖牛皮', bg: '#c49a6c' },
                          { id: 'morning_pastel', name: '晨曦粉彩', bg: '#fbcfe8' },
                          { id: 'modern_white', name: '現代純白', bg: '#ffffff' },
                        ].map((cv) => (
                          <button
                            key={cv.id}
                            type="button"
                            onClick={() => setNewCoverStyle(cv.id)}
                            className={`p-2 rounded-xl border flex items-center gap-2 transition-all ${
                              newCoverStyle === cv.id
                                ? 'border-purple-400 bg-purple-500/20 text-white font-bold'
                                : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:text-white'
                            }`}
                          >
                            <span
                              className="w-3.5 h-3.5 rounded-full border border-neutral-600 shrink-0"
                              style={{ backgroundColor: cv.bg }}
                            />
                            <span className="truncate text-[11px]">{cv.name}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Inner Page Default Style (格子 / 橫線 / 五線譜 / 全白 / 點點) */}
                  <div>
                    <div className="text-[11px] text-neutral-300 font-medium mb-1.5">4. 內頁風格：</div>
                    <div className="grid grid-cols-5 gap-1 text-xs">
                      {[
                        { id: 'grid', name: '格子' },
                        { id: 'lines', name: '橫線' },
                        { id: 'staff', name: '五線譜' },
                        { id: 'blank', name: '全白' },
                        { id: 'dots', name: '點點' },
                      ].map((st) => (
                        <button
                          key={st.id}
                          type="button"
                          onClick={() => setNewGridStyle(st.id as GridStyle)}
                          className={`py-1.5 px-1 rounded-xl border text-center transition-all ${
                            newGridStyle === st.id
                              ? 'border-purple-400 bg-purple-500/20 text-white font-bold'
                              : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:text-white'
                          }`}
                        >
                          <span className="text-[11px]">{st.name}</span>
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Grid Color */}
                  <div>
                    <div className="text-[11px] text-neutral-300 font-medium mb-1.5">5. 格線顏色：</div>
                    <div className="grid grid-cols-5 gap-1 text-xs">
                      {[
                        { id: undefined, name: '自適應' },
                        { id: '#94a3b8', name: '淺灰' },
                        { id: '#475569', name: '深灰' },
                        { id: '#ffffff', name: '白色' },
                        { id: '#18181b', name: '柔黑' },
                      ].map((gc) => (
                        <button
                          key={gc.name}
                          type="button"
                          onClick={() => setNewGridColor(gc.id)}
                          className={`py-1 px-1 rounded-xl border text-center transition-all ${
                            newGridColor === gc.id
                              ? 'border-purple-400 bg-purple-500/20 text-white font-bold'
                              : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:text-white'
                          }`}
                        >
                          <span className="text-[10px]">{gc.name}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Theme & Background Picker */}
            <div>
              <label className="text-xs text-neutral-400 font-medium block mb-1">黑板底色風格：</label>
              <div className="grid grid-cols-4 gap-2">
                {[
                  { id: 'blackboard', title: '經典綠', bg: '#172e25' },
                  { id: 'dark', title: '曜石黑', bg: '#121316' },
                  { id: 'whiteboard', title: '象牙暖白', bg: '#FAF8F5' },
                  { id: 'slate', title: '石板灰', bg: '#1e2430' },
                ].map((tpl) => (
                  <button
                    key={tpl.id}
                    type="button"
                    onClick={() => {
                      setNewBoardTheme(tpl.id as BoardTheme);
                      setNewBgColor(tpl.bg);
                    }}
                    className={`p-2 rounded-xl border flex flex-col items-center gap-1.5 transition-all ${
                      newBoardTheme === tpl.id
                        ? 'border-emerald-500 bg-emerald-500/10 text-white ring-1 ring-emerald-500'
                        : 'border-neutral-800 bg-neutral-800/40 text-neutral-400 hover:text-white'
                    }`}
                  >
                    <div
                      className="w-5 h-5 rounded-full border border-white/20 shadow-inner"
                      style={{ backgroundColor: tpl.bg }}
                    />
                    <span className="text-[11px] font-medium truncate">{tpl.title}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Actions */}
            <div className="flex items-center justify-end gap-2 pt-2 border-t border-neutral-800">
              <button
                type="button"
                onClick={() => setShowCreateModal(false)}
                className="px-4 py-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-neutral-300 text-xs font-medium"
              >
                取消
              </button>
              <button
                type="button"
                onClick={() => {
                  const title = newBoardTitle.trim() || (newCanvasMode === 'notebook' ? '未命名多頁筆記本' : '未命名全新黑板');
                  let w = 1920, h = 1080;
                  if (newCanvasPreset === 'b5') {
                    w = 499;
                    h = 709;
                  } else if (newCanvasPreset === '1_1') {
                    w = 1080;
                    h = 1080;
                  } else if (newCanvasPreset === '9_16') {
                    w = 1080;
                    h = 1920;
                  } else if (newCanvasPreset === 'a4_portrait' || newCanvasMode === 'notebook') {
                    w = 595;
                    h = 842;
                  } else if (newCanvasPreset === 'a4_landscape') {
                    w = 842;
                    h = 595;
                  } else if (newCanvasPreset === 'a3_landscape') {
                    w = 1191;
                    h = 842;
                  } else if (newCanvasPreset === '4_3') {
                    w = 1440;
                    h = 1080;
                  } else if (newCanvasPreset === '16_9') {
                    w = 1920;
                    h = 1080;
                  } else if (newCanvasPreset === 'custom') {
                    w = 2560;
                    h = 1440;
                  }

                  // Handle orientation flipping
                  if (newOrientation === 'landscape' && w < h) {
                    const temp = w;
                    w = h;
                    h = temp;
                  } else if (newOrientation === 'portrait' && w > h) {
                    const temp = w;
                    w = h;
                    h = temp;
                  }

                  onCreateBoard(title, newBoardTheme, newCanvasMode, newCanvasPreset, w, h, {
                    orientation: newOrientation,
                    coverStyle: newCoverStyle,
                    gridStyle: newGridStyle,
                    backgroundColor: newBgColor,
                    gridColor: newGridColor,
                  });
                  setShowCreateModal(false);
                }}
                className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-md transition-all active:scale-95"
              >
                立即建立畫布
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Settings Modal (偏好設定、Google帳號管理、字體、主題、版本、開發者、意見回饋) */}
      <SettingsModal
        isOpen={showSettingsModal}
        onClose={() => setShowSettingsModal(false)}
        user={user}
        onSignIn={onSignIn}
        onSignOut={onSignOut}
        defaultTheme={defaultTheme}
        onChangeDefaultTheme={onChangeDefaultTheme}
        defaultFont={defaultFont}
        onChangeDefaultFont={onChangeDefaultFont}
      />
    </div>
  );
};
