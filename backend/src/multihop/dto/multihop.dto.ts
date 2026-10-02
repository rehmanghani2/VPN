import { IsString, IsNotEmpty } from 'class-validator';

export class ConnectMultiHopDto {
  @IsString()
  @IsNotEmpty()
  entryServerId: string;

  @IsString()
  @IsNotEmpty()
  exitServerId: string;

  @IsString()
  @IsNotEmpty()
  deviceId: string;
}
