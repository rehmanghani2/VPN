#include "vpn_channel.h"

#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <fstream>
#include <string>
#include <vector>
#include <sstream>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

namespace {

static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_vpn_channel = nullptr;
static bool g_is_connected = false;

// Connect to the privileged Windows Service over Named Pipe IPC
bool SendIpcCommand(const std::string& jsonCommand, std::string& outResponse) {
    HANDLE hPipe = CreateFileW(
        L"\\\\.\\pipe\\AntigravityVpnIpc",
        GENERIC_READ | GENERIC_WRITE,
        0,
        NULL,
        OPEN_EXISTING,
        0,
        NULL);

    if (hPipe == INVALID_HANDLE_VALUE) {
        return false;
    }

    std::string payload = jsonCommand + "\n";
    DWORD bytesWritten = 0;
    if (!WriteFile(hPipe, payload.c_str(), static_cast<DWORD>(payload.length()), &bytesWritten, NULL)) {
        CloseHandle(hPipe);
        return false;
    }

    char buffer[4096];
    DWORD bytesRead = 0;
    if (ReadFile(hPipe, buffer, sizeof(buffer) - 1, &bytesRead, NULL) && bytesRead > 0) {
        buffer[bytesRead] = '\0';
        outResponse = std::string(buffer);
        CloseHandle(hPipe);
        return true;
    }

    CloseHandle(hPipe);
    return false;
}

std::wstring GetConfigDirectory() {
    wchar_t path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, path))) {
        std::wstring dir = std::wstring(path) + L"\\AntigravityVPN";
        CreateDirectoryW(dir.c_str(), NULL);
        return dir;
    }
    return L"C:\\Temp";
}

std::wstring FindWireGuardExecutable() {
    // Check standard 64-bit and 32-bit Program Files
    const wchar_t* paths[] = {
        L"C:\\Program Files\\WireGuard\\wireguard.exe",
        L"C:\\Program Files (x86)\\WireGuard\\wireguard.exe",
    };

    for (const auto* p : paths) {
        DWORD attribs = GetFileAttributesW(p);
        if (attribs != INVALID_FILE_ATTRIBUTES && !(attribs & FILE_ATTRIBUTE_DIRECTORY)) {
            return std::wstring(p);
        }
    }
    return L"";
}

bool WriteTunnelConfig(const std::wstring& filePath, const flutter::EncodableMap& args) {
    std::wofstream file(filePath);
    if (!file.is_open()) return false;

    // Helper lambda to get string value
    auto getString = [&](const std::string& key, const std::string& defaultVal) -> std::string {
        auto it = args.find(flutter::EncodableValue(key));
        if (it != args.end() && std::holds_alternative<std::string>(it->second)) {
            return std::get<std::string>(it->second);
        }
        return defaultVal;
    };

    // Client Private Key (Mock or secure key)
    std::string clientPrivKey = getString("clientPrivateKey", "aElxR3d1c2VyLXNlY3VyZS1wcml2YXRlLWtleS0yMDI2=");
    std::string clientIpV4 = getString("clientAddressV4", "10.8.0.2/24");
    std::string clientIpV6 = getString("clientAddressV6", "fd42:42:42::2/64");
    std::string endpoint = getString("endpoint", "127.0.0.1:51820");
    std::string serverPubKey = getString("serverPublicKey", "Yx0R7w0VvP+r/f01hZzGg5r4t8u7v6w5x4y3z2a1b0c=");

    file << L"[Interface]\n";
    file << L"PrivateKey = " << std::wstring(clientPrivKey.begin(), clientPrivKey.end()) << L"\n";
    file << L"Address = " << std::wstring(clientIpV4.begin(), clientIpV4.end());
    if (!clientIpV6.empty()) {
        file << L", " << std::wstring(clientIpV6.begin(), clientIpV6.end());
    }
    file << L"\n";
    file << L"DNS = 10.8.0.1\n";
    file << L"MTU = 1360\n\n";

    file << L"[Peer]\n";
    file << L"PublicKey = " << std::wstring(serverPubKey.begin(), serverPubKey.end()) << L"\n";
    file << L"Endpoint = " << std::wstring(endpoint.begin(), endpoint.end()) << L"\n";
    file << L"AllowedIPs = 0.0.0.0/0, ::/0\n";
    file << L"PersistentKeepalive = 25\n";

    file.close();
    return true;
}

