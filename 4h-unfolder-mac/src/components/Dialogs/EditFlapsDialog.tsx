import { useEffect, useState } from 'react';
import { X } from 'lucide-react';
import { useUIStore } from '@/state/uiStore';
import { useMeshStore } from '@/state/meshStore';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useHistoryStore } from '@/state/historyStore';
import { useSettingsStore } from '@/state/settingsStore';
import type { FlapMode } from '@/types/unfold';

// ---------------------------------------------------------------------------
// Mode option lists
// ---------------------------------------------------------------------------

const INTERIOR_MODES: { value: FlapMode; label: string; desc: string }[] = [
  { value: 'default',        label: 'Default',          desc: 'Use global alternate-flaps setting' },
  { value: 'switchPosition', label: 'Switch Side',       desc: 'Move tab to the other face' },
  { value: 'onOnThisSide',   label: 'This Face Only',    desc: 'Tab only on the face you clicked' },
  { value: 'offOnOtherSide', label: 'Other Face Only',   desc: 'Tab only on the adjacent face' },
  { value: 'offOffNoFlap',   label: 'No Tab',            desc: 'Remove tab from this edge entirely' },
  { value: 'onOnBothSides',  label: 'Both Sides',        desc: 'Tab on both adjacent faces' },
];

const BORDER_MODES: { value: FlapMode; label: string; desc: string }[] = [
  { value: 'default',           label: 'Default',       desc: 'No tab (boundary default)' },
  { value: 'borderMountainFold',label: 'Mountain Fold',  desc: 'Add tab with mountain fold line' },
  { value: 'borderValleyFold',  label: 'Valley Fold',    desc: 'Add tab with valley fold line' },
  { value: 'borderNoFold',      label: 'Tab (no fold)',  desc: 'Add tab without a fold line' },
  { value: 'borderNoFlap',      label: 'No Tab',         desc: 'Explicitly remove tab' },
];

// ---------------------------------------------------------------------------
// Tab shape preview (SVG)
// ---------------------------------------------------------------------------

function TabPreview({
  depth,
  angle,
  shape,
}: {
  depth:  number;
  angle:  number;
  shape:  string;
}) {
  const w   = 80;
  const h   = 40;
  const dep = Math.min(depth * 3, h - 4); // scale depth to preview
  const inset = dep / Math.tan((Math.min(angle, 89) * Math.PI) / 180);
  const ci  = Math.min(inset, w * 0.4);

  let points = '';
  if (shape === 'Trapezoid') {
    points = `0,${h} ${w},${h} ${w - ci},${h - dep} ${ci},${h - dep}`;
  } else if (shape === 'Rectangle') {
    points = `0,${h} ${w},${h} ${w},${h - dep} 0,${h - dep}`;
  } else {
    // Triangle
    points = `0,${h} ${w},${h} ${w / 2},${h - dep}`;
  }

  return (
    <svg width={w} height={h} className="border border-border rounded bg-muted">
      {/* Edge line */}
      <line x1={0} y1={h} x2={w} y2={h} stroke="#ff2222" strokeWidth={1.5} />
      {/* Tab fill */}
      <polygon points={points} fill="rgba(80,200,80,0.4)" stroke="#2e7d32" strokeWidth={1} />
    </svg>
  );
}

// ---------------------------------------------------------------------------
// Main dialog
// ---------------------------------------------------------------------------

