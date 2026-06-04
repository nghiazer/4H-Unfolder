import { Upload } from 'lucide-react';
import { openMeshFileDialog } from '@/services/meshLoader';

export function DropZone() {
  return (
    <div
      className="absolute inset-0 flex flex-col items-center justify-center
                 text-muted-foreground cursor-pointer select-none
                 hover:bg-muted/30 transition-colors"
      onClick={openMeshFileDialog}
    >
      <Upload size={48} strokeWidth={1} className="mb-4 opacity-40" />
      <p className="text-lg font-medium opacity-60">Drop a 3D model here</p>
      <p className="text-sm opacity-40 mt-1">Supports .obj — or click to browse</p>
    </div>
  );
}
