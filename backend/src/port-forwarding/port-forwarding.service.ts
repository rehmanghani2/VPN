import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePortForwardDto } from './dto/port-forwarding.dto';

@Injectable()
export class PortForwardingService {
  private readonly logger = new Logger(PortForwardingService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * List all active port forwards for a user
   */
  async getUserPortForwards(userId: string) {
    return this.prisma.portForwardRule.findMany({
      where: { userId },
      include: {
        device: { select: { id: true, name: true, platform: true } },
        server: {
          select: {
            id: true,
            name: true,
            countryCode: true,
            city: true,
            publicIp: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Create a new port forward rule
   */
  async createPortForward(userId: string, dto: CreatePortForwardDto) {
    // 1. Verify User & Subscription Eligibility
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { subscriptions: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const activeSub = user.subscriptions.find((s) => s.status === 'ACTIVE');
    if (!activeSub || activeSub.planType === 'FREE') {
      throw new ForbiddenException(
        'Port Forwarding requires an active Pro or Family subscription',
      );
    }

    // 2. Verify Device & Server
    const device = await this.prisma.device.findFirst({
      where: { id: dto.deviceId, userId },
    });
    if (!device) throw new NotFoundException('Device not found or not owned by user');

    const server = await this.prisma.vpnServer.findUnique({
      where: { id: dto.serverId },
    });
    if (!server) throw new NotFoundException('VPN server not found');

    // 3. Find active VPN peer for client's internal tunnel IP
    const peer = await this.prisma.vpnPeer.findFirst({
      where: { deviceId: dto.deviceId, serverId: dto.serverId, status: 'ACTIVE' },
    });
    if (!peer) {
      throw new ConflictException(
        'Device must be actively connected to this server to establish port forwarding',
      );
    }

    const protocol = dto.protocol || 'BOTH';

    // 4. Allocate External Port
    let externalPort = dto.externalPort;
    if (externalPort) {
      const existing = await this.prisma.portForwardRule.findFirst({
        where: {
          serverId: dto.serverId,
          externalPort,
          status: 'ACTIVE',
        },
      });
      if (existing) {
        throw new ConflictException(
          `Port ${externalPort} is already forwarded on server ${server.name}`,
        );
      }
    } else {
      // Find next free port in range 40000 - 55000
      externalPort = await this.findAvailableExternalPort(dto.serverId);
    }

    // 5. Store rule in Database
    const rule = await this.prisma.portForwardRule.create({
      data: {
        userId,
        deviceId: dto.deviceId,
        serverId: dto.serverId,
        externalPort,
        internalPort: dto.internalPort,
        protocol,
        status: 'ACTIVE',
      },
      include: {
        device: { select: { id: true, name: true } },
        server: { select: { id: true, name: true, publicIp: true } },
      },
    });

    // 6. Synchronize with Edge Node Agent
    await this.notifyNodeAgent(server.publicIp, 'enable', {
      externalPort,
      internalPort: dto.internalPort,
      protocol,
      clientTunnelIp: peer.allocatedIpV4,
    });

    this.logger.log(
      `[PORT-FORWARD] Assigned ${server.publicIp}:${externalPort} -> ${peer.allocatedIpV4}:${dto.internalPort} (${protocol}) for ${user.email}`,
    );

    return {
      rule,
      connectionEndpoint: `${server.publicIp}:${externalPort}`,
      clientTunnelIp: peer.allocatedIpV4,
    };
  }

  /**
   * Delete / Release a port forward rule
   */
  async deletePortForward(userId: string, ruleId: string) {
    const rule = await this.prisma.portForwardRule.findFirst({
      where: { id: ruleId, userId },
      include: {
        server: true,
        device: true,
      },
    });
    if (!rule) throw new NotFoundException('Port forward rule not found');

    const peer = await this.prisma.vpnPeer.findFirst({
      where: { deviceId: rule.deviceId, serverId: rule.serverId },
    });

    // Notify node agent to tear down DNAT iptables rules
    if (peer) {
      await this.notifyNodeAgent(rule.server.publicIp, 'disable', {
        externalPort: rule.externalPort,
        internalPort: rule.internalPort,
        protocol: rule.protocol,
        clientTunnelIp: peer.allocatedIpV4,
      });
    }

    await this.prisma.portForwardRule.delete({
      where: { id: ruleId },
    });

    return { success: true, message: `Port forward ${rule.externalPort} released` };
  }

  /**
   * Find available external port on a server in 40000-55000 range
   */
  private async findAvailableExternalPort(serverId: string): Promise<number> {
    const activeRules = await this.prisma.portForwardRule.findMany({
      where: { serverId, status: 'ACTIVE' },
      select: { externalPort: true },
    });

    const usedPorts = new Set(activeRules.map((r) => r.externalPort));
    const minPort = 40000;
    const maxPort = 55000;

    for (let p = minPort; p <= maxPort; p++) {
      if (!usedPorts.has(p)) return p;
    }

    throw new ConflictException('No available ports remaining on this edge server');
  }

  /**
   * Call Edge Node Agent on remote Linux server
   */
  private async notifyNodeAgent(
    serverIp: string,
    action: 'enable' | 'disable',
    payload: any,
  ) {
    const agentPort = process.env.AGENT_PORT || 51821;
    const token = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';
    const url = `http://${serverIp}:${agentPort}/port-forward/${action}`;

    try {
      await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Node-Token': token,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(4000),
      });
    } catch (err: any) {
      this.logger.warn(
        `Failed to sync port forward ${action} with node agent at ${url}: ${err.message}`,
      );
      // Non-blocking in dev/mock environments
    }
  }
}
