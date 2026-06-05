// MARK: - Union-Find with path compression + union by rank

final class UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        rank   = Array(repeating: 0, count: count)
    }

    func find(_ x: Int) -> Int {
        if parent[x] != x { parent[x] = find(parent[x]) }   // path compression
        return parent[x]
    }

    @discardableResult
    func union(_ a: Int, _ b: Int) -> Bool {
        let ra = find(a), rb = find(b)
        guard ra != rb else { return false }
        if rank[ra] < rank[rb]      { parent[ra] = rb }
        else if rank[ra] > rank[rb] { parent[rb] = ra }
        else                        { parent[rb] = ra; rank[ra] += 1 }
        return true
    }
}
