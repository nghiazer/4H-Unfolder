using System.Numerics;
using FourHUnfolder.Domain.Results;

namespace FourHUnfolder.Application.Interfaces;

public interface IExporter
{
    /// <param name="texturePath">
    /// Optional fallback diffuse texture path (used when a face has no material or
    /// its material has no entry in <paramref name="perMaterialTextures"/>).
    /// </param>
    /// <param name="perMaterialTextures">
    /// Optional per-material texture paths keyed by <see cref="UnfoldedFace.MaterialId"/>.
    /// Takes precedence over <paramref name="texturePath"/> for faces whose material is found here.
    /// </param>
    /// <param name="paddingPolygons">
    /// Optional list of pre-computed inflated boundary polygons (one per piece) in the
    /// same coordinate space as <paramref name="result"/> faces.  When provided, each
    /// polygon is exported as a dashed outline guide for cutting.
    /// </param>
    void Export(UnfoldResult result, string filePath,
                string? texturePath = null,
                IReadOnlyDictionary<int, string?>? perMaterialTextures = null,
                IReadOnlyList<IReadOnlyList<Vector2>>? paddingPolygons = null);
}
