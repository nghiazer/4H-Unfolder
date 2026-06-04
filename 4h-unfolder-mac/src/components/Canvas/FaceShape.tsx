import { Group, Line, Text } from 'react-konva';
import type { KonvaEventObject } from 'konva/lib/Node';
import type { UnfoldedFace } from '@/types/unfold';
import { useUIStore } from '@/state/uiStore';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useHistoryStore } from '@/state/historyStore';
import { useMultiSelectKey } from '@/hooks/useCanvas';

interface Props {
  face:  UnfoldedFace;
  scale: number;
  /** cut-edge pair labels from unfoldResult.cutEdgePairIds */
  cutPairIds?: Record<number, number>;
}

const FILL_DEFAULT  = '#f5f0e8';
const FILL_SELECTED = '#bfd7ff';
const FILL_HOVER    = '#e8f4ff';

const STROKE_FOLD     = '#3388ff';
const STROKE_CUT      = '#ff2222';
const STROKE_BOUNDARY = '#505050';
const DASH_FOLD: [number, number] = [4, 2];

export function FaceShape({ face, scale, cutPairIds }: Props) {
  const isSelected   = useUIStore((s) => s.selectedFaceIds.has(face.faceId));
  const isHovered    = useUIStore((s) => s.hoveredFaceId === face.faceId);
  const mode         = useUIStore((s) => s.mode);
  const toggle       = useUIStore((s) => s.toggleFaceSelect);
  const setHovered   = useUIStore((s) => s.setHoveredFace);
  const setEditEdge  = useUIStore((s) => s.setEditingEdge);
  const hoveredEdge  = useUIStore((s) => s.hoveredEdgeId);
  const multiKey     = useMultiSelectKey();

  const setEdgeOverride  = useUnfoldStore((s) => s.setEdgeOverride);
  const clearEdgeOverride = useUnfoldStore((s) => s.clearEdgeOverride);
  const getEdgeOverride   = useUnfoldStore((s) => s.getEdgeOverride);
  const unfold            = useUnfoldStore((s) => s.unfold);
  const pushSnapshot      = useHistoryStore((s) => s.pushSnapshot);

  const fill = isSelected ? FILL_SELECTED : isHovered ? FILL_HOVER : FILL_DEFAULT;
  const vs   = [face.v0, face.v1, face.v2];

  const handleFaceClick = (e: KonvaEventObject<MouseEvent>) => {
    e.cancelBubble = true;
    if (mode !== 'select') return;
    if (!multiKey.current) useUIStore.getState().clearSelection();
    toggle(face.faceId);
  };

  const handleEdgeClick = (localIdx: number, meshEdgeId: number) =>
    (e: KonvaEventObject<MouseEvent>) => {
      e.cancelBubble = true;
      if (mode === 'editPieces') {
        // Toggle Fold ↔ Cut, then re-unfold.
        pushSnapshot();
        const current = getEdgeOverride(meshEdgeId);
        const isCurrentlyFold = current === 'Fold'
          || (current === undefined && face.edgeIsFold[localIdx]);
        if (isCurrentlyFold) {
          setEdgeOverride(meshEdgeId, 'Cut');
        } else {
          // If it was a user Cut override, clear it; otherwise force Fold.
          if (current === 'Cut') clearEdgeOverride(meshEdgeId);
          else setEdgeOverride(meshEdgeId, 'Fold');
        }
        unfold();
      } else if (mode === 'editFlaps') {
        setEditEdge(meshEdgeId);
        useUIStore.getState().openDialog('editFlaps');
      } else {
        // select mode: clicking edge = noop (handled by face click)
        handleFaceClick(e as unknown as KonvaEventObject<MouseEvent>);
      }
    };

  // Face polygon (fill only, no outline — edges rendered separately)
  const polyPoints = vs.flatMap((v) => [v.x * scale, v.y * scale]);

  return (
    <Group>
      {/* Face fill */}
      <Line
        points={polyPoints}
        closed
        fill={fill}
        strokeWidth={0}
        onClick={handleFaceClick}
        onMouseEnter={() => setHovered(face.faceId)}
        onMouseLeave={() => setHovered(null)}
        hitStrokeWidth={4}
      />

      {/* Per-edge lines */}
      {([0, 1, 2] as const).map((i) => {
        const p0 = vs[i];
        const p1 = vs[(i + 1) % 3];
        const isFold     = face.edgeIsFold[i];
        const isBoundary = face.edgeIsBoundary[i];
        const meshEdgeId = face.meshEdgeIds[i];
        const isEdgeHovered = hoveredEdge === meshEdgeId;

        // Effective type after user override
        const override = getEdgeOverride(meshEdgeId);
        const effectiveFold = override === 'Fold' || (override === undefined && isFold);
        const effectiveBoundary = isBoundary;

        const stroke = effectiveFold ? STROKE_FOLD
          : effectiveBoundary ? STROKE_BOUNDARY
          : STROKE_CUT;
        const dash = effectiveFold ? DASH_FOLD : undefined;
        const sw   = effectiveBoundary ? 0.4 : isEdgeHovered ? 1.2 : 0.7;

        const midX = (p0.x + p1.x) / 2 * scale;
        const midY = (p0.y + p1.y) / 2 * scale;
        const pairId = cutPairIds?.[meshEdgeId];

        return (
          <Group key={i}>
            <Line
              points={[p0.x * scale, p0.y * scale, p1.x * scale, p1.y * scale]}
              stroke={stroke}
              strokeWidth={sw}
              dash={dash}
              hitStrokeWidth={6}
              onClick={handleEdgeClick(i, meshEdgeId)}
              onMouseEnter={() => useUIStore.getState().setHoveredEdge(meshEdgeId)}
              onMouseLeave={() => useUIStore.getState().setHoveredEdge(null)}
            />
            {/* Cut-edge pair number label */}
            {pairId !== undefined && !effectiveFold && !effectiveBoundary && (
              <Text
                x={midX - 5}
                y={midY - 5}
                text={String(pairId)}
                fontSize={8}
                fill="#cc0000"
                listening={false}
              />
            )}
          </Group>
        );
      })}
    </Group>
  );
}
