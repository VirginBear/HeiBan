import React, { useState } from 'react';
import { User } from 'firebase/auth';
import {
  X,
  User as UserIcon,
  Palette,
  Type,
  Info,
  Users,
  MessageSquare,
  LogIn,
  LogOut,
  Check,
  Send,
  Sparkles,
  ShieldCheck,
  Laptop,
} from 'lucide-react';
import { BoardTheme } from '../types';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  user: User | null;
  onSignIn: () => void;
  onSignOut: () => void;
  defaultTheme?: BoardTheme;
  onChangeDefaultTheme?: (theme: BoardTheme) => void;
  defaultFont?: string;
  onChangeDefaultFont?: (font: string) => void;
}

type TabKey = 'account' | 'theme' | 'font' | 'version' | 'developer' | 'feedback';

const THEME_OPTIONS: { id: BoardTheme; name: string; bg: string; desc: string }[] = [
  { id: 'blackboard', name: '經典綠黑板', bg: '#172e25', desc: '墨綠粉筆課堂風格，沉穩護眼' },
  { id: 'dark', name: '深炭黑畫布', bg: '#121316', desc: '極黑曜石質感，高對比幾何製圖' },
  { id: 'whiteboard', name: '純淨白板', bg: '#f8fafc', desc: '簡報、心智圖與會議腦力激盪' },
  { id: 'slate', name: '石板灰風格', bg: '#1e2430', desc: '工程架構與幾何手繪設計' },
];

