import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';

export type EditorMode =
  | 'select'
  | 'pan'
  | 'editFlaps'
  | 'editPieces';

export type PanelId = 'properties' | 'faceList' | 'settings' | null;

interface LassoState {
  active: boolean;
  points: number[];  // flat [x0,y0, x1,y1, ...]
}

interface UIState {
  mode:              EditorMode;
  activePanel:       PanelId;
  selectedFaceIds:   Set<number>;
  selectedEdgeIds:   Set<number>;
  /** Piece selected for rotation handle display */
  selectedPieceId:   number | null;
  hoveredFaceId:     number | null;
  hoveredEdgeId:     number | null;
  /** Edge being edited in the EditFlaps dialog */
  editingEdgeId:     number | null;
  lasso:             LassoState;
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

  setMode:             (mode: EditorMode) => void;
  setActivePanel:      (panel: PanelId) => void;
  toggleFaceSelect:    (faceId: number) => void;
  clearSelection:      () => void;
  setHoveredFace:      (id: number | null) => void;
  setHoveredEdge:      (id: number | null) => void;
  setSelectedPiece:    (id: number | null) => void;
  setEditingEdge:      (id: number | null) => void;
  setViewport:         (vp: Partial<UIState['viewport']>) => void;
  openDialog:          (d: keyof UIState['dialogs']) => void;
  closeDialog:         (d: keyof UIState['dialogs']) => void;
  startLasso:          (x: number, y: number) => void;
  extendLasso:         (x: number, y: number) => void;
  endLasso:            () => void;
}

export const useUIStore = create<UIState>()(
  immer((set) => ({
    mode:            'select',
    activePanel:     'properties',
    selectedFaceIds: new Set(),
    selectedEdgeIds: new Set(),
    selectedPieceId: null,
    hoveredFaceId:   null,
    hoveredEdgeId:   null,
    editingEdgeId:   null,
    lasso:           { active: false, points: [] },
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
        s.selectedPieceId = null;
      }),

    setHoveredFace:   (id) => set((s) => { s.hoveredFaceId = id; }),
    setHoveredEdge:   (id) => set((s) => { s.hoveredEdgeId = id; }),
    setSelectedPiece: (id) => set((s) => { s.selectedPieceId = id; }),
    setEditingEdge:   (id) => set((s) => { s.editingEdgeId = id; }),

    setViewport: (vp) =>
      set((s) => { Object.assign(s.viewport, vp); }),

    openDialog:  (d) => set((s) => { s.dialogs[d] = true; }),
    closeDialog: (d) => set((s) => { s.dialogs[d] = false; }),

    startLasso: (x, y) =>
      set((s) => { s.lasso = { active: true, points: [x, y] }; }),

    extendLasso: (x, y) =>
      set((s) => {
        if (s.lasso.active) s.lasso.points.push(x, y);
      }),

    endLasso: () =>
      set((s) => { s.lasso = { active: false, points: [] }; }),
  }))
);
