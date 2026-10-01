# Phase 9: Operator Admin Console & Global Telemetry Control Plane

## 1. Overview & Architecture

Phase 9 establishes the centralized operator control plane and web administration console for monitoring distributed WireGuard edge nodes, executing rolling server drains, managing user subscription tiers, and enforcing emergency session killswitches:

```
+-----------------------------------------------------------------------------------------------+
|                                    Operator Web Browser                                       |
|                                                                                               |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
|  |     Live KPI Cards        |   |   Cluster Nodes Topology    |   |     User Directory    |  |
|  | - Active WireGuard Peers  |   | - Live Capacity & Load Bar  |   | - Subscription Tier   |  |
|  | - Global Edge Nodes       |   | - One-Click Drain / Online  |   | - Session Killswitch  |  |
|  | - Aggregate Gbps Bandwidth|   | - Port 443 Stealth Badges   |   | - Plan Override Modal |  |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
+------------------------------^---------------------------------^------------------------------+
                               |                                 |
                        HTTPS (Admin JWT)                 REST Endpoints
                               |                                 |
+------------------------------v---------------------------------v------------------------------+
|                                NestJS Control Plane API (`/admin`)                            |
|                                                                                               |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
|  |       AdminGuard          |   |        AdminService         |   |    Audit Log Stream   |  |
|  | - Checks role === 'ADMIN' |   | - Dynamic Node Drain/Online |   | - Real-time Peer Ingest| |
|  | - Protects /admin/*       |   | - Subscription Overrides    |   | - Auto-polling (5s)   |  |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
+-----------------------------------------------------------------------------------------------+
```

---

## 2. Admin Management Endpoints

All admin endpoints reside under `/api/v1/admin` and require authentication (`JwtAuthGuard`) and administrative authorization (`AdminGuard`).

### 2.1 Cluster Overview & Business KPIs
- **Endpoint**: `GET /api/v1/admin/overview`
- **Output**:
  ```json
  {
    "kpi": {
      "totalUsers": 1250,
      "totalDevices": 2400,
      "activePeers": 312,
      "totalCapacity": 10000,
      "clusterLoadPercent": 3.1,
      "estimatedBandwidthGbps": 5.77
    },
    "servers": {
      "total": 12,
      "online": 11,
      "draining": 1,
      "offline": 0
    },
    "subscriptions": {
      "total": 1250,
      "breakdown": {
        "FREE": 850,
        "PRO": 320,
        "FAMILY": 80
      }
    }
  }
  ```

### 2.2 Operational Node Management
- **`GET /api/v1/admin/servers`**: Returns list of all cluster servers with current load, maximum capacity, load percentage, stealth status, and public endpoints.
- **`POST /api/v1/admin/servers/:id/drain`**: Marks a server as `DRAINING`. Smart Connect immediately diverts new connection attempts away from this server while existing active tunnels finish gracefully.
- **`POST /api/v1/admin/servers/:id/restore`**: Restores a draining or offline server back to `ONLINE` status.
- **`PATCH /api/v1/admin/servers/:id`**: Dynamically adjusts node capacity, name, or maintenance flags.
- **`DELETE /api/v1/admin/servers/:id`**: Deregisters an edge node from the central database.

### 2.3 User Directory & Emergency Controls
- **`GET /api/v1/admin/users?search=...`**: Searchable user catalog with subscription plan, registered devices count, and active VPN sessions.
- **`POST /api/v1/admin/users/:id/override-plan`**:
  ```json
  { "planType": "PRO", "maxDevices": 5 }
  ```
  Immediately overrides a user's subscription tier without requiring payment processing.
- **`POST /api/v1/admin/users/:id/kill-sessions`**:
  - Finds all active WireGuard peers for the user across all edge nodes worldwide.
  - Calls edge node agents (`POST /peers/remove`) to revoke their cryptographic peers in real-time.
  - Decrements node load and marks peers `INACTIVE`.

### 2.4 Real-time Audit Stream
- **`GET /api/v1/admin/audit-feed`**: Ingests recent cluster lifecycle events (`PEER_CONNECTED`, `PEER_DISCONNECTED`) with timestamps, server locations, and client hardware types.

---

## 3. Interactive Web Console

Accessible at `http://localhost:3000/api/v1/admin/dashboard`:
- Dark neon cyber UI matching the mobile aesthetic.
- One-click Admin Auto-Login or manual JWT token authentication.
- Live progress bars for edge node capacity.
- Interactive user plan switcher and emergency killswitch.
- Real-time audit log auto-polling every 5 seconds.
