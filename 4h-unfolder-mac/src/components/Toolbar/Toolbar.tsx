import { MousePointer2, Hand, Scissors, LayoutGrid, Download, Settings, FolderOpen, Zap, Box, Ruler, FlipHorizontal, PackageOpen } from 'lucide-react';
import { useUIStore, type EditorMode } from '@/state/uiStore';
import { useUnfoldStore } from '@/state/unfoldStore';
import { useMeshStore } from '@/state/meshStore';
import { openMeshFileDialog } from '@/services/meshLoader';
import { exportSvgDialog } from '@/services/exportService';
import { ToolbarButton } from './ToolbarButton';
import { Separator } from './Separator';

interface Props {
  showAssembly:      boolean;
  onToggleAssembly:  () => void;
}

export function Toolbar({ showAssembly, onToggleAssembly }: Props) {
  const mode             = useUIStore((s) => s.mode);
  const setMode          = useUIStore((s) => s.setMode);
  const openDialog       = useUIStore((s) => s.openDialog);
  const showViewport3D   = useUIStore((s) => s.showViewport3D);
  const toggleViewport3D = useUIStore((s) => s.toggleViewport3D);
  const unfold     = useUnfoldStore((s) => s.unfold);
  const unfolding  = useUnfoldStore((s) => s.unfolding);
  const hasMesh    = useMeshStore((s) => s.mesh !== null);
  const hasResult  = useUnfoldStore((s) => s.response !== null);

  const modeBtn = (m: EditorMode, icon: React.ReactNode, label: string) => (
    <ToolbarButton
      icon={icon}
      label={label}
      active={mode === m}
      onClick={() => setMode(m)}
    />
  );

  return (
    <div className="flex items-center gap-1 px-2 py-1.5 bg-toolbar border-b border-border select-none">
      {/* File */}
      <ToolbarButton icon={<FolderOpen size={16} />} label="Open (⌘O)" onClick={openMeshFileDialog} />

      {/* 3D Viewport toggle */}
      <ToolbarButton
        icon={<Box size={16} />}
        label="3D Viewport"
        active={showViewport3D}
        onClick={toggleViewport3D}
      />

      <Separator />

      {/* Edit modes */}
      {modeBtn('select',    <MousePointer2 size={16} />, 'Select (S)')}
      {modeBtn('pan',       <Hand size={16} />,          'Pan (H)')}
      {modeBtn('editFlaps', <Scissors size={16} />,      'Edit Flaps (F)')}

      <Separator />

      {/* Unfold */}
      <ToolbarButton
        icon={<Zap size={16} />}
        label="Unfold (U)"
        disabled={!hasMesh || unfolding}
        loading={unfolding}
        onClick={unfold}
      />

      <Separator />

      {/* Model transforms */}
      <ToolbarButton
        icon={<Ruler size={16} />}
        label="Scale model"
        disabled={!hasMesh}
        onClick={() => openDialog('scale')}
      />
      <ToolbarButton
        icon={<FlipHorizontal size={16} />}
        label="Orientation"
        disabled={!hasMesh}
        onClick={() => openDialog('orient')}
      />

      <Separator />

      {/* Layout & Export */}
      <ToolbarButton
        icon={<LayoutGrid size={16} />}
        label="Auto-arrange"
        disabled={!hasResult}
        onClick={() => {/* trigger re-arrange */}}
      />
      <ToolbarButton
        icon={<Download size={16} />}
        label="Export SVG (⌘S)"
        disabled={!hasResult}
        onClick={exportSvgDialog}
      />

      <Separator />

      {/* Assembly */}
      <ToolbarButton
        icon={<PackageOpen size={16} />}
        label="Assembly"
        active={showAssembly}
        disabled={!hasResult}
        onClick={onToggleAssembly}
      />

      <div className="flex-1" />

      <ToolbarButton icon={<Settings size={16} />} label="Settings (⌘,)" onClick={() => openDialog('settings')} />
    </div>
  );
}
