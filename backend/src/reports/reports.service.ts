import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, DataSource } from 'typeorm';
import { Sale } from '../sales/entities/sale.entity';
import { SaleItem } from '../sales/entities/sale-item.entity';
import { Product } from '../products/entities/product.entity';
import { Category } from '../categories/entities/category.entity';
import { Expense } from '../expenses/entities/expense.entity';
import { StoreSetting } from '../settings/entities/store-setting.entity';
import { Customer } from '../customers/entities/customer.entity';

@Injectable()
export class ReportsService {
  constructor(
    private dataSource: DataSource,
    @InjectRepository(Sale)
    private saleRepository: Repository<Sale>,
    @InjectRepository(SaleItem)
    private saleItemRepository: Repository<SaleItem>,
    @InjectRepository(Product)
    private productRepository: Repository<Product>,
    @InjectRepository(Category)
    private categoryRepository: Repository<Category>,
    @InjectRepository(Expense)
    private expenseRepository: Repository<Expense>,
    @InjectRepository(StoreSetting)
    private settingRepository: Repository<StoreSetting>,
  ) {}

  async getAnalyticsSummary() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);

    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);

    // Today's Sales
    const todaySales = await this.saleRepository.find({
      where: {
        transactionDate: Between(today, tomorrow),
      },
    });
    const todayTotal = todaySales.reduce(
      (sum, sale) => sum + Number(sale.finalAmount),
      0,
    );

    // Monthly Revenue
    const monthlySales = await this.saleRepository.find({
      where: {
        transactionDate: Between(startOfMonth, tomorrow),
      },
      relations: {
        items: {
          product: true,
        },
      },
    });
    const monthlyRevenue = monthlySales.reduce(
      (sum, sale) => sum + Number(sale.finalAmount),
      0,
    );

    // Monthly Profit (subtotal - (cost * quantity))
    let monthlyProfit = 0;
    monthlySales.forEach((sale) => {
      sale.items.forEach((item) => {
        const cost = item.product ? Number(item.product.purchasePrice) : 0;
        monthlyProfit += Number(item.subtotal) - cost * item.quantity;
      });
    });

    // Total Transactions
    const totalTransactions = await this.saleRepository.count();

    // Low Stock Count
    const lowStockCount = await this.productRepository
      .createQueryBuilder('product')
      .where('product.stockQuantity <= product.reorderLevel')
      .getCount();

    // New Customers Today
    const newCustomersToday = await this.dataSource
      .getRepository(Customer)
      .createQueryBuilder('customer')
      .where('customer.createdAt >= :today', { today })
      .getCount();

    return {
      today_sales: todayTotal,
      monthly_revenue: monthlyRevenue,
      monthly_profit: monthlyProfit,
      total_transactions: totalTransactions,
      low_stock_count: lowStockCount,
      new_customers_today: newCustomersToday,
    };
  }

  async getChartData() {
    // sales_trend: Last 7 days sales aggregated by date
    const last7Days: Date[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      d.setHours(0, 0, 0, 0);
      last7Days.push(d);
    }

    const salesTrend = await Promise.all(
      last7Days.map(async (date) => {
        const nextDate = new Date(date);
        nextDate.setDate(date.getDate() + 1);
        const sales = await this.saleRepository.find({
          where: {
            transactionDate: Between(date, nextDate),
          },
        });
        const total = sales.reduce((sum, s) => sum + Number(s.finalAmount), 0);
        return {
          date: date.toISOString().split('T')[0],
          total: total,
        };
      }),
    );

    // category_share: Total sales aggregated by category
    const categoryShare = await this.saleItemRepository
      .createQueryBuilder('si')
      .leftJoin('si.product', 'p')
      .leftJoin('p.category', 'c')
      .select('c.name', 'category')
      .addSelect('SUM(si.subtotal)', 'total')
      .groupBy('c.name')
      .getRawMany();

    return {
      sales_trend: salesTrend,
      category_share: categoryShare.map((cs) => ({
        category: cs.category || 'Uncategorized',
        total: Number(cs.total),
      })),
    };
  }

  async getTopSelling() {
    const topSelling = await this.saleItemRepository
      .createQueryBuilder('si')
      .leftJoin('si.product', 'p')
      .select('p.name', 'product')
      .addSelect('SUM(si.quantity)', 'total_quantity')
      .groupBy('p.name')
      .orderBy('total_quantity', 'DESC')
      .limit(10)
      .getRawMany();

    return topSelling.map((item) => ({
      product: item.product,
      total_quantity: Number(item.total_quantity),
    }));
  }

  async getSalesPrediction() {
    // Simple average of the last 7 days sales
    const last7DaysStart = new Date();
    last7DaysStart.setDate(last7DaysStart.getDate() - 7);
    last7DaysStart.setHours(0, 0, 0, 0);

    const sales = await this.saleRepository.find({
      where: {
        transactionDate: Between(last7DaysStart, new Date()),
      },
    });

    const total = sales.reduce((sum, s) => sum + Number(s.finalAmount), 0);
    const prediction = total / 7;

    return {
      predicted_sales: prediction,
    };
  }

  async getTopSuki() {
    return await this.dataSource
      .getRepository(Customer)
      .createQueryBuilder('c')
      .leftJoin('c.sales', 's')
      .select('c.id', 'id')
      .addSelect('c.name', 'name')
      .addSelect('c.email', 'email')
      .addSelect('COUNT(s.id)', 'order_count')
      .addSelect('SUM(s.finalAmount)', 'total_spend')
      .addSelect('MAX(s.transactionDate)', 'last_order')
      .groupBy('c.id')
      .orderBy('total_spend', 'DESC')
      .limit(10)
      .getRawMany();
  }

  async getShiftAudit(shiftId: number) {
    const paymentSummary = await this.saleRepository
      .createQueryBuilder('s')
      .select('s.paymentMethod', 'payment_method')
      .addSelect('SUM(s.finalAmount)', 'total')
      .where('s.shiftId = :shiftId', { shiftId })
      .groupBy('s.paymentMethod')
      .getRawMany();

    const categorySummary = await this.saleItemRepository
      .createQueryBuilder('si')
      .leftJoin('si.product', 'p')
      .leftJoin('p.category', 'c')
      .leftJoin('si.sale', 's')
      .select('c.name', 'category')
      .addSelect('SUM(si.subtotal)', 'total')
      .where('s.shiftId = :shiftId', { shiftId })
      .groupBy('c.name')
      .getRawMany();

    return {
      payment_summary: paymentSummary,
      category_summary: categorySummary,
    };
  }
}
