import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';

export class OverrideUserPlanDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['FREE', 'PRO', 'FAMILY', 'ENTERPRISE', 'PREMIUM'])
  planType: string;

  @IsInt()
  @IsOptional()
  @Min(1)
  maxDevices?: number;
}

export class UpdateServerDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsInt()
  @IsOptional()
  @Min(1)
  capacity?: number;

  @IsString()
  @IsOptional()
  @IsIn(['ONLINE', 'DRAINING', 'OFFLINE', 'MAINTENANCE'])
  status?: string;
}
