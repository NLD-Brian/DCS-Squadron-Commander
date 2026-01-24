using System.Windows;
using System.Windows.Threading;
using DCS_SC_Bridge.Models;
using DCS_SC_Bridge.Services;
using Microsoft.Extensions.Logging;

namespace DCS_SC_Bridge
{
    public partial class MainWindow : Window
    {
        private readonly AppSettings _settings;
        private readonly UdpListenerService _listenerService;
        private readonly ILogger<MainWindow> _logger;
        private readonly SettingsService _settingsService;
        private DispatcherTimer _uptimeTimer;
        private DateTime _startTime;
        private int _messageCount = 0;

        public MainWindow(AppSettings settings, UdpListenerService listenerService, ILogger<MainWindow> logger, SettingsService settingsService = null)
        {
            InitializeComponent();
            _settings = settings;
            _listenerService = listenerService;
            _logger = logger;
            _settingsService = settingsService ?? new SettingsService();
            
            InitializeUptimeTimer();
            SubscribeToMessages();
        }

        private void SubscribeToMessages()
        {
            _listenerService.MessageReceived += (s, msg) => 
            {
                Console.WriteLine($"[GUI] Message event received in MainWindow: {msg}");
                _messageCount++;
                Dispatcher.Invoke(() => 
                {
                    MessagesCountText.Text = _messageCount.ToString();
                    LastMessageText.Text = DateTime.Now.ToString("HH:mm:ss");
                    LogMessage($"[{DateTime.Now:HH:mm:ss}] Received: {msg}");
                });
            };
        }

        private void InitializeUptimeTimer()
        {
            _uptimeTimer = new DispatcherTimer();
            _uptimeTimer.Interval = TimeSpan.FromSeconds(1);
            _uptimeTimer.Tick += (s, e) =>
            {
                var uptime = DateTime.Now - _startTime;
                UptimeText.Text = uptime.ToString(@"hh\:mm\:ss");
            };
        }

        protected override void OnStateChanged(EventArgs e)
        {
            if (WindowState == WindowState.Minimized)
            {
                Hide();
                WindowState = WindowState.Minimized;
            }
            base.OnStateChanged(e);
        }

        private void StartButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                _startTime = DateTime.Now;
                _messageCount = 0;
                MessagesCountText.Text = "0";
                LastMessageText.Text = "None";
                LogTextBox.Clear();
                
                _listenerService.Start(_settings.ListenerIp, _settings.ListenerPort);
                _uptimeTimer.Start();
                
                StatusText.Text = "Running";
                StatusText.Foreground = System.Windows.Media.Brushes.Green;
                StartButton.IsEnabled = false;
                StopButton.IsEnabled = true;
                
                LogMessage($"Listener started on {_settings.ListenerIp}:{_settings.ListenerPort}");
            }
            catch (Exception ex)
            {
                LogMessage($"Error: {ex.Message}");
                StatusText.Text = "Error";
                StatusText.Foreground = System.Windows.Media.Brushes.Red;
                StartButton.IsEnabled = true;
                StopButton.IsEnabled = false;
            }
        }

        private async void StopButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                await _listenerService.StopAsync();
                _uptimeTimer.Stop();
                
                StatusText.Text = "Stopped";
                StatusText.Foreground = System.Windows.Media.Brushes.Red;
                StartButton.IsEnabled = true;
                StopButton.IsEnabled = false;
                
                LogMessage("Listener stopped");
            }
            catch (Exception ex)
            {
                LogMessage($"Error stopping listener: {ex.Message}");
            }
        }

        private async void SettingsButton_Click(object sender, RoutedEventArgs e)
        {
            // Stop the listener before opening settings
            if (StatusText.Text == "Running")
            {
                await _listenerService.StopAsync();
                _uptimeTimer.Stop();
                StatusText.Text = "Stopped";
            }

            var configWindow = new ConfigurationWindow();
            configWindow.Show();
            this.Close();
        }

        private void LogMessage(string message)
        {
            LogTextBox.AppendText(message + "\n");
            LogTextBox.ScrollToEnd();
        }

        protected override async void OnClosed(EventArgs e)
        {
            if (StatusText.Text == "Running")
            {
                await _listenerService.StopAsync();
            }
            _uptimeTimer?.Stop();
            base.OnClosed(e);
        }
    }
}

