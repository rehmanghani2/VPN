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
            else {
                result->NotImplemented();
            }
        });

    g_vpn_channel = std::move(channel);
}
