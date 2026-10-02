# Phase 13: Dedicated IP & Port Forwarding Infrastructure

## Executive Overview
Phase 13 establishes the enterprise-grade **Dedicated IP** and **Dynamic Port Forwarding (NAT)** subsystems for the **Antigravity Commercial VPN** platform. High-tier commercial users require exclusive, clean static IPs for corporate whitelisting, CAPTCHA elimination, and secure banking, as well as dynamic NAT port mapping for peer-to-peer (P2P/BitTorrent) hosting, self-hosted game servers, and remote desktop access.

---

## 1. System Architecture & Packet Flow

```
+-----------------------------------------------------------------------------------------+
|                                    INTERNET TRAFFIC                                     |
+--------------------+--------------------------------------------------------------------+
                     |
                     | Inbound Packet to Public IP (e.g., 198.51.100.10:40000)
                     v
+-----------------------------------------------------------------------------------------+
|                               EDGE SERVER LINUX KERNEL                                  |
|                                                                                         |
|   +---------------------------------------------------------------------------------+   |
|   | PREROUTING NAT (DNAT):                                                          |   |
|   | iptables -t nat -A PREROUTING -p tcp --dport 40000 -j DNAT                      |   |
|   |          --to-destination 10.8.0.2:8080                                         |   |
|   +---------------------------------------+-----------------------------------------+   |
|                                           |                                             |
|                                           v                                             |
|   +---------------------------------------------------------------------------------+   |
|   | FORWARD FILTER:                                                                 |   |
|   | iptables -A FORWARD -p tcp -d 10.8.0.2 --dport 8080 -j ACCEPT                   |   |
|   +---------------------------------------+-----------------------------------------+   |
|                                           |                                             |
|                                           | Encapsulated via WireGuard Tunnel (wg0)     |
|                                           v                                             |
|   +---------------------------------------------------------------------------------+   |
|   | POSTROUTING SNAT (For Dedicated IP peers):                                      |   |
|   | iptables -t nat -A POSTROUTING -s 10.8.0.2 -j SNAT --to-source <DEDICATED_IP>   |   |
|   +---------------------------------------+-----------------------------------------+   |
+-------------------------------------------|---------------------------------------------+
                                            |
                                            v
+-----------------------------------------------------------------------------------------+
|                              CLIENT DEVICE (10.8.0.2)                                   |
|                                                                                         |
|   +---------------------------------------------------------------------------------+   |
|   | Local Inbound Application (Listening on internal port :8080)                     |   |
|   | Web Server / P2P Client / Minecraft / Remote Access                             |   |
|   +---------------------------------------------------------------------------------+   |
+-----------------------------------------------------------------------------------------+
```

---

## 2. Implemented Components

### 2.1 Backend Control Plane Subsystems

#### A. Database Schema (`backend/prisma/schema.prisma`)
- **`DedicatedIp` Model:**
  - `id`: UUID primary key
  - `userId`: Relation to `User`
  - `serverId`: Relation to `VpnServer`
  - `publicIp`: Unique clean IPv4 address allocated to user
  - `status`: `ACTIVE`, `RESERVED`, `EXPIRED`
  - `expiresAt`: Expiration timestamp (30-day billing cycle)
- **`PortForwardRule` Model:**
  - `id`: UUID primary key
  - `userId`, `deviceId`, `serverId` relations
  - `externalPort`: Allocated port (range `40000-55000` or custom requested)
  - `internalPort`: Destination port on client device (`1-65535`)
  - `protocol`: `TCP`, `UDP`, or `BOTH`
  - `status`: `ACTIVE`, `DISABLED`
  - Unique constraint: `[serverId, externalPort, protocol]`

#### B. Port Forwarding Module (`backend/src/port-forwarding/`)
- **`PortForwardingService` & `PortForwardingController`:**
  - `GET /api/v1/port-forwarding`: Lists all active port forward rules for authenticated user.
  - `POST /api/v1/port-forwarding`: Allocates a collision-free high port (`40000-55000`) on the target server, verifies active connection on device, creates database record, and notifies the edge node agent.
  - `DELETE /api/v1/port-forwarding/:id`: Flushes iptables DNAT rules on edge node and releases port allocation.
  - Plan gating: Enforces `PRO` or `FAMILY` subscription.

