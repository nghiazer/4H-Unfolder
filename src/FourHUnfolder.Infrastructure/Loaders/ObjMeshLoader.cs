using System.Globalization;
using System.Numerics;
using FourHUnfolder.Application.Interfaces;
using FourHUnfolder.Domain.Models;

namespace FourHUnfolder.Infrastructure.Loaders;

/// <summary>
/// Parses Wavefront OBJ files including UV texture coordinates and multiple materials.
/// Supports "v/vt", "v/vt/vn", "v//vn" face tokens and fan-triangulates n-gons.
/// </summary>
public class ObjMeshLoader : IMeshLoader
{
    public Mesh Load(string filePath)
    {
        var mesh  = new Mesh();
        var lines = File.ReadAllLines(filePath);

        // State for multi-material tracking
        int currentMaterialId = -1;
        var materialNameToId  = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        // deferred MTL loads: will be processed before first usemtl is encountered
        string? pendingMtlFile = null;
        string objDir = Path.GetDirectoryName(filePath) ?? string.Empty;

        foreach (var rawLine in lines)
        {
            var line  = rawLine.Trim();
            if (line.Length == 0 || line[0] == '#') continue;

            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) continue;

            switch (parts[0])
            {
                case "v" when parts.Length >= 4:
                    ParseVertex(mesh, parts);
                    break;

                case "vt" when parts.Length >= 3:
                    ParseUV(mesh, parts);
                    break;

                case "f" when parts.Length >= 4:
                    ParseFace(mesh, parts, currentMaterialId);
                    break;

                case "mtllib" when line.Length > 7:
                    // Use rest of line (after "mtllib ") to preserve filenames with spaces
                    pendingMtlFile = line[7..].Trim();
                    TryLoadMtl(mesh, objDir, pendingMtlFile, materialNameToId);
                    break;

                case "usemtl" when parts.Length >= 2:
                    var matName = string.Join(" ", parts.Skip(1));
                    if (!materialNameToId.TryGetValue(matName, out currentMaterialId))
                    {
                        // Material not in MTL yet — register on-the-fly
                        currentMaterialId = mesh.MaterialNames.Count;
                        materialNameToId[matName] = currentMaterialId;
                        mesh.MaterialNames.Add(matName);
                        mesh.MaterialTexturePaths.Add(null);
                    }
                    break;
            }
        }

        // Back-compat: set SuggestedTexturePath to first non-null material texture
        mesh.SuggestedTexturePath = mesh.MaterialTexturePaths.FirstOrDefault(p => p != null);

        return mesh;
    }

    // ── vertex / UV parsing ──────────────────────────────────────────────

    private static void ParseVertex(Mesh mesh, string[] parts)
    {
        float x = F(parts[1]);
        float y = F(parts[2]);
        float z = F(parts[3]);
        mesh.AddVertex(new Vertex(mesh.Vertices.Count, new Vector3(x, y, z)));
    }

    private static void ParseUV(Mesh mesh, string[] parts)
    {
        float u = F(parts[1]);
        float v = F(parts[2]);
        mesh.UVs.Add(new Vector2(u, v));
    }

    // ── face parsing ─────────────────────────────────────────────────────

    private static void ParseFace(Mesh mesh, string[] parts, int materialId)
    {
        var tokens = parts.Skip(1).ToArray();

        var posIdx = tokens.Select(t => SlotIndex(t, 0)).ToArray();
        var uvIdx  = tokens.Select(t => SlotIndex(t, 1)).ToArray();
        int vCount = mesh.Vertices.Count;

        for (int i = 1; i < posIdx.Length - 1; i++)
        {
            int a = posIdx[0], b = posIdx[i], c = posIdx[i + 1];
            if (a < 0 || a >= vCount || b < 0 || b >= vCount || c < 0 || c >= vCount)
                continue;

            int faceId = mesh.Faces.Count;
            mesh.AddFace(a, b, c, uvIdx[0], uvIdx[i], uvIdx[i + 1]);
            if (faceId < mesh.Faces.Count)
                mesh.Faces[faceId].MaterialId = materialId;
        }
    }

    private static int SlotIndex(string token, int slot)
    {
        var segs = token.Split('/');
        if (slot >= segs.Length || string.IsNullOrEmpty(segs[slot])) return -1;
        int idx = int.Parse(segs[slot], CultureInfo.InvariantCulture);
        return idx > 0 ? idx - 1 : -1;
    }

    // ── MTL loading ───────────────────────────────────────────────────────

    private static void TryLoadMtl(Mesh mesh, string objDir, string mtlName,
                                   Dictionary<string, int> materialNameToId)
    {
        var mtlPath = Path.Combine(objDir, mtlName);
        if (!File.Exists(mtlPath)) return;

        string? currentMatName = null;
        int     currentMatId   = -1;

        foreach (var rawLine in File.ReadAllLines(mtlPath))
        {
            var line  = rawLine.Trim();
            if (line.Length == 0 || line[0] == '#') continue;

            var parts = line.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 1) continue;

            if (parts[0].Equals("newmtl", StringComparison.OrdinalIgnoreCase) && parts.Length >= 2)
            {
                currentMatName = parts[1].Trim();
                if (!materialNameToId.TryGetValue(currentMatName, out currentMatId))
                {
                    currentMatId = mesh.MaterialNames.Count;
                    materialNameToId[currentMatName] = currentMatId;
                    mesh.MaterialNames.Add(currentMatName);
                    mesh.MaterialTexturePaths.Add(null);
                }
                continue;
            }

            if (parts[0].Equals("map_Kd", StringComparison.OrdinalIgnoreCase)
                && parts.Length >= 2 && currentMatId >= 0)
            {
                var texFile = parts[1].Trim();
                var texPath = Path.IsPathRooted(texFile)
                    ? texFile
                    : Path.Combine(objDir, texFile);

                if (File.Exists(texPath))
                    mesh.MaterialTexturePaths[currentMatId] = texPath;
            }
        }
    }

    private static float F(string s) =>
        float.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : 0f;
}
