export declare enum Platform {
    ANDROID = "ANDROID",
    IOS = "IOS",
    WINDOWS = "WINDOWS",
    MACOS = "MACOS",
    LINUX = "LINUX"
}
export declare class RegisterDeviceDto {
    deviceIdentifier: string;
    name: string;
    platform: Platform;
    publicKey: string;
}
