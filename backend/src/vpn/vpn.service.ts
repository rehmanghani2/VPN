import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ConnectVpnDto, DisconnectVpnDto } from './dto/connect.dto';

@Injectable()
export class VpnService {
  constructor(private readonly prisma: PrismaService) {}

  async listServers() {
    return this.prisma.vpnServer.findMany({
      where: {
        status: { in: ['ONLINE', 'DEGRADED'] },
      },
      select: {
        id: true,
        name: true,
        countryCode: true,
        countryName: true,
        city: true,
        hostname: true,
        status: true,
        capacity: true,
        currentLoad: true,
      },
      orderBy: [{ countryName: 'asc' }, { city: 'asc' }],
    });
  }

  async connect(userId: string, dto: ConnectVpnDto) {
    // 1. Validate device ownership
    const device = await this.prisma.device.findFirst({
      where: { id: dto.deviceId, userId },
    });

    if (!device) {
      throw new NotFoundException('Device not found or not owned by user');
    }

    // 2. Validate user subscription
    const subscription = await this.prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
    });

    if (!subscription) {
      throw new ForbiddenException('An active subscription is required to connect');
    }

    // 3. Resolve target server (Specific Server or Smart Connect)
    let server = null;
    if (dto.serverId) {
      server = await this.prisma.vpnServer.findUnique({
        where: { id: dto.serverId },
      });
      if (!server || server.status === 'OFFLINE' || server.status === 'MAINTENANCE') {
        throw new BadRequestException('Selected VPN server is currently unavailable');
      }
    } else {
      // Smart Connect: pick server with lowest current load
      server = await this.prisma.vpnServer.findFirst({
        where: { status: 'ONLINE' },
        orderBy: { currentLoad: 'asc' },
      });
      if (!server) {
        throw new NotFoundException('No available VPN servers found');
      }
    }

    // 4. Check if peer already exists for this device & server
    let peer = await this.prisma.vpnPeer.findFirst({
      where: { deviceId: device.id, serverId: server.id },
    });

    if (!peer) {
      // Allocate next available IP from server subnet (10.8.0.2 to 10.8.0.254)
      const allocatedIps = await this.prisma.vpnPeer.findMany({
        where: { serverId: server.id },
        select: { allocatedIpV4: true },
      });

      const usedOctets = new Set(
        allocatedIps.map((p) => {
          const parts = p.allocatedIpV4.split('.');
          return parseInt(parts[3], 10);
        }),
      );

      let allocatedOctet = -1;
      for (let i = 2; i <= 254; i++) {
        if (!usedOctets.has(i)) {
          allocatedOctet = i;
          break;
        }
      }

      if (allocatedOctet === -1) {
        throw new BadRequestException('Server capacity reached: no available IP slots');
      }

      const clientIpV4 = `10.8.0.${allocatedOctet}`;
      const clientIpV6 = `fd42:42:42::${allocatedOctet}`;

      peer = await this.prisma.vpnPeer.create({
        data: {
          deviceId: device.id,
          serverId: server.id,
          allocatedIpV4: clientIpV4,
          allocatedIpV6: clientIpV6,
          clientPublicKey: device.publicKey,
          status: 'ACTIVE',
        },
      });

      // Increment server load
      await this.prisma.vpnServer.update({
        where: { id: server.id },
        data: { currentLoad: { increment: 1 } },
      });
    } else {
      // Ensure peer is marked ACTIVE and matches latest device public key
      peer = await this.prisma.vpnPeer.update({
        where: { id: peer.id },
        data: {
          clientPublicKey: device.publicKey,
          status: 'ACTIVE',
        },
      });
    }

    // Update device last seen
    await this.prisma.device.update({
      where: { id: device.id },
      data: { lastSeenAt: new Date() },
    });

    // 5. Construct WireGuard Client Configuration Payload
    return {
      tunnel: {
        serverName: server.name,
        countryCode: server.countryCode,
        city: server.city,
        endpoint: `${server.publicIp}:${server.wgPort}`,
        serverPublicKey: server.wgPublicKey,
        clientAddressV4: `${peer.allocatedIpV4}/24`,
        clientAddressV6: `${peer.allocatedIpV6}/64`,
        dns: [server.dnsV4, server.dnsV6],
        allowedIPs: ['0.0.0.0/0', '::/0'],
        mtu: 1360,
        keepalive: 25,
      },
      peerId: peer.id,
      status: 'CONNECTED',
    };
  }

  async disconnect(userId: string, dto: DisconnectVpnDto) {
    const device = await this.prisma.device.findFirst({
      where: { id: dto.deviceId, userId },
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    const whereClause: any = { deviceId: device.id, status: 'ACTIVE' };
    if (dto.serverId) {
      whereClause.serverId = dto.serverId;
    }

    const activePeers = await this.prisma.vpnPeer.findMany({
      where: whereClause,
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
    }

    return { message: 'Disconnected successfully' };
  }
}
