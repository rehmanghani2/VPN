import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { MultiHopService } from './multihop.service';
import { ConnectMultiHopDto } from './dto/multihop.dto';

@Controller('vpn')
@UseGuards(JwtAuthGuard)
export class MultiHopController {
  constructor(private readonly multiHopService: MultiHopService) {}

  @Get('multihop/pairs')
  async getPairs() {
    return this.multiHopService.getMultiHopPairs();
  }

  @Post('multihop/connect')
  async connectMultiHop(
    @CurrentUser('id') userId: string,
    @Body() dto: ConnectMultiHopDto,
  ) {
    return this.multiHopService.connectMultiHop(userId, dto);
  }

  @Get('onion/servers')
  async getOnionServers() {
    return this.multiHopService.getOnionServers();
  }
}
