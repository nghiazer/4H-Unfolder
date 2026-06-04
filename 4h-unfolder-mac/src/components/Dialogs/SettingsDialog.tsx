import { useState } from 'react';
import { X } from 'lucide-react';
import { useSettingsStore } from '@/state/settingsStore';
import { useUIStore } from '@/state/uiStore';
import type { AppSettings, TabShape, Theme, ScaleUnit, PaperPreset } from '@/types/settings';
import { PAPER_PRESETS } from '@/types/settings';

// ---------------------------------------------------------------------------
// Tab names
// ---------------------------------------------------------------------------

const TABS = ['General', 'View 3D', 'View 2D', 'Print'] as const;
type Tab = typeof TABS[number];

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="flex items-center justify-between gap-3">
      <span className="text-muted-foreground shrink-0">{label}</span>
      {children}
    </label>
  );
}

function CheckField({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-center gap-2 cursor-pointer">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="rounded"
      />
      <span>{label}</span>
    </label>
  );
}

function NumberInput({
  value,
  min,
  max,
  step,
  onChange,
}: {
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (v: number) => void;
}) {
  return (
    <input
      type="number"
      min={min}
      max={max}
      step={step}
      value={value}
      onChange={(e) => onChange(parseFloat(e.target.value))}
      className="input-field w-24"
    />
  );
}

function ColorInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <div className="flex items-center gap-2">
      <input
        type="color"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-8 h-7 rounded border border-border cursor-pointer p-0"
      />
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="input-field w-20 font-mono text-xs"
      />
    </div>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground mt-4 mb-2 first:mt-0">
      {children}
    </h3>
  );
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

function GeneralTab({ s, u }: { s: AppSettings; u: (p: Partial<AppSettings>) => void }) {
  return (
    <div className="space-y-3">
      <SectionTitle>Appearance</SectionTitle>
      <Field label="Theme">
        <select
          value={s.theme}
          onChange={(e) => u({ theme: e.target.value as Theme })}
          className="input-field w-28"
        >
          <option value="system">System</option>
          <option value="light">Light</option>
          <option value="dark">Dark</option>
        </select>
      </Field>

      <SectionTitle>Units</SectionTitle>
      <Field label="Scale unit">
        <select
          value={s.scaleUnit}
          onChange={(e) => u({ scaleUnit: e.target.value as ScaleUnit })}
          className="input-field w-28"
        >
          <option value="mm">Millimeters (mm)</option>
          <option value="cm">Centimeters (cm)</option>
          <option value="inch">Inches (in)</option>
        </select>
      </Field>

      <SectionTitle>Auto-arrange</SectionTitle>
      <CheckField
        label="Auto-arrange pieces after unfold"
        checked={s.autoArrange}
        onChange={(v) => u({ autoArrange: v })}
      />
    </div>
  );
}

function View3DTab({ s, u }: { s: AppSettings; u: (p: Partial<AppSettings>) => void }) {
  return (
    <div className="space-y-3">
      <SectionTitle>Viewport</SectionTitle>
      <Field label="Background color">
        <ColorInput value={s.viewport3dBg} onChange={(v) => u({ viewport3dBg: v })} />
      </Field>
      <CheckField
        label="Show wireframe"
        checked={s.viewport3dWireframe}
        onChange={(v) => u({ viewport3dWireframe: v })}
      />
      <Field label="Face opacity">
        <NumberInput
          value={s.viewport3dFaceOpacity}
          min={0.1}
          max={1}
          step={0.05}
          onChange={(v) => u({ viewport3dFaceOpacity: v })}
        />
      </Field>
    </div>
  );
}

