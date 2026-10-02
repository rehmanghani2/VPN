import { IsString, IsNotEmpty, IsNumber, Min, Max, IsIn, IsOptional } from 'class-validator';

export class CreatePortForwardDto {
  @IsString()
  @IsNotEmpty()
  deviceId: string;

  @IsString()
  @IsNotEmpty()
  serverId: string;

  @IsNumber()
  @Min(1)
  @Max(65535)
  internalPort: number;

  @IsOptional()
  @IsNumber()
  @Min(1024)
  @Max(65535)
  externalPort?: number;

  @IsOptional()
  @IsString()
  @IsIn(['TCP', 'UDP', 'BOTH'])
  protocol?: 'TCP' | 'UDP' | 'BOTH';
}
