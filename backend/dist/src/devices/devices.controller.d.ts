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
            updatedAt: Date;
            serverId: string;
            allocatedIpV4: string;
            status: string;
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
        userId: string;
        deviceIdentifier: string;
        name: string;
        platform: string;
        publicKey: string;
        lastSeenAt: Date;
        createdAt: Date;
        updatedAt: Date;
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
