import { useState } from 'react';
import { X } from 'lucide-react';
import { useUIStore } from '@/state/uiStore';
import { useMeshStore } from '@/state/meshStore';
import { useUnfoldStore } from '@/state/unfoldStore';
import { tauriCommands } from '@/types/tauri';

type Axis = 'Width' | 'Height' | 'Depth' | 'Longest';
type Unit = 'mm' | 'cm' | 'inch';

const UNIT_FACTOR: Record<Unit, number> = { mm: 1, cm: 10, inch: 25.4 };

function currentDim(bounds: { min: [number,number,number]; max: [number,number,number] }, axis: Axis): number {
  const dx = bounds.max[0] - bounds.min[0];
  const dy = bounds.max[1] - bounds.min[1];
  const dz = bounds.max[2] - bounds.min[2];
  switch (axis) {
    case 'Width':   return dx;
    case 'Height':  return dy;
    case 'Depth':   return dz;
    case 'Longest': return Math.max(dx, dy, dz);
  }
}

export function ScaleDialog() {
  const isOpen       = useUIStore((s) => s.dialogs.scale);
  const close        = useUIStore((s) => s.closeDialog);
  const mesh         = useMeshStore((s) => s.mesh);
  const unfold       = useUnfoldStore((s) => s.unfold);
  const clearResult  = useUnfoldStore((s) => s.clearResult);

  const [axis,       setAxis]       = useState<Axis>('Longest');
  const [unit,       setUnit]       = useState<Unit>('mm');
  const [targetStr,  setTargetStr]  = useState('100');
  const [applying,   setApplying]   = useState(false);
  const [error,      setError]      = useState<string | null>(null);

  if (!isOpen || !mesh) return null;

  const rawDim     = currentDim(mesh.bounds, axis);
  const unitFact   = UNIT_FACTOR[unit];
  const dimMm      = rawDim; // mesh vertices are in mm (OBJ units treated as mm)
  const dimDisplay = (dimMm / unitFact).toFixed(3);

  const targetMm = parseFloat(targetStr) * unitFact;
  const scaleFactor = isFinite(targetMm) && dimMm > 0 ? targetMm / dimMm : 1;

  const handleApply = async () => {
    if (!mesh) return;
    setApplying(true);
    setError(null);
    try {
      const scaled = await tauriCommands.transformMesh(mesh, scaleFactor, false);
      useMeshStore.setState((s) => ({ ...s, mesh: scaled }));
      clearResult();
      await unfold();
      close('scale');
    } catch (e) {
      setError(String(e));
    } finally {
      setApplying(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-background border border-border rounded-lg shadow-xl w-[360px]">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-4 pb-2 border-b border-border">
          <h2 className="font-semibold text-base">Scale Model</h2>
          <button onClick={() => close('scale')} className="text-muted-foreground hover:text-foreground">
            <X size={18} />
          </button>
        </div>

        <div className="p-5 space-y-4 text-sm">
          {/* Current dimensions */}
          <section>
            <p className="text-xs text-muted-foreground mb-2 font-semibold uppercase tracking-wide">Current dimensions (mm)</p>
            <div className="grid grid-cols-3 gap-2 text-xs font-mono bg-muted rounded p-2">
              <span>W: {(mesh.bounds.max[0] - mesh.bounds.min[0]).toFixed(2)}</span>
              <span>H: {(mesh.bounds.max[1] - mesh.bounds.min[1]).toFixed(2)}</span>
              <span>D: {(mesh.bounds.max[2] - mesh.bounds.min[2]).toFixed(2)}</span>
            </div>
          </section>

          {/* Axis + unit */}
          <div className="flex gap-3">
            <label className="flex flex-col gap-1 flex-1">
              <span className="text-muted-foreground text-xs">Axis</span>
              <select
                value={axis}
                onChange={(e) => setAxis(e.target.value as Axis)}
                className="input-field"
              >
                <option>Width</option>
                <option>Height</option>
                <option>Depth</option>
                <option>Longest</option>
              </select>
            </label>
            <label className="flex flex-col gap-1 flex-1">
              <span className="text-muted-foreground text-xs">Unit</span>
              <select
                value={unit}
                onChange={(e) => setUnit(e.target.value as Unit)}
                className="input-field"
              >
                <option value="mm">mm</option>
                <option value="cm">cm</option>
                <option value="inch">inch</option>
              </select>
            </label>
          </div>

          {/* Current size in unit */}
          <p className="text-muted-foreground text-xs">
            Current {axis}: <span className="font-mono text-foreground">{dimDisplay} {unit}</span>
          </p>

          {/* Target size */}
          <label className="flex flex-col gap-1">
            <span className="text-muted-foreground text-xs">Target size ({unit})</span>
            <input
              type="number"
              value={targetStr}
              min={0.1}
              step={0.1}
              onChange={(e) => setTargetStr(e.target.value)}
              className="input-field"
            />
          </label>

          <p className="text-muted-foreground text-xs">
            Scale factor: <span className="font-mono text-foreground">{scaleFactor.toFixed(4)}×</span>
          </p>

          {error && <p className="text-red-500 text-xs">{error}</p>}
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-2 px-5 pb-4 pt-1 border-t border-border">
          <button
            onClick={() => close('scale')}
            className="px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground border border-border rounded"
          >
            Cancel
          </button>
          <button
            onClick={handleApply}
            disabled={applying || !isFinite(scaleFactor) || scaleFactor <= 0}
            className="px-4 py-1.5 bg-primary text-primary-foreground rounded text-sm hover:bg-primary/90 disabled:opacity-50"
          >
            {applying ? 'Applying…' : 'Apply & Re-unfold'}
          </button>
        </div>
      </div>
    </div>
  );
}
