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
import { PortForwardingService } from './port-forwarding.service';
import { CreatePortForwardDto } from './dto/port-forwarding.dto';

@Controller('port-forwarding')
@UseGuards(JwtAuthGuard)
export class PortForwardingController {
  constructor(private readonly portForwardingService: PortForwardingService) {}

  @Get()
  async getMyPortForwards(@CurrentUser('id') userId: string) {
    return this.portForwardingService.getUserPortForwards(userId);
  }

  @Post()
  async createPortForward(
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePortForwardDto,
  ) {
    return this.portForwardingService.createPortForward(userId, dto);
  }

  @Delete(':id')
  async deletePortForward(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
  ) {
    return this.portForwardingService.deletePortForward(userId, id);
  }
}
