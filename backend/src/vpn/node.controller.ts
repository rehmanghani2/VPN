import {
  Controller,
  Post,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
  Get,
} from '@nestjs/common';
import { NodeMonitorService } from './node-monitor.service';
import { RegisterNodeDto, NodeHeartbeatDto } from './dto/node.dto';
import { NodeTokenGuard } from './guards/node-token.guard';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('vpn/nodes')
export class NodeController {
  constructor(private readonly nodeMonitorService: NodeMonitorService) {}

  /**
   * Edge Node self-registration on boot via cloud-init / bootstrap script
   */
  @Post('register')
  @UseGuards(NodeTokenGuard)
  @HttpCode(HttpStatus.OK)
  async register(@Body() dto: RegisterNodeDto) {
    return this.nodeMonitorService.registerNode(dto);
  }

  /**
   * Edge Node periodic heartbeat / telemetry push
   */
  @Post('heartbeat')
  @UseGuards(NodeTokenGuard)
  @HttpCode(HttpStatus.OK)
  async heartbeat(@Body() dto: NodeHeartbeatDto) {
    return this.nodeMonitorService.recordHeartbeat(dto);
  }

  /**
   * Drain an edge server for rolling updates or maintenance
   */
  @Post(':id/drain')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async drainServer(@Param('id') serverId: string) {
    return this.nodeMonitorService.drainServer(serverId);
  }

  /**
   * Restore a drained or offline server back to active cluster rotation
   */
  @Post(':id/restore')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async restoreServer(@Param('id') serverId: string) {
    return this.nodeMonitorService.restoreServer(serverId);
  }

  /**
   * Trigger an immediate manual health check across all cluster nodes
   */
  @Post('probe')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async triggerProbes() {
    await this.nodeMonitorService.runHealthChecks();
    return { success: true, message: 'Node health probes executed' };
  }
}
