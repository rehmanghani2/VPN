# Phase 6: Multi-Region Cluster Orchestration & Dynamic Health Telemetry

## 1. Overview & Architecture

To achieve commercial-tier availability and global reach matching NordVPN and Proton VPN, the Commercial VPN Platform utilizes an autonomous multi-region cluster management architecture:

```
+-----------------------------------------------------------------------------------+
|                        NestJS Central Control Plane                                |
|                                                                                   |
|  +--------------------+   +-----------------------+   +------------------------+  |
|  |   NodeController   |   |   NodeMonitorService  |   |   Prisma / PostgreSQL  |  |
|  |  /nodes/register   |   |  - 30s Health Prober  |   |  - Cluster State       |  |
|  |  /nodes/heartbeat  |   |  - Telemetry Ingest   |   |  - Regional Load       |  |
|  |  /nodes/:id/drain  |   |  - Auto-Failover Logic|   |  - Server Rotation     |  |
|  +--------------------+   +-----------------------+   +------------------------+  |
+--------------------------^--------------------------------------------------------+
                           |
        mTLS / Shared Auth Token (`X-Node-Token`)
                           |
         +-----------------+-----------------+
         |                                   |
         v                                   v
+------------------------+       +------------------------+
| Frankfurt Edge Node    |       | Tokyo Stealth Node     |
| - WireGuard (51820)    |       | - WireGuard (51820)    |
| - Node Agent (51821)   |       | - Anti-DPI Proxy (443) |
| - Unbound DNS (53)     |       | - Node Agent (51821)   |
| - BBR Congestion       |       | - Unbound DNS (53)     |
+------------------------+       +------------------------+
```

---

## 2. API Endpoints

### 2.1 Edge Node Self-Registration
- **Endpoint**: `POST /api/v1/vpn/nodes/register`
- **Authentication**: `X-Node-Token` header
- **Payload (`RegisterNodeDto`)**:
  ```json
  {
    "name": "TOKYO-HYPER-EDGE",
    "countryCode": "JP",
    "countryName": "Japan",
    "city": "Tokyo",
    "hostname": "jp-tok-01.commercialvpn.internal",
    "publicIp": "203.0.113.88",
    "wgPort": 51820,
    "wgPublicKey": "<SERVER_PUBLIC_KEY>",
    "capacity": 1000,
    "subnetV4": "10.8.4.0/24",
    "dnsV4": "10.8.4.1",
    "isObfuscated": true,
    "obfuscationPort": 443,
    "obfuscationProtocol": "AMNEZIA_WG"
  }
  ```
- **Response**: Returns server record with initial status `ONLINE`.

### 2.2 Periodic Node Telemetry Heartbeat
- **Endpoint**: `POST /api/v1/vpn/nodes/heartbeat`
- **Authentication**: `X-Node-Token` header
- **Payload (`NodeHeartbeatDto`)**:
  ```json
  {
    "hostname": "jp-tok-01.commercialvpn.internal",
    "activePeers": 42,
    "memoryUsagePercent": 32,
    "totalRxBytes": 104857600,
    "totalTxBytes": 524288000
  }
  ```
- **Behavior**: Resets failure counters, updates server load (`currentLoad`), and automatically marks recovered nodes as `ONLINE`.

### 2.3 Rolling Drain & Recovery (Maintenance Mode)
- **Drain Endpoint**: `POST /api/v1/vpn/nodes/:id/drain` (Requires Admin JWT)
  - Updates node status to `DRAINING`.
  - Smart Connect avoids routing new client connections to this server while allowing existing peers to gracefully finish sessions.
- **Restore Endpoint**: `POST /api/v1/vpn/nodes/:id/restore` (Requires Admin JWT)
  - Resets node status back to `ONLINE` to rejoin active connection rotation.

---

## 3. Automated Cluster Failover Mechanism

The `NodeMonitorService` runs a continuous background event loop every 30 seconds:
1. Queries all non-maintenance nodes in the database.
2. Dispatches asynchronous HTTP `/health` probes with a strict 3-second timeout.
3. If an edge node fails 3 consecutive probes:
   - Server status is automatically transitioned to `OFFLINE`.
   - Central control plane logs `[FAILOVER TRIGGERED]` alert.
   - Flutter clients querying `GET /api/v1/vpn/servers` receive updated server availability immediately.
4. As soon as the node responds to subsequent probes or posts a heartbeat webhook, it is automatically resurrected to `ONLINE`.

---

## 4. Zero-Touch Provisioning (IaC & Cloud-Init)

- **Cloud-Init Template**: `infrastructure/scripts/node-bootstrap-cloudinit.yaml`
  - Automates kernel TCP BBR configuration.
  - Installs WireGuard, Unbound DNS, and Node.js.
  - Generates server cryptographic keypairs.
  - Launches `vpn-node-agent.service` systemd daemon.
  - Self-registers with central control plane on initial boot.
- **Terraform Multi-Region Blueprint**:
  - `infrastructure/terraform/main.tf`
  - `infrastructure/terraform/variables.tf`
  - `infrastructure/terraform/outputs.tf`
  - Provisions Hetzner / AWS cloud edge nodes across Frankfurt, New York, Singapore, and London with automated zero-leak firewalling and cloud-init integration.
