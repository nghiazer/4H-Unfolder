import XCTest
import simd
@testable import FourHUnfolderCore

final class UnfoldEngineTests: XCTestCase {

    // MARK: - Tetrahedron

    func testTetrahedron_faceCount() {
        let faces = TestMesh.runUnfold(TestMesh.tetrahedron())
        XCTAssertEqual(faces.count, 4, "Tetrahedron unfold must produce 4 2D faces")
    }

    func testTetrahedron_noOverlaps() {
        let faces = TestMesh.runUnfold(TestMesh.tetrahedron())
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: faces),
                       "MST unfold of a tetrahedron should be overlap-free")
    }

    func testTetrahedron_rootFaceEdgeLengthsPreserved() {
        // Root face is placed at the origin — its edge lengths should equal 1.0
        // (regular tetrahedron with unit edge length).
        let faces = TestMesh.runUnfold(TestMesh.tetrahedron())
        let root  = faces[0]
        let d01 = simd_length(root.v1 - root.v0)
        let d12 = simd_length(root.v2 - root.v1)
        let d20 = simd_length(root.v0 - root.v2)
        XCTAssertEqual(d01, 1.0, accuracy: 1e-4)
        XCTAssertEqual(d12, 1.0, accuracy: 1e-4)
        XCTAssertEqual(d20, 1.0, accuracy: 1e-4)
    }

    func testTetrahedron_childEdgeLengthsPreserved() {
        // All unfolded faces should have unit edge lengths (regular tetrahedron).
        let faces = TestMesh.runUnfold(TestMesh.tetrahedron())
        for face in faces {
            let sides = [
                simd_length(face.v1 - face.v0),
                simd_length(face.v2 - face.v1),
                simd_length(face.v0 - face.v2),
            ]
            for s in sides {
                XCTAssertEqual(s, 1.0, accuracy: 1e-3,
                               "All tetrahedron edges are unit length — 2D unfold must preserve this")
            }
        }
    }

    func testTetrahedron_rootPlacedAtOrigin() {
        let faces = TestMesh.runUnfold(TestMesh.tetrahedron())
        // Root face: v0 = (0,0), v1 = (1,0)
        XCTAssertEqual(faces[0].v0.x, 0, accuracy: 1e-5)
        XCTAssertEqual(faces[0].v0.y, 0, accuracy: 1e-5)
        XCTAssertEqual(faces[0].v1.x, 1, accuracy: 1e-4)
        XCTAssertEqual(faces[0].v1.y, 0, accuracy: 1e-5)
    }

    // MARK: - Cube

    func testCube_faceCount() {
        let faces = TestMesh.runUnfold(TestMesh.cube())
        XCTAssertEqual(faces.count, 12, "Fan-triangulated cube has 12 faces")
    }

    func testCube_noOverlaps() {
        let faces = TestMesh.runUnfold(TestMesh.cube())
        XCTAssertFalse(OverlapDetector().hasOverlaps(faces: faces),
                       "MST unfold of a cube should be overlap-free")
    }

    func testCube_dihedralAngles_allNinety() {
        let mesh = TestMesh.cube()
        let dg   = DualGraphBuilder().build(mesh: mesh)
        let mst  = KruskalMSTBuilder().build(graph: dg)
        let folds = Set(mst.map { $0.sharedMeshEdgeId })
        EdgeMarker().mark(mesh: mesh, foldEdgeIds: folds)
        let eng = UnfoldEngine().unfold(mesh: mesh, foldEdgeIds: folds)
        for (_, angleDeg) in eng.dihedralAngles {
            XCTAssertEqual(angleDeg, 90, accuracy: 0.5,
                           "All cube edges have ~90° dihedral angle")
        }
    }

    func testCube_foldEdgeCount_isNMinusOne() {
        let faces = TestMesh.runUnfold(TestMesh.cube())
        let foldCount = faces.flatMap {
            [$0.edge0IsFold, $0.edge1IsFold, $0.edge2IsFold]
        }.filter { $0 }.count
        // MST gives 11 fold edges; each fold edge is shared between 2 faces
        // so it appears in 2 faces' edge lists → 22 fold-edge references
        XCTAssertEqual(foldCount, 22, "11 MST fold edges × 2 faces each = 22 fold edge references")
    }

    // MARK: - Disconnected mesh

    func testDisconnectedMesh_bothFacesPlaced() {
        let faces = TestMesh.runUnfold(TestMesh.twoSeparateTriangles())
        XCTAssertEqual(faces.count, 2, "Both disconnected triangles must be placed")
    }

    func testDisconnectedMesh_pieceCount() {
        let mesh = TestMesh.twoSeparateTriangles()
        TestMesh.runUnfold(mesh)   // stamps EdgeTypes
        let pieces = PieceComputer().computePieces(mesh: mesh)
        XCTAssertEqual(pieces.count, 2, "Two separate triangles = 2 pieces")
    }

    // MARK: - Edge override

    func testEdgeOverride_forceAllCut_noFoldEdges() {
        let mesh = TestMesh.tetrahedron()
        let allCut = Dictionary(uniqueKeysWithValues: mesh.edges.map { ($0.id, EdgeType.cut) })
        let faces  = TestMesh.runUnfold(mesh, edgeOverrides: allCut)
        let foldCount = faces.flatMap {
            [$0.edge0IsFold, $0.edge1IsFold, $0.edge2IsFold]
        }.filter { $0 }.count
        XCTAssertEqual(foldCount, 0, "Forcing all edges to cut produces zero fold-edge references")
    }

    // MARK: - Empty / degenerate mesh

    func testEmptyMesh_returnsEmpty() {
        let mesh  = Mesh()
        let faces = UnfoldEngine().unfold(mesh: mesh, foldEdgeIds: []).faces
        XCTAssertTrue(faces.isEmpty)
    }
}
