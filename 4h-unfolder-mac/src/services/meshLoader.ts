import { open } from '@tauri-apps/plugin-dialog';
import { readFile } from '@tauri-apps/plugin-fs';
import { useMeshStore } from '@/state/meshStore';

const SUPPORTED_EXTS = ['obj', 'gltf', 'glb', 'pdo'];

export async function openMeshFileDialog(): Promise<void> {
  const path = await open({
    multiple: false,
    filters: [
      {
        name: '3D Models',
        extensions: SUPPORTED_EXTS,
      },
    ],
  });

  if (!path || typeof path !== 'string') return;

  const ext = path.split('.').pop()?.toLowerCase() ?? '';

  if (ext === 'obj') {
    await useMeshStore.getState().loadFromPath(path);
  } else {
    // For unsupported formats, read as bytes and let the backend decide.
    const bytes = await readFile(path);
    const name  = path.split('/').pop() ?? path;
    await useMeshStore.getState().loadFromBytes(bytes, name);
  }
}

/** Handle a file dragged onto the window. */
export async function handleDroppedFile(path: string): Promise<void> {
  const ext = path.split('.').pop()?.toLowerCase() ?? '';
  if (!SUPPORTED_EXTS.includes(ext)) return;

  if (ext === 'obj') {
    await useMeshStore.getState().loadFromPath(path);
  } else {
    const bytes = await readFile(path);
    const name  = path.split('/').pop() ?? path;
    await useMeshStore.getState().loadFromBytes(bytes, name);
  }
}
