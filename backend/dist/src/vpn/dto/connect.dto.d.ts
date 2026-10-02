export declare class ConnectVpnDto {
    deviceId: string;
    serverId?: string;
    protocol?: string;
    threatShieldLevel?: 'off' | 'malware_only' | 'all';
    enablePostQuantum?: boolean;
}
export declare class RotateKeyDto {
    deviceId: string;
    newPublicKey: string;
    enablePostQuantum?: boolean;
}
export declare class DisconnectVpnDto {
    deviceId: string;
    serverId?: string;
}