function View2DTab({ s, u }: { s: AppSettings; u: (p: Partial<AppSettings>) => void }) {
  return (
    <div className="space-y-3">
      <SectionTitle>Lines</SectionTitle>
      <CheckField label="Show fold lines"     checked={s.showFoldLines}   onChange={(v) => u({ showFoldLines: v })} />
      <CheckField label="Show cut lines"      checked={s.showCutLines}    onChange={(v) => u({ showCutLines: v })} />
      <CheckField label="Show boundary lines" checked={s.showBoundary}    onChange={(v) => u({ showBoundary: v })} />

      <SectionTitle>Labels</SectionTitle>
      <CheckField label="Show face labels"   checked={s.showFaceLabels}  onChange={(v) => u({ showFaceLabels: v })} />
      <CheckField label="Show fold angles"   checked={s.showFoldAngles}  onChange={(v) => u({ showFoldAngles: v })} />

      <SectionTitle>Glue tabs</SectionTitle>
      <CheckField label="Show glue tabs"     checked={s.showGlueTabs}    onChange={(v) => u({ showGlueTabs: v })} />

      <SectionTitle>Page</SectionTitle>
      <CheckField label="Show page numbers"  checked={s.showPageNumbers} onChange={(v) => u({ showPageNumbers: v })} />
    </div>
  );
}

