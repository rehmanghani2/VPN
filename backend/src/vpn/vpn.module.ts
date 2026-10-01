import { Module } from '@nestjs/common';
import { VpnController } from './vpn.controller';
import { NodeController } from './node.controller';
import { VpnService } from './vpn.service';
import { NodeMonitorService } from './node-monitor.service';

@Module({
  controllers: [VpnController, NodeController],
  providers: [VpnService, NodeMonitorService],
  exports: [VpnService, NodeMonitorService],
})
export class VpnModule {}
