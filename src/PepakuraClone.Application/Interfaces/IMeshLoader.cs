using PepakuraClone.Domain.Models;

namespace PepakuraClone.Application.Interfaces;

public interface IMeshLoader
{
    Mesh Load(string filePath);
}
