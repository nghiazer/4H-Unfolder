import { useRef } from 'react';
import { Line, Rect } from 'react-konva';
import type { KonvaEventObject } from 'konva/lib/Node';
import type { UnfoldedFace, PieceLayout } from '@/types/unfold';
import { useUIStore } from '@/state/uiStore';

interface Props {
  /** All unfolded faces — used for centroid hit-test at lasso end. */
  faces:        UnfoldedFace[];
  /** Effective piece layouts (offset+rotation applied). */
  pieceLayouts: PieceLayout[];
  scale:        number;
  stageWidth:   number;
  stageHeight:  number;
}

/** Ray-cast point-in-polygon (even-odd rule). */
function pointInPolygon(px: number, py: number, poly: number[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 2; i < poly.length; j = i, i += 2) {
    const xi = poly[i], yi = poly[i + 1];
    const xj = poly[j], yj = poly[j + 1];
    const intersect =
      yi > py !== yj > py &&
      px < ((xj - xi) * (py - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

/** Compute the canvas-space centroid of a face given its piece layout. */
function faceCentroid(
  face: UnfoldedFace,
  layout: PieceLayout,
  scale: number,
): { x: number; y: number } {
  const cx = (face.v0.x + face.v1.x + face.v2.x) / 3;
  const cy = (face.v0.y + face.v1.y + face.v2.y) / 3;
  return {
    x: (cx + layout.offset.x) * scale,
    y: (cy + layout.offset.y) * scale,
  };
}

export function LassoOverlay({ faces, pieceLayouts, scale, stageWidth, stageHeight }: Props) {
  const mode        = useUIStore((s) => s.mode);
  const lasso       = useUIStore((s) => s.lasso);
  const startLasso  = useUIStore((s) => s.startLasso);
  const extendLasso = useUIStore((s) => s.extendLasso);
  const endLasso    = useUIStore((s) => s.endLasso);
  const toggleFace  = useUIStore((s) => s.toggleFaceSelect);
  const clearSel    = useUIStore((s) => s.clearSelection);

  const isDragging = useRef(false);

  if (mode !== 'select') return null;

  // Build a pieceId → layout map for fast lookup.
  const layoutMap = new Map(pieceLayouts.map((l) => [l.pieceId, l]));

  const onMouseDown = (e: KonvaEventObject<MouseEvent>) => {
    // Only start lasso on the transparent background rect (target === the rect itself).
    if (e.target !== e.currentTarget) return;
    isDragging.current = true;
    const pos = e.target.getStage()!.getPointerPosition()!;
    startLasso(pos.x, pos.y);
  };

  const onMouseMove = (e: KonvaEventObject<MouseEvent>) => {
    if (!isDragging.current) return;
    const pos = e.target.getStage()!.getPointerPosition()!;
    extendLasso(pos.x, pos.y);
  };

  const onMouseUp = (e: KonvaEventObject<MouseEvent>) => {
    if (!isDragging.current) return;
    isDragging.current = false;

    const poly = lasso.points;
    if (poly.length >= 6) {
      const multiKey = e.evt.metaKey || e.evt.ctrlKey;
      if (!multiKey) clearSel();

      for (const face of faces) {
        const layout = layoutMap.get(face.pieceId);
        if (!layout) continue;
        // For rotation we'd need to inverse-transform the centroid.
        // For Phase 3, rotation is not yet applied in centroid check (acceptable trade-off).
        const c = faceCentroid(face, layout, scale);
        if (pointInPolygon(c.x, c.y, poly)) {
          toggleFace(face.faceId);
        }
      }
    }

    endLasso();
  };

  return (
    <>
      {/* Full-canvas transparent capture rect — sits behind all pieces */}
      <Rect
        x={0}
        y={0}
        width={stageWidth}
        height={stageHeight}
        fill="transparent"
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        listening
      />

      {/* Lasso polygon line */}
      {lasso.active && lasso.points.length >= 4 && (
        <Line
          points={lasso.points}
          stroke="#3388ff"
          strokeWidth={1}
          dash={[4, 3]}
          fill="rgba(51,136,255,0.08)"
          closed
          listening={false}
        />
      )}
    </>
  );
}
