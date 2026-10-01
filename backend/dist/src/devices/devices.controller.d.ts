import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
export declare class DevicesController {
    private readonly devicesService;
    constructor(devicesService: DevicesService);
    list(userId: string): Promise<({
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
    register(userId: string, dto: RegisterDeviceDto): Promise<{
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
    remove(userId: string, deviceId: string): Promise<{
        message: string;
    }>;
}
