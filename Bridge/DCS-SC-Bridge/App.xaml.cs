using System.Windows;
using DCS_SC_Bridge.Models;
using DCS_SC_Bridge.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Console;

namespace DCS_SC_Bridge
{
    public partial class App : Application
    {
        private IServiceProvider _serviceProvider;

        protected override void OnStartup(StartupEventArgs e)
        {
            // Show console window for debugging
            ConsoleHelper.ShowConsole();
            Console.WriteLine("[APP] Application starting...");

            var services = new ServiceCollection();

            // Configure services
            services.AddLogging(builder => builder.AddConsole().SetMinimumLevel(LogLevel.Information));

            // Load settings from disk or use defaults
            var settingsService = new SettingsService();
            var settings = settingsService.Load();
            services.AddSingleton(settings);
            services.AddSingleton(settingsService);
            
            services.AddSingleton<UdpListenerService>();
            services.AddSingleton<ConfigurationWindow>();
            services.AddSingleton<MainWindow>();

            _serviceProvider = services.BuildServiceProvider();

            var mainWindow = _serviceProvider.GetRequiredService<MainWindow>();
            var configWindow = _serviceProvider.GetRequiredService<ConfigurationWindow>();
            
            // Check if this is first run (no saved settings) or if settings are incomplete
            if (string.IsNullOrWhiteSpace(settings.ApiUrl) || string.IsNullOrWhiteSpace(settings.ApiToken))
            {
                Console.WriteLine("[APP] First run - showing configuration window");
                configWindow.Owner = null;
                configWindow.Show();
            }
            else
            {
                Console.WriteLine("[APP] Settings loaded - showing main window");
                mainWindow.Show();
            }
        }

        protected override void OnExit(ExitEventArgs e)
        {
            (_serviceProvider as ServiceProvider)?.Dispose();
            base.OnExit(e);
        }
    }
}
