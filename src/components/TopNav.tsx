import React, { useState } from 'react';
import { User } from 'firebase/auth';
import {
  BoardMetadata,
  BoardTheme,
  GridStyle,
  UserPresence,
  CanvasMode,
} from '../types';
import {
  Share2,
  Download,
  Layers,
  MousePointer,
  Grid,
  FileDown,
  Image,
  FolderOpen,
  Plus,
  LogIn,
  LogOut,
  Check,
  Palette,
  Users,
  Copy,
  Pin,
  Home,
  Maximize,
  Minimize,
  Cloud,
  Clock,
  Save,
  Crop,
  Settings,
  ChevronDown,
  FileText,
} from 'lucide-react';

interface TopNavProps {
  board: BoardMetadata;
  user: User | null;
  presences: UserPresence[];
  showCursors: boolean;
  isLayerOpen: boolean;
  isPinOpen: boolean;
  syncStatus: 'synced' | 'saving' | 'offline';
  autoSaveMinutes?: number;
  lastSavedTime?: string;
  isAutoSaving?: boolean;
  onChangeAutoSaveMinutes?: (minutes: number) => void;
  onTriggerAutoSave?: () => void;
  onGoHome?: () => void;
  onUpdateBoard: (partial: Partial<BoardMetadata>) => void;
  onToggleCursors: () => void;
  onToggleLayers: () => void;
  onTogglePins: () => void;
  onExportSvg: () => void;
  onExportPdf: () => void;
  onExportPng: () => void;
  onExportJson: () => void;
  onImportJson: (file: File) => void;
  onOpenBoardsModal: () => void;
  onSignIn: () => void;
  onSignOut: () => void;
  onStartRangeExport?: () => void;
  onOpenSettings?: () => void;
}

