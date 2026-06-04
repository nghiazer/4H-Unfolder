import { useEffect } from 'react';
import { useUIStore } from '@/state/uiStore';
import { openMeshFileDialog } from '@/services/meshLoader';
import { exportSvgDialog } from '@/services/exportService';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useHistoryStore } from '@/state/historyStore';

export function useGlobalKeyboard() {
  const clearSelection = useUIStore((s) => s.clearSelection);
  const openDialog     = useUIStore((s) => s.openDialog);
  const unfold         = useUnfoldStore((s) => s.unfold);
  const undo           = useHistoryStore((s) => s.undo);
  const redo           = useHistoryStore((s) => s.redo);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const meta = e.metaKey || e.ctrlKey;

      if (meta && e.key === 'o') { e.preventDefault(); openMeshFileDialog(); }
      if (meta && e.key === 's') { e.preventDefault(); exportSvgDialog(); }
      if (meta && e.key === ',') { e.preventDefault(); openDialog('settings'); }
      if (meta && e.shiftKey && e.key.toLowerCase() === 'z') { e.preventDefault(); redo(); }
      else if (meta && e.key === 'z') { e.preventDefault(); undo(); }
      if (!meta && e.key === 'u') { unfold(); }
      if (e.key === 'Escape') { clearSelection(); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [clearSelection, openDialog, unfold, undo, redo]);
}
