import { IsEnum, IsNotEmpty, IsString } from 'class-validator';
import { Platform } from '@prisma/client';

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
