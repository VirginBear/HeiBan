import { useState, useRef, useEffect, useCallback } from 'react';
import { BoardMetadata, BoardObject } from '../types';
import { BoardSessionController, BoardSyncStatus } from '../controllers/BoardSessionController';
import { LocalPersistenceManager } from '../controllers/LocalPersistenceManager';

export function useBoardSession(
  initialBoard: BoardMetadata,
  onFlushWrite?: (boardId: string, objects: BoardObject[]) => void
) {
  const [board, setBoardState] = useState<BoardMetadata>(initialBoard);
  const [syncStatus, setSyncStatus] = useState<BoardSyncStatus>(
    initialBoard.source === 'local' ? 'local_only' : 'synced'
  );

  const sessionControllerRef = useRef<BoardSessionController>(
    new BoardSessionController(initialBoard)
  );
  const persistenceRef = useRef<LocalPersistenceManager>(new LocalPersistenceManager());

  useEffect(() => {
    if (onFlushWrite) {
      sessionControllerRef.current.setWriteHandler((bId, objs) => {
        onFlushWrite(bId, objs);
        setSyncStatus(sessionControllerRef.current.getSyncStatus());
      });
    }
  }, [onFlushWrite]);

  const queueObjectWrite = useCallback((obj: BoardObject) => {
    sessionControllerRef.current.queueObjectWrite(obj);
    setSyncStatus(sessionControllerRef.current.getSyncStatus());
  }, []);

  const flushWrites = useCallback(() => {
    sessionControllerRef.current.flushWrites();
    setSyncStatus(sessionControllerRef.current.getSyncStatus());
  }, []);

  const switchBoard = useCallback((nextBoard: BoardMetadata, flushCurrent = false) => {
    sessionControllerRef.current.switchBoard(nextBoard, flushCurrent);
    setBoardState(nextBoard);
    setSyncStatus(sessionControllerRef.current.getSyncStatus());
  }, []);

  const setBoard = useCallback((updater: BoardMetadata | ((prev: BoardMetadata) => BoardMetadata)) => {
    setBoardState((prev) => {
      const next = typeof updater === 'function' ? updater(prev) : updater;
      sessionControllerRef.current.switchBoard(next, false);
      return next;
    });
  }, []);

  return {
    board,
    setBoard,
    syncStatus,
    queueObjectWrite,
    flushWrites,
    switchBoard,
    persistence: persistenceRef.current,
    sessionController: sessionControllerRef.current,
  };
}
