import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SalesService } from './sales.service';
import { SalesController } from './sales.controller';
import { Sale } from './entities/sale.entity';
import { SaleItem } from './entities/sale-item.entity';
import { ShiftsModule } from '../shifts/shifts.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { Refund } from './entities/refund.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Sale, SaleItem, Refund]),
    ShiftsModule,
    NotificationsModule,
  ],
  providers: [SalesService],
  controllers: [SalesController],
  exports: [SalesService],
})
export class SalesModule {}
