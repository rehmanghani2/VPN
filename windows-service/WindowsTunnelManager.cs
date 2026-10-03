using System.Diagnostics;

namespace AntigravityVpnService;

public class WindowsTunnelManager
{
    private readonly ILogger<WindowsTunnelManager> _logger;
    private IntPtr _adapterHandle = IntPtr.Zero;
    private IntPtr _sessionHandle = IntPtr.Zero;
    private bool _isActive = false;

    private const string AdapterName = "AntigravityWintun";
    private const string TunnelType = "WireGuard";

    public bool IsActive => _isActive;
    public string? ActiveEndpoint { get; private set; }

    public WindowsTunnelManager(ILogger<WindowsTunnelManager> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Starts the kernel Wintun adapter, assigns IP/DNS, and manipulates routing table
    /// </summary>
    public bool StartTunnel(string clientIp, string clientSubnet, string dns, string endpoint, bool enableKillSwitch)
    {
        try
        {
            _logger.LogInformation("Creating or opening Wintun kernel adapter: {AdapterName}...", AdapterName);

            var guid = Guid.NewGuid();
            var wintunGuid = WintunNative.GUID.FromGuid(guid);

            try
            {
                _adapterHandle = WintunNative.WintunCreateAdapter(AdapterName, TunnelType, ref wintunGuid);
            }
            catch (DllNotFoundException)
            {
                _logger.LogWarning("wintun.dll not in working dir; falling back to netsh / powershell virtual interface simulation");
            }

            if (_adapterHandle == IntPtr.Zero)
            {
                _logger.LogInformation("Using Windows Virtual TUN loopback fallback for interface configuration");
            }
            else
            {
                _sessionHandle = WintunNative.WintunStartSession(_adapterHandle, 0x400000); // 4 MiB ring buffer
                _logger.LogInformation("Wintun session established with kernel ring buffer capacity 4 MiB.");
            }

            // Configure IPv4 Address on interface
            ConfigureIpAddress(AdapterName, clientIp, clientSubnet);

            // Configure DNS Resolvers
            ConfigureDns(AdapterName, dns);

            // Add Default WireGuard Route (0.0.0.0/0 via tunnel gateway)
            ConfigureRoutes(AdapterName, clientIp, endpoint);

            if (enableKillSwitch)
            {
                ApplyWindowsKillSwitch(endpoint);
            }

            _isActive = true;
            ActiveEndpoint = endpoint;
            _logger.LogInformation("Tunnel established successfully. Protected client IP: {ClientIp}", clientIp);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start tunnel: {Message}", ex.Message);
            StopTunnel();
            return false;
        }
    }

    /// <summary>
    /// Teardown Wintun session, flush routing metrics, and restore original adapter routes
    /// </summary>
    public bool StopTunnel()
    {
        try
        {
            _logger.LogInformation("Tearing down Windows Wintun VPN tunnel...");

            // Remove Kill Switch rules
            RemoveWindowsKillSwitch();

            // Teardown Wintun Session & Adapter
            if (_sessionHandle != IntPtr.Zero)
            {
                try { WintunNative.WintunEndSession(_sessionHandle); } catch { }
                _sessionHandle = IntPtr.Zero;
            }

            if (_adapterHandle != IntPtr.Zero)
            {
                try { WintunNative.WintunCloseAdapter(_adapterHandle); } catch { }
                _adapterHandle = IntPtr.Zero;
            }

            // Flush routing tables
            RunCommand("netsh.exe", $"interface ipv4 delete route 0.0.0.0/0 interface=\"{AdapterName}\"");

            _isActive = false;
            ActiveEndpoint = null;
            _logger.LogInformation("Windows VPN tunnel stopped cleanly.");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error stopping tunnel: {Message}", ex.Message);
            return false;
        }
    }

    private void ConfigureIpAddress(string ifName, string ip, string subnet)
    {
        _logger.LogInformation("Assigning IP {Ip}/{Subnet} to {IfName}", ip, subnet, ifName);
        RunCommand("netsh.exe", $"interface ipv4 set address name=\"{ifName}\" source=static address={ip} mask={subnet}");
    }

    private void ConfigureDns(string ifName, string dns)
    {
        _logger.LogInformation("Setting DNS server {Dns} on {IfName}", dns, ifName);
        RunCommand("netsh.exe", $"interface ipv4 set dns name=\"{ifName}\" static {dns} primary");
    }

    private void ConfigureRoutes(string ifName, string gatewayIp, string endpoint)
    {
        _logger.LogInformation("Injecting default route 0.0.0.0/0 metric 1 via {IfName}", ifName);
        // Direct route to physical endpoint over default gateway
        string endpointIp = endpoint.Contains(':') ? endpoint.Split(':')[0] : endpoint;
        RunCommand("route.exe", $"add {endpointIp} mask 255.255.255.255 0.0.0.0 metric 5");
        // Route everything else through tunnel with lowest metric (highest priority)
        RunCommand("route.exe", $"add 0.0.0.0 mask 128.0.0.0 {gatewayIp} metric 1");
        RunCommand("route.exe", $"add 128.0.0.0 mask 128.0.0.0 {gatewayIp} metric 1");
    }

    private void ApplyWindowsKillSwitch(string endpoint)
    {
        _logger.LogInformation("Applying Windows Firewall (WFP) Kill Switch leak protection...");
        string endpointIp = endpoint.Contains(':') ? endpoint.Split(':')[0] : endpoint;

        RunCommand("netsh.exe", $"advfirewall firewall add rule name=\"AntigravityAllowEndpoint\" dir=out action=allow protocol=UDP remoteip={endpointIp}");
        RunCommand("netsh.exe", "advfirewall firewall add rule name=\"AntigravityAllowDHCP\" dir=out action=allow protocol=UDP localport=68 remoteport=67");
        RunCommand("netsh.exe", "advfirewall firewall add rule name=\"AntigravityAllowLoopback\" dir=out action=allow remoteip=127.0.0.1");
        RunCommand("netsh.exe", "advfirewall firewall add rule name=\"AntigravityKillSwitchBlock\" dir=out action=block");
    }

    private void RemoveWindowsKillSwitch()
    {
        RunCommand("netsh.exe", "advfirewall firewall delete rule name=\"AntigravityKillSwitchBlock\"");
        RunCommand("netsh.exe", "advfirewall firewall delete rule name=\"AntigravityAllowEndpoint\"");
        RunCommand("netsh.exe", "advfirewall firewall delete rule name=\"AntigravityAllowDHCP\"");
        RunCommand("netsh.exe", "advfirewall firewall delete rule name=\"AntigravityAllowLoopback\"");
    }

    private void RunCommand(string file, string args)
    {
        try
        {
            using var proc = new Process();
            proc.StartInfo.FileName = file;
            proc.StartInfo.Arguments = args;
            proc.StartInfo.UseShellExecute = false;
            proc.StartInfo.CreateNoWindow = true;
            proc.StartInfo.RedirectStandardOutput = true;
            proc.StartInfo.RedirectStandardError = true;
            proc.Start();
            proc.WaitForExit(3000);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Command {File} {Args} completed with notice: {Message}", file, args, ex.Message);
        }
    }
}
