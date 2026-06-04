import { save } from '@tauri-apps/plugin-dialog';
import { tauriCommands } from '@/types/tauri';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useSettingsStore } from '@/state/settingsStore';
import type { ExportOpts } from '@/types/tauri';

function buildExportOpts(outputPath: string): ExportOpts {
  const s = useSettingsStore.getState().settings;
  return {
    outputPath,
    showFoldLines:   s.showFoldLines    ?? true,
    showCutLines:    true,
    showBoundary:    true,
    showLabels:      s.showFaceLabels   ?? true,
    includeGlueTabs: s.showGlueTabs     ?? true,
    grayscaleOutput: false,
    includePageLabel: false,
    dpi:             s.exportDpi        ?? 96,
    foldLineColor:   s.foldLineColor    ?? '#4169e1',
    cutLineColor:    s.cutLineColor     ?? '#ff0000',
    foldLineWidth:   1,
    cutLineWidth:    1,
    foldLineDash:    '4,2',
    marginMm:        s.marginMm         ?? 5,
    scaleFactor:     1,
    pagesWide:       1,
    pagesTall:       1,
  };
}

export async function exportSvgDialog(): Promise<void> {
  const response = useUnfoldStore.getState().response;
  if (!response) return;

  const path = await save({
    filters: [{ name: 'SVG', extensions: ['svg'] }],
    defaultPath: 'pattern.svg',
  });
  if (!path) return;

  await tauriCommands.exportSvg(response, buildExportOpts(path));
}

export async function exportPdfDialog(): Promise<void> {
  const response = useUnfoldStore.getState().response;
  if (!response) return;

  const path = await save({
    filters: [{ name: 'PDF', extensions: ['pdf'] }],
    defaultPath: 'pattern.pdf',
  });
  if (!path) return;

  await tauriCommands.exportPdf(response, buildExportOpts(path));
}
