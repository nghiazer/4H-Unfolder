using System.Windows;
using FourHUnfolder.App.ViewModels;

namespace FourHUnfolder.App.Dialogs;

/// <summary>
/// Code-behind for the Assembly Animation window.
/// All logic lives in <see cref="AssemblyViewModel"/>; this file only wires
/// the window lifetime to the VM's Dispose.
/// </summary>
public partial class AssemblyAnimationWindow : Window
{
    private readonly AssemblyViewModel _vm;

    public AssemblyAnimationWindow(AssemblyViewModel vm)
    {
        InitializeComponent();
        _vm        = vm;
        DataContext = vm;
        Closed     += OnWindowClosed;
    }

    private void OnWindowClosed(object? sender, EventArgs e)
    {
        _vm.Dispose();   // stop the DispatcherTimer
    }
}
