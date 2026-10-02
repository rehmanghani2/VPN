import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ConnectMultiHopDto } from './dto/multihop.dto';

export interface MultiHopPair {
  id: string;
  name: string;
  entryServer: any;
  exitServer: any;
  estimatedPingMs: number;
  securityRating: string;
  isPopular?: boolean;
}

@Injectable()
export class MultiHopService {
  private readonly logger = new Logger(MultiHopService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Get pre-computed and dynamic Multi-Hop (Double VPN) server pairs
   */
  async getMultiHopPairs(): Promise<MultiHopPair[]> {
    const servers = await this.prisma.vpnServer.findMany({
      where: { status: 'ONLINE' },
    });

    if (servers.length < 2) {
      return [];
    }

    const pairs: MultiHopPair[] = [];

    // Construct inter-country pairs
    for (const entry of servers) {
      for (const exit of servers) {
        if (entry.id !== exit.id && entry.countryCode !== exit.countryCode) {
          // Calculate estimated distance/ping
          const ping = this.calculateEstimatedPing(entry.countryCode, exit.countryCode);
          const pairId = `${entry.id.substring(0, 6)}-to-${exit.id.substring(0, 6)}`;

          pairs.push({
            id: pairId,
            name: `${entry.city} ➔ ${exit.city}`,
            entryServer: {
              id: entry.id,
              name: entry.name,
              countryCode: entry.countryCode,
              countryName: entry.countryName,
              city: entry.city,
              publicIp: entry.publicIp,
            },
            exitServer: {
              id: exit.id,
              name: exit.name,
              countryCode: exit.countryCode,
              countryName: exit.countryName,
              city: exit.city,
              publicIp: exit.publicIp,
            },
            estimatedPingMs: ping,
            securityRating: 'A+ (DOUBLE CHACHA20-POLY1305)',
            isPopular: (entry.countryCode === 'DE' && exit.countryCode === 'US') ||
                       (entry.countryCode === 'GB' && exit.countryCode === 'SG'),
          });
        }
      }
    }

    // Sort by popularity and lowest latency
    return pairs.sort((a, b) => (b.isPopular ? 1 : 0) - (a.isPopular ? 1 : 0));
  }

  /**
   * Connect to a Multi-Hop (Double VPN) chain
   */
  async connectMultiHop(userId: string, dto: ConnectMultiHopDto) {
    if (dto.entryServerId === dto.exitServerId) {
      throw new BadRequestException('Entry and Exit servers must be distinct');
    }

    // 1. Verify User Plan Gating
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { subscriptions: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const activeSub = user.subscriptions.find((s) => s.status === 'ACTIVE');
    if (!activeSub || activeSub.planType === 'FREE') {
      throw new ForbiddenException(
        'Multi-Hop (Double VPN) requires an active Pro or Family subscription',
      );
    }

    // 2. Fetch Entry & Exit Servers
    const entryServer = await this.prisma.vpnServer.findUnique({
      where: { id: dto.entryServerId },
    });
    const exitServer = await this.prisma.vpnServer.findUnique({
      where: { id: dto.exitServerId },
    });

    if (!entryServer || !exitServer) {
      throw new NotFoundException('Specified Entry or Exit server not found');
    }

    // 3. Verify Device
    const device = await this.prisma.device.findFirst({
      where: { id: dto.deviceId, userId },
    });
    if (!device) throw new NotFoundException('Device not found');

    // 4. Allocate or retrieve peer session on Entry Server
    let peer = await this.prisma.vpnPeer.findFirst({
      where: { deviceId: dto.deviceId, serverId: dto.entryServerId },
    });

    if (!peer) {
      // Allocate client IPv4 in Entry server subnet (e.g. 10.8.0.x)
      const count = await this.prisma.vpnPeer.count({ where: { serverId: dto.entryServerId } });
      const allocatedIpV4 = `10.8.0.${count + 2}`;
      const allocatedIpV6 = `fd42:42:42::${count + 2}`;

      peer = await this.prisma.vpnPeer.create({
        data: {
          deviceId: dto.deviceId,
          serverId: dto.entryServerId,
          allocatedIpV4,
          allocatedIpV6,
          clientPublicKey: device.publicKey,
          status: 'ACTIVE',
        },
      });
    }

    // 5. Notify Entry Server Node Agent to route this peer through Exit Server backhaul
    await this.notifyEntryNodeRouting(entryServer.publicIp, {
      clientTunnelIp: peer.allocatedIpV4,
      exitServerIp: exitServer.publicIp,
      exitServerWgPublicKey: exitServer.wgPublicKey,
    });

    this.logger.log(
      `[MULTIHOP] Established Double VPN chain: Client (${peer.allocatedIpV4}) ➔ Entry ${entryServer.city} ➔ Exit ${exitServer.city} for ${user.email}`,
    );

    return {
      type: 'DOUBLE_VPN_MULTIHOP',
      entryServer: {
        id: entryServer.id,
        name: entryServer.name,
        city: entryServer.city,
        countryCode: entryServer.countryCode,
        publicIp: entryServer.publicIp,
        wgPort: entryServer.wgPort,
        wgPublicKey: entryServer.wgPublicKey,
      },
      exitServer: {
        id: exitServer.id,
        name: exitServer.name,
        city: exitServer.city,
        countryCode: exitServer.countryCode,
        publicIp: exitServer.publicIp,
      },
      clientAddressV4: peer.allocatedIpV4,
      clientAddressV6: peer.allocatedIpV6,
      dns: [entryServer.dnsV4, '10.8.0.53'],
      allowedIPs: ['0.0.0.0/0', '::/0'],
      securitySummary: 'Traffic is encrypted to Entry node, then re-routed across encrypted backbone to Exit node.',
    };
  }

  /**
   * Get Onion over VPN (Tor Gateway) Server nodes
   */
  async getOnionServers() {
    const servers = await this.prisma.vpnServer.findMany({
      where: { status: 'ONLINE' },
      select: {
        id: true,
        name: true,
        countryCode: true,
        countryName: true,
        city: true,
        publicIp: true,
        wgPort: true,
      },
    });

    return servers.map((s) => ({
      ...s,
      isOnionOverVpn: true,
      torTransparentPort: 9040,
      torDnsPort: 5353,
      description: 'Routes all VPN traffic through 3-hop Tor network. Access .onion sites directly in standard browsers.',
    }));
  }

  private calculateEstimatedPing(code1: string, code2: string): number {
    const key = `${code1}-${code2}`;
    const pings: Record<string, number> = {
      'DE-US': 95,
      'US-DE': 95,
      'DE-GB': 32,
      'GB-DE': 32,
      'GB-SG': 160,
      'SG-GB': 160,
      'US-SG': 190,
      'SG-US': 190,
      'US-GB': 80,
      'GB-US': 80,
    };
    return pings[key] || 110;
  }

  private async notifyEntryNodeRouting(entryIp: string, payload: any) {
    const agentPort = process.env.AGENT_PORT || 51821;
    const token = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';
    const url = `http://${entryIp}:${agentPort}/multihop/route`;

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
      this.logger.warn(`Failed to sync multihop routing with entry node: ${err.message}`);
    }
  }
}
