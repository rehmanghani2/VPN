import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
export declare class DevicesController {
    private readonly devicesService;
    constructor(devicesService: DevicesService);
    list(userId: string): Promise<{
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
    register(userId: string, dto: RegisterDeviceDto): Promise<{
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
    disconnect(userId: string, deviceId: string): Promise<{
        success: boolean;
        message: string;
    }>;
    remove(userId: string, deviceId: string): Promise<{
        success: boolean;
        message: string;
    }>;
}
