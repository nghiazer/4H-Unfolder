import { useCallback, useEffect, useRef, useState } from 'react';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { Toolbar } from '@/components/Toolbar/Toolbar';
import { PatternCanvas } from '@/components/Canvas/PatternCanvas';
import { PropertiesPanel } from '@/components/Sidebar/PropertiesPanel';
import { SettingsDialog } from '@/components/Dialogs/SettingsDialog';
import { MeshViewer } from '@/components/Viewport3D/MeshViewer';
import { ScaleDialog } from '@/components/Dialogs/ScaleDialog';
import { EditFlapsDialog } from '@/components/Dialogs/EditFlapsDialog';
import { ModelOrientationDialog } from '@/components/Dialogs/ModelOrientationDialog';
import { AssemblyPanel } from '@/components/Assembly/AssemblyPanel';
import { useSettingsStore } from '@/state/settingsStore';
import { useUIStore } from '@/state/uiStore';
import { useMeshStore } from '@/state/meshStore';
import { handleDroppedFile } from '@/services/meshLoader';
import { useGlobalKeyboard } from '@/hooks/useKeyboard';

const MIN_PANE_PX = 180;

export function AppLayout() {
  const loadSettings     = useSettingsStore((s) => s.loadSettings);
  const showViewport3D   = useUIStore((s) => s.showViewport3D);
  const meshError        = useMeshStore((s) => s.error);
  const [showAssembly, setShowAssembly] = useState(false);

  const canvasRef   = useRef<HTMLDivElement>(null);
  const [canvasSize, setCanvasSize] = useState({ width: 800, height: 600 });

  // Split pane state: fraction of content width allocated to 3D viewport
  const [splitFraction, setSplitFraction] = useState(0.4);
  const dragging = useRef(false);
  const splitContainerRef = useRef<HTMLDivElement>(null);

  useEffect(() => { loadSettings(); }, [loadSettings]);
  useGlobalKeyboard();

  // Tauri file drag-drop listener — provides full filesystem paths unlike browser DragEvent
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    getCurrentWebviewWindow()
      .onDragDropEvent((event) => {
        if (event.payload.type === 'drop') {
          for (const path of event.payload.paths) {
            handleDroppedFile(path);
          }
        }
      })
      .then((fn) => { unlisten = fn; });
    return () => { unlisten?.(); };
  }, []);

  // Observe the canvas container for size changes
  useEffect(() => {
    if (!canvasRef.current) return;
    const ro = new ResizeObserver((entries) => {
      const rect = entries[0].contentRect;
      setCanvasSize({ width: rect.width, height: rect.height });
    });
    ro.observe(canvasRef.current);
    return () => ro.disconnect();
  }, []);

  // Drag handle handlers
  const onDragHandleMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    dragging.current = true;
  }, []);

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      if (!dragging.current || !splitContainerRef.current) return;
      const rect = splitContainerRef.current.getBoundingClientRect();
      const raw  = (e.clientX - rect.left) / rect.width;
      const clamped = Math.max(
        MIN_PANE_PX / rect.width,
        Math.min(1 - MIN_PANE_PX / rect.width, raw),
      );
      setSplitFraction(clamped);
    };
    const onUp = () => { dragging.current = false; };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup',   onUp);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup',   onUp);
    };
  }, []);

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-sans overflow-hidden">
      <Toolbar showAssembly={showAssembly} onToggleAssembly={() => setShowAssembly((v) => !v)} />

      {meshError && (
        <div className="flex items-center gap-2 px-3 py-2 bg-destructive/10 border-b border-destructive/30 text-destructive text-sm">
          <span className="flex-1 truncate">{meshError}</span>
          <button
            className="shrink-0 opacity-60 hover:opacity-100 text-xs font-bold"
            onClick={() => useMeshStore.setState((s) => ({ ...s, error: null }))}
          >
            ✕
          </button>
        </div>
      )}

      <div ref={splitContainerRef} className="flex flex-1 overflow-hidden">
        {/* 3D Viewport — conditionally visible */}
        {showViewport3D && (
          <>
            <div
              style={{ width: `${splitFraction * 100}%` }}
              className="flex-shrink-0 overflow-hidden"
            >
              <MeshViewer />
            </div>

            {/* Drag handle */}
            <div
              className="w-1.5 cursor-col-resize bg-border hover:bg-accent flex-shrink-0 select-none"
              onMouseDown={onDragHandleMouseDown}
            />
          </>
        )}

        {/* 2D Pattern Canvas */}
        <div ref={canvasRef} className="flex-1 overflow-hidden min-w-0">
          <PatternCanvas width={canvasSize.width} height={canvasSize.height} />
        </div>

        {/* Right sidebar — Properties or Assembly */}
        <aside className="w-56 border-l border-border bg-sidebar overflow-y-auto flex-shrink-0 flex flex-col">
          {showAssembly ? (
            <AssemblyPanel onClose={() => setShowAssembly(false)} />
          ) : (
            <PropertiesPanel />
          )}
        </aside>
      </div>

      {/* Dialogs */}
      <SettingsDialog />
      <ScaleDialog />
      <ModelOrientationDialog />
      <EditFlapsDialog />
    </div>
  );
}
