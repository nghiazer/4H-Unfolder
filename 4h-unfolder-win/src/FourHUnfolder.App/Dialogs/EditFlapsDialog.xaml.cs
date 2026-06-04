using System.Windows;
using FourHUnfolder.App.ViewModels;

namespace FourHUnfolder.App.Dialogs;

/// <summary>
/// Modeless Edit Flaps dialog.
/// While the Position(Q) tab is active, edge clicks on the canvas are routed here
/// via NotifyEdgeClicked; the dialog applies the selected operation to that edge.
/// </summary>
public partial class EditFlapsDialog : Window
{
    public EditFlapsViewModel Vm { get; }

    public EditFlapsDialog(MainViewModel mainVm)
    {
        Vm          = new EditFlapsViewModel(mainVm);
        DataContext = Vm;
        InitializeComponent();
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    /// Called by PatternCanvasControl when FlapEditActive=true and an edge is clicked.
    internal void NotifyEdgeClicked(int meshEdgeId, bool isBoundary, int faceId)
        => Vm.ApplyToEdge(meshEdgeId, isBoundary, faceId);
}
