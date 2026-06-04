export type Theme     = 'light' | 'dark' | 'system';
export type ScaleUnit = 'mm' | 'cm' | 'inch';

export interface AppSettings {
  // Glue tab
  tabWidthMm:       number;
  tabAngleDeg:      number;
  tabShape:         string;    // "Trapezoid" | "Rectangle" | "Triangle"
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

  // Export
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