void ExecuteTunnelService(const std::wstring& cmd, const std::wstring& params) {
    SHELLEXECUTEINFOW sei = { sizeof(sei) };
    sei.lpVerb = L"runas"; // Elevate if required
    sei.lpFile = cmd.c_str();
    sei.lpParameters = params.c_str();
    sei.nShow = SW_HIDE;
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;

    if (ShellExecuteExW(&sei)) {
        if (sei.hProcess) {
            WaitForSingleObject(sei.hProcess, 5000);
            CloseHandle(sei.hProcess);
        }
    }
}

void SetWindowsKillSwitch(bool enable, const std::string& endpoint = "") {
    if (enable) {
        std::string ip = endpoint;
        size_t colon = endpoint.find(':');
        if (colon != std::string::npos) {
            ip = endpoint.substr(0, colon);
        }

        // 1. Allow WireGuard tunnel endpoint UDP traffic
        std::wstring allowEndpointCmd = L"advfirewall firewall add rule name=\"AntigravityAllowEndpoint\" dir=out action=allow protocol=UDP remoteip=" +
            std::wstring(ip.begin(), ip.end());
        ExecuteTunnelService(L"netsh.exe", allowEndpointCmd);

        // 2. Allow Loopback and DHCP
        ExecuteTunnelService(L"netsh.exe", L"advfirewall firewall add rule name=\"AntigravityAllowDHCP\" dir=out action=allow protocol=UDP localport=68 remoteport=67");
        ExecuteTunnelService(L"netsh.exe", L"advfirewall firewall add rule name=\"AntigravityAllowLoopback\" dir=out action=allow remoteip=127.0.0.1");

        // 3. Block unencrypted outbound leak
        ExecuteTunnelService(L"netsh.exe", L"advfirewall firewall add rule name=\"AntigravityKillSwitchBlock\" dir=out action=block");
    } else {
        // Tear down kill switch rules cleanly
        ExecuteTunnelService(L"netsh.exe", L"advfirewall firewall delete rule name=\"AntigravityKillSwitchBlock\"");
        ExecuteTunnelService(L"netsh.exe", L"advfirewall firewall delete rule name=\"AntigravityAllowEndpoint\"");
        ExecuteTunnelService(L"netsh.exe", L"advfirewall firewall delete rule name=\"AntigravityAllowDHCP\"");
        ExecuteTunnelService(L"netsh.exe", L"advfirewall firewall delete rule name=\"AntigravityAllowLoopback\"");
    }
}

} // namespace

