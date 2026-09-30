import {
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  async listDevices(userId: string) {
    return this.prisma.device.findMany({
      where: { userId },
      orderBy: { lastSeenAt: 'desc' },
      include: {
        vpnPeers: {
          select: {
            id: true,
            serverId: true,
            allocatedIpV4: true,
            status: true,
            server: {
              select: {
                name: true,
                countryCode: true,
                city: true,
              },
            },
          },
        },
      },
    });
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
          `Device limit reached (${maxAllowed} device maximum for your plan). Upgrade your plan or remove an existing device.`,
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

  async removeDevice(userId: string, deviceId: string) {
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId },
    });

    if (!device) {
      throw new NotFoundException('Device not found or not owned by user');
    }

    await this.prisma.device.delete({
      where: { id: deviceId },
    });

    return { message: 'Device successfully removed' };
  }
}