#### C. Dedicated IP Module (`backend/src/dedicated-ip/`)
- **`DedicatedIpService` & `DedicatedIpController`:**
  - `GET /api/v1/dedicated-ip`: Lists user's active dedicated IP allocations.
  - `GET /api/v1/dedicated-ip/available-regions`: Lists edge servers eligible for dedicated IP reservation.
  - `POST /api/v1/dedicated-ip/reserve`: Reserves a dedicated static IP on a specific server/city.
  - `POST /api/v1/dedicated-ip/assign`: Binds dedicated IP SNAT routing to an active device session.
  - `DELETE /api/v1/dedicated-ip/:id`: Releases dedicated IP.

---

### 2.2 Edge Node Agent Dynamic NAT Engine (`infrastructure/node-agent/agent.js`)
- Added native HTTP orchestration webhooks (`X-Node-Token` authenticated):
  - **`POST /port-forward/enable`:** Executes `iptables -t nat -A PREROUTING` and `iptables -A FORWARD` for requested protocols.
  - **`POST /port-forward/disable`:** Flushes the corresponding PREROUTING and FORWARD rules using `iptables -D`.
  - **`POST /dedicated-ip/bind`:** Executes `iptables -t nat -A POSTROUTING -s <clientIp> -j SNAT --to-source <dedicatedIp>`.
  - **`POST /dedicated-ip/unbind`:** Removes SNAT mapping.

---

### 2.3 Flutter Multi-Platform Client Features

#### A. Port Forwarding Interface (`PortForwardingScreen`)
- **File:** `mobile/lib/features/port_forwarding/screens/port_forwarding_screen.dart`
- **Capabilities:**
  - Live list of active port forward rules showing public endpoint (`<server_ip>:<external_port>`), target internal port, protocol badge (`TCP`, `UDP`, `BOTH`), and device label.
  - One-tap clipboard copy for the public endpoint.
  - Interactive "New Port Forward" modal with internal port input (e.g. 8080, 25565, 32400), optional custom port, and segmented protocol selector.
  - Real-time rule deletion and teardown.

#### B. Dedicated IP Interface (`DedicatedIpScreen`)
- **File:** `mobile/lib/features/dedicated_ip/screens/dedicated_ip_screen.dart`
- **Capabilities:**
  - Displays user's exclusive static IP cards with location badges, copy buttons, and expiration/renewal counters.
  - "Connect with this IP" action button to instantly establish a tunnel with the dedicated static IP.
  - "Reserve Dedicated IP" modal displaying available global server locations.

#### C. Settings Integration (`SettingsScreen`)
- Added **`ADVANCED NETWORKING & DEDICATED IP`** section to `SettingsScreen` providing one-tap access to Dedicated IP and Port Forwarding.

---

## 3. End-to-End Verification Results

### 3.1 Backend & Lifecycle Test
Executed complete lifecycle test in `scratch/test_phase13.ps1`:
```powershell
Auth Token Obtained: eyJhbGciOiJIUzI...
Dedicated IP Available Regions: 4
Reserved Dedicated IP: 198.51.100.141 in Frankfurt
User Dedicated IP Count Now: 1

VPN Connected. Internal Tunnel IP: 10.8.0.2
Port Forward Created! Public Endpoint: 198.51.100.10:40000 -> 10.8.0.2:8080
Active Port Forwards Count: 1
Released Port Forward: Port forward 40000 released
```

### 3.2 Flutter Code Health & Analysis
```bash
flutter analyze
Analyzing mobile...
No issues found! (ran in 3.6s)
```

---

## 4. Phase 13 Metrics & Quality Gate
| Component | Metric | Result |
| :--- | :--- | :--- |
| **Prisma Schema** | Models: `DedicatedIp`, `PortForwardRule` | **Synced & Generated** |
| **Backend API** | Endpoints: `/port-forwarding`, `/dedicated-ip` | **100% Operational (JWT Protected)** |
| **Edge Node Agent** | DNAT / SNAT dynamic iptables hooks | **Implemented & Tested** |
| **Flutter Client** | Screens: `PortForwardingScreen`, `DedicatedIpScreen` | **Analyzed: 0 Errors** |
| **Security Gating** | Free tier vs Pro/Family enforcement | **Strict 403 / 409 Validation** |
