import { useEffect, useRef, useState } from 'react';
import { Toolbar } from '@/components/Toolbar/Toolbar';
import { PatternCanvas } from '@/components/Canvas/PatternCanvas';
import { PropertiesPanel } from '@/components/Sidebar/PropertiesPanel';
import { SettingsDialog } from '@/components/Dialogs/SettingsDialog';
import { useSettingsStore } from '@/state/settingsStore';
import { useGlobalKeyboard } from '@/hooks/useKeyboard';

export function AppLayout() {
  const loadSettings = useSettingsStore((s) => s.loadSettings);
  const canvasRef    = useRef<HTMLDivElement>(null);
  const [canvasSize, setCanvasSize] = useState({ width: 800, height: 600 });

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  useGlobalKeyboard();

  useEffect(() => {
    if (!canvasRef.current) return;
    const ro = new ResizeObserver((entries) => {
      const rect = entries[0].contentRect;
      setCanvasSize({ width: rect.width, height: rect.height });
    });
    ro.observe(canvasRef.current);
    return () => ro.disconnect();
  }, []);

  return (
    <div className="flex flex-col h-screen bg-background text-foreground font-sans overflow-hidden">
      <Toolbar />

      <div className="flex flex-1 overflow-hidden">
        {/* Main canvas */}
        <div ref={canvasRef} className="flex-1 overflow-hidden">
          <PatternCanvas width={canvasSize.width} height={canvasSize.height} />
        </div>

        {/* Right sidebar */}
        <aside className="w-56 border-l border-border bg-sidebar overflow-y-auto flex-shrink-0">
          <PropertiesPanel />
        </aside>
      </div>

      {/* Dialogs */}
      <SettingsDialog />
    </div>
  );
}
