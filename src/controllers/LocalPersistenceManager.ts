import { BoardMetadata, BoardObject } from '../types';

export interface BoardSnapshotData {
  board: BoardMetadata;
  objects: BoardObject[];
  revision: number;
}

export class LocalPersistenceManager {
  private memoryStore = new Map<string, BoardSnapshotData>();
  private storageKeyPrefix = 'heiban_board_snapshot_';

  private isLocalStorageAvailable(): boolean {
    return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';
  }

  public saveBoardSnapshot(boardId: string, snapshot: BoardSnapshotData): boolean {
    const existing = this.loadBoardSnapshot(boardId);
    if (existing && existing.revision > snapshot.revision) {
      // Rejects stale revision overwrite to prevent data loss
      return false;
    }

    this.memoryStore.set(boardId, { ...snapshot });

    if (this.isLocalStorageAvailable()) {
      try {
        window.localStorage.setItem(
          `${this.storageKeyPrefix}${boardId}`,
          JSON.stringify(snapshot)
        );
      } catch (e) {
        console.warn('LocalStorage save failed, persisted in-memory fallback:', e);
      }
    }

    return true;
  }

  public loadBoardSnapshot(boardId: string): BoardSnapshotData | null {
    if (this.isLocalStorageAvailable()) {
      try {
        const raw = window.localStorage.getItem(`${this.storageKeyPrefix}${boardId}`);
        if (raw) {
          const parsed = JSON.parse(raw) as BoardSnapshotData;
          if (parsed && parsed.board && Array.isArray(parsed.objects)) {
            this.memoryStore.set(boardId, parsed);
            return parsed;
          }
        }
      } catch (e) {
        console.warn('LocalStorage load failed, attempting in-memory fallback:', e);
      }
    }

    return this.memoryStore.get(boardId) || null;
  }

  public deleteBoardSnapshot(boardId: string): boolean {
    this.memoryStore.delete(boardId);
    if (this.isLocalStorageAvailable()) {
      try {
        window.localStorage.removeItem(`${this.storageKeyPrefix}${boardId}`);
      } catch (e) {
        console.warn('LocalStorage delete failed:', e);
      }
    }
    return true;
  }
}
