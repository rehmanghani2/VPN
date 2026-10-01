import { Module } from '@nestjs/common';
import { VpnController } from './vpn.controller';
import { NodeController } from './node.controller';
import { SpeedTestController } from './speedtest.controller';
import { VpnService } from './vpn.service';
import { NodeMonitorService } from './node-monitor.service';

@Module({
  controllers: [VpnController, NodeController, SpeedTestController],
  providers: [VpnService, NodeMonitorService],
  exports: [VpnService, NodeMonitorService],
})
export class VpnModule {}
