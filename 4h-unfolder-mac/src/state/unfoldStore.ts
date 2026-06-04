import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import type { UnfoldResponse, FlapOverride, UnfoldOptions, PieceLayout } from '@/types/unfold';
import { useMeshStore } from './meshStore';
import { useSettingsStore } from './settingsStore';
import { tauriCommands } from '@/types/tauri';

interface UnfoldState {
  response:       UnfoldResponse | null;
  /** edgeId → FlapOverride */
  flapOverrides:  Map<number, FlapOverride>;
  /** edgeId → 'Fold' | 'Cut' (user edge overrides) */
  edgeOverrides:  Map<number, 'Fold' | 'Cut'>;
  /** pieceId → user-edited layout (offset / rotation) */
  pieceLayouts:   Map<number, { offsetX: number; offsetY: number; rotation: number }>;
  unfolding:      boolean;
  error:          string | null;

  unfold:              () => Promise<void>;
  setFlapOverride:     (ov: FlapOverride & { edgeId: number }) => void;
  removeFlapOverride:  (edgeId: number) => void;
  setEdgeOverride:     (edgeId: number, type: 'Fold' | 'Cut') => void;
  clearEdgeOverride:   (edgeId: number) => void;
  setPieceOffset:      (pieceId: number, x: number, y: number) => void;
  setPieceRotation:    (pieceId: number, deg: number) => void;
  clearResult:         () => void;
  /** Effective piece layout merging backend result with user edits. */
  getEffectivePieceLayouts: () => PieceLayout[];
}

export const useUnfoldStore = create<UnfoldState>()(
  immer((set, get) => ({
    response:      null,
    flapOverrides: new Map(),
    edgeOverrides: new Map(),
    pieceLayouts:  new Map(),
    unfolding:     false,
    error:         null,

    unfold: async () => {
      const mesh     = useMeshStore.getState().mesh;
      const settings = useSettingsStore.getState().settings;
      if (!mesh) return;

      set((s) => { s.unfolding = true; s.error = null; });
      try {
        // Serialize overrides to string maps for the backend.
        const edgeOvStr: Record<string, string> = {};
        get().edgeOverrides.forEach((v, k) => { edgeOvStr[String(k)] = v; });

        const flapOvStr: Record<string, string> = {};
        get().flapOverrides.forEach((v, k) => {
          flapOvStr[String(k)] = `${v.mode},${v.primaryFaceId}`;
        });

        const options: UnfoldOptions = {
          tabWidthMm:    settings.tabWidthMm,
          tabAngleDeg:   settings.tabAngleDeg,
          sheetWidthMm:  settings.sheetWidthMm,
          sheetHeightMm: settings.sheetHeightMm,
          autoArrange:   settings.autoArrange,
          alternateFlaps: settings.alternateFlaps,
          tabShape:      settings.tabShape,
          edgeOverrides: edgeOvStr,
          flapOverrides: flapOvStr,
        };
        const response = await tauriCommands.unfoldMesh(mesh, options);
        set((s) => { s.response = response; s.unfolding = false; });
      } catch (err) {
        set((s) => { s.error = String(err); s.unfolding = false; });
      }
    },

    setFlapOverride: ({ edgeId, ...ov }) =>
      set((s) => { s.flapOverrides.set(edgeId, ov); }),

    removeFlapOverride: (edgeId) =>
      set((s) => { s.flapOverrides.delete(edgeId); }),

    setEdgeOverride: (edgeId, type) =>
      set((s) => { s.edgeOverrides.set(edgeId, type); }),

    clearEdgeOverride: (edgeId) =>
      set((s) => { s.edgeOverrides.delete(edgeId); }),

    setPieceOffset: (pieceId, x, y) =>
      set((s) => {
        const cur = s.pieceLayouts.get(pieceId) ?? { offsetX: 0, offsetY: 0, rotation: 0 };
        s.pieceLayouts.set(pieceId, { ...cur, offsetX: x, offsetY: y });
      }),

    setPieceRotation: (pieceId, deg) =>
      set((s) => {
        const cur = s.pieceLayouts.get(pieceId) ?? { offsetX: 0, offsetY: 0, rotation: 0 };
        s.pieceLayouts.set(pieceId, { ...cur, rotation: deg });
      }),

    clearResult: () =>
      set((s) => {
        s.response      = null;
        s.error         = null;
        s.pieceLayouts  = new Map();
      }),

    getEffectivePieceLayouts: () => {
      const { response, pieceLayouts } = get();
      if (!response) return [];
      return response.pieceLayouts.map((pl) => {
        const userEdit = pieceLayouts.get(pl.pieceId);
        if (!userEdit) return pl;
        return {
          ...pl,
          offset:   { x: userEdit.offsetX, y: userEdit.offsetY },
          rotation: userEdit.rotation,
        };
      });
    },
  }))
);
