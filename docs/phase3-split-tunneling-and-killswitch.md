# Commercial VPN Platform - Phase 3: Split Tunneling & Zero-Leak Kill Switch

## 1. Overview

In commercial VPN clients (such as NordVPN, ExpressVPN, and Proton VPN), security and flexibility are the two most critical customer requirements:
1. **Kill Switch**: If the VPN connection drops unexpectedly, network traffic must NOT leak onto the unencrypted public Wi-Fi or ISP network.
2. **Split Tunneling**: Users need the flexibility to route low-latency games, local banking apps, or streaming services outside the VPN, or conversely, only force sensitive apps (browsers, torrents) through the encrypted tunnel while leaving everyday apps on normal internet.
3. **Local LAN Bypass**: Users must retain access to local network devices (Wi-Fi printers, Chromecast, local NAS servers) without leaving the VPN tunnel.

---

## 2. Kill Switch Architecture

```
┌────────────────────────────────────────────────────────┐
│                     Client Machine                     │
│                                                        │
│  [ Applications ] ────► [ OS Network Stack ]           │
│                                │                       │
│                   Is VPN Tunnel Connected?             │
│                      ├── YES ──► Route through wg0     │
│                      │           (ChaCha20-Poly1305)   │
│                      │                                 │
│                      └── NO (Tunnel Dropped/Unstable)  │
│                            │                           │
│                     Is Kill Switch ON?                 │
│                      ├── YES ──► [ BLOCK ALL TRAFFIC ] │
│                      │           (Zero IP/DNS leak)    │
│                      │                                 │
│                      └── NO ───► Default Gateway       │
│                                  (Unencrypted ISP)     │
└────────────────────────────────────────────────────────┘
```

### 2.1. Android Implementation
- **In-App Kill Switch**: 
  - `VpnService.Builder.setBlocking(true)` ensures that all packet sockets bound to the interface block rather than falling back to cellular/Wi-Fi when interface drops.
  - Active notification dynamically informs the user with `🛡️ Kill Switch Active`.
- **System-Level Hardware Kill Switch (Always-on VPN)**:
  - Through the in-app direct shortcut (`android.net.vpn.SETTINGS`), users can toggle Android's native OS-level **"Block connections without VPN"**.
  - Under this Android OS policy, the Android Linux kernel refuses to establish any socket outside the designated VPN UID, guaranteeing 100% leak-proof security even during device boot.

### 2.2. Windows Implementation
- **Windows Filtering Platform (WFP) / Windows Firewall Rules**:
  - Outbound Rule `AntigravityAllowEndpoint`: Allows UDP traffic exclusively to `<SERVER_IP>:<PORT>`.
  - Outbound Rule `AntigravityAllowDHCP`: Preserves local IP lease renewals (`UDP 67/68`).
  - Outbound Rule `AntigravityAllowLoopback`: Allows internal communication (`127.0.0.1`).
  - Outbound Rule `AntigravityKillSwitchBlock`: Rejects all unencrypted outbound traffic across physical NICs.
  - When the user gracefully disconnects, the blocking rules are cleanly removed. If the tunnel terminates abnormally or the app crashes, the blocking rules protect the user from leaking cleartext packets.

---

## 3. Split Tunneling Architecture

### 3.1. Routing Policies
Our client supports two modes:
1. **Bypass Mode (Default)**:
   - All system traffic is encrypted and routed through the WireGuard tunnel.
   - User-selected applications (e.g., Banking, Netflix, Steam) bypass the VPN interface and communicate directly over the physical network interface.
2. **Exclusive Mode ("Only Route Selected Apps")**:
   - Only explicitly chosen applications (e.g., Chrome, Telegram, BitTorrent) are encrypted through the VPN interface.
   - All other applications use regular unencrypted local connectivity.

### 3.2. Android Native Hook
Using Android's official `VpnService.Builder`:
```kotlin
if (splitTunnelingEnabled && splitTunnelApps.isNotEmpty()) {
    if (splitTunnelingMode == "only_vpn") {
        for (pkg in splitTunnelApps) {
            builder.addAllowedApplication(pkg)
        }
    } else {
        for (pkg in splitTunnelApps) {
            builder.addDisallowedApplication(pkg)
        }
    }
}
```

### 3.3. App Enumeration
The platform bridge queries Android's `PackageManager` for launchable user-facing packages (`getLaunchIntentForPackage`), sorts them alphabetically, and delivers them to Flutter with app title and package identifier for interactive selection in `SplitTunnelingScreen`.

---

## 4. UI Components Implemented

1. **`SplitTunnelingScreen` (`features/settings/screens/split_tunneling_screen.dart`)**:
   - Master Toggle (ON/OFF).
   - Radio policy selector (Bypass vs. Exclusive).
   - Local LAN Bypass toggle.
   - Live search filter across installed apps.
   - Counter chip showing selected applications.
   - Checkbox list with application icons and identifiers.
2. **`SettingsScreen` (`features/settings/screens/settings_screen.dart`)**:
   - Kill Switch toggle with direct Android system settings deep-link.
   - Split Tunneling summary row with live badge (`ON` / `OFF` and count).
3. **`HomeScreen` (`features/vpn/screens/home_screen.dart`)**:
   - Live cyber-glow badges for `🛡️ Kill Switch` and `⚡ Split (N apps)`.
