import { useRef, useMemo } from 'react';
import { Stage, Layer } from 'react-konva';
import type { KonvaEventObject } from 'konva/lib/Node';
import type { GlueTab, PieceLayout, UnfoldedFace, UnfoldResponse } from '@/types/unfold';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useUIStore } from '@/state/uiStore';
import { useMeshStore } from '@/state/meshStore';
import { useCanvasZoomPan } from '@/hooks/useCanvas';
import { PieceGroup } from './PieceGroup';
import { LassoOverlay } from './LassoOverlay';
import { SheetBackground } from './SheetBackground';
import { DropZone } from './DropZone';
import { handleDroppedFile } from '@/services/meshLoader';

interface Props {
  width:  number;
  height: number;
}

const MM_TO_PX = 3.7795; // 1 mm ≈ 3.78 px at 96 dpi

// ---------------------------------------------------------------------------
// Derive renderable pieces from UnfoldResponse + user layout edits.
// ---------------------------------------------------------------------------

interface RenderedPiece {
  layout: PieceLayout;
  faces:  UnfoldedFace[];
  tabs:   GlueTab[];
}

function buildRenderedPieces(
  response: UnfoldResponse,
  userLayouts: Map<number, { offsetX: number; offsetY: number; rotation: number }>,
): RenderedPiece[] {
  const faceMap = new Map(response.unfoldResult.faces.map((f) => [f.faceId, f]));

  // Map faceId → pieceId so tabs can be grouped by piece.
  const faceIdToPieceId = new Map(
    response.unfoldResult.faces.map((f) => [f.faceId, f.pieceId])
  );
  const tabsByPiece = new Map<number, GlueTab[]>();
  for (const tab of response.unfoldResult.glueTabs) {
    const pid = faceIdToPieceId.get(tab.faceId) ?? 0;
    if (!tabsByPiece.has(pid)) tabsByPiece.set(pid, []);
    tabsByPiece.get(pid)!.push(tab);
  }

  return response.pieceLayouts.map((backendLayout) => {
    const edit = userLayouts.get(backendLayout.pieceId);
    const layout: PieceLayout = edit
      ? {
          ...backendLayout,
          offset:   { x: edit.offsetX, y: edit.offsetY },
          rotation: edit.rotation,
        }
      : backendLayout;

    const pieceFaces = backendLayout.faceIds
      .map((id) => faceMap.get(id))
      .filter((f): f is UnfoldedFace => f !== undefined);

    return {
      layout,
      faces: pieceFaces,
      tabs:  tabsByPiece.get(backendLayout.pieceId) ?? [],
    };
  });
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function PatternCanvas({ width, height }: Props) {
  const stageRef   = useRef<any>(null);
  const response   = useUnfoldStore((s) => s.response);
  const pieceLayouts = useUnfoldStore((s) => s.pieceLayouts);
  const hasMesh    = useMeshStore((s) => s.mesh !== null);
  const viewport   = useUIStore((s) => s.viewport);
  const mode       = useUIStore((s) => s.mode);
  const { handleWheel } = useCanvasZoomPan(stageRef);

  // Pan state for middle-mouse drag.
  const panStart = useRef<{ mouseX: number; mouseY: number; tx: number; ty: number } | null>(null);

  const renderedPieces = useMemo(
    () => (response ? buildRenderedPieces(response, pieceLayouts) : []),
    [response, pieceLayouts]
  );

  const cutPairIds: Record<number, number> =
    response?.unfoldResult.cutEdgePairIds ?? {};

  // Effective piece layouts for lasso (need offset).
  const effectiveLayouts = renderedPieces.map((p) => p.layout);
  const allFaces         = renderedPieces.flatMap((p) => p.faces);

  // ---------------------------------------------------------------------------
  // Drop handler
  // ---------------------------------------------------------------------------
  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const files = Array.from(e.dataTransfer.files);
    if (files[0]) handleDroppedFile(files[0].name);
  };

  // ---------------------------------------------------------------------------
  // Middle-mouse pan
  // ---------------------------------------------------------------------------
  const handleStageMouseDown = (e: KonvaEventObject<MouseEvent>) => {
    if (e.evt.button === 1 || (mode === 'pan' && e.evt.button === 0)) {
      e.evt.preventDefault();
      panStart.current = {
        mouseX: e.evt.clientX,
        mouseY: e.evt.clientY,
        tx: viewport.tx,
        ty: viewport.ty,
      };
    }
  };

  const handleStageMouseMove = (e: KonvaEventObject<MouseEvent>) => {
    if (!panStart.current) return;
    const dx = e.evt.clientX - panStart.current.mouseX;
    const dy = e.evt.clientY - panStart.current.mouseY;
    useUIStore.getState().setViewport({
      tx: panStart.current.tx + dx,
      ty: panStart.current.ty + dy,
    });
  };

  const handleStageMouseUp = (e: KonvaEventObject<MouseEvent>) => {
    if (panStart.current && (e.evt.button === 1 || mode === 'pan')) {
      panStart.current = null;
    }
  };

  const handleStageClick = (e: KonvaEventObject<MouseEvent>) => {
    // Click on empty canvas (not on any piece/face) → clear selection.
    if (e.target === e.currentTarget && mode === 'select') {
      useUIStore.getState().clearSelection();
    }
  };

  return (
    <div
      className="flex-1 overflow-hidden bg-canvas relative"
      onDrop={handleDrop}
      onDragOver={(e) => e.preventDefault()}
    >
      {!hasMesh && <DropZone />}

      <Stage
        ref={stageRef}
        width={width}
        height={height}
        x={viewport.tx}
        y={viewport.ty}
        scaleX={viewport.scale}
        scaleY={viewport.scale}
        onWheel={handleWheel}
        onMouseDown={handleStageMouseDown}
        onMouseMove={handleStageMouseMove}
        onMouseUp={handleStageMouseUp}
        onClick={handleStageClick}
        style={{ cursor: mode === 'pan' ? 'grab' : 'default' }}
      >
        <Layer>
          {response && (
            <>
              <SheetBackground
                widthMm={response.sheetWidthMm}
                heightMm={response.sheetHeightMm}
                scale={MM_TO_PX}
              />

              {renderedPieces.map((piece) => (
                <PieceGroup
                  key={piece.layout.pieceId}
                  layout={piece.layout}
                  faces={piece.faces}
                  tabs={piece.tabs}
                  scale={MM_TO_PX}
                  cutPairIds={cutPairIds}
                />
              ))}

              <LassoOverlay
                faces={allFaces}
                pieceLayouts={effectiveLayouts}
                scale={MM_TO_PX}
                stageWidth={width / viewport.scale}
                stageHeight={height / viewport.scale}
              />
            </>
          )}
        </Layer>
      </Stage>
    </div>
  );
}
