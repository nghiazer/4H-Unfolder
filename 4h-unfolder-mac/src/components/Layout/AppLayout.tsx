import { useCallback, useEffect, useRef, useState } from 'react';
import { Toolbar } from '@/components/Toolbar/Toolbar';
import { PatternCanvas } from '@/components/Canvas/PatternCanvas';
import { PropertiesPanel } from '@/components/Sidebar/PropertiesPanel';
import { SettingsDialog } from '@/components/Dialogs/SettingsDialog';
import { MeshViewer } from '@/components/Viewport3D/MeshViewer';
import { ScaleDialog } from '@/components/Dialogs/ScaleDialog';
import { ModelOrientationDialog } from '@/components/Dialogs/ModelOrientationDialog';
import { useSettingsStore } from '@/state/settingsStore';
import { useUIStore } from '@/state/uiStore';
import { useGlobalKeyboard } from '@/hooks/useKeyboard';

const MIN_PANE_PX = 180;

export function AppLayout() {
  const loadSettings     = useSettingsStore((s) => s.loadSettings);
  const showViewport3D   = useUIStore((s) => s.showViewport3D);

  const canvasRef   = useRef<HTMLDivElement>(null);
  const [canvasSize, setCanvasSize] = useState({ width: 800, height: 600 });

  // Split pane state: fraction of content width allocated to 3D viewport
  const [splitFraction, setSplitFraction] = useState(0.4);
  const dragging = useRef(false);
  const splitContainerRef = useRef<HTMLDivElement>(null);

  useEffect(() => { loadSettings(); }, [loadSettings]);
  useGlobalKeyboard();

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
      <Toolbar />

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

        {/* Right sidebar */}
        <aside className="w-56 border-l border-border bg-sidebar overflow-y-auto flex-shrink-0">
          <PropertiesPanel />
        </aside>
      </div>

      {/* Dialogs */}
      <SettingsDialog />
      <ScaleDialog />
      <ModelOrientationDialog />
    </div>
  );
}
