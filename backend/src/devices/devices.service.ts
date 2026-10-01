import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Injectable()
export class DevicesService {
  private readonly logger = new Logger(DevicesService.name);

  constructor(private readonly prisma: PrismaService) {}

  async listDevices(userId: string) {
    const devices = await this.prisma.device.findMany({
      where: { userId },
      orderBy: { lastSeenAt: 'desc' },
      include: {
        vpnPeers: {
          where: { status: 'ACTIVE' },
          select: {
            id: true,
            serverId: true,
            allocatedIpV4: true,
            status: true,
            updatedAt: true,
            server: {
              select: {
                name: true,
                countryCode: true,
                city: true,
                isObfuscated: true,
              },
            },
          },
        },
      },
    });

    return devices.map((d) => ({
      id: d.id,
      name: d.name,
      platform: d.platform,
      deviceIdentifier: d.deviceIdentifier,
      lastSeenAt: d.lastSeenAt,
      isConnected: d.vpnPeers.length > 0,
      activeSession: d.vpnPeers[0] || null,
    }));
  }

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    // 1. Check existing device with same identifier for this user
    const existing = await this.prisma.device.findUnique({
      where: {
        userId_deviceIdentifier: {
          userId,
          deviceIdentifier: dto.deviceIdentifier,
        },
      },
    });

    if (!existing) {
      // Check user subscription device quota
      const sub = await this.prisma.subscription.findFirst({
        where: { userId, status: 'ACTIVE' },
        orderBy: { createdAt: 'desc' },
      });

      const maxAllowed = sub ? sub.maxDevices : 1;
      const currentCount = await this.prisma.device.count({
        where: { userId },
      });

      if (currentCount >= maxAllowed) {
        throw new ForbiddenException(
          `Device limit reached (${maxAllowed} registered device limit for your plan). Upgrade to PRO or remove an existing device.`,
        );
      }
    }

    // 2. Upsert device record
    return this.prisma.device.upsert({
      where: {
        userId_deviceIdentifier: {
          userId,
          deviceIdentifier: dto.deviceIdentifier,
        },
      },
      update: {
        name: dto.name,
        platform: dto.platform,
        publicKey: dto.publicKey,
        lastSeenAt: new Date(),
      },
      create: {
        userId,
        deviceIdentifier: dto.deviceIdentifier,
        name: dto.name,
        platform: dto.platform,
        publicKey: dto.publicKey,
      },
    });
  }

  /**
   * Disconnect any active VPN tunnel session for a specific device remotely
   */
  async disconnectDevice(userId: string, deviceId: string) {
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId },
      include: {
        vpnPeers: {
          where: { status: 'ACTIVE' },
          include: { server: true },
        },
      },
    });

    if (!device) {
      throw new NotFoundException('Device not found or not owned by user');
    }

    for (const peer of device.vpnPeers) {
      await this.prisma.vpnPeer.update({
        where: { id: peer.id },
        data: { status: 'INACTIVE' },
      });

      await this.prisma.vpnServer.update({
        where: { id: peer.serverId },
        data: { currentLoad: { decrement: 1 } },
      });

      if (peer.server?.publicIp) {
        await this.syncPeerToNode(peer.server.publicIp, 'remove', {
          publicKey: peer.clientPublicKey,
        });
      }
    }

    this.logger.log(`[DEVICE DISCONNECT] Device ${device.name} remote sessions terminated.`);
    return { success: true, message: `Device ${device.name} disconnected successfully` };
  }

  /**
   * Delete a device and terminate any active sessions
   */
  async removeDevice(userId: string, deviceId: string) {
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId },
    });

    if (!device) {
      throw new NotFoundException('Device not found or not owned by user');
    }

    // Disconnect first
    await this.disconnectDevice(userId, deviceId);

    await this.prisma.device.delete({
      where: { id: deviceId },
    });

    return { success: true, message: 'Device successfully removed' };
  }

  private async syncPeerToNode(serverIp: string, action: 'add' | 'remove', payload: any) {
    if (!serverIp || serverIp.startsWith('198.51.100.') || serverIp === '127.0.0.1') {
      return;
    }

    try {
      const agentPort = process.env.AGENT_PORT || 51821;
      const agentUrl = `http://${serverIp}:${agentPort}/peers/${action}`;
      const token = process.env.NODE_AGENT_TOKEN || 'vpn-node-agent-secure-token-2026';

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2500);

      await fetch(agentUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Node-Token': token,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
    } catch (err: any) {
      this.logger.warn(`[NodeAgent] Node sync ${serverIp} skipped: ${err.message}`);
    }
  }
}
