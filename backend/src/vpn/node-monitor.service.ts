import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterNodeDto, NodeHeartbeatDto } from './dto/node.dto';
import * as http from 'http';

@Injectable()
export class NodeMonitorService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NodeMonitorService.name);
  private checkIntervalTimer: NodeJS.Timeout | null = null;
  private readonly failureCounters = new Map<string, number>(); // serverId -> count

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    this.logger.log('Starting Automated Multi-Region Node Health Monitoring loop (30s interval)...');
    // Run initial health check shortly after startup
    setTimeout(() => this.runHealthChecks(), 5000);
    this.checkIntervalTimer = setInterval(() => this.runHealthChecks(), 30000);
  }

  onModuleDestroy() {
    if (this.checkIntervalTimer) {
      clearInterval(this.checkIntervalTimer);
      this.checkIntervalTimer = null;
    }
  }

  /**
   * Periodic Probe Loop across all registered Edge Nodes
   */
  async runHealthChecks() {
    try {
      const servers = await this.prisma.vpnServer.findMany();

      for (const server of servers) {
        // Skip nodes currently undergoing maintenance
        if (server.status === 'MAINTENANCE') continue;

        // Skip test dummy IPs (e.g. 198.51.100.x documentation IPs)
        if (server.publicIp.startsWith('198.51.100.')) continue;

        const isAlive = await this.probeNodeHealth(server.publicIp, 51821);
        const currentFailures = this.failureCounters.get(server.id) || 0;

        if (isAlive) {
          this.failureCounters.set(server.id, 0);

          // If was previously flagged OFFLINE, automatically resurrect to ONLINE
          if (server.status === 'OFFLINE') {
            await this.prisma.vpnServer.update({
              where: { id: server.id },
              data: { status: 'ONLINE' },
            });
            this.logger.log(`[FAILOVER RESURRECTED] Node ${server.name} (${server.publicIp}) recovered and marked ONLINE.`);
          }

          // Fetch live telemetry metrics from node agent
          const metrics = await this.fetchNodeMetrics(server.publicIp, 51821);
          if (metrics && typeof metrics.activePeers === 'number') {
            await this.prisma.vpnServer.update({
              where: { id: server.id },
              data: { currentLoad: metrics.activePeers },
            });
          }
        } else {
          const nextFailures = currentFailures + 1;
          this.failureCounters.set(server.id, nextFailures);
          this.logger.warn(`Node ${server.name} (${server.publicIp}) probe failed (${nextFailures}/3).`);

          if (nextFailures >= 3 && server.status === 'ONLINE') {
            await this.prisma.vpnServer.update({
              where: { id: server.id },
              data: { status: 'OFFLINE' },
            });
            this.logger.error(`[FAILOVER TRIGGERED] Node ${server.name} missed 3 consecutive heartbeats. Marked OFFLINE.`);
          }
        }
      }
    } catch (err) {
      this.logger.error('Error during node health check loop:', err);
    }
  }

  /**
   * Dynamic Edge Node Self-Registration (used by cloud-init & bootstrap scripts)
   */
  async registerNode(dto: RegisterNodeDto) {
    const existing = await this.prisma.vpnServer.findFirst({
      where: {
        OR: [{ hostname: dto.hostname }, { publicIp: dto.publicIp }],
      },
    });

    if (existing) {
      const updated = await this.prisma.vpnServer.update({
        where: { id: existing.id },
        data: {
          name: dto.name,
          countryCode: dto.countryCode,
          countryName: dto.countryName,
          city: dto.city,
          wgPort: dto.wgPort ?? existing.wgPort,
          wgPublicKey: dto.wgPublicKey,
          capacity: dto.capacity ?? existing.capacity,
          subnetV4: dto.subnetV4 ?? existing.subnetV4,
          subnetV6: dto.subnetV6 ?? existing.subnetV6,
          dnsV4: dto.dnsV4 ?? existing.dnsV4,
          isObfuscated: dto.isObfuscated ?? existing.isObfuscated,
          obfuscationPort: dto.obfuscationPort ?? existing.obfuscationPort,
          obfuscationProtocol: dto.obfuscationProtocol ?? existing.obfuscationProtocol,
          status: 'ONLINE', // Fresh bootstrap comes up ONLINE
        },
      });
      this.logger.log(`[PROVISIONING] Node re-registered and online: ${updated.name} (${updated.publicIp})`);
      return { success: true, server: updated };
    }

    const created = await this.prisma.vpnServer.create({
      data: {
        name: dto.name,
        countryCode: dto.countryCode,
        countryName: dto.countryName,
        city: dto.city,
        hostname: dto.hostname,
        publicIp: dto.publicIp,
        wgPort: dto.wgPort ?? 51820,
        wgPublicKey: dto.wgPublicKey,
        capacity: dto.capacity ?? 500,
        subnetV4: dto.subnetV4 ?? '10.8.0.0/24',
        subnetV6: dto.subnetV6 ?? 'fd42:42:42::/64',
        dnsV4: dto.dnsV4 ?? '10.8.0.1',
        isObfuscated: dto.isObfuscated ?? false,
        obfuscationPort: dto.obfuscationPort ?? 443,
        obfuscationProtocol: dto.obfuscationProtocol ?? 'NONE',
        status: 'ONLINE',
      },
    });

    this.logger.log(`[PROVISIONING] New edge node successfully provisioned: ${created.name} (${created.publicIp})`);
    return { success: true, server: created };
  }

  /**
   * Heartbeat webhook dispatched directly by Edge Node Agent
   */
  async recordHeartbeat(dto: NodeHeartbeatDto) {
    const server = await this.prisma.vpnServer.findFirst({
      where: { hostname: dto.hostname },
    });

    if (!server) {
      return { success: false, message: 'Node not recognized' };
    }

    this.failureCounters.set(server.id, 0);

    const updateData: any = {};
    if (typeof dto.activePeers === 'number') {
      updateData.currentLoad = dto.activePeers;
    }
    if (server.status === 'OFFLINE') {
      updateData.status = 'ONLINE';
    }

    if (Object.keys(updateData).length > 0) {
      await this.prisma.vpnServer.update({
        where: { id: server.id },
        data: updateData,
      });
    }

    return { success: true, timestamp: new Date().toISOString() };
  }

  /**
   * Graceful Draining: Marks a node as DRAINING so Smart Connect avoids it
   */
  async drainServer(serverId: string) {
    const server = await this.prisma.vpnServer.update({
      where: { id: serverId },
      data: { status: 'DRAINING' },
    });
    this.logger.warn(`[DRAINING] Server ${server.name} set to DRAINING. New client connections blocked.`);
    return { success: true, message: `Server ${server.name} is now draining`, server };
  }

  /**
   * Restores a DRAINING or OFFLINE server to ONLINE rotation
   */
  async restoreServer(serverId: string) {
    const server = await this.prisma.vpnServer.update({
      where: { id: serverId },
      data: { status: 'ONLINE' },
    });
    this.logger.log(`[ONLINE] Server ${server.name} restored to active cluster.`);
    return { success: true, message: `Server ${server.name} restored to ONLINE`, server };
  }

  /**
   * Low-level HTTP health check probe with 3-second timeout
   */
  private probeNodeHealth(ip: string, port: number): Promise<boolean> {
    return new Promise((resolve) => {
      const req = http.get(
        {
          host: ip,
          port,
          path: '/health',
          timeout: 3000,
        },
        (res) => {
          resolve(res.statusCode === 200);
        },
      );

      req.on('error', () => resolve(false));
      req.on('timeout', () => {
        req.destroy();
        resolve(false);
      });
    });
  }

  /**
   * Low-level HTTP telemetry fetcher
   */
  private fetchNodeMetrics(ip: string, port: number): Promise<any> {
    return new Promise((resolve) => {
      const req = http.get(
        {
          host: ip,
          port,
          path: '/metrics',
          headers: { 'X-Node-Token': process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026' },
          timeout: 3000,
        },
        (res) => {
          let data = '';
          res.on('data', (chunk) => (data += chunk));
          res.on('end', () => {
            try {
              resolve(JSON.parse(data));
            } catch (_) {
              resolve(null);
            }
          });
        },
      );

      req.on('error', () => resolve(null));
      req.on('timeout', () => {
        req.destroy();
        resolve(null);
      });
    });
  }
}
