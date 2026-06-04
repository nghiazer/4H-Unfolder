import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import type { FlapOverride } from '@/types/unfold';
import { useUnfoldStore } from './unfoldStore';

interface Snapshot {
  edgeOverrides: Map<number, 'Fold' | 'Cut'>;
  flapOverrides: Map<number, FlapOverride>;
  pieceLayouts:  Map<number, { offsetX: number; offsetY: number; rotation: number }>;
}

interface HistoryState {
  undoStack: Snapshot[];
  redoStack: Snapshot[];

  /** Call BEFORE making any change so it can be undone. */
  pushSnapshot: () => void;
  undo: () => void;
  redo: () => void;
  /** Wipe history (e.g. after loading a new mesh). */
  clear: () => void;
}

const MAX_HISTORY = 50;

function snapshot(): Snapshot {
  const uf = useUnfoldStore.getState();
  return {
    edgeOverrides: new Map(uf.edgeOverrides),
    flapOverrides: new Map(uf.flapOverrides),
    pieceLayouts:  new Map(uf.pieceLayouts),
  };
}

function restore(snap: Snapshot) {
  useUnfoldStore.setState((us) => ({
    ...us,
    edgeOverrides: new Map(snap.edgeOverrides),
    flapOverrides: new Map(snap.flapOverrides),
    pieceLayouts:  new Map(snap.pieceLayouts),
  }));
  useUnfoldStore.getState().unfold();
}

export const useHistoryStore = create<HistoryState>()(
  immer((set) => ({
    undoStack: [],
    redoStack: [],

    pushSnapshot: () => {
      const snap = snapshot();
      set((s) => {
        s.undoStack.push(snap);
        if (s.undoStack.length > MAX_HISTORY) s.undoStack.shift();
        s.redoStack = [];
      });
    },

    undo: () => {
      set((s) => {
        const snap = s.undoStack.pop();
        if (!snap) return;
        s.redoStack.push(snapshot());
        restore(snap);
      });
    },

    redo: () => {
      set((s) => {
        const snap = s.redoStack.pop();
        if (!snap) return;
        s.undoStack.push(snapshot());
        restore(snap);
      });
    },

    clear: () => set((s) => { s.undoStack = []; s.redoStack = []; }),
  }))
);
