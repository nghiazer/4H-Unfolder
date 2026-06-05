import { useCallback, useEffect, useRef } from 'react';
import type { KonvaEventObject } from 'konva/lib/Node';
import { useUIStore } from '@/state/uiStore';

const MIN_SCALE    = 0.02;
const MAX_SCALE    = 20;
const ZOOM_INTENSITY = 0.003; // exp-based — small pinch step ≈ 0.3%, mouse step ≈ 26%

export function useCanvasZoomPan(stageRef: React.RefObject<any>) {
  const setViewport = useUIStore((s) => s.setViewport);

  const handleWheel = useCallback((e: KonvaEventObject<WheelEvent>) => {
    e.evt.preventDefault();
    const stage = stageRef.current;
    if (!stage) return;

    if (e.evt.ctrlKey || e.evt.metaKey) {
      // Pinch-to-zoom (macOS trackpad sends ctrlKey=true) or Ctrl+scroll
      const oldScale = stage.scaleX();
      const pointer  = stage.getPointerPosition();
      if (!pointer) return;

      const zoomDelta = Math.exp(-e.evt.deltaY * ZOOM_INTENSITY);
      const newScale  = Math.min(MAX_SCALE, Math.max(MIN_SCALE, oldScale * zoomDelta));

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
    } else {
      // Two-finger scroll (macOS trackpad) = pan
      const newPos = {
        tx: stage.x() - e.evt.deltaX,
        ty: stage.y() - e.evt.deltaY,
      };
      setViewport(newPos);
      stage.position(newPos);
    }
  }, [stageRef, setViewport]);

  /** Fit content (in px) into canvas dimensions with padding. */
  const fitToView = useCallback((
    contentWidthPx:  number,
    contentHeightPx: number,
    canvasWidth:     number,
    canvasHeight:    number,
  ) => {
    if (contentWidthPx <= 0 || contentHeightPx <= 0 || canvasWidth <= 0 || canvasHeight <= 0) return;
    const PADDING = 48;
    const scale = Math.min(
      (canvasWidth  - PADDING * 2) / contentWidthPx,
      (canvasHeight - PADDING * 2) / contentHeightPx,
    );
    const clamped = Math.min(MAX_SCALE, Math.max(MIN_SCALE, scale));
    const tx = (canvasWidth  - contentWidthPx  * clamped) / 2;
    const ty = (canvasHeight - contentHeightPx * clamped) / 2;
    setViewport({ scale: clamped, tx, ty });
    if (stageRef.current) {
      stageRef.current.scale({ x: clamped, y: clamped });
      stageRef.current.position({ x: tx, y: ty });
    }
  }, [stageRef, setViewport]);

  return { handleWheel, fitToView };
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
