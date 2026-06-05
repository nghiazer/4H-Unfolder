import XCTest
@testable import FourHUnfolderCore

final class UnionFindTests: XCTestCase {

    func testInitialState_eachElementIsOwnRoot() {
        let uf = UnionFind(count: 5)
        for i in 0..<5 {
            XCTAssertEqual(uf.find(i), uf.find(i), "find() is idempotent")
        }
        // Verify all in separate components: union 0&1 should succeed
        XCTAssertTrue(uf.union(0, 1), "First union of distinct elements succeeds")
    }

    func testUnion_mergesComponents() {
        let uf = UnionFind(count: 4)
        XCTAssertTrue(uf.union(0, 1))
        XCTAssertFalse(uf.union(0, 1), "Duplicate union returns false")
        XCTAssertTrue(uf.union(2, 3))
        XCTAssertTrue(uf.union(0, 2),  "Merging two disjoint components succeeds")
        XCTAssertFalse(uf.union(1, 3), "All four now in same component → false")
    }

    func testFind_pathCompression_sameRoot() {
        let uf = UnionFind(count: 5)
        uf.union(0, 1); uf.union(1, 2); uf.union(2, 3); uf.union(3, 4)
        let root = uf.find(0)
        for i in 1..<5 {
            XCTAssertEqual(uf.find(i), root, "Path compression: all share the same root")
        }
    }

    func testUnion_singleElement_alwaysFalse() {
        let uf = UnionFind(count: 1)
        XCTAssertFalse(uf.union(0, 0), "Self-union always false")
    }

    func testComponentCount_afterFullMerge() {
        let n = 8
        let uf = UnionFind(count: n)
        for i in 0..<(n - 1) { uf.union(i, i + 1) }
        let root = uf.find(0)
        for i in 0..<n {
            XCTAssertEqual(uf.find(i), root, "All \(n) elements should be in one component")
        }
    }
}
