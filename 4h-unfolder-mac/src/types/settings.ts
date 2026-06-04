export type Theme     = 'light' | 'dark' | 'system';
export type ScaleUnit = 'mm' | 'cm' | 'inch';
export type TabShape  = 'Trapezoid' | 'Rectangle' | 'Triangle';
export type PaperPreset = 'A4' | 'A3' | 'A2' | 'A1' | 'Letter' | 'Legal' | 'Custom';

export interface AppSettings {
  // Glue tab
  tabWidthMm:       number;
  tabAngleDeg:      number;
  tabShape:         TabShape;
  alternateFlaps:   boolean;

  // Paper / layout
  sheetWidthMm:     number;
  sheetHeightMm:    number;
  pagesWide:        number;
  pagesTall:        number;
  autoArrange:      boolean;

  // View 2D
  showFoldLines:    boolean;
  showCutLines:     boolean;
  showBoundary:     boolean;
  showFaceLabels:   boolean;
  showGlueTabs:     boolean;
  showPageNumbers:  boolean;
  showFoldAngles:   boolean;

  // View 3D
  viewport3dBg:          string;
  viewport3dWireframe:   boolean;
  viewport3dFaceOpacity: number;

  // Export / print
  foldLineColor:    string;
  cutLineColor:     string;
  foldLineWidth:    number;
  cutLineWidth:     number;
  foldLineDash:     string;
  marginMm:         number;
  scaleFactor:      number;
  grayscaleOutput:  boolean;
  includePageLabel: boolean;
  exportDpi:        number;

  // General
  theme:            Theme;
  scaleUnit:        ScaleUnit;
  outlinePaddingMm: number;
}

export const PAPER_PRESETS: Record<Exclude<PaperPreset, 'Custom'>, [number, number]> = {
  A4:     [210,   297],
  A3:     [297,   420],
  A2:     [420,   594],
  A1:     [594,   841],
  Letter: [215.9, 279.4],
  Legal:  [215.9, 355.6],
};

export const DEFAULT_SETTINGS: AppSettings = {
  tabWidthMm:       5,
  tabAngleDeg:      45,
  tabShape:         'Trapezoid',
  alternateFlaps:   false,

  sheetWidthMm:     210,
  sheetHeightMm:    297,
  pagesWide:        1,
  pagesTall:        1,
  autoArrange:      true,

  showFoldLines:    true,
  showCutLines:     true,
  showBoundary:     true,
  showFaceLabels:   false,
  showGlueTabs:     true,
  showPageNumbers:  false,
  showFoldAngles:   false,

  viewport3dBg:          '#1a1a2e',
  viewport3dWireframe:   false,
  viewport3dFaceOpacity: 1.0,

  foldLineColor:    '#4169e1',
  cutLineColor:     '#ff0000',
  foldLineWidth:    0.5,
  cutLineWidth:     0.8,
  foldLineDash:     '4,2',
  marginMm:         5,
  scaleFactor:      1,
  grayscaleOutput:  false,
  includePageLabel: true,
  exportDpi:        300,

  theme:            'system',
  scaleUnit:        'mm',
  outlinePaddingMm: 0,
};
