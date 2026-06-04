import { save } from '@tauri-apps/plugin-dialog';
import { tauriCommands } from '@/types/tauri';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useSettingsStore } from '@/state/settingsStore';

export async function exportSvgDialog(): Promise<void> {
  const result = useUnfoldStore.getState().result;
  if (!result) return;

  const path = await save({
    filters: [{ name: 'SVG', extensions: ['svg'] }],
    defaultPath: 'pattern.svg',
  });
  if (!path) return;

  const settings = useSettingsStore.getState().settings;
  await tauriCommands.exportSvg(result, {
    outputPath:    path,
    showFoldLines: settings.showFoldLines,
    showLabels:    settings.showFaceLabels,
    dpi:           settings.exportDpi,
  });
}

export async function exportPdfDialog(): Promise<void> {
  const result = useUnfoldStore.getState().result;
  if (!result) return;

  const path = await save({
    filters: [{ name: 'PDF', extensions: ['pdf'] }],
    defaultPath: 'pattern.pdf',
  });
  if (!path) return;

  const settings = useSettingsStore.getState().settings;
  await tauriCommands.exportPdf(result, {
    outputPath:    path,
    showFoldLines: settings.showFoldLines,
    showLabels:    settings.showFaceLabels,
    dpi:           settings.exportDpi,
  });
}
