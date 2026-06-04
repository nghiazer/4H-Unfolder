import { Line } from 'react-konva';
import type { KonvaEventObject } from 'konva/lib/Node';
import type { UnfoldedFace } from '@/types/unfold';
import { useUIStore } from '@/state/uiStore';
import { useMultiSelectKey } from '@/hooks/useCanvas';

interface Props {
  face:  UnfoldedFace;
  scale: number;
}

const FILL_DEFAULT   = '#f5f0e8';
const FILL_SELECTED  = '#bfd7ff';
const FILL_HOVER     = '#e8f4ff';
const STROKE_CUT     = '#333333';
const STROKE_FOLD    = '#3388ff';

export function FaceShape({ face, scale }: Props) {
  const isSelected  = useUIStore((s) => s.selectedFaceIds.has(face.faceId));
  const isHovered   = useUIStore((s) => s.hoveredFaceId === face.faceId);
  const toggle      = useUIStore((s) => s.toggleFaceSelect);
  const setHovered  = useUIStore((s) => s.setHoveredFace);
  const multiKey    = useMultiSelectKey();

  const flatPoints = face.vertices.flatMap((v) => [v.x * scale, v.y * scale]);

  const fill = isSelected ? FILL_SELECTED : isHovered ? FILL_HOVER : FILL_DEFAULT;

  const handleClick = (e: KonvaEventObject<MouseEvent>) => {
    e.cancelBubble = true;
    if (!multiKey.current) useUIStore.getState().clearSelection();
    toggle(face.faceId);
  };

  return (
    <Line
      points={flatPoints}
      closed
      fill={fill}
      stroke={STROKE_CUT}
      strokeWidth={0.6}
      onClick={handleClick}
      onMouseEnter={() => setHovered(face.faceId)}
      onMouseLeave={() => setHovered(null)}
      hitStrokeWidth={4}
    />
  );
}
