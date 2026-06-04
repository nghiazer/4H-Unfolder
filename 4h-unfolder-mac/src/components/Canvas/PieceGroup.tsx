import { useMemo } from 'react';
import { Group, Circle } from 'react-konva';
import type { KonvaEventObject } from 'konva/lib/Node';
import type { GlueTab, PieceLayout, UnfoldedFace } from '@/types/unfold';
import { FaceShape } from './FaceShape';
import { GlueTabShape } from './GlueTabShape';
import { useUIStore } from '@/state/uiStore';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useHistoryStore } from '@/state/historyStore';

interface Props {
  layout:     PieceLayout;
  faces:      UnfoldedFace[];
  tabs:       GlueTab[];
  scale:      number;
  cutPairIds: Record<number, number>;
}

/** Pixel offset from centroid where the rotation handle is rendered. */
const HANDLE_OFFSET = 30;

export function PieceGroup({ layout, faces, tabs, scale, cutPairIds }: Props) {
  const mode            = useUIStore((s) => s.mode);
  const selectedPieceId = useUIStore((s) => s.selectedPieceId);
  const setSelectedPiece = useUIStore((s) => s.setSelectedPiece);

  const setPieceOffset   = useUnfoldStore((s) => s.setPieceOffset);
  const setPieceRotation = useUnfoldStore((s) => s.setPieceRotation);
  const pushSnapshot     = useHistoryStore((s) => s.pushSnapshot);

  const isSelected = selectedPieceId === layout.pieceId;

  // Centroid of all face vertices in piece-local (mm) coords.
  const centroid = useMemo(() => {
    const allVerts = faces.flatMap((f) => [f.v0, f.v1, f.v2]);
    if (allVerts.length === 0) return { x: 0, y: 0 };
    const sx = allVerts.reduce((a, v) => a + v.x, 0);
    const sy = allVerts.reduce((a, v) => a + v.y, 0);
    return { x: sx / allVerts.length, y: sy / allVerts.length };
  }, [faces]);

  // Konva Group positioning: rotate around centroid while translating by offset.
  const centPx = { x: centroid.x * scale, y: centroid.y * scale };
  const tx = layout.offset.x * scale + centPx.x;
  const ty = layout.offset.y * scale + centPx.y;

  const handleDragEnd = (e: KonvaEventObject<DragEvent>) => {
    pushSnapshot();
    const newOffsetX = (e.target.x() - centPx.x) / scale;
    const newOffsetY = (e.target.y() - centPx.y) / scale;
    setPieceOffset(layout.pieceId, newOffsetX, newOffsetY);
  };

  const handleClick = (e: KonvaEventObject<MouseEvent>) => {
    if (mode !== 'select') return;
    e.cancelBubble = true;
    setSelectedPiece(isSelected ? null : layout.pieceId);
  };

  // Rotation handle: drag to rotate piece around centroid.
  const handleRotateDragMove = (e: KonvaEventObject<DragEvent>) => {
    const node = e.target;
    const stage = node.getStage();
    if (!stage) return;
    const ptr = stage.getPointerPosition();
    if (!ptr) return;

    // Convert pointer to Group's local frame (after Group translation/scale).
    const groupNode = node.getParent();
    if (!groupNode) return;
    const transform = groupNode.getAbsoluteTransform().copy().invert();
    const local = transform.point(ptr);

    // Angle from centroid (which is at offsetX/offsetY = centPx) to pointer.
    // In Group local coords centroid is at (0,0) because offsetX/offsetY shift it.
    const angle = Math.atan2(local.y, local.x) * (180 / Math.PI);
    setPieceRotation(layout.pieceId, angle - 90);

    // Keep handle visually at fixed offset — let Konva do the transform.
    node.position({ x: 0, y: -HANDLE_OFFSET });
  };

  return (
    <Group
      x={tx}
      y={ty}
      offsetX={centPx.x}
      offsetY={centPx.y}
      rotation={layout.rotation}
      draggable={mode === 'select'}
      onDragEnd={handleDragEnd}
      onClick={handleClick}
    >
      {faces.map((f) => (
        <FaceShape
          key={f.faceId}
          face={f}
          scale={scale}
          cutPairIds={cutPairIds}
        />
      ))}
      {tabs.map((t) => (
        <GlueTabShape
          key={`${t.faceId}-${t.localEdgeIdx}`}
          tab={t}
          scale={scale}
        />
      ))}

      {/* Rotation handle — shown only when this piece is selected */}
      {isSelected && mode === 'select' && (
        <Circle
          x={0}
          y={-HANDLE_OFFSET}
          radius={5}
          fill="#3388ff"
          stroke="#ffffff"
          strokeWidth={1.5}
          draggable
          onDragMove={handleRotateDragMove}
          onDragEnd={() => {}}
          onMouseEnter={(e) => {
            const stage = e.target.getStage();
            if (stage) stage.container().style.cursor = 'crosshair';
          }}
          onMouseLeave={(e) => {
            const stage = e.target.getStage();
            if (stage) stage.container().style.cursor = 'default';
          }}
        />
      )}
    </Group>
  );
}
