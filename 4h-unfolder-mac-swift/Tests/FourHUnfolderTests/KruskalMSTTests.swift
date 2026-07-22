import XCTest
@testable import FourHUnfolderCore

final class KruskalMSTTests: XCTestCase {

    func testTetrahedron_returnsNMinusOneEdges() {
        let mesh = TestMesh.tetrahedron()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        let mst  = KruskalMSTBuilder().build(graph: dg)
        XCTAssertEqual(mst.count, mesh.faces.count - 1,
                       "Tetrahedron (4 faces) → MST has 3 fold edges")
    }

    func testCube_returnsNMinusOneEdges() {
        let mesh = TestMesh.cube()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        let mst  = KruskalMSTBuilder().build(graph: dg)
        XCTAssertEqual(mst.count, mesh.faces.count - 1,
                       "Cube (12 tri faces) → MST has 11 fold edges")
    }

    func testDisconnectedMesh_returnsEmptyMST() {
        let mesh = TestMesh.twoSeparateTriangles()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        let mst  = KruskalMSTBuilder().build(graph: dg)
        // Two components with no shared edges → 0 interior graph edges → empty MST
        XCTAssertEqual(mst.count, 0, "Disconnected triangles: no fold edges possible")
    }

    func testFlatStrip_returnsNMinusOneEdges() {
        let mesh = TestMesh.flatStrip()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        let mst  = KruskalMSTBuilder().build(graph: dg)
        XCTAssertEqual(mst.count, mesh.faces.count - 1,
                       "Flat strip (3 faces) → MST has 2 fold edges")
    }

    func testMSTEdgesAreUnique() {
        let mesh = TestMesh.cube()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        let mst  = KruskalMSTBuilder().build(graph: dg)
        let uniqueIds = Set(mst.map { $0.sharedMeshEdgeId })
        XCTAssertEqual(uniqueIds.count, mst.count, "MST contains no duplicate mesh edges")
    }

    func testMSTEdges_referenceValidMeshEdges() {
        let mesh = TestMesh.tetrahedron()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        let mst  = KruskalMSTBuilder().build(graph: dg)
        for edge in mst {
            XCTAssertTrue(edge.sharedMeshEdgeId >= 0 &&
                          edge.sharedMeshEdgeId < mesh.edges.count,
                          "MST edge ID must reference a valid mesh edge")
        }
    }

    func testDualGraph_nodeCount_equalseFaceCount() {
        let mesh = TestMesh.cube()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        XCTAssertEqual(dg.nodes.count, mesh.faces.count)
    }

    func testDualGraph_edgeWeights_areNonNegative() {
        let mesh = TestMesh.cube()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        for edge in dg.edges {
            XCTAssertGreaterThanOrEqual(edge.weight, 0,
                "Dihedral angle weight must be non-negative")
        }
    }

    // MARK: - tieBreakSeed (GĐ3.2: used by UnfoldService's multi-seed overlap retry)
    //
    // A regular tetrahedron's dual graph is K4 with all-equal dihedral angles (every pair of the
    // 4 faces is geometrically equivalent), so Kruskal ties on every one of the 6 edges — exactly
    // the scenario the tie-break perturbation is built for.

    func testTieBreakSeed_nil_matchesDefaultNoSeedParameter() {
        let mesh = TestMesh.tetrahedron()
        let dg   = DualGraphBuilder().build(mesh: mesh)

        let withoutSeedParam = KruskalMSTBuilder().build(graph: dg)
        let withExplicitNil  = KruskalMSTBuilder().build(graph: dg, tieBreakSeed: nil)

        XCTAssertEqual(withExplicitNil.map(\.id), withoutSeedParam.map(\.id),
                       "an explicit nil seed must match omitting the parameter entirely")
    }

    func testTieBreakSeed_alwaysReturnsValidSpanningTree() {
        let mesh = TestMesh.tetrahedron()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        for seed in [0, 1, 2, 5, 42] {
            let mst = KruskalMSTBuilder().build(graph: dg, tieBreakSeed: seed)
            XCTAssertEqual(mst.count, mesh.faces.count - 1,
                          "seed \(seed) must still produce a valid n-1 spanning tree")
        }
    }

    func testTieBreakSeed_producesVariedMstsAcrossEqualWeightTies() {
        let mesh = TestMesh.tetrahedron()
        let dg   = DualGraphBuilder().build(mesh: mesh)

        let distinctResults = Set((0..<20).map { seed -> String in
            let mst = KruskalMSTBuilder().build(graph: dg, tieBreakSeed: seed)
            return mst.map(\.id).sorted().map(String.init).joined(separator: ",")
        })

        XCTAssertGreaterThan(distinctResults.count, 1,
            "different tie-break seeds must be able to select a different spanning tree " +
            "among equal-weight ties — otherwise the multi-seed overlap retry can never help")
    }
}