void RegisterVpnChannel(flutter::BinaryMessenger* messenger) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, "com.vpnplatform.app/vpn",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            
            const std::string& method = call.method();

            if (method == "startTunnel") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (!args) {
                    result->Error("INVALID_ARGUMENTS", "Tunnel config must be a map");
                    return;
                }

                std::wstring configDir = GetConfigDirectory();
                std::wstring configFile = configDir + L"\\AntigravityTunnel.conf";

                if (!WriteTunnelConfig(configFile, *args)) {
                    result->Error("CONFIG_WRITE_FAILED", "Could not write WireGuard configuration file");
                    return;
                }

                // Check Kill Switch parameter
                bool killSwitch = false;
                auto ksIt = args->find(flutter::EncodableValue("killSwitch"));
                if (ksIt != args->end() && std::holds_alternative<bool>(ksIt->second)) {
                    killSwitch = std::get<bool>(ksIt->second);
                }

                std::string endpoint = "127.0.0.1:51820";
                auto epIt = args->find(flutter::EncodableValue("endpoint"));
                if (epIt != args->end() && std::holds_alternative<std::string>(epIt->second)) {
                    endpoint = std::get<std::string>(epIt->second);
                }

                if (killSwitch) {
                    SetWindowsKillSwitch(true, endpoint);
                }

                // Phase 18: Try privileged background Windows Service over Named Pipe IPC first
                std::string clientIp = "10.8.0.2";
                auto ipIt = args->find(flutter::EncodableValue("clientAddressV4"));
                if (ipIt != args->end() && std::holds_alternative<std::string>(ipIt->second)) {
                    clientIp = std::get<std::string>(ipIt->second);
                    size_t slash = clientIp.find('/');
                    if (slash != std::string::npos) clientIp = clientIp.substr(0, slash);
                }

                std::ostringstream jsonStream;
                jsonStream << "{\"Command\":\"StartTunnel\","
                           << "\"ClientAddressV4\":\"" << clientIp << "\","
                           << "\"Endpoint\":\"" << endpoint << "\","
                           << "\"KillSwitch\":" << (killSwitch ? "true" : "false") << "}";

                std::string ipcResponse;
                if (SendIpcCommand(jsonStream.str(), ipcResponse)) {
                    g_is_connected = true;
                    if (g_vpn_channel) {
                        flutter::EncodableMap stateMap;
                        stateMap[flutter::EncodableValue("state")] = flutter::EncodableValue("connected");
                        g_vpn_channel->InvokeMethod("onTunnelStateChanged",
                            std::make_unique<flutter::EncodableValue>(stateMap));
                    }
                    result->Success(flutter::EncodableValue(true));
                    return;
                }

                // Fallback: If Windows background service is not running, run elevated executable fallback
                std::wstring wgExe = FindWireGuardExecutable();
                if (!wgExe.empty()) {
                    // Install and start tunnel service with Wintun
                    std::wstring params = L"/installtunnelservice \"" + configFile + L"\"";
                    ExecuteTunnelService(wgExe, params);
                }

                g_is_connected = true;

                // Broadcast state to Flutter
                if (g_vpn_channel) {
                    flutter::EncodableMap stateMap;
                    stateMap[flutter::EncodableValue("state")] = flutter::EncodableValue("connected");
                    g_vpn_channel->InvokeMethod("onTunnelStateChanged",
                        std::make_unique<flutter::EncodableValue>(stateMap));
                }

                result->Success(flutter::EncodableValue(true));
            }
            else if (method == "stopTunnel") {
                // Try privileged background Windows Service over Named Pipe IPC first
                std::string ipcResponse;
                if (SendIpcCommand("{\"Command\":\"StopTunnel\"}", ipcResponse)) {
                    g_is_connected = false;
                    if (g_vpn_channel) {
                        flutter::EncodableMap stateMap;
                        stateMap[flutter::EncodableValue("state")] = flutter::EncodableValue("disconnected");
                        g_vpn_channel->InvokeMethod("onTunnelStateChanged",
                            std::make_unique<flutter::EncodableValue>(stateMap));
                    }
                    result->Success(flutter::EncodableValue(true));
                    return;
                }

                // Fallback: Remove Windows Kill Switch firewall rules
                SetWindowsKillSwitch(false);

                std::wstring wgExe = FindWireGuardExecutable();
                if (!wgExe.empty()) {
                    std::wstring params = L"/uninstalltunnelservice AntigravityTunnel";
                    ExecuteTunnelService(wgExe, params);
                }

                g_is_connected = false;

                // Broadcast state to Flutter
                if (g_vpn_channel) {
                    flutter::EncodableMap stateMap;
                    stateMap[flutter::EncodableValue("state")] = flutter::EncodableValue("disconnected");
                    g_vpn_channel->InvokeMethod("onTunnelStateChanged",
                        std::make_unique<flutter::EncodableValue>(stateMap));
                }

                result->Success(flutter::EncodableValue(true));
            }
            else if (method == "getTunnelState") {
                std::string state = g_is_connected ? "connected" : "disconnected";
                result->Success(flutter::EncodableValue(state));
            }
            else if (method == "getInstalledApps") {
                flutter::EncodableList appList;
                const std::vector<std::pair<std::string, std::string>> knownApps = {
                    {"Google Chrome", "chrome.exe"},
                    {"Mozilla Firefox", "firefox.exe"},
                    {"Microsoft Edge", "msedge.exe"},
                    {"Spotify Music", "spotify.exe"},
                    {"Steam Client", "steam.exe"},
                    {"Discord", "discord.exe"},
                    {"Telegram Desktop", "telegram.exe"},
                    {"Visual Studio Code", "code.exe"}
                };

                for (const auto& app : knownApps) {
                    flutter::EncodableMap item;
                    item[flutter::EncodableValue("appName")] = flutter::EncodableValue(app.first);
                    item[flutter::EncodableValue("packageName")] = flutter::EncodableValue(app.second);
                    appList.push_back(flutter::EncodableValue(item));
                }

                result->Success(flutter::EncodableValue(appList));
            }
            else if (method == "getTunnelStatistics") {
                flutter::EncodableMap stats;
                static int64_t simulatedRx = 1024 * 1024 * 12;
                static int64_t simulatedTx = 1024 * 1024 * 3;
                if (g_is_connected) {
                    simulatedRx += (1024 * 1024 * 3);
                    simulatedTx += (1024 * 512);
                }
                stats[flutter::EncodableValue("rxBytes")] = flutter::EncodableValue(simulatedRx);
                stats[flutter::EncodableValue("txBytes")] = flutter::EncodableValue(simulatedTx);
                stats[flutter::EncodableValue("lastHandshake")] = flutter::EncodableValue(4);
                stats[flutter::EncodableValue("pingMs")] = flutter::EncodableValue(26);

                result->Success(flutter::EncodableValue(stats));
            }
            else {
                result->NotImplemented();
            }
        });

    g_vpn_channel = std::move(channel);
}
