import { useCallback, useState } from 'react';
import { ChevronFirst, ChevronLast, ChevronLeft, ChevronRight, Play, Pause, X } from 'lucide-react';
import { useMeshStore } from '@/state/meshStore';
import { useUIStore } from '@/state/uiStore';
import { tauriCommands } from '@/types/tauri';
import type { AssemblyStep } from '@/types/tauri';

interface Props {
  onClose: () => void;
}

export function AssemblyPanel({ onClose }: Props) {
  const mesh            = useMeshStore((s) => s.mesh);
  const toggleFaceSelect = useUIStore((s) => s.toggleFaceSelect);
  const clearSelection  = useUIStore((s) => s.clearSelection);

  const [steps,    setSteps]    = useState<AssemblyStep[]>([]);
  const [current,  setCurrent]  = useState(0);
  const [loading,  setLoading]  = useState(false);
  const [playing,  setPlaying]  = useState(false);
  const [error,    setError]    = useState<string | null>(null);

  const loaded = steps.length > 0;

  const loadSteps = useCallback(async () => {
    if (!mesh) return;
    setLoading(true);
    setError(null);
    try {
      const s = await tauriCommands.getAssemblySteps(mesh);
      setSteps(s);
      setCurrent(0);
      highlightStep(s, 0, clearSelection, toggleFaceSelect);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, [mesh, clearSelection, toggleFaceSelect]);

  const goTo = (idx: number) => {
    const clamped = Math.max(0, Math.min(steps.length - 1, idx));
    setCurrent(clamped);
    highlightStep(steps, clamped, clearSelection, toggleFaceSelect);
  };

  // Auto-play: advance one step per 1.5 s
  const togglePlay = useCallback(() => {
    setPlaying((prev) => {
      if (prev) return false;
      const tick = setInterval(() => {
        setCurrent((c) => {
          const next = c + 1;
          if (next >= steps.length) {
            clearInterval(tick);
            setPlaying(false);
            return c;
          }
          highlightStep(steps, next, clearSelection, toggleFaceSelect);
          return next;
        });
      }, 1500);
      return true;
    });
  }, [steps, clearSelection, toggleFaceSelect]);

  const step = loaded ? steps[current] : null;

  return (
    <div className="flex flex-col h-full bg-sidebar border-l border-border text-sm">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-border">
        <h3 className="font-semibold text-xs uppercase tracking-wide text-muted-foreground">
          Assembly
        </h3>
        <button onClick={onClose} className="text-muted-foreground hover:text-foreground">
          <X size={14} />
        </button>
      </div>

      {!loaded ? (
        <div className="flex-1 flex flex-col items-center justify-center gap-3 p-4">
          <p className="text-xs text-muted-foreground text-center">
            Compute the assembly order to see step-by-step folding instructions.
          </p>
          {error && <p className="text-red-500 text-xs text-center">{error}</p>}
          <button
            onClick={loadSteps}
            disabled={loading || !mesh}
            className="px-4 py-2 bg-primary text-primary-foreground rounded text-xs hover:bg-primary/90 disabled:opacity-50"
          >
            {loading ? 'Computing…' : 'Compute Assembly'}
          </button>
        </div>
      ) : (
        <>
          {/* Step info */}
          <div className="p-3 border-b border-border space-y-1">
            <div className="flex justify-between text-xs">
              <span className="text-muted-foreground">Step</span>
              <span className="font-mono">{current + 1} / {steps.length}</span>
            </div>
            {step && (
              <>
                <div className="flex justify-between text-xs">
                  <span className="text-muted-foreground">Piece</span>
                  <span className="font-mono">#{step.groupId}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-muted-foreground">Faces</span>
                  <span className="font-mono">{step.faceIds.length}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-muted-foreground">Attaches to</span>
                  <span className="font-mono">
                    {step.parentGroupId >= 0 ? `Piece #${step.parentGroupId}` : 'Root'}
                  </span>
                </div>
              </>
            )}
          </div>

          {/* Step list */}
          <div className="flex-1 overflow-y-auto">
            {steps.map((s, i) => (
              <button
                key={s.stepIndex}
                className={`w-full text-left px-3 py-2 text-xs border-b border-border/50 hover:bg-muted/50 transition-colors ${
                  i === current ? 'bg-primary/10 text-primary' : ''
                }`}
                onClick={() => goTo(i)}
              >
                <span className="font-mono mr-2 text-muted-foreground">
                  {String(i + 1).padStart(2, '0')}
                </span>
                Piece #{s.groupId} — {s.faceIds.length} face{s.faceIds.length !== 1 ? 's' : ''}
                {s.parentGroupId < 0 && <span className="ml-1 text-muted-foreground">(root)</span>}
              </button>
            ))}
          </div>

          {/* Controls */}
          <div className="p-2 border-t border-border flex items-center justify-center gap-1">
            <CtrlBtn icon={<ChevronFirst size={14} />} onClick={() => goTo(0)}     title="First step" />
            <CtrlBtn icon={<ChevronLeft  size={14} />} onClick={() => goTo(current - 1)} title="Previous" />
            <CtrlBtn
              icon={playing ? <Pause size={14} /> : <Play size={14} />}
              onClick={togglePlay}
              title={playing ? 'Pause' : 'Play'}
              active={playing}
            />
            <CtrlBtn icon={<ChevronRight size={14} />} onClick={() => goTo(current + 1)} title="Next" />
            <CtrlBtn icon={<ChevronLast  size={14} />} onClick={() => goTo(steps.length - 1)} title="Last step" />
          </div>
        </>
      )}
    </div>
  );
}

function CtrlBtn({
  icon, onClick, title, active,
}: {
  icon: React.ReactNode;
  onClick: () => void;
  title: string;
  active?: boolean;
}) {
  return (
    <button
      title={title}
      onClick={onClick}
      className={`p-1.5 rounded hover:bg-muted transition-colors ${active ? 'bg-primary/20 text-primary' : 'text-muted-foreground hover:text-foreground'}`}
    >
      {icon}
    </button>
  );
}

function highlightStep(
  steps: AssemblyStep[],
  idx:   number,
  clear: () => void,
  toggle: (id: number) => void,
) {
  clear();
  // Highlight all faces up to and including the current step
  for (let i = 0; i <= idx; i++) {
    for (const fid of steps[i].faceIds) {
      toggle(fid);
    }
  }
}
