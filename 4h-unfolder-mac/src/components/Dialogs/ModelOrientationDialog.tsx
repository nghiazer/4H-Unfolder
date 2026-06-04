import { useState } from 'react';
import { X } from 'lucide-react';
import { useUIStore } from '@/state/uiStore';
import { useMeshStore } from '@/state/meshStore';
import { useUnfoldStore } from '@/state/unfoldStore';
import { tauriCommands } from '@/types/tauri';

export function ModelOrientationDialog() {
  const isOpen      = useUIStore((s) => s.dialogs.orient);
  const close       = useUIStore((s) => s.closeDialog);
  const mesh        = useMeshStore((s) => s.mesh);
  const unfold      = useUnfoldStore((s) => s.unfold);
  const clearResult = useUnfoldStore((s) => s.clearResult);

  const [mirrorX,   setMirrorX]   = useState(false);
  const [applying,  setApplying]  = useState(false);
  const [error,     setError]     = useState<string | null>(null);

  if (!isOpen || !mesh) return null;

  const handleApply = async () => {
    setApplying(true);
    setError(null);
    try {
      const transformed = await tauriCommands.transformMesh(mesh, 1.0, mirrorX);
      useMeshStore.setState((s) => ({ ...s, mesh: transformed }));
      clearResult();
      await unfold();
      close('orient');
    } catch (e) {
      setError(String(e));
    } finally {
      setApplying(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-background border border-border rounded-lg shadow-xl w-[320px]">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-4 pb-2 border-b border-border">
          <h2 className="font-semibold text-base">Model Orientation</h2>
          <button onClick={() => close('orient')} className="text-muted-foreground hover:text-foreground">
            <X size={18} />
          </button>
        </div>

        <div className="p-5 space-y-4 text-sm">
          <section>
            <p className="text-xs text-muted-foreground mb-2 font-semibold uppercase tracking-wide">
              Current bounds (mm)
            </p>
            <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs font-mono bg-muted rounded p-2">
              <span>Min X: {mesh.bounds.min[0].toFixed(2)}</span>
              <span>Max X: {mesh.bounds.max[0].toFixed(2)}</span>
              <span>Min Y: {mesh.bounds.min[1].toFixed(2)}</span>
              <span>Max Y: {mesh.bounds.max[1].toFixed(2)}</span>
              <span>Min Z: {mesh.bounds.min[2].toFixed(2)}</span>
              <span>Max Z: {mesh.bounds.max[2].toFixed(2)}</span>
            </div>
          </section>

          <section className="space-y-2">
            <p className="text-xs text-muted-foreground font-semibold uppercase tracking-wide">Transforms</p>
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={mirrorX}
                onChange={(e) => setMirrorX(e.target.checked)}
                className="rounded"
              />
              <span>Mirror X axis</span>
            </label>
            <p className="text-xs text-muted-foreground">
              Flips the model left-to-right. Face winding is automatically corrected.
            </p>
          </section>

          {error && <p className="text-red-500 text-xs">{error}</p>}
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-2 px-5 pb-4 pt-1 border-t border-border">
          <button
            onClick={() => close('orient')}
            className="px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground border border-border rounded"
          >
            Cancel
          </button>
          <button
            onClick={handleApply}
            disabled={applying || !mirrorX}
            className="px-4 py-1.5 bg-primary text-primary-foreground rounded text-sm hover:bg-primary/90 disabled:opacity-50"
          >
            {applying ? 'Applying…' : 'Apply & Re-unfold'}
          </button>
        </div>
      </div>
    </div>
  );
}
