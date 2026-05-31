using System.Windows;

namespace FourHUnfolder.App.Services;

/// <summary>
/// Manages the active UI theme (Light / Dark) by swapping the
/// theme ResourceDictionary in Application.Resources.MergedDictionaries
/// at runtime so all DynamicResource references auto-update.
/// </summary>
public sealed class ThemeService
{
    private const string LightUri = "pack://application:,,,/Themes/LightTheme.xaml";
    private const string DarkUri  = "pack://application:,,,/Themes/DarkTheme.xaml";

    private ResourceDictionary? _current;

    /// <summary>
    /// Applies the given theme immediately.
    /// <paramref name="themeMode"/> should be "Light" or "Dark" (case-insensitive).
    /// Defaults to Light for any unrecognized value.
    /// </summary>
    public void Apply(string themeMode)
    {
        var uri = themeMode.Equals("Dark", StringComparison.OrdinalIgnoreCase)
            ? new Uri(DarkUri,  UriKind.Absolute)
            : new Uri(LightUri, UriKind.Absolute);

        var newDict = new ResourceDictionary { Source = uri };

        var merged = System.Windows.Application.Current.Resources.MergedDictionaries;

        // Remove the previously injected theme (if any)
        if (_current != null)
            merged.Remove(_current);

        // Add at the END so it has highest priority (WPF MergedDictionaries: last wins).
        // App.xaml statically loads LightTheme.xaml at index 0; by appending here we
        // always override it — regardless of whether we're switching to Dark or Light.
        merged.Add(newDict);
        _current = newDict;
    }
}
