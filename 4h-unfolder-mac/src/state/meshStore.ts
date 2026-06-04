import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import type { Mesh } from '@/types/mesh';
import { tauriCommands } from '@/types/tauri';

interface MeshState {
  mesh:     Mesh | null;
  filePath: string | null;
  fileName: string | null;
  loading:  boolean;
  error:    string | null;

  loadFromPath:  (path: string) => Promise<void>;
  loadFromBytes: (bytes: Uint8Array, name: string) => Promise<void>;
  clearMesh:     () => void;
}

export const useMeshStore = create<MeshState>()(
  immer((set) => ({
    mesh:     null,
    filePath: null,
    fileName: null,
    loading:  false,
    error:    null,

    loadFromPath: async (path) => {
      set((s) => { s.loading = true; s.error = null; });
      try {
        const mesh = await tauriCommands.loadObj(path);
        set((s) => {
          s.mesh     = mesh;
          s.filePath = path;
          s.fileName = path.split('/').pop() ?? path;
          s.loading  = false;
        });
      } catch (err) {
        set((s) => { s.error = String(err); s.loading = false; });
      }
    },

    loadFromBytes: async (bytes, name) => {
      set((s) => { s.loading = true; s.error = null; });
      try {
        const mesh = await tauriCommands.loadObjFromBytes(Array.from(bytes));
        set((s) => {
          s.mesh     = mesh;
          s.filePath = null;
          s.fileName = name;
          s.loading  = false;
        });
      } catch (err) {
        set((s) => { s.error = String(err); s.loading = false; });
      }
    },

    clearMesh: () =>
      set((s) => {
        s.mesh     = null;
        s.filePath = null;
        s.fileName = null;
        s.error    = null;
      }),
  }))
);
