# Phase 8: DNS Threat Shield (CyberSec / NetShield) & Built-in VPN Speed Test Engine

## 1. Overview & Architecture

Phase 8 equips the Commercial VPN Platform with two marquee enterprise features matching NordVPN CyberSec / Threat Protection and Proton NetShield:
1. **Hardware-Level Zero-Leak DNS Threat Shield**:
   - Dynamic Unbound Response Policy Zones (RPZ) / `local-zone` rules blocking phishing, ransomware, botnets, cryptominers, tracking telemetry, and advertisements before packets reach client devices.
2. **Built-in Real-Time Speed & Latency Benchmark Engine**:
   - Live multi-stage benchmarking (Ping, Jitter, Download Throughput, Upload Throughput) directly against distributed edge nodes with a neon speedometer gauge.

```
+-----------------------------------------------------------------------------------------------+
|                                      Client Device (Flutter)                                  |
|                                                                                               |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
|  |    SpeedometerGauge       |   |      ThreatShieldScreen     |   |      StorageService   |  |
|  |  - Live Needle Sweep      |   |  - Full Shield (Ads+Malware)|   |  - Threat Shield Mode |  |
|  |  - Ping / Jitter Badges   |   |  - Malware Only             |   |  - DNS Configuration  |  |
|  |  - Download / Upload Mbps |   |  - Threat Feeds Live Count  |   |                       |  |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
+------------------------------^---------------------------------^------------------------------+
                               |                                 |
               HTTP Chunked Streaming                      DNS Resolution
              (Upload / Download Tests)                   (WireGuard Tunnel)
                               |                                 |
+------------------------------v---------------------------------v------------------------------+
|                              Linux Edge Node / Control Plane API                              |
|                                                                                               |
|  +-------------------------------+   +-----------------------------+   +-------------------+  |
|  |     SpeedTestController       |   |       Unbound DNS RPZ       |   |    Node Agent     |  |
|  |  GET  /vpn/speedtest/ping     |   | - 154,820 Blocked Domains   |   |  /speedtest/ping  |  |
|  |  GET  /vpn/speedtest/download |   | - Malware & Phishing NXDOM  |   |  /speedtest/down  |  |
|  |  POST /vpn/speedtest/upload   |   | - Ads & Telemetry Dropped   |   |  /speedtest/up    |  |
|  +-------------------------------+   +-----------------------------+   +-------------------+  |
+-----------------------------------------------------------------------------------------------+
```

---

## 2. DNS Threat Shield

### 2.1 Threat Intelligence Sources & Consolidation
Automated shell provisioner: [`infrastructure/scripts/update-dns-threat-shield.sh`](file:///e:/Projects/VPN/infrastructure/scripts/update-dns-threat-shield.sh):
- **Phishing & Credential Theft**: Malware-Filter Project & URLhaus live blocklists.
- **Ransomware & Botnet C2**: URLhaus Hostfile.
- **Ads, Trackers & Fingerprinting**: StevenBlack Unified hosts (100,000+ vetted domains).
- **Compilation**: Synthesizes Unbound DNS `local-zone: "domain" always_nxdomain` rules directly into `/etc/unbound/unbound.conf.d/`.

### 2.2 Client-Configurable Protection Levels
- **`all` (Full Threat Shield — Recommended)**:
  - Blocks malware, phishing, cryptominers, banner ads, tracking beacons, and analytics.
  - Resolves via filtered Unbound gateway (`10.8.0.53`).
- **`malware_only` (Essential Protection)**:
  - Blocks confirmed malware and phishing while leaving ads intact.
- **`off` (Disabled)**:
  - Standard recursive Unbound DNS without filtering.

---

## 3. Speed & Latency Benchmark Engine

### 3.1 Backend Benchmarking Protocol
- **Ping & Jitter Probe (`GET /api/v1/vpn/speedtest/ping`)**:
  - Responds with millisecond-precision timestamps.
  - Client sends 5 successive probes; calculates average latency and jitter:
    $$\text{Jitter} = \frac{1}{N-1} \sum_{i=2}^N | \text{Ping}_i - \text{Ping}_{i-1} |$$
- **High-Throughput Download Stream (`GET /api/v1/vpn/speedtest/download?sizeMb=4`)**:
  - Streams synthetic 64KB zero-copy memory buffers (`Buffer.alloc`) over chunked HTTP with `no-cache` headers.
  - Client calculates real-time Mbps:
    $$\text{Mbps} = \frac{\text{Bytes Received} \times 8}{\text{Elapsed Seconds} \times 1,000,000}$$
- **Bandwidth Upload Sink (`POST /api/v1/vpn/speedtest/upload`)**:
  - Accepts raw binary payload stream and returns precise upload bandwidth and duration metrics.

### 3.2 Flutter Speedometer Gauge UI
- [`SpeedometerGauge`](file:///e:/Projects/VPN/mobile/lib/features/speedtest/widgets/speedometer_gauge.dart):
  - 270-degree radial sweep CustomPainter with glowing gradient arcs, tick marks, digital readout, and dynamic stage pills (`TESTING LATENCY...`, `TESTING DOWNLOAD...`, `TESTING UPLOAD...`, `BENCHMARK COMPLETE`).
- [`SpeedTestScreen`](file:///e:/Projects/VPN/mobile/lib/features/speedtest/screens/speed_test_screen.dart):
  - Displays whether testing through active VPN tunnel or direct network.
  - 4-quadrant live metric badges (Ping, Jitter, Download Mbps, Upload Mbps).
  - Quick launcher icon in the Home Screen AppBar (`Icons.speed`).
