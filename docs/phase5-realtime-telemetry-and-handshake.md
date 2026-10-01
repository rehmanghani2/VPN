# Commercial VPN Platform - Phase 5: Real-time Handshake & Performance Telemetry

## 1. Overview

Commercial VPN users demand transparency and immediate visual confirmation that their connection is fast, stable, and encrypted. Phase 5 establishes an end-to-end performance and telemetry pipeline:
1. **Live Round-Trip Latency (Ping in ms)**: Continuous measurement of packet transit times to the active edge node.
2. **Real-time Bandwidth Speeds**: Per-second upload ($\uparrow$) and download ($\downarrow$) speeds alongside cumulative session totals.
3. **WireGuard Handshake & Keepalive Health**: Monitoring the 2-minute WireGuard cryptographic re-keying lifecycle and the 25-second persistent keepalive heartbeat.
4. **Live Throughput Sparkline Graph**: A custom-painted 30-second rolling speed curve with dual gradient fills.

---

## 2. Telemetry Architecture

```
┌────────────────────────────────────────────────────────┐
│                   OS Kernel Layer                      │
│                                                        │
│  [ Android VpnService ]        [ Windows Wintun ]      │
│  • TrafficStats UID bytes      • GetIfEntry2 MIB stats │
│  • WireGuard handshake timer   • Keepalive counter     │
└───────────────┬────────────────────────┬───────────────┘
                │                        │
                ▼                        ▼
┌────────────────────────────────────────────────────────┐
│                 MethodChannel Bridge                   │
│          com.vpnplatform.app/vpn                       │
│          method: "getTunnelStatistics"                 │
│                                                        │
│  Returns: { rxBytes, txBytes, lastHandshake, pingMs }  │
└──────────────────────────┬─────────────────────────────┘
                           │ Periodic 1Hz Polling
                           ▼
┌────────────────────────────────────────────────────────┐
│               Flutter State Provider                   │
│                    (VpnProvider)                       │
│                                                        │
│  • Calculates delta speeds: (rx - prevRx) / dt         │
│  • Maintains 30-sample rolling history buffer          │
│  • Updates immutable VpnStatistics state               │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│               Cyber-Dark User Interface                │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 12.4 MB/s ↓ (450 MB)   1.8 MB/s ↑ (85 MB)  🟢 28ms│  │
│  │ Handshake: 4s ago                                │  │
│  │ ──────────────────────────────────────────────── │  │
│  │ [ ~~~~ Live Dual-Gradient Throughput Chart ~~~~ ]│  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 3. Data Plane & Keepalive Protocol

WireGuard incorporates two key cryptographic timers:
1. **Rekey-After-Time (`120s`)**: Every 2 minutes, peers initiate a new 1-RTT cryptographic handshake using ephemeral keys (providing Perfect Forward Secrecy, PFS).
2. **PersistentKeepalive (`25s`)**: WireGuard sends an empty encrypted packet every 25 seconds if no payload data has been transmitted. This maintains active NAT translation entries on intermediate Wi-Fi routers and cellular carrier CGNAT gateways.

The UI displays:
```
⚡ Handshake: 4s ago
```
Resetting whenever a keepalive or re-keying packet is validated.

---

## 4. UI Components Implemented

1. **`VpnStatistics` Model (`mobile/lib/features/vpn/models/vpn_statistics.dart`)**:
   - `rxSpeed`, `txSpeed`, `totalRxBytes`, `totalTxBytes`, `pingMs`, `lastHandshakeSeconds`.
   - Formatters: `formatSpeed()` (KB/s, MB/s) and `formatBytes()` (KB, MB, GB).
   - Rolling history queues: `rxHistory`, `txHistory`.
2. **`TelemetryGraph` (`mobile/lib/features/vpn/widgets/telemetry_graph.dart`)**:
   - CustomPainter widget using quadratic/cubic Bezier curves.
   - Dual gradient glows: Cyan (`#06B6D4`) for downloads, Accent (`#8B5CF6`) for uploads.
   - Dynamic auto-scaling based on peak throughput observed.
3. **Live Dashboard (`mobile/lib/features/vpn/screens/home_screen.dart`)**:
   - Integrated directly beneath the connect button on the Home screen when tunnel is active.
   - Real-time latency indicator with status dot (`🟢 28 ms`).
