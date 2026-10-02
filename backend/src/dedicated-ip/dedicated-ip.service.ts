import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ReserveDedicatedIpDto, AssignDedicatedIpDto } from './dto/dedicated-ip.dto';

@Injectable()
export class DedicatedIpService {
  private readonly logger = new Logger(DedicatedIpService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Get all dedicated IPs reserved by the user
   */
  async getUserDedicatedIps(userId: string) {
    return this.prisma.dedicatedIp.findMany({
      where: { userId },
      include: {
        server: {
          select: {
            id: true,
            name: true,
            countryCode: true,
            countryName: true,
            city: true,
            publicIp: true,
            status: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Get available regions/servers supporting dedicated IPs
   */
  async getAvailableRegions() {
    return this.prisma.vpnServer.findMany({
      where: { status: 'ONLINE' },
      select: {
        id: true,
        name: true,
        countryCode: true,
        countryName: true,
        city: true,
        publicIp: true,
      },
    });
  }

  /**
   * Reserve / Purchase a dedicated IP for a user
   */
  async reserveDedicatedIp(userId: string, dto: ReserveDedicatedIpDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { subscriptions: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const activeSub = user.subscriptions.find((s) => s.status === 'ACTIVE');
    if (!activeSub || activeSub.planType === 'FREE') {
      throw new ForbiddenException(
        'Dedicated IP add-on requires an active Pro or Family subscription',
      );
    }

    const server = await this.prisma.vpnServer.findUnique({
      where: { id: dto.serverId },
    });
    if (!server) throw new NotFoundException('VPN server not found');

    // Generate a unique clean dedicated public IP (in production: drawn from ISP subnet pool)
    const baseOctets = server.publicIp.split('.');
    const randomHost = Math.floor(Math.random() * 200) + 20;
    const dedicatedPublicIp = `${baseOctets[0]}.${baseOctets[1]}.${baseOctets[2]}.${randomHost}`;

    // Verify uniqueness
    const existing = await this.prisma.dedicatedIp.findUnique({
      where: { publicIp: dedicatedPublicIp },
    });
    if (existing) {
      throw new ConflictException('Dedicated IP already allocated. Please retry.');
    }

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30-day initial billing cycle

    const record = await this.prisma.dedicatedIp.create({
      data: {
        userId,
        serverId: dto.serverId,
        publicIp: dedicatedPublicIp,
        status: 'ACTIVE',
        expiresAt,
      },
      include: {
        server: true,
      },
    });

    this.logger.log(
      `[DEDICATED-IP] Assigned Dedicated IP ${dedicatedPublicIp} on ${server.name} (${server.city}) to ${user.email}`,
    );

    return {
      dedicatedIp: record,
      message: `Dedicated IP ${dedicatedPublicIp} successfully provisioned in ${server.city}`,
    };
  }

  /**
   * Assign a dedicated IP to an active client device
   */
  async assignToDevice(userId: string, dto: AssignDedicatedIpDto) {
    const dedicated = await this.prisma.dedicatedIp.findFirst({
      where: { id: dto.dedicatedIpId, userId, status: 'ACTIVE' },
      include: { server: true },
    });
    if (!dedicated) throw new NotFoundException('Dedicated IP not found');

    const peer = await this.prisma.vpnPeer.findFirst({
      where: { deviceId: dto.deviceId, serverId: dedicated.serverId, status: 'ACTIVE' },
    });
    if (!peer) {
      throw new ConflictException(
        'Device must be connected to this server to bind dedicated IP SNAT routing',
      );
    }

    // Call edge node agent to apply SNAT rule
    await this.notifyNodeAgent(dedicated.server.publicIp, 'bind', {
      clientTunnelIp: peer.allocatedIpV4,
      dedicatedPublicIp: dedicated.publicIp,
    });

    return {
      success: true,
      message: `Dedicated IP ${dedicated.publicIp} bound to device tunnel ${peer.allocatedIpV4}`,
    };
  }

  /**
   * Release / Delete Dedicated IP
   */
  async releaseDedicatedIp(userId: string, id: string) {
    const dedicated = await this.prisma.dedicatedIp.findFirst({
      where: { id, userId },
      include: { server: true },
    });
    if (!dedicated) throw new NotFoundException('Dedicated IP not found');

    await this.prisma.dedicatedIp.delete({ where: { id } });

    return { success: true, message: `Dedicated IP ${dedicated.publicIp} released` };
  }

  private async notifyNodeAgent(
    serverIp: string,
    action: 'bind' | 'unbind',
    payload: any,
  ) {
    const agentPort = process.env.AGENT_PORT || 51821;
    const token = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';
    const url = `http://${serverIp}:${agentPort}/dedicated-ip/${action}`;

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
      this.logger.warn(`Dedicated IP node sync ${action} failed: ${err.message}`);
    }
  }
}
