import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('devices')
@UseGuards(JwtAuthGuard)
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Get()
  async list(@CurrentUser('id') userId: string) {
    return this.devicesService.listDevices(userId);
  }

  @Post()
  async register(
    @CurrentUser('id') userId: string,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.devicesService.registerDevice(userId, dto);
  }

  @Post(':id/disconnect')
  @HttpCode(HttpStatus.OK)
  async disconnect(
    @CurrentUser('id') userId: string,
    @Param('id') deviceId: string,
  ) {
    return this.devicesService.disconnectDevice(userId, deviceId);
  }

  @Delete(':id')
  async remove(
    @CurrentUser('id') userId: string,
    @Param('id') deviceId: string,
  ) {
    return this.devicesService.removeDevice(userId, deviceId);
  }
}
