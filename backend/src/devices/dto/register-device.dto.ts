import { IsEnum, IsNotEmpty, IsString } from 'class-validator';

export enum Platform {
  ANDROID = 'ANDROID',
  IOS = 'IOS',
  WINDOWS = 'WINDOWS',
  MACOS = 'MACOS',
  LINUX = 'LINUX',
}

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  deviceIdentifier: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsEnum(Platform)
  platform: Platform;

  @IsString()
  @IsNotEmpty({ message: 'Device WireGuard public key is required' })
  publicKey: string;
}
