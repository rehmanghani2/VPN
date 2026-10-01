import { IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class RegisterNodeDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  countryCode: string;

  @IsString()
  @IsNotEmpty()
  countryName: string;

  @IsString()
  @IsNotEmpty()
  city: string;

  @IsString()
  @IsNotEmpty()
  hostname: string;

  @IsString()
  @IsNotEmpty()
  publicIp: string;

  @IsInt()
  @IsOptional()
  wgPort?: number;

  @IsString()
  @IsNotEmpty()
  wgPublicKey: string;

  @IsInt()
  @IsOptional()
  capacity?: number;

  @IsString()
  @IsOptional()
  subnetV4?: string;

  @IsString()
  @IsOptional()
  subnetV6?: string;

  @IsString()
  @IsOptional()
  dnsV4?: string;

  @IsBoolean()
  @IsOptional()
  isObfuscated?: boolean;

  @IsInt()
  @IsOptional()
  obfuscationPort?: number;

  @IsString()
  @IsOptional()
  obfuscationProtocol?: string;
}

export class NodeHeartbeatDto {
  @IsString()
  @IsNotEmpty()
  hostname: string;

  @IsInt()
  @IsOptional()
  activePeers?: number;

  @IsInt()
  @IsOptional()
  memoryUsagePercent?: number;

  @IsOptional()
  loadAverage?: number[];

  @IsInt()
  @IsOptional()
  totalRxBytes?: number;

  @IsInt()
  @IsOptional()
  totalTxBytes?: number;
}
