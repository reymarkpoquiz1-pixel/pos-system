import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Product } from './entities/product.entity';
import { StockHistory } from './entities/stock-history.entity';
import { ActivityLogsService } from '../activity-logs/activity-logs.service';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private productsRepository: Repository<Product>,
    @InjectRepository(StockHistory)
    private stockHistoryRepository: Repository<StockHistory>,
    private activityLogsService: ActivityLogsService,
    private dataSource: DataSource,
  ) {}

  async upsertProduct(data: any, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const {
        id,
        name,
        barcode,
        description,
        purchase_price,
        cost_price, // Support both names
        selling_price,
        stock_quantity,
        reorder_level,
        category_id,
        tags,
        variants,
        images,
        admin_id,
        added_by, // Support added_by from Flutter
      } = data;

      let product: Product;
      let action = 'UPDATE_PRODUCT';
      let details = `Updated product: ${name}`;

      if (id && id !== 'null' && id !== '') {
        const existingProduct = await manager.findOne(Product, {
          where: { id: Number(id) },
        });
        if (!existingProduct) throw new NotFoundException('Product not found');
        product = existingProduct;
      } else {
        product = manager.create(Product);
        action = 'ADD_PRODUCT';
        details = `Added new product: ${name}`;
      }

      // Convert Strings to Numbers (Multi-part sends everything as string)
      if (name) product.name = name;
      if (barcode) product.barcode = barcode;
      if (description) product.description = description;

      const pPrice = cost_price || purchase_price;
      if (pPrice !== undefined) product.purchasePrice = Number(pPrice);
      if (selling_price !== undefined) product.sellingPrice = Number(selling_price);
      if (stock_quantity !== undefined) product.stockQuantity = Number(stock_quantity);
      if (reorder_level !== undefined) product.reorderLevel = Number(reorder_level);
      if (category_id) product.categoryId = Number(category_id);

      // JSON fields
      if (tags) {
        product.tags = typeof tags === 'string' ? JSON.parse(tags) : tags;
      }
      if (variants) {
        product.variants =
          typeof variants === 'string' ? JSON.parse(variants) : variants;
      }

      // Images - handle as comma separated string or array
      if (images) {
        if (Array.isArray(images)) {
          product.imageUrl = images.join(',');
        } else {
          product.imageUrl = images;
        }
      }

      const saved = await manager.save(product);

      const actingAdminId = admin_id || added_by;
      await this.activityLogsService.log(actingAdminId ? Number(actingAdminId) : null, action, details, ip);

      return { success: true, data: saved };
    });
  }

  async findAll() {
    const products = await this.productsRepository.find({
      relations: { category: true },
    });
    return products.map((p) => {
      const allImages = p.imageUrl ? p.imageUrl.split(',') : [];
      return {
        ...p,
        image_url: allImages.length > 0 ? allImages[0] : null,
        images: allImages,
        stock_quantity: p.stockQuantity,
        selling_price: p.sellingPrice,
        cost_price: p.purchasePrice,
        reorder_level: p.reorderLevel,
        category_name: p.category?.name,
        created_at: p.createdAt,
        updated_at: p.updatedAt,
      };
    });
  }

  async adjustStock(data: any) {
    return await this.dataSource.transaction(async (manager) => {
      const { product_id, adjustment, reason, user_id, variant_index } = data;
      const product = await manager.findOne(Product, {
        where: { id: product_id },
      });
      if (!product) throw new NotFoundException('Product not found');

      product.stockQuantity += Number(adjustment);

      if (variant_index !== undefined && product.variants) {
        let variants = product.variants;
        if (typeof variants === 'string') variants = JSON.parse(variants);
        if (variants[variant_index]) {
          variants[variant_index].stock_quantity =
            (variants[variant_index].stock_quantity || 0) + Number(adjustment);
          product.variants = variants;
        }
      }

      await manager.save(product);

      const history = manager.create(StockHistory, {
        productId: product_id,
        adjustment: Number(adjustment),
        reason,
        userId: user_id ? Number(user_id) : undefined,
      } as any);
      await manager.save(history);

      return { success: true, new_stock: product.stockQuantity };
    });
  }

  async getStockHistory(productId: number) {
    const history = await this.stockHistoryRepository.find({
      where: { productId },
      relations: { user: true },
      order: { createdAt: 'DESC' },
    });

    return history.map((h) => ({
      ...h,
      user_name: h.user?.username || 'Admin',
      created_at: h.createdAt,
    }));
  }

  async getReorderList() {
    return this.productsRepository
      .createQueryBuilder('product')
      .where('product.stock_quantity <= product.reorder_level')
      .getMany();
  }
}
