import { useRef } from 'react';
import { Stage, Layer, Group } from 'react-konva';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useUIStore } from '@/state/uiStore';
import { useMeshStore } from '@/state/meshStore';
import { useCanvasZoomPan } from '@/hooks/useCanvas';
import { FaceShape } from './FaceShape';
import { GlueTabShape } from './GlueTabShape';
import { SheetBackground } from './SheetBackground';
import { DropZone } from './DropZone';
import { handleDroppedFile } from '@/services/meshLoader';

interface Props {
  width:  number;
  height: number;
}

const MM_TO_PX = 3.7795; // 1 mm ≈ 3.78 px at 96 dpi

export function PatternCanvas({ width, height }: Props) {
  const stageRef   = useRef<any>(null);
  const result     = useUnfoldStore((s) => s.result);
  const hasMesh    = useMeshStore((s) => s.mesh !== null);
  const viewport   = useUIStore((s) => s.viewport);
  const { handleWheel } = useCanvasZoomPan(stageRef);

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const files = Array.from(e.dataTransfer.files);
    if (files[0]) handleDroppedFile(files[0].name);
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
        draggable
        onDragEnd={(e) => {
          useUIStore.getState().setViewport({
            tx: e.target.x(),
            ty: e.target.y(),
          });
        }}
      >
        <Layer>
          {result && (
            <>
              <SheetBackground
                widthMm={result.sheetWidthMm}
                heightMm={result.sheetHeightMm}
                scale={MM_TO_PX}
              />
              {result.pieces.map((piece) => (
                <Group
                  key={piece.id}
                  x={(piece.offset.x) * MM_TO_PX}
                  y={(piece.offset.y) * MM_TO_PX}
                >
                  {piece.faces.map((face) => (
                    <FaceShape
                      key={face.faceId}
                      face={face}
                      scale={MM_TO_PX}
                    />
                  ))}
                  {piece.tabs.map((tab) => (
                    <GlueTabShape
                      key={`${tab.edgeId}-${tab.faceId}`}
                      tab={tab}
                      scale={MM_TO_PX}
                    />
                  ))}
                </Group>
              ))}
            </>
          )}
        </Layer>
      </Stage>
    </div>
  );
}
