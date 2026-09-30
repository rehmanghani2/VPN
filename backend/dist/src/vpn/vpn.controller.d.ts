import { VpnService } from './vpn.service';
import { ConnectVpnDto, DisconnectVpnDto } from './dto/connect.dto';
export declare class VpnController {
    private readonly vpnService;
    constructor(vpnService: VpnService);
    listServers(): Promise<{
        id: string;
        status: string;
        name: string;
        countryCode: string;
        countryName: string;
        city: string;
        hostname: string;
        capacity: number;
        currentLoad: number;
    }[]>;
    connect(userId: string, dto: ConnectVpnDto): Promise<{
        tunnel: {
            serverName: any;
            countryCode: any;
            city: any;
            endpoint: string;
            serverPublicKey: any;
            clientAddressV4: string;
            clientAddressV6: string;
            dns: any[];
            allowedIPs: string[];
            mtu: number;
            keepalive: number;
        };
        peerId: string;
        status: string;
    }>;
    disconnect(userId: string, dto: DisconnectVpnDto): Promise<{
        message: string;
    }>;
}
