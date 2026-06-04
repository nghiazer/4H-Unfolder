/** Mirrors Rust `models/mesh.rs` field-for-field. */

export type EdgeType = 'unknown' | 'fold' | 'cut' | 'boundary';

export interface Vertex {
  x: number;
  y: number;
  z: number;
}

/** Triangular face.  `edgeIds[i]` = edge between vertex i and (i+1)%3. */
export interface Face {
  id:         number;
  vertices:   [number, number, number];
  edgeIds:    [number, number, number];
  materialId: number;  // -1 = none
  uvs?:       [number, number, number];
}

export interface MeshEdge {
  id:        number;
  faceA:     number;
  faceB?:    number;
  vertA:     number;
  vertB:     number;
  edgeType:  EdgeType;
}

export interface BoundingBox {
  min: [number, number, number];
  max: [number, number, number];
}

export interface EmbeddedTexture {
  name:       string;
  width:      number;
  height:     number;
  rgb24Bytes: number[];
}

export interface PdoFace {
  faceId:    number;
  partIndex: number;
  a: [number, number];
  b: [number, number];
  c: [number, number];
}

export interface PdoLayout {
  faces: PdoFace[];
}

export interface Mesh {
  name:                  string;
  vertices:              Vertex[];
  faces:                 Face[];
  edges:                 MeshEdge[];
  uvs:                   [number, number][];
  materialNames:         string[];
  materialTexturePaths:  (string | null)[];
  suggestedTexturePath?: string;
  pdoLayout?:            PdoLayout;
  embeddedTextures:      EmbeddedTexture[];
  bounds:                BoundingBox;
}

/** Lightweight metadata returned by `get_mesh_info` — avoids sending the full Mesh payload. */
export interface MeshInfoDto {
  faceCount:              number;
  vertexCount:            number;
  edgeCount:              number;
  materialCount:          number;
  hasUvs:                 boolean;
  bounds:                 BoundingBox;
  suggestedTexturePath?:  string;
  materialNames:          string[];
  /** True when `build_edges()` has stamped face.edgeIds correctly. */
  edgesStamped:           boolean;
}
