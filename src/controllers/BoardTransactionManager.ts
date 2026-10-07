import { BoardObject, BoardMetadata, BoardPin } from '../types';

export type BoardCommand =
  | { type: 'insertObjects'; objects: BoardObject[] }
  | { type: 'removeObjects'; objects: BoardObject[] }
  | { type: 'modifyObjects'; before: BoardObject[]; after: BoardObject[] }
  | { type: 'reorderObjects'; before: BoardObject[]; after: BoardObject[] }
  | { type: 'updateCanvas'; before: BoardMetadata; after: BoardMetadata }
  | { type: 'updatePins'; before: BoardPin[]; after: BoardPin[] }
  | { type: 'clearCanvas'; clearedObjects: BoardObject[] }
  | { type: 'composite'; commands: BoardCommand[] };

export interface TransactionExecutionResult {
  objects: BoardObject[];
  board?: BoardMetadata;
}

export class BoardTransactionManager {
  private undoStack: BoardCommand[] = [];
  private redoStack: BoardCommand[] = [];
  private maxCapacity: number;

  constructor(maxCapacity: number = 50) {
    this.maxCapacity = Math.max(1, maxCapacity);
  }

  public canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  public canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  public getUndoStackDepth(): number {
    return this.undoStack.length;
  }

  public push(command: BoardCommand): void {
    this.undoStack.push(command);
    this.redoStack = [];
    if (this.undoStack.length > this.maxCapacity) {
      this.undoStack.splice(0, this.undoStack.length - this.maxCapacity);
    }
  }

  public undo(
    currentObjects: BoardObject[],
    currentBoard?: BoardMetadata
  ): TransactionExecutionResult | null {
    const command = this.undoStack.pop();
    if (!command) return null;

    this.redoStack.push(command);
    return this.executeUndoCommand(command, currentObjects, currentBoard);
  }

  public redo(
    currentObjects: BoardObject[],
    currentBoard?: BoardMetadata
  ): TransactionExecutionResult | null {
    const command = this.redoStack.pop();
    if (!command) return null;

    this.undoStack.push(command);
    return this.executeRedoCommand(command, currentObjects, currentBoard);
  }

  public clear(): void {
    this.undoStack = [];
    this.redoStack = [];
  }

  private executeUndoCommand(
    command: BoardCommand,
    objects: BoardObject[],
    board?: BoardMetadata
  ): TransactionExecutionResult {
    switch (command.type) {
      case 'insertObjects': {
        const removeIds = new Set(command.objects.map((o) => o.id));
        return {
          objects: objects.filter((o) => !removeIds.has(o.id)),
          board,
        };
      }
      case 'removeObjects': {
        return {
          objects: [...objects, ...command.objects],
          board,
        };
      }
      case 'modifyObjects': {
        const beforeMap = new Map(command.before.map((o) => [o.id, o]));
        return {
          objects: objects.map((o) => beforeMap.get(o.id) || o),
          board,
        };
      }
      case 'reorderObjects': {
        return {
          objects: [...command.before],
          board,
        };
      }
      case 'updateCanvas': {
        return {
          objects,
          board: { ...command.before },
        };
      }
      case 'updatePins': {
        return {
          objects,
          board: board ? { ...board, pins: command.before } : undefined,
        };
      }
      case 'clearCanvas': {
        return {
          objects: [...command.clearedObjects],
          board,
        };
      }
      case 'composite': {
        let currentObjs = [...objects];
        let currentBrd = board ? { ...board } : undefined;
        // Undo in reverse order
        for (let i = command.commands.length - 1; i >= 0; i--) {
          const res = this.executeUndoCommand(command.commands[i], currentObjs, currentBrd);
          currentObjs = res.objects;
          if (res.board) currentBrd = res.board;
        }
        return { objects: currentObjs, board: currentBrd };
      }
    }
  }

  private executeRedoCommand(
    command: BoardCommand,
    objects: BoardObject[],
    board?: BoardMetadata
  ): TransactionExecutionResult {
    switch (command.type) {
      case 'insertObjects': {
        return {
          objects: [...objects, ...command.objects],
          board,
        };
      }
      case 'removeObjects': {
        const removeIds = new Set(command.objects.map((o) => o.id));
        return {
          objects: objects.filter((o) => !removeIds.has(o.id)),
          board,
        };
      }
      case 'modifyObjects': {
        const afterMap = new Map(command.after.map((o) => [o.id, o]));
        return {
          objects: objects.map((o) => afterMap.get(o.id) || o),
          board,
        };
      }
      case 'reorderObjects': {
        return {
          objects: [...command.after],
          board,
        };
      }
      case 'updateCanvas': {
        return {
          objects,
          board: { ...command.after },
        };
      }
      case 'updatePins': {
        return {
          objects,
          board: board ? { ...board, pins: command.after } : undefined,
        };
      }
      case 'clearCanvas': {
        return {
          objects: [],
          board,
        };
      }
      case 'composite': {
        let currentObjs = [...objects];
        let currentBrd = board ? { ...board } : undefined;
        for (const subCmd of command.commands) {
          const res = this.executeRedoCommand(subCmd, currentObjs, currentBrd);
          currentObjs = res.objects;
          if (res.board) currentBrd = res.board;
        }
        return { objects: currentObjs, board: currentBrd };
      }
    }
  }
}
