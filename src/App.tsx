import { useState, useEffect, useRef, useCallback } from 'react';
import {
  onAuthStateChanged,
  signInWithPopup,
  signOut,
  User,
} from 'firebase/auth';
import {
  collection,
  doc,
  setDoc,
  deleteDoc,
  onSnapshot,
} from 'firebase/firestore';
import {
  auth,
  db,
  googleProvider,
  testFirestoreConnection,
  handleFirestoreError,
  OperationType,
} from './firebase';
import {
  BoardMetadata,
  BoardObject,
  ToolType,
  RulerState,
  ViewportTransform,
  UserPresence,
  EraserMode,
  BoardTheme,
  BoardPin,
  CanvasMode,
  CanvasPreset,
} from './types';
import { Canvas } from './components/Canvas';
import { Toolbar } from './components/Toolbar';
import { TopNav } from './components/TopNav';
import { LayerPanel } from './components/LayerPanel';
import { PropertiesBar } from './components/PropertiesBar';
import { BoardModal } from './components/BoardModal';
import { ScreenCaptureModal } from './components/ScreenCaptureModal';
import { PinManager } from './components/PinManager';
import { HomeDashboard } from './components/HomeDashboard';
import { ImageCropModal } from './components/ImageCropModal';
import { BrushSettingsBar } from './components/BrushSettingsBar';
import {
  exportToSvgFile,
  exportToPdfFile,
  exportToPngFile,
  exportToJsonFile,
  generateBoardThumbnailDataUrl,
} from './utils/export';

// Initial default board configuration
const DEFAULT_BOARD_ID = 'demo_blackboard_main';
const DEFAULT_BOARD: BoardMetadata = {
  id: DEFAULT_BOARD_ID,
  title: '我的第一塊黑板',
  ownerId: 'local',
  ownerName: '本機使用者',
  backgroundColor: '#172e25',
  gridStyle: 'grid',
  boardTheme: 'blackboard',
  canvasMode: 'infinite',
  canvasPreset: 'infinite',
  pins: [],
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
};

// New local boards start clean; the feature-tour objects are not user content.
const INITIAL_DEMO_OBJECTS: BoardObject[] = [];

