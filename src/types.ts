export type ToolType =
  | 'select'
  | 'pen'
  | 'highlighter'
  | 'paint'
  | 'eraser'
  | 'ruler'
  | 'rect'
  | 'circle'
  | 'triangle'
  | 'diamond'
  | 'arrow'
  | 'line'
  | 'star'
  | 'text'
  | 'sticky'
  | 'image'
  | 'pin'
  | 'laser';

export type EraserMode = 'object' | 'pixel';

export type BoardTheme = 'blackboard' | 'dark' | 'whiteboard' | 'slate';
export type GridStyle = 'grid' | 'dots' | 'lines' | 'blank';
export type CanvasMode = 'fixed' | 'infinite' | 'notebook';
export type CanvasPreset =
  | 'infinite'
  | 'a4_landscape'
  | 'a4_portrait'
  | 'a3_landscape'
  | '16_9'
  | '4_3'
  | '1_1'
  | '9_16'
  | 'notebook'
  | 'custom';
export type StickyStyle = 'classic' | 'washi' | 'cat' | 'notebook' | 'grid' | 'soft';
export type LineExtension = 'none' | 'start' | 'end' | 'both';

export interface BoardPage {
  id: string;
  title: string;
  index: number;
  createdAt: string;
  updatedAt: string;
}

export interface Point {
  x: number;
  y: number;
  pressure?: number;
}

export interface TextSpan {
  text: string;
  isBold?: boolean;
  isItalic?: boolean;
  isUnderline?: boolean;
  isStrikethrough?: boolean;
  color?: string;
  highlightColor?: string;
}

export interface BoardObject {
  id: string;
  boardId: string;
  type:
    | 'stroke'
    | 'highlighter'
    | 'paint'
    | 'rect'
    | 'circle'
    | 'triangle'
    | 'diamond'
    | 'arrow'
    | 'line'
    | 'star'
    | 'text'
    | 'sticky'
    | 'image'
    | 'pin';
  x: number;
  y: number;
  width: number;
  height: number;
  // Specific Point A and Point B for Lines & Arrows
  x1?: number;
  y1?: number;
  x2?: number;
  y2?: number;
  extension?: LineExtension;
  points?: string;
  strokeColor: string;
  fillColor: string;
  strokeWidth: number;
  lineStyle?: 'solid' | 'dashed';
  opacity: number;
  rotation: number;
  zIndex: number;
  text?: string;
  fontSize?: number;
  fontFamily?: string;
  stickyStyle?: StickyStyle;
  isBold?: boolean;
  isItalic?: boolean;
  isUnderline?: boolean;
  isStrikethrough?: boolean;
  highlightColor?: string;
  align?: 'left' | 'center' | 'right';
  richTextSpans?: TextSpan[];
  imageUrl?: string;
  originalImageUrl?: string;
  originalWidth?: number;
  originalHeight?: number;
  cropX?: number;
  cropY?: number;
  cropWidth?: number;
  cropHeight?: number;
  isLocked?: boolean;
  isVisible?: boolean;
  name?: string;
  groupId?: string;
  createdBy: string;
  creatorName?: string;
  pageId?: string;
  updatedAt: string;
  [key: string]: unknown;
}

export interface BoardPin {
  id: string;
  name: string;
  x: number;
  y: number;
  zoom: number;
  createdAt: string;
}

export interface UserPresence {
  boardId: string;
  userId: string;
  displayName: string;
  photoURL?: string;
  cursorX: number;
  cursorY: number;
  color: string;
  isDrawing?: boolean;
  currentTool?: string;
  updatedAt: string;
}

export interface BoardMetadata {
  id: string;
  title: string;
  ownerId: string;
  ownerName: string;
  ownerPhoto?: string;
  backgroundColor: string;
  gridStyle: GridStyle;
  boardTheme: BoardTheme;
  canvasMode?: CanvasMode;
  canvasPreset?: CanvasPreset;
  canvasWidth?: number;
  canvasHeight?: number;
  pins?: BoardPin[];
  thumbnail?: string;
  itemCount?: number;
  revision?: number;
  pages?: BoardPage[];
  activePageId?: string;
  createdAt: string;
  updatedAt: string;
  [key: string]: unknown;
}

export interface HeiBanDocument {
  schemaVersion?: string;
  version: string;
  board: BoardMetadata;
  objects: BoardObject[];
  exportedAt: string;
  [key: string]: unknown;
}

export interface ViewportTransform {
  x: number;
  y: number;
  zoom: number;
}

export interface RulerState {
  enabled: boolean;
  screenCenterX: number;
  screenCenterY: number;
  angle: number;
  width: number;
  height: number;
  pivotRatio: number;
  pivotEdge: 'top' | 'center' | 'bottom';
  opacity: number;
}