export function EditFlapsDialog() {
  const isOpen        = useUIStore((s) => s.dialogs.editFlaps);
  const close         = useUIStore((s) => s.closeDialog);
  const edgeId        = useUIStore((s) => s.editingEdgeId);
  const faceId        = useUIStore((s) => s.editingFaceId);

  const mesh          = useMeshStore((s) => s.mesh);
  const settings      = useSettingsStore((s) => s.settings);
  const flapOverrides = useUnfoldStore((s) => s.flapOverrides);
  const setFlap       = useUnfoldStore((s) => s.setFlapOverride);
  const removeFlap    = useUnfoldStore((s) => s.removeFlapOverride);
  const unfold        = useUnfoldStore((s) => s.unfold);
  const push          = useHistoryStore((s) => s.pushSnapshot);

  const [tab,  setTab]  = useState<'shape' | 'position'>('position');
  const [mode, setMode] = useState<FlapMode>('default');

  // Determine if boundary edge
  const edge       = edgeId !== null ? mesh?.edges[edgeId] : null;
  const isBoundary = edge ? edge.faceB === null || edge.faceB === undefined : false;
  const modes      = isBoundary ? BORDER_MODES : INTERIOR_MODES;

  // Sync mode to existing override when dialog opens or edge changes
  useEffect(() => {
    if (!isOpen || edgeId === null) return;
    const existing = flapOverrides.get(edgeId);
    setMode(existing?.mode ?? 'default');
  }, [isOpen, edgeId, flapOverrides]);

  if (!isOpen || edgeId === null) return null;

  const handleApply = () => {
    push();
    if (mode === 'default') {
      removeFlap(edgeId);
    } else {
      setFlap({ edgeId, mode, primaryFaceId: faceId ?? -1 });
    }
    unfold();
    close('editFlaps');
  };

  const handleClear = () => {
    push();
    removeFlap(edgeId);
    unfold();
    close('editFlaps');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-background border border-border rounded-lg shadow-xl w-[380px] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-4 pb-2 border-b border-border">
          <div>
            <h2 className="font-semibold text-base">Edit Flaps</h2>
            <p className="text-xs text-muted-foreground">
              Edge #{edgeId} — {isBoundary ? 'Boundary' : 'Interior'} edge
            </p>
          </div>
          <button onClick={() => close('editFlaps')} className="text-muted-foreground hover:text-foreground">
            <X size={18} />
          </button>
        </div>

        {/* Tab bar */}
        <div className="flex border-b border-border">
          {(['position', 'shape'] as const).map((t) => (
            <button
              key={t}
              className={`px-4 py-2 text-sm capitalize transition-colors ${
                tab === t
                  ? 'border-b-2 border-primary text-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
              onClick={() => setTab(t)}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="p-5 text-sm overflow-y-auto max-h-[50vh]">
          {tab === 'position' ? (
            <div className="space-y-2">
              <p className="text-xs text-muted-foreground font-semibold uppercase tracking-wide mb-3">
                {isBoundary ? 'Border edge mode' : 'Interior edge mode'}
              </p>
              {modes.map(({ value, label, desc }) => (
                <label
                  key={value}
                  className={`flex items-start gap-3 p-2.5 rounded cursor-pointer border transition-colors ${
                    mode === value
                      ? 'border-primary bg-primary/5'
                      : 'border-border hover:border-border/80 hover:bg-muted/50'
                  }`}
                >
                  <input
                    type="radio"
                    name="flapMode"
                    value={value}
                    checked={mode === value}
                    onChange={() => setMode(value)}
                    className="mt-0.5 shrink-0"
                  />
                  <div>
                    <p className="font-medium leading-tight">{label}</p>
                    <p className="text-muted-foreground text-xs mt-0.5">{desc}</p>
                  </div>
                </label>
              ))}

              {/* Show primary face info for directional modes */}
              {(mode === 'onOnThisSide' || mode === 'offOnOtherSide') && (
                <p className="text-xs text-muted-foreground mt-2 p-2 bg-muted rounded">
                  Using face #{faceId ?? '?'} as &quot;this side&quot;
                  (the face you clicked when opening this dialog).
                </p>
              )}
            </div>
          ) : (
            <div className="space-y-4">
              <p className="text-xs text-muted-foreground font-semibold uppercase tracking-wide">
                Current tab shape
              </p>
              <div className="flex justify-center">
                <TabPreview
                  depth={settings.tabWidthMm}
                  angle={settings.tabAngleDeg}
                  shape={settings.tabShape}
                />
              </div>
              <dl className="space-y-2 text-xs">
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Shape</dt>
                  <dd className="font-mono">{settings.tabShape}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Depth</dt>
                  <dd className="font-mono">{settings.tabWidthMm} mm</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Side angle</dt>
                  <dd className="font-mono">{settings.tabAngleDeg}°</dd>
                </div>
              </dl>
              <p className="text-xs text-muted-foreground">
                Per-edge shape overrides (depth, angle) can be set in Settings → Print.
              </p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex justify-between gap-2 px-5 pb-4 pt-3 border-t border-border">
          <button
            onClick={handleClear}
            className="px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground border border-border rounded"
          >
            Clear override
          </button>
          <div className="flex gap-2">
            <button
              onClick={() => close('editFlaps')}
              className="px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground border border-border rounded"
            >
              Cancel
            </button>
            <button
              onClick={handleApply}
              className="px-4 py-1.5 bg-primary text-primary-foreground rounded text-sm hover:bg-primary/90"
            >
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
