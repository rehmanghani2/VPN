import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class ConnectVpnDto {
  @IsString()
  @IsNotEmpty({ message: 'Device ID is required' })
  deviceId: string;

  @IsString()
  @IsOptional()
  serverId?: string; // If omitted, system picks fastest / lowest load (Smart Connect)
}

export class DisconnectVpnDto {
  @IsString()
  @IsNotEmpty({ message: 'Device ID is required' })
  deviceId: string;

  @IsString()
  @IsOptional()
  serverId?: string;
}
