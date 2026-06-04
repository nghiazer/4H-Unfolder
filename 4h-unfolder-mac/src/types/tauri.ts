/** Typed wrappers around the Tauri `invoke` API. */
import { invoke } from '@tauri-apps/api/core';
import type { Mesh } from './mesh';
import type { UnfoldOptions, UnfoldResponse } from './unfold';
import type { AppSettings } from './settings';

export const tauriCommands = {
  // -------------------------------------------------------------------------
  // Mesh loading
  // -------------------------------------------------------------------------
  loadObj: (path: string) =>
    invoke<Mesh>('load_obj', { path }),

  loadObjFromBytes: (bytes: number[]) =>
    invoke<Mesh>('load_obj_from_bytes', { bytes }),

  // -------------------------------------------------------------------------
  // Unfolding
  // -------------------------------------------------------------------------
  unfoldMesh: (mesh: Mesh, options: UnfoldOptions) =>
    invoke<UnfoldResponse>('unfold_mesh', { mesh, options }),

  getFaceAdjacency: (mesh: Mesh) =>
    invoke<[number, number, number | null][]>('get_face_adjacency', { mesh }),

  // -------------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------------
  exportSvg: (result: UnfoldResponse, opts: ExportOpts) =>
    invoke<void>('export_svg', { result, opts }),

  exportPdf: (result: UnfoldResponse, opts: ExportOpts) =>
    invoke<void>('export_pdf', { result, opts }),

  // -------------------------------------------------------------------------
  // Project persistence
  // -------------------------------------------------------------------------
  saveProject: (
    path:      string,
    state:     ProjectStateDto,
    meshBytes: number[],
  ) => invoke<void>('save_project', { path, state, meshBytes }),

  loadProject: (path: string) =>
    invoke<[ProjectStateDto, number[]]>('load_project', { path }),

  // -------------------------------------------------------------------------
  // Settings
  // -------------------------------------------------------------------------
  loadSettings: () =>
    invoke<AppSettings>('load_settings'),

  saveSettings: (settings: AppSettings) =>
    invoke<void>('save_settings', { settings }),
};

// ---------------------------------------------------------------------------
// Supporting DTOs
// ---------------------------------------------------------------------------

export interface ExportOpts {
  outputPath:      string;
  showFoldLines:   boolean;
  showCutLines:    boolean;
  showBoundary:    boolean;
  showLabels:      boolean;
  includeGlueTabs: boolean;
  grayscaleOutput: boolean;
  includePageLabel: boolean;
  dpi:             number;
  foldLineColor:   string;
  cutLineColor:    string;
  foldLineWidth:   number;
  cutLineWidth:    number;
  foldLineDash:    string;
  marginMm:        number;
  scaleFactor:     number;
  pagesWide:       number;
  pagesTall:       number;
}

export interface ProjectStateDto {
  version:           number;
  meshFilename:      string;
  textureExt?:       string;
  scaleMmPerUnit:    number;
  mirrorX:           boolean;
  paper:             { name: string; widthMm: number; heightMm: number };
  pagesWide:         number;
  pagesTall:         number;
  edgeOverrides:     Record<string, string>;
  flapOverrides:     Record<string, string>;
  pieceLayouts:      Array<{
    groupId:     number;
    positionX:   number;
    positionY:   number;
    rotation:    number;
    userGroupId?: number;
  }>;
  materialTextureExts: Record<string, string | null>;
  insertedImageExt?: string;
}
