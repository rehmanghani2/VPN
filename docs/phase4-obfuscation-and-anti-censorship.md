# Commercial VPN Platform - Phase 4: Anti-DPI Traffic Obfuscation & Camouflage

## 1. The Censorship & DPI Challenge

Standard WireGuard packets have fixed, deterministic byte patterns:
- **Handshake Initiation**: Always 148 bytes, begins with byte `0x01` (`0x01 0x00 0x00 0x00`).
- **Handshake Response**: Always 92 bytes, begins with byte `0x02`.
- **Keepalive / Data**: Begins with byte `0x04`.

Deep Packet Inspection (DPI) firewalls (used in restricted enterprise networks, university dorms, hotels, and countries with active state censorship like China's GFW, Iran, and Russia) easily identify these static packet headers and throttle or completely drop the UDP stream within 3–10 seconds of connection initiation.

To achieve commercial-grade resilience comparable to **Proton VPN's Stealth protocol**, **Surfshark's Camouflage mode**, and **AmneziaWG**, the Antigravity VPN platform incorporates a multi-tiered Anti-DPI Obfuscation & Camouflage Engine.

---

## 2. Multi-Layer Obfuscation Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Client Application                   │
│                                                        │
│  User selects "Stealth Camouflage (Anti-DPI)"          │
│  • MTU dynamically tuned to 1280 (prevents fragmentation)│
│  • Destination Port redirected to 443 (standard HTTPS) │
│  • Magic Packet Header Substitution (AmneziaWG format) │
└──────────────────────────┬─────────────────────────────┘
                           │ Obfuscated UDP/TLS (Port 443)
                           │ Indistinguishable from HTTPS
                           ▼
┌────────────────────────────────────────────────────────┐
│               Intermediate Network / ISP               │
│                                                        │
│   [ DPI Inspection Filter ]                            │
│   - "Is it WireGuard type 0x01?" ──► NO                │
│   - "Does it target standard UDP 51820?" ──► NO        │
│   - "Is it Port 443 HTTPS traffic?" ──► YES (ALLOW)    │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│           Linux Edge Node (e.g. Frankfurt)             │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Anti-DPI Proxy Daemon (Port 443 TCP/UDP)         │  │
│  │                                                  │  │
│  │ • Replaces scrambled magic headers with Type 1/2 │  │
│  │ • Strips outer junk padding                      │  │
│  │ • Forwards to in-kernel WireGuard 127.0.0.1:51820│  │
│  │ • Active Probing Defense: returns benign HTML to │  │
│  │   suspicious TCP scanners                        │  │
│  └───────────────────────┬──────────────────────────┘  │
│                          │ Clear local loopback UDP    │
│                          ▼                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │ WireGuard Kernel Interface (wg0 @ 51820)         │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 3. Core Anti-DPI Mechanisms

### 3.1. Magic Header Substitution (AmneziaWG Mechanism)
- **Standard Initiation**: `0x00000001` $\to$ Replaced with custom randomized marker `0xa1b2c3d4`.
- **Standard Response**: `0x00000002` $\to$ Replaced with custom randomized marker `0xd4c3b2a1`.
- The edge proxy transparently swaps these bytes on ingress and egress, so the native Linux kernel WireGuard module processes ordinary packets while the public wire only ever carries non-standard bytes.

### 3.2. Port 443 Camouflage
- Standard WireGuard runs on port `51820/udp`, which many network firewalls block by default.
- By binding the edge obfuscation daemon to **Port 443** (the universal HTTPS web port), the VPN traffic flows freely across almost any network without triggering port-blocking firewalls.

### 3.3. Active Probing Defense (Anti-GFW)
- State censors use **active probing scanners**: when they observe encrypted traffic to an IP:port, automated robots connect via TCP and send probe packets to determine if a VPN daemon or proxy is listening.
- If the proxy encounters unexpected HTTP/TLS scan probes, it serves a benign HTTP landing page (`"IT Infrastructure Gateway - Server operating normally"`), deceiving the censor into categorizing the host as an ordinary web server rather than a VPN node.

---

## 4. Backend Control Plane Integration

1. **Prisma Server Attributes**:
   - `isObfuscated`: Flag indicating stealth capabilities.
   - `obfuscationPort`: Listening port (default 443).
   - `obfuscationProtocol`: `'WIREGUARD_OBFUSCATED'` or `'SHADOWSOCKS_TLS'`.
2. **Dynamic Protocol Resolution**:
   - In `POST /api/v1/vpn/connect`:
     - If the client passes `'protocol': 'stealth_obfuscated'`, the Smart Connect algorithm prioritizes servers with `isObfuscated: true`.
     - The connection payload sets `endpoint: "${publicIp}:${obfuscationPort}"` and lowers client MTU to `1280` to accommodate padding overhead.

---

## 5. Client UI Experience

1. **Protocol Selection**:
   - In **Settings $\to$ VPN Protocol**, users can switch between:
     - **WireGuard Standard (Recommended for Speed)**: Maximum throughput for open networks.
     - **Stealth Camouflage (Anti-DPI / Censorship)**: Maximum evasion on restricted networks.
2. **Server Catalog Filters**:
   - Filter chips allow instant toggling between **All Servers**, **Standard WireGuard**, and **Stealth / Anti-DPI (Port 443)**.
   - Dedicated `STEALTH 443` badges identify obfuscation-ready nodes.
3. **Real-time Status Badges**:
   - Home screen displays active badges: `🛡️ Kill Switch`, `⚡ Split Tunneling`, and `🥷 Stealth Anti-DPI`.
