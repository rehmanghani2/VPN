import { Platform } from '@prisma/client';
export declare class RegisterDeviceDto {
    deviceIdentifier: string;
    name: string;
    platform: Platform;
    publicKey: string;
}
