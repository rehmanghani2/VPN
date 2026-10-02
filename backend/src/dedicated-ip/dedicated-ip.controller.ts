import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DedicatedIpService } from './dedicated-ip.service';
import { ReserveDedicatedIpDto, AssignDedicatedIpDto } from './dto/dedicated-ip.dto';

@Controller('dedicated-ip')
@UseGuards(JwtAuthGuard)
export class DedicatedIpController {
  constructor(private readonly dedicatedIpService: DedicatedIpService) {}

  @Get()
  async getMyDedicatedIps(@CurrentUser('id') userId: string) {
    return this.dedicatedIpService.getUserDedicatedIps(userId);
  }

  @Get('available-regions')
  async getAvailableRegions() {
    return this.dedicatedIpService.getAvailableRegions();
  }

  @Post('reserve')
  async reserveDedicatedIp(
    @CurrentUser('id') userId: string,
    @Body() dto: ReserveDedicatedIpDto,
  ) {
    return this.dedicatedIpService.reserveDedicatedIp(userId, dto);
  }

  @Post('assign')
  async assignToDevice(
    @CurrentUser('id') userId: string,
    @Body() dto: AssignDedicatedIpDto,
  ) {
    return this.dedicatedIpService.assignToDevice(userId, dto);
  }

  @Delete(':id')
  async releaseDedicatedIp(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
  ) {
    return this.dedicatedIpService.releaseDedicatedIp(userId, id);
  }
}
