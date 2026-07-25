using System.Numerics;
using FluentAssertions;
using FourHUnfolder.Geometry.Algorithms;
using Xunit;

namespace FourHUnfolder.Tests;

/// Backlog Phase 7 (TD-38-4): "Select Symmetrical Pair". See SymmetryDetector.cs.
public class SymmetryDetectorTests
{
    // Mirror-symmetric about X=0: each point has a matching -X counterpart, plus one point
    // exactly on the plane (X=0, self-symmetric — a "spine" vertex).
    private static List<Vector3> SymmetricAboutXZero() =>
    [
        new(1, 0, 0), new(-1, 0, 0),
        new(2, 1, 0), new(-2, 1, 0),
        new(1.5f, 0, 2), new(-1.5f, 0, 2),
        new(3, -1, 1), new(-3, -1, 1),
        new(0, 0, 0),   // on the plane
    ];

    [Fact]
    public void DetectMirrorPlane_symmetricPointSet_findsXAxisAtCenterZero()
    {
        var plane = SymmetryDetector.DetectMirrorPlane(SymmetricAboutXZero());

        plane.Should().NotBeNull();
        plane!.Value.Axis.Should().Be(SymmetryDetector.Axis.X);
        plane.Value.Center.Should().BeApproximately(0f, 0.01f);
    }

    [Fact]
    public void DetectMirrorPlane_asymmetricPointSet_returnsNull()
    {
        // Scattered points with no mirror relationship on any axis.
        var points = new List<Vector3>
        {
            new(1, 2, 3), new(4, -5, 6), new(-7, 8, 2), new(3, 3, -9),
            new(0.5f, 7, 1), new(-2, -3, 5), new(6, 1, -4),
        };

        SymmetryDetector.DetectMirrorPlane(points).Should().BeNull();
    }

    [Fact]
    public void DetectMirrorPlane_emptyList_returnsNull()
    {
        SymmetryDetector.DetectMirrorPlane([]).Should().BeNull();
    }

    [Fact]
    public void DetectMirrorPlane_singlePoint_returnsNull()
    {
        // Degenerate bounding box (zero diagonal) — must not divide by zero or crash.
        SymmetryDetector.DetectMirrorPlane([new Vector3(5, 5, 5)]).Should().BeNull();
    }

    [Fact]
    public void Mirror_reflectsAcrossEachAxisCorrectly()
    {
        var p = new Vector3(3, 4, 5);
        SymmetryDetector.Mirror(p, SymmetryDetector.Axis.X, 0).Should().Be(new Vector3(-3, 4, 5));
        SymmetryDetector.Mirror(p, SymmetryDetector.Axis.Y, 0).Should().Be(new Vector3(3, -4, 5));
        SymmetryDetector.Mirror(p, SymmetryDetector.Axis.Z, 0).Should().Be(new Vector3(3, 4, -5));
        // Off-center plane: mirror(p, center=c) = 2c - p on that axis.
        SymmetryDetector.Mirror(p, SymmetryDetector.Axis.X, 10).Should().Be(new Vector3(17, 4, 5));
    }

    [Fact]
    public void FindMirrorPiece_picksTheClosestMirroredCentroid()
    {
        var plane = new SymmetryDetector.MirrorPlane(SymmetryDetector.Axis.X, 0f);
        var centroids = new Dictionary<int, Vector3>
        {
            [1] = new(5, 2, 0),     // picked piece
            [2] = new(-5, 2, 0),    // exact mirror of piece 1 -> should be picked
            [3] = new(-5, 9, 9),    // far away, wrong position, must NOT be picked
            [4] = new(5, 2, 0.1f),  // near piece 1 itself but on the SAME side, irrelevant
        };

        var result = SymmetryDetector.FindMirrorPiece(plane, pickedPieceId: 1, centroids);

        result.Should().Be(2);
    }

    [Fact]
    public void FindMirrorPiece_noCloseMatch_returnsNull()
    {
        var plane = new SymmetryDetector.MirrorPlane(SymmetryDetector.Axis.X, 0f);
        var centroids = new Dictionary<int, Vector3>
        {
            [1] = new(5, 2, 0),
            [2] = new(-5, 50, 50),   // mirrored X matches, but Y/Z are wildly different -> not a real pair
        };

        var result = SymmetryDetector.FindMirrorPiece(plane, pickedPieceId: 1, centroids, matchToleranceMm: 5.0f);

        result.Should().BeNull();
    }

    [Fact]
    public void FindMirrorPiece_pickedPieceNotInDictionary_returnsNull()
    {
        var plane = new SymmetryDetector.MirrorPlane(SymmetryDetector.Axis.X, 0f);
        var centroids = new Dictionary<int, Vector3> { [2] = new(-5, 2, 0) };

        SymmetryDetector.FindMirrorPiece(plane, pickedPieceId: 1, centroids).Should().BeNull();
    }

    [Fact]
    public void FindMirrorPiece_neverReturnsThePickedPieceItself()
    {
        // A piece exactly on the mirror plane has no distinct pair -- must not match itself.
        var plane = new SymmetryDetector.MirrorPlane(SymmetryDetector.Axis.X, 0f);
        var centroids = new Dictionary<int, Vector3>
        {
            [1] = new(0, 3, 3),   // sits exactly on the plane; its own mirror equals itself
        };

        SymmetryDetector.FindMirrorPiece(plane, pickedPieceId: 1, centroids).Should().BeNull();
    }
}
