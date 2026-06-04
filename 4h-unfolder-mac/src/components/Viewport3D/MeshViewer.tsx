import { Suspense, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useThree } from '@react-three/fiber';
import { OrbitControls, GizmoHelper, GizmoViewport } from '@react-three/drei';
import * as THREE from 'three';
import type { OrbitControls as OrbitControlsImpl } from 'three-stdlib';
import { useMeshStore } from '@/state/meshStore';
import { useUIStore } from '@/state/uiStore';
import { tauriCommands } from '@/types/tauri';
import type { Mesh as AppMesh } from '@/types/mesh';
import { MeshGeometry } from './MeshGeometry';

// ---------------------------------------------------------------------------
// Camera fit helper
// ---------------------------------------------------------------------------

function CameraFit({ mesh }: { mesh: AppMesh }) {
  const { camera, controls } = useThree();
  const fittedRef = useRef<string | null>(null);

  useEffect(() => {
    const key = `${mesh.name}-${mesh.vertices.length}`;
    if (fittedRef.current === key) return;
    fittedRef.current = key;

    const { min, max } = mesh.bounds;
    const cx = (min[0] + max[0]) / 2;
    const cy = (min[1] + max[1]) / 2;
    const cz = (min[2] + max[2]) / 2;
    const dx = max[0] - min[0];
    const dy = max[1] - min[1];
    const dz = max[2] - min[2];
    const diagonal = Math.sqrt(dx * dx + dy * dy + dz * dz) || 1;

    const target = new THREE.Vector3(cx, cy, cz);
    camera.position.set(cx + diagonal * 0.8, cy + diagonal * 0.5, cz + diagonal * 0.8);
    camera.lookAt(target);

    if (controls) {
      const oc = controls as unknown as OrbitControlsImpl;
      oc.target.copy(target);
      oc.update();
    }
  }, [mesh, camera, controls]);

  return null;
}

// ---------------------------------------------------------------------------
// Texture loader hook
// ---------------------------------------------------------------------------

function useTextureCache(mesh: AppMesh): Map<string, THREE.Texture> {
  const [cache, setCache] = useState<Map<string, THREE.Texture>>(new Map());

  useEffect(() => {
    const paths = mesh.materialTexturePaths.filter(Boolean) as string[];
    if (paths.length === 0) return;

    let cancelled = false;

    async function load() {
      const newCache = new Map<string, THREE.Texture>();
      for (const p of paths) {
        try {
          const dataUri = await tauriCommands.getTextureAsBase64(p);
          if (cancelled) return;
          const loader = new THREE.TextureLoader();
          const tex = await new Promise<THREE.Texture>((resolve, reject) =>
            loader.load(dataUri, resolve, undefined, reject),
          );
          tex.flipY = true;
          newCache.set(p, tex);
        } catch {
          // texture unavailable — mesh renders without it
        }
      }
      if (!cancelled) setCache(newCache);
    }

    load();
    return () => { cancelled = true; };
  }, [mesh]);

  return cache;
}

// ---------------------------------------------------------------------------
// Inner scene (needs useThree → must be inside Canvas)
// ---------------------------------------------------------------------------

function Scene({ mesh }: { mesh: AppMesh }) {
  const textureCache = useTextureCache(mesh);
  const selectedFaceIds = useUIStore((s) => s.selectedFaceIds);
  const hoveredFaceId   = useUIStore((s) => s.hoveredFaceId);
  const toggleFaceSelect = useUIStore((s) => s.toggleFaceSelect);
  const setHoveredFace   = useUIStore((s) => s.setHoveredFace);

  return (
    <>
      {/* Lights */}
      <ambientLight intensity={0.5} />
      <directionalLight position={[5, 10, 7]} intensity={0.9} castShadow={false} />
      <directionalLight position={[-5, -3, -5]} intensity={0.3} />

      <MeshGeometry
        mesh={mesh}
        textureCache={textureCache}
        selectedFaceIds={selectedFaceIds}
        hoveredFaceId={hoveredFaceId}
        onFacePointerDown={(id) => toggleFaceSelect(id)}
        onFacePointerEnter={(id) => setHoveredFace(id)}
        onFacePointerLeave={() => setHoveredFace(null)}
      />

      <OrbitControls makeDefault enableDamping dampingFactor={0.1} />
      <CameraFit mesh={mesh} />

      <GizmoHelper alignment="bottom-right" margin={[60, 60]}>
        <GizmoViewport />
      </GizmoHelper>
    </>
  );
}

// ---------------------------------------------------------------------------
// Main exported component
// ---------------------------------------------------------------------------

export function MeshViewer() {
  const mesh = useMeshStore((s) => s.mesh);

  const bg = useMemo(() => new THREE.Color(0x1a1a2e), []);

  if (!mesh) {
    return (
      <div className="w-full h-full flex items-center justify-center bg-[#1a1a2e] text-muted-foreground text-sm">
        No mesh loaded
      </div>
    );
  }

  return (
    <Canvas
      camera={{ fov: 45, near: 0.001, far: 10000, position: [0, 0, 5] }}
      scene={{ background: bg }}
      style={{ width: '100%', height: '100%' }}
    >
      <Suspense fallback={null}>
        <Scene mesh={mesh} />
      </Suspense>
    </Canvas>
  );
}
