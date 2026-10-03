using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Text.Json;

namespace AntigravityVpnService;

public class NamedPipeIpcServer
{
    private readonly ILogger<NamedPipeIpcServer> _logger;
    private readonly WindowsTunnelManager _tunnelManager;
    private const string PipeName = "AntigravityVpnIpc";
    private CancellationTokenSource? _cts;

    public NamedPipeIpcServer(ILogger<NamedPipeIpcServer> logger, WindowsTunnelManager tunnelManager)
    {
        _logger = logger;
        _tunnelManager = tunnelManager;
    }

    public void Start(CancellationToken cancellationToken)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _ = ListenLoopAsync(_cts.Token);
    }

    private async Task ListenLoopAsync(CancellationToken token)
    {
        _logger.LogInformation("Starting Windows Named Pipe IPC listener: \\\\.\\pipe\\{PipeName}", PipeName);

        while (!token.IsCancellationRequested)
        {
            try
            {
                var pipeSecurity = new PipeSecurity();
                // Allow Authenticated Users & Everyone to connect and write commands without admin elevation
                var everyone = new SecurityIdentifier(WellKnownSidType.WorldSid, null);
                pipeSecurity.AddAccessRule(new PipeAccessRule(everyone, PipeAccessRights.ReadWrite, AccessControlType.Allow));

                using var pipeServer = NamedPipeServerStreamAcl.Create(
                    PipeName,
                    PipeDirection.InOut,
                    NamedPipeServerStream.MaxAllowedServerInstances,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous,
                    4096,
                    4096,
                    pipeSecurity);

                _logger.LogInformation("Named pipe waiting for client connection from Flutter UI...");
                await pipeServer.WaitForConnectionAsync(token);

                _logger.LogInformation("Client connected to Named Pipe IPC.");
                await HandleClientAsync(pipeServer, token);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in Named Pipe IPC loop: {Message}", ex.Message);
                await Task.Delay(1000, token);
            }
        }
    }

    private async Task HandleClientAsync(NamedPipeServerStream pipe, CancellationToken token)
    {
        using var reader = new StreamReader(pipe, Encoding.UTF8, leaveOpen: true);
        using var writer = new StreamWriter(pipe, Encoding.UTF8, leaveOpen: true) { AutoFlush = true };

        while (pipe.IsConnected && !token.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(token);
            if (string.IsNullOrEmpty(line)) break;

            _logger.LogInformation("IPC Received Request: {Line}", line);

            try
            {
                var request = JsonSerializer.Deserialize<IpcMessage>(line);
                var response = ProcessCommand(request);
                var responseJson = JsonSerializer.Serialize(response);
                await writer.WriteLineAsync(responseJson);
            }
            catch (Exception ex)
            {
                var errorResponse = new IpcResponse { Success = false, Message = ex.Message };
                await writer.WriteLineAsync(JsonSerializer.Serialize(errorResponse));
            }
        }
    }

    private IpcResponse ProcessCommand(IpcMessage? request)
    {
        if (request == null) return new IpcResponse { Success = false, Message = "Empty request" };

        switch (request.Command?.ToLowerInvariant())
        {
            case "starttunnel":
                var clientIp = request.ClientAddressV4 ?? "10.8.0.2";
                var subnet = "255.255.255.0";
                var dns = request.Dns ?? "10.8.0.1";
                var endpoint = request.Endpoint ?? "127.0.0.1:51820";
                var killSwitch = request.KillSwitch;

                var started = _tunnelManager.StartTunnel(clientIp, subnet, dns, endpoint, killSwitch);
                return new IpcResponse
                {
                    Success = started,
                    Message = started ? "Tunnel started successfully" : "Failed to start tunnel",
                    State = started ? "connected" : "error"
                };

            case "stoptunnel":
                var stopped = _tunnelManager.StopTunnel();
                return new IpcResponse
                {
                    Success = stopped,
                    Message = stopped ? "Tunnel stopped successfully" : "Failed to stop tunnel",
                    State = "disconnected"
                };

            case "getstate":
                return new IpcResponse
                {
                    Success = true,
                    State = _tunnelManager.IsActive ? "connected" : "disconnected",
                    Message = _tunnelManager.IsActive ? $"Active on {_tunnelManager.ActiveEndpoint}" : "Idle"
                };

            default:
                return new IpcResponse { Success = false, Message = $"Unknown command: {request.Command}" };
        }
    }
}

public class IpcMessage
{
    public string? Command { get; set; }
    public string? ClientAddressV4 { get; set; }
    public string? ClientAddressV6 { get; set; }
    public string? Endpoint { get; set; }
    public string? ServerPublicKey { get; set; }
    public string? Dns { get; set; }
    public bool KillSwitch { get; set; }
}

public class IpcResponse
{
    public bool Success { get; set; }
    public string? Message { get; set; }
    public string? State { get; set; }
}
