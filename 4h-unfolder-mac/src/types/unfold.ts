/** Mirrors Rust `models/unfold.rs` field-for-field. */

export interface Point2 {
  x: number;
  y: number;
}

// ---------------------------------------------------------------------------
// Enums — 10 FlapMode variants matching C# + Rust exactly
// ---------------------------------------------------------------------------

export type FlapMode =
  | 'default'
  | 'switchPosition'
  | 'onOnThisSide'
  | 'offOnOtherSide'
  | 'offOffNoFlap'
  | 'onOnBothSides'
  | 'borderMountainFold'
  | 'borderValleyFold'
  | 'borderNoFold'
  | 'borderNoFlap';

export type TabShape = 'trapezoid' | 'rectangle' | 'triangle';

export interface FlapOverride {
  mode:          FlapMode;
  /** -1 when not needed */
  primaryFaceId: number;
}

// ---------------------------------------------------------------------------
// Core result types
// ---------------------------------------------------------------------------

/**
 * One unfolded triangle in paper space (mm).
 * edgeIs* arrays are indexed [V0-V1, V1-V2, V2-V0].
 */
export interface UnfoldedFace {
  faceId:          number;
  v0:              Point2;
  v1:              Point2;
  v2:              Point2;
  edgeIsFold:      [boolean, boolean, boolean];
  edgeIsBoundary:  [boolean, boolean, boolean];
  uvCoords?:       [[number, number], [number, number], [number, number]];
  materialId:      number;
  /** -1 if not resolved */
  meshEdgeIds:     [number, number, number];
  pieceId:         number;
}

/**
 * Glue tab.  p0/p1 are on the cut edge; p2/p3 are inset.
 * Matches C# GlueTab.P0/P1/P2/P3.
 */
export interface GlueTab {
  faceId:          number;
  localEdgeIdx:    number;
  p0: Point2;
  p1: Point2;
  p2: Point2;
  p3: Point2;
  borderFoldStyle?: FlapMode;
}

// ---------------------------------------------------------------------------
// Algorithm output
// ---------------------------------------------------------------------------

export interface UnfoldResult {
  faces:                UnfoldedFace[];
  glueTabs:             GlueTab[];
  hasOverlaps:          boolean;
  /** meshEdgeId → 1-based pair number (cut edges only) */
  cutEdgePairIds:       Record<number, number>;
  /** meshEdgeId → degrees (fold edges only) */
  edgeDihedralAngles:   Record<number, number>;
}

// ---------------------------------------------------------------------------
// Layout layer
// ---------------------------------------------------------------------------

export interface PieceLayout {
  pieceId:  number;
  faceIds:  number[];
  /** Translation offset in mm on top of unfolded coordinates */
  offset:   Point2;
  /** Rotation in degrees */
  rotation: number;
}

/** Full response from `unfold_mesh` Tauri command */
export interface UnfoldResponse {
  unfoldResult:   UnfoldResult;
  pieceLayouts:   PieceLayout[];
  sheetWidthMm:   number;
  sheetHeightMm:  number;
}

// ---------------------------------------------------------------------------
// Options sent to the backend
// ---------------------------------------------------------------------------

export interface UnfoldOptions {
  tabWidthMm:    number;
  tabAngleDeg:   number;
  sheetWidthMm:  number;
  sheetHeightMm: number;
  autoArrange:   boolean;
  alternateFlaps: boolean;
  tabShape:      string;
  /** meshEdgeId → "Fold" | "Cut" */
  edgeOverrides: Record<string, string>;
  /** meshEdgeId → "{Mode},{primaryFaceId}" */
  flapOverrides: Record<string, string>;
}

// ---------------------------------------------------------------------------
// Assembly
// ---------------------------------------------------------------------------

export interface AssemblyStep {
  stepIndex:     number;
  groupId:       number;
  parentGroupId: number;
  faceIds:       number[];
}