const FONT_OPTIONS = [
  { id: '"Caveat", "Comic Sans MS", cursive', name: '黑板手寫體 (Caveat)', preview: 'HeiBan 黑板手寫板書 123' },
  { id: 'system-ui, -apple-system, sans-serif', name: '現代無襯線 (System UI)', preview: 'HeiBan 簡約現代黑體 123' },
  { id: 'Georgia, "Times New Roman", serif', name: '經典襯線 (Georgia)', preview: 'HeiBan 典雅學術襯線 123' },
  { id: '"Courier New", Consolas, monospace', name: '等寬字體 (Monospace)', preview: 'HeiBan 程式碼等寬 123' },
];

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  user,
  onSignIn,
  onSignOut,
  defaultTheme = 'blackboard',
  onChangeDefaultTheme,
  defaultFont = '"Caveat", "Comic Sans MS", cursive',
  onChangeDefaultFont,
}) => {
  const [activeTab, setActiveTab] = useState<TabKey>('account');
  const [feedbackCategory, setFeedbackCategory] = useState<'bug' | 'feature' | 'praise'>('feature');
  const [feedbackContent, setFeedbackContent] = useState('');
  const [feedbackEmail, setFeedbackEmail] = useState(user?.email || '');
  const [feedbackSent, setFeedbackSent] = useState(false);

  if (!isOpen) return null;

  const handleSubmitFeedback = (e: React.FormEvent) => {
    e.preventDefault();
    if (!feedbackContent.trim()) return;
    setFeedbackSent(true);
    setTimeout(() => {
      setFeedbackSent(false);
      setFeedbackContent('');
    }, 2500);
  };

  const navItems: { key: TabKey; label: string; icon: React.ReactNode }[] = [
    { key: 'account', label: 'Google 帳號管理', icon: <UserIcon className="w-4 h-4" /> },
    { key: 'theme', label: '整體主題顏色', icon: <Palette className="w-4 h-4" /> },
    { key: 'font', label: '預設字體', icon: <Type className="w-4 h-4" /> },
    { key: 'version', label: '版本號與更新', icon: <Info className="w-4 h-4" /> },
    { key: 'developer', label: '開發人員介紹', icon: <Users className="w-4 h-4" /> },
    { key: 'feedback', label: '意見回覆', icon: <MessageSquare className="w-4 h-4" /> },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-md animate-in fade-in duration-150">
      <div className="w-full max-w-2xl bg-neutral-900 border border-neutral-700/80 rounded-3xl shadow-2xl overflow-hidden flex flex-col text-neutral-200 h-[600px] max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-neutral-800 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-400 flex items-center justify-center text-white font-bold text-sm shadow">
              ⚙️
            </div>
            <div>
              <h2 className="text-base font-bold text-white tracking-tight">系統設定與帳號中心</h2>
              <p className="text-xs text-neutral-400">HeiBan 黑板自訂偏好與帳號管理</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl hover:bg-neutral-800 text-neutral-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body: Left Tabs Sidebar + Right Panel */}
        <div className="flex flex-1 overflow-hidden">
          {/* Left Navigation */}
          <div className="w-48 sm:w-52 border-r border-neutral-800 bg-neutral-950/50 p-3 space-y-1 overflow-y-auto shrink-0">
            {navItems.map((item) => (
              <button
                key={item.key}
                onClick={() => setActiveTab(item.key)}
                className={`w-full flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-xs font-medium text-left transition-colors ${
                  activeTab === item.key
                    ? 'bg-emerald-600 text-white shadow-md font-bold'
                    : 'text-neutral-400 hover:bg-neutral-800/80 hover:text-neutral-200'
                }`}
              >
                {item.icon}
                <span className="truncate">{item.label}</span>
              </button>
            ))}
          </div>

          {/* Right Content */}
          <div className="flex-1 p-6 overflow-y-auto scrollbar-thin">
            {/* Tab 1: Google Account */}
            {activeTab === 'account' && (
              <div className="space-y-5">
                <div>
                  <h3 className="text-sm font-bold text-white mb-1">Google 帳號管理</h3>
                  <p className="text-xs text-neutral-400">
                    登入 Google 帳號後，您的所有黑板作品將即時同步至雲端，支援跨裝置隨時存取。
                  </p>
                </div>

                {user ? (
                  <div className="p-4 rounded-2xl bg-neutral-800/60 border border-neutral-700/60 space-y-4">
                    <div className="flex items-center gap-3.5">
                      <img
                        src={user.photoURL || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&fit=crop&q=80'}
                        alt={user.displayName || 'User'}
                        className="w-12 h-12 rounded-full border-2 border-emerald-500 object-cover"
                      />
                      <div className="min-w-0 flex-1">
                        <div className="font-bold text-white truncate flex items-center gap-1.5">
                          <span>{user.displayName || 'Google 雲端使用者'}</span>
                          <span className="px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 text-[10px] font-mono">
                            已連線
                          </span>
                        </div>
                        <div className="text-xs text-neutral-400 truncate">{user.email}</div>
                        <div className="text-[10px] text-neutral-500 font-mono mt-0.5">UID: {user.uid}</div>
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-3 border-t border-neutral-700/60 text-xs">
                      <div className="flex items-center gap-1.5 text-emerald-400">
                        <ShieldCheck className="w-4 h-4" />
                        <span>雲端即時同步已啟動</span>
                      </div>
                      <button
                        onClick={onSignOut}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-red-600/20 hover:bg-red-600 text-red-300 hover:text-white transition-all text-xs"
                      >
                        <LogOut className="w-3.5 h-3.5" />
                        <span>登出帳號</span>
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="p-6 rounded-2xl bg-neutral-800/40 border border-dashed border-neutral-700 text-center space-y-3">
                    <div className="w-12 h-12 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center mx-auto">
                      <UserIcon className="w-6 h-6" />
                    </div>
                    <div>
                      <div className="font-bold text-white text-sm">目前為訪客離線模式</div>
                      <div className="text-xs text-neutral-400 mt-1">
                        資料儲存於瀏覽器本地緩存中。登入 Google 帳號可備份所有畫布至雲端。
                      </div>
                    </div>
                    <button
                      onClick={onSignIn}
                      className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs shadow-lg transition-transform active:scale-95"
                    >
                      <LogIn className="w-4 h-4" />
                      <span>使用 Google 帳號登入</span>
                    </button>
                  </div>
                )}
              </div>
            )}

            {/* Tab 2: Theme */}
            {activeTab === 'theme' && (
              <div className="space-y-5">
                <div>
                  <h3 className="text-sm font-bold text-white mb-1">整體主題顏色風格</h3>
                  <p className="text-xs text-neutral-400">
                    設定新建黑板時的預設背景風格與底色，兼顧板書書寫護眼與清晰幾何製圖。
                  </p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {THEME_OPTIONS.map((th) => (
                    <div
                      key={th.id}
                      onClick={() => onChangeDefaultTheme?.(th.id)}
                      className={`p-3.5 rounded-2xl border cursor-pointer transition-all flex items-start gap-3 ${
                        defaultTheme === th.id
                          ? 'border-emerald-500 bg-emerald-500/10 shadow-md ring-1 ring-emerald-500'
                          : 'border-neutral-800 bg-neutral-800/40 hover:bg-neutral-800 hover:border-neutral-700'
                      }`}
                    >
                      <div
                        className="w-10 h-10 rounded-xl border border-white/20 shrink-0 shadow-inner flex items-center justify-center"
                        style={{ backgroundColor: th.bg }}
                      >
                        {defaultTheme === th.id && <Check className="w-5 h-5 text-white" />}
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="text-xs font-bold text-white">{th.name}</div>
                        <div className="text-[11px] text-neutral-400 mt-0.5 leading-relaxed">{th.desc}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Tab 3: Font */}
            {activeTab === 'font' && (
              <div className="space-y-5">
                <div>
                  <h3 className="text-sm font-bold text-white mb-1">預設字體與板書排版</h3>
                  <p className="text-xs text-neutral-400">
                    設定文字工具輸入文字與便簽時的預設字體質感。
                  </p>
                </div>

                <div className="space-y-2.5">
                  {FONT_OPTIONS.map((f) => (
                    <div
                      key={f.id}
                      onClick={() => onChangeDefaultFont?.(f.id)}
                      className={`p-3 rounded-2xl border cursor-pointer transition-all flex items-center justify-between ${
                        defaultFont === f.id
                          ? 'border-emerald-500 bg-emerald-500/10 ring-1 ring-emerald-500'
                          : 'border-neutral-800 bg-neutral-800/40 hover:bg-neutral-800 hover:border-neutral-700'
                      }`}
                    >
                      <div>
                        <div className="text-xs font-bold text-white">{f.name}</div>
                        <div className="text-sm text-emerald-300 mt-1" style={{ fontFamily: f.id }}>
                          {f.preview}
                        </div>
                      </div>
                      {defaultFont === f.id && (
                        <div className="w-5 h-5 rounded-full bg-emerald-500 text-white flex items-center justify-center shrink-0">
                          <Check className="w-3.5 h-3.5" />
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Tab 4: Version */}
            {activeTab === 'version' && (
              <div className="space-y-5">
                <div>
                  <h3 className="text-sm font-bold text-white mb-1">版本資訊與發布日誌</h3>
                  <p className="text-xs text-neutral-400">HeiBan 黑板當前核心架構版本</p>
                </div>

                <div className="p-4 rounded-2xl bg-neutral-800/40 border border-neutral-700/60 space-y-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Sparkles className="w-4 h-4 text-emerald-400" />
                      <span className="font-bold text-white text-sm">HeiBan 黑板 Pro</span>
                    </div>
                    <span className="text-xs px-2.5 py-0.5 rounded-full bg-emerald-600/30 text-emerald-300 font-mono font-bold border border-emerald-500/40">
                      v2.5.0 (Build 2026.10)
                    </span>
                  </div>

                  <div className="text-xs text-neutral-300 space-y-1.5 leading-relaxed pt-2 border-t border-neutral-700/50">
                    <div className="font-semibold text-white">✨ 最新功能更新亮點：</div>
                    <div className="flex items-center gap-1.5 text-neutral-400">
                      • CAD 級鼠標游標居中精準放大縮小（Centered Cursor Zoom）
                    </div>
                    <div className="flex items-center gap-1.5 text-neutral-400">
                      • 自由切換無限無邊界畫布與 A4 / 16:9 規格畫布，有邊界可平滑升級無邊界
                    </div>
                    <div className="flex items-center gap-1.5 text-neutral-400">
                      • 可愛造型便箋（和紙膠帶、貓耳、撕紙手帳、圓潤柔和粉彩）
                    </div>
                    <div className="flex items-center gap-1.5 text-neutral-400">
                      • 側邊垂直工具列排版最佳化，支援螢幕任意邊緣自適應
                    </div>
                    <div className="flex items-center gap-1.5 text-neutral-400">
                      • 360° 純圓形調色盤（Circular Color Palette）無方形對話框
                    </div>
                    <div className="flex items-center gap-1.5 text-neutral-400">
                      • 鍵盤 Esc 鍵一鍵無縫切換選取工具 (Select Tool)
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Tab 5: Developer */}
            {activeTab === 'developer' && (
              <div className="space-y-5">
                <div>
                  <h3 className="text-sm font-bold text-white mb-1">開發人員介紹</h3>
                  <p className="text-xs text-neutral-400">HeiBan 黑板設計與工程理念</p>
                </div>

                <div className="p-4 rounded-2xl bg-neutral-800/40 border border-neutral-700/60 space-y-3 leading-relaxed text-xs text-neutral-300">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-400 flex items-center justify-center text-white font-black text-sm shadow">
                      黑
                    </div>
                    <div>
                      <div className="font-bold text-white text-sm">HeiBan Architecture Group</div>
                      <div className="text-[11px] text-emerald-400">核心架構與手寫向量渲染團隊</div>
                    </div>
                  </div>

                  <p className="pt-2 border-t border-neutral-700/60 text-neutral-400">
                    HeiBan 黑板專為廣大教師、學生、學者與軟體設計師量身打造。我們深入拆解了
                    <strong className="text-neutral-200"> 微軟白板（Microsoft Whiteboard）</strong> 與
                    <strong className="text-neutral-200"> Excalidraw Desktop</strong>{' '}
                    的精華互動細節，融合向量筆觸吸附、直尺規標記、自訂圖釘導航、可愛便箋手帳排版與即時雲端協同，打造真正乾淨、純粹且生產力滿載的開源黑板平台。
                  </p>

                  <div className="pt-2 text-[11px] text-neutral-500 font-mono">
                    技術棧：React 19, TypeScript, Tailwind CSS, HTML5 Canvas 向量運算, Firebase Firestore
                  </div>
                </div>
              </div>
            )}

            {/* Tab 6: Feedback */}
            {activeTab === 'feedback' && (
              <div className="space-y-4">
                <div>
                  <h3 className="text-sm font-bold text-white mb-1">意見回覆與功能建議</h3>
                  <p className="text-xs text-neutral-400">
                    歡迎提出您的使用心得、功能期待或問題回報，我們將持續打磨！
                  </p>
                </div>

                {feedbackSent ? (
                  <div className="p-6 rounded-2xl bg-emerald-500/10 border border-emerald-500/40 text-center space-y-2 animate-in fade-in duration-200">
                    <div className="w-10 h-10 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center justify-center mx-auto">
                      <Check className="w-5 h-5" />
                    </div>
                    <div className="font-bold text-white text-sm">感謝您的寶貴回饋！</div>
                    <div className="text-xs text-neutral-400">已成功收到您的建議，工程團隊將積極檢閱更新。</div>
                  </div>
                ) : (
                  <form onSubmit={handleSubmitFeedback} className="space-y-3">
                    <div>
                      <label className="text-xs text-neutral-400 font-medium block mb-1">回饋類型：</label>
                      <div className="grid grid-cols-3 gap-2">
                        {[
                          { key: 'feature', label: '💡 功能建議' },
                          { key: 'bug', label: '🐞 問題回報' },
                          { key: 'praise', label: '❤️ 使用體驗' },
                        ].map((cat) => (
                          <button
                            key={cat.key}
                            type="button"
                            onClick={() => setFeedbackCategory(cat.key as any)}
                            className={`py-1.5 px-2 rounded-xl text-xs font-medium border text-center transition-colors ${
                              feedbackCategory === cat.key
                                ? 'border-emerald-500 bg-emerald-500/20 text-white font-bold'
                                : 'border-neutral-700 bg-neutral-800 text-neutral-400 hover:text-white'
                            }`}
                          >
                            {cat.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div>
                      <label className="text-xs text-neutral-400 font-medium block mb-1">聯絡 Email (選填)：</label>
                      <input
                        type="email"
                        value={feedbackEmail}
                        onChange={(e) => setFeedbackEmail(e.target.value)}
                        placeholder="your@email.com"
                        className="w-full px-3 py-1.5 rounded-xl bg-neutral-800 border border-neutral-700 text-xs text-white placeholder-neutral-500 outline-none focus:border-emerald-500"
                      />
                    </div>

                    <div>
                      <label className="text-xs text-neutral-400 font-medium block mb-1">詳細意見內容：</label>
                      <textarea
                        rows={4}
                        required
                        value={feedbackContent}
                        onChange={(e) => setFeedbackContent(e.target.value)}
                        placeholder="請詳細描述您的想法、操作中遇到的狀況或希望新增的功能..."
                        className="w-full p-3 rounded-xl bg-neutral-800 border border-neutral-700 text-xs text-white placeholder-neutral-500 outline-none focus:border-emerald-500 resize-none"
                      />
                    </div>

                    <button
                      type="submit"
                      disabled={!feedbackContent.trim()}
                      className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-bold text-xs shadow-md flex items-center justify-center gap-1.5 transition-all"
                    >
                      <Send className="w-3.5 h-3.5" />
                      <span>送出意見回饋</span>
                    </button>
                  </form>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
