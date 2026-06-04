import { useCallback, useEffect, useRef } from 'react';
import type { KonvaEventObject } from 'konva/lib/Node';
import { useUIStore } from '@/state/uiStore';

const MIN_SCALE = 0.05;
const MAX_SCALE = 20;
const ZOOM_FACTOR = 1.08;

export function useCanvasZoomPan(stageRef: React.RefObject<any>) {
  const setViewport = useUIStore((s) => s.setViewport);
  const viewport    = useUIStore((s) => s.viewport);

  const handleWheel = useCallback((e: KonvaEventObject<WheelEvent>) => {
    e.evt.preventDefault();
    const stage    = stageRef.current;
    if (!stage) return;

    const oldScale = stage.scaleX();
    const pointer  = stage.getPointerPosition();
    if (!pointer) return;

    const direction = e.evt.deltaY < 0 ? 1 : -1;
    const newScale  = Math.min(
      MAX_SCALE,
      Math.max(MIN_SCALE, oldScale * Math.pow(ZOOM_FACTOR, direction))
    );

    const mousePointTo = {
      x: (pointer.x - stage.x()) / oldScale,
      y: (pointer.y - stage.y()) / oldScale,
    };

    const newPos = {
      tx: pointer.x - mousePointTo.x * newScale,
      ty: pointer.y - mousePointTo.y * newScale,
    };

    setViewport({ scale: newScale, ...newPos });
    stage.scale({ x: newScale, y: newScale });
    stage.position(newPos);
  }, [stageRef, setViewport]);

  const handleFitToScreen = useCallback(() => {
    // Reset to default view.
    setViewport({ scale: 1, tx: 0, ty: 0 });
  }, [setViewport]);

  return { handleWheel, handleFitToScreen, viewport };
}

/** Track whether a modifier key is held for multi-select. */
export function useMultiSelectKey() {
  const ref = useRef(false);

  useEffect(() => {
    const down = (e: KeyboardEvent) => { if (e.metaKey || e.ctrlKey) ref.current = true; };
    const up   = (e: KeyboardEvent) => { if (!e.metaKey && !e.ctrlKey) ref.current = false; };
    window.addEventListener('keydown', down);
    window.addEventListener('keyup',   up);
    return () => {
      window.removeEventListener('keydown', down);
      window.removeEventListener('keyup',   up);
    };
  }, []);

  return ref;
}
