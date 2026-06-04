import { open } from '@tauri-apps/plugin-dialog';
import { useMeshStore } from '@/state/meshStore';
import { tauriCommands } from '@/types/tauri';

const SUPPORTED_EXTS = ['obj', 'pdo', 'fbx', 'glb', 'gltf', 'dae', 'stl', 'ply', '3ds'];

/** Open a file dialog and load the selected mesh via the universal load_mesh command. */
export async function openMeshFileDialog(): Promise<void> {
  const path = await open({
    multiple: false,
    filters: [{ name: '3D Models', extensions: SUPPORTED_EXTS }],
  });
  if (!path || typeof path !== 'string') return;
  await loadMeshFromPath(path);
}

/** Load mesh from a file path using the backend load_mesh dispatch. */
export async function loadMeshFromPath(path: string): Promise<void> {
  const store = useMeshStore.getState();
  // Use loadFromPath for OBJ (handles dir resolution for MTL textures)
  const ext = path.split('.').pop()?.toLowerCase() ?? '';
  if (ext === 'obj') {
    await store.loadFromPath(path);
    return;
  }

  useMeshStore.setState((s) => ({ ...s, loading: true, error: null }));
  try {
    const mesh = await tauriCommands.loadMesh(path);
    const name = path.split('/').pop() ?? path;
    useMeshStore.setState((s) => ({
      ...s,
      mesh,
      filePath: path,
      fileName: name,
      loading: false,
    }));
  } catch (err) {
    useMeshStore.setState((s) => ({ ...s, error: String(err), loading: false }));
  }
}

/** Handle a file dragged onto the canvas. */
export async function handleDroppedFile(path: string): Promise<void> {
  const ext = path.split('.').pop()?.toLowerCase() ?? '';
  if (!SUPPORTED_EXTS.includes(ext)) return;
  await loadMeshFromPath(path);
}
