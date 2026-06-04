import { useMemo, useRef } from 'react';
import * as THREE from 'three';
import type { Mesh as AppMesh } from '@/types/mesh';

interface Props {
  mesh: AppMesh;
  textureCache: Map<string, THREE.Texture>;
  selectedFaceIds: Set<number>;
  hoveredFaceId: number | null;
  onFacePointerDown?: (faceId: number) => void;
  onFacePointerEnter?: (faceId: number) => void;
  onFacePointerLeave?: () => void;
}

/** Convert app Mesh → Three.js BufferGeometry, grouped by material. */
function buildGeometry(appMesh: AppMesh): THREE.BufferGeometry {
  const positions: number[] = [];
  const normals:   number[] = [];
  const uvCoords:  number[] = [];

  const geo = new THREE.BufferGeometry();
  const groups: { start: number; count: number; matIdx: number }[] = [];

  // Group faces by materialId
  const byMat = new Map<number, typeof appMesh.faces>();
  for (const f of appMesh.faces) {
    const mat = f.materialId >= 0 ? f.materialId : 0;
    if (!byMat.has(mat)) byMat.set(mat, []);
    byMat.get(mat)!.push(f);
  }

  for (const [matIdx, faces] of byMat) {
    const start = positions.length / 3;
    for (const f of faces) {
      const [ia, ib, ic] = f.vertices;
      const va = appMesh.vertices[ia];
      const vb = appMesh.vertices[ib];
      const vc = appMesh.vertices[ic];
      if (!va || !vb || !vc) continue;

      // Per-face flat normal
      const ax = vb.x - va.x, ay = vb.y - va.y, az = vb.z - va.z;
      const bx = vc.x - va.x, by = vc.y - va.y, bz = vc.z - va.z;
      const nx = ay * bz - az * by;
      const ny = az * bx - ax * bz;
      const nz = ax * by - ay * bx;
      const nLen = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1;

      for (const v of [va, vb, vc]) {
        positions.push(v.x, v.y, v.z);
        normals.push(nx / nLen, ny / nLen, nz / nLen);
      }

      // UVs
      if (f.uvs) {
        for (const uvIdx of f.uvs) {
          const uv = appMesh.uvs[uvIdx];
          uvCoords.push(uv ? uv[0] : 0, uv ? uv[1] : 0);
        }
      } else {
        uvCoords.push(0, 0, 1, 0, 0.5, 1);
      }
    }
    const count = positions.length / 3 - start;
    if (count > 0) groups.push({ start, count, matIdx });
  }

  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setAttribute('normal',   new THREE.Float32BufferAttribute(normals,   3));
  geo.setAttribute('uv',       new THREE.Float32BufferAttribute(uvCoords,  2));
  for (const g of groups) {
    geo.addGroup(g.start * 3, g.count * 3, g.matIdx);
  }
  return geo;
}

/** Build a geometry that only includes selected/hovered faces for overlay. */
function buildOverlayGeometry(
  appMesh: AppMesh,
  faceIds: Set<number>,
): THREE.BufferGeometry {
  const positions: number[] = [];
  const geo = new THREE.BufferGeometry();
  for (const f of appMesh.faces) {
    if (!faceIds.has(f.id)) continue;
    const [ia, ib, ic] = f.vertices;
    for (const i of [ia, ib, ic]) {
      const v = appMesh.vertices[i];
      if (v) positions.push(v.x, v.y, v.z);
    }
  }
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  return geo;
}

export function MeshGeometry({
  mesh,
  textureCache,
  selectedFaceIds,
  hoveredFaceId,
  onFacePointerDown,
  onFacePointerEnter,
  onFacePointerLeave,
}: Props) {
  const geo = useMemo(() => buildGeometry(mesh), [mesh]);

  // Build material array
  const materials = useMemo(() => {
    const mats: THREE.Material[] = [];
    const count = Math.max(1, mesh.materialNames.length);
    for (let i = 0; i < count; i++) {
      const texPath = mesh.materialTexturePaths[i];
      const tex = texPath ? textureCache.get(texPath) : undefined;
      const mat = new THREE.MeshStandardMaterial({
        color: tex ? 0xffffff : 0xcccccc,
        map:   tex ?? null,
        side:  THREE.DoubleSide,
      });
      mats.push(mat);
    }
    return mats;
  }, [mesh, textureCache]);

  // Selection overlay
  const selectionIds = useMemo(() => {
    const ids = new Set(selectedFaceIds);
    if (hoveredFaceId !== null) ids.add(hoveredFaceId);
    return ids;
  }, [selectedFaceIds, hoveredFaceId]);

  const overlayGeo = useMemo(
    () => buildOverlayGeometry(mesh, selectionIds),
    [mesh, selectionIds],
  );

  // Map Three.js triangle index → app face id
  // Each face = 1 triangle = 3 vertices; order depends on buildGeometry grouping.
  const faceIndexMapRef = useRef<number[]>([]);
  useMemo(() => {
    const map: number[] = [];
    const byMat = new Map<number, typeof mesh.faces>();
    for (const f of mesh.faces) {
      const mat = f.materialId >= 0 ? f.materialId : 0;
      if (!byMat.has(mat)) byMat.set(mat, []);
      byMat.get(mat)!.push(f);
    }
    for (const faces of byMat.values()) {
      for (const f of faces) map.push(f.id);
    }
    faceIndexMapRef.current = map;
  }, [mesh]);

  return (
    <group>
      {/* Main mesh */}
      <mesh
        geometry={geo}
        material={materials}
        onPointerDown={(e) => {
          e.stopPropagation();
          const triIdx = e.face?.materialIndex ?? -1;
          // r3f gives face index in the draw call; use faceIndex from event
          const faceId = faceIndexMapRef.current[(e as any).faceIndex ?? triIdx];
          if (faceId !== undefined) onFacePointerDown?.(faceId);
        }}
        onPointerEnter={(e) => {
          e.stopPropagation();
          const faceId = faceIndexMapRef.current[(e as any).faceIndex ?? 0];
          if (faceId !== undefined) onFacePointerEnter?.(faceId);
        }}
        onPointerLeave={() => onFacePointerLeave?.()}
      />

      {/* Selection / hover highlight overlay */}
      {selectionIds.size > 0 && (
        <mesh geometry={overlayGeo} renderOrder={1}>
          <meshBasicMaterial
            color={0xf59e0b}
            transparent
            opacity={0.35}
            depthTest={false}
            side={THREE.DoubleSide}
          />
        </mesh>
      )}
    </group>
  );
}
