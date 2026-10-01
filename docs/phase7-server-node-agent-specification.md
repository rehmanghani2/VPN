# Commercial VPN Platform - Phase 7: Edge Node Agent & Dynamic Synchronization

## 1. Overview

In a commercial VPN architecture (similar to NordVPN, ExpressVPN, or Proton VPN), when an end-user taps **"Connect"** on their mobile or desktop client, the WireGuard handshake cannot complete unless the target edge server (e.g., in Frankfurt, New York, or Singapore) has registered that client's public key and allocated virtual IP into its running kernel routing table.

Historically, legacy VPN setups wrote to a static `/etc/wireguard/wg0.conf` file and restarted the interface (`wg-quick down wg0 && wg-quick up wg0`), which is catastrophic in production: it terminates all active user connections and causes packet blackholes.

The **Antigravity Edge Node Agent** (`vpn-node-agent`) solves this problem by providing a zero-overhead, ultra-secure dynamic control plane daemon on each Linux server that synchronizes with the central NestJS control plane in real time.

---

## 2. Core Architecture

```
┌─────────────────────────────────┐
│     Central Control Plane       │
│      (NestJS + TypeScript)      │
│     http://127.0.0.1:3000       │
└───────────────┬─────────────────┘
                │
                │ HTTP/REST with X-Node-Token (or mTLS)
                │ Sub-millisecond peer dispatch
                ▼
┌────────────────────────────────────────────────────────┐
│             Remote Linux Edge Node (e.g. Frankfurt)    │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ vpn-node-agent (Node.js/Go daemon, port 51821)   │  │
│  └───────────┬───────────────────────────┬──────────┘  │
│              │ (Instant kernel call)     │ (Survives   │
│              │ < 1ms execution           │  reboots)   │
│              ▼                           ▼             │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │   Linux Kernel wg0    │   │ /etc/wireguard/      │  │
│  │ (WireGuard In-Kernel) │   │     wg0.conf         │  │
│  └───────────────────────┘   └──────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 3. Communication Protocol & Endpoints

The daemon listens on TCP port `51821` by default (`0.0.0.0:51821`), bound to root/systemd privileges (`CAP_NET_ADMIN`).

### 3.1. Authentication
Every request to the node agent (except `/health`) requires an authentication token passed in the header:
```http
X-Node-Token: <NODE_AGENT_TOKEN>
```
or
```http
Authorization: Bearer <NODE_AGENT_TOKEN>
```
Unauthorized requests receive immediate `HTTP 401 Unauthorized`.

---

### 3.2. Endpoints

#### `POST /peers/add`
Dynamically injects a newly connected client into the running Linux kernel WireGuard table without dropping active traffic.

**Request Body:**
```json
{
  "publicKey": "bXlQdWJsaWNLZXkxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ=",
  "allowedIps": ["10.8.0.2/32", "fd42:42:42::2/128"],
  "presharedKey": "optional-base64-preshared-key"
}
```

**Actions Performed by Agent:**
1. Validates standard Base64 WireGuard 32-byte public key format (`/^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw480]=$/`).
2. Runs atomic kernel command:
   ```bash
   wg set wg0 peer "<CLIENT_PUBLIC_KEY>" allowed-ips "10.8.0.2/32,fd42:42:42::2/128"
   ```
3. Appends the peer block to `/etc/wireguard/wg0.conf` for persistent reboot recovery.

**Response (`200 OK`):**
```json
{
  "success": true,
  "message": "Peer registered successfully in WireGuard kernel interface",
  "peer": {
    "publicKey": "bXlQdWJsaWNLZXkxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ=",
    "allowedIps": ["10.8.0.2/32", "fd42:42:42::2/128"]
  }
}
```

---

#### `POST /peers/remove`
Removes an expired or disconnected client session from the running WireGuard kernel.

**Request Body:**
```json
{
  "publicKey": "bXlQdWJsaWNLZXkxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ="
}
```

**Actions Performed by Agent:**
1. Runs:
   ```bash
   wg set wg0 peer "<CLIENT_PUBLIC_KEY>" remove
   ```
2. Strips the corresponding `[Peer]` block from `/etc/wireguard/wg0.conf`.

**Response (`200 OK`):**
```json
{
  "success": true,
  "message": "Peer removed from WireGuard kernel interface"
}
```

---

#### `GET /metrics`
Reports live telemetry, server load, total active tunnel peers, and aggregated transfer statistics.

**Response (`200 OK`):**
```json
{
  "node": "vpn-node-frankfurt-01",
  "status": "ONLINE",
  "activePeers": 142,
  "bandwidth": {
    "totalRxBytes": 104857600,
    "totalTxBytes": 524288000
  },
  "system": {
    "cpuCount": 4,
    "loadAverage": [0.42, 0.38, 0.35],
    "memoryUsagePercent": 34,
    "totalMemoryMB": 8192,
    "freeMemoryMB": 5406
  },
  "timestamp": "2026-10-01T11:20:00.000Z"
}
```

---

#### `GET /health`
Liveness probe for backend health monitoring and smart server load balancing.

**Response (`200 OK`):**
```json
{
  "status": "UP",
  "node": "vpn-node-frankfurt-01",
  "uptime": 128456.2,
  "timestamp": "2026-10-01T11:20:00.000Z"
}
```

---

## 4. Central Backend Integration (NestJS)

Inside `backend/src/vpn/vpn.service.ts`:
1. When a user requests a connection profile via `POST /api/v1/vpn/connect`:
   - An unused virtual IPv4 (`10.8.0.X/32`) and IPv6 (`fd42:42:42::X/128`) are allocated.
   - The user's device public key is assigned.
   - The backend calls `syncPeerToNode(server, clientPubKey, [clientIpv4, clientIpv6], 'add')`.
   - The edge agent dynamically registers the peer into the kernel within < 2ms.
   - The complete configuration is delivered back to the client.

2. When a user disconnects via `POST /api/v1/vpn/disconnect`:
   - The active session is terminated in the database.
   - The backend calls `syncPeerToNode(server, clientPubKey, [], 'remove')`.
   - The edge agent ejects the peer from the kernel routing table immediately.

---

## 5. Deployment & Systemd Service

The agent runs as a systemd service under `/etc/systemd/system/vpn-node-agent.service`:

```ini
[Unit]
Description=Antigravity VPN Edge Node Agent & Dynamic WireGuard Synchronizer
After=network.target wg-quick@wg0.service
Wants=wg-quick@wg0.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn-node-agent
ExecStart=/usr/bin/node /opt/vpn-node-agent/agent.js
Restart=always
RestartSec=5

# Configuration
Environment=AGENT_PORT=51821
Environment=WG_INTERFACE=wg0
Environment=WG_CONF_PATH=/etc/wireguard/wg0.conf
Environment=NODE_AGENT_TOKEN=vpn-node-agent-secure-token-2026

# Security hardening
LimitNOFILE=65536
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

To install and enable on a new Linux server:
```bash
sudo mkdir -p /opt/vpn-node-agent
sudo cp agent.js /opt/vpn-node-agent/
sudo cp vpn-node-agent.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now vpn-node-agent
```
