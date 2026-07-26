import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProductsService } from './products.service';
import { ProductsController } from './products.controller';
import { Product } from './entities/product.entity';
import { StockHistory } from './entities/stock-history.entity';
import { CategoriesModule } from '../categories/categories.module';
import { ActivityLogsModule } from '../activity-logs/activity-logs.module';
import { CloudinaryModule } from '../cloudinary/cloudinary.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Product, StockHistory]),
    CategoriesModule,
    ActivityLogsModule,
    CloudinaryModule,
  ],
  providers: [ProductsService],
  controllers: [ProductsController],
  exports: [ProductsService],
})
export class ProductsModule {}
