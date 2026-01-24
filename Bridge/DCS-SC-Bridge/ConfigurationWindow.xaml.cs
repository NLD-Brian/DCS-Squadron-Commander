using System.Windows;
using DCS_SC_Bridge.Models;
using DCS_SC_Bridge.Services;
using Microsoft.Extensions.DependencyInjection;

namespace DCS_SC_Bridge
{
    public partial class ConfigurationWindow : Window
    {
        private readonly SettingsService _settingsService;
        private readonly IServiceProvider _serviceProvider;
        private AppSettings _currentSettings;

        public ConfigurationWindow() : this(null)
        {
        }

        public ConfigurationWindow(IServiceProvider serviceProvider = null)
        {
            InitializeComponent();
            _serviceProvider = serviceProvider;
            _settingsService = new SettingsService();
            
            _currentSettings = _settingsService.Load();
            IpTextBox.Text = _currentSettings.ListenerIp;
            PortTextBox.Text = _currentSettings.ListenerPort.ToString();
            ApiUrlTextBox.Text = _currentSettings.ApiUrl;
        }

        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            ErrorText.Text = "";

            if (string.IsNullOrWhiteSpace(IpTextBox.Text))
            {
                ErrorText.Text = "Listener IP is required";
                return;
            }

            if (!int.TryParse(PortTextBox.Text, out var port) || port < 1 || port > 65535)
            {
                ErrorText.Text = "Invalid port number (1-65535)";
                return;
            }

            if (string.IsNullOrWhiteSpace(ApiUrlTextBox.Text))
            {
                ErrorText.Text = "API URL is required";
                return;
            }

            if (string.IsNullOrWhiteSpace(TokenPasswordBox.Password))
            {
                ErrorText.Text = "API Token is required";
                return;
            }

            var settings = new AppSettings
            {
                ListenerIp = IpTextBox.Text,
                ListenerPort = port,
                ApiUrl = ApiUrlTextBox.Text,
                ApiToken = TokenPasswordBox.Password
            };

            try
            {
                _settingsService.Save(settings);
                
                // Update the settings instance in the service provider
                if (_serviceProvider != null)
                {
                    _currentSettings.ListenerIp = settings.ListenerIp;
                    _currentSettings.ListenerPort = settings.ListenerPort;
                    _currentSettings.ApiUrl = settings.ApiUrl;
                    _currentSettings.ApiToken = settings.ApiToken;
                    
                    var mainWindow = _serviceProvider.GetRequiredService<MainWindow>();
                    mainWindow.Show();
                }
                
                this.Close();
            }
            catch (Exception ex)
            {
                ErrorText.Text = $"Failed to save settings: {ex.Message}";
            }
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}

