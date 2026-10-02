import { Module } from '@nestjs/common';
import { MultiHopService } from './multihop.service';
import { MultiHopController } from './multihop.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [MultiHopController],
  providers: [MultiHopService],
  exports: [MultiHopService],
})
export class MultiHopModule {}
