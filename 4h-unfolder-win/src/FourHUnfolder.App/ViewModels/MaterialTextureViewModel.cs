using System.Windows.Media.Imaging;
using CommunityToolkit.Mvvm.ComponentModel;

namespace FourHUnfolder.App.ViewModels;

/// <summary>
/// Represents one material slot in the multi-texture dialog.
/// Each slot may have a texture image assigned independently.
/// </summary>
public partial class MaterialTextureViewModel : ObservableObject
{
    public int    MaterialId   { get; }
    public string MaterialName { get; }

    [ObservableProperty] private string?      _texturePath;
    [ObservableProperty] private BitmapImage? _thumbnail;

    public bool   HasTexture   => !string.IsNullOrEmpty(TexturePath);
    public string ShortName    => HasTexture ? System.IO.Path.GetFileName(TexturePath!) : "(none)";

    partial void OnTexturePathChanged(string? value)
    {
        OnPropertyChanged(nameof(HasTexture));
        OnPropertyChanged(nameof(ShortName));
    }

    public MaterialTextureViewModel(int materialId, string materialName,
                                    string? texturePath = null,
                                    BitmapImage? thumbnail = null)
    {
        MaterialId   = materialId;
        MaterialName = materialName;
        _texturePath = texturePath;
        _thumbnail   = thumbnail;
    }
}
