import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
export declare class DevicesService {
    private readonly prisma;
    private readonly logger;
    constructor(prisma: PrismaService);
    listDevices(userId: string): Promise<{
        id: string;
        name: string;
        platform: string;
        deviceIdentifier: string;
        lastSeenAt: Date;
        isConnected: boolean;
        activeSession: {
            id: string;
            status: string;
            updatedAt: Date;
            serverId: string;
            allocatedIpV4: string;
            server: {
                name: string;
                countryCode: string;
                city: string;
                isObfuscated: boolean;
            };
        };
    }[]>;
    registerDevice(userId: string, dto: RegisterDeviceDto): Promise<{
        id: string;
        name: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        deviceIdentifier: string;
        platform: string;
        publicKey: string;
        lastSeenAt: Date;
    }>;
    disconnectDevice(userId: string, deviceId: string): Promise<{
        success: boolean;
        message: string;
    }>;
    removeDevice(userId: string, deviceId: string): Promise<{
        success: boolean;
        message: string;
    }>;
    private syncPeerToNode;
}
