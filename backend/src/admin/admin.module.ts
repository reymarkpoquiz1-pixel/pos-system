import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { BackupService } from './backup.service';
import { Sale } from '../sales/entities/sale.entity';
import { User } from '../users/entities/user.entity';
import { Product } from '../products/entities/product.entity';
import { Category } from '../categories/entities/category.entity';
import { Customer } from '../customers/entities/customer.entity';
import { Staff } from '../staff/entities/staff.entity';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Sale, User, Product, Category, Customer, Staff]),
    SettingsModule,
  ],
  providers: [AdminService, BackupService],
  controllers: [AdminController],
})
export class AdminModule {}
