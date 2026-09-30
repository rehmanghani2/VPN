import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
export declare class DevicesController {
    private readonly devicesService;
    constructor(devicesService: DevicesService);
    list(userId: string): Promise<({
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
    remove(userId: string, deviceId: string): Promise<{
        message: string;
    }>;
}
