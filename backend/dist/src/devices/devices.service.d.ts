import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
export declare class DevicesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    listDevices(userId: string): Promise<({
        vpnPeers: {
            id: string;
            status: string;
            serverId: string;
            allocatedIpV4: string;
            server: {
                name: string;
                countryCode: string;
                city: string;
            };
        }[];
    } & {
        id: string;
        createdAt: Date;
        updatedAt: Date;
        name: string;
        userId: string;
        deviceIdentifier: string;
        platform: string;
        publicKey: string;
        lastSeenAt: Date;
    })[]>;
    registerDevice(userId: string, dto: RegisterDeviceDto): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        name: string;
        userId: string;
        deviceIdentifier: string;
        platform: string;
        publicKey: string;
        lastSeenAt: Date;
    }>;
    removeDevice(userId: string, deviceId: string): Promise<{
        message: string;
    }>;
}
