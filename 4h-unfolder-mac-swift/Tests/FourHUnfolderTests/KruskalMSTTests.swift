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
}
