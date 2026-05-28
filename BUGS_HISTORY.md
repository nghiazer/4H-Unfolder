# 4H-Unfolder — Bug & Session History Archive

> Archived sessions (oldest first). Current 2 sessions are in [`SESSION_PROGRESS.md`](SESSION_PROGRESS.md).

---

## Session 37 — Changes

| Item | Detail |
|------|--------|
| **Branch** | `fix/theme-system` — branched from `fix/ui-ux-polish` @ v0.0.3.D |
| **Theme root cause** | `ThemeService.Apply()` used `merged.Insert(0, newDict)` → theme inserted at index 0 (lowest priority); App.xaml's static `LightTheme.xaml` at higher index always won every `DynamicResource` lookup → dark theme never applied to any binding except code-set values |
| **ThemeService core fix** | Changed `merged.Insert(0,…)` → `merged.Add(…)` — last entry wins in WPF `MergedDictionaries`; now the applied theme always overrides App.xaml's static baseline |
| **4 new theme keys** | Added `WarningTextFg`, `ColorSwatchBorderBrush`, `TransparencyCheckerA/B` to both `DarkTheme.xaml` and `LightTheme.xaml` |
| **WarningTextFg** | `ModelOrientationDialog.xaml`: hardcoded `#ff6666` → `{DynamicResource WarningTextFg}` — warning text now adjusts shade per theme |
| **ColorSwatchBorderBrush** | `SettingsDialog.xaml`: 17× `Stroke="#666"` → `{DynamicResource ColorSwatchBorderBrush}` — swatch borders visible in both themes |
| **CheckerBrush — freeze workaround** | `TextureDialog.xaml.cs`: `ApplyCheckerBrush()` builds `DrawingBrush` in code-behind using `TryFindResource("TransparencyCheckerA/B")`, stores in `Window.Resources["CheckerBrush"]`; XAML uses `{DynamicResource CheckerBrush}`; `OnActivated` override re-builds brush so live theme switch is picked up when dialog is re-focused |
| **ViewportBorderBrush** | `MainViewModel.cs`: getter now uses `TryFindResource("SplitterBg")` instead of hardcoded `#3d3d5c`; `OnSettingsChanged` notifies binding after `Apply()` |
| **Version** | `0.0.3.4 → 0.0.3.5` (v0.0.3.D → v0.0.3.E) |
| **Tests** | 56 / 56 pass |

---

## Session 36 — Changes

| Item | Detail |
|------|--------|
| **Branch** | `fix/ui-ux-polish` — branched from `main` @ v0.0.3.C |
| **Maximize on startup** | `MainWindow.xaml`: added `WindowState="Maximized"` — app opens fullscreen by default; `Width`/`Height` kept at 1400×900 for restore size |
| **ModelOrientationDialog — layout** | Right column widened `180→210 px`; added `TextWrapping="Wrap"` to "Up axis" and "Front axis" label TextBlocks — text no longer clips at minimum dialog width |
| **ModelOrientationDialog — buttons** | Added `HorizontalContentAlignment="Center"` to OK + Skip; removed whitespace-padding hack from `Content="  OK  "` |
| **UnfoldSetupDialog — buttons** | Added `HorizontalContentAlignment="Center"` to OK + Cancel |
| **UnfoldSetupDialog — inputs** | TextBox style: added `VerticalContentAlignment="Center"` + changed `Padding="4,2"→"4,0"` — text vertically centred in 26 px input rows |
| **2D Align icons** | Replaced non-descriptive icons with semantic Unicode characters: Left `⬛→◧`, CenterV `▪→◫`, Right `⬜→◨`, Top `🔼→⊤`, Bottom `🔽→⊥`, CenterH `↔→↕` |
| **Version** | `0.0.3.3 → 0.0.3.4` (v0.0.3.C → v0.0.3.D) |
| **Tests** | 56 / 56 pass |

---

## Sessions 1–35

Recorded in tech-debt table and commit history. Key milestones:

| Sessions | Work |
|----------|------|
| s1–s20 | Core pipeline: OBJ load, MST, BFS unfold, SVG/PDF export, basic 2D canvas |
| s21–s25 | Interactive canvas: drag, rotate, snap, undo/redo, lasso, assembly animation |
| s26–s29 | Multi-texture, edge-edit mode, rotate-by-point, auto-align, parts alignment |
| s30–s35 | PDO import (v3/PD6): parser, 2D layout, multi-texture, BUG-PDO-1/2/3, auto-arrange formula fix |
