import {
  Injectable,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OverrideUserPlanDto, UpdateServerDto } from './dto/admin.dto';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Global Cluster Telemetry & Business KPI Overview
   */
  async getOverview() {
    const totalUsers = await this.prisma.user.count();

    const subscriptions = await this.prisma.subscription.groupBy({
      by: ['planType'],
      _count: { id: true },
    });

    const subBreakdown: Record<string, number> = {};
    for (const sub of subscriptions) {
      subBreakdown[sub.planType] = sub._count.id;
    }

    const servers = await this.prisma.vpnServer.findMany();
    const totalServers = servers.length;
    const onlineServers = servers.filter((s) => s.status === 'ONLINE').length;
    const drainingServers = servers.filter((s) => s.status === 'DRAINING').length;
    const offlineServers = servers.filter((s) => s.status === 'OFFLINE').length;

    const totalCapacity = servers.reduce((acc, s) => acc + s.capacity, 0);
    const activePeers = await this.prisma.vpnPeer.count({
      where: { status: 'ACTIVE' },
    });

    const totalDevices = await this.prisma.device.count();

    // Aggregated real-time metrics
    const clusterLoadPercent =
      totalCapacity > 0 ? ((activePeers / totalCapacity) * 100).toFixed(1) : '0';
    const estimatedBandwidthGbps = ((activePeers * 18.5) / 1000).toFixed(2); // Avg 18.5 Mbps per active tunnel

    return {
      kpi: {
        totalUsers,
        totalDevices,
        activePeers,
        totalCapacity,
        clusterLoadPercent: parseFloat(clusterLoadPercent),
        estimatedBandwidthGbps: parseFloat(estimatedBandwidthGbps),
      },
      servers: {
        total: totalServers,
        online: onlineServers,
        draining: drainingServers,
        offline: offlineServers,
      },
      subscriptions: {
        total: Object.values(subBreakdown).reduce((a, b) => a + b, 0),
        breakdown: subBreakdown,
      },
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Detailed Operational Node Health & Telemetry
   */
  async listServers() {
    const servers = await this.prisma.vpnServer.findMany({
      orderBy: [{ status: 'asc' }, { countryName: 'asc' }, { city: 'asc' }],
      include: {
        _count: {
          select: { vpnPeers: true },
        },
      },
    });

    return servers.map((srv) => ({
      ...srv,
      activePeersCount: srv.currentLoad,
      loadPercent: srv.capacity > 0 ? Math.round((srv.currentLoad / srv.capacity) * 100) : 0,
    }));
  }

  /**
   * Mark Server as DRAINING for rolling updates
   */
  async drainServer(serverId: string) {
    const server = await this.prisma.vpnServer.update({
      where: { id: serverId },
      data: { status: 'DRAINING' },
    });
    this.logger.warn(`[ADMIN] Node ${server.name} set to DRAINING.`);
    return { success: true, message: `Node ${server.name} is now draining`, server };
  }

  /**
   * Restore Server to ONLINE active rotation
   */
  async restoreServer(serverId: string) {
    const server = await this.prisma.vpnServer.update({
      where: { id: serverId },
      data: { status: 'ONLINE' },
    });
    this.logger.log(`[ADMIN] Node ${server.name} restored to ONLINE.`);
    return { success: true, message: `Node ${server.name} restored to ONLINE`, server };
  }

  /**
   * Update server properties (capacity, name, status)
   */
  async updateServer(serverId: string, dto: UpdateServerDto) {
    const server = await this.prisma.vpnServer.update({
      where: { id: serverId },
      data: { ...dto },
    });
    return { success: true, server };
  }

  /**
   * Remove edge node from cluster
   */
  async deleteServer(serverId: string) {
    await this.prisma.vpnServer.delete({
      where: { id: serverId },
    });
    return { success: true, message: 'Server deleted from cluster' };
  }

  /**
   * User Management Directory
   */
  async listUsers(search?: string) {
    const where: any = {};
    if (search) {
      where.email = { contains: search };
    }

    const users = await this.prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        subscriptions: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
        devices: {
          include: {
            vpnPeers: {
              where: { status: 'ACTIVE' },
              include: { server: true },
            },
          },
        },
      },
    });

    return users.map((u) => {
      const sub = u.subscriptions[0];
      const activeSessions = u.devices.flatMap((d) => d.vpnPeers);

      return {
        id: u.id,
        email: u.email,
        role: u.role,
        status: u.status,
        createdAt: u.createdAt,
        subscription: sub
          ? {
              planType: sub.planType,
              status: sub.status,
              maxDevices: sub.maxDevices,
              expiresAt: sub.expiresAt,
            }
          : {
              planType: 'FREE',
              status: 'ACTIVE',
              maxDevices: 1,
              expiresAt: null,
            },
        devicesCount: u.devices.length,
        activeSessionsCount: activeSessions.length,
        activeSessions: activeSessions.map((s) => ({
          serverName: s.server.name,
          allocatedIp: s.allocatedIpV4,
          updatedAt: s.updatedAt,
        })),
      };
    });
  }

  /**
   * Override user subscription plan
   */
  async overrideUserPlan(userId: string, dto: OverrideUserPlanDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) throw new NotFoundException('User not found');

    const defaultMax = dto.planType === 'FREE' ? 1 : dto.planType === 'PRO' ? 5 : 10;
    const maxDevices = dto.maxDevices ?? defaultMax;

    const existing = await this.prisma.subscription.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    let updated;
    if (existing) {
      updated = await this.prisma.subscription.update({
        where: { id: existing.id },
        data: {
          planType: dto.planType,
          status: 'ACTIVE',
          maxDevices,
        },
      });
    } else {
      updated = await this.prisma.subscription.create({
        data: {
          userId,
          planType: dto.planType,
          status: 'ACTIVE',
          maxDevices,
        },
      });
    }

    this.logger.log(`[ADMIN] Overrode plan for user ${user.email} to ${dto.planType} (Max: ${maxDevices})`);
    return { success: true, subscription: updated };
  }

  /**
   * Killswitch: Terminate all active VPN sessions for user across all global nodes
   */
  async terminateUserSessions(userId: string) {
    const activePeers = await this.prisma.vpnPeer.findMany({
      where: {
        device: { userId },
        status: 'ACTIVE',
      },
      include: { server: true, device: true },
    });

    for (const peer of activePeers) {
      await this.prisma.vpnPeer.update({
        where: { id: peer.id },
        data: { status: 'INACTIVE' },
      });

      await this.prisma.vpnServer.update({
        where: { id: peer.serverId },
        data: { currentLoad: { decrement: 1 } },
      });

      if (peer.server?.publicIp) {
        await this.syncPeerRemoval(peer.server.publicIp, peer.clientPublicKey);
      }
    }

    this.logger.warn(`[ADMIN KILLSWITCH] Terminated ${activePeers.length} sessions for user ${userId}.`);
    return {
      success: true,
      message: `Terminated ${activePeers.length} active VPN sessions.`,
      terminatedCount: activePeers.length,
    };
  }

  /**
   * Recent cluster audit events
   */
  async getAuditFeed() {
    const recentPeers = await this.prisma.vpnPeer.findMany({
      take: 15,
      orderBy: { updatedAt: 'desc' },
      include: {
        server: { select: { name: true, city: true, countryCode: true } },
        device: { select: { name: true, platform: true } },
      },
    });

    return recentPeers.map((p) => ({
      id: p.id,
      event: p.status === 'ACTIVE' ? 'PEER_CONNECTED' : 'PEER_DISCONNECTED',
      server: `${p.server.name} (${p.server.city})`,
      device: `${p.device.name} [${p.device.platform}]`,
      allocatedIp: p.allocatedIpV4,
      timestamp: p.updatedAt,
    }));
  }

  private async syncPeerRemoval(serverIp: string, publicKey: string) {
    if (!serverIp || serverIp.startsWith('198.51.100.') || serverIp === '127.0.0.1') return;

    try {
      const agentPort = process.env.AGENT_PORT || 51821;
      const agentUrl = `http://${serverIp}:${agentPort}/peers/remove`;
      const token = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2000);

      await fetch(agentUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Node-Token': token,
        },
        body: JSON.stringify({ publicKey }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
    } catch (_) {}
  }
}
