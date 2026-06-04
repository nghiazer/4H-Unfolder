namespace FourHUnfolder.Domain.Results;

/// <summary>
/// One step in the paper-model assembly sequence: add one piece (connected
/// component of fold edges) to the growing 3-D structure.
/// Steps are ordered so that each piece is adjacent (via a cut/glue edge)
/// to at least one already-placed piece, except the root (step 0).
/// </summary>
public sealed class AssemblyStep
{
    /// 0-based index in the assembly sequence.
    public int StepIndex { get; }

    /// GroupId of the piece being added at this step
    /// (== minimum faceId in the connected component).
    public int GroupId { get; }

    /// GroupId of the piece this one attaches to.  -1 for the root piece.
    public int ParentGroupId { get; }

    /// Face IDs belonging to this piece.
    public IReadOnlyList<int> FaceIds { get; }

    public AssemblyStep(int stepIndex, int groupId, int parentGroupId,
                        IReadOnlyList<int> faceIds)
    {
        StepIndex     = stepIndex;
        GroupId       = groupId;
        ParentGroupId = parentGroupId;
        FaceIds       = faceIds;
    }
}
