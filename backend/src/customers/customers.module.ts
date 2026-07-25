import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CustomersService } from './customers.service';
import { CustomersController } from './customers.controller';
import { Customer } from './entities/customer.entity';
import { CustomerPointsHistory } from './entities/customer-points-history.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Customer, CustomerPointsHistory])],
  providers: [CustomersService],
  controllers: [CustomersController],
  exports: [CustomersService, TypeOrmModule],
})
export class CustomersModule {}
