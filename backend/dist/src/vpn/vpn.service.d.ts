import { PrismaService } from '../prisma/prisma.service';
import { ConnectVpnDto, DisconnectVpnDto } from './dto/connect.dto';
export declare class VpnService {
    private readonly prisma;
    private readonly logger;
    constructor(prisma: PrismaService);
    listServers(): Promise<{
        id: string;
        name: string;
        countryCode: string;
        countryName: string;
        city: string;
        hostname: string;
        status: string;
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
    private syncPeerToNode;
}
