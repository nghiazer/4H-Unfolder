using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Domain.Models;
using FourHUnfolder.Domain.Settings;
using FourHUnfolder.Infrastructure.Exporters;
using Xunit;

namespace FourHUnfolder.Tests;

/// <summary>
/// Regression coverage for a cross-review finding: UnfoldService.TryBuildFromPdoLayout used to
/// build its UnfoldResult without dihedral angles, so HideCoplanarFolds silently did nothing for
/// PDO-imported models (SvgExporter/PdfExporter's coplanar check always failed on an empty dict).
/// </summary>
public class UnfoldServicePdoDihedralTests
{
    /// Two coplanar triangles (both in the z=0 plane, same winding) sharing edge v1-v2, both
    /// assigned to the same PDO part so that shared edge is classified as Fold.
    private static Mesh CoplanarTwoTriangleMesh()
    {
        var mesh = new Mesh();
        mesh.AddVertex(new Vertex(0, new Vector3(0, 0, 0)));
        mesh.AddVertex(new Vertex(1, new Vector3(1, 0, 0)));
        mesh.AddVertex(new Vertex(2, new Vector3(0, 1, 0)));
        mesh.AddVertex(new Vertex(3, new Vector3(1, 1, 0)));

        mesh.AddFace(0, 1, 2);  // face 0
        mesh.AddFace(1, 3, 2);  // face 1 — shares edge v1-v2 with face 0, same plane (z=0)

        var layout = new PdoLayout();
        layout.Faces.Add(new PdoFace(0, 0, new Vector2(0, 0), new Vector2(10, 0), new Vector2(0, 10)));
        layout.Faces.Add(new PdoFace(1, 0, new Vector2(10, 0), new Vector2(20, 0), new Vector2(10, 10)));
        mesh.PdoLayout = layout;
        return mesh;
    }

    [Fact]
    public void TryBuildFromPdoLayout_PopulatesEdgeDihedralAngles()
    {
        var mesh   = CoplanarTwoTriangleMesh();
        var result = new UnfoldService().TryBuildFromPdoLayout(mesh);

        result.Should().NotBeNull();
        result!.EdgeDihedralAngles.Should().NotBeEmpty(
            "the shared edge's dihedral angle must be computed even for PDO layouts");

        var sharedEdge = mesh.Edges.Single(e => e.FaceA >= 0 && e.FaceB >= 0);
        result.EdgeDihedralAngles.Should().ContainKey(sharedEdge.Id);
        result.EdgeDihedralAngles[sharedEdge.Id].Should().BeApproximately(0f, 0.5f,
            "both triangles lie flat in the z=0 plane");
    }

    private static string ExportSvg(Mesh mesh, bool hideCoplanar)
    {
        var settings = new AppSettings();
        settings.Print.PrintFoldLines     = true;
        settings.Print.HideCoplanarFolds  = hideCoplanar;
        settings.Print.CoplanarAngleDeg   = 1.0;

        var ss = new SettingsService();
        ss.Apply(settings);

        var result = new UnfoldService().TryBuildFromPdoLayout(mesh, settings.Print)!;
        var path = Path.Combine(Path.GetTempPath(), $"pdo_coplanar_{Guid.NewGuid():N}.svg");
        new SvgExporter(ss).Export(result, path);
        var svg = File.ReadAllText(path);
        File.Delete(path);
        return svg;
    }

    [Fact]
    public void PdoLayout_CoplanarFoldLine_Suppressed_WhenHideEnabled()
        => ExportSvg(CoplanarTwoTriangleMesh(), hideCoplanar: true).Should().NotContain("class=\"fold\"");

    [Fact]
    public void PdoLayout_FoldLine_Drawn_WhenHideDisabled()
        => ExportSvg(CoplanarTwoTriangleMesh(), hideCoplanar: false).Should().Contain("class=\"fold\"");
}
