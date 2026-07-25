import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { PurchaseOrder, POStatus } from './entities/purchase-order.entity';
import { PurchaseOrderItem } from './entities/purchase-order-item.entity';
import { Product } from '../products/entities/product.entity';

@Injectable()
export class InventoryService {
  constructor(
    private dataSource: DataSource,
    @InjectRepository(PurchaseOrder)
    private readonly poRepository: Repository<PurchaseOrder>,
    @InjectRepository(PurchaseOrderItem)
    private readonly poItemRepository: Repository<PurchaseOrderItem>,
  ) {}

  async createPurchaseOrder(data: any) {
    const { supplier_id, order_date, expected_date, items } = data;

    if (!items || !Array.isArray(items) || items.length === 0) {
      throw new BadRequestException('Items are required for a purchase order.');
    }

    return await this.dataSource.transaction(async (manager) => {
      let totalAmount = 0;

      const purchaseOrder = manager.create(PurchaseOrder, {
        supplierId: supplier_id,
        orderDate: order_date ? new Date(order_date) : new Date(),
        expectedDate: expected_date ? new Date(expected_date) : undefined,
        status: POStatus.PENDING,
      } as any);

      const savedPO = await manager.save(purchaseOrder);

      for (const item of items) {
        const subtotal = item.quantity * item.unit_cost;
        totalAmount += subtotal;

        const poItem = manager.create(PurchaseOrderItem, {
          purchaseOrderId: savedPO.id,
          productId: item.product_id,
          quantity: item.quantity,
          unitCost: item.unit_cost,
          subtotal,
        });
        await manager.save(poItem);
      }

      savedPO.totalAmount = totalAmount;
      return await manager.save(savedPO);
    });
  }

  async receivePurchaseOrder(poId: number) {
    return await this.dataSource.transaction(async (manager) => {
      const po = await manager.findOne(PurchaseOrder, {
        where: { id: poId },
        relations: { items: true },
      });

      if (!po) throw new NotFoundException('Purchase Order not found.');
      if (po.status === POStatus.RECEIVED) {
        throw new BadRequestException(
          'Purchase Order has already been received.',
        );
      }

      for (const item of po.items) {
        const product = await manager.findOne(Product, {
          where: { id: item.productId },
        });
        if (product) {
          product.stockQuantity = Number(product.stockQuantity) + item.quantity;
          await manager.save(product);
        }
      }

      po.status = POStatus.RECEIVED;
      return await manager.save(po);
    });
  }

  async findAllPOs() {
    return this.poRepository.find({
      relations: { supplier: true, items: true },
    });
  }

  async getReorderList() {
    return this.dataSource
      .getRepository(Product)
      .createQueryBuilder('product')
      .where('product.stockQuantity <= product.reorderLevel')
      .getMany();
  }
}
