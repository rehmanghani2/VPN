import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
export declare class DevicesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    listDevices(userId: string): Promise<({
        vpnPeers: {
            id: string;
            serverId: string;
            allocatedIpV4: string;
            status: string;
            server: {
                name: string;
                countryCode: string;
                city: string;
            };
        }[];
    } & {
        id: string;
        userId: string;
        deviceIdentifier: string;
        name: string;
        platform: string;
        publicKey: string;
        lastSeenAt: Date;
        createdAt: Date;
        updatedAt: Date;
    })[]>;
    registerDevice(userId: string, dto: RegisterDeviceDto): Promise<{
        id: string;
        userId: string;
        deviceIdentifier: string;
        name: string;
        platform: string;
        publicKey: string;
        lastSeenAt: Date;
        createdAt: Date;
        updatedAt: Date;
    }>;
    removeDevice(userId: string, deviceId: string): Promise<{
        message: string;
    }>;
}
