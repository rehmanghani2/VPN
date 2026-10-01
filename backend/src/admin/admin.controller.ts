import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { AdminService } from './admin.service';
import { OverrideUserPlanDto, UpdateServerDto } from './dto/admin.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from './guards/admin.guard';

@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /**
   * Cluster KPI Overview & Business Telemetry
   */
  @Get('overview')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async getOverview() {
    return this.adminService.getOverview();
  }

  /**
   * Cluster Edge Servers Detailed Status
   */
  @Get('servers')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async listServers() {
    return this.adminService.listServers();
  }

  /**
   * Put Server into Maintenance / Draining Mode
   */
  @Post('servers/:id/drain')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @HttpCode(HttpStatus.OK)
  async drainServer(@Param('id') serverId: string) {
    return this.adminService.drainServer(serverId);
  }

  /**
   * Restore Server to Active Online Rotation
   */
  @Post('servers/:id/restore')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @HttpCode(HttpStatus.OK)
  async restoreServer(@Param('id') serverId: string) {
    return this.adminService.restoreServer(serverId);
  }

  /**
   * Update Server Parameters
   */
  @Patch('servers/:id')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async updateServer(
    @Param('id') serverId: string,
    @Body() dto: UpdateServerDto,
  ) {
    return this.adminService.updateServer(serverId, dto);
  }

  /**
   * Deregister Edge Server
   */
  @Delete('servers/:id')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async deleteServer(@Param('id') serverId: string) {
    return this.adminService.deleteServer(serverId);
  }

  /**
   * Users Directory & Quota Inspection
   */
  @Get('users')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async listUsers(@Query('search') search?: string) {
    return this.adminService.listUsers(search);
  }

  /**
   * Override User Subscription Tier
   */
  @Post('users/:id/override-plan')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @HttpCode(HttpStatus.OK)
  async overrideUserPlan(
    @Param('id') userId: string,
    @Body() dto: OverrideUserPlanDto,
  ) {
    return this.adminService.overrideUserPlan(userId, dto);
  }

  /**
   * Emergency Killswitch: Force-disconnect all active sessions
   */
  @Post('users/:id/kill-sessions')
  @UseGuards(JwtAuthGuard, AdminGuard)
  @HttpCode(HttpStatus.OK)
  async killSessions(@Param('id') userId: string) {
    return this.adminService.terminateUserSessions(userId);
  }

  /**
   * Live Cluster Audit Log Stream
   */
  @Get('audit-feed')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async getAuditFeed() {
    return this.adminService.getAuditFeed();
  }

  /**
   * Interactive Operator Web Console HTML
   */
  @Get('dashboard')
  getDashboard(@Res() res: Response) {
    res.type('html').send(this.getDashboardHtml());
  }

  private getDashboardHtml(): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Commercial VPN - Operator Admin Control Plane</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0B0E14;
      --surface: #151922;
      --surface-light: #202634;
      --primary: #00E5FF;
      --green: #00E676;
      --red: #FF1744;
      --yellow: #FFD600;
      --text: #F0F4F8;
      --text-muted: #8A99AD;
      --border: #263042;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: 'Inter', -apple-system, sans-serif;
      padding: 24px;
      line-height: 1.5;
    }
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;
      padding-bottom: 20px;
      border-bottom: 1px solid var(--border);
    }
    .logo-area { display: flex; align-items: center; gap: 12px; }
    .logo-icon {
      width: 40px; height: 40px; border-radius: 10px;
      background: linear-gradient(135deg, var(--primary), #0070F3);
      display: flex; align-items: center; justify-content: center;
      font-weight: 800; color: #000; font-size: 20px;
    }
    h1 { font-size: 22px; font-weight: 700; letter-spacing: -0.5px; }
    .subtitle { font-size: 13px; color: var(--text-muted); }
    .auth-banner {
      background: var(--surface); padding: 12px 20px; border-radius: 12px;
      border: 1px solid var(--border); display: flex; gap: 12px; align-items: center;
    }
    input, button, select {
      background: var(--surface-light); border: 1px solid var(--border);
      color: #fff; padding: 8px 14px; border-radius: 8px; font-size: 13px;
      outline: none; font-family: inherit;
    }
    input:focus { border-color: var(--primary); }
    button {
      background: var(--primary); color: #000; font-weight: 600;
      cursor: pointer; transition: 0.15s ease; border: none;
    }
    button:hover { opacity: 0.9; transform: translateY(-1px); }
    button.btn-danger { background: var(--red); color: #fff; }
    button.btn-warning { background: var(--yellow); color: #000; }
    button.btn-success { background: var(--green); color: #000; }
    button.btn-outline { background: transparent; border: 1px solid var(--border); color: #fff; }
    button.btn-outline:hover { background: var(--surface-light); }

    /* KPI Grid */
    .kpi-grid {
      display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 16px; margin-bottom: 24px;
    }
    .kpi-card {
      background: var(--surface); border: 1px solid var(--border);
      padding: 18px; border-radius: 14px; position: relative; overflow: hidden;
    }
    .kpi-card::after {
      content: ''; position: absolute; top: 0; left: 0; width: 100%; height: 3px;
      background: linear-gradient(90deg, var(--primary), transparent);
    }
    .kpi-label { font-size: 11px; font-weight: 600; color: var(--text-muted); letter-spacing: 1px; text-transform: uppercase; }
    .kpi-value { font-size: 28px; font-weight: 800; font-family: 'JetBrains Mono', monospace; margin-top: 6px; }

    /* Layout Sections */
    .section-grid {
      display: grid; grid-template-columns: 2fr 1.2fr; gap: 24px;
    }
    @media (max-width: 1024px) { .section-grid { grid-template-columns: 1fr; } }

    .panel {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 14px; padding: 20px; margin-bottom: 24px;
    }
    .panel-header {
      display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;
    }
    .panel-title { font-size: 16px; font-weight: 700; }

    /* Table styling */
    table { width: 100%; border-collapse: collapse; font-size: 13px; text-align: left; }
    th {
      padding: 10px 12px; color: var(--text-muted); font-weight: 600; font-size: 11px;
      text-transform: uppercase; letter-spacing: 0.8px; border-bottom: 1px solid var(--border);
    }
    td { padding: 12px; border-bottom: 1px solid var(--border); }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: rgba(255,255,255,0.02); }

    .badge {
      display: inline-block; padding: 3px 8px; border-radius: 6px;
      font-size: 11px; font-weight: 700; font-family: 'JetBrains Mono', monospace;
    }
    .badge-online { background: rgba(0, 230, 118, 0.15); color: var(--green); border: 1px solid rgba(0, 230, 118, 0.3); }
    .badge-draining { background: rgba(255, 214, 0, 0.15); color: var(--yellow); border: 1px solid rgba(255, 214, 0, 0.3); }
    .badge-offline { background: rgba(255, 23, 68, 0.15); color: var(--red); border: 1px solid rgba(255, 23, 68, 0.3); }
    .badge-stealth { background: rgba(0, 229, 255, 0.15); color: var(--primary); border: 1px solid rgba(0, 229, 255, 0.3); }

    .progress-bar {
      height: 6px; background: var(--bg); border-radius: 4px; overflow: hidden; margin-top: 4px;
    }
    .progress-fill { height: 100%; background: var(--primary); }

    .feed-item {
      padding: 10px 12px; border-bottom: 1px solid var(--border);
      display: flex; justify-content: space-between; font-size: 12px;
    }
    .feed-item:last-child { border-bottom: none; }
    .mono { font-family: 'JetBrains Mono', monospace; }
  </style>
</head>
<body>
  <header>
    <div class="logo-area">
      <div class="logo-icon">V</div>
      <div>
        <h1>Commercial VPN Control Plane</h1>
        <div class="subtitle">Global Edge Node Orchestration & User Management</div>
      </div>
    </div>
    <div class="auth-banner">
      <input type="password" id="adminToken" placeholder="Paste Admin JWT Token" style="width: 260px;" />
      <button onclick="saveAndReload()">Authenticate</button>
      <button class="btn-outline" onclick="loginDefaultAdmin()">Auto-Login Admin</button>
    </div>
  </header>

  <!-- KPI Overview Grid -->
  <div class="kpi-grid">
    <div class="kpi-card">
      <div class="kpi-label">Active WireGuard Peers</div>
      <div class="kpi-value" id="kpiActivePeers" style="color: var(--primary)">--</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-label">Global Edge Nodes</div>
      <div class="kpi-value" id="kpiNodes" style="color: var(--green)">--</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-label">Total Users</div>
      <div class="kpi-value" id="kpiUsers">--</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-label">Cluster Load %</div>
      <div class="kpi-value" id="kpiLoad">--%</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-label">Throughput (Est)</div>
      <div class="kpi-value" id="kpiBandwidth">-- Gbps</div>
    </div>
  </div>

  <div class="section-grid">
    <!-- Left Column: Edge Servers & Users -->
    <div>
      <!-- Server Nodes Panel -->
      <div class="panel">
        <div class="panel-header">
          <div class="panel-title">Cluster Edge Nodes</div>
          <button class="btn-outline" onclick="fetchServers()">Refresh Nodes</button>
        </div>
        <table>
          <thead>
            <tr>
              <th>Node Name</th>
              <th>Location</th>
              <th>Public Endpoint</th>
              <th>Status</th>
              <th>Load / Capacity</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody id="serversTbody">
            <tr><td colspan="6" style="text-align: center; color: var(--text-muted);">Loading servers...</td></tr>
          </tbody>
        </table>
      </div>

      <!-- Users Management Panel -->
      <div class="panel">
        <div class="panel-header">
          <div class="panel-title">Registered Users & Sessions</div>
          <div>
            <input type="text" id="userSearchInput" placeholder="Search by email..." onkeyup="if(event.key === 'Enter') searchUsers()" />
            <button onclick="searchUsers()">Search</button>
          </div>
        </div>
        <table>
          <thead>
            <tr>
              <th>Email</th>
              <th>Plan</th>
              <th>Devices</th>
              <th>Active Tunnels</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody id="usersTbody">
            <tr><td colspan="5" style="text-align: center; color: var(--text-muted);">Loading users...</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Right Column: Audit Logs & Real-time Feeds -->
    <div>
      <div class="panel">
        <div class="panel-header">
          <div class="panel-title">Live Peer Audit Stream</div>
          <span class="badge badge-online">AUTO-POLL 5s</span>
        </div>
        <div id="auditFeed" style="max-height: 480px; overflow-y: auto;">
          <div style="padding: 12px; color: var(--text-muted); text-align: center;">Streaming connection events...</div>
        </div>
      </div>
    </div>
  </div>

  <script>
    const API_BASE = '/api/v1';
    let token = localStorage.getItem('vpn_admin_token') || '';

    if (token) {
      document.getElementById('adminToken').value = token;
    }

    async function loginDefaultAdmin() {
      try {
        const res = await fetch(API_BASE + '/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: 'admin@vpnplatform.internal', password: 'AdminSecurePass2026!' })
        });
        const data = await res.json();
        if (data.accessToken) {
          token = data.accessToken;
          localStorage.setItem('vpn_admin_token', token);
          document.getElementById('adminToken').value = token;
          loadDashboard();
        } else {
          alert('Admin login failed: ' + (data.message || 'Check credentials'));
        }
      } catch (err) {
        alert('Connection error: ' + err.message);
      }
    }

    function saveAndReload() {
      token = document.getElementById('adminToken').value.trim();
      localStorage.setItem('vpn_admin_token', token);
      loadDashboard();
    }

    function getHeaders() {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + token
      };
    }

    async function loadDashboard() {
      if (!token) return;
      await Promise.all([fetchOverview(), fetchServers(), searchUsers(), fetchAudit()]);
    }

    async function fetchOverview() {
      try {
        const res = await fetch(API_BASE + '/admin/overview', { headers: getHeaders() });
        if (res.status === 401 || res.status === 403) {
          alert('Unauthorized. Please enter a valid Admin JWT token.');
          return;
        }
        const data = await res.json();
        document.getElementById('kpiActivePeers').innerText = data.kpi.activePeers;
        document.getElementById('kpiNodes').innerText = data.servers.online + ' / ' + data.servers.total;
        document.getElementById('kpiUsers').innerText = data.kpi.totalUsers;
        document.getElementById('kpiLoad').innerText = data.kpi.clusterLoadPercent + '%';
        document.getElementById('kpiBandwidth').innerText = data.kpi.estimatedBandwidthGbps + ' Gbps';
      } catch (_) {}
    }

    async function fetchServers() {
      try {
        const res = await fetch(API_BASE + '/admin/servers', { headers: getHeaders() });
        const servers = await res.json();
        const tbody = document.getElementById('serversTbody');
        tbody.innerHTML = '';

        servers.forEach(s => {
          const statusBadge = s.status === 'ONLINE' ? 'badge-online' : s.status === 'DRAINING' ? 'badge-draining' : 'badge-offline';
          const stealth = s.isObfuscated ? '<span class="badge badge-stealth">STEALTH 443</span>' : '';
          const tr = document.createElement('tr');
          tr.innerHTML = \`
            <td><strong>\${s.name}</strong> \${stealth}</td>
            <td>\${s.city}, \${s.countryCode}</td>
            <td class="mono">\${s.publicIp}:\${s.wgPort}</td>
            <td><span class="badge \${statusBadge}">\${s.status}</span></td>
            <td>
              <div>\${s.currentLoad} / \${s.capacity} (\${s.loadPercent}%)</div>
              <div class="progress-bar"><div class="progress-fill" style="width: \${Math.min(s.loadPercent, 100)}%;"></div></div>
            </td>
            <td>
              \${s.status === 'ONLINE'
                ? \`<button class="btn-warning" onclick="drainServer('\${s.id}')">Drain</button>\`
                : \`<button class="btn-success" onclick="restoreServer('\${s.id}')">Online</button>\`
              }
            </td>
          \`;
          tbody.appendChild(tr);
        });
      } catch (_) {}
    }

    async function drainServer(id) {
      await fetch(API_BASE + '/admin/servers/' + id + '/drain', { method: 'POST', headers: getHeaders() });
      fetchServers();
      fetchOverview();
    }

    async function restoreServer(id) {
      await fetch(API_BASE + '/admin/servers/' + id + '/restore', { method: 'POST', headers: getHeaders() });
      fetchServers();
      fetchOverview();
    }

    async function searchUsers() {
      const q = document.getElementById('userSearchInput').value.trim();
      try {
        const res = await fetch(API_BASE + '/admin/users' + (q ? '?search=' + encodeURIComponent(q) : ''), { headers: getHeaders() });
        const users = await res.json();
        const tbody = document.getElementById('usersTbody');
        tbody.innerHTML = '';

        users.forEach(u => {
          const tr = document.createElement('tr');
          tr.innerHTML = \`
            <td>
              <div><strong>\${u.email}</strong></div>
              <div style="font-size: 11px; color: var(--text-muted);">Role: \${u.role}</div>
            </td>
            <td><span class="badge badge-stealth">\${u.subscription.planType}</span> (\${u.subscription.maxDevices} Dev)</td>
            <td>\${u.devicesCount} devices</td>
            <td><span class="badge \${u.activeSessionsCount > 0 ? 'badge-online' : 'badge-offline'}">\${u.activeSessionsCount} active</span></td>
            <td>
              <button class="btn-outline" onclick="overridePlan('\${u.id}')">Upgrade</button>
              \${u.activeSessionsCount > 0 ? \`<button class="btn-danger" onclick="killSessions('\${u.id}')">Kill VPN</button>\` : ''}
            </td>
          \`;
          tbody.appendChild(tr);
        });
      } catch (_) {}
    }

    async function overridePlan(userId) {
      const plan = prompt('Enter Plan Type (FREE, PRO, FAMILY):', 'PRO');
      if (!plan) return;
      await fetch(API_BASE + '/admin/users/' + userId + '/override-plan', {
        method: 'POST',
        headers: getHeaders(),
        body: JSON.stringify({ planType: plan.toUpperCase() })
      });
      searchUsers();
      fetchOverview();
    }

    async function killSessions(userId) {
      if (!confirm('Force disconnect all VPN connections for this user?')) return;
      await fetch(API_BASE + '/admin/users/' + userId + '/kill-sessions', {
        method: 'POST',
        headers: getHeaders()
      });
      searchUsers();
      fetchOverview();
      fetchAudit();
    }

    async function fetchAudit() {
      try {
        const res = await fetch(API_BASE + '/admin/audit-feed', { headers: getHeaders() });
        const events = await res.json();
        const feed = document.getElementById('auditFeed');
        feed.innerHTML = '';

        events.forEach(e => {
          const div = document.createElement('div');
          div.className = 'feed-item';
          const isConn = e.event === 'PEER_CONNECTED';
          div.innerHTML = \`
            <div>
              <span class="badge \${isConn ? 'badge-online' : 'badge-offline'}">\${e.event}</span>
              <span style="margin-left: 6px;">\${e.device}</span>
              <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">\${e.server} &bull; \${e.allocatedIp}</div>
            </div>
            <div style="color: var(--text-muted); font-size: 10px;">\${new Date(e.timestamp).toLocaleTimeString()}</div>
          \`;
          feed.appendChild(div);
        });
      } catch (_) {}
    }

    // Auto-poll audit feed every 5 seconds
    setInterval(() => {
      if (token) fetchAudit();
    }, 5000);

    // Initial load
    if (token) {
      loadDashboard();
    } else {
      loginDefaultAdmin();
    }
  </script>
</body>
</html>`;
  }
}
