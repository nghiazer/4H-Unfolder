using Microsoft.Extensions.DependencyInjection;
using FourHUnfolder.App.Services;
using FourHUnfolder.App.ViewModels;
using FourHUnfolder.Application.Interfaces;
using FourHUnfolder.Application.Services;
using FourHUnfolder.Infrastructure.Exporters;
using PdfExporter = FourHUnfolder.Infrastructure.Exporters.PdfExporter;
using FourHUnfolder.Infrastructure.Loaders;
using System.Windows;

namespace FourHUnfolder.App;

public partial class App : System.Windows.Application
{
    public static IServiceProvider Services { get; private set; } = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var sc = new ServiceCollection();

        // Settings (must be registered and loaded before anything that needs it)
        sc.AddSingleton<SettingsService>();

        // Theme
        sc.AddSingleton<ThemeService>();

        // Infrastructure
        sc.AddSingleton<IMeshLoader,  MultiFormatMeshLoader>();
        sc.AddSingleton<IExporter,    SvgExporter>();
        sc.AddSingleton<PdfExporter>();
        sc.AddSingleton<PngExporter>();

        // Application
        sc.AddSingleton<MeshService>();
        sc.AddSingleton<UnfoldService>();
        sc.AddSingleton<ProjectSerializer>();

        // UI
        sc.AddTransient<MainViewModel>();

        Services = sc.BuildServiceProvider();

        // Load persisted settings before the main window opens
        var settings = Services.GetRequiredService<SettingsService>();
        settings.Load();

        // Apply the persisted theme (replaces the static LightTheme.xaml from App.xaml)
        var theme = Services.GetRequiredService<ThemeService>();
        theme.Apply(settings.Current.General.ThemeMode);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        (Services.GetService(typeof(MainViewModel)) as System.IDisposable)?.Dispose();
        base.OnExit(e);
    }
}
