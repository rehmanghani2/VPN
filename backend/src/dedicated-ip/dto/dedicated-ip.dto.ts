import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class ReserveDedicatedIpDto {
  @IsString()
  @IsNotEmpty()
  serverId: string;

  @IsOptional()
  @IsString()
  deviceId?: string;
}

export class AssignDedicatedIpDto {
  @IsString()
  @IsNotEmpty()
  dedicatedIpId: string;

  @IsString()
  @IsNotEmpty()
  deviceId: string;
}
