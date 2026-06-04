import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';

export type EditorMode =
  | 'select'
  | 'pan'
  | 'editFlaps'
  | 'editPieces';

export type PanelId = 'properties' | 'faceList' | 'settings' | null;

interface UIState {
  mode:              EditorMode;
  activePanel:       PanelId;
  selectedFaceIds:   Set<number>;
  selectedEdgeIds:   Set<number>;
  hoveredFaceId:     number | null;
  hoveredEdgeId:     number | null;
  /** Canvas viewport: scale and translation. */
  viewport: {
    scale: number;
    tx:    number;
    ty:    number;
  };
  /** Open dialogs. */
  dialogs: {
    settings:  boolean;
    export:    boolean;
    editFlaps: boolean;
  };

  setMode:           (mode: EditorMode) => void;
  setActivePanel:    (panel: PanelId) => void;
  toggleFaceSelect:  (faceId: number) => void;
  clearSelection:    () => void;
  setHoveredFace:    (id: number | null) => void;
  setHoveredEdge:    (id: number | null) => void;
  setViewport:       (vp: Partial<UIState['viewport']>) => void;
  openDialog:        (d: keyof UIState['dialogs']) => void;
  closeDialog:       (d: keyof UIState['dialogs']) => void;
}

export const useUIStore = create<UIState>()(
  immer((set) => ({
    mode:            'select',
    activePanel:     'properties',
    selectedFaceIds: new Set(),
    selectedEdgeIds: new Set(),
    hoveredFaceId:   null,
    hoveredEdgeId:   null,
    viewport:  { scale: 1, tx: 0, ty: 0 },
    dialogs:   { settings: false, export: false, editFlaps: false },

    setMode: (mode) => set((s) => { s.mode = mode; }),

    setActivePanel: (panel) => set((s) => { s.activePanel = panel; }),

    toggleFaceSelect: (faceId) =>
      set((s) => {
        if (s.selectedFaceIds.has(faceId)) {
          s.selectedFaceIds.delete(faceId);
        } else {
          s.selectedFaceIds.add(faceId);
        }
      }),

    clearSelection: () =>
      set((s) => {
        s.selectedFaceIds = new Set();
        s.selectedEdgeIds = new Set();
      }),

    setHoveredFace: (id) => set((s) => { s.hoveredFaceId = id; }),
    setHoveredEdge: (id) => set((s) => { s.hoveredEdgeId = id; }),

    setViewport: (vp) =>
      set((s) => { Object.assign(s.viewport, vp); }),

    openDialog:  (d) => set((s) => { s.dialogs[d] = true; }),
    closeDialog: (d) => set((s) => { s.dialogs[d] = false; }),
  }))
);
