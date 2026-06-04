import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import type { AppSettings } from '@/types/settings';
import { DEFAULT_SETTINGS } from '@/types/settings';
import { tauriCommands } from '@/types/tauri';

interface SettingsState {
  settings: AppSettings;
  loaded:   boolean;

  loadSettings:   () => Promise<void>;
  saveSettings:   () => Promise<void>;
  updateSettings: (patch: Partial<AppSettings>) => void;
  resetToDefaults: () => void;
}

export const useSettingsStore = create<SettingsState>()(
  immer((set, get) => ({
    settings: DEFAULT_SETTINGS,
    loaded:   false,

    loadSettings: async () => {
      try {
        const s = await tauriCommands.loadSettings();
        set((st) => { st.settings = s; st.loaded = true; });
      } catch {
        // Fall back to defaults if settings file doesn't exist yet.
        set((st) => { st.loaded = true; });
      }
    },

    saveSettings: async () => {
      try {
        await tauriCommands.saveSettings(get().settings);
      } catch (err) {
        console.error('Failed to save settings:', err);
      }
    },

    updateSettings: (patch) =>
      set((st) => { Object.assign(st.settings, patch); }),

    resetToDefaults: () =>
      set((st) => { st.settings = DEFAULT_SETTINGS; }),
  }))
);
