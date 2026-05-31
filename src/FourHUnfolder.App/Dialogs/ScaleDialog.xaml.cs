using System.Globalization;
using System.Windows;
using FourHUnfolder.Domain.Models;

namespace FourHUnfolder.App.Dialogs;

public partial class ScaleDialog : Window
{
    public ModelScale? Result { get; private set; }

    public ScaleDialog(string boundingBoxInfo, double currentTargetMm = 200.0)
    {
        InitializeComponent();
        BBoxLabel.Text       = $"Bounding box: {boundingBoxInfo}";
        TargetSizeBox.Text   = currentTargetMm.ToString("F0", CultureInfo.InvariantCulture);
    }

    private void OK_Click(object sender, RoutedEventArgs e)
    {
        if (!double.TryParse(TargetSizeBox.Text, NumberStyles.Any,
                             CultureInfo.InvariantCulture, out double size) || size <= 0)
        {
            MessageBox.Show("Please enter a valid positive number for the target size.",
                            "Input Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var unit = UnitCombo.SelectedIndex switch
        {
            1 => ScaleUnit.Cm,
            2 => ScaleUnit.Inch,
            _ => ScaleUnit.Mm
        };
        var axis = AxisCombo.SelectedIndex switch
        {
            0 => ScaleAxis.Width,
            1 => ScaleAxis.Height,
            2 => ScaleAxis.Depth,
            _ => ScaleAxis.Longest
        };

        Result = new ModelScale(size, unit, axis);
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) =>
        DialogResult = false;
}
