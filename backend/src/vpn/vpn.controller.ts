import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { VpnService } from './vpn.service';
import { ConnectVpnDto, DisconnectVpnDto } from './dto/connect.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('vpn')
@UseGuards(JwtAuthGuard)
export class VpnController {
  constructor(private readonly vpnService: VpnService) {}

  @Get('servers')
  async listServers() {
    return this.vpnService.listServers();
  }

  @Post('connect')
  @HttpCode(HttpStatus.OK)
  async connect(
    @CurrentUser('id') userId: string,
    @Body() dto: ConnectVpnDto,
  ) {
    return this.vpnService.connect(userId, dto);
  }

  @Post('disconnect')
  @HttpCode(HttpStatus.OK)
  async disconnect(
    @CurrentUser('id') userId: string,
    @Body() dto: DisconnectVpnDto,
  ) {
    return this.vpnService.disconnect(userId, dto);
  }

  @Post('rotate-key')
  @HttpCode(HttpStatus.OK)
  async rotateKey(
    @CurrentUser('id') userId: string,
    @Body() dto: any,
  ) {
    return this.vpnService.rotateKey(userId, dto);
  }

  @Get('key-status')
  async getKeyStatus(
    @CurrentUser('id') userId: string,
    @Query('deviceId') deviceId: string,
  ) {
    return this.vpnService.getKeyRotationStatus(userId, deviceId);
  }
}
