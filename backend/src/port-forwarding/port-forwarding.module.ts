import { Module } from '@nestjs/common';
import { PortForwardingService } from './port-forwarding.service';
import { PortForwardingController } from './port-forwarding.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [PortForwardingController],
  providers: [PortForwardingService],
  exports: [PortForwardingService],
})
export class PortForwardingModule {}
