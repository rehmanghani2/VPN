export declare class ConnectVpnDto {
    deviceId: string;
    serverId?: string;
    protocol?: string;
    threatShieldLevel?: 'off' | 'malware_only' | 'all';
}
export declare class DisconnectVpnDto {
    deviceId: string;
    serverId?: string;
}
