use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 2-D point in paper space (mm).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Point2 {
    pub x: f64,
    pub y: f64,
}

impl Point2 {
    pub const ZERO: Self = Self { x: 0.0, y: 0.0 };

    pub fn new(x: f64, y: f64) -> Self { Self { x, y } }

    pub fn dist(self, other: Self) -> f64 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        (dx * dx + dy * dy).sqrt()
    }

    pub fn dot(self, other: Self) -> f64 { self.x * other.x + self.y * other.y }

    pub fn cross_z(self, other: Self) -> f64 { self.x * other.y - self.y * other.x }

    pub fn len(self) -> f64 { (self.x * self.x + self.y * self.y).sqrt() }
}

impl std::ops::Add for Point2 {
    type Output = Self;
    fn add(self, r: Self) -> Self { Self::new(self.x + r.x, self.y + r.y) }
}
impl std::ops::Sub for Point2 {
    type Output = Self;
    fn sub(self, r: Self) -> Self { Self::new(self.x - r.x, self.y - r.y) }
}
impl std::ops::Mul<f64> for Point2 {
    type Output = Self;
    fn mul(self, s: f64) -> Self { Self::new(self.x * s, self.y * s) }
}
impl std::ops::Div<f64> for Point2 {
    type Output = Self;
    fn div(self, s: f64) -> Self { Self::new(self.x / s, self.y / s) }
}
impl std::ops::Neg for Point2 {
    type Output = Self;
    fn neg(self) -> Self { Self::new(-self.x, -self.y) }
}

// ---------------------------------------------------------------------------
// Enums matching C# exactly
// ---------------------------------------------------------------------------

/// Per-edge glue-tab placement override — 10 variants, mirrors C# `FlapMode`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum FlapMode {
    /// Defer to the global alternateFlaps setting.
    #[default]
    Default,
    /// Move the tab to the other face.
    SwitchPosition,
    /// Tab only on the face specified by `primary_face_id`.
    OnOnThisSide,
    /// Tab only on the *other* face (not `primary_face_id`).
    OffOnOtherSide,
    /// No tab on either face.
    OffOffNoFlap,
    /// Tab on both faces.
    OnOnBothSides,
    // Border (mesh boundary) edge modes:
    BorderMountainFold,
    BorderValleyFold,
    BorderNoFold,
    BorderNoFlap,
}

impl FlapMode {
    /// Serialize to the same string format as C# FlapOverride.Serialize().
    pub fn to_str(self) -> &'static str {
        match self {
            Self::Default          => "Default",
            Self::SwitchPosition   => "SwitchPosition",
            Self::OnOnThisSide     => "OnOn_ThisSide",
            Self::OffOnOtherSide   => "OffOn_OtherSide",
            Self::OffOffNoFlap     => "OffOff_NoFlap",
            Self::OnOnBothSides    => "OnOn_BothSides",
            Self::BorderMountainFold => "Border_MountainFold",
            Self::BorderValleyFold => "Border_ValleyFold",
            Self::BorderNoFold     => "Border_NoFold",
            Self::BorderNoFlap     => "Border_NoFlap",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "Default"             => Some(Self::Default),
            "SwitchPosition"      => Some(Self::SwitchPosition),
            "OnOn_ThisSide"       => Some(Self::OnOnThisSide),
            "OffOn_OtherSide"     => Some(Self::OffOnOtherSide),
            "OffOff_NoFlap"       => Some(Self::OffOffNoFlap),
            "OnOn_BothSides"      => Some(Self::OnOnBothSides),
            "Border_MountainFold" => Some(Self::BorderMountainFold),
            "Border_ValleyFold"   => Some(Self::BorderValleyFold),
            "Border_NoFold"       => Some(Self::BorderNoFold),
            "Border_NoFlap"       => Some(Self::BorderNoFlap),
            _                     => None,
        }
    }
}

/// Per-edge glue-tab override — mirrors C# `FlapOverride` record.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FlapOverride {
    pub mode:            FlapMode,
    /// -1 when not needed (all modes except OnOnThisSide / OffOnOtherSide).
    pub primary_face_id: i32,
}

impl FlapOverride {
    /// Serialize to `"{Mode},{PrimaryFaceId}"` matching C#.
    pub fn serialize(&self) -> String {
        format!("{},{}", self.mode.to_str(), self.primary_face_id)
    }

    /// Deserialize from `"{Mode},{PrimaryFaceId}"`.
    pub fn deserialize(s: &str) -> Option<Self> {
        let mut parts = s.splitn(2, ',');
        let mode_str  = parts.next()?;
        let face_str  = parts.next().unwrap_or("-1");
        let mode      = FlapMode::from_str(mode_str)?;
        let primary   = face_str.parse::<i32>().unwrap_or(-1);
        Some(Self { mode, primary_face_id: primary })
    }
}

