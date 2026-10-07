import { BoardMetadata, BoardObject } from '../types';

export type BoardSyncStatus = 'local_only' | 'synced' | 'syncing' | 'error';

export type ObjectWriteHandler = (boardId: string, objects: BoardObject[]) => void;

export class BoardSessionController {
  private activeBoard: BoardMetadata;
  private syncStatus: BoardSyncStatus;
  private pendingWrites: Map<string, BoardObject> = new Map();
  private writeHandler: ObjectWriteHandler | null = null;

  constructor(initialBoard: BoardMetadata) {
    this.activeBoard = { ...initialBoard };
    this.syncStatus = initialBoard.source === 'local' ? 'local_only' : 'synced';
  }

  public getActiveBoard(): BoardMetadata {
    return { ...this.activeBoard };
  }

  public getActiveBoardId(): string {
    return this.activeBoard.id;
  }

  public getSyncStatus(): BoardSyncStatus {
    return this.syncStatus;
  }

  public setSyncStatus(status: BoardSyncStatus): void {
    this.syncStatus = status;
  }

  public setWriteHandler(handler: ObjectWriteHandler): void {
    this.writeHandler = handler;
  }

  public queueObjectWrite(object: BoardObject): void {
    this.pendingWrites.set(object.id, object);
    if (this.activeBoard.source === 'cloud') {
      this.syncStatus = 'syncing';
    }
  }

  public getPendingWritesCount(): number {
    return this.pendingWrites.size;
  }

  public flushWrites(): void {
    if (this.pendingWrites.size === 0) return;
    const objectsToFlush = Array.from(this.pendingWrites.values());
    this.pendingWrites.clear();

    if (this.writeHandler) {
      this.writeHandler(this.activeBoard.id, objectsToFlush);
    }

    if (this.activeBoard.source === 'cloud') {
      this.syncStatus = 'synced';
    }
  }

  public discardPendingWrites(): void {
    this.pendingWrites.clear();
    if (this.activeBoard.source === 'cloud') {
      this.syncStatus = 'synced';
    }
  }

  public switchBoard(nextBoard: BoardMetadata, flushCurrent: boolean = false): void {
    if (flushCurrent) {
      this.flushWrites();
    } else {
      this.discardPendingWrites();
    }
    this.activeBoard = { ...nextBoard };
    this.syncStatus = nextBoard.source === 'local' ? 'local_only' : 'synced';
  }
}
