using System.Net.Sockets;
using System.Text;
using Microsoft.Extensions.Logging;

namespace DCS_SC_Bridge
{
    public class UdpListenerService
    {
        private readonly ILogger<UdpListenerService> _logger;
        private UdpClient _udpClient;
        private CancellationTokenSource _cancellationTokenSource;
        private Task _listenerTask;

        public event EventHandler<string> MessageReceived;

        public UdpListenerService(ILogger<UdpListenerService> logger)
        {
            _logger = logger;
        }

        public void Start(string ipAddress, int port)
        {
            if (_udpClient != null)
                return;

            _cancellationTokenSource = new CancellationTokenSource();
            _udpClient = new UdpClient(new System.Net.IPEndPoint(System.Net.IPAddress.Parse(ipAddress), port));
            
            _logger.LogInformation("UDP Listener started on {ip}:{port}", ipAddress, port);
            
            _listenerTask = ListenAsync(_cancellationTokenSource.Token);
        }

        public async Task StopAsync()
        {
            if (_cancellationTokenSource == null)
                return;

            _cancellationTokenSource.Cancel();
            await (_listenerTask ?? Task.CompletedTask);
            _udpClient?.Dispose();
            _cancellationTokenSource.Dispose();
            _udpClient = null;
        }

        private async Task ListenAsync(CancellationToken cancellationToken)
        {
            try
            {
                while (!cancellationToken.IsCancellationRequested)
                {
                    var result = await _udpClient.ReceiveAsync(cancellationToken);
                    string message = Encoding.UTF8.GetString(result.Buffer);
                    
                    _logger.LogInformation("Received UDP message at {time}: {message}", DateTimeOffset.Now, message);
                    MessageReceived?.Invoke(this, message);
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("UDP Listener stopped");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "UDP Listener error");
            }
        }
    }
}