export const TopNav: React.FC<TopNavProps> = ({
  board,
  user,
  presences,
  showCursors,
  isLayerOpen,
  isPinOpen,
  syncStatus,
  autoSaveMinutes = 2,
  lastSavedTime,
  isAutoSaving = false,
  onChangeAutoSaveMinutes,
  onTriggerAutoSave,
  onGoHome,
  onUpdateBoard,
  onToggleCursors,
  onToggleLayers,
  onTogglePins,
  onExportSvg,
  onExportPdf,
  onExportPng,
  onExportJson,
  onImportJson,
  onOpenBoardsModal,
  onSignIn,
  onSignOut,
  onStartRangeExport,
  onOpenSettings,
}) => {
  const [isEditingTitle, setIsEditingTitle] = useState(false);
  const [titleInput, setTitleInput] = useState(board.title);
  const [showExportMenu, setShowExportMenu] = useState(false);
  const [showCanvasSizeMenu, setShowCanvasSizeMenu] = useState(false);
  const [showThemeMenu, setShowThemeMenu] = useState(false);
  const [showAutoSaveMenu, setShowAutoSaveMenu] = useState(false);
  const [copiedShare, setCopiedShare] = useState(false);

  const handleTitleSubmit = () => {
    setIsEditingTitle(false);
    if (titleInput.trim() && titleInput !== board.title) {
      onUpdateBoard({ title: titleInput.trim() });
    }
  };

  const handleCopyShareLink = () => {
    navigator.clipboard.writeText(window.location.href);
    setCopiedShare(true);
    setTimeout(() => setCopiedShare(false), 2000);
  };

  const themes: { id: BoardTheme; name: string; bg: string }[] = [
    { id: 'blackboard', name: '經典綠黑板', bg: '#172e25' },
    { id: 'dark', name: '深炭黑黑板', bg: '#121316' },
    { id: 'whiteboard', name: '純淨白板', bg: '#f8fafc' },
    { id: 'slate', name: '石板灰', bg: '#1e2430' },
  ];

  const gridStyles: { id: GridStyle; name: string }[] = [
    { id: 'grid', name: '方格網格' },
    { id: 'dots', name: '點陣 (FigJam)' },
    { id: 'lines', name: '筆記橫線' },
    { id: 'blank', name: '純淨無格' },
  ];

  return (
    <header className="heiban-topnav absolute top-3 left-3 right-3 z-30 pointer-events-none flex flex-nowrap items-center justify-between gap-2">
      {/* Left: App Logo, Board Title & Switcher */}
      <div className="heiban-topnav-left pointer-events-auto flex shrink-0 items-center gap-1.5 bg-neutral-900/90 backdrop-blur-xl border border-neutral-700/80 px-2.5 py-1.5 rounded-2xl shadow-xl">
        {/* Brand Logo & Return to Home Dashboard */}
        <div
          onClick={onGoHome || onOpenBoardsModal}
          className="flex items-center gap-2 cursor-pointer group px-1 py-0.5 rounded-xl hover:bg-neutral-800/80 transition-colors shrink-0"
          title="回首頁 (主畫面 / 所有存檔畫布)"
        >
          <img src="/logo.png" alt="" className="w-8 h-8 rounded-lg object-cover shrink-0" />
          <div className="flex flex-col">
            <span className="font-bold text-xs tracking-tight text-white flex items-center gap-1">
              HeiBan 黑板 <span className="text-[10px] text-emerald-400 group-hover:underline">首頁</span>
            </span>
            <span className="hidden lg:flex text-[9px] text-neutral-400 leading-none items-center gap-0.5">
              <Home className="w-2.5 h-2.5" /> 所有作品
            </span>
          </div>
        </div>

        <div className="h-4 w-[1px] bg-neutral-700 mx-1" />

        {/* Board Title Edit */}
        {isEditingTitle ? (
          <input
            type="text"
            value={titleInput}
            onChange={(e) => setTitleInput(e.target.value)}
            onBlur={handleTitleSubmit}
            onKeyDown={(e) => e.key === 'Enter' && handleTitleSubmit()}
            autoFocus
            className="bg-neutral-800 text-white text-xs font-medium px-2 py-1 rounded border border-blue-500 outline-none w-36 sm:w-48"
          />
        ) : (
          <div
            onClick={() => {
              setTitleInput(board.title);
              setIsEditingTitle(true);
            }}
            className="flex items-center gap-1 text-xs text-neutral-200 hover:text-white cursor-pointer px-1.5 py-1 rounded-lg hover:bg-neutral-800 transition-colors max-w-[92px] sm:max-w-[124px] lg:max-w-[170px] shrink-0 whitespace-nowrap"
            title="點擊修改黑板標題"
          >
            <span className="truncate font-medium">{board.title || '無標題黑板'}</span>
            <span className="text-[10px] text-neutral-500">✎</span>
          </div>
        )}

        {/* Auto-Save & Cloud Sync Badge with Interactive Dropdown (每幾分鐘自動存儲) */}
        <div className="relative">
          <button
            onClick={() => setShowAutoSaveMenu(!showAutoSaveMenu)}
            className="flex shrink-0 items-center gap-1.5 text-[11px] px-2 py-1.5 rounded-xl bg-neutral-800/80 hover:bg-neutral-800 text-neutral-300 hover:text-white border border-neutral-700/60 transition-colors"
            title="自動儲存設定 (可自訂每幾分鐘自動存檔)"
          >
            <Cloud
              className={`w-3.5 h-3.5 ${
                isAutoSaving || syncStatus === 'saving'
                  ? 'text-amber-400 animate-pulse'
                  : 'text-emerald-400'
              }`}
            />
            <span className="hidden xl:inline font-mono whitespace-nowrap">
              {isAutoSaving || syncStatus === 'saving'
                ? '儲存中...'
                : autoSaveMinutes > 0
                ? `每${autoSaveMinutes}分自動儲存`
                : '自動存儲已關閉'}
            </span>
            <div
              className={`w-1.5 h-1.5 rounded-full ${
                syncStatus === 'synced'
                  ? 'bg-emerald-400'
                  : syncStatus === 'saving' || isAutoSaving
                  ? 'bg-amber-400 animate-ping'
                  : 'bg-neutral-500'
              }`}
            />
          </button>

          {showAutoSaveMenu && (
            <div className="absolute left-0 mt-2 w-60 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-3 shadow-2xl text-xs space-y-2.5 z-50 animate-in fade-in zoom-in-95 duration-100">
              <div className="flex items-center justify-between border-b border-neutral-800 pb-2">
                <div className="flex items-center gap-1.5 font-bold text-white">
                  <Clock className="w-3.5 h-3.5 text-cyan-400" />
                  <span>自動儲存設定</span>
                </div>
                {lastSavedTime && (
                  <span className="text-[10px] text-neutral-400 font-mono">
                    上次: {lastSavedTime}
                  </span>
                )}
              </div>

              <div>
                <span className="text-[10px] text-neutral-400 font-medium block mb-1">
                  自動儲存頻率 (定時存儲黑板及縮圖):
                </span>
                <div className="grid grid-cols-3 gap-1">
                  {[
                    { label: '1 分鐘', val: 1 },
                    { label: '2 分鐘', val: 2 },
                    { label: '3 分鐘', val: 3 },
                    { label: '5 分鐘', val: 5 },
                    { label: '10 分鐘', val: 10 },
                    { label: '關閉', val: 0 },
                  ].map((opt) => (
                    <button
                      key={opt.val}
                      onClick={() => {
                        onChangeAutoSaveMinutes?.(opt.val);
                      }}
                      className={`px-2 py-1 rounded-lg text-center text-xs transition-colors ${
                        autoSaveMinutes === opt.val
                          ? 'bg-emerald-600 text-white font-bold'
                          : 'bg-neutral-800 hover:bg-neutral-700 text-neutral-300'
                      }`}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="border-t border-neutral-800 pt-2">
                <button
                  onClick={() => {
                    onTriggerAutoSave?.();
                    setShowAutoSaveMenu(false);
                  }}
                  className="w-full flex items-center justify-center gap-1.5 py-1.5 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold text-xs shadow-md transition-all active:scale-95"
                >
                  <Save className="w-3.5 h-3.5" />
                  <span>立即手動存儲黑板 (Ctrl+S)</span>
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Boards List Button */}
        <button
          onClick={onOpenBoardsModal}
          className="hidden lg:block shrink-0 p-1.5 rounded-lg text-neutral-400 hover:text-white hover:bg-neutral-800 transition-colors"
          title="管理黑板"
        >
          <FolderOpen className="w-4 h-4" />
        </button>

        {/* Pin (圖釘) Viewport Navigation Button - 位於左上方 */}
        <button
          onClick={onTogglePins}
          className={`flex shrink-0 items-center gap-1 px-2 py-1.5 rounded-xl text-xs transition-colors ${
            isPinOpen
              ? 'bg-rose-600/30 text-rose-300 border border-rose-500/40'
              : 'text-neutral-300 hover:text-white hover:bg-neutral-800 border border-neutral-700/60'
          }`}
          title="視野圖釘 (左上方) - 點擊快速平滑移動至指定位置，可自訂名稱"
        >
          <Pin className="w-3.5 h-3.5 text-rose-400 rotate-45" />
          <span className="hidden xl:inline font-medium">圖釘</span>
          {board.pins && board.pins.length > 0 && (
            <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-rose-500/40 text-rose-200 font-mono">
              {board.pins.length}
            </span>
          )}
        </button>
      </div>

      {/* Right: Actions, Collaborators, Presence, Export, Login */}
      <div className="heiban-topnav-right pointer-events-auto flex min-w-0 shrink-0 items-center gap-1 bg-neutral-900/90 backdrop-blur-xl border border-neutral-700/80 px-2 py-1.5 rounded-2xl shadow-xl">
        {/* Background / Theme picker */}
        <div className="relative">
          <button
            onClick={() => {
              setShowThemeMenu(!showThemeMenu);
              setShowExportMenu(false);
            }}
            className="flex shrink-0 items-center gap-1.5 px-2 py-1.5 rounded-xl text-xs text-neutral-300 hover:text-white hover:bg-neutral-800 transition-colors"
            title="調整底色與網格樣式"
          >
            <Palette className="w-4 h-4 text-emerald-400" />
            <span className="hidden xl:inline whitespace-nowrap">底色/網格</span>
          </button>

          {showThemeMenu && (
            <div className="absolute right-0 mt-2 w-64 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-3 shadow-2xl text-xs space-y-3 z-50">
              <div>
                <div className="text-[11px] font-medium text-neutral-400 mb-1.5">黑板底色風格</div>
                <div className="grid grid-cols-2 gap-1.5">
                  {themes.map((th) => (
                    <button
                      key={th.id}
                      onClick={() => {
                        onUpdateBoard({ boardTheme: th.id, backgroundColor: th.bg });
                        setShowThemeMenu(false);
                      }}
                      className={`flex items-center gap-2 p-1.5 rounded-xl border text-left transition-all ${
                        board.boardTheme === th.id
                          ? 'border-emerald-500 bg-emerald-500/10 text-white'
                          : 'border-neutral-800 hover:bg-neutral-800 text-neutral-300'
                      }`}
                    >
                      <div
                        className="w-4 h-4 rounded-full border border-neutral-600 shrink-0"
                        style={{ backgroundColor: th.bg }}
                      />
                      <span className="truncate">{th.name}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div className="border-t border-neutral-800 pt-2">
                <div className="text-[11px] font-medium text-neutral-400 mb-1.5">網格格線模式</div>
                <div className="grid grid-cols-2 gap-1.5">
                  {gridStyles.map((g) => (
                    <button
                      key={g.id}
                      onClick={() => {
                        onUpdateBoard({ gridStyle: g.id });
                        setShowThemeMenu(false);
                      }}
                      className={`px-2 py-1.5 rounded-xl border text-left transition-all ${
                        board.gridStyle === g.id
                          ? 'border-emerald-500 bg-emerald-500/10 text-white'
                          : 'border-neutral-800 hover:bg-neutral-800 text-neutral-300'
                      }`}
                    >
                      {g.name}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Collaborators Active Bubbles (up to 10 users) */}
        <div className="flex items-center -space-x-1.5 px-1">
          {presences.slice(0, 5).map((p, idx) => (
            <div
              key={p.userId || idx}
              className="relative w-6 h-6 rounded-full border-2 border-neutral-900 bg-neutral-800 flex items-center justify-center text-[10px] font-bold text-white shadow-sm overflow-hidden"
              title={`${p.displayName || '協作者'}`}
              style={{ backgroundColor: p.color || '#3b82f6' }}
            >
              {p.photoURL ? (
                <img src={p.photoURL} alt="" className="w-full h-full object-cover" />
              ) : (
                (p.displayName || 'U').charAt(0).toUpperCase()
              )}
            </div>
          ))}
          {presences.length > 5 && (
            <div className="w-6 h-6 rounded-full border-2 border-neutral-900 bg-neutral-700 flex items-center justify-center text-[10px] text-neutral-300 font-medium">
              +{presences.length - 5}
            </div>
          )}
          <span className="text-[10px] text-neutral-400 ml-2 hidden 2xl:inline font-mono whitespace-nowrap">
            {presences.length}/10 在線
          </span>
        </div>

        {/* Share Button */}
        <button
          onClick={handleCopyShareLink}
          className={`flex items-center gap-1 px-2.5 py-1.5 rounded-xl text-xs transition-colors ${
            copiedShare
              ? 'bg-emerald-600/30 text-emerald-300 border border-emerald-500/40'
              : 'text-neutral-300 hover:text-white hover:bg-neutral-800'
          }`}
          title="複製分享連結，邀請其他人一起線上即時繪圖"
        >
          {copiedShare ? <Check className="w-3.5 h-3.5" /> : <Share2 className="w-3.5 h-3.5" />}
          <span className="hidden xl:inline whitespace-nowrap">{copiedShare ? '已複製連結' : '分享'}</span>
        </button>

        {/* Collaborator Cursor Toggle (User Requirement: 可以開啟/關閉軌跡) */}
        <button
          onClick={onToggleCursors}
          className={`flex items-center gap-1 px-2 py-1.5 rounded-xl text-xs transition-colors ${
            showCursors
              ? 'bg-blue-600/25 text-blue-300 border border-blue-500/30'
              : 'text-neutral-500 hover:text-neutral-300 hover:bg-neutral-800'
          }`}
          title={showCursors ? '軌跡顯示中（點擊關閉他人滑鼠軌跡）' : '軌跡已隱藏（點擊開啟顯示他人滑鼠軌跡）'}
        >
          <MousePointer className="w-3.5 h-3.5" />
          <span className="hidden xl:inline">{showCursors ? '軌跡開啟' : '軌跡關閉'}</span>
        </button>

        {/* Canvas Bounds Mode & Paper Size Adjustment (遵循規則：有邊界可轉無邊界，無邊界不可轉有邊界) */}
        {board.canvasMode === 'infinite' ? (
          <div
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-xs bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 font-medium select-none"
            title="無限無邊界畫布：無拘無束自由塗鴉、推導與筆記（不可還原為固定尺寸邊界）"
          >
            <Maximize className="w-3.5 h-3.5 text-emerald-400" />
            <span className="hidden xl:inline">♾️ 無邊界畫布</span>
          </div>
        ) : (
          <div className="relative">
            <button
              onClick={() => setShowCanvasSizeMenu(!showCanvasSizeMenu)}
              className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-xs bg-neutral-800 text-cyan-300 border border-neutral-700 hover:border-cyan-500/60 transition-colors"
              title="固定規格紙張（點擊調整紙張尺寸，或升級轉換為無邊界畫布）"
            >
              <Minimize className="w-3.5 h-3.5 text-cyan-400" />
            <span className="hidden xl:inline whitespace-nowrap">
                {board.canvasPreset === 'a4_landscape'
                  ? 'A4 橫向'
                  : board.canvasPreset === 'a4_portrait'
                  ? 'A4 直向'
                  : board.canvasPreset === '16_9'
                  ? '16:9 簡報'
                  : board.canvasPreset === 'a3_landscape'
                  ? 'A3 橫向'
                  : board.canvasPreset === '4_3'
                  ? '4:3 課堂'
                  : '紙張規格'}{' '}
                ({board.canvasWidth || 1920}×{board.canvasHeight || 1080})
              </span>
              <ChevronDown className="w-3 h-3 text-neutral-400" />
            </button>

            {showCanvasSizeMenu && (
              <div className="absolute right-0 mt-2 w-64 bg-neutral-900/98 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-3 shadow-2xl text-xs space-y-2.5 z-50 animate-in fade-in duration-100">
                <div className="flex items-center justify-between text-neutral-300 font-semibold border-b border-neutral-800 pb-1.5">
                  <div className="flex items-center gap-1.5">
                    <FileText className="w-3.5 h-3.5 text-cyan-400" />
                    <span>調整畫布尺寸規格</span>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-1.5">
                  {[
                    { key: 'a4_landscape', label: 'A4 橫向', w: 1920, h: 1358 },
                    { key: 'a4_portrait', label: 'A4 直向', w: 1358, h: 1920 },
                    { key: '16_9', label: '16:9 簡報', w: 1920, h: 1080 },
                    { key: '4_3', label: '4:3 課堂', w: 1600, h: 1200 },
                    { key: 'a3_landscape', label: 'A3 橫向', w: 2715, h: 1920 },
                  ].map((p) => (
                    <button
                      key={p.key}
                      onClick={() => {
                        onUpdateBoard({
                          canvasPreset: p.key as any,
                          canvasWidth: p.w,
                          canvasHeight: p.h,
                        });
                        setShowCanvasSizeMenu(false);
                      }}
                      className={`px-2.5 py-1.5 rounded-xl border text-left transition-colors ${
                        board.canvasPreset === p.key
                          ? 'border-cyan-400 bg-cyan-500/20 text-white font-bold'
                          : 'border-neutral-800 hover:border-neutral-700 text-neutral-300 hover:text-white'
                      }`}
                    >
                      <div className="font-semibold text-xs">{p.label}</div>
                      <div className="text-[10px] text-neutral-400 font-mono">{p.w}×{p.h}</div>
                    </button>
                  ))}
                </div>

                {/* Convert to Infinite Option (單向升級轉換，有邊界可轉無邊界) */}
                <div className="border-t border-neutral-800 pt-2">
                  <button
                    onClick={() => {
                      if (
                        confirm(
                          '確認要將此黑板轉為「無限無邊界畫布」嗎？\n\n轉換後畫布將不再限制邊界，且依規則無法再還原為固定尺寸紙張。'
                        )
                      ) {
                        onUpdateBoard({ canvasMode: 'infinite', canvasPreset: 'infinite' });
                        setShowCanvasSizeMenu(false);
                      }
                    }}
                    className="w-full flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-xs font-bold transition-colors"
                  >
                    <Maximize className="w-3.5 h-3.5" />
                    <span>升級轉換為無邊界畫布 ♾️</span>
                  </button>
                  <p className="text-[9px] text-neutral-500 text-center mt-1">
                    無邊界畫布可享受無限自由延伸，但不可再縮回固定規格
                  </p>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Layer Panel Toggle */}
        <button
          onClick={onToggleLayers}
          className={`p-1.5 rounded-xl text-xs transition-colors ${
            isLayerOpen
              ? 'bg-cyan-600/30 text-cyan-300 border border-cyan-500/30'
              : 'text-neutral-300 hover:text-white hover:bg-neutral-800'
          }`}
          title="圖層管理"
        >
          <Layers className="w-4 h-4" />
        </button>

        {/* Export Menu Dropdown */}
        <div className="relative">
          <button
            onClick={() => {
              setShowExportMenu(!showExportMenu);
              setShowThemeMenu(false);
            }}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl text-xs bg-neutral-800 hover:bg-neutral-700 text-neutral-200 transition-colors"
            title="匯出黑板作品"
          >
            <Download className="w-3.5 h-3.5 text-cyan-400" />
            <span className="hidden sm:inline">匯出</span>
          </button>

          {showExportMenu && (
            <div className="absolute right-0 mt-2 w-52 bg-neutral-900/95 backdrop-blur-xl border border-neutral-700/80 rounded-2xl p-2 shadow-2xl text-xs space-y-1 z-50">
              {/* Custom Range Selection for Infinite Canvas (自訂框選輸出範圍) */}
              {onStartRangeExport && (
                <button
                  onClick={() => {
                    onStartRangeExport();
                    setShowExportMenu(false);
                  }}
                  className="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-cyan-300 hover:bg-cyan-500/20 text-left transition-colors border border-cyan-500/30 mb-1"
                >
                  <Crop className="w-4 h-4 text-cyan-400" />
                  <div>
                    <div className="font-bold">自訂框選輸出範圍</div>
                    <div className="text-[10px] text-cyan-400/80">滑鼠拖曳自訂要匯出的區域</div>
                  </div>
                </button>
              )}

              <button
                onClick={() => {
                  onExportSvg();
                  setShowExportMenu(false);
                }}
                className="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-neutral-200 hover:bg-neutral-800 hover:text-white text-left transition-colors"
              >
                <FileDown className="w-4 h-4 text-emerald-400" />
                <div>
                  <div className="font-medium">SVG 向量格式</div>
                  <div className="text-[10px] text-neutral-400">保留純向量，可二次編輯</div>
                </div>
              </button>

              <button
                onClick={() => {
                  onExportPdf();
                  setShowExportMenu(false);
                }}
                className="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-neutral-200 hover:bg-neutral-800 hover:text-white text-left transition-colors"
              >
                <FileDown className="w-4 h-4 text-red-400" />
                <div>
                  <div className="font-medium">PDF 文件格式</div>
                  <div className="text-[10px] text-neutral-400">適合列印與簡報分享</div>
                </div>
              </button>

              <button
                onClick={() => {
                  onExportPng();
                  setShowExportMenu(false);
                }}
                className="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-neutral-200 hover:bg-neutral-800 hover:text-white text-left transition-colors"
              >
                <Image className="w-4 h-4 text-blue-400" />
                <div>
                  <div className="font-medium">PNG 高清圖片</div>
                  <div className="text-[10px] text-neutral-400">2x 原畫質影像</div>
                </div>
              </button>

              <div className="border-t border-neutral-800 my-1" />

              <button
                onClick={() => {
                  onExportJson();
                  setShowExportMenu(false);
                }}
                className="w-full flex items-center gap-2 px-3 py-1.5 rounded-xl text-neutral-400 hover:bg-neutral-800 hover:text-neutral-200 text-left transition-colors"
              >
                <FolderOpen className="w-3.5 h-3.5" />
                <span>匯出 JSON 備份檔</span>
              </button>

              <label className="w-full flex items-center gap-2 px-3 py-1.5 rounded-xl text-neutral-400 hover:bg-neutral-800 hover:text-neutral-200 text-left transition-colors cursor-pointer">
                <FolderOpen className="w-3.5 h-3.5" />
                <span>匯入 JSON 專案檔</span>
                <input
                  type="file"
                  accept=".json"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) onImportJson(f);
                    setShowExportMenu(false);
                  }}
                />
              </label>
            </div>
          )}
        </div>

        {/* Global Settings Button in TopNav */}
        {onOpenSettings && (
          <button
            onClick={onOpenSettings}
            className="p-1.5 rounded-xl text-neutral-400 hover:text-white hover:bg-neutral-800 transition-colors"
            title="系統設定與帳號中心"
          >
            <Settings className="w-4 h-4 text-emerald-400" />
          </button>
        )}

        {/* Google User Profile & Login/Logout */}
        {user ? (
          <div className="flex items-center gap-1.5 pl-1">
            <img
              src={user.photoURL || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&fit=crop&q=80'}
              alt={user.displayName || '使用者'}
              className="w-7 h-7 rounded-full border border-neutral-600 object-cover shadow"
            />
            <button
              onClick={onSignOut}
              className="p-1 text-neutral-400 hover:text-red-400 hover:bg-neutral-800 rounded-lg transition-colors"
              title="登出 Google 帳號"
            >
              <LogOut className="w-3.5 h-3.5" />
            </button>
          </div>
        ) : (
          <button
            onClick={onSignIn}
            className="flex shrink-0 items-center gap-1 px-3 py-1.5 rounded-xl bg-emerald-700 hover:bg-emerald-600 text-white font-medium text-xs shadow-sm transition-colors ml-1"
            title="使用 Google 帳號登入以啟用多人即時協作與雲端儲存"
          >
            <LogIn className="w-3.5 h-3.5" />
            <span className="hidden xl:inline whitespace-nowrap">Google 登入協作</span>
          </button>
        )}
      </div>
    </header>
  );
};
