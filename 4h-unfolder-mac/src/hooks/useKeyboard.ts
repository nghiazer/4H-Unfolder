import { useEffect } from 'react';
import { useUIStore } from '@/state/uiStore';
import { openMeshFileDialog } from '@/services/meshLoader';
import { exportSvgDialog } from '@/services/exportService';
import { useUnfoldStore } from '@/state/unfoldStore';

export function useGlobalKeyboard() {
  const clearSelection = useUIStore((s) => s.clearSelection);
  const openDialog     = useUIStore((s) => s.openDialog);
  const unfold         = useUnfoldStore((s) => s.unfold);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const meta = e.metaKey || e.ctrlKey;

      // ⌘O — open file
      if (meta && e.key === 'o') { e.preventDefault(); openMeshFileDialog(); }
      // ⌘S — export SVG
      if (meta && e.key === 's') { e.preventDefault(); exportSvgDialog(); }
      // ⌘, — settings
      if (meta && e.key === ',') { e.preventDefault(); openDialog('settings'); }
      // U — unfold
      if (!meta && e.key === 'u') { unfold(); }
      // Esc — clear selection
      if (e.key === 'Escape') { clearSelection(); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [clearSelection, openDialog, unfold]);
}
