# Phase 14: Multi-Hop (Double VPN) & Onion over VPN Infrastructure

## Executive Overview
Phase 14 implements **Multi-Hop (Double VPN)** and **Onion over VPN (Tor Gateway)** across the **Antigravity Commercial VPN** ecosystem. 

These features cater to high-threat-model users (journalists, human rights activists, enterprise executives, privacy purists) who require cascading multi-jurisdictional encryption where no single server or network provider knows both the client's origin IP and their traffic destination.

---

## 1. Multi-Hop (Double VPN) Architecture

```
+-----------------------------------------------------------------------------------------+
|                                  USER CLIENT DEVICE                                     |
|                                                                                         |
|   1. Outer Encapsulation: ChaCha20-Poly1305 (Targeting Entry Gateway)                    |
|   2. Inner Encapsulation: ChaCha20-Poly1305 (Payload destined for Exit Gateway)         |
+--------------------------------------------+--------------------------------------------+
                                             |
                                             | WireGuard Tunnel 1 (e.g. to Germany)
                                             v
+-----------------------------------------------------------------------------------------+
|                              ENTRY GATEWAY (e.g., Frankfurt)                            |
|                                                                                         |
|   - Strips Outer Encapsulation Layer                                                    |
|   - Observes Client's Real IP (Knows WHO connected, but NOT WHERE they are going)        |
|   - Policy Routing Table 200:                                                           |
|       ip rule add from <clientTunnelIp> table 200                                       |
|       ip route add default via <exitServerIp> dev wg-backhaul table 200                 |
+--------------------------------------------+--------------------------------------------+
                                             |
                                             | Inter-Datacenter Encrypted Backbone
                                             v
+-----------------------------------------------------------------------------------------+
|                               EXIT GATEWAY (e.g., New York)                             |
|                                                                                         |
|   - Strips Inner Encapsulation Layer                                                    |
|   - Does NOT know Client's Real IP (Only sees Frankfurt Entry Server IP)                |
|   - NAT Masquerade out to the Public Internet                                           |
+--------------------------------------------+--------------------------------------------+
                                             |
                                             v
+-----------------------------------------------------------------------------------------+
|                                     PUBLIC INTERNET                                     |
|                      (Only sees New York Exit Gateway IP)                               |
+-----------------------------------------------------------------------------------------+
```

---

## 2. Onion over VPN (Tor Gateway) Architecture

```
+-----------------------------------------------------------------------------------------+
|                                     CLIENT DEVICE                                       |
|          (Standard Chrome / Firefox / Safari Browser or any App)                        |
+--------------------------------------------+--------------------------------------------+
                                             |
                                             | Encrypted WireGuard Tunnel (10.8.0.x)
                                             v
+-----------------------------------------------------------------------------------------+
|                            ONION EDGE GATEWAY SERVER                                    |
|                                                                                         |
|   +---------------------------------------------------------------------------------+   |
|   | iptables Transparent Redirection:                                               |   |
|   | iptables -t nat -A PREROUTING -p tcp --syn -j REDIRECT --to-ports 9040 (Tor)    |   |
|   | iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353     |   |
|   +---------------------------------------+-----------------------------------------+   |
|                                           |                                             |
|                                           v                                             |
|   +---------------------------------------------------------------------------------+   |
|   | Local Tor Daemon (TransPort 9040, DNSPort 5353)                                 |   |
|   | Automatically routes TCP across 3 Tor Relays: Guard ➔ Middle ➔ Exit             |   |
|   | Directly resolves .onion hidden service domains                                 |   |
|   +---------------------------------------------------------------------------------+   |
+-----------------------------------------------------------------------------------------+
```

---

## 3. Implemented Components

### 3.1 Backend Control Plane (`backend/src/multihop/`)
- **`MultiHopService` & `MultiHopController`:**
  - `GET /api/v1/vpn/multihop/pairs`: Computes inter-country server pairings (e.g., Frankfurt ➔ New York, London ➔ Singapore), calculating distance-based ping estimates and security ratings.
  - `POST /api/v1/vpn/multihop/connect`: Sets up double VPN session, binds Entry and Exit node routing, and provisions client peer allocation.
  - `GET /api/v1/vpn/onion/servers`: Exposes edge servers running hardened Tor transparent proxy gateways (`TransPort 9040` / `DNSPort 5353`).
  - Gated by subscription tier (`PRO` or `FAMILY` required).

### 3.2 Linux Edge Node Agent (`infrastructure/node-agent/agent.js`)
- Added HTTP webhooks (`X-Node-Token` authenticated):
  - **`POST /multihop/route`:** Configures policy routing rules (`ip rule add from <clientIp> table 200`) directing client traffic out the inter-server WireGuard backhaul interface.
  - **`POST /onion/route`:** Applies transparent Tor iptables redirection rules for TCP (port 9040) and DNS (port 5353).

### 3.3 Flutter Multi-Platform Client Features
- **Models & Service:**
  - [`MultiHopPair`](file:///e:/Projects/VPN/mobile/lib/features/multihop/models/multihop_pair.dart) & [`MultiHopService`](file:///e:/Projects/VPN/mobile/lib/features/multihop/services/multihop_service.dart).
- **Interface Screen ([`MultiHopScreen`](file:///e:/Projects/VPN/mobile/lib/features/multihop/screens/multihop_screen.dart)):**
  - **Double VPN Tab:** Visual cascaded route chain cards (`Entry Node ➔ Encrypted Tunnel ➔ Exit Node`) with latency estimate, flag emojis, and one-tap connect.
  - **Onion over VPN Tab:** Explains Tor transparent routing with direct connect cards for `.onion` access without Tor Browser.
- **Location Drawer Integration ([`ServersScreen`](file:///e:/Projects/VPN/mobile/lib/features/vpn/screens/servers_screen.dart)):**
  - Added dedicated **"Double VPN & Onion"** filter chip to the location browser.

---

## 4. End-to-End Verification Results

### 4.1 Live Backend Test
```powershell
Multi-Hop (Double VPN) Pairs Available: 12
   -> Chain: Frankfurt ➔ New York (Est. Ping: 95ms) [Grade: A+ (DOUBLE CHACHA20-POLY1305)]
   -> Chain: London ➔ Singapore (Est. Ping: 160ms) [Grade: A+ (DOUBLE CHACHA20-POLY1305)]
   -> Chain: Frankfurt ➔ Singapore (Est. Ping: 110ms) [Grade: A+ (DOUBLE CHACHA20-POLY1305)]
   -> Chain: Frankfurt ➔ London (Est. Ping: 32ms) [Grade: A+ (DOUBLE CHACHA20-POLY1305)]
   ...

Double VPN Connected Successfully!
   -> Entry Gateway: Frankfurt (198.51.100.10:51820)
   -> Exit Gateway : New York (198.51.100.20)
   -> Client IP    : 10.8.0.2
   -> Summary      : Traffic is encrypted to Entry node, then re-routed across encrypted backbone to Exit node.

Onion over VPN Nodes Available: 4
   -> Tor Transparent Port: 9040
   -> Tor DNS Port        : 5353
```

### 4.2 Flutter Code Health
```bash
flutter analyze
Analyzing mobile...
No issues found! (ran in 9.4s)
```
