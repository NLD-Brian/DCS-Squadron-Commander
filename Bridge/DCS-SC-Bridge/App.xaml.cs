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
            var services = new ServiceCollection();

            // Configure services
            services.AddLogging(builder => builder.AddConsole().SetMinimumLevel(LogLevel.Information));

            services.AddSingleton<AppSettings>(new AppSettings());
            services.AddSingleton<UdpListenerService>();
            services.AddSingleton<ConfigurationWindow>();
            services.AddSingleton<MainWindow>();

            _serviceProvider = services.BuildServiceProvider();

            var configWindow = _serviceProvider.GetRequiredService<ConfigurationWindow>();
            configWindow.Show();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            (_serviceProvider as ServiceProvider)?.Dispose();
            base.OnExit(e);
        }
    }
}
