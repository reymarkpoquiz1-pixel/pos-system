import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Sale, PaymentMethod, OrderType } from './entities/sale.entity';
import { SaleItem } from './entities/sale-item.entity';
import { Product } from '../products/entities/product.entity';
import { Customer } from '../customers/entities/customer.entity';
import { CustomerPointsHistory } from '../customers/entities/customer-points-history.entity';
import { ShiftsService } from '../shifts/shifts.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';

@Injectable()
export class SalesService {
  private readonly logger = new Logger(SalesService.name);

  constructor(
    private dataSource: DataSource,
    private readonly shiftsService: ShiftsService,
    private readonly notificationsService: NotificationsService,
    @InjectRepository(Sale)
    private readonly saleRepository: Repository<Sale>,
  ) {}

  async placeOrder(orderData: any, userId: number, role: string) {
    try {
      return await this.dataSource.transaction(async (manager) => {
        // 1. Check for an active shift (Optional check based on role - only for walk-in/staff)
        const activeShift = await this.shiftsService.findActiveShift(userId);
        if (!activeShift && role !== 'User') {
          throw new BadRequestException(
            'No active shift found for this user. Please open a shift first.',
          );
        }

        const {
          customer_id,
          items,
          discount = 0,
          points_to_spend = 0,
          shipping_fee = 0,
          shipping_address,
          payment_method,
          order_type,
          amount_paid,
        } = orderData;

        if (!items || !Array.isArray(items) || items.length === 0) {
          throw new BadRequestException(
            'Order must contain at least one item.',
          );
        }

        // 2. Calculate total_amount and verify products
        let totalAmount = 0;
        const verifiedItems: {
          product: Product;
          quantity: number;
          unitPrice: number;
          purchasePrice: number;
          subtotal: number;
        }[] = [];

        for (const item of items) {
          const product = await manager.findOne(Product, {
            where: { id: item.product_id },
          });
          if (!product) {
            throw new BadRequestException(
              `Product with ID ${item.product_id} not found.`,
            );
          }
          if (product.status !== 'Active') {
            throw new BadRequestException(
              `Product ${product.name} is not active.`,
            );
          }
          if (product.stockQuantity < item.quantity) {
            throw new BadRequestException(
              `Insufficient stock for product: ${product.name}. Available: ${product.stockQuantity}`,
            );
          }

          const subtotal = Number(product.sellingPrice) * item.quantity;
          totalAmount += subtotal;

          verifiedItems.push({
            product,
            quantity: item.quantity,
            unitPrice: product.sellingPrice,
            purchasePrice: product.purchasePrice,
            subtotal,
          });
        }

        // Apply point discount (1 point = 1 peso)
        let pointDiscount = 0;
        if (points_to_spend > 0 && customer_id) {
          const customer = await manager.findOne(Customer, {
            where: { id: customer_id },
          });
          if (!customer || customer.points < points_to_spend) {
            throw new BadRequestException('Insufficient loyalty points.');
          }
          pointDiscount = points_to_spend;
        }

        const totalDiscount = Number(discount) + pointDiscount;
        const finalAmount = totalAmount - totalDiscount + Number(shipping_fee);
        const amountPaidNum = Number(amount_paid || finalAmount);
        const change = amountPaidNum - finalAmount;

        if (
          change < 0 &&
          (payment_method === PaymentMethod.CASH || !payment_method)
        ) {
          throw new BadRequestException(
            `Insufficient payment. Total: ${finalAmount}, Paid: ${amountPaidNum}`,
          );
        }

        // 3. Create Sale record
        const sale = manager.create(Sale, {
          user: { id: userId } as any,
          customer: customer_id ? ({ id: customer_id } as any) : undefined,
          branch: activeShift
            ? ({ id: activeShift.branch.id } as any)
            : undefined,
          totalAmount,
          discount: totalDiscount,
          finalAmount,
          amountPaid: amountPaidNum,
          change: change > 0 ? change : 0,
          shippingFee: shipping_fee,
          shippingAddress: shipping_address,
          paymentMethod: payment_method || PaymentMethod.CASH,
          orderType:
            order_type ||
            (role === 'User' ? OrderType.ONLINE : OrderType.WALKIN),
        });

        const savedSale = await manager.save(Sale, sale);

        // 4. Create SaleItems and update stock
        for (const vItem of verifiedItems) {
          const saleItem = manager.create(SaleItem, {
            sale: savedSale,
            product: vItem.product as any,
            quantity: vItem.quantity,
            purchasePrice: vItem.purchasePrice, // Capture COGS at time of sale
            unitPrice: vItem.unitPrice,
            subtotal: vItem.subtotal,
          });
          await manager.save(SaleItem, saleItem);

          // Subtract stock
          vItem.product.stockQuantity -= vItem.quantity;
          await manager.save(Product, vItem.product);

          // Low stock alert via NotificationsService
          if (vItem.product.stockQuantity <= vItem.product.reorderLevel) {
            await this.notificationsService.create({
              title:
                vItem.product.stockQuantity <= 0
                  ? `Out of Stock: ${vItem.product.name}`
                  : `Low Stock Alert: ${vItem.product.name}`,
              message: `Product ${vItem.product.name} is ${vItem.product.stockQuantity <= 0 ? 'out of stock' : 'running low (' + vItem.product.stockQuantity + ' left)'}.`,
              type:
                vItem.product.stockQuantity <= 0
                  ? NotificationType.ERROR
                  : NotificationType.WARNING,
            });
          }
        }

        // 5. Update loyalty points and history
        if (customer_id) {
          const pointsEarned = Math.floor(finalAmount / 100);
          const customer = await manager.findOne(Customer, {
            where: { id: customer_id },
          });
          if (customer) {
            customer.points =
              Number(customer.points) + pointsEarned - points_to_spend;
            await manager.save(Customer, customer);

            // Log points history
            const pointsLog = manager.create(CustomerPointsHistory, {
              customerId: customer.id,
              saleId: savedSale.id,
              pointsEarned,
              pointsSpent: points_to_spend,
              reason: 'Order Purchase',
            });
            await manager.save(pointsLog);
          }
        }

        // 6. Update shift total sales
        if (activeShift) {
          activeShift.totalSales = Number(activeShift.totalSales) + finalAmount;
          await manager.save(activeShift);
        }

        return { success: true, sale_id: savedSale.id };
      });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      this.logger.error(`Failed to place order: ${errorMessage}`);
      throw error;
    }
  }

  async getShiftHistory() {
    return await this.saleRepository.find({
      relations: ['user', 'branch'],
      order: { transactionDate: 'DESC' },
      take: 20,
    });
  }

  async getUserOrders(userId: number) {
    return await this.saleRepository.find({
      where: { user: { id: userId } },
      relations: { items: { product: true } },
      order: { transactionDate: 'DESC' },
    });
  }
}