export default function App() {
  const pendingPresenceRef = useRef<{ x: number; y: number; isDrawing: boolean } | null>(null);
  const presenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const presenceWriteActiveRef = useRef(false);
  const pendingObjectWritesRef = useRef(new Map<string, BoardObject>());
  const objectWriteTimersRef = useRef(new Map<string, ReturnType<typeof setTimeout>>());
  const pendingLocalObjectUpdatesRef = useRef(new Map<string, BoardObject>());
  const localObjectFrameRef = useRef<number | null>(null);
  // Current user state
  const [user, setUser] = useState<User | null>(null);

  // Board state
  const [board, setBoard] = useState<BoardMetadata>(DEFAULT_BOARD);
  const [allBoards, setAllBoards] = useState<BoardMetadata[]>([DEFAULT_BOARD]);
  const [isBoardModalOpen, setIsBoardModalOpen] = useState(false);

  // Objects on the board
  const [objects, setObjects] = useState<BoardObject[]>(INITIAL_DEMO_OBJECTS);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  // History for Undo / Redo
  const [history, setHistory] = useState<BoardObject[][]>([INITIAL_DEMO_OBJECTS]);
  const [historyIndex, setHistoryIndex] = useState(0);

  // Active Tool & Styling
  const [currentTool, setCurrentTool] = useState<ToolType>('pen');
  const [eraserMode, setEraserMode] = useState<EraserMode>('object');
  const [penColor, setPenColor] = useState('#ffffff');
  const [highlighterColor, setHighlighterColor] = useState('#facc15');
  const [activeColor, setActiveColor] = useState('#ffffff');
  const [activeStrokeWidth, setActiveStrokeWidth] = useState(4);
  const [activeLineStyle, setActiveLineStyle] = useState<'solid' | 'dashed'>('solid');
  const [activeOpacity, setActiveOpacity] = useState(1);
  const [isSelectingExportRange, setIsSelectingExportRange] = useState(false);

  const handleToolChange = useCallback((tool: ToolType) => {
    setCurrentTool(tool);
    if (tool === 'highlighter') {
      setActiveColor(highlighterColor);
      setActiveStrokeWidth(24);
      setActiveOpacity(0.45);
    } else if (tool === 'pen') {
      setActiveColor(penColor);
      setActiveStrokeWidth(4);
      setActiveOpacity(1);
    }
  }, [highlighterColor, penColor]);

  const handleChangeActiveColor = useCallback((color: string) => {
    setActiveColor(color);
    if (currentTool === 'highlighter') {
      setHighlighterColor(color);
    } else {
      setPenColor(color);
    }
  }, [currentTool]);

  // Secondary Image Cropping state (二次裁切與重置)
  const [croppingImage, setCroppingImage] = useState<BoardObject | null>(null);

  // Auto-save every X minutes state
  const [autoSaveMinutes, setAutoSaveMinutes] = useState<number>(() => {
    try {
      const saved = localStorage.getItem('blackboard_autosave_min');
      return saved !== null ? parseInt(saved, 10) : 2;
    } catch {
      return 2;
    }
  });
  const [lastSavedTime, setLastSavedTime] = useState<string>(() =>
    new Date().toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  );
  const [isAutoSaving, setIsAutoSaving] = useState(false);

  // Screen-spanning Ruler state (穿越整個螢幕畫面)
  const [ruler, setRuler] = useState<RulerState>({
    enabled: false,
    screenCenterX: window.innerWidth / 2,
    screenCenterY: window.innerHeight / 2,
    angle: 0,
    width: 1100,
    height: 80,
    pivotRatio: 0,
    pivotEdge: 'center',
    opacity: 0.35,
  });

  // Viewport transform (Pan & Zoom)
  const [viewport, setViewport] = useState<ViewportTransform>({
    x: 40,
    y: 40,
    zoom: 1,
  });

  // Collaborator Presences & Cursors
  const [presences, setPresences] = useState<UserPresence[]>([]);
  const [showCursors, setShowCursors] = useState(true);

  // Modals & Panels
  const [isLayerOpen, setIsLayerOpen] = useState(false);
  const [isPinOpen, setIsPinOpen] = useState(false);
  const [isScreenCaptureOpen, setIsScreenCaptureOpen] = useState(false);
  const [syncStatus, setSyncStatus] = useState<'synced' | 'saving' | 'offline'>('synced');
  // View mode: 'home' dashboard (Word/Figma-like start screen) or 'canvas' editor
  const [viewMode, setViewMode] = useState<'home' | 'canvas'>('home');

  // Push history checkpoint
  const pushHistory = useCallback((newObjects: BoardObject[]) => {
    setHistory((prev) => {
      const trimmed = prev.slice(0, historyIndex + 1);
      return [...trimmed, newObjects].slice(-35);
    });
    setHistoryIndex((prev) => prev + 1);
  }, [historyIndex]);

  // Auth observer & boot verification
  useEffect(() => {
    testFirestoreConnection();
    const unsub = onAuthStateChanged(auth, (usr) => {
      setUser(usr);
    });
    return () => unsub();
  }, []);

  // Sync board metadata from Firestore
  useEffect(() => {
    if (!user || !board.id) return;
    const boardDocRef = doc(db, 'boards', board.id);
    const unsub = onSnapshot(
      boardDocRef,
      (snapshot) => {
        if (snapshot.exists()) {
          setBoard(snapshot.data() as BoardMetadata);
        }
      },
      (error) => {
        handleFirestoreError(error, OperationType.GET, `boards/${board.id}`);
      }
    );
    return () => unsub();
  }, [board.id, user?.uid]);

  // Sync objects from Firestore
  useEffect(() => {
    if (!user || !board.id) return;
    const objectsColRef = collection(db, 'boards', board.id, 'objects');
    const unsub = onSnapshot(
      objectsColRef,
      (snapshot) => {
        if (!snapshot.empty) {
          const list: BoardObject[] = [];
          snapshot.forEach((d) => list.push(d.data() as BoardObject));
          setObjects(list);
        }
      },
      (error) => {
        handleFirestoreError(error, OperationType.LIST, `boards/${board.id}/objects`);
      }
    );
    return () => unsub();
  }, [board.id, user?.uid]);

  // Sync collaborator presences from Firestore
  useEffect(() => {
    if (!user || !board.id) return;
    const presencesColRef = collection(db, 'boards', board.id, 'presences');
    const unsub = onSnapshot(
      presencesColRef,
      (snapshot) => {
        const list: UserPresence[] = [];
        snapshot.forEach((d) => list.push(d.data() as UserPresence));
        setPresences(list);
      },
      (error) => {
        handleFirestoreError(error, OperationType.LIST, `boards/${board.id}/presences`);
      }
    );
    return () => unsub();
  }, [board.id, user?.uid]);

  // Keep only the latest cursor sample and serialize presence writes.
  const flushPresence = useCallback(async () => {
    presenceTimerRef.current = null;
    const sample = pendingPresenceRef.current;
    pendingPresenceRef.current = null;
    if (!user || !sample || presenceWriteActiveRef.current) return;
    presenceWriteActiveRef.current = true;
    try {
      await setDoc(
        doc(db, 'boards', board.id, 'presences', user.uid),
        {
          boardId: board.id,
          userId: user.uid,
          displayName: user.displayName || '訪客',
          photoURL: user.photoURL || '',
          cursorX: Math.round(sample.x),
          cursorY: Math.round(sample.y),
          color: '#3b82f6',
          isDrawing: sample.isDrawing,
          currentTool,
          updatedAt: new Date().toISOString(),
        },
        { merge: true }
      );
    } catch {
      // Presence is ephemeral; a later sample will retry it.
    } finally {
      presenceWriteActiveRef.current = false;
      if (pendingPresenceRef.current && !presenceTimerRef.current) {
        presenceTimerRef.current = setTimeout(() => void flushPresence(), 100);
      }
    }
  }, [user, board.id, currentTool]);

  const handlePointerTrack = useCallback(
    (x: number, y: number, isDrawing: boolean) => {
      pendingPresenceRef.current = { x, y, isDrawing };
      if (user && !presenceWriteActiveRef.current && !presenceTimerRef.current) {
        presenceTimerRef.current = setTimeout(() => void flushPresence(), 100);
      }
    },
    [user, flushPresence]
  );

  // Firestore save object helper
  const persistObject = async (obj: BoardObject) => {
    setSyncStatus('saving');
    try {
      if (user) {
        const docRef = doc(db, 'boards', board.id, 'objects', obj.id);
        await setDoc(docRef, obj);
      }
      setSyncStatus('synced');
    } catch (err) {
      setSyncStatus('offline');
      handleFirestoreError(err, OperationType.WRITE, `boards/${board.id}/objects/${obj.id}`);
    }
  };

  const scheduleObjectPersist = (obj: BoardObject) => {
    pendingObjectWritesRef.current.set(obj.id, obj);
    const existingTimer = objectWriteTimersRef.current.get(obj.id);
    if (existingTimer) clearTimeout(existingTimer);
    const timer = setTimeout(() => {
      objectWriteTimersRef.current.delete(obj.id);
      const latest = pendingObjectWritesRef.current.get(obj.id);
      pendingObjectWritesRef.current.delete(obj.id);
      if (latest) void persistObject(latest);
    }, 180);
    objectWriteTimersRef.current.set(obj.id, timer);
  };

  const cancelScheduledObjectPersist = (id: string) => {
    const timer = objectWriteTimersRef.current.get(id);
    if (timer) clearTimeout(timer);
    objectWriteTimersRef.current.delete(id);
    pendingObjectWritesRef.current.delete(id);
    pendingLocalObjectUpdatesRef.current.delete(id);
  };

  useEffect(() => {
    return () => {
      if (presenceTimerRef.current) clearTimeout(presenceTimerRef.current);
      for (const timer of objectWriteTimersRef.current.values()) clearTimeout(timer);
      for (const obj of pendingObjectWritesRef.current.values()) void persistObject(obj);
      pendingObjectWritesRef.current.clear();
      objectWriteTimersRef.current.clear();
    };
  }, [user, board.id]);

  useEffect(() => () => {
    if (localObjectFrameRef.current !== null) cancelAnimationFrame(localObjectFrameRef.current);
    localObjectFrameRef.current = null;
    pendingLocalObjectUpdatesRef.current.clear();
  }, [board.id]);

  // Add object
  const handleAddObject = (obj: BoardObject) => {
    const updated = [...objects, obj];
    setObjects(updated);
    pushHistory(updated);
    persistObject(obj);
  };

  // Update object
  const handleUpdateObject = (id: string, partial: Partial<BoardObject>) => {
    const base = pendingLocalObjectUpdatesRef.current.get(id) ?? objects.find((o) => o.id === id);
    if (!base) return;
    const target = { ...base, ...partial, updatedAt: new Date().toISOString() };
    pendingLocalObjectUpdatesRef.current.set(id, target);
    if (localObjectFrameRef.current === null) {
      localObjectFrameRef.current = requestAnimationFrame(() => {
        localObjectFrameRef.current = null;
        const updates = new Map(pendingLocalObjectUpdatesRef.current);
        pendingLocalObjectUpdatesRef.current.clear();
        setObjects((current) => current.map((object) => updates.get(object.id) ?? object));
      });
    }
    scheduleObjectPersist(target);
  };

  // Delete objects
  const handleDeleteObjects = (ids: string[]) => {
    ids.forEach(cancelScheduledObjectPersist);
    const updated = objects.filter((o) => !ids.includes(o.id));
    setObjects(updated);
    setSelectedIds((prev) => prev.filter((id) => !ids.includes(id)));
    pushHistory(updated);

    if (user) {
      for (const id of ids) {
        deleteDoc(doc(db, 'boards', board.id, 'objects', id)).catch(() => {});
      }
    }
  };

  // Reorder layer
  const handleReorderLayer = (id: string, action: 'top' | 'up' | 'down' | 'bottom') => {
    const index = objects.findIndex((o) => o.id === id);
    if (index === -1) return;

    const copy = [...objects];
    if (action === 'top') {
      const maxZ = Math.max(...copy.map((o) => o.zIndex), 0);
      handleUpdateObject(id, { zIndex: maxZ + 1 });
    } else if (action === 'bottom') {
      const minZ = Math.min(...copy.map((o) => o.zIndex), 0);
      handleUpdateObject(id, { zIndex: Math.max(0, minZ - 1) });
    } else if (action === 'up') {
      handleUpdateObject(id, { zIndex: copy[index].zIndex + 1 });
    } else if (action === 'down') {
      handleUpdateObject(id, { zIndex: Math.max(0, copy[index].zIndex - 1) });
    }
  };

  // Duplicate selected objects
  const handleDuplicateSelected = () => {
    const selectedObjs = objects.filter((o) => selectedIds.includes(o.id));
    if (selectedObjs.length === 0) return;

    const newObjs: BoardObject[] = selectedObjs.map((orig) => {
      const newId = orig.type + '_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6);
      return {
        ...orig,
        id: newId,
        x: orig.x + 30,
        y: orig.y + 30,
        zIndex: objects.length + 2,
        updatedAt: new Date().toISOString(),
      };
    });

    const updated = [...objects, ...newObjs];
    setObjects(updated);
    setSelectedIds(newObjs.map((o) => o.id));
    pushHistory(updated);
    for (const no of newObjs) {
      persistObject(no);
    }
  };

  // One-click Clear Canvas (一鍵清除畫布)
  const handleClearCanvas = () => {
    if (objects.length === 0) return;
    if (confirm('確定要清除黑板上的所有物件嗎？此動作可透過 Ctrl+Z 隨時復原。')) {
      const idsToDelete = objects.map((o) => o.id);
      idsToDelete.forEach(cancelScheduledObjectPersist);
      setObjects([]);
      setSelectedIds([]);
      pushHistory([]);

      if (user) {
        for (const id of idsToDelete) {
          deleteDoc(doc(db, 'boards', board.id, 'objects', id)).catch(() => {});
        }
      }
    }
  };

  // Clipboard Paste (Ctrl+V) handler
  useEffect(() => {
    const handlePaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        if (item.type.startsWith('image/')) {
          const file = item.getAsFile();
          if (file) {
            handleImageUpload(file);
          }
          break;
        }
      }
    };

    window.addEventListener('paste', handlePaste);
    return () => window.removeEventListener('paste', handlePaste);
  }, [objects, viewport, board.id]);

  // Image upload handler preserving full original resolution
  const handleImageUpload = (file: File) => {
    const reader = new FileReader();
    reader.onload = (ev) => {
      const dataUrl = ev.target?.result as string;
      createImageObjectFromDataUrl(dataUrl);
    };
    reader.readAsDataURL(file);
  };

  const createImageObjectFromDataUrl = (dataUrl: string) => {
    const img = new Image();
    img.onload = () => {
      let width = img.naturalWidth || 600;
      let height = img.naturalHeight || 400;

      const maxInitial = 800;
      if (width > maxInitial || height > maxInitial) {
        const ratio = Math.min(maxInitial / width, maxInitial / height);
        width = Math.round(width * ratio);
        height = Math.round(height * ratio);
      }

      const worldX = (window.innerWidth / 2 - viewport.x) / viewport.zoom - width / 2;
      const worldY = (window.innerHeight / 2 - viewport.y) / viewport.zoom - height / 2;

      const newId = 'img_' + Date.now();
      const imgObj: BoardObject = {
        id: newId,
        boardId: board.id,
        type: 'image',
        x: Math.round(worldX),
        y: Math.round(worldY),
        width,
        height,
        strokeColor: 'transparent',
        fillColor: 'none',
        strokeWidth: 0,
        opacity: 1,
        rotation: 0,
        zIndex: objects.length + 1,
        imageUrl: dataUrl,
        originalImageUrl: dataUrl, // Preserve original pristine high-res source for secondary crop & reset!
        originalWidth: width,
        originalHeight: height,
        createdBy: user?.uid || 'anonymous',
        updatedAt: new Date().toISOString(),
      };

      handleAddObject(imgObj);
      setSelectedIds([newId]);
      setCurrentTool('select');
    };
    img.src = dataUrl;
  };

  // Image Cropping & Reset handlers (二次裁切與還原原始狀態)
  const handleSaveCrop = (
    objectId: string,
    newImageUrl: string,
    newWidth: number,
    newHeight: number
  ) => {
    handleUpdateObject(objectId, {
      imageUrl: newImageUrl,
      width: newWidth,
      height: newHeight,
    });
    setCroppingImage(null);
  };

  const handleResetImageOriginal = (objectId: string) => {
    const obj = objects.find((o) => o.id === objectId);
    if (obj && obj.originalImageUrl) {
      handleUpdateObject(objectId, {
        imageUrl: obj.originalImageUrl,
        width: obj.originalWidth || obj.width,
        height: obj.originalHeight || obj.height,
      });
    }
    setCroppingImage(null);
  };

  // Auto-Save Implementation (每幾分鐘自動存儲)
  const handleAutoSave = useCallback(async () => {
    if (!board.id) return;
    try {
      setIsAutoSaving(true);
      setSyncStatus('saving');

      // Generate fresh board thumbnail for home dashboard
      const thumbnail = generateBoardThumbnailDataUrl(objects, board);
      const updatedBoard: BoardMetadata = {
        ...board,
        thumbnail: thumbnail || board.thumbnail,
        itemCount: objects.length,
        updatedAt: new Date().toISOString(),
      };
      setBoard(updatedBoard);

      // Update allBoards list with latest thumbnail & metadata
      setAllBoards((prev) =>
        prev.map((b) => (b.id === board.id ? updatedBoard : b))
      );

      // Save board metadata to Firestore
      const boardDocRef = doc(db, 'boards', board.id);
      await setDoc(boardDocRef, updatedBoard, { merge: true });

      // Save objects to Firestore if user logged in
      if (user) {
        for (const obj of objects) {
          const objDocRef = doc(db, 'boards', board.id, 'objects', obj.id);
          await setDoc(objDocRef, obj, { merge: true });
        }
      }

      // Offline backup in localStorage
      try {
        localStorage.setItem(
          `board_backup_${board.id}`,
          JSON.stringify({ board: updatedBoard, objects })
        );
      } catch {
        // ignore
      }

      const nowStr = new Date().toLocaleTimeString('zh-TW', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      });
      setLastSavedTime(nowStr);
      setSyncStatus('synced');
    } catch (err) {
      console.error('Auto save error:', err);
      setSyncStatus('offline');
    } finally {
      setIsAutoSaving(false);
    }
  }, [board, objects, user]);

  // Auto-Save interval timer
  useEffect(() => {
    if (autoSaveMinutes <= 0) return;
    const intervalMs = autoSaveMinutes * 60 * 1000;
    const timer = setInterval(() => {
      handleAutoSave();
    }, intervalMs);
    return () => clearInterval(timer);
  }, [autoSaveMinutes, handleAutoSave]);

  const handleChangeAutoSaveMinutes = (min: number) => {
    setAutoSaveMinutes(min);
    try {
      localStorage.setItem('blackboard_autosave_min', min.toString());
    } catch {
      // ignore
    }
  };

  // Keyboard Shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (['INPUT', 'TEXTAREA'].includes((e.target as HTMLElement).tagName)) {
        return;
      }

      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') {
        if (e.shiftKey) {
          handleRedo();
        } else {
          handleUndo();
        }
        e.preventDefault();
        return;
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') {
        handleRedo();
        e.preventDefault();
        return;
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
        e.preventDefault();
        handleAutoSave();
        return;
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'd') {
        e.preventDefault();
        handleDuplicateSelected();
        return;
      }

      if (e.key === 'Escape') {
        handleToolChange('select');
        setSelectedIds([]);
        setIsSelectingExportRange(false);
        return;
      }

      if (e.key === 'Delete' || e.key === 'Backspace') {
        if (selectedIds.length > 0) {
          handleDeleteObjects(selectedIds);
          e.preventDefault();
        }
        return;
      }

      const key = e.key.toLowerCase();
      if (key === 'v') handleToolChange('select');
      if (key === 'p') handleToolChange('pen');
      if (key === 'h') handleToolChange('highlighter');
      if (key === 'e') handleToolChange('eraser');
      if (key === 'r') setRuler((prev) => ({ ...prev, enabled: !prev.enabled }));
      if (key === 's') handleToolChange('line');
      if (key === 't') handleToolChange('text');
      if (key === 'n') handleToolChange('sticky');
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [selectedIds, historyIndex, history, objects, handleToolChange]);

  // Undo / Redo
  const handleUndo = () => {
    if (historyIndex > 0) {
      const prevObjects = history[historyIndex - 1];
      setHistoryIndex((prev) => prev - 1);
      setObjects(prevObjects);
    }
  };

  const handleRedo = () => {
    if (historyIndex < history.length - 1) {
      const nextObjects = history[historyIndex + 1];
      setHistoryIndex((prev) => prev + 1);
      setObjects(nextObjects);
    }
  };

  // Google Login
  const handleSignIn = async () => {
    try {
      await signInWithPopup(auth, googleProvider);
    } catch (err) {
      console.error('Google Sign In failed:', err);
    }
  };

  const handleSignOut = async () => {
    try {
      await signOut(auth);
    } catch (err) {
      console.error('Sign out failed:', err);
    }
  };

  // Update board metadata
  const handleUpdateBoard = async (partial: Partial<BoardMetadata>) => {
    const updated = { ...board, ...partial, updatedAt: new Date().toISOString() };
    setBoard(updated);
    setAllBoards((prev) => prev.map((b) => (b.id === board.id ? updated : b)));

    if (user) {
      try {
        await setDoc(doc(db, 'boards', board.id), updated, { merge: true });
      } catch (err) {
        handleFirestoreError(err, OperationType.UPDATE, `boards/${board.id}`);
      }
    }
  };

  // Auto-generate thumbnail for Home Dashboard preview
  useEffect(() => {
    if (objects.length > 0) {
      const thumb = generateBoardThumbnailDataUrl(objects, board);
      if (thumb && thumb !== board.thumbnail) {
        setBoard((prev) => ({ ...prev, thumbnail: thumb }));
        setAllBoards((prev) =>
          prev.map((b) => (b.id === board.id ? { ...b, thumbnail: thumb, updatedAt: new Date().toISOString() } : b))
        );
      }
    }
  }, [objects, board.id]);

  // Pin (圖釘) handlers
  const handleAddPin = (name: string, x: number, y: number, zoom: number) => {
    const newPin: BoardPin = {
      id: 'pin_' + Date.now(),
      name,
      x: Math.round(x),
      y: Math.round(y),
      zoom,
      createdAt: new Date().toISOString(),
    };
    const updatedPins = [...(board.pins || []), newPin];
    handleUpdateBoard({ pins: updatedPins });
  };

  const handleUpdatePin = (pinId: string, partial: Partial<BoardPin>) => {
    const currentPins = board.pins || [];
    const updatedPins = currentPins.map((p) => (p.id === pinId ? { ...p, ...partial } : p));
    handleUpdateBoard({ pins: updatedPins });
  };

  const handleDeletePin = (id: string) => {
    const updatedPins = (board.pins || []).filter((p) => p.id !== id);
    handleUpdateBoard({ pins: updatedPins });
  };

  // User requirement: "圖釘不要瞬間移動 用較平滑的方式移動 然後圖釘應該是 會在左上方 不是右上方 而且圖釘可以自己設定名稱"
  const pinAnimRef = useRef<number | null>(null);

  const handleJumpToPin = (pin: BoardPin) => {
    if (pinAnimRef.current) {
      cancelAnimationFrame(pinAnimRef.current);
      pinAnimRef.current = null;
    }

    // Top-left alignment (在左上方，預留導航列與左側邊距)
    const targetZoom = pin.zoom || 1;
    const targetX = 130 - pin.x * targetZoom;
    const targetY = 110 - pin.y * targetZoom;

    const startX = viewport.x;
    const startY = viewport.y;
    const startZoom = viewport.zoom;
    const startTime = performance.now();
    const duration = 480; // 480ms smooth animation

    const easeOutCubic = (t: number) => 1 - Math.pow(1 - t, 3);

    const step = (now: number) => {
      const elapsed = now - startTime;
      const progress = Math.min(1, elapsed / duration);
      const ease = easeOutCubic(progress);

      setViewport({
        x: Math.round(startX + (targetX - startX) * ease),
        y: Math.round(startY + (targetY - startY) * ease),
        zoom: Number((startZoom + (targetZoom - startZoom) * ease).toFixed(4)),
      });

      if (progress < 1) {
        pinAnimRef.current = requestAnimationFrame(step);
      } else {
        pinAnimRef.current = null;
      }
    };

    pinAnimRef.current = requestAnimationFrame(step);
    setIsPinOpen(false);
  };

  // Batch layer reorder (iPhone drag-and-drop)
  const handleReorderBatch = (newOrderedIds: string[]) => {
    setObjects((prev) => {
      const idToZ: Record<string, number> = {};
      newOrderedIds.forEach((id, index) => {
        idToZ[id] = newOrderedIds.length - index;
      });
      const updated = prev.map((o) =>
        idToZ[o.id] !== undefined ? { ...o, zIndex: idToZ[o.id] } : o
      );
      pushHistory(updated);
      return updated;
    });
  };

  // Open Board from Home Dashboard
  const handleOpenBoard = (boardId: string) => {
    const found = allBoards.find((b) => b.id === boardId);
    if (found) {
      setBoard(found);
    }
    setViewMode('canvas');
  };

  // Create new board
  const handleCreateBoard = async (
    title: string,
    theme: BoardTheme,
    canvasMode: CanvasMode = 'infinite',
    canvasPreset: CanvasPreset = 'infinite',
    width: number = 1920,
    height: number = 1080
  ) => {
    const themeBgs: Record<BoardTheme, string> = {
      blackboard: '#172e25',
      dark: '#121316',
      whiteboard: '#f8fafc',
      slate: '#1e2430',
    };
    const newBoardId = 'board_' + Date.now();
    const newBoard: BoardMetadata = {
      id: newBoardId,
      title,
      ownerId: user?.uid || 'anonymous',
      ownerName: user?.displayName || '黑板協作者',
      ownerPhoto: user?.photoURL || '',
      backgroundColor: themeBgs[theme],
      gridStyle: 'grid',
      boardTheme: theme,
      canvasMode,
      canvasPreset,
      canvasWidth: width,
      canvasHeight: height,
      pins: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    setAllBoards((prev) => [newBoard, ...prev]);
    setBoard(newBoard);
    setObjects([]);
    setSelectedIds([]);
    setHistory([[]]);
    setHistoryIndex(0);
    setIsBoardModalOpen(false);

    if (user) {
      try {
        await setDoc(doc(db, 'boards', newBoardId), newBoard);
      } catch (err) {
        handleFirestoreError(err, OperationType.CREATE, `boards/${newBoardId}`);
      }
    }
  };

  // Delete board
  const handleDeleteBoard = async (boardId: string) => {
    setAllBoards((prev) => prev.filter((b) => b.id !== boardId));
    if (board.id === boardId) {
      const remaining = allBoards.filter((b) => b.id !== boardId);
      setBoard(remaining.length > 0 ? remaining[0] : DEFAULT_BOARD);
    }
    if (user) {
      try {
        await deleteDoc(doc(db, 'boards', boardId));
      } catch (err) {
        handleFirestoreError(err, OperationType.DELETE, `boards/${boardId}`);
      }
    }
  };

  // Import JSON
  const handleImportJson = (file: File) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = JSON.parse(e.target?.result as string);
        if (data.board && data.objects) {
          setBoard(data.board);
          setObjects(data.objects);
          pushHistory(data.objects);
        }
      } catch {
        alert('匯入失敗：非有效的黑板 JSON 檔案格式');
      }
    };
    reader.readAsText(file);
  };

  if (viewMode === 'home') {
    return (
      <HomeDashboard
        boards={allBoards}
        currentBoardId={board.id}
        user={user}
        onOpenBoard={handleOpenBoard}
        onCreateBoard={(title, theme, canvasMode, canvasPreset, w, h) => {
          handleCreateBoard(title, theme, canvasMode, canvasPreset, w, h);
          setViewMode('canvas');
        }}
        onDeleteBoard={handleDeleteBoard}
        onSignIn={handleSignIn}
        onSignOut={handleSignOut}
      />
    );
  }

  return (
    <div className="relative w-screen h-screen overflow-hidden bg-[#4a4e57] font-sans select-none">
      {/* Top Navigation Bar */}
      <TopNav
        board={board}
        user={user}
        presences={presences}
        showCursors={showCursors}
        isLayerOpen={isLayerOpen}
        isPinOpen={isPinOpen}
        syncStatus={syncStatus}
        autoSaveMinutes={autoSaveMinutes}
        lastSavedTime={lastSavedTime}
        isAutoSaving={isAutoSaving}
        onChangeAutoSaveMinutes={handleChangeAutoSaveMinutes}
        onTriggerAutoSave={handleAutoSave}
        onGoHome={() => setViewMode('home')}
        onUpdateBoard={handleUpdateBoard}
        onToggleCursors={() => setShowCursors(!showCursors)}
        onToggleLayers={() => setIsLayerOpen(!isLayerOpen)}
        onTogglePins={() => setIsPinOpen(!isPinOpen)}
        onStartRangeExport={() => setIsSelectingExportRange(true)}
        onExportSvg={() => exportToSvgFile(objects, board)}
        onExportPdf={() => exportToPdfFile(objects, board)}
        onExportPng={() => exportToPngFile(objects, board)}
        onExportJson={() => exportToJsonFile(objects, board)}
        onImportJson={handleImportJson}
        onOpenBoardsModal={() => setIsBoardModalOpen(true)}
        onSignIn={handleSignIn}
        onSignOut={handleSignOut}
      />

      {/* Selected Object Properties Floating Bar */}
      {selectedIds.length > 0 && (
        <PropertiesBar
          selectedObjects={objects.filter((o) => selectedIds.includes(o.id))}
          onUpdate={(partial) => {
            if (partial.lineStyle) {
              setActiveLineStyle(partial.lineStyle);
            }
            for (const id of selectedIds) {
              handleUpdateObject(id, partial);
            }
          }}
          onDelete={() => handleDeleteObjects(selectedIds)}
          onDuplicate={handleDuplicateSelected}
          onReorder={(action) => handleReorderLayer(selectedIds[0], action)}
          onCropImage={(obj) => setCroppingImage(obj)}
          onResetImage={(obj) => handleResetImageOriginal(obj.id)}
        />
      )}

      {/* Floating Brush Settings Bar (調整畫筆粗細/顏色/透明度/實線虛線) */}
      {selectedIds.length === 0 &&
        ['pen', 'highlighter', 'line', 'arrow', 'rect', 'circle', 'triangle', 'diamond', 'star'].includes(
          currentTool
        ) && (
          <BrushSettingsBar
            currentTool={currentTool}
            activeColor={activeColor}
            activeStrokeWidth={activeStrokeWidth}
            activeLineStyle={activeLineStyle}
            activeOpacity={activeOpacity}
            onChangeColor={handleChangeActiveColor}
            onChangeStrokeWidth={setActiveStrokeWidth}
            onChangeLineStyle={setActiveLineStyle}
            onChangeOpacity={setActiveOpacity}
          />
        )}

      {/* Main Vector Canvas */}
      <Canvas
        board={board}
        objects={objects}
        selectedIds={selectedIds}
        currentTool={currentTool}
        eraserMode={eraserMode}
        ruler={ruler}
        viewport={viewport}
        presences={presences}
        currentUserId={user?.uid}
        showCursors={showCursors}
        activeColor={activeColor}
        activeStrokeWidth={activeStrokeWidth}
        activeLineStyle={activeLineStyle}
        activeOpacity={activeOpacity}
        onUpdateViewport={setViewport}
        onUpdateRuler={(partial) => setRuler((prev) => ({ ...prev, ...partial }))}
        onAddObject={handleAddObject}
        onUpdateObject={handleUpdateObject}
        onDeleteObjects={handleDeleteObjects}
        onSelectObjects={setSelectedIds}
        onPointerTrack={handlePointerTrack}
        onAddPin={handleAddPin}
        onUpdatePin={handleUpdatePin}
        onDeletePin={handleDeletePin}
        onJumpToPin={handleJumpToPin}
        onSelectTool={handleToolChange}
        onCropImage={(obj) => setCroppingImage(obj)}
        isSelectingExportRange={isSelectingExportRange}
        onExportCustomRange={(bounds, format) => {
          if (format === 'svg') exportToSvgFile(objects, board, bounds);
          else if (format === 'pdf') exportToPdfFile(objects, board, bounds);
          else exportToPngFile(objects, board, bounds);
          setIsSelectingExportRange(false);
        }}
        onCancelExportRange={() => setIsSelectingExportRange(false)}
      />

      {/* Pin (圖釘) Navigation Manager */}
      <PinManager
        pins={board.pins || []}
        viewport={viewport}
        isOpen={isPinOpen}
        onClose={() => setIsPinOpen(false)}
        onAddPin={handleAddPin}
        onUpdatePin={handleUpdatePin}
        onDeletePin={handleDeletePin}
        onJumpToPin={handleJumpToPin}
      />

      {/* Layer Management Sidebar */}
      <LayerPanel
        objects={objects}
        selectedIds={selectedIds}
        isOpen={isLayerOpen}
        onClose={() => setIsLayerOpen(false)}
        onSelect={(id, multi) => {
          setSelectedIds((prev) => (multi ? [...prev, id] : [id]));
          handleToolChange('select');
        }}
        onUpdateObject={handleUpdateObject}
        onReorder={handleReorderLayer}
        onReorderBatch={handleReorderBatch}
        onDelete={(id) => handleDeleteObjects([id])}
      />

      {/* Bottom Floating Whiteboard Toolbar */}
      <Toolbar
        currentTool={currentTool}
        rulerEnabled={ruler.enabled}
        eraserMode={eraserMode}
        canUndo={historyIndex > 0}
        canRedo={historyIndex < history.length - 1}
        zoom={viewport.zoom}
        activeColor={activeColor}
        onChangeColor={handleChangeActiveColor}
        onSelectTool={handleToolChange}
        onToggleRuler={() => setRuler((prev) => ({ ...prev, enabled: !prev.enabled }))}
        onToggleEraserMode={() => setEraserMode((prev) => (prev === 'object' ? 'pixel' : 'object'))}
        onUploadImage={handleImageUpload}
        onOpenScreenCapture={() => setIsScreenCaptureOpen(true)}
        onClearCanvas={handleClearCanvas}
        onUndo={handleUndo}
        onRedo={handleRedo}
        onZoomIn={() =>
          setViewport((prev) => ({ ...prev, zoom: Math.min(5, prev.zoom * 1.2) }))
        }
        onZoomOut={() =>
          setViewport((prev) => ({ ...prev, zoom: Math.max(0.1, prev.zoom / 1.2) }))
        }
        onResetZoom={() => setViewport((prev) => ({ ...prev, zoom: 1 }))}
      />

      {/* Screen Snipping & Crop Modal */}
      <ScreenCaptureModal
        isOpen={isScreenCaptureOpen}
        onClose={() => setIsScreenCaptureOpen(false)}
        onCaptureComplete={createImageObjectFromDataUrl}
      />

      {/* Secondary Image Crop Modal (圖片二次裁切與重置) */}
      <ImageCropModal
        isOpen={!!croppingImage}
        imageObject={croppingImage}
        onClose={() => setCroppingImage(null)}
        onSaveCrop={handleSaveCrop}
        onResetOriginal={handleResetImageOriginal}
      />

      {/* Boards Switcher Modal */}
      <BoardModal
        isOpen={isBoardModalOpen}
        boards={allBoards}
        currentBoardId={board.id}
        onClose={() => setIsBoardModalOpen(false)}
        onSelectBoard={(id) => {
          const found = allBoards.find((b) => b.id === id);
          if (found) setBoard(found);
        }}
        onCreateBoard={handleCreateBoard}
        onDeleteBoard={handleDeleteBoard}
      />
    </div>
  );
}