function PrintTab({ s, u }: { s: AppSettings; u: (p: Partial<AppSettings>) => void }) {
  // Detect current paper preset
  const currentPreset = (): PaperPreset => {
    for (const [k, [w, h]] of Object.entries(PAPER_PRESETS)) {
      if (Math.abs(s.sheetWidthMm - w) < 0.5 && Math.abs(s.sheetHeightMm - h) < 0.5) {
        return k as PaperPreset;
      }
    }
    return 'Custom';
  };

  const applyPreset = (p: PaperPreset) => {
    if (p !== 'Custom') {
      const [w, h] = PAPER_PRESETS[p];
      u({ sheetWidthMm: w, sheetHeightMm: h });
    }
  };

  return (
    <div className="space-y-3">
      <SectionTitle>Glue Tabs</SectionTitle>
      <Field label="Tab depth (mm)">
        <NumberInput value={s.tabWidthMm} min={0.5} max={30} step={0.5} onChange={(v) => u({ tabWidthMm: v })} />
      </Field>
      <Field label="Side angle (°)">
        <NumberInput value={s.tabAngleDeg} min={10} max={80} step={5} onChange={(v) => u({ tabAngleDeg: v })} />
      </Field>
      <Field label="Tab shape">
        <select
          value={s.tabShape}
          onChange={(e) => u({ tabShape: e.target.value as TabShape })}
          className="input-field w-28"
        >
          <option value="Trapezoid">Trapezoid</option>
          <option value="Rectangle">Rectangle</option>
          <option value="Triangle">Triangle</option>
        </select>
      </Field>
      <CheckField label="Alternate flap sides" checked={s.alternateFlaps} onChange={(v) => u({ alternateFlaps: v })} />

      <SectionTitle>Line Colors & Widths</SectionTitle>
      <Field label="Fold line color">
        <ColorInput value={s.foldLineColor} onChange={(v) => u({ foldLineColor: v })} />
      </Field>
      <Field label="Cut line color">
        <ColorInput value={s.cutLineColor} onChange={(v) => u({ cutLineColor: v })} />
      </Field>
      <Field label="Fold line width (mm)">
        <NumberInput value={s.foldLineWidth} min={0.1} max={3} step={0.1} onChange={(v) => u({ foldLineWidth: v })} />
      </Field>
      <Field label="Cut line width (mm)">
        <NumberInput value={s.cutLineWidth} min={0.1} max={3} step={0.1} onChange={(v) => u({ cutLineWidth: v })} />
      </Field>
      <Field label="Fold dash pattern">
        <input
          type="text"
          value={s.foldLineDash}
          onChange={(e) => u({ foldLineDash: e.target.value })}
          className="input-field w-24 font-mono"
          placeholder="4,2"
        />
      </Field>

      <SectionTitle>Paper & Layout</SectionTitle>
      <Field label="Paper preset">
        <select
          value={currentPreset()}
          onChange={(e) => applyPreset(e.target.value as PaperPreset)}
          className="input-field w-28"
        >
          {(['A4','A3','A2','A1','Letter','Legal','Custom'] as PaperPreset[]).map(p => (
            <option key={p} value={p}>{p}</option>
          ))}
        </select>
      </Field>
      <Field label="Width (mm)">
        <NumberInput value={s.sheetWidthMm} min={50} max={2000} step={1} onChange={(v) => u({ sheetWidthMm: v })} />
      </Field>
      <Field label="Height (mm)">
        <NumberInput value={s.sheetHeightMm} min={50} max={2000} step={1} onChange={(v) => u({ sheetHeightMm: v })} />
      </Field>
      <Field label="Pages wide">
        <NumberInput value={s.pagesWide} min={1} max={10} step={1} onChange={(v) => u({ pagesWide: Math.round(v) })} />
      </Field>
      <Field label="Pages tall">
        <NumberInput value={s.pagesTall} min={1} max={10} step={1} onChange={(v) => u({ pagesTall: Math.round(v) })} />
      </Field>
      <Field label="Margin (mm)">
        <NumberInput value={s.marginMm} min={0} max={50} step={1} onChange={(v) => u({ marginMm: v })} />
      </Field>

      <SectionTitle>Export</SectionTitle>
      <Field label="Scale factor">
        <NumberInput value={s.scaleFactor} min={0.1} max={10} step={0.1} onChange={(v) => u({ scaleFactor: v })} />
      </Field>
      <Field label="DPI">
        <NumberInput value={s.exportDpi} min={72} max={600} step={1} onChange={(v) => u({ exportDpi: Math.round(v) })} />
      </Field>
      <CheckField label="Grayscale output" checked={s.grayscaleOutput} onChange={(v) => u({ grayscaleOutput: v })} />
      <CheckField label="Include page label" checked={s.includePageLabel} onChange={(v) => u({ includePageLabel: v })} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main dialog
// ---------------------------------------------------------------------------

export function SettingsDialog() {
  const isOpen = useUIStore((s) => s.dialogs.settings);
  const close  = useUIStore((s) => s.closeDialog);
  const s      = useSettingsStore((st) => st.settings);
  const u      = useSettingsStore((st) => st.updateSettings);
  const save   = useSettingsStore((st) => st.saveSettings);

  const [tab, setTab] = useState<Tab>('General');

  if (!isOpen) return null;

  const handleClose = () => { save(); close('settings'); };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-background border border-border rounded-lg shadow-xl w-[480px] flex flex-col max-h-[80vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-4 pb-2 border-b border-border">
          <h2 className="font-semibold text-base">Settings</h2>
          <button onClick={handleClose} className="text-muted-foreground hover:text-foreground">
            <X size={18} />
          </button>
        </div>

        {/* Tab bar */}
        <div className="flex border-b border-border shrink-0">
          {TABS.map((t) => (
            <button
              key={t}
              className={`px-4 py-2 text-sm transition-colors ${
                tab === t
                  ? 'border-b-2 border-primary text-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
              onClick={() => setTab(t)}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Tab content */}
        <div className="p-5 overflow-y-auto text-sm flex-1">
          {tab === 'General' && <GeneralTab s={s} u={u} />}
          {tab === 'View 3D' && <View3DTab  s={s} u={u} />}
          {tab === 'View 2D' && <View2DTab  s={s} u={u} />}
          {tab === 'Print'   && <PrintTab   s={s} u={u} />}
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-2 px-5 pb-4 pt-3 border-t border-border shrink-0">
          <button
            onClick={() => useSettingsStore.getState().resetToDefaults()}
            className="px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground border border-border rounded"
          >
            Reset defaults
          </button>
          <button
            onClick={handleClose}
            className="px-4 py-1.5 bg-primary text-primary-foreground rounded text-sm hover:bg-primary/90"
          >
            Save &amp; Close
          </button>
        </div>
      </div>
    </div>
  );
}
