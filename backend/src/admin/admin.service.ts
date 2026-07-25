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

    const totalSalesResult = await this.saleRepository
      .createQueryBuilder('sale')
      .select('SUM(sale.finalAmount)', 'total')
      .where('sale.transactionDate BETWEEN :start AND :end', {
        start: startOfDay,
        end: endOfDay,
      })
      .getRawOne();

    const totalSales = parseFloat(totalSalesResult?.total || '0');

    const orderCount = await this.saleRepository.count({
      where: {
        transactionDate: Between(startOfDay, endOfDay),
      },
    });

    const activeEmployeesCount = await this.userRepository.count({
      where: {
        role: UserRole.STAFF,
      },
    });

    const lowStockCount = await this.productRepository
      .createQueryBuilder('product')
      .where('product.stockQuantity <= product.reorderLevel')
      .getCount();

    const firstDayOfMonth = new Date(startOfDay.getFullYear(), startOfDay.getMonth(), 1);
    const monthlySales = await this.saleRepository.find({
      where: {
        transactionDate: Between(firstDayOfMonth, endOfDay),
      },
      relations: {
        items: {
          product: true,
        },
      },
    });

    const totalRevenueMonth = monthlySales.reduce((sum, s) => sum + Number(s.finalAmount), 0);
    let totalProfitMonth = 0;
    monthlySales.forEach((sale) => {
      sale.items.forEach((item) => {
        const cost = item.purchasePrice || (item.product ? Number(item.product.purchasePrice) : 0);
        totalProfitMonth += Number(item.subtotal) - cost * item.quantity;
      });
    });

    const newCustomersToday = await this.customerRepository
      .createQueryBuilder('customer')
      .where('customer.createdAt >= :today', { today: startOfDay })
      .getCount();

    const recentSales = await this.saleRepository.find({
      relations: { user: true, customer: true, items: { product: true } },
      order: { transactionDate: 'DESC' },
      take: 10,
    });

    const storeSettings = await this.settingsService.getStoreSettings();

    const allProducts = await this.productRepository.find({
      relations: { category: true },
    });
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

    const rawCategories = await this.categoryRepository.find({
      where: { parentId: IsNull() },
      relations: { children: true },
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

    const allEmployees = await this.userRepository.find({
      where: { role: Not(UserRole.USER) },
      relations: { staff: true },
    });

    const allCustomers = await this.customerRepository.find();

    // Charts - Hourly Sales
    const hourlySalesRaw = await this.saleRepository
      .createQueryBuilder('sale')
      .select("EXTRACT(HOUR FROM sale.transactionDate)", "hour")
      .addSelect("SUM(sale.finalAmount)", "total")
      .where('sale.transactionDate BETWEEN :start AND :end', { start: startOfDay, end: endOfDay })
      .groupBy("hour")
      .orderBy("hour", "ASC")
      .getRawMany();

    // Charts - Payment Methods
    const paymentMethodsRaw = await this.saleRepository
      .createQueryBuilder('sale')
      .select("sale.paymentMethod", "payment_method")
      .addSelect("COUNT(*)", "count")
      .where('sale.transactionDate BETWEEN :start AND :end', { start: startOfDay, end: endOfDay })
      .groupBy("sale.paymentMethod")
      .getRawMany();

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
        hourly_sales: hourlySalesRaw.map(h => ({ h: h.hour, total: h.total })),
        payment_methods: paymentMethodsRaw.map(p => ({ payment_method: p.payment_method, count: p.count })),
      },
      products: mappedProducts,
      top_selling_products: mappedProducts.slice(0, 5), // Simple placeholder for top selling
      categories: allCategories,
      employees: allEmployees.map(e => ({
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
        items: (sale.items || []).map(item => ({
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
