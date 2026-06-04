namespace FourHUnfolder.Geometry.Algorithms;

/// <summary>
/// Path-compressed, union-by-rank Union-Find over a contiguous range [0, size).
/// </summary>
internal sealed class UnionFind
{
    private readonly int[] _parent;
    private readonly int[] _rank;

    public UnionFind(int size)
    {
        _parent = new int[size];
        _rank   = new int[size];
        for (int i = 0; i < size; i++) _parent[i] = i;
    }

    public int Find(int x)
    {
        if (_parent[x] != x) _parent[x] = Find(_parent[x]);
        return _parent[x];
    }

    /// Returns false if a and b were already in the same component.
    public bool Union(int a, int b)
    {
        a = Find(a); b = Find(b);
        if (a == b) return false;
        if (_rank[a] < _rank[b]) (a, b) = (b, a);
        _parent[b] = a;
        if (_rank[a] == _rank[b]) _rank[a]++;
        return true;
    }
}
