import { useSettingsStore } from '@/state/settingsStore';
import { useUIStore } from '@/state/uiStore';
import { X } from 'lucide-react';

export function SettingsDialog() {
  const isOpen     = useUIStore((s) => s.dialogs.settings);
  const close      = useUIStore((s) => s.closeDialog);
  const settings   = useSettingsStore((s) => s.settings);
  const update     = useSettingsStore((s) => s.updateSettings);
  const save       = useSettingsStore((s) => s.saveSettings);

  if (!isOpen) return null;

  const handleClose = () => {
    save();
    close('settings');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-background border border-border rounded-lg shadow-xl w-[400px] p-5">
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-semibold text-base">Settings</h2>
          <button onClick={handleClose} className="text-muted-foreground hover:text-foreground">
            <X size={18} />
          </button>
        </div>

        <div className="space-y-4 text-sm">
          <Field label="Tab width (mm)">
            <input
              type="number"
              min={0.5} max={30} step={0.5}
              value={settings.tabWidthMm}
              onChange={(e) => update({ tabWidthMm: parseFloat(e.target.value) })}
              className="input-field"
            />
          </Field>

          <Field label="Tab angle (°)">
            <input
              type="number"
              min={10} max={80} step={5}
              value={settings.tabAngleDeg}
              onChange={(e) => update({ tabAngleDeg: parseFloat(e.target.value) })}
              className="input-field"
            />
          </Field>

          <Field label="Sheet width (mm)">
            <input
              type="number"
              min={50} max={1200} step={1}
              value={settings.sheetWidthMm}
              onChange={(e) => update({ sheetWidthMm: parseFloat(e.target.value) })}
              className="input-field"
            />
          </Field>

          <Field label="Sheet height (mm)">
            <input
              type="number"
              min={50} max={1600} step={1}
              value={settings.sheetHeightMm}
              onChange={(e) => update({ sheetHeightMm: parseFloat(e.target.value) })}
              className="input-field"
            />
          </Field>

          <CheckField
            label="Auto-arrange pieces"
            checked={settings.autoArrange}
            onChange={(v) => update({ autoArrange: v })}
          />

          <CheckField
            label="Show fold lines"
            checked={settings.showFoldLines}
            onChange={(v) => update({ showFoldLines: v })}
          />

          <CheckField
            label="Show face labels"
            checked={settings.showFaceLabels}
            onChange={(v) => update({ showFaceLabels: v })}
          />

          <Field label="Theme">
            <select
              value={settings.theme}
              onChange={(e) => update({ theme: e.target.value as any })}
              className="input-field"
            >
              <option value="system">System</option>
              <option value="light">Light</option>
              <option value="dark">Dark</option>
            </select>
          </Field>
        </div>

        <div className="flex justify-end mt-5">
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

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="flex items-center justify-between gap-3">
      <span className="text-muted-foreground">{label}</span>
      {children}
    </label>
  );
}

function CheckField({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
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
