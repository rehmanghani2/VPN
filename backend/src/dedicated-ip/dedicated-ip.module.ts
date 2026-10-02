import { Module } from '@nestjs/common';
import { DedicatedIpService } from './dedicated-ip.service';
import { DedicatedIpController } from './dedicated-ip.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [DedicatedIpController],
  providers: [DedicatedIpService],
  exports: [DedicatedIpService],
})
export class DedicatedIpModule {}
