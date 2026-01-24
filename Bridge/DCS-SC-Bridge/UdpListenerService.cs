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

            try
            {
                _cancellationTokenSource = new CancellationTokenSource();
                var parsedIp = System.Net.IPAddress.Parse(ipAddress);
                var endpoint = new System.Net.IPEndPoint(parsedIp, port);
                _udpClient = new UdpClient(endpoint);
                
                Console.WriteLine($"[UDP] Listener binding to {ipAddress}:{port}");
                _logger.LogInformation("UDP Listener started on {ip}:{port}", ipAddress, port);
                
                _listenerTask = ListenAsync(_cancellationTokenSource.Token);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[UDP] FAILED to start: {ex.GetType().Name}: {ex.Message}");
                _logger.LogError(ex, "Failed to start UDP Listener on {ip}:{port}", ipAddress, port);
                _udpClient?.Dispose();
                _udpClient = null;
                throw;
            }
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
                Console.WriteLine($"[UDP] Listener is now waiting for messages...");
                
                while (!cancellationToken.IsCancellationRequested)
                {
                    var result = await _udpClient.ReceiveAsync(cancellationToken);
                    string message = Encoding.UTF8.GetString(result.Buffer);
                    
                    Console.WriteLine($"[UDP] {DateTimeOffset.Now:HH:mm:ss.fff} - Received {result.Buffer.Length} bytes from {result.RemoteEndPoint}");
                    Console.WriteLine($"[UDP] Message: {message}");
                    
                    _logger.LogInformation("Received UDP message at {time}: {message}", DateTimeOffset.Now, message);
                    MessageReceived?.Invoke(this, message);
                }
            }
            catch (OperationCanceledException)
            {
                Console.WriteLine("[UDP] Listener stopped");
                _logger.LogInformation("UDP Listener stopped");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[UDP] ERROR: {ex.GetType().Name}: {ex.Message}");
                Console.WriteLine($"[UDP] Stack trace: {ex.StackTrace}");
                _logger.LogError(ex, "UDP Listener error");
            }
        }
    }
}