using PepakuraClone.Domain.Results;

namespace PepakuraClone.Application.Interfaces;

public interface IExporter
{
    void Export(UnfoldResult result, string filePath);
}
