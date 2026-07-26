import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, DataSource, IsNull, Not } from 'typeorm';
import { Sale } from '../sales/entities/sale.entity';
import { User, UserRole } from '../users/entities/user.entity';
import { Product } from '../products/entities/product.entity';
import { Category } from '../categories/entities/category.entity';
import { Customer } from '../customers/entities/customer.entity';
import { SettingsService } from '../settings/settings.service';

@Injectable()
export class AdminService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(Sale)
    private readonly saleRepository: Repository<Sale>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Product)
    private readonly productRepository: Repository<Product>,
    @InjectRepository(Category)
    private readonly categoryRepository: Repository<Category>,
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
    private readonly settingsService: SettingsService,
  ) {}

  async getInitialData() {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const firstDayOfMonth = new Date(
      startOfDay.getFullYear(),
      startOfDay.getMonth(),
      1,
    );

    // Run basic counts and single-table summaries in parallel
    const [
      totalSalesResult,
      orderCount,
      activeEmployeesCount,
      lowStockCount,
      newCustomersToday,
      storeSettings,
      allProducts,
      rawCategories,
      allEmployees,
      allCustomers,
      hourlySalesRaw,
      paymentMethodsRaw,
      monthlyStats,
    ] = await Promise.all([
      // 1. Today's Sales
      this.saleRepository
        .createQueryBuilder('sale')
        .select('SUM(sale.finalAmount)', 'total')
        .where('sale.transactionDate BETWEEN :start AND :end', {
          start: startOfDay,
          end: endOfDay,
        })
        .getRawOne(),

      // 2. Today's Order Count
      this.saleRepository.count({
        where: { transactionDate: Between(startOfDay, endOfDay) },
      }),

      // 3. Active Employees
      this.userRepository.count({
        where: { role: UserRole.STAFF },
      }),

      // 4. Low Stock Count
      this.productRepository
        .createQueryBuilder('product')
        .where('product.stockQuantity <= product.reorderLevel')
        .getCount(),

      // 5. New Customers Today
      this.customerRepository
        .createQueryBuilder('customer')
        .where('customer.createdAt >= :today', { today: startOfDay })
        .getCount(),

      // 6. Store Settings
      this.settingsService.getStoreSettings(),

      // 7. Products
      this.productRepository.find({ relations: { category: true } }),

      // 8. Categories
      this.categoryRepository.find({
        where: { parentId: IsNull() },
        relations: { children: true },
      }),

      // 9. Employees
      this.userRepository.find({
        where: { role: Not(UserRole.USER) },
        relations: { staff: true },
      }),

      // 10. Customers
      this.customerRepository.find(),

      // 11. Hourly Sales
      this.saleRepository
        .createQueryBuilder('sale')
        .select('EXTRACT(HOUR FROM sale.transactionDate)', 'hour')
        .addSelect('SUM(sale.finalAmount)', 'total')
        .where('sale.transactionDate BETWEEN :start AND :end', {
          start: startOfDay,
          end: endOfDay,
        })
        .groupBy('hour')
        .orderBy('hour', 'ASC')
        .getRawMany(),

      // 12. Payment Methods
      this.saleRepository
        .createQueryBuilder('sale')
        .select('sale.paymentMethod', 'payment_method')
        .addSelect('COUNT(*)', 'count')
        .where('sale.transactionDate BETWEEN :start AND :end', {
          start: startOfDay,
          end: endOfDay,
        })
        .groupBy('sale.paymentMethod')
        .getRawMany(),

      // 13. Monthly Revenue and Profit via SQL Aggregate (JOIN)
      // This is much faster than fetching thousands of rows
      this.dataSource
        .createQueryBuilder()
        .select('SUM(sale.finalAmount)', 'revenue')
        .addSelect(
          'SUM(item.subtotal - (COALESCE(item.purchasePrice, p.purchasePrice, 0) * item.quantity))',
          'profit',
        )
        .from(Sale, 'sale')
        .innerJoin('sale_items', 'item', 'item.sale_id = sale.id')
        .leftJoin('products', 'p', 'p.id = item.product_id')
        .where('sale.transactionDate BETWEEN :start AND :end', {
          start: firstDayOfMonth,
          end: endOfDay,
        })
        .getRawOne(),
    ]);

    // Fetch recent sales separately (smaller limit for initial data)
    const recentSales = await this.saleRepository.find({
      relations: { user: true, customer: true, items: { product: true } },
      order: { transactionDate: 'DESC' },
      take: 5, // Reduced from 10 to speed up initial payload
    });

    const totalSales = parseFloat(totalSalesResult?.total || '0');
    const totalRevenueMonth = parseFloat(monthlyStats?.revenue || '0');
    const totalProfitMonth = parseFloat(monthlyStats?.profit || '0');

    const mappedProducts = allProducts.map((p) => {
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

    const allCategories = rawCategories.map((cat) => ({
      ...cat,
      parent_id: cat.parentId,
      sub_categories: (cat.children || []).map((child) => ({
        ...child,
        parent_id: child.parentId,
        created_at: child.createdAt,
        updated_at: child.updatedAt,
      })),
      created_at: cat.createdAt,
      updated_at: cat.updatedAt,
    }));

    return {
      stats: {
        total_sales_today: totalSales.toFixed(2),
        new_customers_today: newCustomersToday.toString(),
        total_transactions_today: orderCount.toString(),
        total_revenue_month: totalRevenueMonth.toFixed(2),
        total_profit_month: totalProfitMonth.toFixed(2),
        low_stock_count: lowStockCount,
        active_employees: activeEmployeesCount,
      },
      charts: {
        hourly_sales: hourlySalesRaw.map((h) => ({
          h: h.hour,
          total: h.total,
        })),
        payment_methods: paymentMethodsRaw.map((p) => ({
          payment_method: p.payment_method,
          count: p.count,
        })),
      },
      products: mappedProducts,
      top_selling_products: mappedProducts.slice(0, 5),
      categories: allCategories,
      employees: allEmployees.map((e) => ({
        user_id: e.id,
        username: e.username,
        email: e.email,
        role: e.role,
        status: e.status,
        first_name: e.staff?.firstName,
        last_name: e.staff?.lastName,
        profile_image: e.staff?.profileImage,
        terminal_id: e.staff?.terminalId,
        created_at: e.createdAt,
      })),
      customers: allCustomers,
      transactions: recentSales.map((sale) => ({
        transaction_id: sale.id.toString(),
        final_amount: sale.finalAmount,
        transaction_date: sale.transactionDate,
        order_type: sale.orderType,
        user_name: sale.user?.username,
        customer_name: sale.customer?.name || 'Guest',
        order_status: sale.orderStatus,
        payment_method: sale.paymentMethod,
        items: (sale.items || []).map((item) => ({
          product_id: item.product?.id,
          name: item.product?.name,
          quantity: item.quantity,
          unit_price: item.unitPrice,
          subtotal: item.subtotal,
        })),
      })),
      notifications: [],
      branches: [],
      store_settings: {
        ...storeSettings,
        id: storeSettings?.id?.toString(),
      },
    };
  }
}
