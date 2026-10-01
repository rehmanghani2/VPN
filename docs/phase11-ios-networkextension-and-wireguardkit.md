# Phase 11: Native iOS Implementation (NetworkExtension Framework & App Group IPC)

## 1. Overview & Architecture

iOS requires distinct architectural considerations compared to Android and Windows:
- All VPN traffic interception must occur within Apple's sandboxed **`NetworkExtension` framework**.
- The main Flutter UI and the VPN packet extension run as two isolated OS processes.
- An **App Group Container (`group.com.antigravity.vpn`)** serves as the IPC shared memory bridge for passing WireGuard credentials, zero-leak DNS routes, and live 1Hz telemetry statistics (`bytesIn`, `bytesOut`, `lastHandshake`).
- Strict hardware-level Kill Switch is enforced via `NEPacketTunnelNetworkSettings.includeAllNetworks = true` (introduced in iOS 14.2+).

```
+-----------------------------------------------------------------------------------------------+
|                                      iOS Host Environment                                     |
|                                                                                               |
|  +-------------------------------------+             +-------------------------------------+  |
|  |     Main Flutter App (Runner)       |             |   PacketTunnelProvider Extension    |  |
|  |                                     |             |                                     |  |
|  |  +-------------------------------+  |             |  +-------------------------------+  |  |
|  |  |      AppDelegate.swift        |  |             |  |   PacketTunnelProvider.swift  |  |  |
|  |  | - MethodChannel listener      |  |             |  | - Virtual TUN (IPv4 / IPv6)   |  |  |
|  |  | - NETunnelProviderManager     |  |             |  | - Zero-Leak NEDNSSettings     |  |  |
|  |  | - Reads App Group Stats       |  |             |  | - includeAllNetworks (Killsw) |  |  |
|  |  +-------------------------------+  |             |  | - NWPathMonitor (Roaming)     |  |  |
|  +------------------^------------------+             +------------------^------------------+  |
|                     |                                                   |                     |
|                     |     Shared App Group: "group.com.antigravity.vpn" |                     |
|                     +---------------------<==>--------------------------+                     |
|                                     UserDefaults(suiteName:)                                  |
|                                 (bytesIn, bytesOut, lastHandshake)                            |
+-----------------------------------------------------------------------------------------------+
```

---

## 2. Component Specifications

### 2.1 [`PacketTunnelProvider.swift`](file:///e:/Projects/VPN/mobile/ios/PacketTunnel/PacketTunnelProvider.swift)
- **Subclass**: `NEPacketTunnelProvider`
- **Network Settings Configuration**:
  - `NEIPv4Settings`: Injects client tunnel IPv4 (`10.8.0.x/24`) and routes `0.0.0.0/0`.
  - `NEIPv6Settings`: Injects client tunnel IPv6 (`fd42:42:42::x/64`) and routes `::/0`.
  - `NEDNSSettings`: Catch-all `matchDomains = [""]` forcing 100% of DNS lookups to the designated resolver (e.g. `10.8.0.53` Threat Shield or `10.8.0.1` Standard), preventing any local ISP DNS leakage.
  - `includeAllNetworks`: Configured to `true` when Kill Switch is toggled, dropping all non-tunnel traffic even during re-keying or momentary packet loss.
- **Cellular ↔ Wi-Fi Network Roaming**:
  - Utilizes `NWPathMonitor` on a dedicated dispatch queue to detect active interface transitions without severing the WireGuard tunnel session.
- **Live Telemetry Ticker**:
  - 1Hz timer writes cumulative `bytesIn`, `bytesOut`, and `lastHandshake` timestamps to shared `UserDefaults(suiteName: "group.com.antigravity.vpn")`.

### 2.2 [`AppDelegate.swift`](file:///e:/Projects/VPN/mobile/ios/Runner/AppDelegate.swift)
- **Flutter MethodChannel**: `com.vpnplatform.app/vpn`
- **Method Handlers**:
  - `startTunnel`: Loads `NETunnelProviderManager`, serializes connection arguments (endpoint, keys, MTU, killswitch), and triggers `manager.connection.startVPNTunnel()`.
  - `stopTunnel`: Halts the tunnel and triggers OS notification observer.
  - `getTunnelState`: Returns `"connected"`, `"connecting"`, or `"disconnected"`.
  - `getTunnelStatistics`: Reads shared App Group memory and passes live `bytesIn`, `bytesOut`, `lastHandshake`, and `isConnected` to Flutter.
  - `openVpnSettings`: Deep-links directly to iOS System VPN Settings.

### 2.3 Apple Entitlements
- **[`Runner.entitlements`](file:///e:/Projects/VPN/mobile/ios/Runner/Runner.entitlements)** & **[`PacketTunnel.entitlements`](file:///e:/Projects/VPN/mobile/ios/PacketTunnel/PacketTunnel.entitlements)**:
  - `com.apple.developer.networking.networkextension` -> `packet-tunnel-provider`
  - `com.apple.security.application-groups` -> `group.com.antigravity.vpn`
