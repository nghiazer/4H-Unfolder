using System.Text.Json;
using FluentAssertions;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Domain.Persistence;
using Xunit;

namespace FourHUnfolder.Tests;

public class ProjectSerializerTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ProjectSerializer _sut = new();

    public ProjectSerializerTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "4hu_tests_" + Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose() => Directory.Delete(_tempDir, recursive: true);

    private string Write(string json)
    {
        var path = Path.Combine(_tempDir, Guid.NewGuid().ToString("N") + ".pmc");
        File.WriteAllText(path, json);
        return path;
    }

    // ── Version gate ──────────────────────────────────────────────────────────

    [Fact]
    public void Load_CurrentVersion_Succeeds()
    {
        var json = JsonSerializer.Serialize(new ProjectState { Version = ProjectSerializer.CurrentVersion });
        var path = Write(json);
        var act  = () => _sut.Load(path);
        act.Should().NotThrow();
    }

    [Fact]
    public void Load_FutureVersion_Throws()
    {
        var json = JsonSerializer.Serialize(new ProjectState { Version = ProjectSerializer.CurrentVersion + 1 });
        var path = Write(json);
        var act  = () => _sut.Load(path);
        act.Should().Throw<InvalidDataException>()
            .WithMessage("*newer version*");
    }

    [Fact]
    public void Load_Version1_Succeeds()
    {
        // Version 1 files are still valid; they just have fewer fields.
        var json = JsonSerializer.Serialize(new ProjectState { Version = 1 });
        var path = Write(json);
        var state = _sut.Load(path);
        state.Version.Should().Be(1);
    }

    // ── Path resolution ───────────────────────────────────────────────────────

    [Fact]
    public void Load_MeshPathNotFound_AddsMissingWarning()
    {
        var state = new ProjectState
        {
            Version  = ProjectSerializer.CurrentVersion,
            MeshPath = $"does_not_exist.obj|/absolute/does_not_exist.obj"
        };
        var path    = Write(JsonSerializer.Serialize(state));
        var loaded  = _sut.Load(path);
        loaded.MeshPath.Should().BeNull("file does not exist");
        loaded.Warnings.Should().ContainMatch("*Mesh file not found*");
    }

    [Fact]
    public void Load_SystemFilePath_NotAllowedAsAsset()
    {
        // A crafted .pmc that points at a system file should be rejected.
        // On any OS the file below has no recognised mesh extension → rejected.
        var systemFilePath = Path.Combine(Path.GetTempPath(), "fake_system.exe");
        File.WriteAllText(systemFilePath, "not a mesh");

        var state = new ProjectState
        {
            Version  = ProjectSerializer.CurrentVersion,
            MeshPath = $"relative.exe|{systemFilePath}"
        };
        var path   = Write(JsonSerializer.Serialize(state));
        var loaded = _sut.Load(path);
        loaded.MeshPath.Should().BeNull("exe extension is not an allowed asset type");

        File.Delete(systemFilePath);
    }

    // ── Save/Load round-trip ──────────────────────────────────────────────────

    [Fact]
    public void SaveLoad_RoundTrip_PreservesScaleAndMirror()
    {
        var original = new ProjectState
        {
            Version        = ProjectSerializer.CurrentVersion,
            ScaleMmPerUnit = 3.14,
            MirrorX        = true,
        };
        var savePath = Path.Combine(_tempDir, "test.pmc");
        _sut.Save(original, savePath);
        var loaded = _sut.Load(savePath);

        loaded.ScaleMmPerUnit.Should().BeApproximately(3.14, 1e-9);
        loaded.MirrorX.Should().BeTrue();
    }

    [Fact]
    public void SaveLoad_RoundTrip_PreservesEdgeOverrides()
    {
        var original = new ProjectState { Version = ProjectSerializer.CurrentVersion };
        original.EdgeOverrides[5]  = "Fold";
        original.EdgeOverrides[12] = "Cut";

        var savePath = Path.Combine(_tempDir, "test_eo.pmc");
        _sut.Save(original, savePath);
        var loaded = _sut.Load(savePath);

        loaded.EdgeOverrides.Should().ContainKey(5).WhoseValue.Should().Be("Fold");
        loaded.EdgeOverrides.Should().ContainKey(12).WhoseValue.Should().Be("Cut");
    }

    [Fact]
    public void SaveLoad_RoundTrip_PreservesFlapOverrides()
    {
        var original = new ProjectState { Version = ProjectSerializer.CurrentVersion };
        original.FlapOverrides[7] = "Border_MountainFold,3";

        var savePath = Path.Combine(_tempDir, "test_fo.pmc");
        _sut.Save(original, savePath);
        var loaded = _sut.Load(savePath);

        loaded.FlapOverrides.Should().ContainKey(7).WhoseValue.Should().Be("Border_MountainFold,3");
    }
}
