# Phase 10: Next.js Web Admin Dashboard & Automated Multi-Platform Release CI/CD

## 1. Overview & Architecture

Phase 10 provides an enterprise SaaS operator experience and automated release infrastructure:
1. **Modern Standalone Next.js Web Admin Dashboard (`admin-dashboard/`)**:
   - Built on Next.js 14 (App Router), TypeScript, and Tailwind CSS.
   - Real-time KPI Metric cards, Cluster Nodes health bars, One-click node draining, and user session killswitch.
2. **Automated Multi-Platform Packaging & Release CI/CD (`.github/workflows/`)**:
   - Automated workflows for Android (APK + AAB), Windows Desktop (InnoSetup installer with Wintun), Backend Control Plane Docker builds, and multi-arch Edge Node Agent containers.

```
+-----------------------------------------------------------------------------------------------+
|                                    CI/CD Release Automation                                   |
|                                                                                               |
|  +----------------------+  +-----------------------+  +-------------------+  +--------------+ |
|  |  mobile-android.yml  |  |  desktop-windows.yml  |  | backend-docker.yml|  |edge-node.yml | |
|  | - armeabi-v7a split  |  | - Wintun Driver embed |  | - NestJS image    |  | - amd64/arm64| |
|  | - arm64-v8a split    |  | - InnoSetup Setup.exe |  | - Prisma generate |  | - Obfuscator | |
|  | - Google Play AAB    |  | - Code signing        |  | - Health checks   |  | - Node daemon| |
|  +----------------------+  +-----------------------+  +-------------------+  +--------------+ |
+-----------------------------------------------------------------------------------------------+

+-----------------------------------------------------------------------------------------------+
|                              Operator Next.js Web Admin Dashboard                             |
|                                                                                               |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
|  |   / (Cluster Overview)    |   |     /servers (Gateways)     |   |   /users (Directory)  |  |
|  | - Active WireGuard Tunnels|   | - Frankfurt, Tokyo, NY, etc.|   | - Search & Filter     |  |
|  | - Global Bandwidth Gbps   |   | - Load vs Capacity          |   | - Plan Overrides      |  |
|  | - Live Event Audit Stream |   | - Rolling Node Drain Action |   | - Session Killswitch  |  |
|  +---------------------------+   +-----------------------------+   +-----------------------+  |
+-----------------------------------------------------------------------------------------------+
```

---

## 2. Next.js Web Admin Dashboard (`admin-dashboard/`)

### 2.1 Technology Stack & Structure
- **Framework**: Next.js 14+ (App Router), React 18, TypeScript.
- **Styling**: Tailwind CSS with custom cyber-dark palette (`#0B0E14` background, `#151922` surface, `#00E5FF` primary, `#00E676` green).
- **Icons**: `lucide-react`.
- **API Client**: Strongly-typed [`admin-dashboard/src/lib/api.ts`](file:///e:/Projects/VPN/admin-dashboard/src/lib/api.ts) with automatic JWT token management.

### 2.2 Dashboard Pages
1. **[`/` (Cluster Overview)](file:///e:/Projects/VPN/admin-dashboard/src/app/page.tsx)**:
   - Top KPI cards: Active Tunnels, Edge Nodes Online, Total Users, Cluster Saturation %, Estimated Global Bandwidth.
   - Edge Nodes table with dynamic progress bars and instant **Drain / Online** actions.
   - Live Handshake Audit Log feed with 5-second automatic polling.
2. **[`/servers` (Cluster Nodes)](file:///e:/Projects/VPN/admin-dashboard/src/app/servers/page.tsx)**:
   - Detailed server cards showing public endpoint, WireGuard port, AmneziaWG obfuscation status, and load saturation.
3. **[`/users` (User Management)](file:///e:/Projects/VPN/admin-dashboard/src/app/users/page.tsx)**:
   - Searchable customer directory.
   - One-click plan upgrade/override (e.g., Free to Pro / Family).
   - One-click Emergency Killswitch to revoke all active VPN sessions for that user across all global nodes.
4. **[`/analytics` (Global Telemetry)](file:///e:/Projects/VPN/admin-dashboard/src/app/analytics/page.tsx)**:
   - Subscription tier distribution charts.
   - Regional traffic and tunnel distribution breakdown.

---

## 3. Automated Multi-Platform Release CI/CD

### 3.1 Android Release Packaging ([`mobile-android.yml`](file:///e:/Projects/VPN/.github/workflows/mobile-android.yml))
- Targets Java 17 and Flutter stable.
- Runs `flutter analyze` lint checks.
- Generates split release APKs for `armeabi-v7a` and `arm64-v8a` to minimize download size.
- Generates production Android App Bundle (`.aab`) ready for Google Play Console upload.

### 3.2 Windows Desktop Packaging ([`desktop-windows.yml`](file:///e:/Projects/VPN/.github/workflows/desktop-windows.yml))
- Builds optimized Flutter Windows desktop binary (`Release/mobile.exe`).
- Downloads official signed `wintun.dll` driver from `wintun.net` and embeds it directly into the release folder.
- Compiles the InnoSetup installer configuration ([`vpn_setup.iss`](file:///e:/Projects/VPN/mobile/windows/installer/vpn_setup.iss)), generating a single setup executable (`AntigravityVPN-Setup-x64.exe`).

### 3.3 Backend Control Plane ([`backend-docker.yml`](file:///e:/Projects/VPN/.github/workflows/backend-docker.yml))
- Builds multi-stage production Docker image.
- Verifies Prisma database migrations and NestJS TypeScript compilation.

### 3.4 Edge Node Agent ([`edge-node-agent.yml`](file:///e:/Projects/VPN/.github/workflows/edge-node-agent.yml))
- Compiles multi-architecture Docker container (`linux/amd64`, `linux/arm64`) with QEMU.
- Packages node synchronizer daemon and HTTPS Port 443 obfuscation proxy.
