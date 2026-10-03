namespace AntigravityVpnService;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = Host.CreateApplicationBuilder(args);

        // Configure as Windows Service
        builder.Services.AddWindowsService(options =>
        {
            options.ServiceName = "AntigravityVpnTunnelService";
        });

        // Register Tunnel Manager & Named Pipe IPC Server
        builder.Services.AddSingleton<WindowsTunnelManager>();
        builder.Services.AddSingleton<NamedPipeIpcServer>();
        builder.Services.AddHostedService<Worker>();

        var host = builder.Build();
        host.Run();
    }
}
