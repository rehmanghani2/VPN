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
        isObfuscated: boolean;
        obfuscationPort: number;
        obfuscationProtocol: string;
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
            threatShieldLevel: "off" | "malware_only" | "all";
            allowedIPs: string[];
            mtu: number;
            keepalive: number;
            isObfuscated: any;
            obfuscationProtocol: any;
            obfuscationParams: {
                junkPacketCount: number;
                junkPacketMinSize: number;
                junkPacketMaxSize: number;
                initiationHeader: string;
                responseHeader: string;
            };
            isPostQuantum: boolean;
            postQuantumAlgorithm: string;
            presharedKey: string;
            keyRotatedAt: string;
        };
        peerId: string;
        status: string;
    }>;
    disconnect(userId: string, dto: DisconnectVpnDto): Promise<{
        message: string;
    }>;
    rotateKey(userId: string, dto: {
        deviceId: string;
        newPublicKey: string;
        enablePostQuantum?: boolean;
    }): Promise<{
        success: boolean;
        message: string;
        deviceId: string;
        newPublicKey: string;
        rotatedPeers: any[];
        rotatedAt: Date;
    }>;
    getKeyRotationStatus(userId: string, deviceId: string): Promise<{
        deviceId: string;
        deviceName: string;
        publicKey: string;
        lastRotatedAt: Date;
        keyAgeDays: number;
        isRecommendedToRotate: boolean;
        postQuantumEnabled: boolean;
        postQuantumAlgorithm: string;
        activeTunnelsCount: number;
    }>;
    private syncPeerToNode;
}
