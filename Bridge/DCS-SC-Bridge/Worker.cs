using System.Net.Sockets;
using System.Text;

namespace DCS_SC_Bridge

{
    public class Worker(ILogger<Worker> logger) : BackgroundService
    {
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            using var udp = new UdpClient(10308);
            logger.LogInformation("UDP Listener started on port 10308");

            while (!stoppingToken.IsCancellationRequested)
            {
                var result = await udp.ReceiveAsync(stoppingToken);

                string message = Encoding.UTF8.GetString(result.Buffer);

                logger.LogInformation("Received UDP message: {message}", message);
            }
        }
    }
}
