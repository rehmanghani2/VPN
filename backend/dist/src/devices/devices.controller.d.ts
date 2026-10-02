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
            serverId: string;
            status: string;
            updatedAt: Date;
            server: {
                name: string;
                countryCode: string;
                city: string;
                isObfuscated: boolean;
            };
            allocatedIpV4: string;
        };
    }[]>;
    register(userId: string, dto: RegisterDeviceDto): Promise<{
        id: string;
        userId: string;
        createdAt: Date;
        updatedAt: Date;
        deviceIdentifier: string;
        name: string;
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
