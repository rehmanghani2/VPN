namespace AntigravityVpnService;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly NamedPipeIpcServer _ipcServer;

    public Worker(ILogger<Worker> logger, NamedPipeIpcServer ipcServer)
    {
        _logger = logger;
        _ipcServer = ipcServer;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Antigravity VPN Elevated Windows Background Service running at: {time}", DateTimeOffset.Now);

        // Start Named Pipe IPC Server
        _ipcServer.Start(stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(10000, stoppingToken);
        }
    }
}
