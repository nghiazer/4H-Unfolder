using System.Windows;
using System.Windows.Controls;
using Microsoft.Win32;
using FourHUnfolder.App.ViewModels;

namespace FourHUnfolder.App.Dialogs;

public partial class TextureDialog : Window
{
    private MainViewModel? Vm => DataContext as MainViewModel;
    private MaterialTextureViewModel? _selected;

    public TextureDialog() => InitializeComponent();

    protected override void OnContentRendered(EventArgs e)
    {
        base.OnContentRendered(e);
        if (MaterialList.Items.Count > 0)
            MaterialList.SelectedIndex = 0;
    }

    private void MaterialList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _selected = MaterialList.SelectedItem as MaterialTextureViewModel;
        RefreshDetail();
    }

    private void RefreshDetail()
    {
        if (_selected == null)
        {
            SelectedMaterialLabel.Text = "Select a material slot";
            SelectedFileLabel.Text     = "";
            LargeThumbnail.Source      = null;
            NoTextureLbl.Visibility    = Visibility.Visible;
            LoadBtn.IsEnabled          = false;
            RemoveBtn.IsEnabled        = false;
            return;
        }

        SelectedMaterialLabel.Text = _selected.MaterialName;
        SelectedFileLabel.Text     = _selected.HasTexture
            ? _selected.TexturePath
            : "(no texture assigned)";
        LargeThumbnail.Source   = _selected.Thumbnail;
        NoTextureLbl.Visibility = _selected.HasTexture ? Visibility.Collapsed : Visibility.Visible;
        LoadBtn.IsEnabled       = true;
        RemoveBtn.IsEnabled     = _selected.HasTexture;
    }

    private void LoadBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null || Vm == null) return;

        var dlg = new OpenFileDialog
        {
            Title  = $"Load texture for \"{_selected.MaterialName}\"",
            Filter = "Images (*.png;*.jpg;*.jpeg;*.bmp;*.tiff)|*.png;*.jpg;*.jpeg;*.bmp;*.tiff|All files (*.*)|*.*"
        };
        if (dlg.ShowDialog() != true) return;

        Vm.SetMaterialTexture(_selected.MaterialId, dlg.FileName);
        RefreshDetail();
    }

    private void RemoveBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null || Vm == null) return;
        Vm.SetMaterialTexture(_selected.MaterialId, null);
        RefreshDetail();
    }

    private void CloseBtn_Click(object sender, RoutedEventArgs e) => Close();
}
