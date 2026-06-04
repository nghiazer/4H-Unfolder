import { useMeshStore } from '@/state/meshStore';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useUIStore } from '@/state/uiStore';

export function PropertiesPanel() {
  const mesh       = useMeshStore((s) => s.mesh);
  const fileName   = useMeshStore((s) => s.fileName);
  const result     = useUnfoldStore((s) => s.response);
  const selected   = useUIStore((s) => s.selectedFaceIds);

  return (
    <div className="p-3 text-sm space-y-4">
      <section>
        <h3 className="font-semibold text-xs uppercase tracking-wide text-muted-foreground mb-2">
          Mesh
        </h3>
        {mesh ? (
          <dl className="space-y-1">
            <Row label="File"     value={fileName ?? '—'} />
            <Row label="Vertices" value={mesh.vertices.length} />
            <Row label="Faces"    value={mesh.faces.length} />
            <Row label="Edges"    value={mesh.edges.length} />
          </dl>
        ) : (
          <p className="text-muted-foreground">No mesh loaded.</p>
        )}
      </section>

      {result && (
        <section>
          <h3 className="font-semibold text-xs uppercase tracking-wide text-muted-foreground mb-2">
            Unfold Result
          </h3>
          <dl className="space-y-1">
            <Row label="Pieces"     value={result.pieceLayouts.length} />
            <Row label="Sheet"      value={`${result.sheetWidthMm} × ${result.sheetHeightMm} mm`} />
          </dl>
        </section>
      )}

      {selected.size > 0 && (
        <section>
          <h3 className="font-semibold text-xs uppercase tracking-wide text-muted-foreground mb-2">
            Selection
          </h3>
          <p>{selected.size} face{selected.size !== 1 ? 's' : ''} selected</p>
        </section>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="flex justify-between gap-2">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="font-mono text-right truncate max-w-[120px]">{value}</dd>
    </div>
  );
}