// ---------------------------------------------------------------------------
// Core result types — one unfolded face, one glue tab
// ---------------------------------------------------------------------------

/// One unfolded triangle in paper space (mm).
/// Mirrors C# `UnfoldedFace` field-for-field.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UnfoldedFace {
    pub face_id:          usize,
    pub v0:               Point2,
    pub v1:               Point2,
    pub v2:               Point2,
    /// `edge_is_fold[i]`  — true when local edge i (V_i → V_{(i+1)%3}) is a fold line.
    pub edge_is_fold:     [bool; 3],
    /// `edge_is_boundary[i]` — true when the edge is a mesh boundary (no adjacent face).
    pub edge_is_boundary: [bool; 3],
    /// UV coordinates for V0/V1/V2; `None` when no UV data.
    pub uv_coords:        Option<[[f64; 2]; 3]>,
    /// -1 = no material.
    pub material_id:      i32,
    /// Mesh `Edge.id` for each local edge.  -1 if not resolved.
    pub mesh_edge_ids:    [i32; 3],
    /// Connected-component index (paper piece this face belongs to).
    pub piece_id:         usize,
}

impl UnfoldedFace {
    /// Convenience: vertex at local index 0/1/2.
    pub fn vertex(&self, i: usize) -> Point2 {
        match i % 3 {
            0 => self.v0,
            1 => self.v1,
            _ => self.v2,
        }
    }

    /// Centroid of the triangle.
    pub fn centroid(&self) -> Point2 {
        Point2::new(
            (self.v0.x + self.v1.x + self.v2.x) / 3.0,
            (self.v0.y + self.v1.y + self.v2.y) / 3.0,
        )
    }
}

/// Glue tab attached to one cut edge.
/// Mirrors C# `GlueTab` field-for-field (P0/P1 on edge, P2/P3 inset).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GlueTab {
    pub face_id:           usize,
    /// Local edge index within the face (0 = V0→V1, 1 = V1→V2, 2 = V2→V0).
    pub local_edge_idx:    usize,
    /// On the cut edge.
    pub p0:                Point2,
    pub p1:                Point2,
    /// Inset / offset points (trapezoid: bevelled; rectangle: straight; triangle: apex).
    pub p2:                Point2,
    pub p3:                Point2,
    /// Set only for boundary-edge tabs (Border_* FlapModes).
    pub border_fold_style: Option<FlapMode>,
}

impl GlueTab {
    /// All four points as an array [P0, P1, P2, P3].
    pub fn vertices(&self) -> [Point2; 4] { [self.p0, self.p1, self.p2, self.p3] }
}

/// Tab shape selector — matches C# `PrintSettings.GlueTabShape`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum TabShape {
    #[default]
    Trapezoid,
    Rectangle,
    Triangle,
}

// ---------------------------------------------------------------------------
// Algorithm output
// ---------------------------------------------------------------------------

/// Complete result of the unfold pipeline — mirrors C# `UnfoldResult`.
/// This is the pure algorithm output; piece layout for rendering is separate.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UnfoldResult {
    pub faces:                Vec<UnfoldedFace>,
    pub glue_tabs:            Vec<GlueTab>,
    pub has_overlaps:         bool,
    /// mesh_edge_id → 1-based sequential pair number (cut edges only).
    pub cut_edge_pair_ids:    HashMap<usize, usize>,
    /// mesh_edge_id → dihedral angle in degrees (fold edges only).
    pub edge_dihedral_angles: HashMap<usize, f64>,
}

// ---------------------------------------------------------------------------
// Rendering / layout layer
// ---------------------------------------------------------------------------

/// Layout position for one paper piece (connected component).
/// Separated from `UnfoldResult` so the algorithm output is pure geometry.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PieceLayout {
    pub piece_id:  usize,
    pub face_ids:  Vec<usize>,
    /// Translation offset applied on top of the unfolded coordinates (mm).
    pub offset:    Point2,
    /// Rotation in degrees.
    pub rotation:  f64,
}

/// The full response returned to the frontend by `unfold_mesh`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UnfoldResponse {
    pub unfold_result:  UnfoldResult,
    pub piece_layouts:  Vec<PieceLayout>,
    pub sheet_width_mm:  f64,
    pub sheet_height_mm: f64,
}

// ---------------------------------------------------------------------------
// Assembly
// ---------------------------------------------------------------------------

/// One step in the paper-assembly sequence — mirrors C# `AssemblyStep`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AssemblyStep {
    pub step_index:    usize,
    /// Connected-component identifier (== min face_id in the piece).
    pub group_id:      usize,
    /// Parent piece group id; `usize::MAX` for the root.
    pub parent_group_id: usize,
    pub face_ids:      Vec<usize>,
}
